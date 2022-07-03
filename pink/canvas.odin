package pink

// ************************************************************************** //
// Type Definitions
// ************************************************************************** //

Canvas_Error_Type :: enum {
	None,
	Init_Failed,
}

Canvas_Error :: Error(Canvas_Error_Type)

// ************************************************************************** //
// Procedures
// ************************************************************************** //

// Returns `true` if the canvas system has encountered no errors or if any
// errors have been marked as handled.
canvas_ok :: proc() -> bool {
	return canvas_state.error.type == .None
}

// Returns any error the canvas system last experienced.
canvas_error :: proc() -> Canvas_Error {
	return canvas_state.error
}

// Marks any error the canvas system has received as handled.
canvas_clear_error :: proc() {
	canvas_state.error.type = .None
}

// Sets the current drawing color.
canvas_set_color :: proc(color: Color) {
	canvas_state.draw_state.color = color
}

// Draws a rectangle using the current draw state.
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
