package pink

import "core:c"
import "core:math/linalg"
import "core:reflect"
import "render"
import "render/wgpu"

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

Canvas_Draw_Slice_Command :: struct {
	image: ^Image,
	uv_extents: [4]f32,
}

// A draw command.
Canvas_Command :: struct {
	data: union {
		Canvas_Draw_Primitive_Command,
		Canvas_Draw_Image_Command,
		Canvas_Draw_Slice_Command,
	},
	times: int,
}

// Appends a draw command to a dynamic array of them, combining the command with
// the top item if they're batchable.
_canvas_append_command :: proc(
	canvas: ^Canvas,
	command: Canvas_Command,
) {
	if len(canvas.core.commands) > 0 {
		top := &canvas.core.commands[len(canvas.core.commands) - 1]
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
				cmd_img_hash := command.data.(Canvas_Draw_Image_Command).image.core.hash
				top_img_hash := top.data.(Canvas_Draw_Image_Command).image.core.hash
				if cmd_img_hash == top_img_hash {
					top.times += command.times
					return
				}
			
			case Canvas_Draw_Slice_Command:
			
			}
		}
	}
	append(&canvas.core.commands, command)
}
