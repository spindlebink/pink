package pink

import "core:math"
import "core:time"

// Holds a runtime clock used to compute fixed updates and keep track of timing
// information.
Clock :: struct {
	now: time.Time,
	update_fixed_alpha: f64,
	delta_ms_fixed: f64,
	delta_ms: f64,

	core: Clock_Core,
}

// Internal state info for a clock.
Clock_Core :: struct {
	fixed_update_count: int,
	frame_time_cap_ms: f64,
	accum_ms: f64,
}

// Resets a clocks current time to `time.now()`.
clock_reset :: proc(
	clock: ^Clock,
) {
	clock.now = time.now()
}

// Internal. Advances a Clock to `new_time`, recalculating fixed step updates
// and timestep.
clock_tick :: proc(
	clock: ^Clock,
) {
	new_time := time.now()
	frame_time := time.diff(clock.now, new_time)
	clock.delta_ms = time.duration_milliseconds(frame_time)
	clock.core.accum_ms += clock.delta_ms
	clock.now = new_time

	if clock.delta_ms_fixed > 0.0 {
		clock.core.fixed_update_count = int(math.floor(clock.core.accum_ms / clock.delta_ms_fixed))
		clock.core.accum_ms -= f64(clock.core.fixed_update_count) * clock.delta_ms_fixed
		clock.update_fixed_alpha = clock.core.accum_ms / clock.delta_ms_fixed
	} else {
		clock.core.fixed_update_count = 1
	}
}
