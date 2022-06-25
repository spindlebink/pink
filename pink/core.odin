package pink

import "core:c/libc"
import "core:fmt"
import "core:time"

import sdl "vendor:sdl2"

@(private)
program_state: struct {
	loaded: bool,
	configured: bool,
	exited: bool,
	should_quit: bool,
}

@(private)
window_state: struct {
	handle: ^sdl.Window,
	flags: sdl.WindowFlags,
	title: string,
	width: i32,
	height: i32,
	minimized: bool,
}

@(private)
runtime_state: struct {
	current_time: time.Time,
	timestep_ms: f64,
	accumulator_ms: f64,
	fixed_timestep_alpha: f64,
	fixed_timestep_ms: f64,
	variable_timestep_ms: f64,
	frame_time_cap_ms: f64,
	has_fixed_timestep: bool,
}

@(private)
runtime_callbacks: struct {
	on_load: [dynamic]proc(),
	on_ready: [dynamic]proc(),
	on_update: [dynamic]proc(),
	on_fixed_update: [dynamic]proc(),
	on_draw: [dynamic]proc(),
	on_exit: [dynamic]proc(),
}

//
//
//

// Adds a callback to the engine to be called on load.
on_load :: proc(callback: proc()) {
	append(&runtime_callbacks.on_load, callback)
}

// Adds a callback to the engine to be called after load.
on_ready :: proc(callback: proc()) {
	append(&runtime_callbacks.on_ready, callback)
}

// Adds a callback to the engine to be called each frame.
on_update :: proc(callback: proc()) {
	append(&runtime_callbacks.on_update, callback)
}

// Adds a callback to the engine to be called each fixed frame.
on_fixed_update :: proc(callback: proc()) {
	append(&runtime_callbacks.on_fixed_update, callback)
}

// Adds a callback to the engine to be called after each frame while the drawing
// context is active.
on_draw :: proc(callback: proc()) {
	append(&runtime_callbacks.on_draw, callback)
}

// Adds a callback to the engine to be called on exit.
on_exit :: proc(callback: proc()) {
	append(&runtime_callbacks.on_exit, callback)
}

// Returns current timestep milliseconds. You can scale game logic by this
// amount to alleviate inconsistencies due to frame drops. Will return a fixed
// timestep if called during a `fixed_update` callback and a variable timestep
// if called during an `update` callback.
timestep_ms :: proc() -> f64 {
	return runtime_state.timestep_ms
}

// Returns current variable timestep milliseconds i.e. the frame delta. You can
// scale game logic by this amount to alleviate inconsistencies due to frame
// drops.
timestep_variable_ms :: proc() -> f64 {
	return runtime_state.variable_timestep_ms
}

// Returns current fixed timestep milliseconds i.e. the fixed frame delta.
timestep_fixed_ms :: proc() -> f64 {
	return runtime_state.fixed_timestep_ms
}

//

// Configures Pink from a given `Config`.
configure :: proc(config: Config) {
	config := config
	config_fill_defaults(&config)
	
	if config.framerate_cap > 0.0 {
		runtime_state.frame_time_cap_ms = 1000.0 / config.framerate_cap
	} else {
		runtime_state.frame_time_cap_ms = -1.0
	}

	if config.framerate_fixed > 0.0 {
		runtime_state.fixed_timestep_ms = 1000.0 / config.framerate_fixed
	} else {
		runtime_state.fixed_timestep_ms = -1.0
	}

	window_state.title = config.window_title
	window_state.width = i32(config.window_width)
	window_state.height = i32(config.window_height)

	program_state.configured = true
}

// Initializes the engine and calls all `load` callbacks.
load :: proc() {
	debug_scope_push("load"); defer debug_scope_pop()
	debug_assert_fatal(!program_state.loaded, "duplicate load attempts")

	init_flags := sdl.InitFlags{.VIDEO}
	init_result := sdl.Init(init_flags)
	debug_assert_fatal(init_result >= 0, "could not initialize SDL")
	
	{
		window_state.flags = sdl.WindowFlags{.SHOWN, .RESIZABLE}
	
		when ODIN_OS == .Linux {
			window_state.flags += {.VULKAN}
		}
	
		window_state.handle = sdl.CreateWindow(
			cast(cstring) raw_data(window_state.title),
			sdl.WINDOWPOS_UNDEFINED,
			sdl.WINDOWPOS_UNDEFINED,
			window_state.width,
			window_state.height,
			window_state.flags,
		)

		debug_assert_fatal(window_state.handle != nil, "could not create SDL window")
		
		graphics_init(window_state.handle)
	}
	
	runtime_call_callbacks(&runtime_callbacks.on_load)
	program_state.loaded = true
}

// Runs the game loop until the window exits.
//
// TODO: user-facing way to exit
run :: proc() {
	debug_scope_push("run"); defer debug_scope_pop()
	
	runtime_state.current_time = time.now()
	runtime_state.accumulator_ms = 0.0

	for !program_state.should_quit {
	
		new_time := time.now()
		frame_time := time.diff(runtime_state.current_time, new_time)
		timestep_ms := time.duration_milliseconds(frame_time)

		runtime_state.current_time = new_time
		
		// TODO: limit frame jump for dropped frames--Fix Your Timestep uses 250ms. We
		// probably want this configurable.
		
		runtime_state.accumulator_ms += timestep_ms
		
		runtime_state.variable_timestep_ms = timestep_ms
		runtime_state.timestep_ms = timestep_ms
		
		window_update()

		runtime_call_callbacks(&runtime_callbacks.on_update)
		
		if runtime_state.fixed_timestep_ms > 0.0 {
			runtime_state.timestep_ms = runtime_state.fixed_timestep_ms
			for runtime_state.accumulator_ms > runtime_state.fixed_timestep_ms {
				runtime_call_callbacks(&runtime_callbacks.on_fixed_update)
				runtime_state.accumulator_ms -= runtime_state.fixed_timestep_ms
			}
		} else {
			runtime_call_callbacks(&runtime_callbacks.on_fixed_update)
		}
	
		runtime_state.timestep_ms = timestep_ms
		runtime_state.fixed_timestep_alpha = runtime_state.accumulator_ms / timestep_ms

		window_draw()
		
		if runtime_state.frame_time_cap_ms > 0.0 {
			work := time.duration_milliseconds(time.since(runtime_state.current_time))
			sleep_ms := runtime_state.frame_time_cap_ms - work
			if sleep_ms > 0.0 {
				sleep_ns := cast(i64) (sleep_ms * 1000.0 * 1000.0)
				time.accurate_sleep(time.Duration(sleep_ns))
			}
		}
	}
}

// Exits the game. You should only call this method after `run` has returned.
exit :: proc() {
	debug_scope_push("exit"); defer debug_scope_pop()

	debug_assert_fatal(!program_state.exited, "duplicate exit attempts")
	
	runtime_call_callbacks(&runtime_callbacks.on_exit)
	
	graphics_destroy()

	sdl.DestroyWindow(window_state.handle)
	sdl.Quit()
	
	delete(runtime_callbacks.on_load)
	delete(runtime_callbacks.on_ready)
	delete(runtime_callbacks.on_update)
	delete(runtime_callbacks.on_fixed_update)
	delete(runtime_callbacks.on_draw)
	delete(runtime_callbacks.on_exit)
	
	program_state.exited = true
}

// Loads, runs, and exits the game in sequence. Unless you need finer control
// over your game's lifetime, you should just `configure()` and then `go()`.
go :: proc() {
	if !program_state.configured do configure(DEFAULT_CONFIG)
	load(); defer exit()
	run()
}

// Internal procs

@(private)
program_request_exit :: proc() {
	program_state.should_quit = true
}

@(private)
runtime_call_callbacks :: proc(callbacks: ^[dynamic]proc()) {
	for callback in callbacks do callback()
}

@(private)
window_update :: proc() {
	size_changed, maximized := false, false
	event: sdl.Event
	for sdl.PollEvent(&event) != 0 {
		#partial switch event.type {
		case .QUIT:
			program_request_exit()
		case .WINDOWEVENT:
			#partial switch event.window.event {
			case .SIZE_CHANGED:
				size_changed = true
			case .MINIMIZED:
				window_state.minimized = true
			case .RESTORED:
				window_state.minimized = false
				size_changed = true
			case .MAXIMIZED:
				maximized = true
				size_changed = true
			}
		// TODO: input
		}
	}
	
	if size_changed || maximized {
		sdl.GetWindowSize(window_state.handle, &window_state.width, &window_state.height)
		graphics_rebuild_swap_chain()
	}
}

@(private)
window_draw :: proc() {
	debug_scope_push("draw"); defer debug_scope_pop()
	runtime_call_callbacks(&runtime_callbacks.on_draw)

	graphics_render()
}
