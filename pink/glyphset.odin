package pink

import "core:c"
import "core:hash"
import "core:sort"
import "rect_atlas"
import "fontdue"
import "render"

GLYPHSET_PAGE_SIZE :: 2048

// A set of rasterized glyphs from a typeface.
Glyphset :: struct {
	core: Glyphset_Core,
}

@(private)
Glyphset_Core :: struct {
	hash: u32,
	baked: bool,
	flushed: bool,
	baked_glyphs: map[rune]int,
	pages: [dynamic]render.Texture,
	bitmap: [dynamic]u8,
	glyphs: [dynamic]Glyph,
	ftd_fonts: [dynamic]fontdue.Font,
	faces: map[Rasterization_Face]bool,
}

@(private)
Rasterization_Face :: struct {
	font: fontdue.Font,
	size: f32,
	index: c.uintptr_t,
}

@(private)
Glyph :: struct {
	face: Rasterization_Face,
	ftd_index: int,
	packed: bool,
	glyph: rune,
	offset: int,
	uv: [4]f32,
	page: int,
	x: int,
	y: int,
	w: int,
	h: int,
}

// Destroys a glyphset.
glyphset_destroy :: proc(
	glyphset: Glyphset,
) {
	if glyphset.core.baked {
		for _, i in glyphset.core.pages {
			render.texture_deinit(&glyphset.core.pages[i])
		}
	}
	delete(glyphset.core.baked_glyphs)
	delete(glyphset.core.pages)
	delete(glyphset.core.bitmap)
	delete(glyphset.core.glyphs)
	delete(glyphset.core.faces)
	delete(glyphset.core.ftd_fonts)
}

// Bakes the glyphset into a format that can be drawn from.
glyphset_bake :: proc(
	glyphset: ^Glyphset,
) {
	glyphset.core.hash = hash.murmur32(glyphset.core.bitmap[:])
	glyphset.core.flushed = false
	clear(&glyphset.core.baked_glyphs)

	if glyphset.core.baked {
		for _, i in glyphset.core.pages {
			render.texture_deinit(&glyphset.core.pages[i])
		}
		clear(&glyphset.core.pages)
	}
	
	atlas: rect_atlas.Atlas(Glyph)
	rect_atlas.atlas_clear(&atlas, GLYPHSET_PAGE_SIZE)
	defer rect_atlas.atlas_destroy(atlas)
	
	// Sort glyphs to improve atlas packing
	sorter := sort.Interface{
		len = proc(it: sort.Interface) -> int {
			bitmaps := (^[dynamic]Glyph)(it.collection)
			return len(bitmaps^)
		},
		less = proc(it: sort.Interface, i, j: int) -> bool {
			bitmaps := (^[dynamic]Glyph)(it.collection)
			return bitmaps[i].w * bitmaps[i].h > bitmaps[j].w * bitmaps[j].h
		},
		swap = proc(it: sort.Interface, i, j: int) {
			bitmaps := (^[dynamic]Glyph)(it.collection)
			bj, bi := bitmaps[j], bitmaps[i]
			bitmaps[i], bitmaps[j] = bj, bi
		},
		collection = &glyphset.core.glyphs,
	}
	sort.sort(sorter)

	// Begin with one glyph page
	all_packed := false

	for !all_packed {
		all_packed = true
		append(&glyphset.core.pages, render.Texture{})
		rect_atlas.atlas_clear(&atlas, GLYPHSET_PAGE_SIZE)
		
		// Cycle through all rasterized glyphs
		for glyph, i in glyphset.core.glyphs {
			if _, baked := glyphset.core.baked_glyphs[glyph.glyph]; baked {
				panic("Attempt to bake a glyph twice")
			}
			
			if !glyph.packed {
				// Attempt to pack it into the current atlas (i.e. page)
				packed := rect_atlas.atlas_pack(
					&atlas,
					&glyphset.core.glyphs[i],
				)

				// If it fits into the current page:
				// * Store the lookup index of the glyph in the baked_glyphs map so that
				//   we can find it by rune
				// * Set the glyph's page index and calculate its UV coordinates within
				//   its page
				if packed {
					u1, v1 := 
						f32(glyphset.core.glyphs[i].x) / f32(GLYPHSET_PAGE_SIZE),
						f32(glyphset.core.glyphs[i].y) / f32(GLYPHSET_PAGE_SIZE)

					glyphset.core.glyphs[i].page = len(glyphset.core.pages) - 1
					glyphset.core.glyphs[i].uv = {
						u1,
						v1,
						u1 + f32(glyphset.core.glyphs[i].w) / f32(GLYPHSET_PAGE_SIZE),
						v1 + f32(glyphset.core.glyphs[i].h) / f32(GLYPHSET_PAGE_SIZE),
					}

					glyphset.core.glyphs[i].packed = true
					glyphset.core.baked_glyphs[glyph.glyph] = i

				// If it doesn't fit on the current page:
				// * Ensure that it fits on a page at all--without this check, we'll
				//   keep looping forever
				// * Trip the flag that tells our loop to generate another page and pack
				//   the remaining glyphs on it
				} else {
					if glyph.w > GLYPHSET_PAGE_SIZE || glyph.h > GLYPHSET_PAGE_SIZE {
						panic("Rasterized glyph is bigger than page size")
					}
					all_packed = false
				}
			}
		}
	}
}

// Flushes the glyphset to the GPU if it hasn't already been.
@(private)
glyphset_ensure_flushed :: #force_inline proc(
	glyphset: ^Glyphset,
	renderer: ^render.Renderer,
) {
	if !glyphset.core.flushed do glyphset_flush_bake(glyphset, renderer)
}

// Flushes bake results to the GPU.
@(private)
glyphset_flush_bake :: proc(
	glyphset: ^Glyphset,
	renderer: ^render.Renderer,
) {
	glyphset.core.flushed = true
	
	for _, i in glyphset.core.pages {
		render.texture_init(
			renderer,
			&glyphset.core.pages[i],
			GLYPHSET_PAGE_SIZE,
			GLYPHSET_PAGE_SIZE,
			render.Texture_Options{
				format = .Grayscale,
			},
		)
	}
	
	for _, baked_glyph in glyphset.core.baked_glyphs {
		glyph := glyphset.core.glyphs[baked_glyph]
		page_texture_addr := &glyphset.core.pages[glyph.page]
		
		lower := glyph.offset
		upper := glyph.offset + glyph.w * glyph.h

		render.texture_queue_copy(
			renderer,
			page_texture_addr,
			glyphset.core.bitmap[lower:upper],
			uint(glyph.x),
			uint(glyph.y),
			uint(glyph.w),
			uint(glyph.h),
		)
	}
}

@(private)
glyphset_glyph :: proc(
	glyphset: ^Glyphset,
	glyph: rune,
) -> Glyph {
	glyph_index := glyphset.core.baked_glyphs[glyph]
	return glyphset.core.glyphs[glyph_index]
}

// @(private)
glyphset_rasterize :: proc(
	glyphset: ^Glyphset,
	typeface: Typeface,
	glyph: rune,
	size: f32,
) {
	ftd_index := -1
	for font, i in glyphset.core.ftd_fonts {
		if font == typeface.core.font {
			ftd_index = i
			break
		}
	}
	if ftd_index < 0 {
		ftd_index = len(glyphset.core.ftd_fonts)
		append(&glyphset.core.ftd_fonts, typeface.core.font)
	}

	f := Rasterization_Face{
		font = typeface.core.font,
		size = size,
		index = c.uintptr_t(ftd_index),
	}
	glyphset.core.faces[f] = true

	bitmap: fontdue.GlyphBitmap
	metrics: fontdue.Metrics
	
	fontdue.font_metrics(typeface.core.font, fontdue.Char(glyph), size, &metrics)

	clen := len(glyphset.core.bitmap)
	resize(
		&glyphset.core.bitmap,
		len(glyphset.core.bitmap) + int(metrics.width * metrics.height),
	)
	
	bitmap.data = &glyphset.core.bitmap[clen]

	fontdue.font_rasterize(typeface.core.font, fontdue.Char(glyph), size, &bitmap)

	append(
		&glyphset.core.glyphs,
		Glyph{
			face = f,
			glyph = glyph,
			offset = clen,
			ftd_index = ftd_index,
			w = int(metrics.width),
			h = int(metrics.height),
		},
	)
}
