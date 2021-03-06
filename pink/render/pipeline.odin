package pk_render

import "core:fmt"
import "core:c"
import "core:intrinsics"
import "core:slice"
import "wgpu"

VERTEX_SHADER_ENTRY :: "vertex"
FRAGMENT_SHADER_ENTRY :: "fragment"

Pipeline :: struct {
	_wgpu_layout: wgpu.PipelineLayout,
	_wgpu_handle: wgpu.RenderPipeline,
}

pipeline_init :: proc(
	pipeline: ^Pipeline,
	shader: Shader,
	buffer_layouts: []Buffer_Layout,
	bindings: []Binding = {},
	push_constant_ranges: []Push_Constant = {},
) {
	layouts := make([]wgpu.VertexBufferLayout, len(buffer_layouts))
	attributes := make([][]wgpu.VertexAttribute, len(buffer_layouts))
	bind_layouts := make([]wgpu.BindGroupLayout, len(bindings))
	push_const_ranges := make([]wgpu.PushConstantRange, len(push_constant_ranges))
	defer delete(layouts)
	defer delete(attributes)
	defer for attr, i in attributes { delete(attributes[i]) }
	defer delete(bind_layouts)
	defer delete(push_const_ranges)
	
	// Create vertex buffer & bind group layouts
	
	shader_loc := 0
	for layout, i in buffer_layouts {
		attrs := make([]wgpu.VertexAttribute, len(layout.attributes))
		attributes[i] = attrs
		
		for attr, i in layout.attributes {
			attrs[i] = wgpu.VertexAttribute{
				shaderLocation = c.uint32_t(shader_loc + i),
				format = wgpu_format_from_attr(attr),
				offset = c.uint64_t(attr.offset),
			}
		}
		
		layouts[i] = wgpu.VertexBufferLayout{
			arrayStride = c.uint64_t(layout.stride),
			stepMode = layout.usage == .Instance ? .Instance : .Vertex,
			attributeCount = c.uint32_t(len(layout.attributes)),
			attributes = raw_data(attrs),
		}

		shader_loc += len(layout.attributes)
	}
	
	for bind_group, i in bindings {
		bind_layouts[i] = bind_group.type == .Texture_Sampler ? texture_bind_group_layout : uniform_bind_group_layout
	}

	push_loc := 0
	for range, i in push_constant_ranges {
		push_const_ranges[i] = wgpu_pcr_from_pcr(range)
		push_const_ranges[i].start = c.uint32_t(push_loc)
		push_loc += int(push_const_ranges[i].end)
		push_const_ranges[i].end += c.uint32_t(push_loc)
	}

	// Create the pipeline

	pipeline._wgpu_layout = wgpu.DeviceCreatePipelineLayout(
		_core.device,
		&wgpu.PipelineLayoutDescriptor{
			bindGroupLayoutCount = c.uint32_t(len(bind_layouts)),
			bindGroupLayouts = raw_data(bind_layouts),
			nextInChain = cast(^wgpu.ChainedStruct)&wgpu.PipelineLayoutExtras{
				chain = wgpu.ChainedStruct{
					next = nil,
					sType = wgpu.SType(wgpu.NativeSType.PipelineLayoutExtras),
				},
				pushConstantRangeCount = c.uint32_t(len(push_const_ranges)),
				pushConstantRanges = raw_data(push_const_ranges),
			},
		}
	)
	
	pipeline._wgpu_handle = wgpu.DeviceCreateRenderPipeline(
		_core.device,
		&wgpu.RenderPipelineDescriptor{
			layout = pipeline._wgpu_layout,
			vertex = wgpu.VertexState{
				module = shader._wgpu_handle,
				entryPoint = cstring(VERTEX_SHADER_ENTRY),
				bufferCount = c.uint32_t(len(layouts)),
				buffers = raw_data(layouts),
			},
			fragment = &wgpu.FragmentState{
				module = shader._wgpu_handle,
				entryPoint = cstring(FRAGMENT_SHADER_ENTRY),
				targetCount = 1,
				targets = &wgpu.ColorTargetState{
					format = _core.ren_tex_format,
					writeMask = wgpu.ColorWriteMaskFlagsAll,
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

pipeline_destroy :: proc(pipeline: Pipeline) {
	if pipeline._wgpu_layout != nil { wgpu.PipelineLayoutDrop(pipeline._wgpu_layout) }
	if pipeline._wgpu_handle != nil { wgpu.RenderPipelineDrop(pipeline._wgpu_handle) }
}
