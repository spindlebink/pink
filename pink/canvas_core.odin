//+private
package pink

import "core:c"
import "core:fmt"
import "core:reflect"
import "wgpu/wgpu"

canvas_state := Canvas_State{
	prim_verts = Render_Buffer{
		usage_flags = {.Vertex, .CopyDst},
	},
	prim_insts = Render_Buffer{
		usage_flags = {.Vertex, .CopyDst},
	},
	img_insts = Render_Buffer{
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

PRIMITIVE_VERTS := []Canvas_Primitive_Vertex{
	Canvas_Primitive_Vertex{{-1.0, -1.0}},
	Canvas_Primitive_Vertex{{1.0, -1.0}},
	Canvas_Primitive_Vertex{{-1.0, 1.0}},
	Canvas_Primitive_Vertex{{-1.0, 1.0}},
	Canvas_Primitive_Vertex{{1.0, -1.0}},
	Canvas_Primitive_Vertex{{1.0, 1.0}},
}

Canvas_Primitive_Vertex :: struct {
	position: [2]f32,
}

Canvas_Primitive_Instance :: struct {
	translation: [2]f32,
	scale: [2]f32,
	rotation: f32,
	modulation: [4]f32,
}

Canvas_Primitive_Type :: enum {
	Rect,
}

Canvas_Draw_Primitive_Data :: struct {
	type: Canvas_Primitive_Type,
}

Canvas_Draw_Image_Data :: struct {
	image: ^Image,
}

Canvas_Draw_Data :: union {
	Canvas_Draw_Primitive_Data,
	Canvas_Draw_Image_Data,
}

Canvas_Draw_Item :: struct {
	data: Canvas_Draw_Data,
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
	prim_pipeline: wgpu.RenderPipeline,
	prim_verts: Render_Buffer,
	prim_insts: Render_Buffer,
	prim_vert_data: []Canvas_Primitive_Vertex,
	prim_inst_data: [dynamic]Canvas_Primitive_Instance,
	img_pipeline: wgpu.RenderPipeline,
	img_insts: Render_Buffer,
	img_inst_data: [dynamic]Canvas_Primitive_Instance,
	core_shader_module: wgpu.ShaderModule,
	tex_bind_group_layout: wgpu.BindGroupLayout,
	active_pipeline: wgpu.RenderPipeline,
	
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

	core_shader_module = render_shader_module_create_wgsl(#load("shader.wgsl"))
	
	return true
}

// Returns the canvas's bind group layout.
canvas_tex_bind_group_layout :: proc() -> wgpu.BindGroupLayout { return canvas_state.tex_bind_group_layout }

// Appends a draw item to the draw items queue.
canvas_append_draw_item :: proc(
	data: Canvas_Draw_Data,
	count := 1,
) {
	using canvas_state
	
	if len(draw_items) > 0 {
		top := &draw_items[len(draw_items) - 1]
		
		if reflect.union_variant_typeid(top.data) == reflect.union_variant_typeid(data) {
			switch in data {
			// Check primitive draw items
			case Canvas_Draw_Primitive_Data:
				if data.(Canvas_Draw_Primitive_Data).type == top^.data.(Canvas_Draw_Primitive_Data).type {
					top.count += count
					return
				}

			// Check image draw items
			case Canvas_Draw_Image_Data:
				if data.(Canvas_Draw_Image_Data).image == top^.data.(Canvas_Draw_Image_Data).image {
					top.count += count
					return
				}

			}
			
			// if we reach here, the top item differs from the current item, so fall
			// through to append it to the draw_items queue--can't batch it
		}
	}

	append(&draw_items, Canvas_Draw_Item{data, count})
}

// Recreates the canvas render prim_pipeline.
canvas_recreate_pipeline :: proc() {
	using canvas_state
	
	device := render_device()
	
	/*
	
	Attributes
	
	*/

	prim_verts_attrs := []wgpu.VertexAttribute{
		wgpu.VertexAttribute{
			offset = c.uint64_t(offset_of(Canvas_Primitive_Vertex, position)),
			shaderLocation = 0,
			format = .Float32x2,
		},
	}

	prim_verts_layout := wgpu.VertexBufferLayout{
		arrayStride = c.uint64_t(size_of(Canvas_Primitive_Vertex)),
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
	
	/*
	
	Primitive pipeline

	*/
	
	prim_pipeline = wgpu.DeviceCreateRenderPipeline(
		device,
		&wgpu.RenderPipelineDescriptor{
			label = "CanvasRenderPrimitivePipeline",
			layout = wgpu.DeviceCreatePipelineLayout(
				device,
				&wgpu.PipelineLayoutDescriptor{},
			),
			vertex = wgpu.VertexState{
				module = core_shader_module,
				entryPoint = "prim_vertex_main",
				bufferCount = 2,
				buffers = cast([^]wgpu.VertexBufferLayout) raw_data(vert_buffer_layouts),
			},
			fragment = &wgpu.FragmentState{
				module = core_shader_module,
				entryPoint = "prim_fragment_main",
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
	
	/*
	
	Image pipeline
	
	*/
	
	bg_layout_entries := []wgpu.BindGroupLayoutEntry{
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
	
	tex_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		device,
		&wgpu.BindGroupLayoutDescriptor{
			label = "ImgBindGroupLayout",
			entryCount = 2,
			entries = cast([^]wgpu.BindGroupLayoutEntry) raw_data(bg_layout_entries),
		},
	)
	
	bind_group_layouts := []wgpu.BindGroupLayout{
		tex_bind_group_layout,
	}
	
	img_pipeline = wgpu.DeviceCreateRenderPipeline(
		device,
		&wgpu.RenderPipelineDescriptor{
			label = "CanvasRenderImgPipeline",
			layout = wgpu.DeviceCreatePipelineLayout(
				device,
				&wgpu.PipelineLayoutDescriptor{
					label = "ImgPipelineLayout",
					bindGroupLayoutCount = 1,
					bindGroupLayouts = cast([^]wgpu.BindGroupLayout) raw_data(bind_group_layouts),
				},
			),
			vertex = wgpu.VertexState{
				module = core_shader_module,
				entryPoint = "img_vertex_main",
				bufferCount = 2,
				buffers = cast([^]wgpu.VertexBufferLayout) raw_data(vert_buffer_layouts),
			},
			fragment = &wgpu.FragmentState{
				module = core_shader_module,
				entryPoint = "img_fragment_main",
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

	render_pass := render_render_pass_encoder()
	render_queue := render_queue()
	
	if render_context_fresh() {
		canvas_recreate_pipeline()
		render_buffer_ensure_size(
			&prim_verts,
			len(prim_vert_data) * size_of(Canvas_Primitive_Vertex),
		)
		wgpu.QueueWriteBuffer(
			render_queue,
			prim_verts.handle,
			0,
			raw_data(prim_vert_data),
			len(prim_vert_data) * size_of(Canvas_Primitive_Vertex),
		)
	}

	// Copy primitive instance data to buffer
	if len(prim_inst_data) > 0 {
		data_size := len(prim_inst_data) * size_of(Canvas_Primitive_Instance)
		render_buffer_ensure_size(&prim_insts, data_size)
		wgpu.QueueWriteBuffer(
			render_queue,
			prim_insts.handle,
			0,
			raw_data(prim_inst_data),
			c.size_t(data_size),
		)
	}
	
	// Copy image instance data to buffer
	if len(img_inst_data) > 0 {
		data_size := len(img_inst_data) * size_of(Canvas_Primitive_Instance)
		render_buffer_ensure_size(&img_insts, data_size)
		wgpu.QueueWriteBuffer(
			render_queue,
			img_insts.handle,
			0,
			raw_data(img_inst_data),
			c.size_t(data_size),
		)
	}
	
	if len(draw_items) > 0 {
		wgpu.RenderPassEncoderSetVertexBuffer(
			render_pass,
			0,
			prim_verts.handle,
			0,
			wgpu.WHOLE_SIZE,
		)
	}
	
	// Make the draw calls
	
	cur_prim_inst := u32(0)
	cur_img_inst := u32(0)

	for i := 0; i < len(draw_items); i += 1 {
		item := draw_items[i]
		switch in item.data {

		// Render rectangle primitive
		case Canvas_Draw_Primitive_Data:
			wgpu.RenderPassEncoderSetPipeline(render_pass, prim_pipeline)
			wgpu.RenderPassEncoderSetVertexBuffer(
				render_pass,
				1,
				prim_insts.handle,
				0,
				wgpu.WHOLE_SIZE,
			)
			
			switch item.data.(Canvas_Draw_Primitive_Data).type {
			case .Rect:
				wgpu.RenderPassEncoderDraw(
					render_pass,
					6, // vertices per rect
					c.uint32_t(item.count),
					0,
					c.uint32_t(cur_prim_inst),
				)
			}
			
			cur_prim_inst += u32(item.count)
		
		// Render image
		case Canvas_Draw_Image_Data:
			wgpu.RenderPassEncoderSetPipeline(render_pass, img_pipeline)
			wgpu.RenderPassEncoderSetVertexBuffer(
				render_pass,
				1,
				img_insts.handle,
				0,
				wgpu.WHOLE_SIZE,
			)
			wgpu.RenderPassEncoderSetBindGroup(
				render_pass,
				0,
				image_bind_group_fetch(
					item.data.(Canvas_Draw_Image_Data).image,
				),
				0,
				nil,
			)
			wgpu.RenderPassEncoderDraw(
				render_pass,
				6,
				c.uint32_t(item.count),
				0,
				c.uint32_t(cur_img_inst),
			)
			cur_img_inst += u32(item.count)
		}
	}

	clear(&prim_inst_data)
	clear(&img_inst_data)
	clear(&draw_items)
}

// Shuts down the canvas system.
canvas_exit :: proc() -> bool {
	using canvas_state
	
	delete(prim_inst_data)
	delete(img_inst_data)
	delete(draw_items)
	delete(draw_state_stack)
	if prim_verts.handle != nil do wgpu.BufferDestroy(prim_verts.handle)
	if prim_insts.handle != nil do wgpu.BufferDestroy(prim_insts.handle)
	
	return true
}
