# API Drafting

We're looking for consistency, explicitness, and simplicity. You should be able to read Pink's API and immediately understand how to write a program using it.

If a subsystem or procedure or group of them or whatever is marked **Not MVP**, it's part of an eventual version of Pink but probably won't make it into the MVP.

> Why am I going to such trouble to articulate this design before even making it? Like a lot of game devs, I've been wanting to write a game framework since I first started writing games. To keep this project from overshadowing actual game development (never make a game engine if you want to make a game!), I'm trying to put a lot of care into this engine. It's a long-term project, and I won't be able to wait on its completion before continuing to write games.

## Error Handling

Odin doesn't have try/catch by design. Therefore, each subsystem defines its own error type based on the model of:

```odin
Error :: struct {
	type: Error_Type,
	message: string,
}
```

> Determine if we need more granularity over error members--would a union work better?

Each subsystem also has standard error handling procedures:

```odin
pink.subsystem_ok() -> bool
pink.subsystem_error() -> Subsystem_Error
pink.subsystem_clear_error()
```

> We will eventually need a user-facing error system to present errors which should be handled by the user--if not dealt with, they should probably halt the game and alert the error in window or something similar.

## Subsystems

Following are the currently-planned subsystems constituting Pink.

### Runtime

The runtime subsystem handles program lifetime and the game loop.

```odin
// Lifetime callbacks
pink.runtime_set_load_proc(callback: proc())
pink.runtime_set_ready_proc(callback: proc())
pink.runtime_set_update_proc(callback: proc(delta: f64))
pink.runtime_set_fixed_update_proc(callback: proc(delta: f64))
pink.runtime_set_exit_proc(callback: proc())

// Call to begin the program
pink.runtime_configure(config: pink.Runtime_Configuration)
pink.runtime_go()

// Runtime properties
pink.runtime_fps() -> f64
pink.runtime_timestep() -> f64
pink.runtime_fixed_timestep() -> f64
```

### Canvas

The canvas subsystem handles an immediate-mode graphics API. The word "canvas" implies two dimensions and associates the API with a DOM canvas, which works similarly. It also allows for an eventual retained-state API set in a different namespace, if that ends up being a goal.

> `float` here refers to an as-yet undecided and unnamed precision of floating-point number which will be used for canvas transform information.

```odin
// Primitive rendering
pink.canvas_draw_rect(x, y, width, height: float)
pink.canvas_draw_circle(x, y, radius: float)
pink.canvas_draw_image(image: Image, x, y, width, height: float)
pink.canvas_draw_image_slice(
	image: Image,
	x, y, width, height: float,
	slice_x, slice_y, slice_width, slice_height: float,
)
pink.canvas_draw_text(
	font: Font,
	text: string,
	x, y: float,
)

// Transformation state
pink.canvas_translate(x, y: float)
pink.canvas_scale(x, y: float)
pink.canvas_rotate_rad(theta: float)
pink.canvas_rotate_deg(theta: float)

// Style state
pink.canvas_set_color(color: Color)
pink.canvas_set_color_rgba(r, g, b, a: f32)

// State stack
pink.canvas_state_push()
pink.canvas_state_push_style()
pink.canvas_state_push_transform()
pink.canvas_state_pop()
```

**Not MVP:**

```odin
pink.canvas_draw_rounded_rect(x, y, width, height, corner_radius: float)
pink.canvas_draw_line(points: []Coord)

// Stroke state is part of style state
pink.canvas_set_stroke_color(color: Color)
pink.canvas_set_stroke_color_rgba(r, g, b, a: f32)
pink.canvas_set_stroke_width(width: float)
```

### Asset

**Not MVP.** For the MVP, we'll just `#load` file data where it's needed.

The asset subystem provides access to assets which can be loaded at runtime. Depending on compile-time flags, these assets may be encoded into the program as a baked file system (design question: what features does `#load` not support for this use case?), or they may be pointed to as part of an OS-specific bundle or a fused executable.

> We might use PhysFS for this. I think LÖVE does.

Ultimately, asset loader subsystems (image and font, for instance) should have central methods to load struct contents from a slice of `u8`s, and loading an image for instance would look similar to:

```odin
img := pink.image_load_png(pink.asset_read_bytes("resources/image.png"))
```

> Is it worth doing something like Godot does with prefixes for file locations? Doing so would need to be part of a more complete `fs_*` subsystem.

### Image

The image subsystem loads images into data structures which can be used for canvas calls.

```odin
pink.image_load_png(bytes: []u8) -> Image
pink.image_load_bmp(bytes: []u8) -> Image
// Etc. with formats--initial format support undecided
```

### Font

The font subsystem loads fonts and provides procedures for querying their metrics.

Any eventual text layout happens at the juncture of this subsystem and the canvas subsystem. Ideally, we wouldn't have duplicate methods in the canvas subsystem to wrap text or format it as LÖVE does, relying instead on more distinct, generalized APIs to first wrap the text (maybe in this namespace, generating a slice of lines?), then calling into the canvas subsystem to render them.

* Might bind to FreeType
* Check if Odin's vendor bindings are enough
	* Is SDL_ttf enough? Can it be used if we're not using SDL's rendering?
	* What about `stb_ttf`?

```odin
pink.font_load_ttf(bytes: []u8) -> Font
pink.font_measure_string(font: Font, str: string) -> width, height: float
pink.font_wrap(font: Font, str: string, width: float) -> []string
```

> Wrapping text will possibly return character ranges instead of multiple strings, or we may do an iterator on wrapped lines.

Need to explore the problem domain further before we can fully design this API.

### Render

**Probably not exposed to the user.**

The render subsystem is a thin abstraction layer over WebGPU. We still want to write rendering code using WGPU, but this subsystem makes object initialization and management easier.

It should:
* Abstract out basic setup of adapter/device/surface
* Handle GPU errors
* Provide convenient buffer management
	* Buffer struct with stored size and resizing
	* Buffer ring (name undecided) for double- or triple- (or quadruple- etc.) buffering
* Make pipeline management clean and non-verbose
	* Where are the pain/boilerplate points with WebGPU right now?

```odin
// Buffer management
Render_Buffer :: struct {
	buffer: wgpu.Buffer,
	size: u32,
}

pink.render_buffer_create() -> Render_Buffer
pink.render_buffer_ensure_size(buffer: ^Render_Buffer, size: u32)
pink.render_buffer_destroy(buffer: ^Render_Buffer)

// Buffer ring management
Render_Buffer_Ring :: struct {
	active: ^Render_Buffer,
	active_index: int,
	buffers: [BUFFER_RING_SIZE]Render_Buffer,
}

pink.render_buffer_ring_create() -> Render_Buffer_Ring
pink.render_buffer_ring_advance(ring: ^Render_Buffer_Ring)
pink.render_buffer_ring_destroy(ring: ^Render_Buffer_Ring)
```

Need to explore the problem domain further before we can fully design this API.
