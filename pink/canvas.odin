package pink

import "core:c"
import "core:fmt"
import "core:math/linalg"
import "render"
import "render/wgpu"

// Canvas context for immediate-mode rendering.
Canvas :: struct {
	draw_state: Canvas_Draw_State,
	core: Canvas_Core,
}

// Internal canvas state.
Canvas_Core :: struct {	
	draw_commands: [dynamic]Canvas_Draw_Command,
	shader: wgpu.ShaderModule,

	texture_bind_group_layout: wgpu.BindGroupLayout,
	
	core_buffer: wgpu.Buffer,
	core_bind_group: wgpu.BindGroup,
	core_bind_group_layout: wgpu.BindGroupLayout,
	
	primitive_vertices: wgpu.Buffer,
	
	primitive_instances: render.Buffer(Canvas_Primitive_Instance),
	primitive_pipeline: render.Pipeline,

	image_instances: render.Buffer(Canvas_Primitive_Instance),
	image_pipeline: render.Pipeline,
}

// Canvas's current color and transform.
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
	renderer: ^render.Context,
) {
	canvas.core.shader = wgpu.DeviceCreateShaderModule(
		renderer.device,
		&wgpu.ShaderModuleDescriptor{
			nextInChain = cast(^wgpu.ChainedStruct)&wgpu.ShaderModuleWGSLDescriptor{
				chain = wgpu.ChainedStruct{
					sType = .ShaderModuleWGSLDescriptor,
				},
				code = cast(cstring)raw_data(#load("res/shader.wgsl")),
			},
		},
	)

	canvas.draw_state.color = {1.0, 1.0, 1.0, 1.0}

	canvas.core.primitive_instances.usage_flags = {.Vertex, .CopyDst}
	canvas.core.image_instances.usage_flags = {.Vertex, .CopyDst}
}

// Destroys a canvas.
_canvas_destroy :: proc(
	canvas: ^Canvas,
) {
	render.pipeline_deinit(&canvas.core.primitive_pipeline)
	render.pipeline_deinit(&canvas.core.image_pipeline)

	render.buffer_destroy(&canvas.core.primitive_instances)
	render.buffer_destroy(&canvas.core.image_instances)

	wgpu.ShaderModuleDrop(canvas.core.shader)
	delete(canvas.core.draw_commands)
}

_canvas_init_core_uniform :: proc(
	canvas: ^Canvas,
	renderer: ^render.Context,
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

	canvas.core.core_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		renderer.device,
		&wgpu.BindGroupLayoutDescriptor{
			label = "CanvasDataUniformBindGroupLayout",
			entryCount = c.uint32_t(len(group_entries)),
			entries = cast([^]wgpu.BindGroupLayoutEntry)raw_data(group_entries),
		},
	)

	canvas.core.core_buffer = wgpu.DeviceCreateBuffer(
		renderer.device,
		&wgpu.BufferDescriptor{
			usage = {.Uniform, .CopyDst},
			size = c.uint64_t(size_of(linalg.Matrix4x4f32)),
		},
	)

	bind_entries := []wgpu.BindGroupEntry{
		wgpu.BindGroupEntry{
			binding = 0,
			buffer = canvas.core.core_buffer,
			size = c.uint64_t(size_of(linalg.Matrix4x4f32)),
		},
	}

	canvas.core.core_bind_group = wgpu.DeviceCreateBindGroup(
		renderer.device,
		&wgpu.BindGroupDescriptor{
			layout = canvas.core.core_bind_group_layout,
			entryCount = c.uint32_t(len(bind_entries)),
			entries = ([^]wgpu.BindGroupEntry)(raw_data(bind_entries)),
		},
	)
}

// Initializes a canvas's primitive and image pipelines.
_canvas_init_pipelines :: proc(
	canvas: ^Canvas,
	renderer: ^render.Context,
) {
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

	canvas.core.texture_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		renderer.device,
		&wgpu.BindGroupLayoutDescriptor{
			label = "CanvasImagePipelineBindGroupLayout",
			entryCount = c.uint32_t(len(group_entries)),
			entries = ([^]wgpu.BindGroupLayoutEntry)(raw_data(group_entries)),
		},
	)

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

	render.pipeline_init(
		renderer,
		&canvas.core.primitive_pipeline,
		render.Pipeline_Descriptor{
			label = "CanvasPrimitivePipeline",
			shader = canvas.core.shader,
			vertex_entry_point = "prim_vertex_main",
			fragment_entry_point = "prim_fragment_main",
			buffer_layouts = buffer_layouts,
			bind_group_layouts = []wgpu.BindGroupLayout{
				canvas.core.core_bind_group_layout,
			},
		},
	)

	// Initialize image pipeline

	render.pipeline_init(
		renderer,
		&canvas.core.image_pipeline,
		render.Pipeline_Descriptor{
			label = "CanvasImagePipeline",
			shader = canvas.core.shader,
			vertex_entry_point = "img_vertex_main",
			fragment_entry_point = "img_fragment_main",
			buffer_layouts = buffer_layouts,
			bind_group_layouts = []wgpu.BindGroupLayout{
				canvas.core.core_bind_group_layout,
				canvas.core.texture_bind_group_layout,
			},
		},
	)
}

_canvas_flush_commands :: proc(
	canvas: ^Canvas,
	renderer: ^render.Context,
) {
	// Copy primitive vertices to buffer if it's a new rendering context
	if renderer.fresh {
		_canvas_init_core_uniform(canvas, renderer)
		_canvas_init_pipelines(canvas, renderer)
		if canvas.core.primitive_vertices != nil {
			wgpu.BufferDestroy(canvas.core.primitive_vertices)
			wgpu.BufferDrop(canvas.core.primitive_vertices)
		}
		primitive_vertices := CANVAS_PRIMITIVE_VERTICES
		vertices_size := len(primitive_vertices) * size_of(Canvas_Primitive_Vertex)
		canvas.core.primitive_vertices = wgpu.DeviceCreateBuffer(
			renderer.device,
			&wgpu.BufferDescriptor{
				usage = {.Vertex, .CopyDst},
				size = c.uint64_t(vertices_size),
			},
		)
		wgpu.QueueWriteBuffer(
			renderer.queue,
			canvas.core.primitive_vertices,
			0,
			raw_data(primitive_vertices),
			c.size_t(vertices_size),
		)
	}

	render.buffer_queue_copy_data(renderer, &canvas.core.primitive_instances)
	render.buffer_queue_copy_data(renderer, &canvas.core.image_instances)

	// TODO: don't re-send if it doesn't change/better way of sending core data
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
			canvas.core.core_buffer,
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
		canvas.core.primitive_vertices,
		0,
		wgpu.WHOLE_SIZE,
	)

	wgpu.RenderPassEncoderSetBindGroup(
		renderer.render_pass_encoder,
		0,
		canvas.core.core_bind_group,
		0,
		nil,
	)

	for i := 0; i < len(canvas.core.draw_commands); i += 1 {
		command := canvas.core.draw_commands[i]

		switch in command.data {
		
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

	clear(&canvas.core.draw_commands)
}
