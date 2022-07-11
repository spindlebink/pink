package pink

import "core:c"
import "core:math/linalg"
import "render"
import "render/wgpu"

@(private)
CANVAS_SHADER_HEADER :: #load("resources/shader_header.wgsl")

// Canvas context for immediate-mode rendering.
Canvas :: struct {
	draw_state: Canvas_Draw_State,
	core: Canvas_Core,
}

// Internal canvas state.
Canvas_Core :: struct {	
	commands: [dynamic]Canvas_Command,

	texture_bind_group_layout: wgpu.BindGroupLayout,

	draw_state_buffer: render.Uniform_Buffer(Canvas_Draw_State_Uniform),
	
	primitive_vertices: render.Vertex_Buffer(Canvas_Primitive_Vertex),
	
	primitive_shader: wgpu.ShaderModule,
	primitive_instances: render.Vertex_Buffer(Canvas_Primitive_Instance),
	primitive_pipeline: render.Pipeline,

	image_shader: wgpu.ShaderModule,
	image_instances: render.Vertex_Buffer(Canvas_Image_Instance),
	image_pipeline: render.Pipeline,

	slice_shader: wgpu.ShaderModule,
	slice_instances: render.Vertex_Buffer(Canvas_Slice_Instance),
	slice_pipeline: render.Pipeline,
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
	canvas.core.primitive_shader = render.shader_module_create(
		renderer,
		CANVAS_SHADER_HEADER,
		#load("resources/primitive_shader.wgsl"),
	)

	canvas.core.image_shader = render.shader_module_create(
		renderer,
		CANVAS_SHADER_HEADER,
		#load("resources/image_shader.wgsl"),
	)
	
	canvas.core.slice_shader = render.shader_module_create(
		renderer,
		CANVAS_SHADER_HEADER,
		#load("resources/slice_shader.wgsl"),
	)

	canvas.draw_state.color = {1.0, 1.0, 1.0, 1.0}

	canvas.core.primitive_vertices.usage_flags = {.Vertex, .CopyDst}
	canvas.core.primitive_instances.usage_flags = {.Vertex, .CopyDst}
	canvas.core.image_instances.usage_flags = {.Vertex, .CopyDst}
	canvas.core.slice_instances.usage_flags = {.Vertex, .CopyDst}

	reserve(&canvas.core.primitive_vertices.data, len(CANVAS_PRIMITIVE_VERTICES))
	for vertex in CANVAS_PRIMITIVE_VERTICES {
		append(&canvas.core.primitive_vertices.data, vertex)
	}

	canvas.core.draw_state_buffer.usage_flags = {.Uniform, .CopyDst}
	render.ubuffer_init(renderer, &canvas.core.draw_state_buffer)
}

// Destroys a canvas.
_canvas_destroy :: proc(
	canvas: ^Canvas,
) {
	render.pipeline_deinit(&canvas.core.primitive_pipeline)
	render.pipeline_deinit(&canvas.core.image_pipeline)

	render.vbuffer_destroy(&canvas.core.primitive_vertices)
	render.vbuffer_destroy(&canvas.core.primitive_instances)
	render.vbuffer_destroy(&canvas.core.image_instances)
	render.vbuffer_destroy(&canvas.core.slice_instances)

	render.ubuffer_destroy(&canvas.core.draw_state_buffer)

	wgpu.ShaderModuleDrop(canvas.core.primitive_shader)
	wgpu.ShaderModuleDrop(canvas.core.image_shader)
	wgpu.ShaderModuleDrop(canvas.core.slice_shader)

	delete(canvas.core.commands)
}

// Initializes a canvas's primitive and image pipelines.
_canvas_init_pipelines :: proc(
	canvas: ^Canvas,
	renderer: ^render.Context,
) {
	canvas.core.texture_bind_group_layout = renderer.basic_texture_bind_group_layout

	vertex_attributes := CANVAS_PRIMITIVE_VERTEX_ATTRIBUTES
	prim_instance_attributes := CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES
	img_instance_attributes := CANVAS_IMAGE_INSTANCE_ATTRIBUTES
	slice_instance_attributes := CANVAS_SLICE_INSTANCE_ATTRIBUTES

	render.wgpu_vertex_attr_offset_shader_location(vertex_attributes)

	prim_buffer_layout := wgpu.VertexBufferLayout{
		arrayStride = c.uint64_t(size_of(Canvas_Primitive_Vertex)),
		stepMode = .Vertex,
		attributeCount = c.uint32_t(len(vertex_attributes)),
		attributes = ([^]wgpu.VertexAttribute)(raw_data(vertex_attributes)),
	}

	// Initialize primitive pipeline

	render.wgpu_vertex_attr_offset_shader_location(
		prim_instance_attributes,
		len(vertex_attributes),
	)

	render.pipeline_init(
		renderer,
		&canvas.core.primitive_pipeline,
		render.Pipeline_Descriptor{
			label = "CanvasPrimitivePipeline",
			shader = canvas.core.primitive_shader,
			vertex_entry_point = "vertex_main",
			fragment_entry_point = "fragment_main",
			buffer_layouts = []wgpu.VertexBufferLayout{
				prim_buffer_layout,
				wgpu.VertexBufferLayout{
					arrayStride = c.uint64_t(size_of(Canvas_Primitive_Instance)),
					stepMode = .Instance,
					attributeCount = c.uint32_t(len(prim_instance_attributes)),
					attributes = ([^]wgpu.VertexAttribute)(raw_data(prim_instance_attributes)),
				},
			},
			bind_group_layouts = []wgpu.BindGroupLayout{
				canvas.core.draw_state_buffer.bind_group_layout,
			},
		},
	)

	// Initialize image pipeline

	render.wgpu_vertex_attr_offset_shader_location(
		img_instance_attributes,
		len(vertex_attributes),
	)

	render.pipeline_init(
		renderer,
		&canvas.core.image_pipeline,
		render.Pipeline_Descriptor{
			label = "CanvasImagePipeline",
			shader = canvas.core.image_shader,
			vertex_entry_point = "vertex_main",
			fragment_entry_point = "fragment_main",
			buffer_layouts = []wgpu.VertexBufferLayout{
				prim_buffer_layout,
				wgpu.VertexBufferLayout{
					arrayStride = c.uint64_t(size_of(Canvas_Image_Instance)),
					stepMode = .Instance,
					attributeCount = c.uint32_t(len(img_instance_attributes)),
					attributes = ([^]wgpu.VertexAttribute)(raw_data(img_instance_attributes)),
				},
			},
			bind_group_layouts = []wgpu.BindGroupLayout{
				canvas.core.draw_state_buffer.bind_group_layout,
				canvas.core.texture_bind_group_layout,
			},
		},
	)
	
	// Initialize slice pipeline
	
	render.wgpu_vertex_attr_offset_shader_location(
		slice_instance_attributes,
		len(vertex_attributes),
	)
	
	render.pipeline_init(
		renderer,
		&canvas.core.slice_pipeline,
		render.Pipeline_Descriptor{
			label = "CanvasSlicePipeline",
			shader = canvas.core.slice_shader,
			vertex_entry_point = "vertex_main",
			fragment_entry_point = "fragment_main",
			buffer_layouts = []wgpu.VertexBufferLayout{
				prim_buffer_layout,
				wgpu.VertexBufferLayout{
					arrayStride = c.uint64_t(size_of(Canvas_Slice_Instance)),
					stepMode = .Instance,
					attributeCount = c.uint32_t(len(slice_instance_attributes)),
					attributes =
						([^]wgpu.VertexAttribute)(raw_data(slice_instance_attributes)),
				},
			},
			bind_group_layouts = []wgpu.BindGroupLayout{
				canvas.core.draw_state_buffer.bind_group_layout,
				canvas.core.texture_bind_group_layout,
			},
		},
	)
}
