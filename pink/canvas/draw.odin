package pk_canvas

import "../image"
import pk ".."

draw_rect :: proc(transform: pk.Transform) {
	append(&_core.solid_insts, draw_inst_from_trans(transform))
	append_cmd(&_core.cmds, Draw_Solid_Command{.Rect})
}

draw_image :: proc(image: image.Image, transform: pk.Transform, quad := pk.Recti{0, 0, 0, 0}) {
	t := transform
	s := quad
	if s.w <= 0 { s.w = int(image.width) - s.x }
	if s.h <= 0 { s.h = int(image.height) - s.y }
	fw, fh := f32(image.width), f32(image.height)
	uv_x, uv_y := f32(s.x) / fw, f32(s.y) / fh
	
	if t.w <= 0 { t.w = f32(image.width) }
	if t.h <= 0 { t.h = f32(image.height) }
	
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
		},
	)
	append_cmd(&_core.cmds, Draw_Image_Command{image})
}
