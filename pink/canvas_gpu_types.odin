//+private
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

Canvas_Slice_Instance :: struct {
	using primitive_instance: Canvas_Primitive_Instance,
	uv_extents: [4]f32,
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
		format = .Float32x2,
	},
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Vertex, uv_indices)),
		format = .Uint16x2,
	},
}

CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES :: []wgpu.VertexAttribute{
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, translation)),
		format = .Float32x2,
	},
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, scale)),
		format = .Float32x2,
	},
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, rotation)),
		format = .Float32,
	},
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Primitive_Instance, color)),
		format = .Float32x4,
	},
}

CANVAS_IMAGE_INSTANCE_ATTRIBUTES :: CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES

CANVAS_SLICE_INSTANCE_ATTRIBUTES :: []wgpu.VertexAttribute{
	CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES[0],
	CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES[1],
	CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES[2],
	CANVAS_PRIMITIVE_INSTANCE_ATTRIBUTES[3],
	wgpu.VertexAttribute{
		offset = c.uint64_t(offset_of(Canvas_Slice_Instance, uv_extents)),
		format = .Float32x4,
	},
}

// Generates primitive instance info from a transform.
canvas_prim_inst_from_transform :: #force_inline proc(
	canvas: ^Canvas,
	transform: Transform,
) -> Canvas_Primitive_Instance {
	return Canvas_Primitive_Instance{
		translation = {
			canvas.translation.x + transform.x + transform.w * 0.5,
			-canvas.translation.y - transform.y - transform.h * 0.5,
		},
		scale = {transform.w * 0.5, transform.h * 0.5},
		rotation = transform.rotation,
		color = ([4]f32)(canvas.color),
	}
}
