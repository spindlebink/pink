package pink

import "core:fmt"
import sdl "vendor:sdl2"
import stbi "vendor:stb/image"
import "wgpu"

// ************************************************************************** //
// Type Definitions
// ************************************************************************** //

Image :: struct {
	width, height: int,
	data: [^]u8,
	data_len: int,
	data_size: int,
	hash: u32,
	load_options: Image_Load_Options,
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

RGBA_CHANNELS :: 4

// ************************************************************************** //
// Procedures
// ************************************************************************** //

image_load_png :: proc(data: []u8, options := Image_Load_Options{}) -> Image {
	data := data
	
	width, height, channels: i32
	
	img_data := stbi.load_from_memory(
		raw_data(data),
		i32(len(data) * size_of(u8)),
		&width, &height, &channels,
		RGBA_CHANNELS,
	)
	
	image := Image{
		width = int(width),
		height = int(height),
		load_options = options,
		data = img_data,
		data_size = int(width * height * size_of(u8)),
		data_len = int(width * height * RGBA_CHANNELS),
	}
	
	return image
}

image_destroy :: proc(image: ^Image) {
	stbi.image_free(image.data)
	image_render_data_destroy(image)
}
