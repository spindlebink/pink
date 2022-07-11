package pink

import "core:c"
import "render"
import "render/wgpu"

// Flushes all draw commands from the canvas to the GPU. Called at the end of a
// frame.
_canvas_flush :: proc(
	canvas: ^Canvas,
	renderer: ^render.Context,
) {
	if renderer.fresh {
		_canvas_init(canvas, renderer)
		render.vbuffer_queue_copy_data(renderer, &canvas.core.prims.vertices)
		render.vbuffer_queue_copy_data(renderer, &canvas.core.imgs.vertices)
		render.vbuffer_queue_copy_data(renderer, &canvas.core.slices.vertices)
	}

	render.vbuffer_queue_copy_data(renderer, &canvas.core.prims.instances)
	render.vbuffer_queue_copy_data(renderer, &canvas.core.imgs.instances)
	render.vbuffer_queue_copy_data(renderer, &canvas.core.slices.instances)

	// Write new renderer transformation matrix to transform buffer
	if renderer.size_changed || renderer.fresh {
		canvas.core.draw_state_buffer.data.window_to_device =
			render.context_compute_window_to_device_matrix(renderer)
		render.ubuffer_queue_copy_data(renderer, &canvas.core.draw_state_buffer)
	}

	// Common canvas state used for global transform, etc. will always
	// be in slot 0
	wgpu.RenderPassEncoderSetBindGroup(
		renderer.render_pass_encoder,
		0,
		canvas.core.draw_state_buffer.bind_group,
		0,
		nil,
	)

	curr_primitive := 0
	curr_image := 0
	curr_slice := 0

	for i := 0; i < len(canvas.core.commands); i += 1 {
		command := canvas.core.commands[i]

		switch in command.data {
		
		//
		// Draw primitive
		//
		
		case Canvas_Draw_Primitive_Cmd:
			render.context_attach_painter(renderer, &canvas.core.prims)
			switch command.data.(Canvas_Draw_Primitive_Cmd).type {
			case .Rect:
				wgpu.RenderPassEncoderDraw(
					renderer.render_pass_encoder,
					6, // vertices per rect
					c.uint32_t(command.times),
					0,
					c.uint32_t(curr_primitive),
				)
			}

			curr_primitive += command.times
		
		//
		// Draw image
		//
		
		case Canvas_Draw_Img_Cmd:
			render.context_attach_painter(renderer, &canvas.core.imgs)

			wgpu.RenderPassEncoderSetBindGroup(
				renderer.render_pass_encoder,
				1, // textures go in bind group 1 b/c global canvas state goes in 0--TODO: use constants for future-proofing
				_image_fetch_bind_group(
					command.data.(Canvas_Draw_Img_Cmd).image,
					renderer,
				),
				0,
				nil,
			)
			wgpu.RenderPassEncoderDraw(
				renderer.render_pass_encoder,
				6, // vertices per rect
				c.uint32_t(command.times),
				0,
				c.uint32_t(curr_image),
			)
			
			curr_image += command.times
		
		
		//
		// Draw slice
		//
		
		case Canvas_Draw_Slice_Cmd:
			render.context_attach_painter(renderer, &canvas.core.slices)

			wgpu.RenderPassEncoderSetBindGroup(
				renderer.render_pass_encoder,
				1,
				_image_fetch_bind_group(
					command.data.(Canvas_Draw_Slice_Cmd).image,
					renderer,
				),
				0,
				nil,
			)
			wgpu.RenderPassEncoderDraw(
				renderer.render_pass_encoder,
				6, // vertices per rect
				c.uint32_t(command.times),
				0,
				c.uint32_t(curr_slice),
			)
			
			curr_slice += command.times
	
		}
	}

	clear(&canvas.core.commands)
}

