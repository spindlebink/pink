//+private
package pink

import "core:time"
import sdl "vendor:sdl2"

runtime_state := Runtime_State{
	config = Runtime_Config{
		window_title = "Window",
		window_width = 800,
		window_height = 600,
		fixed_framerate = 60.0,
		framerate_cap = 0.0,
		vsync_enabled = false,
	},
}

// ************************************************************************** //
// Type Definitions
// ************************************************************************** //

Runtime_State :: struct {
	on_load: proc(),
	on_ready: proc(),
	on_update: proc(f64),
	on_fixed_update: proc(f64),
	on_draw: proc(),
	on_exit: proc(),
	
	running: bool,
	should_quit: bool,
	configured: bool,
	config: Runtime_Config,
	error: Error(Runtime_Error),

	window: Runtime_Window_State,
	clock: Runtime_Clock_State,
}

Runtime_Config :: struct {
	window_title: string,
	window_width: int,
	window_height: int,
	fixed_framerate: f64,
	framerate_cap: f64,
	vsync_enabled: bool,
}

Runtime_Window_State :: struct {
	handle: ^sdl.Window,
	flags: sdl.WindowFlags,
	width: i32,
	height: i32,
	minimized: bool,
}

Runtime_Clock_State :: struct {
	now: time.Time,
	timestep_ms: f64,
	accumulator_ms: f64,
	fixed_timestep_alpha: f64,
	fixed_timestep_ms: f64,
	variable_timestep_ms: f64,
	frame_time_cap_ms: f64,
	has_fixed_timestep: bool,
}
