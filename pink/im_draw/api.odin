package pk_im_draw

import "../render"
import "../image"
import pk ".."

Drawable :: struct {
	draw_data: rawptr,
	draw: proc(rawptr, pk.Transform),
}

draw :: proc(drawable: Drawable, transform := pk.Transform{}) {
	drawable.draw(drawable.draw_data, transform)
}

rect :: proc(transform: pk.Transform) {
	append(&_core.solid_insts, draw_inst_from_trans(transform))
	append_cmd(&_core.cmds, Draw_Solid_Command{.Rect})
}

image :: proc(img: render.Texture, transform: pk.Transform, quad := pk.Recti{0, 0, 0, 0}) {
	t := transform
	s := quad
	if s.w <= 0 { s.w = int(img.width) - s.x }
	if s.h <= 0 { s.h = int(img.height) - s.y }
	fw, fh := f32(img.width), f32(img.height)
	uv_x, uv_y := f32(s.x) / fw, f32(s.y) / fh
	
	if t.w <= 0 { t.w = f32(img.width) }
	if t.h <= 0 { t.h = f32(img.height) }
	
	append(
		&_core.image_insts,
		Image_Inst{
			inst = draw_inst_from_trans(t),
			uv = {
				uv_x,
				uv_y,
				uv_x + f32(s.w) / fw,
				uv_y + f32(s.h) / fh,
			},
			texture_flags = img._fmt == .RGBA ? {} : {.RGBA_Convert},
		},
	)
	append_cmd(&_core.cmds, Draw_Image_Command{img})
}
