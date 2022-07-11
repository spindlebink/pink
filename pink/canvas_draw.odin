package pink

import "core:reflect"
import "render/wgpu"

canvas_set_color :: proc(
	canvas: ^Canvas,
	color: Color,
) {
	canvas.draw_state.color = color
}

canvas_draw_rect :: proc(
	canvas: ^Canvas,
	x, y, width, height: f32,
	rotation: f32 = 0.0,
) {
	append(
		&canvas.core.primitive_instances.data,
		Canvas_Primitive_Instance{
			translation = {x + width * 0.5, -y - height * 0.5},
			scale = {width * 0.5, height * 0.5},
			rotation = rotation,
			color = ([4]f32)(canvas.draw_state.color),
		},
	)
	_canvas_append_command(
		canvas,
		Canvas_Command{
			data = Canvas_Draw_Primitive_Command{
				type = .Rect,
			},
			times = 1,
		},
	)
}

canvas_draw_image :: proc(
	canvas: ^Canvas,
	image: ^Image,
	x, y: f32,
	width: f32 = -1.0,
	height: f32 = -1.0,
	rotation: f32 = 0.0,
) {
	width, height := width, height
	if width < 0 do width = f32(image.width)
	if height < 0 do height = f32(image.height)
	append(
		&canvas.core.image_instances.data,
		Canvas_Image_Instance{
			primitive_instance = Canvas_Primitive_Instance{
				translation = {x + width * 0.5, -y - height * 0.5},
				scale = {width * 0.5, height * 0.5},
				rotation = rotation,
				color = ([4]f32)(canvas.draw_state.color),
			},
		},
	)
	_canvas_append_command(
		canvas,
		Canvas_Command{
			data = Canvas_Draw_Image_Command{
				image = image,
			},
			times = 1,
		},
	)
}

canvas_draw_slice :: proc(
	canvas: ^Canvas,
	image: ^Image,
	slice: Recti,
	x, y: f32,
	width: f32 = -1.0,
	height: f32 = -1.0,
	rotation: f32 = 0.0,
) {
	width, height := width, height
	if width < 0 do width = f32(slice.w)
	if height < 0 do height = f32(slice.h)
	
	fw, fh := f32(image.width), f32(image.height)
	uv_x := f32(slice.x) / fw
	uv_y := f32(slice.y) / fh
	
	append(
		&canvas.core.slice_instances.data,
		Canvas_Slice_Instance{
			primitive_instance = Canvas_Primitive_Instance{
				translation = {x + width * 0.5, -y - height * 0.5},
				scale = {width * 0.5, height * 0.5},
				rotation = rotation,
				color = ([4]f32)(canvas.draw_state.color),
			},
			uv_extents = {
				uv_x,
				uv_y,
				uv_x + f32(slice.w) / fw,
				uv_y + f32(slice.h) / fh,
			},
		},
	)
	_canvas_append_command(
		canvas,
		Canvas_Command{
			data = Canvas_Draw_Slice_Command{
				image = image,
			},
			times = 1,
		},
	)
}
