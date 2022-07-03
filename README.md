# Pink

A WIP game framework in [the Odin programming language](https://odin-lang.org) modeled after [LÖVE](https://love2d.org).

**This is not currently usable.** It's primarily a learning project at this point.

## Odin?

Odin is an absurdly well-designed programming language that's essentially all the good parts of C, plus a lot of more convenient features like generics, minus the 50-odd years of cruft C has accumulated while trying to stay up-to-date. You should definitely learn it. It's the ideal language for a minimalist framework like Pink.

## Project Goals?

* Cleanness and orthogonality in the spirit of Odin. Individual framework components should do their own thing and do it well. Higher-level functionality builds on top of lower-level functionality--few to no black boxes.
* Self-documentation. When the framework is at a more complete state, I want to ensure there are robust docs, but ideally most functions should be understandable at a glance: `image_load_png() -> Image` followed by `canvas_draw_img(&image, x, y, width, height)`, for example.
* Pick-up-and-playness. Frameworks like LÖVE and Raylib are fun to use (for me, at least--YMMV) because they often scratch the itch most game developers have to make their own engines, but do so without requiring that you get down in the weeds of GPU programming and cross-platform support.

## Status?

We've got:

* Runtime callbacks (load, ready, update, fixed update, draw, and exit)
* Drawing axis-aligned rectangles
* Drawing axis-aligned images

That's about it right now. My current tasks are:

* Completing a renderer MVP
  * For the MVP, I'm planning on supporting rectangle and circle primitives and images. *Maybe* text. The eventual target is a dedicated 2D renderer like NanoVG. Writing a 3D engine is outside of scope at the moment.
  * The MVP renderer will operate in immediate-mode using calls like `canvas_draw_rect`. It'll also have a state stack which allows you to do easier graphics transformations on top of themselves. LÖVE is my model at the moment--once I get to an okay state, I'll do more design branching.
* Documenting the framework's internals. Too few projects document their implementation details, which makes contribution difficult. It's a (possible pipe) dream of mine for this to become a Real Open Source Entity.

## Limitations?

Pretty much everything right now. Pink is very much an infant framework. It also currently runs exclusively on Linux.

## Contributing

Feel free! Fork and pull request. I'm just figuring this stuff out. It may or may not turn into anything.

Things that I'd appreciate help with, besides core stuff of course:
* Cross-platform support. Odin makes this super easy, but the Windows side of my desktop isn't set up for development and I haven't had the heart to wrestle with the Windows dev experience right now.
