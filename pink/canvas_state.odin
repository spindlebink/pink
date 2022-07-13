package pink

@(private)
CANVAS_EMPTY_STATE :: Canvas_Draw_State{
	color = {1.0, 1.0, 1.0, 1.0},
	translation = {0.0, 0.0},
	rotation = 0.0,
}

Canvas_State_Type :: enum {
	All,
	Transform,
	Style,
}

@(private)
Canvas_State_Memo :: struct {
	state: Canvas_Draw_State,
	type: Canvas_State_Type,
}

canvas_push :: proc(
	canvas: ^Canvas,
	state_type := Canvas_State_Type.All,
) {
	if canvas.core.state_head >= CANVAS_STATE_STACK_SIZE {
		panic("Canvas state stack overflow")
	}
	canvas.core.state_stack[canvas.core.state_head] = Canvas_State_Memo{
		state = canvas.draw_state,
		type = state_type,
	}
	canvas.core.state_head += 1
}

canvas_pop :: proc(
	canvas: ^Canvas,
) {
	if canvas.core.state_head == 0 {
		canvas.draw_state = CANVAS_EMPTY_STATE
	} else {
		canvas.core.state_head -= 1
		memo := canvas.core.state_stack[canvas.core.state_head]
		switch memo.type {
		case .All:
			canvas.draw_state = memo.state
		case .Transform:
			canvas.translation = memo.state.translation
			// No rotation support yet
			// canvas.translation, canvas.rotation =
			// 	memo.state.translation, memo.state.rotation
		case .Style:
			canvas.color = memo.state.color
		}
	}
}

canvas_set_color :: #force_inline proc(
	canvas: ^Canvas,
	color: Color,
) {
	canvas.draw_state.color = color
}

canvas_set_color_rgba :: #force_inline proc(
	canvas: ^Canvas,
	r, g, b, a: f32,
) {
	canvas.draw_state.color.r = r
	canvas.draw_state.color.g = g
	canvas.draw_state.color.b = b
	canvas.draw_state.color.a = a
}

canvas_set_color_rgb :: #force_inline proc(
	canvas: ^Canvas,
	r, g, b: f32,
) {
	canvas_set_color_rgba(canvas, r, g, b, canvas.draw_state.color.a)
}

canvas_translate :: #force_inline proc(
	canvas: ^Canvas,
	x, y: f32,
) {
	canvas.translation[0] += x
	canvas.translation[1] += y
}
