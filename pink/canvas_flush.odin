package pink

import "core:c"
import "render"
import "render/wgpu"

// Flushes all draw commands from the canvas to the GPU. Called at the end of a
// frame.
@(private)
canvas_flush :: proc(
	canvas: ^Canvas,
	renderer: ^render.Renderer,
) {
	if renderer.fresh {
		canvas_init(canvas, renderer)
		render.vbuffer_queue_copy_data(renderer, &canvas.core.prims.vertices)
		render.vbuffer_queue_copy_data(renderer, &canvas.core.imgs.vertices)
		render.vbuffer_queue_copy_data(renderer, &canvas.core.slices.vertices)
		render.vbuffer_queue_copy_data(renderer, &canvas.core.glyphs.vertices)
	}

	render.vbuffer_queue_copy_data(renderer, &canvas.core.prims.instances)
	render.vbuffer_queue_copy_data(renderer, &canvas.core.imgs.instances)
	render.vbuffer_queue_copy_data(renderer, &canvas.core.slices.instances)
	render.vbuffer_queue_copy_data(renderer, &canvas.core.glyphs.instances)

	// Write new renderer transformation matrix to transform buffer
	if renderer.size_changed || renderer.fresh {
		canvas.core.draw_state_buffer.data.window_to_device =
			render.renderer_compute_window_to_device_matrix(renderer)
		render.ubuffer_queue_copy_data(renderer, &canvas.core.draw_state_buffer)
	}

	canvas.core.render_pass = render.render_pass_begin(renderer)

	// Common canvas state used for global transform, etc. will always
	// be in slot 0
	render.render_pass_bind_uniform_buffer(
		canvas.core.render_pass,
		0,
		canvas.core.draw_state_buffer,
	)

	curr_primitive, curr_image, curr_slice, curr_glyph: uint

	for i := 0; i < len(canvas.core.commands); i += 1 {
		command := canvas.core.commands[i]

		switch in command.data {
		
		//
		// Draw primitive
		//
		
		case Canvas_Draw_Primitive_Cmd:
			render.render_pass_attach_painter(
				&canvas.core.render_pass,
				&canvas.core.prims,
			)

			switch command.data.(Canvas_Draw_Primitive_Cmd).type {
			case .Rect:
				render.render_pass_draw(
					canvas.core.render_pass,
					0, // Rectangle primitive starts at 0
					6, // and there are 6 vertices per rectangle primitive
					curr_primitive,
					command.times,
				)
			}

			curr_primitive += command.times
		
		//
		// Draw image
		//
		
		case Canvas_Draw_Img_Cmd:
			render.render_pass_attach_painter(&canvas.core.render_pass, &canvas.core.imgs)
			render.render_pass_bind(
				canvas.core.render_pass,
				1,
				image_fetch_bind_group(
					command.data.(Canvas_Draw_Img_Cmd).image,
					renderer,
				),
			)
			render.render_pass_draw(
				canvas.core.render_pass,
				0,
				6,
				curr_image,
				command.times,
			)

			curr_image += command.times
		
		
		//
		// Draw slice
		//
		
		case Canvas_Draw_Slice_Cmd:
			render.render_pass_attach_painter(&canvas.core.render_pass, &canvas.core.slices)
			render.render_pass_bind(
				canvas.core.render_pass,
				1,
				image_fetch_bind_group(
					command.data.(Canvas_Draw_Slice_Cmd).image,
					renderer,
				),
			)
			render.render_pass_draw(
				canvas.core.render_pass,
				0,
				6,
				curr_slice,
				command.times,
			)

			curr_slice += command.times
		
		
		//
		// Draw glyph
		//
		
		case Canvas_Draw_Glyph_Cmd:
			glyph_cmd := command.data.(Canvas_Draw_Glyph_Cmd)
			glyphset_ensure_flushed(glyph_cmd.glyphset, renderer)
			
			render.render_pass_attach_painter(&canvas.core.render_pass, &canvas.core.glyphs)
			render.render_pass_bind(
				canvas.core.render_pass,
				1,
				glyph_cmd.glyphset.core.pages[glyph_cmd.page].bind_group,
			)
			render.render_pass_draw(
				canvas.core.render_pass,
				0,
				6,
				curr_glyph,
				command.times,
			)
			
			curr_glyph += command.times
		}
	}

	clear(&canvas.core.commands)
	render.render_pass_end(&canvas.core.render_pass)
}
