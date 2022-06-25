//+private
package pink

import "core:c"
import "wgpu/wgpu"

Vertex :: struct {
	position: [2]f32,
	color: [4]f32,
	texture_coord: [2]f32,
}

@(private)
ATTRIBUTE_COUNT :: 3

QUAD_INDICES : [6]c.uint16_t = {
	0, 1, 2,
	1, 2, 3,
}

vertex_buffer_layout :: proc() -> wgpu.VertexBufferLayout {
	attributes := []wgpu.VertexAttribute{
		wgpu.VertexAttribute{
			offset = cast(c.uint64_t) offset_of(Vertex, position),
			shaderLocation = 0,
			format = .Float32x2,
		},
		wgpu.VertexAttribute{
			offset = cast(c.uint64_t) offset_of(Vertex, color),
			shaderLocation = 1,
			format = .Float32x4,
		},
		wgpu.VertexAttribute{
			offset = cast(c.uint64_t) offset_of(Vertex, texture_coord),
			shaderLocation = 2,
			format = .Float32x2,
		},
	}

	buffer_layout := wgpu.VertexBufferLayout{
		arrayStride = cast(c.uint64_t) size_of(Vertex),
		stepMode = .Vertex,
		attributeCount = ATTRIBUTE_COUNT,
		attributes = raw_data(attributes),
	}

	return buffer_layout
}

renderer_poc_vertices :: proc() -> [3]Vertex {
	return [3]Vertex{
		Vertex{
			position = {0.0, 0.5},
			color = {1.0, 0.0, 0.0, 1.0},
			texture_coord = {0.0, 0.0},
		},
		Vertex{
			position = {-0.5, -0.5},
			color = {0.0, 1.0, 0.0, 1.0},
			texture_coord = {0.0, 0.0},
		},
		Vertex{
			position = {0.5, -0.5},
			color = {0.0, 0.0, 1.0, 1.0},
			texture_coord = {0.0, 0.0},
		},
	}
}

