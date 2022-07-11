package pink_render

import "core:c"
import "wgpu"

wgpu_vertex_attr_offset_shader_location :: proc(
	attributes: []wgpu.VertexAttribute,
	offset := 0,
) {
	for _, i in attributes {
		attributes[i].shaderLocation = c.uint32_t(i + offset)
	}
}
