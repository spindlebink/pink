//+private
package pink

import "core:fmt"
import render "pink_wgpu"

graphics_load :: proc() {
	if response := render.load(); response != .OK {
		fmt.eprintf("Error while loading renderer: %v\n", response)
	}
}

graphics_init :: proc() {
	if response := render.init(ctx.window); response != .OK {
		fmt.eprintf("Error while initializing renderer: %v\n", response)
	}
}

graphics_draw :: proc() {
	if response := render.draw(); response != .OK {
		fmt.eprintf("Error while drawing: %v\n", response)
	}
}

graphics_destroy :: proc() {
	if response := render.destroy(); response != .OK {
		fmt.eprintf("Error while destroying renderer: %v\n", response)
	}
}

graphics_handle_resize :: proc() {
	if response := render.handle_resize(); response != .OK {
		fmt.eprintf("Error while handling resize: %v\n", response)
	}
}
