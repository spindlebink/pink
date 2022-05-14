package pink

import "core:log"
import "core:fmt"
import render "vk"

@(private)
graphics_load :: proc() {
	if ok := render.load(); !ok {
		log.fatalf("Could not load renderer!")
		for error in &render.error_buf {
			log.fatalf("\t%s", error)
		}
	}
}

@(private)
graphics_init :: proc() {
	if ok := render.init(ctx.window); !ok {
		log.fatalf("Could not initialize renderer!")
		for error in &render.error_buf {
			log.fatalf("\t%s", error)
		}
	}
}

@(private)
graphics_draw :: proc() {
	if ok := render.draw_frame(); !ok {
		log.fatalf("Could not draw frame!")
		for error in &render.error_buf {
			log.fatalf("\t%s", error)
		}
	}
}

@(private)
graphics_destroy :: proc() {
	render.destroy()
}

@(private)
graphics_trigger_resize :: proc() {
	render.trigger_resize()
}
