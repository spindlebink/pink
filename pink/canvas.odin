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
	
	win_w, win_h := f32(runtime_window_width()), f32(runtime_window_height())
	scaled_x, scaled_y := render_pos_from_window_pos(x + w * 0.5, y + h * 0.5)
	scaled_w, scaled_h := w / win_w, h / win_h
	
	append(&prim_inst_data, Canvas_Primitive_Instance{
		translation = {scaled_x, scaled_y},
		scale = {scaled_w, scaled_h},
		rotation = 0.0,
		modulation = cast([4]f32) draw_state.color,
	})
	canvas_append_draw_item(.Rect_Primitive)
}

