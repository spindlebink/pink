package pk_canvas

import pk ".."

draw_rect :: proc(transform: pk.Transform) {
	append(&_core.solid_insts, draw_inst_from_trans(transform))
	append_cmd(&_core.cmds, Draw_Solid_Command{.Rect})
}
