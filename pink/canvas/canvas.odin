package pk_canvas

import "core:fmt"
import "core:math/linalg"
import pk ".."
import "../render"

@(init, private)
_module_init :: proc() {
	pk._core.hooks.cnv_init = init
	pk._core.hooks.cnv_destroy = destroy
	pk._core.hooks.cnv_frame_begin = frame_begin
	pk._core.hooks.cnv_frame_end = frame_end
}

// Internal state. Shouldn't generally be accessed user-side.
_core: Core

@(private)
Core :: struct {
	frame_began: bool,

	cmds: [dynamic]Command_Invoc,
	state: State,
	state_stack: [STATE_STACK_SIZE]State_Memo,
	state_head: int,

	pass: render.Pass,
	ubuf: render.Buffer,

	solid_vbuf: render.Buffer,
	solid_ibuf: render.Buffer,
	solid_insts: [dynamic]Draw_Inst,
	solid_shader: render.Shader,
	solid_pipeline: render.Pipeline,

	image_vbuf: render.Buffer,
	image_ibuf: render.Buffer,
	image_insts: [dynamic]Image_Inst,
	image_shader: render.Shader,
	image_pipeline: render.Pipeline,
}

/*
 * Initialize
 */

init :: proc() {
	// fmt.println("draw instances are", size_of(Draw_Inst), "bytes")
	// fmt.println("image instances are", size_of(Image_Inst), "bytes")
	
	_core.state = EMPTY_STATE

	vert_attrs := VERT_ATTRS
	draw_inst_attrs := DRAW_INST_ATTRS
	image_vert_attrs := IMAGE_VERT_ATTRS
	image_inst_attrs := IMAGE_INST_ATTRS
	
	_core.ubuf.usage = .Uniform
	
	shader_header := #load("header.wgsl")
	
	render.buffer_init(&_core.ubuf, size_of(Data_Uniform))
	
	render.buffer_init(&_core.solid_vbuf)
	render.buffer_init(&_core.solid_ibuf)
	render.shader_init_wgsl(&_core.solid_shader, #load("solid_shader.wgsl"), shader_header)
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
			{.Uniform}, // canvas global uniform
		}
	)
	
	push_constants: []render.Push_Constant
	when render.USE_PUSH_CONSTANTS {
		push_constants = {{.Fragment, size_of(Image_Pipeline_Push_Constants)}}
	}
	
	render.buffer_init(&_core.image_vbuf)
	render.buffer_init(&_core.image_ibuf)
	render.shader_init_wgsl(&_core.image_shader, #load("image_shader.wgsl"), shader_header)
	render.pipeline_init(
		&_core.image_pipeline,
		_core.image_shader,
		[]render.Buffer_Layout{
			{
				usage = .Vertex,
				stride = size_of(Image_Vertex),
				attributes = image_vert_attrs[:],
			},
			{
				usage = .Instance,
				stride = size_of(Image_Inst),
				attributes = image_inst_attrs[:],
			},
		},
		[]render.Binding{
			{.Uniform},         // canvas global uniform
			{.Texture_Sampler}, // texture+sampler
		},
		push_constants, // TODO: push constants seem to have regressed WGPU-side,
		                // but it'd be nice to use them for things like RGBA/grayscale
		                // flags instead of putting it in instance data
	)
	
	render.buffer_copy(&_core.solid_vbuf, []Vertex{
		Vertex{{-1.0, 1.0}},
		Vertex{{1.0, 1.0}},
		Vertex{{-1.0, -1.0}},
		Vertex{{-1.0, -1.0}},
		Vertex{{1.0, 1.0}},
		Vertex{{1.0, -1.0}},
	})
	render.buffer_copy_slice(&_core.image_vbuf, []Image_Vertex{
		Image_Vertex{{-1.0, 1.0}, {0, 1}},
		Image_Vertex{{1.0, 1.0}, {2, 1}},
		Image_Vertex{{-1.0, -1.0}, {0, 3}},
		Image_Vertex{{-1.0, -1.0}, {0, 3}},
		Image_Vertex{{1.0, 1.0}, {2, 1}},
		Image_Vertex{{1.0, -1.0}, {2, 3}},
	})
}

/*
 * Destroy
 */

destroy :: proc() {
	delete(_core.cmds)
	delete(_core.solid_insts)
	delete(_core.image_insts)
	render.buffer_destroy(_core.solid_vbuf)
	render.buffer_destroy(_core.solid_ibuf)
	render.pipeline_destroy(_core.solid_pipeline)
	render.shader_destroy(_core.solid_shader)
	render.buffer_destroy(_core.image_vbuf)
	render.buffer_destroy(_core.image_ibuf)
	render.pipeline_destroy(_core.image_pipeline)
	render.shader_destroy(_core.image_shader)
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
	
	w_s := 2.0 / f32(pk.window.width)
	h_s := 2.0 / f32(pk.window.height)
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
	
	// Ensure buffers are big enough to hold this frame's instance data, then
	// copy CPU data to them
	{
		if _core.solid_ibuf.size < size_of(Draw_Inst) * len(_core.solid_insts) {
			render.buffer_reinit(&_core.solid_ibuf, size_of(Draw_Inst) * len(_core.solid_insts) * 2)
		}
		if _core.image_ibuf.size < size_of(Image_Inst) * len(_core.image_insts) {
			render.buffer_reinit(&_core.image_ibuf, size_of(Image_Inst) * len(_core.image_insts) * 2)
		}
		render.buffer_copy(&_core.solid_ibuf, _core.solid_insts[:])
		render.buffer_copy(&_core.image_ibuf, _core.image_insts[:])
	}

	current_solid := uint(0)
	current_image := uint(0)

	in_rgba_mode := true
	
	for cmd, i in _core.cmds {
		switch in cmd.cmd {
		
		case Draw_Solid_Command:
			render.pass_set_pipeline(&_core.pass, _core.solid_pipeline)
			render.pass_set_buffers(&_core.pass, _core.solid_vbuf, _core.solid_ibuf)
			
			switch cmd.cmd.(Draw_Solid_Command).type {
			case .Rect:
				render.pass_draw(&_core.pass, 0, 6, current_solid, cmd.times)
			}
			
			current_solid += cmd.times
		
		case Draw_Image_Command:
			tex := cmd.cmd.(Draw_Image_Command).texture

			render.pass_set_pipeline(&_core.pass, _core.image_pipeline)
			render.pass_set_buffers(&_core.pass, _core.image_vbuf, _core.image_ibuf)
			render.pass_set_binding_texture(&_core.pass, 1, tex)

			// if tex._fmt == .Gray && in_rgba_mode {
			// 	render.pass_set_push_constants(&_core.pass, Image_Pipeline_Push_Constants{
			// 		rgba_convert = true,
			// 	})
			// 	in_rgba_mode = false
			// } else if tex._fmt == .RGBA && !in_rgba_mode {
			// 	render.pass_set_push_constants(&_core.pass, Image_Pipeline_Push_Constants{
			// 		rgba_convert = false,
			// 	})
			// 	in_rgba_mode = true
			// }

			render.pass_draw(&_core.pass, 0, 6, current_image, cmd.times)
			
			current_image += cmd.times

		}
	}
	
	clear(&_core.cmds)
	clear(&_core.solid_insts)
	clear(&_core.image_insts)
}
