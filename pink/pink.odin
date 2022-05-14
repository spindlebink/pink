package pink

import "core:fmt"
import "core:time"
import "core:strings"
import "core:log"
import sdl "vendor:sdl2"

@(private)
Context :: struct {
	window: ^sdl.Window,
	window_width,
	window_height: i32,
	window_title: string,

	initialized: bool,
	should_close: bool,
	target_frame_time: time.Duration,

	on_load: [dynamic]proc(),
	on_ready: [dynamic]proc(),
	on_update: [dynamic]proc(delta: f64),
	on_draw: [dynamic]proc(),
	on_exit: [dynamic]proc(),
}

when ODIN_DEBUG {
	@(private)
	debug_log: log.Logger
}

@(private)
ctx: Context

//****************************************************************************//
// Init
//****************************************************************************//

init :: proc(width: i32 = 1024, height: i32 = 768) {
	when ODIN_DEBUG {
		logger_options := log.Options{.Level, .Line, .Time, .Short_File_Path}
		lowest :: log.Level.Debug
		debug_log = log.create_console_logger(opt = logger_options, lowest = lowest)
		context.logger = debug_log
	}
	
	fmt.assertf(!ctx.initialized, "Runtime context already initialized")
	
	if ctx.window_title == "" {
		ctx.window_title = "Window"
	}

	init_flags: bit_set[sdl.InitFlag; u32] : sdl.InitFlags{.VIDEO}
	fmt.assertf(sdl.Init(init_flags) >= 0, "Could not initialize SDL")
	
	graphics_load()

	ctx.window_width = width
	ctx.window_height = height
	
	cstr := strings.clone_to_cstring(ctx.window_title); defer delete(cstr)
	ctx.window = sdl.CreateWindow(
		cstr,
		i32(sdl.WINDOWPOS_UNDEFINED),
		i32(sdl.WINDOWPOS_UNDEFINED),
		width,
		height,
		sdl.WindowFlags{.SHOWN, .RESIZABLE, .VULKAN},
	)
	
	graphics_init()

	ctx.initialized = true
}

//****************************************************************************//
// Run
//****************************************************************************//

run :: proc() {
	fmt.assertf(ctx.initialized, "Runtime context not initialized")
	
	for callback in ctx.on_load {
		callback()
	}
	
	for callback in ctx.on_ready {
		callback()
	}
	
	frame_start_time := time.tick_now()
	delta := time.Duration(0)

	for !ctx.should_close {
		frame_start_time = time.tick_now()
		
		event: sdl.Event
		for sdl.PollEvent(&event) != 0 {
			#partial switch event.type {
			case .QUIT:
				ctx.should_close = true
			case .WINDOWEVENT:
				#partial switch event.window.event {
				case .SIZE_CHANGED:
					graphics_trigger_resize()
				}
			}
		}
		
		ms := time.duration_milliseconds(delta)
		for callback in ctx.on_update {
			callback(ms)
		}
		
		for callback in ctx.on_draw {
			callback()
		}
		
		graphics_draw()
		
		total_frame_time := time.tick_diff(frame_start_time, time.tick_now())
		if ctx.target_frame_time != 0 && total_frame_time < ctx.target_frame_time {
			time.accurate_sleep(ctx.target_frame_time - total_frame_time)
		}
		delta = time.tick_diff(frame_start_time, time.tick_now())
	}
}

//****************************************************************************//
// Exit
//****************************************************************************//

exit :: proc() {
	context.logger = debug_log
	if !ctx.initialized {
		fmt.eprintln("Context not initialized before exit")
		return
	}
	graphics_destroy()

	sdl.DestroyWindow(ctx.window)
	sdl.Quit()
	delete(ctx.on_load)
	delete(ctx.on_ready)
	delete(ctx.on_update)
	delete(ctx.on_draw)
	
	when ODIN_DEBUG {
		log.destroy_console_logger(&debug_log)
	}
}

//****************************************************************************//
// Configuration
//****************************************************************************//

set_target_fps :: proc(fps: f64) {
	if fps == 0.0 {
		ctx.target_frame_time = time.Duration(0)
	} else {
		ctx.target_frame_time = time.Millisecond * time.Duration(1000.0 / fps)
	}
}

set_window_size :: proc(width: i32, height: i32) {
	fmt.assertf(width > 0 && height > 0, "cannot set window size to <= 0")
	ctx.window_width, ctx.window_height = width, height
	if ctx.initialized {
		sdl.SetWindowSize(ctx.window, width, height)
	}
}

set_window_title :: proc(title: string) {
	ctx.window_title = title
	if ctx.initialized {
		cstr := strings.clone_to_cstring(title); defer delete(cstr)
		sdl.SetWindowTitle(ctx.window, cstr)
	}
}

//****************************************************************************//
// Callback Procs
//****************************************************************************//

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
