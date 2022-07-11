package pink

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
		_canvas_prim_inst_from_transform(canvas, transform),
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
			primitive_instance = _canvas_prim_inst_from_transform(canvas, transform),
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
			primitive_instance = _canvas_prim_inst_from_transform(canvas, transform),
			uv_extents = {uv_x, uv_y, uv_x + f32(slice.w) / fw, uv_y + f32(slice.h) / fh},
		},
	)
	canvas_append_cmd(canvas, Canvas_Draw_Slice_Cmd{image})
}
