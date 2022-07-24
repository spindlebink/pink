package pk_render

import "core:c"
import "wgpu"

Binding :: struct {
	type: enum {
		Texture_Sampler,
		Uniform,
	},
}

Attr_Type :: enum {
	F32,
	F32x2,
	F32x3,
	F32x4,
	U16x2,
	U16x4,
	U32,
	U32x2,
	U32x3,
	U32x4,
	I32,
	I32x2,
	I32x3,
	I32x4,
}

Attr :: struct {
	type: Attr_Type,
	offset: uintptr,
}

@(private)
wgpu_format_from_attr :: #force_inline proc(attr: Attr) -> wgpu.VertexFormat {
	switch attr.type {
	
	case .F32:
		return .Float32
	case .F32x2:
		return .Float32x2
	case .F32x3:
		return .Float32x3
	case .F32x4:
		return .Float32x4
	
	case .U16x2:
		return .Uint16x2
	case .U16x4:
		return .Uint16x4
	
	case .U32:
		return .Uint32
	case .U32x2:
		return .Uint32x2
	case .U32x3:
		return .Uint32x3
	case .U32x4:
		return .Uint32x4
	
	case .I32:
		return .Sint32
	case .I32x2:
		return .Sint32x2
	case .I32x3:
		return .Sint32x3
	case .I32x4:
		return .Sint32x4
	
	}
	
	return .Undefined
}
