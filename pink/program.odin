package pink

import "core:fmt"
import sdl "vendor:sdl2"
import "render"
import "clock"

PROGRAM_DEFAULT_CONFIG :: Program_Config{
	window_title = "Window",
	window_width = 1920,
	window_height = 1080,
	fixed_framerate = 60.0,
	framerate_cap = 0.0,
	vsync_enabled = false,
}

// The state of a program.
Program :: struct {
	clock: clock.Clock,
	window: Window,
	hooks: Program_Hooks,
	canvas: Canvas,
	quit_at_frame_end: bool,

	core: Program_Core,
}

Program_Core :: struct {
	renderer: render.Context,
	phase: enum {
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
	on_mouse_button_down: proc(int, int, Mouse_Button),
	on_mouse_button_up: proc(int, int, Mouse_Button),
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

Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}

// Configures the program. Call before `program_load()`. If you skip
// calling this, the program will be configured using `PROGRAM_DEFAULT_CONFIG`
program_configure :: proc(
	program: ^Program,
	config := PROGRAM_DEFAULT_CONFIG,
) -> bool {
	if program.core.phase != .Limbo {
		fmt.eprintln("program_configure must be called before any other lifetime procedures")
		return false
	}
	
	program.window.width = config.window_width
	program.window.height = config.window_height
	
	if config.framerate_cap > 0.0 {
		program.clock.frame_time_cap_ms = 1000.0 / config.framerate_cap
	} else {
		program.clock.frame_time_cap_ms = 0.0
	}
	
	if config.fixed_framerate > 0.0 {
		program.clock.delta_ms_fixed = 1000.0 / config.fixed_framerate
	} else {
		program.clock.delta_ms_fixed = 0.0
	}
	
	program.core.renderer.vsync = config.vsync_enabled
	program.window.core.sdl_flags += {.RESIZABLE}
	
	program.core.phase = .Configured
	return true
}

// Initializes the program.
program_load :: proc(
	program: ^Program,
) -> bool {
	if program.core.phase != .Configured && program.core.phase != .Limbo {
		fmt.eprintln("program_load must be called before program_run or program_exit")
		return false
	} else if program.core.phase == .Limbo {
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
		program.core.renderer.surface = surface
		render.context_init(&program.core.renderer)
	} else {
		fmt.eprintln("Failed to obtain render surface from window")
		return false
	}

	_canvas_init(&program.canvas, &program.core.renderer)

	if program.hooks.on_load != nil do program.hooks.on_load()
	
	program.core.phase = .Loaded
	return true
}

// Runs the program.
program_run :: proc(
	program: ^Program,
) -> bool {
	if program.core.phase != .Loaded {
		fmt.eprintln("program_run called before program_load")
		return false
	}
	
	if program.hooks.on_ready != nil do program.hooks.on_ready()
	
	first_frame := true
	clock.clock_reset(&program.clock)

	for !program.quit_at_frame_end {
		clock.clock_tick(&program.clock)
		
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
			case .MOUSEBUTTONDOWN:
				if program.hooks.on_mouse_button_down != nil {
					program.hooks.on_mouse_button_down(
						int(event.button.x),
						int(event.button.y),
						_mouse_button_from_sdl_button(event.button.button),
					)
				}

			case .MOUSEBUTTONUP:
				if program.hooks.on_mouse_button_up != nil {
					program.hooks.on_mouse_button_up(
						int(event.button.x),
						int(event.button.y),
						_mouse_button_from_sdl_button(event.button.button),
					)
				}
			}
		}
		
		if first_frame || size_changed || minimized || maximized {
			_window_fetch_info(&program.window)
			render.context_resize(
				&program.core.renderer,
				program.window.width,
				program.window.height,
			)
		}
		
		render.context_begin_frame(&program.core.renderer)
		
		if program.hooks.on_update != nil do program.hooks.on_update(program.clock.delta_ms)
		if program.hooks.on_update_fixed != nil {
			for i := 0; i < program.clock.fixed_update_count; i += 1 {
				program.hooks.on_update_fixed(program.clock.delta_ms_fixed)
			}
		}
		
		if program.hooks.on_draw != nil do program.hooks.on_draw()

		_canvas_flush_commands(&program.canvas, &program.core.renderer)
		render.context_end_frame(&program.core.renderer)

		first_frame = false
	}
	
	return true
}

// Shuts the program down.
program_exit :: proc(
	program: ^Program,
) -> bool {
	_canvas_destroy(&program.canvas)
	render.context_destroy(&program.core.renderer)
	_window_destroy(&program.window)
	sdl.Quit()
	
	return true
}

_mouse_button_from_sdl_button :: proc(button: u8) -> Mouse_Button {
	if button == sdl.BUTTON_LEFT {
		return .Left
	} else if button == sdl.BUTTON_RIGHT {
		return .Right
	} else if button == sdl.BUTTON_MIDDLE {
		return .Middle
	}
	return .Left
}