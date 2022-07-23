package main

import "core:fmt"
import "core:mem"
import "core:image"
import "core:image/png"
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
		},
		[]render.Binding{
			{.Texture_Sampler},
		}
	)
	
	vertices := []Vertex{
		Vertex{{-1.0, 1.0}, {1.0, 1.0, 1.0}},
		Vertex{{1.0, 1.0}, {1.0, 1.0, 1.0}},
		Vertex{{-1.0, -1.0}, {1.0, 1.0, 1.0}},
		Vertex{{-1.0, -1.0}, {1.0, 1.0, 1.0}},
		Vertex{{1.0, 1.0}, {1.0, 1.0, 1.0}},
		Vertex{{1.0, -1.0}, {1.0, 1.0, 1.0}},
	}
	render.buffer_copy(&buf, vertices)
	
	img, ok := image.load_from_bytes(#load("examples/wut.png"), image.Options{.alpha_add_if_missing})	
	tex := render.Texture{
		width = uint(img.width),
		height = uint(img.height),
	}
	render.texture_init(&tex)
	render.texture_write(&tex, img.pixels.buf[:])
	image.destroy(img)
	
	for !app.should_quit {
		app.frame_begin()
		pass := render.pass_begin()
		render.pass_set_buffers(&pass, buf)
		render.pass_set_pipeline(&pass, pipe)
		render.pass_set_bind_texture(&pass, 0, tex)
		render.pass_draw(&pass, 0, 6)
		render.pass_end(pass)
		app.frame_end()
	}

	app.exit()
}
