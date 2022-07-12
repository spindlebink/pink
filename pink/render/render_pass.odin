package pink_render

import "core:fmt"
import "core:c"
import "wgpu"

Render_Pass :: struct {
	// renderer: ^Renderer,
	encoder: wgpu.RenderPassEncoder,
	active_painter: rawptr,
}

render_pass_attach_painter :: proc(
	pass: ^Render_Pass,
	painter: ^$P/Painter,
) {
	if pass.active_painter != painter {
		wgpu.RenderPassEncoderSetPipeline(
			pass.encoder,
			painter.pipeline.handle,
		)
		wgpu.RenderPassEncoderSetVertexBuffer(
			pass.encoder,
			PAINTER_VERTICES_BUFFER_INDEX,
			painter.vertices.handle,
			0,
			wgpu.WHOLE_SIZE,
		)
		wgpu.RenderPassEncoderSetVertexBuffer(
			pass.encoder,
			PAINTER_INSTANCES_BUFFER_INDEX,
			painter.instances.handle,
			0,
			wgpu.WHOLE_SIZE,
		)
	}
}

render_pass_detach_painter :: proc(
	pass: ^Render_Pass,
) {
	pass.active_painter = nil
}

render_pass_bind :: proc(
	pass: Render_Pass,
	index: int,
	group: wgpu.BindGroup,
) {
	wgpu.RenderPassEncoderSetBindGroup(
		pass.encoder,
		c.uint32_t(index),
		group,
		0,
		nil,
	)
}

render_pass_bind_uniform_buffer :: proc(
	pass: Render_Pass,
	index: int,
	buffer: $U/Uniform_Buffer,
) {
	wgpu.RenderPassEncoderSetBindGroup(
		pass.encoder,
		c.uint32_t(index),
		buffer.bind_group,
		0,
		nil,
	)
}

render_pass_draw :: proc(
	pass: Render_Pass,
	vertex_start: uint = 0,
	vertices: uint = 3,
	instance_start: uint = 0,
	instances: uint = 1,
) {
	wgpu.RenderPassEncoderDraw(
		pass.encoder,
		c.uint32_t(vertices),
		c.uint32_t(instances),
		c.uint32_t(vertex_start),
		c.uint32_t(instance_start),
	)
}

render_pass_begin :: proc(
	ren: ^Renderer,
) -> Render_Pass {
	return Render_Pass {
		// renderer = ren,
		encoder = wgpu.CommandEncoderBeginRenderPass(
			ren.command_encoder,
			&wgpu.RenderPassDescriptor{
				colorAttachmentCount = 1,
				colorAttachments = &wgpu.RenderPassColorAttachment{
					view = ren.swap_texture_view,
					loadOp = .Clear,
					storeOp = .Store,
					clearValue = wgpu.Color{0.0, 0.0, 0.0, 1.0},
				},
			},
		),
	}
}

render_pass_end :: proc(
	pass: ^Render_Pass,
) {
	wgpu.RenderPassEncoderEnd(pass.encoder)
}
