package pink

import "core:fmt"
import sdl "vendor:sdl2"

PROGRAM_DEFAULT_CONFIG :: Program_Config{
	window_title = "Window",
	window_width = 800,
	window_height = 600,
	fixed_framerate = 60.0,
	framerate_cap = 0.0,
	vsync_enabled = false,
}

// The state of a program.
Program :: struct {
	clock: Clock,
	window: Window,
	hooks: Program_Hooks,
	canvas: Canvas,
	quit_at_frame_end: bool,

	_renderer: Renderer,
	_phase: enum {
		Limbo,
		Configured,
		Loaded,
		Running,
		Exited,
	},
}

// Callbacks triggered at various points in the program's lifetime.
Program_Hooks :: struct {
	on_load: proc(),
	on_ready: proc(),
	on_update: proc(f64),
	on_update_fixed: proc(f64),
	on_draw: proc(),
	on_exit: proc(),
}

// Configuration options for a program.
Program_Config :: struct {
	window_title: string,
	window_width: int,
	window_height: int,
	fixed_framerate: f64,
	framerate_cap: f64,
	vsync_enabled: bool,
}

// Configures the program. Call before `program_load()`. If you skip
// calling this, the program will be configured using `PROGRAM_DEFAULT_CONFIG`
program_configure :: proc(
	program: ^Program,
	config := PROGRAM_DEFAULT_CONFIG,
) -> bool {
	if program._phase != .Limbo {
		fmt.eprintln("program_configure must be called before any other lifetime procedures")
		return false
	}
	
	program.window.width = config.window_width
	program.window.height = config.window_height
	
	if config.framerate_cap > 0.0 {
		program.clock._frame_time_cap_ms = 1000.0 / config.framerate_cap
	} else {
		program.clock._frame_time_cap_ms = 0.0
	}
	
	if config.fixed_framerate > 0.0 {
		program.clock.delta_ms_fixed = 1000.0 / config.fixed_framerate
	} else {
		program.clock.delta_ms_fixed = 0.0
	}
	
	program._renderer.vsync = config.vsync_enabled
	
	program._phase = .Configured
	return true
}

// Initializes the program.
program_load :: proc(
	program: ^Program,
) -> bool {
	if program._phase != .Configured && program._phase != .Limbo {
		fmt.eprintln("program_load must be called before program_run or program_exit")
		return false
	} else if program._phase == .Limbo {
		program_configure(program)
	}
	
	sdl_init := sdl.Init({.VIDEO})
	if sdl_init < 0 {
		fmt.eprintln("Failed to initialize SDL")
		return false
	}
	
	win_success := _window_init(&program.window)
	if !win_success do return false

	if surface, ok := _window_create_wgpu_surface(&program.window); ok {
		program._renderer.surface = surface
		_renderer_init(&program._renderer)
	} else {
		fmt.eprintln("Failed to obtain render surface from window")
		return false
	}

	_canvas_init(&program.canvas, &program._renderer)

	if program.hooks.on_load != nil do program.hooks.on_load()
	
	program._phase = .Loaded
	return true
}

// Runs the program.
program_run :: proc(
	program: ^Program,
) -> bool {
	if program._phase != .Loaded {
		fmt.eprintln("program_run called before program_load")
		return false
	}
	
	if program.hooks.on_ready != nil do program.hooks.on_ready()
	
	first_frame := true
	_clock_reset(&program.clock)

	for !program.quit_at_frame_end {
		_clock_tick(&program.clock)
		
		size_changed, minimized, maximized := false, false, false
		event: sdl.Event
		for sdl.PollEvent(&event) != 0 {
			#partial switch event.type {
			case .QUIT:
				program.quit_at_frame_end = true
			case .WINDOWEVENT:
				#partial switch event.window.event {
				case .SIZE_CHANGED:
					size_changed = true
				case .MINIMIZED:
					minimized = true
					size_changed = true
				case .RESTORED:
					size_changed = true
				case .MAXIMIZED:
					maximized = true
					size_changed = true
				}
			}
		}
		
		if first_frame || size_changed || minimized || maximized {
			_window_fetch_info(&program.window)
			_renderer_resize(
				&program._renderer,
				program.window.width,
				program.window.height,
			)
		}
		
		_renderer_begin_frame(&program._renderer)
		
		if program.hooks.on_update != nil do program.hooks.on_update(program.clock.delta_ms)
		if program.hooks.on_update_fixed != nil {
			for i := 0; i < program.clock._fixed_update_count; i += 1 {
				program.hooks.on_update_fixed(program.clock.delta_ms_fixed)
			}
		}
		
		if program.hooks.on_draw != nil do program.hooks.on_draw()

		_renderer_end_frame(&program._renderer)

		first_frame = false
	}
	
	return true
}

// Shuts the program down.
program_exit :: proc(
	program: ^Program,
) -> bool {
	_canvas_destroy(&program.canvas)
	_renderer_destroy(&program._renderer)
	_window_destroy(&program.window)
	sdl.Quit()
	
	return true
}

