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
		_canvas_init_pipelines(canvas, renderer)
		render.vbuffer_queue_copy_data(renderer, &canvas.core.primitive_vertices)
	}

	render.vbuffer_queue_copy_data(renderer, &canvas.core.primitive_instances)
	render.vbuffer_queue_copy_data(renderer, &canvas.core.image_instances)

	// Write new renderer transformation matrix to transform buffer
	if renderer.size_changed || renderer.fresh {
		canvas.core.draw_state_buffer.data.window_to_device =
			render.context_compute_window_to_device_matrix(renderer)
		render.ubuffer_queue_copy_data(renderer, &canvas.core.draw_state_buffer)
	}

	// Vertex buffer 0 is currently always the primitive vertices
	// Images and primitives both only need very simple vertex data
	wgpu.RenderPassEncoderSetVertexBuffer(
		renderer.render_pass_encoder,
		0,
		canvas.core.primitive_vertices.ptr,
		0,
		wgpu.WHOLE_SIZE,
	)

	// Common canvas state used for modulation, global transform, etc. will always
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

	for i := 0; i < len(canvas.core.commands); i += 1 {
		command := canvas.core.commands[i]

		switch in command.data {
		
		//
		// Draw primitive
		//
		
		case Canvas_Draw_Primitive_Command:
			wgpu.RenderPassEncoderSetPipeline(
				renderer.render_pass_encoder,
				canvas.core.primitive_pipeline.pipeline,
			)
			wgpu.RenderPassEncoderSetVertexBuffer(
				renderer.render_pass_encoder,
				1,
				canvas.core.primitive_instances.ptr,
				0,
				wgpu.WHOLE_SIZE,
			)

			switch command.data.(Canvas_Draw_Primitive_Command).type {
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
		
		case Canvas_Draw_Image_Command:
			wgpu.RenderPassEncoderSetPipeline(
				renderer.render_pass_encoder,
				canvas.core.image_pipeline.pipeline,
			)
			wgpu.RenderPassEncoderSetVertexBuffer(
				renderer.render_pass_encoder,
				1,
				canvas.core.image_instances.ptr,
				0,
				wgpu.WHOLE_SIZE,
			)

			wgpu.RenderPassEncoderSetBindGroup(
				renderer.render_pass_encoder,
				1,
				_image_fetch_bind_group(
					command.data.(Canvas_Draw_Image_Command).image,
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
		
		}

	}

	clear(&canvas.core.commands)
}

