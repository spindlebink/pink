package pk_image

import "core:fmt"
import "core:hash"
import "core:image"
import "core:image/png"
import "../render"

CHANNEL_COUNT_RGBA :: 4

Image :: struct {
	using texture: render.Texture,
	_hash: u32,
}

Address_Mode :: render.Texture_Address_Mode
Filter :: render.Texture_Filter

Options :: struct {
	min_filter: Filter,
	mag_filter: Filter,
	address_mode: Address_Mode,
}

load_from_bytes :: proc(data: []byte, options := Options{}) -> Image {
	loaded, err := image.load_from_bytes(data, image.Options{.alpha_add_if_missing})
	defer image.destroy(loaded)
	if err != nil { panic("could not load image") }
	if loaded.channels != CHANNEL_COUNT_RGBA { panic("unsupported image channel count") }

	img := Image{
		texture = render.Texture{
			width = uint(loaded.width),
			height = uint(loaded.height),
		},
		_hash = hash.murmur32(loaded.pixels.buf[:]),
	}

	render.texture_init(&img.texture, render.Texture_Options{
		usage = .Binding,
		format = .RGBA,
		min_filter = options.min_filter,
		mag_filter = options.mag_filter,
		address_mode = options.address_mode,
	})

	render.texture_write(&img.texture, loaded.pixels.buf[:])

	return img
}
