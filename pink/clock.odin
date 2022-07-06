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

	_fixed_update_count: int,
	_frame_time_cap_ms: f64,
	_accum_ms: f64,
}

_clock_reset :: proc(
	clock: ^Clock,
) {
	clock.now = time.now()
}

// Internal. Advances a Clock to `new_time`, recalculating fixed step updates
// and timestep.
_clock_tick :: proc(
	clock: ^Clock,
) {
	new_time := time.now()
	frame_time := time.diff(clock.now, new_time)
	clock.delta_ms = time.duration_milliseconds(frame_time)
	clock._accum_ms += clock.delta_ms
	clock.now = new_time

	if clock.delta_ms_fixed > 0.0 {
		clock._fixed_update_count = int(math.floor(clock._accum_ms / clock.delta_ms_fixed))
		clock._accum_ms -= f64(clock._fixed_update_count) * clock.delta_ms_fixed
		clock.update_fixed_alpha = clock._accum_ms / clock.delta_ms_fixed
	} else {
		clock._fixed_update_count = 1
	}
}
