package pink

import "core:log"
import "core:fmt"
import render "vk"

@(private)
graphics_load :: proc() {
	if ok := render.load(); !ok {
		log.fatalf("Could not load renderer")
	}
}

@(private)
graphics_init :: proc() {
	if ok := render.init(ctx.window); !ok {
		log.fatalf("Could not initialize renderer")
	}
}

@(private)
graphics_destroy :: proc() {
	render.destroy()
}
