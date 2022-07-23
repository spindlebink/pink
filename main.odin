package main

import "core:fmt"
import "core:mem"
import "core:image"
import "core:image/png"
import "core:time"
import "pink"
import "pink/app"
import "pink/canvas"

ctx: Context

Vertex :: struct {
	position: [2]f32,
	color: [3]f32,
}
Context :: struct {}

on_draw :: proc() {
	canvas.draw_rect(pink.Transform{
		rect = {0, 0, 100, 100}
	})
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

	app.hooks.on_draw = on_draw
	
	conf := app.DEFAULT_CONFIG
	conf.framerate_cap = 60.0
	
	app.conf(conf)
	app.load()
	app.run()
	app.exit()
}
