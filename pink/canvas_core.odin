//+private
package pink

import "core:c"
import "wgpu/wgpu"

canvas_state := Canvas_State{
	prim_verts = Render_Buffer{
		usage_flags = {.Vertex, .CopyDst},
	},
	prim_insts = Render_Buffer{
		usage_flags = {.Vertex, .CopyDst},
	},
	prim_vert_data = PRIMITIVE_VERTS,
}

// ************************************************************************** //
// Type Definitions
// ************************************************************************** //

PRIMITIVE_VERTS := []Canvas_Vertex{
	Canvas_Vertex{{-1.0, -1.0}},
	Canvas_Vertex{{1.0, -1.0}},
	Canvas_Vertex{{-1.0, 1.0}},
	Canvas_Vertex{{-1.0, 1.0}},
	Canvas_Vertex{{1.0, -1.0}},
	Canvas_Vertex{{1.0, 1.0}},
}

Canvas_Vertex :: struct {
	position: [2]f32,
}

Canvas_Primitive_Instance :: struct {
	translation: [2]f32,
	scale: [2]f32,
	rotation: f32,
	modulation: [4]f32,
}

Canvas_Draw_Item_Type :: enum {
	Rect_Primitive,
}

Canvas_Draw_Item :: struct {
	type: Canvas_Draw_Item_Type,
	count: int,
}

Canvas_State :: struct {
	pipeline: wgpu.RenderPipeline,
	prim_verts: Render_Buffer,
	prim_insts: Render_Buffer,
	prim_vert_data: []Canvas_Vertex,
	prim_inst_data: [dynamic]Canvas_Primitive_Instance,
	
	error: Canvas_Error,
	draw_items: [dynamic]Canvas_Draw_Item,
}

// ************************************************************************** //
// Procedures
// ************************************************************************** //

// Initializes the canvas system.
canvas_init :: proc() -> bool {
	using canvas_state
	
	return true
}

// Recreates the canvas render pipeline.
canvas_recreate_pipeline :: proc() {
	using canvas_state
	
	core_shader_module := render_shader_module_create_wgsl(#load("shader.wgsl"))

	// Attribute layouts

	prim_verts_attrs := []wgpu.VertexAttribute{
		wgpu.VertexAttribute{
			offset = c.uint64_t(offset_of(Canvas_Vertex, position)),
			shaderLocation = 0,
			format = .Float32x2,
		},
	}

	prim_verts_layout := wgpu.VertexBufferLayout{
		arrayStride = c.uint64_t(size_of(Canvas_Vertex)),
		stepMode = .Vertex,
		attributeCount = 1,
		attributes = cast([^]wgpu.VertexAttribute) raw_data(prim_verts_attrs),
	}

	prim_insts_attrs := []wgpu.VertexAttribute{
		wgpu.VertexAttribute{
			offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, translation)),
			shaderLocation = 1,
			format = .Float32x2,
		},
		wgpu.VertexAttribute{
			offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, scale)),
			shaderLocation = 2,
			format = .Float32x2,
		},
		wgpu.VertexAttribute{
			offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, rotation)),
			shaderLocation = 3,
			format = .Float32,
		},
		wgpu.VertexAttribute{
			offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, modulation)),
			shaderLocation = 4,
			format = .Float32x4,
		},
	}
	
	prim_insts_layout := wgpu.VertexBufferLayout{
		arrayStride = c.uint64_t(size_of(Canvas_Primitive_Instance)),
		stepMode = .Instance,
		attributeCount = 4,
		attributes = cast([^]wgpu.VertexAttribute) raw_data(prim_insts_attrs),
	}

	vert_buffer_layouts := []wgpu.VertexBufferLayout{
		prim_verts_layout,
		prim_insts_layout,
	}
	
	// Pipeline
	
	pipeline = wgpu.DeviceCreateRenderPipeline(
		render_state.device,
		&wgpu.RenderPipelineDescriptor{
			label = "Canvas Render Pipeline",
			layout = wgpu.DeviceCreatePipelineLayout(
				render_state.device,
				&wgpu.PipelineLayoutDescriptor{},
			),
			vertex = wgpu.VertexState{
				module = core_shader_module,
				entryPoint = "vertex_main",
				bufferCount = 2,
				buffers = cast([^]wgpu.VertexBufferLayout) raw_data(vert_buffer_layouts),
			},
			fragment = &wgpu.FragmentState{
				module = core_shader_module,
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
				cullMode = .None,
			},
			multisample = wgpu.MultisampleState{
				count = 1,
				mask = wgpu.MultisampleStateMaskMax,
			},
		},
	)
}

// Renders all queued draw commands.
canvas_render :: proc() {
	if render_context_fresh() do canvas_recreate_pipeline()
}

canvas_exit :: proc() -> bool {
	using canvas_state
	
	if prim_verts.handle != nil do wgpu.BufferDestroy(prim_verts.handle)
	if prim_insts.handle != nil do wgpu.BufferDestroy(prim_insts.handle)
	
	return true
}
