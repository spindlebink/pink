package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:mem"
import "core:time"
import "pink"

Game_State :: struct {
	kenney_img: pink.Image,
}

game_state: Game_State

on_draw :: proc() {
	pink.canvas_draw_img(
		&game_state.kenney_img,
		0, 0,
		f32(game_state.kenney_img.width), f32(game_state.kenney_img.height),
	)
}

main :: proc() {
	pink.runtime_set_draw_proc(on_draw)
	
	game_state.kenney_img = pink.image_load_png(#load("kenney16.png"))

	if !pink.runtime_go() {
		pink.error_report_fatal(pink.runtime_error())
	}
	
	pink.image_destroy(&game_state.kenney_img)
}
