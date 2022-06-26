//+private
package pink

import "core:c"
import "core:fmt"
import "core:mem"
import "wgpu/wgpu"

render_state: struct {
	swap_chain: wgpu.SwapChain,
	texture_format: wgpu.TextureFormat,
	render_pipeline: wgpu.RenderPipeline,

	command_encoder: wgpu.CommandEncoder,
	render_pass_encoder: wgpu.RenderPassEncoder,

	vertex_buffer_size: u64,
	vertex_buffer: wgpu.Buffer,
	index_buffer_size: u64,
	index_buffer: wgpu.Buffer,
}

render_init :: proc() {
	render_state.texture_format = wgpu.SurfaceGetPreferredFormat(
		graphics_state.surface,
		graphics_state.adapter,
	)
	
	core_shader := create_wgsl_shader_module(
		graphics_state.device,
		#load("shader.wgsl"),
	)
	
	vertex_attributes := [ATTRIBUTE_COUNT]wgpu.VertexAttribute{
		wgpu.VertexAttribute{
			offset = cast(c.uint64_t) offset_of(Vertex, position),
			shaderLocation = 0,
			format = .Float32x2,
		},
		wgpu.VertexAttribute{
			offset = cast(c.uint64_t) offset_of(Vertex, color),
			shaderLocation = 1,
			format = .Float32x4,
		},
		wgpu.VertexAttribute{
			offset = cast(c.uint64_t) offset_of(Vertex, texture_coord),
			shaderLocation = 2,
			format = .Float32x2,
		},
	}

	vertex_buffer_layout := wgpu.VertexBufferLayout{
		arrayStride = cast(c.uint64_t) size_of(Vertex),
		stepMode = .Vertex,
		attributeCount = ATTRIBUTE_COUNT,
		attributes = cast([^]wgpu.VertexAttribute) &vertex_attributes,
	}

	render_state.render_pipeline = wgpu.DeviceCreateRenderPipeline(
		graphics_state.device,
		&wgpu.RenderPipelineDescriptor{
			label = "Render pipeline",
			layout = wgpu.DeviceCreatePipelineLayout(
				graphics_state.device,
				&wgpu.PipelineLayoutDescriptor{},
			),
			vertex = wgpu.VertexState{
				module = core_shader,
				entryPoint = "vertex_main",
				bufferCount = 1,
				buffers = &vertex_buffer_layout,
			},
			fragment = &wgpu.FragmentState{
				module = core_shader,
				entryPoint = "fragment_main",
				targetCount = 1,
				targets = &wgpu.ColorTargetState{
					format = render_state.texture_format,
					blend = &wgpu.BlendState{
						color = wgpu.BlendComponent{
							srcFactor = .One,
							dstFactor = .Zero,
							operation = .Add,
						},
						alpha = wgpu.BlendComponent{
							srcFactor = .One,
							dstFactor = .Zero,
							operation = .Add,
						},
					},
					writeMask = wgpu.ColorWriteMaskFlagsAll,
				},
			},
			primitive = wgpu.PrimitiveState{
				topology = .TriangleList,
				stripIndexFormat = .Undefined,
				frontFace = .CW,
				cullMode = .Back,
			},
			multisample = wgpu.MultisampleState{
				count = 1,
				mask = wgpu.MultisampleStateMaskMax,
			},
		},
	)
	
	render_rebuild_swap_chain()
}

render_rebuild_swap_chain :: proc() {
	fmt.println("Rebuilding swap chain")
	render_state.swap_chain = wgpu.DeviceCreateSwapChain(
		graphics_state.device,
		graphics_state.surface,
		&wgpu.SwapChainDescriptor{
			usage = {.RenderAttachment},
			format = render_state.texture_format,
			width = cast(c.uint32_t) window_state.width,
			height = cast(c.uint32_t) window_state.height,
			presentMode = .Fifo,
		},
	)
}

render_destroy :: proc() {
	if render_state.vertex_buffer != nil {
		wgpu.BufferDestroy(render_state.vertex_buffer)
	}
	if render_state.index_buffer != nil {
		wgpu.BufferDestroy(render_state.index_buffer)
	}
}

render_gen_vertex_buffer :: proc() {
	// until renderer is actually written, we only want to generate the VB once
	@(static) dbg_already_gen := false
	
	if dbg_already_gen do return
	dbg_already_gen = true
	
	fmt.println("Generating POC vertex buffer")
	
	vertices := renderer_poc_vertices()
	render_state.vertex_buffer = wgpu.DeviceCreateBuffer(
		graphics_state.device,
		&wgpu.BufferDescriptor{
			usage = {.Vertex},
			size = cast(c.uint64_t) (size_of(Vertex) * len(vertices)),
			mappedAtCreation = true,
		},
	)
	
	render_state.index_buffer = wgpu.DeviceCreateBuffer(
		graphics_state.device,
		&wgpu.BufferDescriptor{
			usage = {.Index},
			size = cast(c.uint64_t) (size_of(c.uint16_t) * len(QUAD_INDICES)),
			mappedAtCreation = true,
		},
	)
	
	range := wgpu.BufferGetMappedRange(
		render_state.vertex_buffer,
		0,
		cast(c.size_t) (size_of(Vertex) * len(vertices)),
	)
	mem.copy(range, &vertices, size_of(Vertex) * len(vertices))
	wgpu.BufferUnmap(render_state.vertex_buffer) 

	quad_indices := QUAD_INDICES
	index_range := wgpu.BufferGetMappedRange(
		render_state.index_buffer,
		0,
		cast(c.size_t) (size_of(c.uint16_t) * len(QUAD_INDICES)),
	)
	mem.copy(index_range, &quad_indices, size_of(c.uint16_t) * len(quad_indices))
	wgpu.BufferUnmap(render_state.index_buffer)
}

render_exec :: proc() {
	render_gen_vertex_buffer()
	
	next_texture := wgpu.SwapChainGetCurrentTextureView(render_state.swap_chain)
	
	if next_texture == nil {
		panic("Could not acquire next swap chain texture")
	}
	command_encoder := wgpu.DeviceCreateCommandEncoder(
		graphics_state.device,
		&wgpu.CommandEncoderDescriptor{},
	)

	render_pass := wgpu.CommandEncoderBeginRenderPass(
		command_encoder,
		&wgpu.RenderPassDescriptor{
			label = "Render pass",
			colorAttachments = &wgpu.RenderPassColorAttachment{
				view = next_texture,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = wgpu.Color{0.0, 0.0, 0.0, 1.0},
			},
			colorAttachmentCount = 1,
		},
	)

	wgpu.RenderPassEncoderSetPipeline(
		render_pass,
		render_state.render_pipeline,
	)
	wgpu.RenderPassEncoderSetVertexBuffer(
		render_pass,
		0,
		render_state.vertex_buffer,
		0,
		wgpu.WHOLE_SIZE,
	)
	wgpu.RenderPassEncoderSetIndexBuffer(
		render_pass,
		render_state.index_buffer,
		.Uint16,
		0,
		wgpu.WHOLE_SIZE,
	)

	// BEGIN DRAW CALLS
	
	wgpu.RenderPassEncoderDrawIndexed(
		render_pass,
		len(QUAD_INDICES),
		1,
		0,
		0,
		0,
	)
	
	// END DRAW CALLS

	wgpu.RenderPassEncoderEnd(render_pass)

	queue := wgpu.DeviceGetQueue(graphics_state.device)
	cmd_buffer := wgpu.CommandEncoderFinish(
		command_encoder,
		&wgpu.CommandBufferDescriptor{},
	)
	
	wgpu.QueueSubmit(queue, 1, &cmd_buffer)
	wgpu.SwapChainPresent(render_state.swap_chain)
}
