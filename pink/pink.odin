package pink

import "core:fmt"
import "core:time"
import "core:strings"
import "core:log"
import sdl "vendor:sdl2"

import "graphics"

WINDOW_DEFAULT_WIDTH: u32 : 800
WINDOW_DEFAULT_HEIGHT: u32 : 600

Config :: struct {
	window_width: u32,
	window_height: u32,
}

fill_config_defaults :: proc(config: ^Config) {
	if config.window_width == 0 do config.window_width = WINDOW_DEFAULT_WIDTH
	if config.window_height == 0 do config.window_height = WINDOW_DEFAULT_HEIGHT
}

//
// Context
//

@(private)
Context :: struct {
	window: ^sdl.Window,
	window_width,
	window_height: u32,
	window_title: string,
	window_minimized: bool,

	initialized: bool,
	should_close: bool,
	target_frame_time: time.Duration,

	on_load: [dynamic]proc(),
	on_ready: [dynamic]proc(),
	on_update: [dynamic]proc(delta: f64),
	on_draw: [dynamic]proc(),
	on_exit: [dynamic]proc(),
}

@(private)
ctx: Context

//
// Init
//

init :: proc(config: Config = Config{}) {
	conf := config
	fill_config_defaults(&conf)
	
	fmt.assertf(!ctx.initialized, "Runtime context already initialized")
	
	if ctx.window_title == "" {
		ctx.window_title = "Window"
	}
	
	ctx.window_minimized = false

	init_flags := sdl.InitFlags{.VIDEO}
	init_result := sdl.Init(init_flags)
	fmt.assertf(init_result >= 0, "Could not initialize SDL")
	
	ctx.window_width = conf.window_width
	ctx.window_height = conf.window_height
	
	window_flags := sdl.WindowFlags{.SHOWN, .RESIZABLE}

	when ODIN_OS == .Linux {
		window_flags += {.VULKAN}
	} else when ODIN_OS == .Darwin {
		window_flags += {.METAL}
	}
	
	ctx.window = sdl.CreateWindow(
		cast(cstring) raw_data(ctx.window_title),
		i32(sdl.WINDOWPOS_UNDEFINED),
		i32(sdl.WINDOWPOS_UNDEFINED),
		cast(i32) ctx.window_width,
		cast(i32) ctx.window_height,
		window_flags,
	)

	graphics.init(ctx.window)
	ctx.initialized = true
}

//
// Run
//

run :: proc() {
	fmt.assertf(ctx.initialized, "Runtime context not initialized")

	for callback in ctx.on_load do callback()
	for callback in ctx.on_ready do callback()

	delta_time := time.Duration(0)

	for !ctx.should_close {
		frame_start_time := time.tick_now()

		window_size_changed, maximized := false, false
		event: sdl.Event
		for sdl.PollEvent(&event) != 0 {
			#partial switch event.type {
			case .QUIT:
				ctx.should_close = true
			case .WINDOWEVENT:
				#partial switch event.window.event {
				case .SIZE_CHANGED:
					window_size_changed = true
				case .MINIMIZED:
					ctx.window_minimized = true
				case .RESTORED:
					fallthrough
				case .MAXIMIZED:
					maximized = true
					ctx.window_minimized = false
					window_size_changed = true
				}
			}
		}

		if window_size_changed {
			ww, wh: i32
			sdl.GetWindowSize(ctx.window, &ww, &wh)
			ctx.window_width, ctx.window_height = cast(u32) ww, cast(u32) wh
			graphics.rebuild_swap_chain(ctx.window_width, ctx.window_height)
		}

		ms := time.duration_milliseconds(delta_time)

		for callback in ctx.on_update do callback(ms)

		graphics.begin_render()
		for callback in ctx.on_draw do callback()
		graphics.end_render()

		total_frame_time := time.tick_diff(frame_start_time, time.tick_now())
		if ctx.target_frame_time != 0 && total_frame_time < ctx.target_frame_time {
			time.sleep(ctx.target_frame_time - total_frame_time)
		}
		delta_time = time.tick_diff(frame_start_time, time.tick_now())
	}

	for callback in ctx.on_exit do callback()
	exit()
}

//
// Exit
//

@(private)
exit :: proc() {
	sdl.DestroyWindow(ctx.window)
	sdl.Quit()
	delete(ctx.on_load)
	delete(ctx.on_ready)
	delete(ctx.on_update)
	delete(ctx.on_draw)
}

//
// Configuration
//

set_target_fps :: proc(fps: f64) {
	if fps == 0.0 {
		ctx.target_frame_time = time.Duration(0)
	} else {
		ctx.target_frame_time = time.Millisecond * time.Duration(1000.0 / fps)
	}
}

set_window_size :: proc(width: u32, height: u32) {
	fmt.assertf(width > 0 && height > 0, "Cannot set window size to <= 0")
	ctx.window_width, ctx.window_height = width, height
	if ctx.initialized {
		sdl.SetWindowSize(ctx.window, cast(i32) width, cast(i32) height)
	}
}

set_window_title :: proc(title: string) {
	ctx.window_title = title
	if ctx.initialized {
		cstr := strings.clone_to_cstring(title); defer delete(cstr)
		sdl.SetWindowTitle(ctx.window, cstr)
	}
}

//
// Callback Procs
//

on_load :: proc(callback: proc()) {
	append(&ctx.on_load, callback)
}

on_ready :: proc(callback: proc()) {
	append(&ctx.on_ready, callback)
}

on_update :: proc(callback: proc(delta: f64)) {
	append(&ctx.on_update, callback)
}

on_draw :: proc(callback: proc()) {
	append(&ctx.on_draw, callback)
}

on_exit :: proc(callback: proc()) {
	append(&ctx.on_exit, callback)
}
