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

on_update :: proc(delta: f64) {
}

on_draw :: proc() {
	pink.canvas_draw_img(
		&game_state.kenney_img,
		10, 10,
		f32(game_state.kenney_img.width), f32(game_state.kenney_img.height),
	)
}

on_exit :: proc() {
	pink.image_destroy(&game_state.kenney_img)
}

main :: proc() {
	pink.runtime_set_update_proc(on_update)
	pink.runtime_set_draw_proc(on_draw)
	pink.runtime_set_exit_proc(on_exit)
	
	game_state.kenney_img = pink.image_load_png(#load("kenney16.png"))

	pink.runtime_go()

	// if !pink.runtime_go() {
	// 	pink.error_report_fatal(pink.runtime_error())
	// }
}
