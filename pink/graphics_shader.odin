package pink

import "wgpu/wgpu"

@(private)
create_wgsl_shader_module :: proc(device: wgpu.Device, source: []u8) -> wgpu.ShaderModule {
	wgsl_descriptor := wgpu.ShaderModuleWGSLDescriptor{
		chain = wgpu.ChainedStruct{
			sType = .ShaderModuleWGSLDescriptor,
		},
		code = cast(cstring) raw_data(source),
	}
	descriptor := wgpu.ShaderModuleDescriptor{
		nextInChain = cast(^wgpu.ChainedStruct) &wgsl_descriptor,
	}
	shader_module := wgpu.DeviceCreateShaderModule(device, &descriptor)
	return shader_module
}
