package main

import "core:fmt"
import "core:mem"
import "core:time"
import "pink"

ctx: Context

Context :: struct {
	program: pink.Program,
}

main :: proc() {
	pink.program_load(&ctx.program)
	pink.program_run(&ctx.program)
	pink.program_exit(&ctx.program)
}
