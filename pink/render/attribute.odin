package pk_render

import "core:c"
import "wgpu"

Attribute :: struct {
	type: typeid,
	offset: uintptr,
}

@(private)
wgpu_format_from_attr :: #force_inline proc(attr: Attribute) -> wgpu.VertexFormat {
	switch attr.type {
	
	case f32:
		return .Float32
	case [2]f32:
		return .Float32x2
	case [3]f32:
		return .Float32x3
	case [4]f32:
		return .Float32x4
	
	case u32:
		return .Uint32
	case [2]u32:
		return .Uint32x2
	case [3]u32:
		return .Uint32x3
	case [4]u32:
		return .Uint32x4
	
	case i32:
		return .Sint32
	case [2]i32:
		return .Sint32x2
	case [3]i32:
		return .Sint32x3
	case [4]i32:
		return .Sint32x4
	
	}
	
	return .Undefined
}
