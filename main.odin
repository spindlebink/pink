package main;

import "core:fmt"
import "pink"

on_load :: proc() {
}

on_update :: proc(dt: f64) {
}

on_draw :: proc() {
}

main :: proc() {
	pink.init()
	
	pink.set_window_title("Test Window")
	pink.set_target_fps(60)
	pink.on_load(on_load)
	pink.on_update(on_update)
	
	pink.run()
	pink.exit()
}
