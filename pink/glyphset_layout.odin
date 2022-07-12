package pink

import "core:strings"
import "core:fmt"
import "fontdue"

Glyphset_Layout :: struct {
	core: Glyphset_Layout_Core,
}

Glyphset_Layout_Align :: enum {
	Min,
	Mid,
	Max,
}

Glyphset_Layout_Options :: struct {
	width: f32,
	height: f32,
	h_align: Glyphset_Layout_Align,
	v_align: Glyphset_Layout_Align,
	ignore_hard_breaks: bool,
}

@(private)
Glyph_Position :: struct {
	glyph: Glyph,
	x: f32,
	y: f32,
}

@(private)
Glyphset_Layout_Core :: struct {
	glyphset: ^Glyphset,
	layout: fontdue.Layout,
	positions: [dynamic]Glyph_Position,
	updated: bool,
}

glyphset_layout_init :: proc(
	layout: ^Glyphset_Layout,
	glyphset: ^Glyphset,
	options := Glyphset_Layout_Options{},
) {
	layout.core.glyphset = glyphset
	
	layout.core.layout = fontdue.layout_new(.PositiveYDown)
	layout_settings := fontdue.LayoutSettings{
		x = 0.0,
		y = 0.0,
		constrain_width = options.width > 0.0,
		constrain_height = options.height > 0.0,
		max_width = options.width,
		max_height = options.height,
		horizontal_align = options.h_align == .Min ? .Left : options.h_align == .Max ? .Right : .Center,
		vertical_align = options.v_align == .Min ? .Top : options.v_align == .Max ? .Bottom : .Top,
		wrap_style = .Word,
		wrap_hard_breaks = !options.ignore_hard_breaks,
	}
	
	fontdue.layout_reset(layout.core.layout, layout_settings)
}

glyphset_layout_destroy :: proc(
	layout: Glyphset_Layout,
) {
	delete(layout.core.positions)
	fontdue.layout_free(layout.core.layout)
}

glyphset_layout_append :: proc(
	layout: ^Glyphset_Layout,
	text: string,
) {
	last_segment := 0
	last_face := Rasterization_Face{}
	layout.core.updated = false

	for g, i in text {
		glyph := glyphset_glyph(layout.core.glyphset, g)
		push_segment := i == len(text) - 1
		
		if glyph.face != last_face && g != ' ' {
			if last_segment != i {
				push_segment = true
			} else {
				last_face = glyph.face
			}
		}

		if push_segment {
			upper := i
			if i == len(text) - 1 do upper += 1
			substr := text[last_segment:upper]
			glyphset_layout_append_seg(layout, substr, last_face)
			last_segment = i
			last_face = glyph.face
		}
	}
}

@(private)
glyphset_layout_update :: proc(
	layout: ^Glyphset_Layout,
) {
	layout.core.updated = true
	
	layout_glyphs := make(
		[]fontdue.GlyphPosition,
		fontdue.layout_glyphs_count(layout.core.layout),
	); defer delete(layout_glyphs)

	fontdue.layout_glyphs(
		layout.core.layout,
		([^]fontdue.GlyphPosition)(raw_data(layout_glyphs)),
	)

	reserve(&layout.core.positions,	len(layout_glyphs))
	for pos in layout_glyphs {
		if !fontdue.char_data_rasterize(pos.char_data) do continue
		glyph := glyphset_glyph(layout.core.glyphset, rune(pos.parent))
		append(
			&layout.core.positions,
			Glyph_Position{
				glyph = glyph,
				x = pos.x,
				y = pos.y,
			},
		)
	}
}

@(private)
glyphset_layout_append_seg :: proc(
	layout: ^Glyphset_Layout,
	slice: string,
	face: Rasterization_Face,
) {
	s := strings.clone(slice); defer delete(s)
	text_style := fontdue.TextStyle{
		text = cstring(raw_data(s)),
		px = face.size,
		font_index = face.index,
	}
	fontdue.layout_append(
		layout.core.layout,
		raw_data(layout.core.glyphset.core.ftd_fonts),
		len(layout.core.glyphset.core.ftd_fonts),
		text_style,
	)
}

glyphset_layout_clear :: proc(
	layout: ^Glyphset_Layout,
) {
	
}
