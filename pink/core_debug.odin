package pink

import "core:fmt"
import "core:os"

@(private)
SCOPE_STACK_SIZE :: 32

@(private)
debug_scope_stack: [SCOPE_STACK_SIZE]string

@(private)
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
