package pk_app

import "core:strings"
import "core:time"
import sdl "vendor:sdl2"

DEFAULT_CONFIG :: Config{
	window_title = "Window",
	window_width = 1920,
	window_height = 1080,
	fixed_framerate = 60.0,
	framerate_cap = 0.0,
}

/*
 * App State
 */

window: Window
clock: Clock
key_state: Keys
key_mod_state: Key_Mods
should_quit: bool
hooks: Hooks

// Configuration options for an app.
Config :: struct {
	window_title: string,
	window_width: uint,
	window_height: uint,
	fixed_framerate: f64,
	framerate_cap: f64,
}

// Program lifetime callbacks.
Hooks :: struct {
	on_load: proc(),
	on_ready: proc(),
	on_update: proc(f64),
	on_update_fixed: proc(f64),
	on_mouse_move: proc(f32, f32),
	on_mouse_button_down: proc(int, int, Mouse_Button),
	on_mouse_button_up: proc(int, int, Mouse_Button),
	on_mouse_wheel: proc(f32, f32),
	on_key_down: proc(Key),
	on_key_up: proc(Key),
	on_draw: proc(),
	on_exit: proc(),
}

// Core state. Shouldn't generally be accessed user-side.
_core: Core

@(private)
Core :: struct {
	phase: enum {
		Limbo,
		Configured,
		Loaded,
		Frame_Began,
		Frame_Ended,
		Exited,
	},
	hooks: Core_Hooks,
}

@(private)
Core_Hooks :: struct {
	ren_init: proc(),
	ren_destroy: proc(),
	ren_frame_begin: proc(),
	ren_frame_end: proc(),
	cnv_frame_begin: proc(),
	cnv_frame_end: proc(),
}

// Configures the app context.
conf :: proc(config := DEFAULT_CONFIG) {
	if _core.phase != .Limbo { panic("conf() called out of order") }

	window.title = strings.clone(config.window_title)
	window.width = config.window_width
	window.height = config.window_height

	if config.framerate_cap > 0.0 {
		clock.frame_target_time = time.Duration(1000.0 / config.framerate_cap) * time.Millisecond
	} else {
		clock.frame_target_time = 0.0
	}

	if config.fixed_framerate > 0.0 {
		clock.delta_ms_fixed = 1000.0 / config.fixed_framerate
	} else {
		clock.delta_ms_fixed = 0.0
	}

	_core.phase = .Configured
}

// Completes initialization of the app context.
load :: proc() {
	if _core.phase != .Configured && _core.phase != .Limbo { panic("load() called out of order") }
	if _core.phase == .Limbo { conf() }

	if sdl.Init({.VIDEO}) < 0 { panic("failed to initialize SDL") }
	
	window_init(&window)
	_core.phase = .Loaded

	if _core.hooks.ren_init != nil { _core.hooks.ren_init() }

	if hooks.on_load != nil { hooks.on_load() }
}

// Call at the beginning of a program frame.
frame_begin :: proc() {
	if _core.phase != .Loaded && _core.phase != .Frame_Ended { panic("frame_begin() called out of order") }
	first_frame := _core.phase == .Loaded

	key_state = key_state_from_sdl()
	key_mod_state = key_mod_state_from_sdl()

	if first_frame {
		clock_reset(&clock)
		
		if hooks.on_ready != nil { hooks.on_ready() }
	} else {
		clock_tick(&clock)
	}

	// Pump events
	size_changed, mind, maxd := false, false, false
	event: sdl.Event
	for sdl.PollEvent(&event) {
		#partial switch event.type {
		
		case .QUIT:
			should_quit = true
		
		}
	}

	if _core.hooks.ren_frame_begin != nil { _core.hooks.ren_frame_begin() }
	if _core.hooks.cnv_frame_begin != nil { _core.hooks.cnv_frame_begin() }

	if hooks.on_update != nil { hooks.on_update(clock.delta_ms) }
	if hooks.on_update_fixed != nil {
		for i := 0; i < clock.fixed_update_count; i += 1 {
			hooks.on_update_fixed(clock.delta_ms_fixed)
		}
	}

	_core.phase = .Frame_Began
}

// Call at the end of a program frame.
frame_end :: proc() {
	if _core.phase != .Frame_Began { panic("frame_end() called out of order") }

	if clock.frame_target_time > 0 {
		total_frame_time := time.diff(clock.now, time.now())
		if total_frame_time < clock.frame_target_time {
			time.accurate_sleep(clock.frame_target_time - total_frame_time)
		}
	}

	if _core.hooks.cnv_frame_end != nil { _core.hooks.cnv_frame_end() }
	if _core.hooks.ren_frame_end != nil { _core.hooks.ren_frame_end() }

	_core.phase = .Frame_Ended
}

// Call at program exit.
exit :: proc() {
	if _core.hooks.ren_destroy != nil { _core.hooks.ren_destroy() }
	window_destroy(&window)
	sdl.Quit()
}
