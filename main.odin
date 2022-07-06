package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:time"
import "pink"

game_state: Game_State

Game_State :: struct {
	program: pink.Program,
	kenney_img: pink.Image,
	rect_rotation: f32,
}

RECTS_X :: 10
RECTS_Y :: 10
RECTS_MARGIN :: 10
ROTATION_SPEED: f32 = 0.0002

on_update :: proc(delta: f64) {
	game_state.rect_rotation += f32(delta) * ROTATION_SPEED
}

on_draw :: proc() {
	pink.canvas_set_color(
		&game_state.program.canvas,
		pink.Color{1.0, 0.65, 0.65, 1.0},
	)

	pink.canvas_draw_rect(
		&game_state.program.canvas,
		f32(game_state.program.window.width) * 0.5,
		f32(game_state.program.window.height) * 0.5,
		f32(game_state.program.window.width) * 0.5 - 10.0,
		f32(game_state.program.window.height) * 0.5 - 10.0,
		0.0,
	)
	
	pink.canvas_set_color(
		&game_state.program.canvas,
		pink.Color{
			pink.PINK_PINK.r,
			pink.PINK_PINK.g,
			pink.PINK_PINK.b,
			0.5,
		},
	)

	w := f32(game_state.program.window.width) / f32(RECTS_X)
	h := f32(game_state.program.window.height) / f32(RECTS_Y)
	rw := w - f32(RECTS_MARGIN)
	rh := h - f32(RECTS_MARGIN)

	for x := 0; x < RECTS_X; x += 1 {
		px := w * f32(x) + f32(RECTS_MARGIN) * 0.5
		for y := 0; y < RECTS_Y; y += 1 {
			py := h * f32(y) + f32(RECTS_MARGIN) * 0.5

			if (x + y) % 2 == 0 {
				pink.canvas_draw_rect(
					&game_state.program.canvas,
					px, py,
					rw, rh,
					game_state.rect_rotation + px * 0.1 + py * 0.1,
				)
			} else {
				pink.canvas_draw_image(
					&game_state.program.canvas,
					&game_state.kenney_img,
					px, py,
					rw, rh,
				)
			}
		}
	}
}

on_exit :: proc() {
	pink.image_destroy(&game_state.kenney_img)
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

	game_state.program.hooks.on_update = on_update
	game_state.program.hooks.on_draw = on_draw
	game_state.program.hooks.on_exit = on_exit
	game_state.kenney_img = pink.image_create(#load("kenney16.png"))

	pink.program_load(&game_state.program)
	pink.program_run(&game_state.program)
	pink.program_exit(&game_state.program)
}
