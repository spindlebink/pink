package pink

import "core:fmt"
import "core:strings"
import "core:time"
import sdl "vendor:sdl2"
import "render"
import "clock"

// Config used when either no config is provided or `program_configure()` isn't
// called.
//
// You can configure your program easily by creating a copy of this constant and
// only modifying the parameters you need.
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
	using hooks: Program_Hooks,

	clock: clock.Clock,
	window: Window,
	canvas: Canvas,
	quit_at_frame_end: bool,

	mouse_pos: [2]f32,
	mouse_rel_pos: [2]f32,
	key_mod_state: Modifier_Keys,
	key_state: map[Key]bool,

	core: Program_Core,
}

// Callbacks triggered at various points in the program's lifetime. You can set
// these for your program using `program.hooks.on_* = your_callback`.
Program_Hooks :: struct {
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

// Configuration options for a program.
Program_Config :: struct {
	window_title: string,
	window_width: int,
	window_height: int,
	fixed_framerate: f64,
	framerate_cap: f64,
	vsync_enabled: bool,
}

// Mouse button used in `on_mouse_button_*` callbacks.
Mouse_Button :: enum {
	Left,
	Right,
	Middle,
}

@(private)
Program_Core :: struct {
	renderer: render.Renderer,
	render_pass: render.Render_Pass,
	phase: enum {
		Limbo,
		Configured,
		Loaded,
		Running,
		Exited,
	},
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
	
	program.window.title = strings.clone(config.window_title)
	program.window.width = config.window_width
	program.window.height = config.window_height
	
	if config.framerate_cap > 0.0 {
		program.clock.frame_target_time = time.Duration(1000.0 / config.framerate_cap) * time.Millisecond
	} else {
		program.clock.frame_target_time = 0
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

// Initializes the program. Must be called before running or exiting.
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
	
	win_success := window_init(&program.window)
	if !win_success do return false

	if surface, ok := window_create_wgpu_surface(&program.window); ok {
		program.core.renderer.surface = surface
		render.renderer_init(&program.core.renderer)
	} else {
		fmt.eprintln("Failed to obtain render surface from window")
		return false
	}

	if program.hooks.on_load != nil do program.hooks.on_load()
	
	program.core.phase = .Loaded
	return true
}

// Runs the program. Must be called after load.
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

	// program.keyboard_state = key_state_from_sdl()
	key_state_from_sdl(&program.key_state)
	program.key_mod_state = key_mod_state_from_sdl()
	
	for !program.quit_at_frame_end {
		clock.clock_tick(&program.clock)

		// program.keyboard_state = key_state_from_sdl()
		key_state_from_sdl(&program.key_state)
		program.key_mod_state = key_mod_state_from_sdl()
		
		size_changed, minimized, maximized := false, false, false
		event: sdl.Event
		for sdl.PollEvent(&event) {
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
						mouse_button_from_sdl(event.button.button),
					)
				}

			case .MOUSEBUTTONUP:
				if program.hooks.on_mouse_button_up != nil {
					program.hooks.on_mouse_button_up(
						int(event.button.x),
						int(event.button.y),
						mouse_button_from_sdl(event.button.button),
					)
				}
			
			case .MOUSEWHEEL:
				if program.hooks.on_mouse_wheel != nil {
					program.hooks.on_mouse_wheel(
						f32(event.wheel.x),
						f32(event.wheel.y),
					)

					// Eventually:
					// event.wheel.preciseX,
					// event.wheel.preciseY,
				}
			
			case .KEYDOWN:
				key := event.key.keysym
				if pk_key, found := sdl_key_lookups[key.scancode]; found {
					if program.hooks.on_key_down != nil {
						program.hooks.on_key_down(pk_key)
					}
				}
				
			case .KEYUP:
				key := event.key.keysym
				if pk_key, found := sdl_key_lookups[key.scancode]; found {
					if program.hooks.on_key_up != nil {
						program.hooks.on_key_up(pk_key)
					}
				}
			
			case .MOUSEMOTION:
				me := event.motion
				program.mouse_pos.x, program.mouse_pos.y = f32(me.x), f32(me.y)
				program.mouse_rel_pos.x, program.mouse_rel_pos.y = f32(me.xrel), f32(me.yrel)
				if program.hooks.on_mouse_move != nil {
					program.hooks.on_mouse_move(program.mouse_pos.x, program.mouse_pos.y)
				}
			
			}
		}
		
		if first_frame || size_changed || maximized {
			window_fetch_info(&program.window)
			render.renderer_resize(
				&program.core.renderer,
				program.window.width,
				program.window.height,
			)
		}
		
		render.renderer_begin_frame(&program.core.renderer)
		
		if program.hooks.on_update != nil do program.hooks.on_update(program.clock.delta_ms)
		if program.hooks.on_update_fixed != nil {
			for i := 0; i < program.clock.fixed_update_count; i += 1 {
				program.hooks.on_update_fixed(program.clock.delta_ms_fixed)
			}
		}
		
		if program.hooks.on_draw != nil do program.hooks.on_draw()

		canvas_flush(&program.canvas, &program.core.renderer)
		render.renderer_end_frame(&program.core.renderer)

		first_frame = false
		
		if program.clock.frame_target_time > 0 {
			total_frame_time := time.diff(program.clock.now, time.now())
			if total_frame_time < program.clock.frame_target_time {
				time.accurate_sleep(program.clock.frame_target_time - total_frame_time)
			}
		}
	}
	
	return true
}

// Shuts the program down. Must be called after running.
program_exit :: proc(
	program: ^Program,
) -> bool {
	if program.hooks.on_exit != nil do program.hooks.on_exit()
	
	delete(program.key_state)
	canvas_destroy(&program.canvas)
	render.renderer_destroy(&program.core.renderer)
	window_destroy(&program.window)
	sdl.Quit()
	
	return true
}

// Calls load, run, and exit on a program in sequence.
program_go :: proc(
	program: ^Program,
) -> bool {
	program_load(program) or_return
	program_run(program) or_return
	program_exit(program) or_return
	return true
}
