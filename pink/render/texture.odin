package pk_render

import "core:c"
import "wgpu"

Texture :: struct {
	width, height: uint,
	options: Texture_Options,

	_bytes_per_pixel: uint,
	_wgpu_texture: wgpu.Texture,
	_wgpu_view: wgpu.TextureView,
	_wgpu_sampler: wgpu.Sampler,
	_wgpu_bind_group: wgpu.BindGroup,
}

Texture_Options :: struct {
	format: Texture_Format,
	usage: Texture_Usage,
	address_mode: Texture_Address_Mode,
	min_filter: Texture_Filter,
	mag_filter: Texture_Filter,
}

Texture_Usage :: enum {
	Binding,
	Render_Target,
}

Texture_Format :: enum {
	RGBA,
	Gray,
}

Texture_Address_Mode :: enum {
	Clamp,
	Repeat,
	Mirror_Repeat,
}

Texture_Filter :: enum {
	Linear,
	Nearest,
}

texture_init :: proc(texture: ^Texture) {
	texture._bytes_per_pixel = texture.options.format == .RGBA ? 4 : 1
	texture._wgpu_texture = wgpu.DeviceCreateTexture(
		_core.device,
		&wgpu.TextureDescriptor{
			size = wgpu.Extent3D{
				width = c.uint32_t(texture.width),
				height = c.uint32_t(texture.height),
				depthOrArrayLayers = 1,
			},
			mipLevelCount = 1,
			sampleCount = 1,
			dimension = .D2,
			format = texture.options.format == .RGBA ? .RGBA8UnormSrgb : .R8Unorm,
			usage = texture.options.usage == .Binding ? {.TextureBinding, .CopyDst} : {.RenderAttachment},
		},
	)
	
	texture._wgpu_view = wgpu.TextureCreateView(
		texture._wgpu_texture,
		&wgpu.TextureViewDescriptor{},
	)

	if texture.options.usage == .Binding {
		addr_mode: wgpu.AddressMode =
			.ClampToEdge if texture.options.address_mode == .Clamp else
			.Repeat if texture.options.address_mode == .Repeat else
			.MirrorRepeat	

		texture._wgpu_sampler = wgpu.DeviceCreateSampler(
			_core.device,
			&wgpu.SamplerDescriptor{
				addressModeU = addr_mode,
				addressModeV = addr_mode,
				addressModeW = addr_mode,
				magFilter = texture.options.mag_filter == .Linear ? .Linear : .Nearest,
				minFilter = texture.options.min_filter == .Linear ? .Linear : .Nearest,
				mipmapFilter = .Linear,
			},
		)
	}
	
	// TODO: create bind group--identify basic texture bind group layout for renderer
}

texture_destroy :: proc(texture: Texture) {
	wgpu.BindGroupDrop(texture._wgpu_bind_group)
	wgpu.SamplerDrop(texture._wgpu_sampler)
	wgpu.TextureViewDrop(texture._wgpu_view)
	wgpu.TextureDestroy(texture._wgpu_texture)
	wgpu.TextureDrop(texture._wgpu_texture)
}

texture_write_rect :: proc(texture: ^Texture, data: []byte, x, y, w, h: uint) {
	bytes_per_row := texture._bytes_per_pixel * w
	wgpu.QueueWriteTexture(
		_core.queue,
		&wgpu.ImageCopyTexture{
			texture = texture._wgpu_texture,
			mipLevel = 0,
			aspect = .All,
			origin = wgpu.Origin3D{
				x = c.uint32_t(x),
				y = c.uint32_t(y),
			},
		},
		raw_data(data),
		c.size_t(len(data)),
		&wgpu.TextureDataLayout{
			offset = 0,
			bytesPerRow = c.uint32_t(bytes_per_row),
			rowsPerImage = c.uint32_t(h),
		},
		&wgpu.Extent3D{
			width = c.uint32_t(w),
			height = c.uint32_t(h),
			depthOrArrayLayers = 1,
		},
	)
}

texture_write_full :: proc(texture: ^Texture, data: []byte) {
	texture_write_rect(texture, data, 0, 0, texture.width, texture.height)
}

texture_write :: proc{
	texture_write_rect,
	texture_write_full,
}
