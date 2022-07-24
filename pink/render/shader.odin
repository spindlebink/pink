package pk_render

import "core:fmt"
import "core:mem"
import "wgpu"

Shader :: struct {
	_wgpu_handle: wgpu.ShaderModule,
}

shader_init_wgsl :: proc(shader: ^Shader, source: []byte, header := []byte{}) {
	code: []byte; defer delete(code)
	if len(header) > 0 {
		code = make([]byte, len(header) + len(source))
		mem.copy(raw_data(code[:len(header)]), raw_data(header), len(header))
		mem.copy(raw_data(code[len(header):]), raw_data(source), len(source))
	} else {
		code = source
	}
	shader._wgpu_handle = wgpu.DeviceCreateShaderModule(
		_core.device,
		&wgpu.ShaderModuleDescriptor{
			nextInChain = cast(^wgpu.ChainedStruct) &wgpu.ShaderModuleWGSLDescriptor{
				chain = wgpu.ChainedStruct{sType = .ShaderModuleWGSLDescriptor},
				code = cstring(raw_data(code)),
			},
		},
	)
}

shader_destroy :: proc(shader: Shader) {
	if shader._wgpu_handle != nil {
		wgpu.ShaderModuleDrop(shader._wgpu_handle)
	}
}
