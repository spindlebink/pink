package pink

// ************************************************************************** //
// Type Definitions
// ************************************************************************** //

Canvas_Error :: enum {
	None,
	Init_Failed,
}

// ************************************************************************** //
// Procedures
// ************************************************************************** //

// Sets the current drawing color.
canvas_set_color :: proc(color: Color) {
	canvas_state.draw_state.color = color
}

// Draws a rectangle.
canvas_draw_rect :: proc(x, y, w, h: f32) {
	using canvas_state
	
	sx, sy, sw, sh := render_rect_from_window_rect(
		x + w * 0.5,
		y + h * 0.5,
		w,
		h,
	)
	
	append(&prim_inst_data, Canvas_Primitive_Instance{
		translation = {sx, sy},
		scale = {sw, sh},
		rotation = 0.0,
		modulation = cast([4]f32) draw_state.color,
	})

	canvas_append_draw_item(Canvas_Draw_Primitive_Data{.Rect})
}

// Draws an image.
canvas_draw_img :: proc(image: ^Image, x, y, w, h: f32) {
	using canvas_state
	
	sx, sy, sw, sh := render_rect_from_window_rect(
		x + w * 0.5,
		y + h * 0.5,
		w,
		h,
	)
	
	append(&img_inst_data, Canvas_Primitive_Instance{
		translation = {sx, sy},
		scale = {sw, sh},
		rotation = 0.0,
		modulation = cast([4]f32) draw_state.color,
	})
	canvas_append_draw_item(Canvas_Draw_Image_Data{image})
}
