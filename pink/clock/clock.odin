package clock

import "core:math"
import "core:time"

// Holds a runtime clock used to compute fixed updates and keep track of timing
// information.
Clock :: struct {
	now: time.Time,
	frame_time: time.Duration,
	frame_target_time: time.Duration,
	delta_ms_fixed: f64,
	delta_ms: f64,
	fixed_update_count: int,
	fixed_update_alpha: f64,
	accum_ms: f64,
}

// Resets a clocks current time to `time.now()`.
clock_reset :: proc(
	clock: ^Clock,
) {
	clock.now = time.now()
}

// Advances a Clock to `new_time`, recalculating fixed step updates and
// timestep.
clock_tick :: proc(
	clock: ^Clock,
) {
	new_time := time.now()
	clock.frame_time = time.diff(clock.now, new_time)
	clock.delta_ms = time.duration_milliseconds(clock.frame_time)
	clock.accum_ms += clock.delta_ms
	clock.now = new_time

	if clock.delta_ms_fixed > 0.0 {
		clock.fixed_update_count = int(math.floor(clock.accum_ms / clock.delta_ms_fixed))
		clock.accum_ms -= f64(clock.fixed_update_count) * clock.delta_ms_fixed
		clock.fixed_update_alpha = clock.accum_ms / clock.delta_ms_fixed
	} else {
		clock.fixed_update_count = 1
	}
}
