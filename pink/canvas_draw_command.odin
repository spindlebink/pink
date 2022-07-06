package pink

import "core:reflect"
import "wgpu"

// Data required for a primitive draw command.
Canvas_Draw_Primitive_Command :: struct {
	type: enum {
		Rect,
	},
}

// Data required for an image draw command.
Canvas_Draw_Image_Command :: struct {
	image: ^Image,
}

// A draw command.
Canvas_Draw_Command :: struct {
	data: union {
		Canvas_Draw_Primitive_Command,
		Canvas_Draw_Image_Command,
	},
	times: int,
}

// Appends a draw command to a dynamic array of them, combining the command with
// the top item if they're batchable.
_draw_commands_append_command :: proc(
	commands: ^[dynamic]Canvas_Draw_Command,
	command: Canvas_Draw_Command,
) {
	if len(commands) > 0 {
		top := &commands[len(commands) - 1]
		top_type := reflect.union_variant_typeid(top.data)
		cmd_type := reflect.union_variant_typeid(command.data)
		
		if top_type == cmd_type {
			switch in command.data {
			case Canvas_Draw_Primitive_Command:
				cmd_prim_type := command.data.(Canvas_Draw_Primitive_Command).type
				top_prim_type := top.data.(Canvas_Draw_Primitive_Command).type
				if cmd_prim_type == top_prim_type {
					top.times += command.times
					return
				}
				
			case Canvas_Draw_Image_Command:
				// if image == top_image
			}
		}
	}
	append(commands, command)
}
