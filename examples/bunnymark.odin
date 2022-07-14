package bunnymark

import "core:fmt"
import "core:math/rand"
import "../pink"

ctx: Context

Instance :: struct {
	pos: [2]f32,
	vel: [2]f32,
	rot_speed: f32,
	rot: f32,
}

Context :: struct {
	program: pink.Program,
	image: pink.Image,
	instances: [dynamic]Instance,
}

GRAVITY :: f32(0.001)
VELOCITY_SCALE :: f32(0.25)
ROTATION_SPEED_BASE :: f32(0.05)
PER_MORE :: 1000

on_load :: proc() {
	ctx.image = pink.image_create_from_data(
		#load("wut.png"),
		pink.Image_Options{
			mag_filter = .Nearest,
		},
	)
}

on_update :: proc(delta: f64) {
	dt := f32(delta)
	win_width := f32(ctx.program.window.width)
	win_height := f32(ctx.program.window.height)
	for _, i in ctx.instances {
		inst := &ctx.instances[i]
		
		inst.pos[0] = inst.pos[0] + inst.vel[0] * dt * VELOCITY_SCALE
		inst.pos[1] = inst.pos[1] + inst.vel[1] * dt * VELOCITY_SCALE
		inst.rot += inst.rot_speed * dt * VELOCITY_SCALE
		
		if inst.pos[0] < 0 {
			inst.vel[0] = abs(inst.vel[0])
		} else if inst.pos[0] > win_width {
			inst.vel[0] = -abs(inst.vel[0])
		}
		
		inst.vel[1] += GRAVITY * dt
		if inst.pos[1] > win_height {
			inst.vel[1] = -abs(inst.vel[1])
		}
	}
}

on_mouse_button_down :: proc(x, y: int, button: pink.Mouse_Button) {
	more_instances()
}

on_draw :: proc() {
	hw, hh := f32(ctx.image.width) * 0.5, f32(ctx.image.height) * 0.5
	sw, sh := f32(ctx.image.width) * 2, f32(ctx.image.height) * 2
	for _, i in ctx.instances {
		inst := &ctx.instances[i]
		test := inst.pos.yx
		pink.canvas_draw_image(
			&ctx.program.canvas,
			&ctx.image,
			pink.Transform{
				rect = {x = inst.pos.x, y = inst.pos.y, w = sw, h = sh},
				rotation = inst.rot,
			}
		)
	}
}

on_exit :: proc() {
	delete(ctx.instances)
	pink.image_destroy(&ctx.image)
}

more_instances :: proc() {
	TWO_PI: f32 : 3.1415926 * 2.0
	for i := 0; i < PER_MORE; i += 1 {
		inst := Instance{
			pos = [2]f32{
				rand.float32() * f32(ctx.program.window.width),
				rand.float32() * f32(ctx.program.window.height),
			},
			vel = [2]f32{
				-1.0 if rand.float32() < 0.5 else 1.0,
				0.0,
			},
			rot = rand.float32() * TWO_PI,
			rot_speed = rand.float32() * ROTATION_SPEED_BASE,
		}
		append(&ctx.instances, inst)
	}
	fmt.println("instances:", len(ctx.instances))
}

main :: proc() {
	ctx.program.hooks.on_load = on_load
	ctx.program.hooks.on_update = on_update
	ctx.program.hooks.on_mouse_button_down = on_mouse_button_down
	ctx.program.hooks.on_draw = on_draw
	ctx.program.hooks.on_exit = on_exit
	
	pink.program_load(&ctx.program)
	pink.program_run(&ctx.program)
	pink.program_exit(&ctx.program)
}
