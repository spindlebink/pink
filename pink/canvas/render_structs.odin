//+private
package pk_canvas

import "core:math/linalg"
import pk ".."
import "../render"

// Basic vertex type
Vertex :: struct {
	pos: [2]f32,
}

// Basic instance type
Draw_Inst :: struct {
	trans: [2]f32,
	scale: [2]f32,
	rot: f32,
	origin: [2]f32,
	color: [4]f32,
}

Image_Vertex :: struct {
	pos: [2]f32,
	uv_indices: [2]u32,
}

// Basic instance type + UV info
Image_Inst :: struct {
	using inst: Draw_Inst,
	uv: [4]f32,
}

// Global shader data uniform
Data_Uniform :: struct {
	window_to_device: linalg.Matrix4x4f32,
}

VERT_ATTRS :: [?]render.Attr{
	{type = .F32x2, offset = offset_of(Vertex, pos)},
}

DRAW_INST_ATTRS :: [?]render.Attr{
	{type = .F32x2, offset = offset_of(Draw_Inst, trans)},
	{type = .F32x2, offset = offset_of(Draw_Inst, scale)},
	{type = .F32, offset = offset_of(Draw_Inst, rot)},
	{type = .F32x2, offset = offset_of(Draw_Inst, origin)},
	{type = .F32x4, offset = offset_of(Draw_Inst, color)},
}

IMAGE_VERT_ATTRS :: [?]render.Attr{
	{type = .F32x2, offset = offset_of(Image_Vertex, pos)},
	{type = .U32x2, offset = offset_of(Image_Vertex, uv_indices)},
}

IMAGE_INST_ATTRS :: [?]render.Attr{
	{type = .F32x2, offset = offset_of(Image_Inst, trans)},
	{type = .F32x2, offset = offset_of(Image_Inst, scale)},
	{type = .F32, offset = offset_of(Image_Inst, rot)},
	{type = .F32x2, offset = offset_of(Image_Inst, origin)},
	{type = .F32x4, offset = offset_of(Image_Inst, color)},
	{type = .F32x4, offset = offset_of(Image_Inst, uv)}
}

@(private)
draw_inst_from_trans :: #force_inline proc(transform: pk.Transform) ->  Draw_Inst {
	return Draw_Inst{
		trans = {
			_core.state.translation.x + transform.x + transform.w * 0.5,
			-_core.state.translation.y - transform.y - transform.h * 0.5,
		},
		scale = {transform.w * 0.5, transform.h * 0.5},
		rot = transform.rotation,
		origin = {
			-transform.origin.x * 2.0 + 1.0,
			-transform.origin.y * 2.0 + 1.0,
		},
		color = ([4]f32)(_core.state.color),
	}
}
