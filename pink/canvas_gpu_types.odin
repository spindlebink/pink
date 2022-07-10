package pink

import "core:c"
import "core:math/linalg"
import "render/wgpu"

Canvas_Draw_State_Uniform :: struct {
	window_to_device: linalg.Matrix4x4f32,
}

Canvas_Primitive_Vertex :: struct {
	position: [2]f32,
	uv_indices: [2]u16,
}

Canvas_Primitive_Instance :: struct {
	translation: [2]f32,
	scale: [2]f32,
	rotation: f32,
	color: [4]f32,
}

Canvas_Image_Instance :: struct {
	using primitive_instance: Canvas_Primitive_Instance,
}

CANVAS_PRIMITIVE_VERTICES :: []Canvas_Primitive_Vertex{
	Canvas_Primitive_Vertex{{-1.0, 1.0}, {0, 1}},
	Canvas_Primitive_Vertex{{1.0, 1.0}, {2, 1}},
	Canvas_Primitive_Vertex{{-1.0, -1.0}, {0, 3}},
	Canvas_Primitive_Vertex{{-1.0, -1.0}, {0, 3}},
	Canvas_Primitive_Vertex{{1.0, 1.0}, {2, 1}},
	Canvas_Primitive_Vertex{{1.0, -1.0}, {2, 3}},
}

CANVAS_PRIMITIVE_VERTEX_ATTRIBUTES :: []wgpu.VertexAttribute{
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Vertex, position)),
		shaderLocation = 0,
		format = .Float32x2,
	},
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Vertex, uv_indices)),
		shaderLocation = 1,
		format = .Uint16x2,
	},
}

CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES :: []wgpu.VertexAttribute{
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, translation)),
		shaderLocation = 2,
		format = .Float32x2,
	},
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, scale)),
		shaderLocation = 3,
		format = .Float32x2,
	},
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, rotation)),
		shaderLocation = 4,
		format = .Float32,
	},
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, color)),
		shaderLocation = 5,
		format = .Float32x4,
	},
}

CANVAS_IMAGE_INSTANCE_ATTRIBUTES :: CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES
