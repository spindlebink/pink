package pk_text

import "core:c"
import "core:fmt"
import "core:hash"
import "core:sort"
import "../render"
import "fontdue"
import "rect_atlas"

GLYPHSET_PAGE_SIZE :: #config(PK_TEXT_GLYPHSET_PAGE_SIZE, 2048)

Glyphset :: struct {
	_glyph_map: map[rune]Glyph,
	_pages: [dynamic]render.Texture,
	_bitmap: [dynamic]byte,
}

@(private)
Glyph :: struct {
	page_index, bm_index: uint,
	x, y, w, h: int,
}

glyphset_destroy :: proc(glyphset: Glyphset) {
	for page in glyphset._pages {
		render.texture_destroy(page)
	}
	delete(glyphset._pages)
	delete(glyphset._glyph_map)
	delete(glyphset._bitmap)
}

glyphset_add :: proc(glyphset: ^Glyphset, typeface: Typeface, size: f32, chars: string) {
	bitmap: fontdue.GlyphBitmap
	metrics: fontdue.Metrics
	
	// For every specified character
	char_data: fontdue.CharacterData
	for glyph_char in chars {
		if glyph_char in glyphset._glyph_map { panic("cannot add duplicate glyph to glyphset") }
		
		fontdue.char_data_classify(fontdue.Char(glyph_char), 1, &char_data)
		if !fontdue.char_data_rasterize(char_data) { continue }
		
		// Rasterize that character in the provided typeface and size, ensuring that
		// our staging bitmap is big enough to hold the glyph's data first
		fontdue.font_metrics(typeface._ftd_font, fontdue.Char(glyph_char), size, &metrics)

		orig_len := len(glyphset._bitmap)
		resize(&glyphset._bitmap, orig_len + int(metrics.width * metrics.height))
		// Write the new bitmap's data at the end of the bitmap's current contents.
		bitmap.data = &glyphset._bitmap[orig_len]
		// We build a 1D array of all bitmap data and store each glyph's starting
		// index into that data. This allows us to sort glyphs before baking instead
		// of packing them right now, which leads to much tighter packing and space
		// savings on the GPU, which *then* leads to better batching
		fontdue.font_rasterize(typeface._ftd_font, fontdue.Char(glyph_char), size, &bitmap)
		glyphset._glyph_map[glyph_char] = Glyph{
			bm_index = uint(orig_len),
			page_index = 0, // set later on when we bake
			x = 0, y = 0,   // set later on when we bake
			w = int(metrics.width),
			h = int(metrics.height),
		}
	}
}

glyphset_bake :: proc(glyphset: ^Glyphset) {
	all_glyphs: [dynamic]^Glyph; defer delete(all_glyphs)
	reserve(&all_glyphs, len(glyphset._glyph_map))
	for glyph_char in glyphset._glyph_map {
		append(&all_glyphs, &glyphset._glyph_map[glyph_char])
	}

	// Sort glyphs to improve atlas packing
	sort.sort(sort.Interface{
		len = proc(it: sort.Interface) -> int {
			glyphs := (^[dynamic]^Glyph)(it.collection)
			return len(glyphs^)
		},
		less = proc(it: sort.Interface, i, j: int) -> bool {
			glyphs := (^[dynamic]^Glyph)(it.collection)
			return glyphs[i].w * glyphs[i].h < glyphs[j].w * glyphs[j].h
		},
		swap = proc(it: sort.Interface, i, j: int) {
			glyphs := (^[dynamic]^Glyph)(it.collection)
			bj, bi := glyphs[j], glyphs[i]
			glyphs[i], glyphs[j] = bj, bi
		},
		collection = &all_glyphs,
	})

	// Pack glyphs
	atlas: rect_atlas.Atlas(Glyph); defer rect_atlas.atlas_destroy(atlas)

	for len(all_glyphs) > 0 {
	 	rect_atlas.atlas_clear(&atlas, GLYPHSET_PAGE_SIZE)
		page := render.Texture{
			width = GLYPHSET_PAGE_SIZE,
			height = GLYPHSET_PAGE_SIZE,
		}
		render.texture_init(&page, render.Texture_Options{
			format = .Gray,
		})
		append(&glyphset._pages, page)
		
		for i := len(all_glyphs) - 1; i >= 0; i -= 1 {
			if all_glyphs[i].w > GLYPHSET_PAGE_SIZE || all_glyphs[i].h > GLYPHSET_PAGE_SIZE {
				panic("glyph exceeds page size")
			}
			could_pack := rect_atlas.atlas_pack(&atlas, all_glyphs[i])
			if could_pack {
				glyph := all_glyphs[i]
				ordered_remove(&all_glyphs, i) // TODO: this won't be very efficient for
				                               // large character sets--profile and
				                               // determine if we should figure out an
				                               // alternate way
				glyph.page_index = len(glyphset._pages) - 1
				render.texture_write(
					&glyphset._pages[len(glyphset._pages) - 1],
					glyphset._bitmap[glyph.bm_index:glyph.bm_index + uint(glyph.w * glyph.h)],
					uint(glyph.x),
					uint(glyph.y),
					uint(glyph.w),
					uint(glyph.h),
				)
			}
		}
	}
}
