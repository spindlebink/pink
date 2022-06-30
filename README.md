# Pink

A WIP game framework in [the Odin programming language](https://odin-lang.org) modeled after [LÖVE](https://love2d.org).

**This is not currently usable.** It's primarily a learning project. The code may be messy, unsafe, less-than-fully-designed, and in most places missing or non-functional.

## Status?

We've got:

* Runtime callbacks (load, ready, update, fixed update, draw, and exit)
* Drawing axis-aligned rectangles

That's about it right now. My current tasks are:

* Completing a renderer MVP
  * For the MVP, I'm planning on supporting rectangle and circle primitives and images. *Maybe* text. The eventual target is a dedicated 2D renderer like NanoVG. Writing a 3D engine is outside of scope at the moment.
  * The MVP renderer will operate in immediate-mode using calls like `graphics_draw_rectangle`. It'll also have a state stack which allows you to do easier graphics transformations on top of themselves. As mentioned, LÖVE is my model at the moment--once I get to an okay state, I'll do more design branching.
* Debug handling that doesn't suck
  * I had an initial idea of writing a little tracing debug system (the hack job you see in the engine now), but I've just discovered that there's a built-in Odin package for something similar already, so I'll be swapping over to that soon.

## Contributing

Feel free! Fork and pull request. I'm just figuring this stuff out. It may or may not turn into anything.
