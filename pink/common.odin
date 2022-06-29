//+private
package pink

import "core:c"
import "core:fmt"
import "core:os"
import "core:thread"
import "core:time"
import "wgpu/wgpu"

// ************************************************************************** //
// Runtime
// ************************************************************************** //

Config :: struct {
	window_title: string,
	window_width: u32,
	window_height: u32,
	framerate_fixed: f64,
	framerate_cap: f64,
}

DEFAULT_CONFIG :: Config{
	window_title = "Window",
	window_width = 800,
	window_height = 600,
	framerate_fixed = 60.0,
	framerate_cap = 120.0,
}

config_fill_defaults :: proc(config: ^Config) {
	if config.window_title == "" {
		config.window_title = DEFAULT_CONFIG.window_title
	}
	if config.window_width == 0 {
		config.window_width = DEFAULT_CONFIG.window_width
	}
	if config.window_height == 0 {
		config.window_height = DEFAULT_CONFIG.window_height
	}
	if config.framerate_fixed == 0.0 {
		config.framerate_fixed = DEFAULT_CONFIG.framerate_fixed
	}
	if config.framerate_cap == 0.0 {
		config.framerate_cap = DEFAULT_CONFIG.framerate_cap
	}
}

// ************************************************************************** //
// Dirty Array
// ************************************************************************** //

DIRTY_ARRAY_CAPACITY_SHRINK_THRESHOLD := 0.5
Dirty_Array :: struct($Data: typeid) {
	data: [dynamic]Data,
	head: int,
}

dirty_array_push :: proc(array: ^Dirty_Array($Data), item: Data) {
	if array.head < len(array.data) {
		array.data[array.head] = item
	} else {
		append(&array.data, item)
	}
	array.head += 1
}

dirty_array_clean :: proc(array: ^Dirty_Array($Data)) {
	if array.head < int(f64(cap(&array.data)) * DIRTY_ARRAY_CAPACITY_SHRINK_THRESHOLD) {
		clear(&array.data)
		array.head = 0
	} else {
		array.head = 0
	}
}

dirty_array_reset :: proc(array: ^Dirty_Array($Data)) {
	array.head = 0
}

dirty_array_clear :: proc(array: ^Dirty_Array($Data)) {
	clear(&array.data)
	array.head = 0
}

// ************************************************************************** //
// Debug
// ************************************************************************** //

SCOPE_STACK_SIZE :: 32

debug_scope_stack: [SCOPE_STACK_SIZE]string
debug_scope_head := 0

debug_scope_push :: proc(scope_name: string) {
	fmt.assertf(debug_scope_head < SCOPE_STACK_SIZE - 1, "debug scope stack overflow")
	debug_scope_stack[debug_scope_head] = scope_name
	debug_scope_head += 1
}

debug_scope_pop :: proc() {
	if debug_scope_head > 0 {
		debug_scope_head -= 1
	}
}

debug_print :: proc(message: string, traceback := true) {
	fmt.eprintln(message)
	if traceback {
		for i := debug_scope_head - 1; i >= 0; i -= 1 {
			if i == debug_scope_head - 1 {
				fmt.eprintf("  during %s\n", debug_scope_stack[i])
			} else {
				fmt.eprintf("  in %s\n", debug_scope_stack[i])
			}
		}
	}
}

debug_assert :: proc(what: bool, message: string) -> bool {
	if !what {
		debug_print(message)
		return false
	} else {
		return true
	}
}

debug_assert_fatal :: proc(what: bool, message: string) -> bool {
	if !what {
		fmt.eprintf("Fatal error: ")
		debug_print(message)
		os.exit(1)
	} else {
		return true
	}
}

