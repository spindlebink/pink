# Component design scratchpad

We're approaching a renderer MVP for Pink. I've learned a lot during development. Doing so was a primary goal of the framework, but it also means design has been less intentional and careful and more of a "we need this, let's put it here" thing.

Now that we're getting to an MVP and hence a structural redesign, I'd like to put time into figuring out *what* exactly Pink is and how it works.

Things that really work in the current design:
* It's clear and generally convenient

Things that don't really work in the current design:
* There's a lot of passing around of pointers to functions
	* Every `canvas_*` call requires that you get the address of `program.canvas` and send it as a first argument. I did it this way to avoid a single global context, but is this really necessary?
	* The frameworks most inspiring to this project (Raylib and LÖVE) use a single global context
	* Think more on this
* As is the case with the renderer abstraction, there's not a clear sense of hierarchy or overarching design.

## Redesign notes

For a redesign of the API, I'd like to reconsider
* Pink's identity as a framework. I keep trying to make it work like LÖVE, but it *shouldn't*: it's written in a lower-level language using lower-level concepts. It doesn't have to be a game-dev-beginner-friendly framework.
	* Things should be *appropriately complex*: if something requires twelve distinct steps programmed normally, we should abstract away the complexities and annoyances of those steps, but we shouldn't be afraid of exposing each step to the user
	* A good example: the text API. Although it's very much incomplete, I like the separation of typeface, glyphset, and layout. It's the way text normally has to be done in an engine, so it makes perfect sense to expose it this way to the user, compared with the more black-boxy nature of LÖVE or Raylib's text functions.
* The relationship of each component to the whole. Pink should be **a collection of related, separately-importable tools**, not a single interlocking web of them.
	* We may emulate the way `core:image` does it, and provide a private registration proc that loads up a component when it's imported
	* We may simply require that the user do things themselves: a runtime loop is a `for true {}` followed by `program_frame_begin()`, `canvas_frame_begin()`, etc. instead of the current massive `program_run` loop
		* This is in keeping with Pink's slightly lower-level niche
	* Each system holds its own global state?

## Tools

Brainstorming of tools that might be worth including in Pink. Not all of these will or should be included. Some of them are also better implemented as user-side plugins or systems, or as vendor plugins.

* `app`: window context, input, framerate, lifetime callbacks, necessary in all programs
	* can/should this be split into `runtime`/`window`/`input`/any other components?
* `render`: GPU layer used internally -> `app`
* `canvas`: immediate-mode graphics -> `render`
* `gfx2d`: retained-mode 2D graphics -> `render`
* `gfx3d`: retained-mode 3D graphics -> `render`
* `text`: text rasterization and layout -> `render`
* `imui`: RayGUI-style immediate-mode UI -> `canvas`
* `asset`: PhysFS-based asset bundling, may not need to depend on anything
* `audio`: sound -> `app`, or may depend on a `render`-like audio layer--need to figure this out when we get around to audio
* `timer`: timers -> `app`
* `anim`: animations and tweening -> `app`
