package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:time"
import "pink"

Game_State :: struct {
	// kenney_img: pink.Image,
}

game_state: Game_State

on_update :: proc(delta: f64) {
}

on_draw :: proc() {
	// pink.canvas_draw_img(
	// 	&game_state.kenney_img,
	// 	10, 10,
	// 	f32(game_state.kenney_img.width), f32(game_state.kenney_img.height),
	// )
}

on_exit :: proc() {
	// pink.image_destroy(&game_state.kenney_img)
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

	program: pink.Program

	pink.program_load(&program)
	pink.program_run(&program)
	pink.program_exit(&program)
	
	// game_state.kenney_img = pink.image_load_png(#load("kenney16.png"))
}
