package pink_render

import "../wgpu"

Texture :: struct {
	renderable: bool,
	texture: wgpu.Texture,
	view: wgpu.TextureView,
	sampler: wgpu.Sampler,
	bind_group: wgpu.BindGroup,
}
