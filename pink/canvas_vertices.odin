package pink

import "core:c"
import "render/wgpu"

Canvas_Primitive_Vertex :: struct {
	position: [2]f32,
}

Canvas_Primitive_Instance :: struct {
	translation: [2]f32,
	scale: [2]f32,
	rotation: f32,
	modulation: [4]f32,
}

CANVAS_PRIMITIVE_VERTICES :: []Canvas_Primitive_Vertex{
	Canvas_Primitive_Vertex{{-1.0, 1.0}},
	Canvas_Primitive_Vertex{{1.0, 1.0}},
	Canvas_Primitive_Vertex{{-1.0, -1.0}},
	Canvas_Primitive_Vertex{{-1.0, -1.0}},
	Canvas_Primitive_Vertex{{1.0, 1.0}},
	Canvas_Primitive_Vertex{{1.0, -1.0}},
}

CANVAS_PRIMITIVE_VERTEX_ATTRIBUTES :: []wgpu.VertexAttribute{
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Vertex, position)),
		shaderLocation = 0,
		format = .Float32x2,
	},
}

CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES :: []wgpu.VertexAttribute{
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
