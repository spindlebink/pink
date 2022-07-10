package pink

import "core:c"
import "wgpu"

// Structure to hold a pipeline layout and render pipeline as a bundle.
Renderer_Pipeline :: struct {
	layout: wgpu.PipelineLayout,
	pipeline: wgpu.RenderPipeline,
}

// Simplified pipeline descriptor containing only the information we actually
// use for Pink's renderer pipelines.
Renderer_Pipeline_Descriptor :: struct {
	label: string,
	shader: wgpu.ShaderModule,
	vertex_entry_point: string,
	fragment_entry_point: string,
	buffer_layouts: []wgpu.VertexBufferLayout,
	bind_group_layouts: []wgpu.BindGroupLayout,
}

// Initializes a renderer pipeline using a descriptor.
renderer_pipeline_init :: proc(
	renderer: ^Renderer,
	pipeline: ^Renderer_Pipeline,
	desc: Renderer_Pipeline_Descriptor,
) {
	pipeline.layout = wgpu.DeviceCreatePipelineLayout(
		renderer.device,
		&wgpu.PipelineLayoutDescriptor{
			label = cstring(raw_data(desc.label)),
			bindGroupLayoutCount = c.uint32_t(len(desc.bind_group_layouts)),
			bindGroupLayouts = ([^]wgpu.BindGroupLayout)(raw_data(desc.bind_group_layouts)),
		},
	)
	
	pipeline.pipeline = wgpu.DeviceCreateRenderPipeline(
		renderer.device,
		&wgpu.RenderPipelineDescriptor{
			label = cstring(raw_data(desc.label)),
			layout = pipeline.layout,
			vertex = wgpu.VertexState{
				module = desc.shader,
				entryPoint = cstring(raw_data(desc.vertex_entry_point)),
				bufferCount = c.uint32_t(len(desc.buffer_layouts)),
				buffers = ([^]wgpu.VertexBufferLayout)(raw_data(desc.buffer_layouts)),
			},
			fragment = &wgpu.FragmentState{
				module = desc.shader,
				entryPoint = cstring(raw_data(desc.fragment_entry_point)),
				targetCount = 1,
				targets = &wgpu.ColorTargetState{
					format = renderer.render_texture_format,
					blend = &wgpu.BlendState{
						color = wgpu.BlendComponent{
							srcFactor = .SrcAlpha,
							dstFactor = .OneMinusSrcAlpha,
							operation = .Add,
						},
						alpha = wgpu.BlendComponent{
							srcFactor = .SrcAlpha,
							dstFactor = .OneMinusSrcAlpha,
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
				cullMode = .None,
			},
			multisample = wgpu.MultisampleState{
				count = 1,
				mask = wgpu.MultisampleStateMaskMax,
			},
		},
	)
}

// Deinitializes a renderer pipeline.
renderer_pipeline_deinit :: proc(
	pipeline: ^Renderer_Pipeline,
) {
	wgpu.RenderPipelineDrop(pipeline.pipeline)
	wgpu.PipelineLayoutDrop(pipeline.layout)
}
