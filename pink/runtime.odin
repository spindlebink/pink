package pink

import "core:time"
import sdl "vendor:sdl2"

// Sets the program's load callback.
on_load :: proc(callback: proc()) {
	program_state.on_load = callback
}

// Sets the program's ready callback.
on_ready :: proc(callback: proc()) {
	program_state.on_ready = callback
}

// Sets the program's update callback.
on_update :: proc(callback: proc(timestep: f64)) {
	program_state.on_update = callback
}

// Sets the program's fixed-update callback.
on_fixed_update :: proc(callback: proc(timestep: f64)) {
	program_state.on_fixed_update = callback
}

// Sets the program's draw callback.
on_draw :: proc(callback: proc()) {
	program_state.on_draw = callback
}

// Sets the program's exit callback.
on_exit :: proc(callback: proc()) {
	program_state.on_exit = callback
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

// Returns current window width.
window_width :: proc() -> uint {
	return uint(window_state.width)
}

// Returns current window height.
window_height :: proc() -> uint {
	return uint(window_state.height)
}

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
	window_state.width = int(config.window_width)
	window_state.height = int(config.window_height)

	program_state.configured = true
}

// Loads, runs, and exits the game in sequence.
go :: proc() {
	if !program_state.configured do configure(DEFAULT_CONFIG)

	// ************************************************************************ //
	// Load
	// ************************************************************************ //

	debug_scope_push("load")
	debug_assert_fatal(!program_state.loaded, "duplicate load attempts")

	init_flags := sdl.InitFlags{.VIDEO}
	init_result := sdl.Init(init_flags)
	debug_assert_fatal(init_result >= 0, "could not initialize SDL")
	
	// Initialize window
	window_state.flags = sdl.WindowFlags{.SHOWN, .RESIZABLE}
	when ODIN_OS == .Linux {
		window_state.flags += {.VULKAN}
	}

	window_state.handle = sdl.CreateWindow(
		cast(cstring) raw_data(window_state.title),
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		i32(window_state.width),
		i32(window_state.height),
		window_state.flags,
	)

	debug_assert_fatal(window_state.handle != nil, "could not create window")
	
	graphics_load()

	if program_state.on_load != nil do program_state.on_load()
	if program_state.on_ready != nil do program_state.on_ready()

	debug_scope_pop() // load

	// ************************************************************************ //
	// Run
	// ************************************************************************ //

	debug_scope_push("run")
	
	runtime_state.current_time = time.now()
	runtime_state.accumulator_ms = 0.0

	for !program_state.should_quit {
		new_time := time.now()
		frame_time := time.diff(runtime_state.current_time, new_time)
		timestep_ms := time.duration_milliseconds(frame_time)

		// TODO: limit frame jump for dropped frames

		runtime_state.current_time = new_time
		runtime_state.accumulator_ms += timestep_ms
		runtime_state.variable_timestep_ms = timestep_ms
		runtime_state.timestep_ms = timestep_ms

		//
		// Process window events
		//

		{
			size_changed, maximized := false, false
			event: sdl.Event
			for sdl.PollEvent(&event) != 0 {
				#partial switch event.type {
				case .QUIT:
					program_state.should_quit = true
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
				ww, wh: i32
				sdl.GetWindowSize(window_state.handle, &ww, &wh)
				window_state.width, window_state.height = int(ww), int(wh)
				graphics_state.swap_chain_expired = true
			}
		}

		//
		// Call loop callbacks
		//

		{
			// variable-rate update callback...
			if program_state.on_update != nil do program_state.on_update(runtime_state.variable_timestep_ms)
		
			// ...and then all scheduled fixed updates
			if runtime_state.fixed_timestep_ms > 0.0 {
				runtime_state.timestep_ms = runtime_state.fixed_timestep_ms
				for runtime_state.accumulator_ms > runtime_state.fixed_timestep_ms {
					if program_state.on_fixed_update != nil do program_state.on_fixed_update(runtime_state.fixed_timestep_ms)
					runtime_state.accumulator_ms -= runtime_state.fixed_timestep_ms
				}
			} else {
				if program_state.on_fixed_update != nil do program_state.on_fixed_update(runtime_state.variable_timestep_ms)
			}
		
			runtime_state.timestep_ms = timestep_ms
			runtime_state.fixed_timestep_alpha = runtime_state.accumulator_ms / timestep_ms
		}

		//
		// Render and sleep
		//

		{
			debug_scope_push("draw")
			
			if program_state.on_draw != nil do program_state.on_draw()
			graphics_frame_begin()
			graphics_frame_render()
			graphics_frame_end()

			debug_scope_pop()
			
			if runtime_state.frame_time_cap_ms > 0.0 {
				work := time.duration_milliseconds(time.since(runtime_state.current_time))
				sleep_ms := runtime_state.frame_time_cap_ms - work
				if sleep_ms > 0.0 {
					sleep_ns := cast(i64) (sleep_ms * 1000.0 * 1000.0)
					time.accurate_sleep(time.Duration(sleep_ns))
				}
			}
		}
	} // loop

	debug_scope_pop() // run

	// ************************************************************************ //
	// Exit
	// ************************************************************************ //

	debug_scope_push("exit")
	
	if program_state.on_exit != nil do program_state.on_exit()
	graphics_exit()

	sdl.DestroyWindow(window_state.handle)
	sdl.Quit()
	
	program_state.exited = true
	debug_scope_pop()
}
