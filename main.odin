package main

import "core:fmt"
import "core:mem"
import "pink"

ctx: Context

Context :: struct {
	program: pink.Program,
	
	dosis: pink.Typeface,
	moon: pink.Typeface,
	glyphset: pink.Glyphset,
	layout: pink.Glyphset_Layout,
}

on_load :: proc() {
	ctx.moon = pink.typeface_create_from_data(
		#load("resources/RubikMoonrocks-Regular.ttf"),
		pink.Typeface_Load_Options{
			scale = 128.0,
		}
	)
	ctx.dosis = pink.typeface_create_from_data(
		#load("resources/Dosis-Regular.ttf"),
		pink.Typeface_Load_Options{
			scale = 128.0,
		}
	)
	
	for r, i in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!'," {
		pink.glyphset_rasterize(
			&ctx.glyphset,
			// Uppercase = moon, everything else = dosis
			i > 25 ? ctx.dosis : ctx.moon,
			r,
			128.0,
		)
	}

	pink.glyphset_bake(&ctx.glyphset)
	pink.glyphset_layout_init(
		&ctx.layout,
		&ctx.glyphset,
	)
	pink.glyphset_layout_append(&ctx.layout, "Waddle Dee Waddle Doo")
}

on_draw :: proc() {
	pink.canvas_draw_text(
		&ctx.program.canvas,
		&ctx.layout,
		100,
		100,
	)
}

on_exit :: proc() {
	pink.typeface_destroy(ctx.moon)
	pink.typeface_destroy(ctx.dosis)
	pink.glyphset_destroy(ctx.glyphset)
	pink.glyphset_layout_destroy(ctx.layout)
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
	ctx.program.hooks.on_draw = on_draw
	ctx.program.hooks.on_exit = on_exit
	
	pink.program_load(&ctx.program)
	pink.program_run(&ctx.program)
	pink.program_exit(&ctx.program)
}
