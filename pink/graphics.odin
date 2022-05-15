package pink

import "core:fmt"
import render "vk"

@(private)
graphics_load :: proc() {
	if response := render.load(); response != .OK {
		fmt.eprintf("Error while loading renderer: %v\n", response)
	}
}

@(private)
graphics_init :: proc() {
	if response := render.init(ctx.window); response != .OK {
		fmt.eprintf("Error while initializing renderer: %v\n", response)
	}
}

@(private)
graphics_draw :: proc() {
	if response := render.draw(); response != .OK {
		fmt.eprintf("Error while drawing: %v\n", response)
	}
}

@(private)
graphics_destroy :: proc() {
	if response := render.destroy(); response != .OK {
		fmt.eprintf("Error while destroying renderer: %v\n", response)
	}
}

@(private)
graphics_handle_resize :: proc() {
	if response := render.handle_resize(); response != .OK {
		fmt.eprintf("Error while handling resize: %v\n", response)
	}
}
