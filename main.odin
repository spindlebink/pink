package main

import "core:fmt"
import "core:mem"
import "pink"

ctx: Context

Context :: struct {
	program: pink.Program,
	
	dosis: pink.Typeface,
}

on_load :: proc() {
	ctx.dosis = pink.typeface_create(#load("res/Dosis-Regular.ttf"))
	
	pink._typeface_rasterize(
		&ctx.dosis,
		'P',
		60.0,
	)
	
	for y := 0; y < ctx.dosis._bitmap_height; y += 1 {
		for x := 0; x < ctx.dosis._bitmap_width; x += 1 {
			bit := ctx.dosis._bitmap[y * ctx.dosis._bitmap_width + x]
			fmt.print(rune(
				' ' if bit < 16 else
				'░' if bit < 32 else
				'▒' if bit < 64 else
				'▓' if bit < 128 else
				'█',
			))
		}
		fmt.println()
	}
}

on_exit :: proc() {
	pink.typeface_destroy(ctx.dosis)
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

	ctx.program.hooks.on_load = on_load
	ctx.program.hooks.on_exit = on_exit
	
	pink.program_load(&ctx.program)
	pink.program_run(&ctx.program)
	pink.program_exit(&ctx.program)
}
