package pink

import "core:reflect"
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

// A draw command.
Canvas_Draw_Command :: struct {
	data: union {
		Canvas_Draw_Primitive_Command,
		Canvas_Draw_Image_Command,
	},
	times: int,
}

canvas_set_color :: proc(
	canvas: ^Canvas,
	color: Color,
) {
	canvas.draw_state.color = color
}

canvas_draw_rect :: proc(
	canvas: ^Canvas,
	x, y, width, height: f32,
	rotation: f32 = 0.0,
) {
	append(
		&canvas.core.primitive_instances.data,
		Canvas_Primitive_Instance{
			translation = {x + width * 0.5, -y - height * 0.5},
			scale = {width * 0.5, height * 0.5},
			rotation = rotation,
			modulation = cast([4]f32)canvas.draw_state.color,
		},
	)
	_canvas_draw_commands_append(
		&canvas.core.draw_commands,
		Canvas_Draw_Command{
			data = Canvas_Draw_Primitive_Command{
				type = .Rect,
			},
			times = 1,
		},
	)
}

canvas_draw_image :: proc(
	canvas: ^Canvas,
	image: ^Image,
	x, y: f32,
	width: f32 = -1.0,
	height: f32 = -1.0,
	rotation: f32 = 0.0,
) {
	width, height := width, height
	if width < 0 do width = f32(image.width)
	if height < 0 do height = f32(image.height)
	append(
		&canvas.core.image_instances.data,
		Canvas_Primitive_Instance{
			translation = {x + width * 0.5, -y - height * 0.5},
			scale = {width * 0.5, height * 0.5},
			rotation = rotation,
			modulation = cast([4]f32)canvas.draw_state.color,
		},
	)
	_canvas_draw_commands_append(
		&canvas.core.draw_commands,
		Canvas_Draw_Command{
			data = Canvas_Draw_Image_Command{
				image = image,
			},
			times = 1,
		},
	)
}

// Appends a draw command to a dynamic array of them, combining the command with
// the top item if they're batchable.
_canvas_draw_commands_append :: proc(
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
				cmd_img_hash := command.data.(Canvas_Draw_Image_Command).image.core.hash
				top_img_hash := top.data.(Canvas_Draw_Image_Command).image.core.hash
				if cmd_img_hash == top_img_hash {
					top.times += command.times
					return
				}
			}
		}
	}
	append(commands, command)
}
