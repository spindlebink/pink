package pink_render

import "core:c"
import "wgpu"

PAINTER_VERTICES_BUFFER_INDEX :: 0
PAINTER_INSTANCES_BUFFER_INDEX :: 1

Painter :: struct(
	$V: typeid,
	$I: typeid,
	// $P: typeid,
) {
	vertices: Vertex_Buffer(V),
	instances: Vertex_Buffer(I),
	// push_constants: P,
	// push_constant_stages: wgpu.ShaderStageFlags,
	pipeline: Pipeline,
}

Painter_Descriptor :: struct {
	shader: wgpu.ShaderModule,
	vertex_entry_point: string,
	fragment_entry_point: string,
	vertex_attributes: []wgpu.VertexAttribute,
	instance_attributes: []wgpu.VertexAttribute,
	bind_group_layouts: []wgpu.BindGroupLayout,
	// push_constant_ranges: []wgpu.PushConstantRange,
}

painter_append_verts :: #force_inline proc(
	p: ^Painter($V, $I),
	verts: []V,
) {
	vbuffer_reserve(&p.vertices, len(verts))
	for vert in verts do vbuffer_append(&p.vertices, vert)
}

painter_append_inst :: #force_inline proc(
	p: ^Painter($V, $I),
	inst: I,
) {
	vbuffer_append(&p.instances, inst)
}

painter_append_insts :: #force_inline proc(
	p: ^Painter($V, $I),
	insts: []I,
) {
	vbuffer_reserve(&p.instances, len(insts))
	for inst in insts do vbuffer_append(&p.instances, inst)
}

// painter_send_push_constants :: #force_inline proc(
// 	p: ^Painter($V, $I),
// 	render_pass: ^Render_Pass,
// ) {
// 	wgpu.RenderPassEncoderSetPushConstants(
// 		render_pass.encoder,
// 		{.Vertex},
// 		0,
// 		size_of(P),
// 		&p.push_constants,
// 	)
// }

painter_init :: proc(
	painter: ^Painter($V, $I),
	renderer: ^Renderer,
	desc: Painter_Descriptor,
) {
	painter.vertices.usage_flags = {.Vertex, .CopyDst}
	painter.instances.usage_flags = {.Vertex, .CopyDst}

	vert_attrs := desc.vertex_attributes
	inst_attrs := desc.instance_attributes
	offset := len(desc.vertex_attributes)
	for _, i in desc.vertex_attributes {
		vert_attrs[i].shaderLocation = c.uint32_t(i)
	}
	for _, i in desc.instance_attributes {
		inst_attrs[i].shaderLocation = c.uint32_t(i + offset)
	}

	vert_buffer_layout := wgpu.VertexBufferLayout{
		arrayStride = c.uint64_t(size_of(V)),
		stepMode = .Vertex,
		attributeCount = c.uint32_t(len(vert_attrs)),
		attributes = ([^]wgpu.VertexAttribute)(raw_data(vert_attrs)),
	}
	inst_buffer_layout := wgpu.VertexBufferLayout{
		arrayStride = c.uint64_t(size_of(I)),
		stepMode = .Instance,
		attributeCount = c.uint32_t(len(inst_attrs)),
		attributes = ([^]wgpu.VertexAttribute)(raw_data(inst_attrs)),
	}

	pipeline_init(
		&painter.pipeline,
		renderer,
		Pipeline_Descriptor{
			shader = desc.shader,
			vertex_entry_point = desc.vertex_entry_point,
			fragment_entry_point = desc.fragment_entry_point,
			// push_constant_ranges = desc.push_constant_ranges,
			buffer_layouts = []wgpu.VertexBufferLayout{
				vert_buffer_layout,
				inst_buffer_layout,
			},
			bind_group_layouts = desc.bind_group_layouts,
		},
	)
}

painter_destroy :: proc(
	painter: ^Painter($V, $I),
) {
	pipeline_deinit(&painter.pipeline)
	vbuffer_destroy(&painter.vertices)
	vbuffer_destroy(&painter.instances)
}
