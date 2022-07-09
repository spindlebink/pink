package main

import "core:math/rand"
import "core:sort"
import "../pink"

NUM_RECTS :: 2800
MIN_RECT_SIDE :: 2
MAX_RECT_SIDE :: 40
ATLAS_SIZE :: 1024
RECT_DISPLAY_RATE :: 15.0

ctx: Context

Context :: struct {
	program: pink.Program,
	rects: [NUM_RECTS]pink.Rect,
	packed_count: int,
	displayed_rect: int,
	time_counter: f64,
}

on_load :: proc() {
	atlas: pink.Rect_Atlas
	failed_row_height := 0
	failed_x := ATLAS_SIZE + 40
	failed_y := 0
	
	for i := 0; i < NUM_RECTS; i += 1 {
		ctx.rects[i].w = int(rand.int31() % (MAX_RECT_SIDE - MIN_RECT_SIDE))
		ctx.rects[i].h = int(rand.int31() % (MAX_RECT_SIDE - MIN_RECT_SIDE))
		ctx.rects[i].w += MIN_RECT_SIDE
		ctx.rects[i].h += MIN_RECT_SIDE
	}
	
	sorter := sort.Interface{
		len = proc(it: sort.Interface) -> int {
			return NUM_RECTS
		},
		less = proc(it: sort.Interface, i, j: int) -> bool {
			arr := cast(^[NUM_RECTS]pink.Rect)it.collection
			return arr[i].w * arr[i].h > arr[j].w * arr[j].h
		},
		swap = proc(it: sort.Interface, i, j: int) {
			arr := cast(^[NUM_RECTS]pink.Rect)it.collection
			arr[i], arr[j] = arr[j], arr[i]
		},
		collection = &ctx.rects,
	}
	sort.sort(sorter)
	
	pink.rect_atlas_clear(&atlas, ATLAS_SIZE)

	for i := 0; i < NUM_RECTS; i += 1 {
		if packed := pink.rect_atlas_pack(&atlas, &ctx.rects[i]); !packed {
			ctx.rects[i].x = failed_x
			ctx.rects[i].y = failed_y
			failed_x += ctx.rects[i].w
			if failed_x > ATLAS_SIZE + 40 + ATLAS_SIZE {
				failed_x = ATLAS_SIZE + 40
				failed_y += failed_row_height
				failed_row_height = 0
			}
			if ctx.rects[i].h > failed_row_height {
				failed_row_height = ctx.rects[i].h
			}
		}
		// Shrink rects by a little so we can see their boundaries
		ctx.rects[i].w -= 2
		ctx.rects[i].h -= 2
	}
	
	pink.rect_atlas_destroy(&atlas)
}

on_update :: proc(delta: f64) {
	if ctx.displayed_rect < NUM_RECTS {
		ctx.time_counter -= delta
		if ctx.time_counter <= 0 {
			ctx.displayed_rect += 1
			ctx.time_counter = RECT_DISPLAY_RATE
		}
	}
}

on_draw :: proc() {
	for i := 0; i < NUM_RECTS; i += 1 {
		if i > ctx.displayed_rect do return
		if ctx.rects[i].x > ATLAS_SIZE {
			pink.canvas_set_color(&ctx.program.canvas, pink.Color{0.6, 0.12, 0.12, 1.0})
		} else {
			pink.canvas_set_color(&ctx.program.canvas, pink.PINK_PINK)
		}
		pink.canvas_draw_rect(
			&ctx.program.canvas,
			f32(ctx.rects[i].x),
			f32(ctx.rects[i].y),
			f32(ctx.rects[i].w),
			f32(ctx.rects[i].h),
		)
	}
}

main :: proc() {
	ctx.program.hooks.on_load = on_load
	ctx.program.hooks.on_update = on_update
	ctx.program.hooks.on_draw = on_draw
	
	pink.program_load(&ctx.program)
	pink.program_run(&ctx.program)
	pink.program_exit(&ctx.program)
}
