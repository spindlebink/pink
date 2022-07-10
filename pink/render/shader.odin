package pink_render

import "core:mem"
import "wgpu"

shader_module_create :: proc(
	renderer: ^Context,
	header: []u8,
	body: []u8,
) -> wgpu.ShaderModule {
	source := make([]u8, len(header) + len(body)); defer delete(source)
	mem.copy(
		raw_data(source[:len(header) * size_of(u8)]),
		raw_data(header),
		len(header) * size_of(u8),
	)
	mem.copy(
		raw_data(source[len(header) * size_of(u8):]),
		raw_data(body),
		len(body) * size_of(u8),
	)

	module := wgpu.DeviceCreateShaderModule(
		renderer.device,
		&wgpu.ShaderModuleDescriptor{
			nextInChain = cast(^wgpu.ChainedStruct)&wgpu.ShaderModuleWGSLDescriptor{
				chain = wgpu.ChainedStruct{
					sType = .ShaderModuleWGSLDescriptor,
				},
				code = cstring(raw_data(source)),
			},
		},
	)
	
	return module
}
