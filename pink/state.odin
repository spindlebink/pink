//+private
package pink

import "core:fmt"
import "core:sync"
import "core:time"
import sdl "vendor:sdl2"
import "wgpu/wgpu"

program_state: struct {
	loaded: bool,
	configured: bool,
	exited: bool,
	should_quit: bool,
	on_load: proc(),
	on_ready: proc(),
	on_update: proc(timestep: f64),
	on_fixed_update: proc(timestep: f64),
	on_draw: proc(),
	on_exit: proc(),
}

window_state: struct {
	handle: ^sdl.Window,
	flags: sdl.WindowFlags,
	title: string,
	width: int,
	height: int,
	minimized: bool,
}

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
