package pink

import "core:c"
import "core:fmt"
import sdl "vendor:sdl2"

// Window information.
Window :: struct {
	title: string,
	width: uint,
	height: uint,
	minimized: bool,

	_sdl_handle: ^sdl.Window,
	_sdl_flags: sdl.WindowFlags,
}

// Initializes the game window.
@(private)
window_init :: proc(
	window: ^Window,
) {
	when ODIN_OS == .Linux {
		// TODO: do we actually need this? WGPU initializes regardless. More research.
		window._sdl_flags += {.VULKAN}
	}
	
	window._sdl_flags += {.RESIZABLE}
	window._sdl_handle = sdl.CreateWindow(
		cast(cstring) raw_data(window.title),
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		i32(window.width),
		i32(window.height),
		window._sdl_flags,
	)
	
	if window._sdl_handle == nil { panic("Failed to create window") }
	window_fetch_info(window)
}

// Destroys the game window.
@(private)
window_destroy :: proc(
	window: ^Window,
) {
	delete(window.title)
	sdl.DestroyWindow(window._sdl_handle)
}

// Updates window information.
@(private)
window_fetch_info :: proc(
	window: ^Window,
) {
	w, h: i32
	window._sdl_flags =
		transmute(sdl.WindowFlags)sdl.GetWindowFlags(window._sdl_handle)
	sdl.GetWindowSize(window._sdl_handle, &w, &h)
	window.width, window.height = uint(w), uint(h)
	window.minimized = .MINIMIZED in window._sdl_flags
}
