//+private
package pk_canvas

import "core:reflect"
import "../image"

Command :: union {
	Draw_Solid_Command,
	Draw_Image_Command,
}

Draw_Solid_Command :: struct {
	type: enum {
		Rect,
	},
}

Draw_Image_Command :: struct {
	image: image.Image,
}

Command_Invoc :: struct {
	cmd: Command,
	times: uint,
}

append_cmd :: proc(cmds: ^[dynamic]Command_Invoc, cmd: Command) {
	// TODO: we could do a slightly more complex batch by checking each command's
	// bounds and checking back over the previous `n` commands for overlap ala
	// `sokol_gp`

	if len(cmds) > 0 {
		top := &cmds[len(cmds) - 1]
		top_type := reflect.union_variant_typeid(top.cmd)
		cmd_type := reflect.union_variant_typeid(cmd)
		if top_type == cmd_type {
			switch in cmd {
				
			case Draw_Solid_Command:
				if cmd.(Draw_Solid_Command).type == top.cmd.(Draw_Solid_Command).type {
					top.times += 1
					return
				}
				
			case Draw_Image_Command:
				if cmd.(Draw_Image_Command).image._hash == top.cmd.(Draw_Image_Command).image._hash {
					top.times += 1
					return
				}
			
			}
		}
	}
	
	append(cmds, Command_Invoc{cmd, 1})
}
