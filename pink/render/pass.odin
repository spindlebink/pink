package pk_render

import "core:c"
import "wgpu"

PASS_MAX_BUFFERS :: 8

Pass :: struct {
	_buffers: [PASS_MAX_BUFFERS]wgpu.Buffer,
	_active_pipeline: wgpu.RenderPipeline,
	_wgpu_handle: wgpu.RenderPassEncoder,
}

pass_begin :: proc(target: Maybe(Texture) = nil) -> Pass {
	return Pass{
		_wgpu_handle = wgpu.CommandEncoderBeginRenderPass(
			_core.cmd_encoder,
			&wgpu.RenderPassDescriptor{
				colorAttachmentCount = 1,
				colorAttachments = &wgpu.RenderPassColorAttachment{
					view = target == nil ? _core.swap_tex_view : target.(Texture)._wgpu_view,
					loadOp = .Clear,
					storeOp = .Store,
					clearValue = wgpu.Color{0.0, 0.0, 0.0, 1.0},
				},
			},
		)
	}
}

pass_end :: proc(pass: Pass) {
	wgpu.RenderPassEncoderEnd(pass._wgpu_handle)
}

pass_set_pipeline :: proc(pass: ^Pass, pipeline: Pipeline) {
	if pass._active_pipeline != pipeline._wgpu_handle {
		pass._active_pipeline = pipeline._wgpu_handle
		wgpu.RenderPassEncoderSetPipeline(pass._wgpu_handle, pipeline._wgpu_handle)
	}
}

pass_set_buffer :: proc(pass: ^Pass, index: uint, buffer: Buffer) {
	assert(index < PASS_MAX_BUFFERS)
	if pass._buffers[index] != buffer._wgpu_handle {
		pass._buffers[index] = buffer._wgpu_handle
		wgpu.RenderPassEncoderSetVertexBuffer(
			pass._wgpu_handle,
			c.uint32_t(index),
			buffer._wgpu_handle,
			0,
			wgpu.WHOLE_SIZE,
		)
	}
}

pass_set_buffers :: #force_inline proc(pass: ^Pass, buffers: ..Buffer) {
	assert(len(buffers) <= PASS_MAX_BUFFERS)
	for buffer, i in buffers {
		pass_set_buffer(pass, uint(i), buffer)
	}
}

pass_draw :: proc(
	pass: ^Pass,
	vert_start: uint = 0,
	verts: uint = 3,
	inst_start: uint = 0,
	insts: uint = 1,
) {
	wgpu.RenderPassEncoderDraw(
		pass._wgpu_handle,
		c.uint32_t(verts),
		c.uint32_t(insts),
		c.uint32_t(vert_start),
		c.uint32_t(inst_start),
	)
}
