package pink

import "core:c"
import "wgpu"

Canvas :: struct {
	_core_shader: wgpu.ShaderModule,
	_draw_commands: [dynamic]Canvas_Draw_Command,
	_primitive_vertices: wgpu.Buffer,
	_primitive_pipeline: Canvas_Pipeline(Canvas_Primitive_Instance),
	_image_pipeline: Canvas_Pipeline(Canvas_Primitive_Instance),
}

Canvas_Pipeline :: struct($Instance: typeid) {
	bind_group_layout: wgpu.BindGroupLayout,
	pipeline_layout: wgpu.PipelineLayout,
	pipeline: wgpu.RenderPipeline,
	instances: Dynamic_Buffer(Instance),
}

// Initializes a canvas.
_canvas_init :: proc(
	canvas: ^Canvas,
	renderer: ^Renderer,
) {
	canvas._core_shader = wgpu.DeviceCreateShaderModule(
		renderer.device,
		&wgpu.ShaderModuleDescriptor{
			nextInChain = cast(^wgpu.ChainedStruct)&wgpu.ShaderModuleWGSLDescriptor{
				chain = wgpu.ChainedStruct{
					sType = .ShaderModuleWGSLDescriptor,
				},
				code = cast(cstring)raw_data(#load("shader.wgsl")),
			},
		},
	)

	_canvas_init_pipelines(canvas, renderer)
}

// Destroys a canvas.
_canvas_destroy :: proc(
	canvas: ^Canvas,
) {
	// wgpu.BindGroupLayoutDrop(canvas._primitive_pipeline.bind_group_layout)
	wgpu.PipelineLayoutDrop(canvas._primitive_pipeline.pipeline_layout)
	wgpu.RenderPipelineDrop(canvas._primitive_pipeline.pipeline)

	wgpu.BindGroupLayoutDrop(canvas._image_pipeline.bind_group_layout)
	wgpu.PipelineLayoutDrop(canvas._image_pipeline.pipeline_layout)
	wgpu.RenderPipelineDrop(canvas._image_pipeline.pipeline)

	_dynamic_buffer_destroy(&canvas._primitive_pipeline.instances)
	_dynamic_buffer_destroy(&canvas._image_pipeline.instances)

	wgpu.ShaderModuleDrop(canvas._core_shader)
	delete(canvas._draw_commands)
}

// Initializes a canvas's primitive and image pipelines.
_canvas_init_pipelines :: proc(
	canvas: ^Canvas,
	renderer: ^Renderer,
) {
	vertex_attributes := CANVAS_PRIMITIVE_VERTEX_ATTRIBUTES
	instance_attributes := CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES

	buffer_layouts := []wgpu.VertexBufferLayout{
		wgpu.VertexBufferLayout{
			arrayStride = c.uint64_t(size_of(Canvas_Primitive_Vertex)),
			stepMode = .Vertex,
			attributeCount = c.uint32_t(len(vertex_attributes)),
			attributes = cast([^]wgpu.VertexAttribute)raw_data(vertex_attributes),
		},
		wgpu.VertexBufferLayout{
			arrayStride = c.uint64_t(size_of(Canvas_Primitive_Instance)),
			stepMode = .Instance,
			attributeCount = c.uint32_t(len(instance_attributes)),
			attributes = cast([^]wgpu.VertexAttribute)raw_data(instance_attributes),
		},
	}

	// Initialize primitive pipeline
	{
		using canvas._primitive_pipeline

		pipeline_layout = wgpu.DeviceCreatePipelineLayout(
			renderer.device,
			&wgpu.PipelineLayoutDescriptor{
				label = "CanvasPrimitivePipelineLayout",
			},
		)

		pipeline = wgpu.DeviceCreateRenderPipeline(
			renderer.device,
			&wgpu.RenderPipelineDescriptor{
				label = "CanvasPrimitivePipeline",
				layout = pipeline_layout,
				vertex = wgpu.VertexState{
					module = canvas._core_shader,
					entryPoint = "prim_vertex_main",
					bufferCount = c.uint32_t(len(buffer_layouts)),
					buffers = cast([^]wgpu.VertexBufferLayout)raw_data(buffer_layouts),
				},
				fragment = &wgpu.FragmentState{
					module = canvas._core_shader,
					entryPoint = "prim_fragment_main",
					targetCount = 1,
					targets = &wgpu.ColorTargetState{
						format = renderer.render_texture_format,
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
					cullMode = .None,
				},
				multisample = wgpu.MultisampleState{
					count = 1,
					mask = wgpu.MultisampleStateMaskMax,
				},
			},
		)
	}

	// Initialize image pipeline
	{
		using canvas._image_pipeline

		group_entries := []wgpu.BindGroupLayoutEntry{
			wgpu.BindGroupLayoutEntry{
				binding = 0,
				visibility = {.Fragment},
				texture = wgpu.TextureBindingLayout{
					multisampled = false,
					viewDimension = .D2,
					sampleType = .Float,
				},
			},
			wgpu.BindGroupLayoutEntry{
				binding = 1,
				visibility = {.Fragment},
				sampler = wgpu.SamplerBindingLayout{
					type = .Filtering,
				},
			},
		}

		bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
			renderer.device,
			&wgpu.BindGroupLayoutDescriptor{
				label = "CanvasImagePipelineBindGroupLayout",
				entryCount = c.uint32_t(len(group_entries)),
				entries = cast([^]wgpu.BindGroupLayoutEntry)raw_data(group_entries),
			},
		)

		group_layouts := []wgpu.BindGroupLayout{bind_group_layout}

		pipeline_layout = wgpu.DeviceCreatePipelineLayout(
			renderer.device,
			&wgpu.PipelineLayoutDescriptor{
				label = "CanvasImagePipelineLayout",
				bindGroupLayoutCount = c.uint32_t(len(group_layouts)),
				bindGroupLayouts = cast([^]wgpu.BindGroupLayout)raw_data(group_layouts),
			},
		)

		pipeline = wgpu.DeviceCreateRenderPipeline(
			renderer.device,
			&wgpu.RenderPipelineDescriptor{
				label = "CanvasImagePipeline",
				layout = pipeline_layout,
				vertex = wgpu.VertexState{
					module = canvas._core_shader,
					entryPoint = "img_vertex_main",
					bufferCount = c.uint32_t(len(buffer_layouts)),
					buffers = cast([^]wgpu.VertexBufferLayout)raw_data(buffer_layouts),
				},
				fragment = &wgpu.FragmentState{
					module = canvas._core_shader,
					entryPoint = "img_fragment_main",
					targetCount = 1,
					targets = &wgpu.ColorTargetState{
						format = renderer.render_texture_format,
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
					cullMode = .None,
				},
				multisample = wgpu.MultisampleState{
					count = 1,
					mask = wgpu.MultisampleStateMaskMax,
				},
			},
		)
	}
}
