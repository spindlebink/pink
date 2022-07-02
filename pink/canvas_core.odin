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
	draw_state = Canvas_Draw_State{
		color = {1.0, 1.0, 1.0, 1.0},
	},
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

Canvas_State :: struct {
	pipeline: wgpu.RenderPipeline,
	prim_verts: Render_Buffer,
	prim_insts: Render_Buffer,
	prim_vert_data: []Canvas_Vertex,
	prim_inst_data: [dynamic]Canvas_Primitive_Instance,
	
	error: Canvas_Error,
	draw_items: [dynamic]Canvas_Draw_Item,
	draw_state: Canvas_Draw_State,
	draw_state_stack: [dynamic]Canvas_Draw_State_Memo,
}

// ************************************************************************** //
// Procedures
// ************************************************************************** //

// Initializes the canvas system.
canvas_init :: proc() -> bool {
	using canvas_state
	
	return true
}

canvas_append_draw_item :: proc(item_type: Canvas_Draw_Item_Type, count := 1) {
	using canvas_state
	
	if len(draw_items) > 0 {
		top := &draw_items[len(draw_items) - 1]
		if top.type == item_type {
			top.count += count
		} else {
			append(&draw_items, Canvas_Draw_Item{
				type = item_type,
				count = count,
			})
		}
	} else {
		append(&draw_items, Canvas_Draw_Item{
			type = item_type,
			count = count,
		})
	}
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
		render_device(),
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
					format = render_texture_format(),
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
	using canvas_state

	// Generate buffers
	
	if render_context_fresh() {
		canvas_recreate_pipeline()

		// Create the primitive vertex buffer only when the context is new
		render_buffer_ensure_size(
			&prim_verts,
			len(prim_vert_data) * size_of(Canvas_Vertex),
		)

		wgpu.QueueWriteBuffer(
			render_queue(),
			prim_verts.handle,
			0,
			raw_data(prim_vert_data),
			len(prim_vert_data) * size_of(Canvas_Vertex),
		)
	}
	
	if len(prim_inst_data) > 0 {
		data_size := len(prim_inst_data) * size_of(Canvas_Primitive_Instance)
		render_buffer_ensure_size(&prim_insts, data_size)

		wgpu.QueueWriteBuffer(
			render_queue(),
			prim_insts.handle,
			0,
			raw_data(prim_inst_data),
			c.size_t(data_size),
		)

		render_pass := render_render_pass_encoder()
	
		wgpu.RenderPassEncoderSetPipeline(render_pass, pipeline)
		wgpu.RenderPassEncoderSetVertexBuffer(
			render_pass,
			0,
			prim_verts.handle,
			0,
			wgpu.WHOLE_SIZE,
		)
		wgpu.RenderPassEncoderSetVertexBuffer(
			render_pass,
			1,
			prim_insts.handle,
			0,
			wgpu.WHOLE_SIZE,
		)
	
		current_inst := u32(0)
		for i := 0; i < len(draw_items); i += 1 {
			item := draw_items[i]
			switch item.type {
			case .Rect_Primitive:
				wgpu.RenderPassEncoderDraw(
					render_pass,
					6, // vertices per rect
					c.uint32_t(item.count),
					0,
					c.uint32_t(current_inst),
				)
			}
		}

		clear(&prim_inst_data)
		clear(&draw_items)
	}
}

// Shuts down the canvas system.
canvas_exit :: proc() -> bool {
	using canvas_state
	
	delete(prim_inst_data)
	delete(draw_items)
	delete(draw_state_stack)
	if prim_verts.handle != nil do wgpu.BufferDestroy(prim_verts.handle)
	if prim_insts.handle != nil do wgpu.BufferDestroy(prim_insts.handle)
	
	return true
}
