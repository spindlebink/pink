package pink

import "core:c"
import "fontdue"

// Represents a single typeface.
Typeface :: struct {
	core: Typeface_Core,
}

Typeface_Core :: struct {
	font: fontdue.Font,
}

// Options used when loading a typeface from data.
Typeface_Load_Options :: struct {
	collection_index: int,
	scale: f32,
}

// Creates a new typeface from font data. You can easily retrieve font data
// using Odin's `#load` or via any other method which returns a byte slice from
// a file.
typeface_create_from_data :: proc(
	data: []u8,
	options := Typeface_Load_Options{
		collection_index = 0,
		scale = 1.0,
	},
) -> Typeface {
	typeface := Typeface{
		core = Typeface_Core{
			font = fontdue.font_new_from_bytes(
				raw_data(data),
				c.size_t(len(data)),
				fontdue.FontSettings{
					collection_index = c.uint32_t(options.collection_index),
					scale = options.scale,
				},
			),
		},
	}
	
	return typeface
}

// Destroys a typeface.
typeface_destroy :: proc(
	typeface: Typeface,
) {
	// delete(typeface.core.bitmap)
	fontdue.font_free(typeface.core.font)
}

// Internal. Rasterizes a given glyph, storing 
// _typeface_rasterize :: proc(
// 	typeface: ^Typeface,
// 	glyph: rune,
// 	size: f32,
// ) {
// 	bitmap: fontdue.GlyphBitmap
// 	metrics: fontdue.Metrics

// 	fontdue.font_metrics(typeface.core.font, fontdue.Char(glyph), size, &metrics)
// 	resize(&typeface._bitmap, int(metrics.width * metrics.height))
	
// 	bitmap.data = cast([^]c.uint8_t)raw_data(typeface.core.bitmap)
	
// 	fontdue.font_rasterize(typeface.core.font, fontdue.Char(glyph), size, &bitmap)
// 	typeface.core.bitmap_width = int(bitmap.metrics.width)
// 	typeface.core.bitmap_height = int(bitmap.metrics.height)
// }
