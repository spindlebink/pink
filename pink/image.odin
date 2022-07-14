package pink

import "core:c"
import "core:hash"
import "core:math"
import stbi "vendor:stb/image"
import "render"
import "render/wgpu"

@(private)
RGBA_CHANNELS :: 4

Image :: struct {
	width, height: uint,
	options: Image_Options,
	core: Image_Core,
}

@(private)
Image_Core :: struct {
	ready: bool,
	hash: u32,
	texture: render.Texture,
	data: [^]u8,
}

Image_Address_Mode :: render.Texture_Address_Mode
Image_Filter :: render.Texture_Filter
Image_Options :: render.Texture_Options

// Loads a byte slice to create an image.
image_create_from_data :: proc(
	data: []u8,
	options := Image_Options{},
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
		width = uint(width),
		height = uint(height),
		options = options,
		core = Image_Core{
			hash = hash.murmur32(loaded[0:len(data)]),
			data = loaded,
		},
	}
	
	return image
}

// Destroys an image.
image_destroy :: proc(
	image: ^Image,
) {
	stbi.image_free(image.core.data)
	if image.core.ready do render.texture_deinit(&image.core.texture)
}

// Initializes a slice of image slices according to the dimensions of an image.
image_atlas_slices_init :: proc(
	image: ^Image,
	cols, rows: int,
	slices: []Recti,
) {
	assert(cols > 0 && rows > 0 && len(slices) >= cols * rows)
	
	slice_w := int(math.floor(f32(image.width) / f32(cols)))
	slice_h := int(math.floor(f32(image.height) / f32(rows)))
	
	for y := 0; y < rows; y += 1 {
		for x := 0; x < cols; x += 1 {
			slices[y * cols + x] = Recti{
				x = x * slice_w,
				y = y * slice_h,
				w = slice_w,
				h = slice_h,
			}
		}
	}
}

// Retrieves the image's texture bind group, queueing a image data copy
// operation if it hasn't been initialized yet.
@(private)
image_fetch_bind_group :: proc(
	image: ^Image,
	renderer: ^render.Renderer,
) -> wgpu.BindGroup {
	if !image.core.ready {
		image_core_init(image, renderer)
		image.core.ready = true
	}
	return image.core.texture.bind_group
}

// Initializes the image's GPU-side data.
@(private)
image_core_init :: proc(
	image: ^Image,
	renderer: ^render.Renderer,
) {
	render.texture_init(
		renderer,
		&image.core.texture,
		image.width,
		image.height,
		image.options,
	)
	render.texture_queue_copy_full(
		renderer,
		&image.core.texture,
		image.core.data[0:image.width * image.height * image.core.texture.bytes_per_pixel],
	)
}
