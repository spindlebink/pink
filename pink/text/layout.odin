package pk_text

import "core:fmt"
import "fontdue"
import pk ".."
import "../canvas"

Layout :: struct {
	using drawable: canvas.Drawable,
	_draw_glyphset: ^Glyphset,
	_ftd_layout: fontdue.Layout,
	_glyphs: [dynamic]fontdue.GlyphPosition,
}

Align :: enum {
	Min,
	Mid,
	Max,
}

Layout_Options :: struct {
	width: f32,
	height: f32,
	h_align: Align,
	v_align: Align,
	ignore_hard_breaks: bool,
}

@(private)
layout_draw :: proc(layout_ptr: rawptr, transform: pk.Transform) {
	layout := cast(^Layout)layout_ptr
	glyphset := layout._draw_glyphset
	if glyphset == nil {
		panic("cannot draw layout when glyphset has not been bound")
	}
	
	char_data: fontdue.CharacterData
	for glyph in layout._glyphs {
		gchar := rune(glyph.parent)

		fontdue.char_data_classify(glyph.parent, 1, &char_data)
		if !fontdue.char_data_rasterize(char_data) {
			continue
		}

		if gd, found := glyphset._glyph_map[gchar]; found {
			canvas.draw_image(
				glyphset._pages[gd.page_index],
				pk.Transform{
					rect = {
						x = f32(glyph.x),
						y = f32(glyph.y),
						w = f32(glyph.width),
						h = f32(glyph.height),
					},
				},
				pk.Recti{gd.x, gd.y, gd.w, gd.h},
			)
		} else {
			fmt.eprintln("missing glyph from glyphset:", gchar)
		}
	}
}

layout_init :: proc(layout: ^Layout, options := Layout_Options{}) {
	layout.drawable.draw_data = layout
	layout.drawable.draw = layout_draw
	
	layout._ftd_layout = fontdue.layout_new(.PositiveYDown)
	
	fontdue.layout_reset(layout._ftd_layout, fontdue.LayoutSettings{
		x = 0.0,
		y = 0.0,
		constrain_width = options.width > 0,
		constrain_height = options.height > 0,
		max_width = options.width,
		max_height = options.height,
		horizontal_align = options.h_align == .Min ? .Left : options.h_align == .Max ? .Right : .Center,
		vertical_align = options.v_align == .Min ? .Top : options.v_align == .Max ? .Bottom : .Top,
		wrap_style = .Word,
		wrap_hard_breaks = !options.ignore_hard_breaks,
	})
}

layout_destroy :: proc(layout: Layout) {
	fontdue.layout_free(layout._ftd_layout)
	delete(layout._glyphs)
}

layout_add :: proc(layout: ^Layout, typeface: Typeface, size: f32, text: string) {
	fontdue.layout_append(
		layout._ftd_layout,
		raw_data([]fontdue.Font{typeface._ftd_font}),
		1,
		fontdue.TextStyle{
			text = cstring(raw_data(text)),
			px = size,
			font_index = 0,
		},
	)
}

layout_bind_drawing_glyphset :: proc(layout: ^Layout, glyphset: ^Glyphset) {
	layout._draw_glyphset = glyphset
}

layout_update :: proc(layout: ^Layout) {
	resize(&layout._glyphs, int(fontdue.layout_glyphs_count(layout._ftd_layout)))
	fontdue.layout_glyphs(layout._ftd_layout, raw_data(layout._glyphs))
}
