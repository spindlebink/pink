package pink_wgpu

import sdl "vendor:sdl2"

Response :: enum {
	OK,
}

load :: proc() -> Response {
	return .OK
}

init :: proc(window: ^sdl.Window) -> Response {
	return .OK
}

draw :: proc() -> Response {
	return .OK
}

destroy :: proc() -> Response {
	return .OK
}

handle_resize :: proc() -> Response {
	return .OK
}

