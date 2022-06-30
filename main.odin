package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:time"
import "pink"

on_draw :: proc() {
	pink.graphics_set_color_rgba(0.8392, 0.3922, 0.5176)
	pink.graphics_draw_rectangle(10, 10, f32(pink.window_width() - 20), f32(pink.window_height() - 20))
}

main :: proc() {
	tracker: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracker, context.allocator)
	defer mem.tracking_allocator_destroy(&tracker)
	context.allocator = mem.tracking_allocator(&tracker)
	defer if len(tracker.allocation_map) > 0 {
		fmt.eprintln()
		for _, v in tracker.allocation_map {
			fmt.eprintf("%v - leaked %v bytes\n", v.location, v.size)
		}
	}

	pink.on_draw(on_draw)

	pink.go()
}
