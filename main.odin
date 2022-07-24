package main

import "core:fmt"
import "core:mem"
import "core:time"
import "pink"
import "pink/canvas"
import "pink/image"

ctx: Context
img_test: image.Image

Vertex :: struct {
	position: [2]f32,
	color: [3]f32,
}
Context :: struct {}

on_draw :: proc() {
	for x: f32 = 0; x < 8; x += 1 {
		for y: f32 = 0; y < 8; y += 1 {
			canvas.draw_image(
				img_test,
				pink.Transform{
					rect = {
						x * 64 + f32(int(x + y) % 2) * 64,
						y * 64,
						64,
						64,
					},
				},
				pink.Recti{
					16, 16, 16, 16,
				},
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

	conf := pink.DEFAULT_CONFIG
	conf.framerate_cap = 60.0

	pink.conf(conf)
	pink.load()
	
	pink.hooks.on_draw = on_draw
	img_test = image.load_from_bytes(#load("resources/wut.png"), image.Options{
		mag_filter = .Nearest,
		min_filter = .Nearest,
	})
	
	pink.run()
	pink.exit()
}
