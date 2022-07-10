package pink_render

import "core:c"
import "wgpu"

// Represents a basic GPU texture type.
Texture :: struct {
	width: uint,
	height: uint,
	bytes_per_pixel: uint,
	options: Texture_Options,
	texture: wgpu.Texture,
	view: wgpu.TextureView,
	sampler: wgpu.Sampler,
	bind_group: wgpu.BindGroup,
}

// Address mode of a texture sampler. Applied to all dimensions of the sampler.
Texture_Address_Mode :: enum {
	Clamp,
	Repeat,
	Mirror_Repeat,
}

// Filter mode for a texture sampler.
Texture_Filter :: enum {
	Linear,
	Nearest,
}

// Simplified format choices for a texture. Pink uses exclusively types in this
// enum for texture formats.
Texture_Format :: enum {
	RGBA,
	Grayscale,
}

// Texture initialization options.
Texture_Options :: struct {
	format: Texture_Format,
	address_mode: Texture_Address_Mode,
	min_filter: Texture_Filter,
	mag_filter: Texture_Filter,
}

// Initializes a texture with a given width, height, and options.
texture_init :: proc(
	renderer: ^Context,
	texture: ^Texture,
	width: uint,
	height: uint,
	options := Texture_Options{},
) {
	texture.width, texture.height = width, height
	texture.options = options
	texture.bytes_per_pixel = 4 if options.format == .RGBA else 1

	texture.texture = wgpu.DeviceCreateTexture(
		renderer.device,
		&wgpu.TextureDescriptor{
			size = wgpu.Extent3D{
				width = c.uint32_t(width),
				height = c.uint32_t(height),
				depthOrArrayLayers = 1,
			},
			mipLevelCount = 1,
			sampleCount = 1,
			dimension = .D2,
			format =
				.RGBA8UnormSrgb if options.format == .RGBA else
				.R8Unorm,
			usage = {.TextureBinding, .CopyDst},
		},
	)
	
	texture.view = wgpu.TextureCreateView(
		texture.texture,
		&wgpu.TextureViewDescriptor{},
	)

	address_mode: wgpu.AddressMode =
		.ClampToEdge if options.address_mode == .Clamp else
		.Repeat if options.address_mode == .Repeat else
		.MirrorRepeat

	texture.sampler = wgpu.DeviceCreateSampler(
		renderer.device,
		&wgpu.SamplerDescriptor{
			addressModeU = address_mode,
			addressModeV = address_mode,
			addressModeW = address_mode,
			magFilter =
				.Linear if options.mag_filter == .Linear else
				.Nearest,
			minFilter =
				.Linear if options.min_filter == .Linear else
				.Nearest,
			mipmapFilter = .Nearest,
		},
	)

	texture.bind_group = context_create_basic_texture_bind_group(
		renderer,
		texture.view,
		texture.sampler,
	)
}

// Deinitializes a texture. The texture can be reinitialized after a call to
// this procedure, but all currently-associated memory is cleared.
texture_deinit :: proc(
	texture: ^Texture,
) {
	wgpu.BindGroupDrop(texture.bind_group)
	wgpu.SamplerDrop(texture.sampler)
	wgpu.TextureViewDrop(texture.view)
	wgpu.TextureDestroy(texture.texture)
	wgpu.TextureDrop(texture.texture)
}

// Queues a write operation to copy data to a texture.
texture_queue_copy :: proc(
	renderer: ^Context,
	texture: ^Texture,
	data: []u8,
	x, y, w, h: uint,
) {
	bytes_per_row := texture.bytes_per_pixel * w
	wgpu.QueueWriteTexture(
		renderer.queue,
		&wgpu.ImageCopyTexture{
			texture = texture.texture,
			mipLevel = 0,
			origin = wgpu.Origin3D{
				x = c.uint32_t(x),
				y = c.uint32_t(y),
			},
			aspect = .All,
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

// Queues a write operation to copy data of the texture's own size to a texture.
texture_queue_copy_full :: proc(
	renderer: ^Context,
	texture: ^Texture,
	data: []u8,
) {
	texture_queue_copy(
		renderer,
		texture,
		data,
		0, 0, texture.width, texture.height,
	)
}
