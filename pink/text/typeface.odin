package pk_text

import "core:c"
import "fontdue"

Typeface :: struct {
	_ftd_font: fontdue.Font,
}

Options :: struct {
	collection_index: uint,
	scale: f32,
}

typeface_load_from_bytes :: proc(data: []byte, options := Options{scale = 40.0}) -> Typeface {
	return Typeface{
		_ftd_font = fontdue.font_new_from_bytes(
			raw_data(data),
			c.size_t(len(data)),
			fontdue.FontSettings{
				collection_index = c.uint32_t(options.collection_index),
				scale = options.scale,
			},
		),
	}
}

typeface_destroy :: proc(typeface: Typeface) {
	fontdue.font_free(typeface._ftd_font)
}
