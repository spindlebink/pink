# Render design scratchpad

The current abstraction (`pink/render`) is a little cobbled-together based on need.

Things that are good about it:
* Very little abstraction from WGPU--the render system should just be a set of tools that makes working with WGPU easier, not an attempt at *further* abstracting an already abstracted system
	* With that said, if we define our domains well, developing something like `sokol_gfx` as a renderer isn't a bad idea

Things that are bad about it:
* Messy and unfocused, without a good sense of how types interact
* Brittle, exposes information on an as-needed basis, when we need something new exposed it usually involves library-wide renaming and modification
* The `Painter` struct is too abstracted
* There's a ton of duplicated shader code
* There's no way to do custom shaders and no obvious path toward them

Stuff to check out:
* https://github.com/floooh/sokol/blob/master/sokol_gfx.h
* https://github.com/edubart/sokol_gp
* https://github.com/icculus/SDL/blob/gpu-api/include/SDL_gpu.h

Notes:

* `sokol_gp` does an interesting thing where pipelines for primitive types are stored in an `_sgp.pipelines` array and looked up according to primitive type
	* This would be an improvement for Pink: right now we've got fixed pipelines for each primitive type and they're super brittle
	* `sokol_gp` may also use this for custom shaders? Need to read closer

The current renderer design targets the canvas system rather than vice-versa. `Painter` abstractions only exist in the context of a canvas: other drawing systems may use different methods. This means that a `Painter` type, if still deemed necessary, should be defined within the canvas system and not on the renderer side, the way `sokol_gp` does it with what it calls pipelines.

## Design

Renderer runs on global state. User-side does no handling of device, adapter, swapchain, etc. Design should be general enough to accomodate multiple targets--WGPU for desktop but also WebGL for our initial WASM target, since WebGPU still isn't standardized and hence isn't available in most browsers.

Types:

* `Pipeline`: a graphics pipeline, representing a rendering path based on zero or more vertex buffers, zero or more uniform buffers, and one paired vertex and fragment shader
* `Shader`: a shader comprising zero or one vertex shaders and zero or one fragment shaders used in the creation of a `Pipeline`
* `Buffer`: a buffer holding vertex or instance data, can be resized, written to, etc., and contains information for its own attributes
	* There is no writing of arbitrary `rawptr` data to a buffer: buffers handle their data via arrays which can be cleared, appended to, etc., using a transparent `data` `[]T`
	* Copying data from the CPU-side buffer to the GPU happens with a `buf_copy`
	* Index buffers are just `Buffer(uint)`, when/if we want to add them eventually--usage for a buffer can be specified elsewhere, maybe during pipeline creation?
* `Uniform`: a fixed-size buffer holding a uniform struct, writeable once per render frame, generally at frame start
* `Texture`: width/height/channels/data. Can be used as the render target of a pass or bound as input to a pipeline.
	* Just as with a buffer, we have a `tex_copy` call to queue a texture copy, and data modification happens using direct access to a `data` array
* `Pass`: a render pass

Canvas system pseudocode:
```odin
canvas_frame_begin :: proc() {
	pkr.pass_begin(&canvas_state.pass)
}

canvas_frame_flush :: proc() {
	for command in canvas_commands {
		switch in command {
		case Cmd_Draw_Rect:
			append(&rect_instance_buf.data, command.data_to_append)
		}
	}
}

canvas_frame_end :: proc() {
	for _, i in filled_buffers {
		pkr.buf_copy(&filled_buffers[i])
	}

	pkr.pass_end(&canvas_state.pass)
}
```
