package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:time"
import "../pink"

RECT_SIZE :: 50.0
INSTANCES :: 200000
GRAVITY :: 0.2

Bun :: struct {
	x, y: f64,
	xv, yv: f64,
	color: pink.Color,
}

Game :: struct {
	buns: [INSTANCES]Bun,
}

game: Game

on_load :: proc() {
	using game
	
	x_range, y_range := f64(pink.runtime_window_width() - RECT_SIZE), f64(pink.runtime_window_height() - RECT_SIZE)

	for i := 0; i < INSTANCES; i += 1 {
		buns[i].color = pink.Color{
			rand.float32(),
			rand.float32(),
			rand.float32(),
			rand.float32(),
		}
		buns[i].x, buns[i].y = rand.float64() * x_range, rand.float64() * (y_range * 0.5)
		buns[i].xv = 1 if rand.float64() > 0.5 else -1
	}
}

on_update :: proc(timestep: f64) {
	using game

	x_range, y_range := f64(pink.runtime_window_width() - RECT_SIZE), f64(pink.runtime_window_height() - RECT_SIZE)

	for i := 0; i < INSTANCES; i += 1 {
		buns[i].yv += GRAVITY
		buns[i].x += buns[i].xv * timestep
		buns[i].y += buns[i].yv * timestep
		if buns[i].x > x_range {
			buns[i].xv = -abs(buns[i].xv)
		} else if buns[i].x < 0 {
			buns[i].xv = abs(buns[i].xv)
		}
		if buns[i].y >= y_range {
			buns[i].yv = -abs(buns[i].yv)
			buns[i].y = y_range - (buns[i].y - y_range)
		}
	}
}

on_draw :: proc() {
	using game
	for i := 0; i < INSTANCES; i += 1 {
		pink.canvas_set_color(buns[i].color)
		pink.canvas_draw_rect(
			f32(buns[i].x), f32(buns[i].y),
			f32(RECT_SIZE), f32(RECT_SIZE),
		)
	}
}

main :: proc() {
	pink.runtime_set_load_proc(on_load)
	pink.runtime_set_update_proc(on_update)
	pink.runtime_set_draw_proc(on_draw)
	pink.runtime_go()
}
