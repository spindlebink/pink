package pink

import "core:c"
import "core:hash"
import stbi "vendor:stb/image"
import "wgpu"

RGBA_CHANNELS :: 4

Image :: struct {
	width, height: int,
	_hash: u32,
	_renderable: bool,
	_texture: wgpu.Texture,
	_texture_view: wgpu.TextureView,
	_texture_sampler: wgpu.Sampler,
	_bind_group: wgpu.BindGroup,
	_data: [^]u8,
	_data_len: int,
	_data_size: int,
	_load_options: Image_Load_Options,
}

Image_Address_Mode :: enum {
	Clamp,
	Repeat,
	Mirror_Repeat,
}

Image_Filter_Mode :: enum {
	Linear,
	Nearest,
}

Image_Load_Options :: struct {
	address_mode: Image_Address_Mode,
	min_filter: Image_Filter_Mode,
	mag_filter: Image_Filter_Mode,
}

// Loads a byte slice to create an image.
image_create :: proc(
	data: []u8,
	options := Image_Load_Options{},
) -> Image {
	data := data
	width, height, channels: i32
	
	loaded := stbi.load_from_memory(
		raw_data(data),
		i32(len(data) * size_of(u8)),
		&width, &height, &channels,
		RGBA_CHANNELS,
	)

	image := Image{
		width = int(width),
		height = int(height),
		_hash = hash.murmur32(loaded[0:width * height]),
		_load_options = options,
		_data = loaded,
		_data_size = int(width * height * size_of(u8)),
		_data_len = int(width * height * RGBA_CHANNELS),
	}
	
	return image
}

image_destroy :: proc(image: ^Image) {
	stbi.image_free(image._data)
	if image._renderable {
		wgpu.BindGroupDrop(image._bind_group)
		wgpu.SamplerDrop(image._texture_sampler)
		wgpu.TextureViewDrop(image._texture_view)
		wgpu.TextureDestroy(image._texture)
		wgpu.TextureDrop(image._texture)
	}
}

_image_fetch_bind_group :: proc(
	image: ^Image,
	canvas: ^Canvas,
	renderer: ^Renderer,
) -> wgpu.BindGroup {
	if !image._renderable {
		_image_init_render_data(image, canvas, renderer)
		_image_write_texture(image, renderer.queue)
		image._renderable = true
	}
	return image._bind_group
}

_image_init_render_data :: proc(
	image: ^Image,
	canvas: ^Canvas,
	renderer: ^Renderer,
) {
	image._texture = wgpu.DeviceCreateTexture(
		renderer.device,
		&wgpu.TextureDescriptor{
			size = wgpu.Extent3D{
				width = c.uint32_t(image.width),
				height = c.uint32_t(image.height),
				depthOrArrayLayers = 1,
			},
			mipLevelCount = 1,
			sampleCount = 1,
			dimension = .D2,
			format = .RGBA8UnormSrgb,
			usage = {.TextureBinding, .CopyDst},
		},
	)
	
	image._texture_view = wgpu.TextureCreateView(
		image._texture,
		&wgpu.TextureViewDescriptor{},
	)
	
	addr_mode := wgpu.AddressMode.ClampToEdge
	switch image._load_options.address_mode {
	case .Clamp:
		// already set
	case .Repeat:
		addr_mode = .Repeat
	case .Mirror_Repeat:
		addr_mode = .MirrorRepeat
	}
	
	image._texture_sampler = wgpu.DeviceCreateSampler(
		renderer.device,
		&wgpu.SamplerDescriptor{
			addressModeU = addr_mode,
			addressModeV = addr_mode,
			addressModeW = addr_mode,
			magFilter =
				.Linear if image._load_options.mag_filter == .Linear else .Nearest,
			minFilter =
				.Linear if image._load_options.min_filter == .Linear else .Nearest,
			mipmapFilter = .Nearest,
		},
	)
	
	entries := []wgpu.BindGroupEntry{
		wgpu.BindGroupEntry{
			binding = 0,
			textureView = image._texture_view,
		},
		wgpu.BindGroupEntry{
			binding = 1,
			sampler = image._texture_sampler,
		},
	}
	
	image._bind_group = wgpu.DeviceCreateBindGroup(
		renderer.device,
		&wgpu.BindGroupDescriptor{
			label = "TextureBindGroup",
			layout = canvas._image_pipeline.bind_group_layout,
			entryCount = c.uint32_t(len(entries)),
			entries = cast([^]wgpu.BindGroupEntry)raw_data(entries),
		},
	)
}

_image_write_texture :: proc(
	image: ^Image,
	queue: wgpu.Queue,
) {
	bytes_per_row := RGBA_CHANNELS * image.width
	wgpu.QueueWriteTexture(
		queue,
		&wgpu.ImageCopyTexture{
			texture = image._texture,
			mipLevel = 0,
			origin = wgpu.Origin3D{},
			aspect = .All,
		},
		image._data,
		c.size_t(image._data_len),
		&wgpu.TextureDataLayout{
			offset = 0,
			bytesPerRow = c.uint32_t(RGBA_CHANNELS * image.width),
			rowsPerImage = c.uint32_t(image.height),
		},
		&wgpu.Extent3D{
			width = c.uint32_t(image.width),
			height = c.uint32_t(image.height),
			depthOrArrayLayers = 1,
		},
	)
}
