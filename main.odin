package main

import "core:fmt"
import "core:mem"
import "core:time"
import "pink/app"
import "pink/render"

ctx: Context

Vertex :: struct {
	position: [2]f32,
	color: [3]f32,
}
Context :: struct {}

main :: proc() {
	tracker: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracker, context.allocator)
	defer mem.tracking_allocator_destroy(&tracker)
	context.allocator = mem.tracking_allocator(&tracker)
	defer if len(tracker.allocation_map) > 0 {
		fmt.eprintln()
		for _, v in tracker.allocation_map {
			fmt.eprintf("%v - leaked %v bytes\n", v.location, v.size)
		}
	}

	app.conf()
	app.load()

	buf: render.Buffer
	render.buffer_init(&buf)
	
	pipe: render.Pipeline
	shader: render.Shader
	render.shader_init_wgsl(&shader, #load("test.wgsl"))

	render.pipeline_init(
		&pipe,
		shader,
		[]render.Buffer_Layout{
			render.Buffer_Layout{
				usage = .Vertex,
				stride = size_of(Vertex),
				attributes = []render.Attribute{
					{type = [2]f32, offset = offset_of(Vertex, position)},
					{type = [3]f32, offset = offset_of(Vertex, color)},
				},
			},
		}
	)
	
	vertices := []Vertex{
		Vertex{{0.0, 0.0}, {1.0, 0.0, 0.0}},
		Vertex{{1.0, 0.0}, {0.0, 1.0, 0.0}},
		Vertex{{0.0, 1.0}, {0.0, 0.0, 1.0}},
	}
	render.buffer_copy(&buf, vertices)
	
	for !app.should_quit {
		app.frame_begin()
		pass := render.pass_begin()
		render.pass_set_buffers(&pass, buf)
		render.pass_end(pass)
		app.frame_end()
	}

	app.exit()
}
