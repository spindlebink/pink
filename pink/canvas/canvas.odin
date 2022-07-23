package pk_canvas

import "core:fmt"
import "core:math/linalg"
import pk ".."
import "../app"
import "../render"

@(init, private)
_module_init :: proc() {
	app._core.hooks.cnv_init = init
	app._core.hooks.cnv_destroy = destroy
	app._core.hooks.cnv_frame_begin = frame_begin
	app._core.hooks.cnv_frame_end = frame_end
}

// Internal state. Shouldn't generally be accessed user-side.
_core: Core

@(private)
Core :: struct {
	trans: [2]f32, // TODO: matrix instead applied during draw commands
	color: pk.Color,
	frame_began: bool,

	cmds: [dynamic]Command_Invoc,

	pass: render.Pass,
	vbuf: render.Buffer,
	ubuf: render.Buffer,

	solid_buf: render.Buffer,
	solid_insts: [dynamic]Draw_Inst,
	solid_shader: render.Shader,
	solid_pipeline: render.Pipeline,
}

/*
 * Initialize
 */

init :: proc() {
	// render.shader_init_wgsl(&_core.image_shader, #load("image_shader.wgsl"))
	
	_core.color = pk.Color{1.0, 1.0, 1.0, 1.0}

	vert_attrs := VERT_ATTRS
	draw_inst_attrs := DRAW_INST_ATTRS
	image_inst_attrs := IMAGE_INST_ATTRS
	
	_core.ubuf.usage = .Uniform
	
	render.buffer_init(&_core.vbuf)
	render.buffer_init(&_core.ubuf, size_of(Data_Uniform))
	
	render.buffer_init(&_core.solid_buf)
	render.shader_init_wgsl(&_core.solid_shader, #load("solid_shader.wgsl"))
	render.pipeline_init(
		&_core.solid_pipeline,
		_core.solid_shader,
		[]render.Buffer_Layout{
			{
				usage = .Vertex,
				stride = size_of(Vertex),
				attributes = vert_attrs[:],
			},
			{
				usage = .Instance,
				stride = size_of(Draw_Inst),
				attributes = draw_inst_attrs[:],
			}
		},
		[]render.Binding{
			{.Uniform},
		}
	)
	
	render.buffer_copy(&_core.vbuf, []Vertex{
		Vertex{{-1.0, 1.0}},
		Vertex{{1.0, 1.0}},
		Vertex{{-1.0, -1.0}},
		Vertex{{-1.0, -1.0}},
		Vertex{{1.0, 1.0}},
		Vertex{{1.0, -1.0}},
	})
}

/*
 * Destroy
 */

destroy :: proc() {
	delete(_core.cmds)
	delete(_core.solid_insts)
	render.buffer_destroy(_core.solid_buf)
	render.pipeline_destroy(_core.solid_pipeline)
	render.shader_destroy(_core.solid_shader)
	// render.shader_destroy(_core.image_shader)
}

/*
 * Frame Begin/End
 */

frame_begin :: proc() {
	if _core.frame_began { return }
	
	_core.pass = render.pass_begin()
	_core.frame_began = true
}

frame_end :: proc() {
	if !_core.frame_began { return }

	flush()

	render.pass_end(_core.pass)
	_core.frame_began = false
}

/*
 * Flush
 */

flush :: proc() {
	if !_core.frame_began { return }
	
	// Write global canvas uniform
	
	w_s := 2.0 / f32(app.window.width)
	h_s := 2.0 / f32(app.window.height)
	win := linalg.Matrix4x4f32{
		w_s, 0.0, 0.0, 0.0,
		0.0, h_s, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		-1.0, 1.0, 0.0, 1.0,
	}

	render.buffer_copy(&_core.ubuf, &Data_Uniform{
		window_to_device = win,
	})
	render.pass_set_binding_uniform(&_core.pass, 0, _core.ubuf)
	
	if _core.solid_buf.size < size_of(Draw_Inst) * len(_core.solid_insts) {
		render.buffer_reinit(&_core.solid_buf, size_of(Draw_Inst) * len(_core.solid_insts) * 2)
	}
	
	render.buffer_copy(&_core.solid_buf, _core.solid_insts[:])

	current_solid := uint(0)
	
	for cmd, i in _core.cmds {
		switch in cmd.cmd {
		
		case Draw_Solid_Command:
			render.pass_set_pipeline(&_core.pass, _core.solid_pipeline)
			render.pass_set_buffers(&_core.pass, _core.vbuf, _core.solid_buf)
			
			switch cmd.cmd.(Draw_Solid_Command).type {
			case .Rect:
				render.pass_draw(&_core.pass, 0, 6, current_solid, cmd.times)
			}
			
			current_solid += cmd.times
		
		case Draw_Image_Command:

		}
	}
	
	clear(&_core.cmds)
	clear(&_core.solid_insts)
}
