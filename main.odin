package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:time"
import "pink"

SIZE :: 40.0

on_update :: proc(delta: f64) {
}

on_fixed_update :: proc(delta: f64) {
}

on_draw :: proc() {
	pink.canvas_set_color(pink.PINK)
	
	for x := 0; x < 10; x += 1 {
		for y := 0; y < 5; y += 1 {
			pink.canvas_draw_rect(
				f32(x) * (SIZE * 1.1),
				f32(y) * (SIZE * 1.1),
				f32(SIZE),
				f32(SIZE),
			)
		}
	}
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

	pink.runtime_set_update_proc(on_update)
	pink.runtime_set_fixed_update_proc(on_fixed_update)
	pink.runtime_set_draw_proc(on_draw)
	
	if !pink.runtime_go() {
		pink.error_report_fatal(pink.runtime_error())
	}
}
