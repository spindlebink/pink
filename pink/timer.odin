package pink

import "core:time"

Timer :: struct {
	active: bool,
	times: uint,
	userdata: rawptr,
	on_time: proc(Timer),
	
	invocations: uint,
	delay: time.Duration,
	until_next: time.Duration,
	began: bool,
}

// Updates a timer, applying `tick` to its internal counter and calling the
// timer's callback if necessary.
timer_update :: proc(
	timer: ^Timer,
	now: time.Time,
	tick: time.Duration,
) -> bool {
	timer.until_next -= tick
	for timer.until_next <= 0 {
		timer.until_next += timer.delay
		if timer.on_time != nil {
			timer.invocations += 1
			timer.on_time(timer^)
			if timer.times > 0 && timer.invocations >= timer.times {
				return true
			}
		}
	}

	return false
}

@(private)
timers_update :: proc(
	timers: ^[dynamic]Timer,
	now: time.Time,
	tick: time.Duration,
) {
	for i := len(timers) - 1; i >= 0; i -= 1 {
		if !timers[i].began {
			timers[i].began = true
			timers[i].until_next = timers[i].delay
		}
		if timer_update(&timers[i], now, tick) {
			unordered_remove(timers, i)
		}
	}
}
