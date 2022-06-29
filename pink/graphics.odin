package pink

import "core:math/linalg"

Color :: linalg.Vector4f32

graphics_draw_rectangle :: proc(x, y, w, h: f32) {
	draw_command_add_rectangle(x, y, w, h)
}

graphics_set_color_rgb :: proc(r, g, b: f32) {
	graphics_state.draw_state.color[0] = r
	graphics_state.draw_state.color[1] = g
	graphics_state.draw_state.color[2] = b
}

graphics_set_color :: proc(color: Color) {
	graphics_state.draw_state.color = color
}
