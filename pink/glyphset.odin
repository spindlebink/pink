package pink

import "core:fmt"
import "core:hash"
import "core:sort"
import "rect_atlas"
import "fontdue"
import "render"

GLYPHSET_PAGE_SIZE :: 2048

Glyphset :: struct {
	core: Glyphset_Core,
}

@(private)
Glyphset_Core :: struct {
	hash: u32,
	baked: bool,
	flushed: bool,
	baked_glyphs: map[rune]Glyph_Lookup,
	pages: [dynamic]render.Texture,
	bitmap: [dynamic]u8,
	glyphs: [dynamic]Glyph_Bitmap_Entry,
}

@(private)
Glyph_Lookup :: struct {
	page: int,
	index: int,
	uv: [4]f32,
}

@(private)
Glyph_Bitmap_Entry :: struct {
	packed: bool,
	glyph: rune,
	offset: int,
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
	
	atlas: rect_atlas.Atlas(Glyph_Bitmap_Entry)
	rect_atlas.atlas_clear(&atlas, GLYPHSET_PAGE_SIZE)
	defer rect_atlas.atlas_destroy(atlas)
	
	// Sort glyphs to improve atlas packing
	sorter := sort.Interface{
		len = proc(it: sort.Interface) -> int {
			bitmaps := (^[dynamic]Glyph_Bitmap_Entry)(it.collection)
			return len(bitmaps^)
		},
		less = proc(it: sort.Interface, i, j: int) -> bool {
			bitmaps := (^[dynamic]Glyph_Bitmap_Entry)(it.collection)
			return bitmaps[i].w * bitmaps[i].h > bitmaps[j].w * bitmaps[j].h
		},
		swap = proc(it: sort.Interface, i, j: int) {
			bitmaps := (^[dynamic]Glyph_Bitmap_Entry)(it.collection)
			bitmaps[i], bitmaps[j] = bitmaps[j], bitmaps[i]
		},
		collection = &glyphset.core.glyphs,
	}
	sort.sort(sorter)
	
	// Begin with one glyph page
	append(&glyphset.core.pages, render.Texture{})
	all_packed := false

	for !all_packed {
		all_packed = true
		
		// Cycle through all rasterized glyphs
		for glyph, i in glyphset.core.glyphs {
			if !glyph.packed {
				// Attempt to pack it into the current atlas (i.e. page)
				packed := rect_atlas.atlas_pack(
					&atlas,
					&glyphset.core.glyphs[i],
				)

				// If it fits into the current page, store a lookup for it in the baked
				// glyphs map so we can find it quickly
				if packed {
					u1, v1 := 
						f32(glyphset.core.glyphs[i].x) / f32(GLYPHSET_PAGE_SIZE),
						f32(glyphset.core.glyphs[i].y) / f32(GLYPHSET_PAGE_SIZE)
					lookup := Glyph_Lookup{
						page = len(glyphset.core.pages) - 1,
						index = i,
						uv = {
							u1,
							v1,
							u1 + f32(glyphset.core.glyphs[i].w) / f32(GLYPHSET_PAGE_SIZE),
							v1 + f32(glyphset.core.glyphs[i].h) / f32(GLYPHSET_PAGE_SIZE),
						},
					}

					glyphset.core.glyphs[i].packed = true
					glyphset.core.baked_glyphs[glyph.glyph] = lookup

					// fmt.println(glyph.glyph, "goes on page", lookup.page, "at", lookup.uv)
				} else {
					if glyph.w > GLYPHSET_PAGE_SIZE || glyph.h > GLYPHSET_PAGE_SIZE {
						panic("Rasterized glyph is bigger than page size")
					}
					all_packed = false
				}
			}
		}

		// If at least one couldn't fit, add a new page and we'll cycle back around
		if !all_packed {
			append(&glyphset.core.pages, render.Texture{})
			rect_atlas.atlas_clear(&atlas, GLYPHSET_PAGE_SIZE)
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
		page_texture_addr := &glyphset.core.pages[baked_glyph.page]
		glyph := glyphset.core.glyphs[baked_glyph.index]
		
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

glyphset_glyph_size :: proc(
	glyphset: ^Glyphset,
	baked_glyph: Glyph_Lookup,
) -> (int, int) {
	glyph := glyphset.core.glyphs[baked_glyph.index]
	return glyph.w, glyph.h
}

// @(private)
glyphset_rasterize :: proc(
	glyphset: ^Glyphset,
	typeface: Typeface,
	glyph: rune,
	size: f32,
) {
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
		Glyph_Bitmap_Entry{
			glyph = glyph,
			offset = clen,
			w = int(metrics.width),
			h = int(metrics.height),
		},
	)
}
