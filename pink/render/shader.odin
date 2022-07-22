package pk_render

import "core:fmt"
import "wgpu"

Shader :: struct {
	_wgpu_handle: wgpu.ShaderModule,
}

shader_init_wgsl :: proc(shader: ^Shader, source: []byte) {
	shader._wgpu_handle = wgpu.DeviceCreateShaderModule(
		_core.device,
		&wgpu.ShaderModuleDescriptor{
			nextInChain = cast(^wgpu.ChainedStruct) &wgpu.ShaderModuleWGSLDescriptor{
				chain = wgpu.ChainedStruct{sType = .ShaderModuleWGSLDescriptor},
				code = cstring(raw_data(source)),
			},
		},
	)
}

shader_destroy :: proc(shader: Shader) {
	if shader._wgpu_handle != nil {
		wgpu.ShaderModuleDrop(shader._wgpu_handle)
	}
}
