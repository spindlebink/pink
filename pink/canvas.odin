package pink

import "core:c"
import "core:fmt"
import "core:math/linalg"
import "wgpu"

Canvas :: struct {
	_core_shader: wgpu.ShaderModule,
	_draw_state: Canvas_Draw_State,
	_draw_commands: [dynamic]Canvas_Draw_Command,
	_camera_buffer: wgpu.Buffer,
	_camera_bind_group: wgpu.BindGroup,
	_camera_bind_group_layout: wgpu.BindGroupLayout,
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

Canvas_Draw_State :: struct {
	color: Color,
}

Canvas_Draw_State_Memo :: struct {
	mode: enum {
		Transform,
		Style,
		All,
	},
	state: Canvas_Draw_State,
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

	canvas._draw_state.color = {1.0, 1.0, 1.0, 1.0}

	canvas._primitive_pipeline.instances.usage_flags = {.Vertex, .CopyDst}
	canvas._image_pipeline.instances.usage_flags = {.Vertex, .CopyDst}
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

_canvas_init_camera :: proc(
	canvas: ^Canvas,
	renderer: ^Renderer,
) {
	group_entries := []wgpu.BindGroupLayoutEntry{
		wgpu.BindGroupLayoutEntry{
			binding = 0,
			visibility = {.Vertex},
			buffer = wgpu.BufferBindingLayout{
				type = .Uniform,
			},
		},
	}

	canvas._camera_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		renderer.device,
		&wgpu.BindGroupLayoutDescriptor{
			label = "CanvasCameraUniformBindGroupLayout",
			entryCount = c.uint32_t(len(group_entries)),
			entries = cast([^]wgpu.BindGroupLayoutEntry)raw_data(group_entries),
		},
	)

	canvas._camera_buffer = wgpu.DeviceCreateBuffer(
		renderer.device,
		&wgpu.BufferDescriptor{
			usage = {.Uniform, .CopyDst},
			size = c.uint64_t(size_of(linalg.Matrix4x4f32)),
		},
	)

	bind_entries := []wgpu.BindGroupEntry{
		wgpu.BindGroupEntry{
			binding = 0,
			buffer = canvas._camera_buffer,
			size = c.uint64_t(size_of(linalg.Matrix4x4f32)),
		},
	}

	canvas._camera_bind_group = wgpu.DeviceCreateBindGroup(
		renderer.device,
		&wgpu.BindGroupDescriptor{
			layout = canvas._camera_bind_group_layout,
			entryCount = c.uint32_t(len(bind_entries)),
			entries = cast([^]wgpu.BindGroupEntry)raw_data(bind_entries),
		},
	)
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

		if bind_group_layout != nil {
			wgpu.BindGroupLayoutDrop(bind_group_layout)
		}
		if pipeline_layout != nil {
			wgpu.PipelineLayoutDrop(pipeline_layout)
		}
		if pipeline != nil {
			wgpu.RenderPipelineDrop(pipeline)
		}

		group_layouts := []wgpu.BindGroupLayout{
			canvas._camera_bind_group_layout,
		}

		pipeline_layout = wgpu.DeviceCreatePipelineLayout(
			renderer.device,
			&wgpu.PipelineLayoutDescriptor{
				label = "CanvasPrimitivePipelineLayout",
				bindGroupLayoutCount = c.uint32_t(len(group_layouts)),
				bindGroupLayouts = cast([^]wgpu.BindGroupLayout)raw_data(group_layouts),
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

	// Initialize image pipeline
	{
		using canvas._image_pipeline

		if bind_group_layout != nil {
			wgpu.BindGroupLayoutDrop(bind_group_layout)
		}
		if pipeline_layout != nil {
			wgpu.PipelineLayoutDrop(pipeline_layout)
		}
		if pipeline != nil {
			wgpu.RenderPipelineDrop(pipeline)
		}

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

		group_layouts := []wgpu.BindGroupLayout{
			canvas._camera_bind_group_layout,
			bind_group_layout,
		}

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
}

_canvas_flush_commands :: proc(
	canvas: ^Canvas,
	renderer: ^Renderer,
) {
	// Copy primitive vertices to buffer if it's a new rendering context
	if renderer.fresh {
		_canvas_init_camera(canvas, renderer)
		_canvas_init_pipelines(canvas, renderer)
		if canvas._primitive_vertices != nil {
			wgpu.BufferDestroy(canvas._primitive_vertices)
			wgpu.BufferDrop(canvas._primitive_vertices)
		}
		primitive_vertices := CANVAS_PRIMITIVE_VERTICES
		vertices_size := len(primitive_vertices) * size_of(Canvas_Primitive_Vertex)
		canvas._primitive_vertices = wgpu.DeviceCreateBuffer(
			renderer.device,
			&wgpu.BufferDescriptor{
				usage = {.Vertex, .CopyDst},
				size = c.uint64_t(vertices_size),
			},
		)
		wgpu.QueueWriteBuffer(
			renderer.queue,
			canvas._primitive_vertices,
			0,
			raw_data(primitive_vertices),
			c.size_t(vertices_size),
		)
	}

	_dynamic_buffer_copy(&canvas._primitive_pipeline.instances, renderer)
	_dynamic_buffer_copy(&canvas._image_pipeline.instances, renderer)

	// TODO: don't re-send if it doesn't change?
	{
		w_s := 2.0 / f32(renderer.render_width)
		h_s := 2.0 / f32(renderer.render_height)
		window_to_device := linalg.Matrix4x4f32{
			w_s, 0.0, 0.0, 0.0,
			0.0, h_s, 0.0, 0.0,
			0.0, 0.0, 1.0, 0.0,
			-1.0, 1.0, 0.0, 1.0,
		}

		wgpu.QueueWriteBuffer(
			renderer.queue,
			canvas._camera_buffer,
			0,
			&window_to_device,
			c.size_t(size_of(linalg.Matrix4x4f32)),
		)
	}

	curr_primitive := 0
	curr_image := 0

	// Vertex buffer 0 is currently always the primitive vertices
	// Images and primitives both only need very simple vertex data
	wgpu.RenderPassEncoderSetVertexBuffer(
		renderer.render_pass_encoder,
		0,
		canvas._primitive_vertices,
		0,
		wgpu.WHOLE_SIZE,
	)

	wgpu.RenderPassEncoderSetBindGroup(
		renderer.render_pass_encoder,
		0,
		canvas._camera_bind_group,
		0,
		nil,
	)

	for i := 0; i < len(canvas._draw_commands); i += 1 {
		command := canvas._draw_commands[i]

		switch in command.data {
		
		case Canvas_Draw_Primitive_Command:
			wgpu.RenderPassEncoderSetPipeline(
				renderer.render_pass_encoder,
				canvas._primitive_pipeline.pipeline,
			)
			wgpu.RenderPassEncoderSetVertexBuffer(
				renderer.render_pass_encoder,
				1,
				canvas._primitive_pipeline.instances.ptr,
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
		
		case Canvas_Draw_Image_Command:
			wgpu.RenderPassEncoderSetPipeline(
				renderer.render_pass_encoder,
				canvas._image_pipeline.pipeline,
			)
			wgpu.RenderPassEncoderSetVertexBuffer(
				renderer.render_pass_encoder,
				1,
				canvas._image_pipeline.instances.ptr,
				0,
				wgpu.WHOLE_SIZE,
			)

			wgpu.RenderPassEncoderSetBindGroup(
				renderer.render_pass_encoder,
				1,
				_image_fetch_bind_group(
					command.data.(Canvas_Draw_Image_Command).image,
					canvas,
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

	clear(&canvas._draw_commands)
}
