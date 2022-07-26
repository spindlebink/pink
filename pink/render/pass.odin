package pk_render

import "core:c"
import "wgpu"

PASS_MAX_BUFFERS :: 8
PASS_MAX_BIND_GROUPS :: MAX_BIND_GROUPS

Pass :: struct {
	_buffers: [PASS_MAX_BUFFERS]wgpu.Buffer,
	_bind_groups: [PASS_MAX_BIND_GROUPS]wgpu.BindGroup,
	_active_pipeline: wgpu.RenderPipeline,
	_wgpu_handle: wgpu.RenderPassEncoder,
}

pass_begin :: proc(
	target: Maybe(Texture) = nil,
	clear_color: [4]f32 = {0.0, 0.0, 0.0, 1.0},
) -> Pass {
	return Pass{
		_wgpu_handle = wgpu.CommandEncoderBeginRenderPass(
			_core.cmd_encoder,
			&wgpu.RenderPassDescriptor{
				colorAttachmentCount = 1,
				colorAttachments = &wgpu.RenderPassColorAttachment{
					view = target == nil ? _core.swap_tex_view : target.(Texture)._wgpu_view,
					loadOp = .Clear,
					storeOp = .Store,
					clearValue = wgpu.Color{
						c.double(clear_color.r),
						c.double(clear_color.g),
						c.double(clear_color.b),
						c.double(clear_color.a),
					},
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

pass_set_binding_uniform :: proc(pass: ^Pass, index: uint, uniform: Buffer) {
	assert(uniform.usage == .Uniform && index < PASS_MAX_BIND_GROUPS)
	if pass._bind_groups[index] != uniform._wgpu_ubind {
		pass._bind_groups[index] = uniform._wgpu_ubind
		wgpu.RenderPassEncoderSetBindGroup(
			pass._wgpu_handle,
			c.uint32_t(index),
			uniform._wgpu_ubind,
			0,
			nil,
		)
	}
}

pass_set_binding_texture :: proc(pass: ^Pass, index: uint, texture: Texture) {
	if pass._bind_groups[index] != texture._wgpu_bind_group {
		pass._bind_groups[index] = texture._wgpu_bind_group
		wgpu.RenderPassEncoderSetBindGroup(
			pass._wgpu_handle,
			c.uint32_t(index),
			texture._wgpu_bind_group,
			0,
			nil,
		)
	}
}

when USE_PUSH_CONSTANTS {

pass_set_push_constants :: proc(pass: ^Pass, data: $D) {
	d := data
	wgpu.RenderPassEncoderSetPushConstants(
		pass._wgpu_handle,
		{.Vertex, .Fragment},
		0,
		size_of(D),
		&d,
	)
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
