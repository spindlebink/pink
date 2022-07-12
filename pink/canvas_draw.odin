package pink

import "core:fmt"
import "core:reflect"
import "render"
import "render/wgpu"

canvas_set_color :: proc(
	canvas: ^Canvas,
	color: Color,
) {
	canvas.draw_state.color = color
}

canvas_draw_rect :: proc(
	canvas: ^Canvas,
	transform: Transform,
) {
	render.painter_append_inst(
		&canvas.core.prims,
		canvas_prim_inst_from_transform(
			transform,
			canvas.draw_state.color,
		),
	)
	canvas_append_cmd(canvas, Canvas_Draw_Primitive_Cmd{.Rect})
}

canvas_draw_image :: proc(
	canvas: ^Canvas,
	image: ^Image,
	transform: Transform,
) {
	transform := transform
	if transform.w <= 0 do transform.w = f32(image.width)
	if transform.h <= 0 do transform.h = f32(image.height)
	render.painter_append_inst(
		&canvas.core.imgs,
		Canvas_Image_Instance{
			primitive_instance = canvas_prim_inst_from_transform(
				transform,
				canvas.draw_state.color,
			),
		},
	)
	canvas_append_cmd(canvas, Canvas_Draw_Img_Cmd{image})
}

canvas_draw_slice :: proc(
	canvas: ^Canvas,
	image: ^Image,
	slice: Recti,
	transform: Transform,
) {
	transform := transform
	if transform.w <= 0 do transform.w = f32(slice.w)
	if transform.h <= 0 do transform.h = f32(slice.h)
	
	fw, fh := f32(image.width), f32(image.height)
	uv_x := f32(slice.x) / fw
	uv_y := f32(slice.y) / fh
	
	render.painter_append_inst(
		&canvas.core.slices,
		Canvas_Slice_Instance{
			primitive_instance = canvas_prim_inst_from_transform(
				transform,
				canvas.draw_state.color,
			),
			uv_extents = {uv_x, uv_y, uv_x + f32(slice.w) / fw, uv_y + f32(slice.h) / fh},
		},
	)
	canvas_append_cmd(canvas, Canvas_Draw_Slice_Cmd{image})
}

canvas_draw_text :: proc(
	canvas: ^Canvas,
	glyphset: ^Glyphset,
	text: string,
) {
	// for each letter, append a glyph data item and a glyph draw command
	// make sure page in glyph draw command corresponds to page in glyphset
	// they'll be batched correctly by canvas_flush
	
	left: f32 = 0
	
	for glyph in text {
		if glyph == ' ' {
			left += 16
			continue
		}
		
		glyph_lookup, ok := glyphset.core.baked_glyphs[glyph]
		if !ok do panic("Glyphset missing requested glyph")

		gwi, ghi := glyphset_glyph_size(glyphset, glyph_lookup)
		glyph_width, glyph_height := f32(gwi), f32(ghi)

		render.painter_append_inst(
			&canvas.core.glyphs,
			Canvas_Slice_Instance{
				primitive_instance = canvas_prim_inst_from_transform(
					Transform{
						{
							x = left,
							y = 0,
							w = glyph_width,
							h = glyph_height,
						},
						0,
					},
					canvas.draw_state.color,
				),
				uv_extents = glyph_lookup.uv,
			},
		)

		canvas_append_cmd(canvas, Canvas_Draw_Glyph_Cmd{glyphset, glyph_lookup.page})
		left += glyph_width
	}
}
