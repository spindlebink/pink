package pink

import "core:c"
import "core:math/linalg"
import "core:reflect"
import "render"
import "render/wgpu"

// Data required for a primitive draw command.
Canvas_Draw_Primitive_Cmd :: struct {
	type: enum {
		Rect,
	},
}

// Data required for an image draw command.
Canvas_Draw_Img_Cmd :: struct {
	image: ^Image,
}

// Data for an slice drawing command.
Canvas_Draw_Slice_Cmd :: struct {
	image: ^Image,
}

// A draw command.
Canvas_Cmd :: union {
	Canvas_Draw_Primitive_Cmd,
	Canvas_Draw_Img_Cmd,
	Canvas_Draw_Slice_Cmd,
}

Canvas_Cmd_Invocation :: struct {
	data: Canvas_Cmd,
	times: int,
}

// Appends a draw command to a dynamic array of them, combining the command with
// the top item if they're batchable.
canvas_append_cmd :: proc(
	canvas: ^Canvas,
	command: Canvas_Cmd,
) {
	if len(canvas.core.commands) > 0 {
		top := &canvas.core.commands[len(canvas.core.commands) - 1]
		top_type := reflect.union_variant_typeid(top.data)
		cmd_type := reflect.union_variant_typeid(command)
		if top_type == cmd_type {
			switch in command {
			case Canvas_Draw_Primitive_Cmd:
				cmd_prim_type := command.(Canvas_Draw_Primitive_Cmd).type
				top_prim_type := top.data.(Canvas_Draw_Primitive_Cmd).type
				if cmd_prim_type == top_prim_type {
					top.times += 1
					return
				}

			case Canvas_Draw_Img_Cmd:
				cmd_img_hash := command.(Canvas_Draw_Img_Cmd).image.core.hash
				top_img_hash := top.data.(Canvas_Draw_Img_Cmd).image.core.hash
				if cmd_img_hash == top_img_hash {
					top.times += 1
					return
				}
			
			case Canvas_Draw_Slice_Cmd:
				cmd_img_hash := command.(Canvas_Draw_Slice_Cmd).image.core.hash
				top_img_hash := top.data.(Canvas_Draw_Slice_Cmd).image.core.hash
				if cmd_img_hash == top_img_hash {
					top.times += 1
					return
				}
			}
		}
	}
	append(
		&canvas.core.commands,
		Canvas_Cmd_Invocation{
			data = command,
			times = 1,
		},
	)
}
