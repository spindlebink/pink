package main;

import "core:mem"
import "core:fmt"
import "pink"

on_load :: proc() {
}

on_update :: proc(dt: f64) {
}

on_draw :: proc() {
}

main :: proc() {
	// set up tracking allocator
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

	pink.init()
	
	pink.set_window_title("Test Window")
	pink.set_target_fps(60)
	pink.on_load(on_load)
	pink.on_update(on_update)
	
	pink.run()
	pink.exit()
}
