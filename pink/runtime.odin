package pink

import "core:time"
import sdl "vendor:sdl2"

// ************************************************************************** //
// Type Definitions & Constants
// ************************************************************************** //

Runtime_Error_Type :: enum {
	None,
	Bad_Initialization,
	Exit_Error,
}

Runtime_Error :: Error(Runtime_Error_Type)

ERROR_DUPLICATE_GO_CALLS :: "Duplicate calls to runtime_go()"
ERROR_SDL_INIT_FAILED :: "Failed to initialize SDL"
ERROR_WINDOW_CREATION_FAILED :: "Failed to create window"
ERROR_RENDER_INIT_FAILED :: "Failed to initialize renderer"
ERROR_RENDER_EXIT_FAILED :: "Failed to shut down renderer"

// ************************************************************************** //
// Procedures
// ************************************************************************** //

// Returns `true` if the runtime system has encountered no errors or if any
// errors have been marked as handled.
runtime_ok :: proc() -> bool {
	return runtime_state.error.type == .None
}

// Returns any error the runtime system last experienced.
runtime_error :: proc() -> Runtime_Error {
	return runtime_state.error
}

// Marks any error the runtime system has received as handled.
runtime_clear_error :: proc() {
	runtime_state.error.type = .None
}

// Configures the program. Call before calling `runtime_go()`.
runtime_configure :: proc(
	window_title := runtime_state.config.window_title,
	window_width := runtime_state.config.window_width,
	window_height := runtime_state.config.window_height,
	fixed_framerate := runtime_state.config.fixed_framerate,
	framerate_cap := runtime_state.config.framerate_cap,
	vsync_enabled := runtime_state.config.vsync_enabled,
) {
	using runtime_state
	
	// ensure we can modify the arguments to set sane bounds
	window_width := window_width
	window_height := window_height
	fixed_framerate := fixed_framerate
	framerate_cap := framerate_cap

	if window_width < 1 do window_width = 1
	if window_height < 1 do window_height = 1
	if fixed_framerate < 0.0 do fixed_framerate = 0.0
	if framerate_cap <= 0.0 do framerate_cap = 0.0
	
	config.window_title = window_title
	config.window_width = window_width
	config.window_height = window_height
	config.fixed_framerate = fixed_framerate
	config.framerate_cap = framerate_cap
	config.vsync_enabled = vsync_enabled
	
	if config.framerate_cap > 0.0 {
		clock.frame_time_cap_ms = 1000.0 / config.framerate_cap
	} else {
		clock.frame_time_cap_ms = -1.0
	}
	
	if config.fixed_framerate > 0.0 {
		clock.fixed_timestep_ms = 1000.0 / config.fixed_framerate
	} else {
		clock.fixed_timestep_ms = -1.0
	}
	
	configured = true
}

// One-liners

runtime_set_load_proc :: proc(callback: proc()) { runtime_state.on_load = callback }
runtime_set_ready_proc :: proc(callback: proc()) { runtime_state.on_ready = callback }
runtime_set_update_proc :: proc(callback: proc(f64)) { runtime_state.on_update = callback }
runtime_set_fixed_update_proc :: proc(callback: proc(f64)) { runtime_state.on_fixed_update = callback }
runtime_set_exit_proc :: proc(callback: proc()) { runtime_state.on_exit = callback }

runtime_window_width :: proc() -> i32 { return runtime_state.window.width }
runtime_window_height :: proc() -> i32 { return runtime_state.window.height }
runtime_window_size :: proc() -> (width: i32, height: i32) { return runtime_state.window.width, runtime_state.window.height }

// Runs the program.
runtime_go :: proc() -> bool {
	using runtime_state
	
	if running {
		error = Runtime_Error{
			type = .Bad_Initialization,
			message = ERROR_DUPLICATE_GO_CALLS,
		}
		return false
	}
	
	running = true
	if !configured do runtime_configure()
	
	/*
	
	Load
	
	*/
	
	initialized := sdl.Init({.VIDEO}); defer sdl.Quit()
	if initialized < 0 {
		error = Runtime_Error{
			type = .Bad_Initialization,
			message = ERROR_SDL_INIT_FAILED,
		}
		return false
	}

	window.flags = sdl.WindowFlags{.RESIZABLE}
	when ODIN_OS == .Linux {
		window.flags += {.VULKAN}
	}

	window.handle = sdl.CreateWindow(
		cast(cstring) raw_data(config.window_title),
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		i32(config.window_width),
		i32(config.window_height),
		window.flags,
	)
	defer sdl.DestroyWindow(window.handle)

	if window.handle == nil {
		error = Runtime_Error{
			type = .Bad_Initialization,
			message = ERROR_WINDOW_CREATION_FAILED,
		}
		return false
	}
	
	sdl.GetWindowSize(window.handle, &window.width, &window.height)

	if !render_init() {
		error = Runtime_Error{
			type = .Bad_Initialization,
			message = ERROR_RENDER_INIT_FAILED,
		}
		return false
	}

	if on_load != nil do on_load()
	if on_ready != nil do on_ready()

	/*
	
	Run
	
	*/

	clock.now = time.now()

	for !should_quit {
		new_time := time.now()
		frame_time := time.diff(clock.now, new_time)
		
		clock.timestep_ms = time.duration_milliseconds(frame_time)
		clock.variable_timestep_ms = clock.timestep_ms
		clock.accumulator_ms += clock.timestep_ms
		clock.now = new_time
		
		// Process window events
		size_changed, maximized := false, false
		event: sdl.Event
		for sdl.PollEvent(&event) != 0 {
			#partial switch event.type {
			case .QUIT:
				should_quit = true
			case .WINDOWEVENT:
				#partial switch event.window.event {
				case .SIZE_CHANGED:
					size_changed = true
				case .MINIMIZED:
					window.minimized = true
				case .RESTORED:
					window.minimized = false
					size_changed = true
				case .MAXIMIZED:
					maximized = true
					size_changed = true
				}
			}
		}
		
		if size_changed || maximized {
			sdl.GetWindowSize(
				window.handle,
				&window.width,
				&window.height,
			)

			render_invalidate_swap_chain()
		}
		
		if on_update != nil do on_update(clock.timestep_ms)
		
		if clock.fixed_timestep_ms > 0.0 {
			clock.timestep_ms = clock.fixed_timestep_ms
			if on_fixed_update != nil {
				for clock.accumulator_ms > clock.fixed_timestep_ms {
					on_fixed_update(clock.fixed_timestep_ms)
					clock.accumulator_ms -= clock.fixed_timestep_ms
				}
			}
		} else {
			if on_fixed_update != nil do on_fixed_update(clock.variable_timestep_ms)
		}
		
		clock.timestep_ms = clock.variable_timestep_ms
		clock.fixed_timestep_alpha = clock.accumulator_ms / clock.timestep_ms
	
		if on_draw != nil do on_draw()

		render_begin_frame()
		
		// Push canvas stuff to GPU
		
		render_end_frame()
	}
	
	/*
	
	Exit
	
	*/
	
	if on_exit != nil do on_exit()
	
	if !render_exit() {
		error = Runtime_Error{
			type = .Exit_Error,
			message = ERROR_RENDER_EXIT_FAILED,
		}
		return false
	}

	return true
}
