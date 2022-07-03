//+private
package pink

import "core:c"
import "core:fmt"
import "core:hash"
import "wgpu"

image_state := Image_State{}

// ************************************************************************** //
// Type Definitions
// ************************************************************************** //

Image_Render_Data :: struct {
	image: ^Image,
	usable: bool,
	texture: wgpu.Texture,
	texture_view: wgpu.TextureView,
	texture_sampler: wgpu.Sampler,
	bind_group: wgpu.BindGroup,
}

Image_State :: struct {
	render_data: map[u32]Image_Render_Data,
}

// ************************************************************************** //
// Procedures
// ************************************************************************** //

image_exit :: proc() -> bool {
	using image_state
	delete(render_data)
	return true
}

image_register_load :: proc(image: ^Image) {
	using image_state
	
	image.hash = hash.murmur32(image.data[0:image.width * image.height])
	
	if image.hash not_in render_data {
		render_data[image.hash] = Image_Render_Data{
			image = image,
			usable = false,
		}
	}
}

image_render_data_destroy :: proc(image: ^Image) {
	if ren, ok := image_state.render_data[image.hash]; ok {
		wgpu.BindGroupDrop(ren.bind_group)
		wgpu.SamplerDrop(ren.texture_sampler)
		wgpu.TextureViewDrop(ren.texture_view)
		wgpu.TextureDestroy(ren.texture)
		wgpu.TextureDrop(ren.texture)
	}
}

image_render_data_create :: proc(image: ^Image) {
	device := render_device()
	ren := &image_state.render_data[image.hash]

	ren.texture = wgpu.DeviceCreateTexture(
		device,
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
	
	ren.texture_view = wgpu.TextureCreateView(
		ren.texture,
		&wgpu.TextureViewDescriptor{},
	)

	addr_mode := wgpu.AddressMode.ClampToEdge
	switch image.load_options.address_mode {
	case .Clamp:
	case .Repeat:
		addr_mode = .Repeat
	case .Mirror_Repeat:
		addr_mode = .MirrorRepeat
	}
	
	ren.texture_sampler = wgpu.DeviceCreateSampler(
		device,
		&wgpu.SamplerDescriptor{
			addressModeU = addr_mode,
			addressModeV = addr_mode,
			addressModeW = addr_mode,
			magFilter = .Linear if image.load_options.mag_filter == .Linear else .Nearest,
			minFilter = .Linear if image.load_options.min_filter == .Linear else .Nearest,
			mipmapFilter = .Nearest,
		},
	)
	
	entries := []wgpu.BindGroupEntry{
		wgpu.BindGroupEntry{
			binding = 0,
			textureView = ren.texture_view,
		},
		wgpu.BindGroupEntry{
			binding = 1,
			sampler = ren.texture_sampler,
		},
	}

	ren.bind_group = wgpu.DeviceCreateBindGroup(
		device,
		&wgpu.BindGroupDescriptor{
			label = "TextureBindGroup",
			layout = canvas_tex_bind_group_layout(),
			entryCount = 2,
			entries = cast([^]wgpu.BindGroupEntry) raw_data(entries),
		},
	)
}

// Fetches the bind group for an image. Can only be called during a render frame
// since it copies texture data to the GPU lazily.
image_bind_group_fetch :: proc(image: ^Image) -> wgpu.BindGroup {
	if image.hash == 0 {
		image_register_load(image)
	}
	
	assert(image.hash in image_state.render_data)
	ren := &image_state.render_data[image.hash]

	if !ren.usable {
		image_render_data_create(image)
		
		bytes_per_row := RGBA_CHANNELS * image.width
		wgpu.QueueWriteTexture(
			render_queue(),
			&wgpu.ImageCopyTexture{
				texture = ren.texture,
				mipLevel = 0,
				origin = wgpu.Origin3D{},
				aspect = .All,
			},
			image.data,
			c.size_t(image.data_len),
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
		ren.usable = true
	}
	
	return ren.bind_group
}
