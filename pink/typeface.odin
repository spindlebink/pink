package pink

import "core:c"
import "fontdue"

// Represents a single typeface.
Typeface :: struct {
	core: Typeface_Core,
}

// Options used when loading a typeface from data.
Typeface_Load_Options :: struct {
	collection_index: int,
	scale: f32,
}

@(private)
Typeface_Core :: struct {
	font: fontdue.Font,
}

// Creates a new typeface from font data. You can easily retrieve font data
// using Odin's `#load` or via any other method which returns a byte slice from
// a file.
typeface_create_from_data :: proc(
	data: []u8,
	options := Typeface_Load_Options{
		collection_index = 0,
		scale = 40.0,
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
	fontdue.font_free(typeface.core.font)
}
