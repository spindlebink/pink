package pink

import "core:fmt"
import "core:c"
import "core:math/linalg"
import "render"
import "render/wgpu"

CANVAS_STATE_STACK_SIZE :: 1024

// Canvas context for immediate-mode rendering.
Canvas :: struct {
	using draw_state: Canvas_Draw_State,
	core: Canvas_Core,
}

// Canvas's current color and transform.
Canvas_Draw_State :: struct {
	color: Color,
	translation: [2]f32,
	rotation: f32,
}

@(private)
CANVAS_SHADER_HEADER :: #load("resources/shader_header.wgsl")

// Internal canvas state.
@(private)
Canvas_Core :: struct {
	render_pass: render.Render_Pass,
	state_stack: [CANVAS_STATE_STACK_SIZE]Canvas_State_Memo,
	state_head: int,
	commands: [dynamic]Canvas_Cmd_Invocation,
	draw_state_buffer: render.Uniform_Buffer(Canvas_Draw_State_Uniform),
	primitive_shader,
	image_shader,
	slice_shader,
	glyph_shader: wgpu.ShaderModule,
	prims: render.Painter(Canvas_Primitive_Vertex, Canvas_Primitive_Instance),
	imgs: render.Painter(Canvas_Primitive_Vertex, Canvas_Image_Instance),
	slices: render.Painter(Canvas_Primitive_Vertex, Canvas_Slice_Instance),
	glyphs: render.Painter(Canvas_Primitive_Vertex, Canvas_Slice_Instance),
}

// Initializes a canvas.
@(private)
canvas_init :: proc(
	canvas: ^Canvas,
	renderer: ^render.Renderer,
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
	
	canvas.core.glyph_shader = render.shader_module_create(
		renderer,
		CANVAS_SHADER_HEADER,
		#load("resources/glyph_shader.wgsl"),
	)

	canvas.draw_state.color = {1.0, 1.0, 1.0, 1.0}

	render.painter_append_verts(&canvas.core.prims, CANVAS_PRIMITIVE_VERTICES)
	render.painter_append_verts(&canvas.core.imgs, CANVAS_PRIMITIVE_VERTICES)
	render.painter_append_verts(&canvas.core.slices, CANVAS_PRIMITIVE_VERTICES)
	render.painter_append_verts(&canvas.core.glyphs, CANVAS_PRIMITIVE_VERTICES)

	render.ubuffer_init(renderer, &canvas.core.draw_state_buffer)

	render.painter_init(
		&canvas.core.prims,
		renderer,
		render.Painter_Descriptor{
			shader = canvas.core.primitive_shader,
			vertex_entry_point = "vertex_main",
			fragment_entry_point = "fragment_main",
			vertex_attributes = CANVAS_PRIMITIVE_VERTEX_ATTRIBUTES,
			instance_attributes = CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES,
			bind_group_layouts = []wgpu.BindGroupLayout{
				canvas.core.draw_state_buffer.bind_group_layout,
			},
		},
	)

	render.painter_init(
		&canvas.core.imgs,
		renderer,
		render.Painter_Descriptor{
			shader = canvas.core.image_shader,
			vertex_entry_point = "vertex_main",
			fragment_entry_point = "fragment_main",
			vertex_attributes = CANVAS_PRIMITIVE_VERTEX_ATTRIBUTES,
			instance_attributes = CANVAS_IMAGE_INSTANCE_ATTRIBUTES,
			bind_group_layouts = []wgpu.BindGroupLayout{
				canvas.core.draw_state_buffer.bind_group_layout,
				renderer.texture_bind_group_layout,
			},
		},
	)

	render.painter_init(
		&canvas.core.slices,
		renderer,
		render.Painter_Descriptor{
			shader = canvas.core.slice_shader,
			vertex_entry_point = "vertex_main",
			fragment_entry_point = "fragment_main",
			vertex_attributes = CANVAS_PRIMITIVE_VERTEX_ATTRIBUTES,
			instance_attributes = CANVAS_SLICE_INSTANCE_ATTRIBUTES,
			bind_group_layouts = []wgpu.BindGroupLayout{
				canvas.core.draw_state_buffer.bind_group_layout,
				renderer.texture_bind_group_layout,
			},
		},
	)

	render.painter_init(
		&canvas.core.glyphs,
		renderer,
		render.Painter_Descriptor{
			shader = canvas.core.glyph_shader,
			vertex_entry_point = "vertex_main",
			fragment_entry_point = "fragment_main",
			vertex_attributes = CANVAS_PRIMITIVE_VERTEX_ATTRIBUTES,
			instance_attributes = CANVAS_SLICE_INSTANCE_ATTRIBUTES,
			bind_group_layouts = []wgpu.BindGroupLayout{
				canvas.core.draw_state_buffer.bind_group_layout,
				renderer.texture_bind_group_layout,
			},
		},
	)
}

// Destroys a canvas.
@(private)
canvas_destroy :: proc(
	canvas: ^Canvas,
) {
	render.painter_destroy(&canvas.core.prims)
	render.painter_destroy(&canvas.core.imgs)
	render.painter_destroy(&canvas.core.slices)
	render.painter_destroy(&canvas.core.glyphs)

	render.ubuffer_destroy(&canvas.core.draw_state_buffer)

	delete(canvas.core.commands)
}
