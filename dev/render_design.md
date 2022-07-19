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
