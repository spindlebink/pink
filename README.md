# Pink

A WIP game framework in [the Odin programming language](https://odin-lang.org) modeled after [LÖVE](https://love2d.org).

**This is not currently usable.** It's primarily a learning project at this point.

* [Codeberg repo](https://codeberg.org/spindlebink/pink)
* [GitHub mirror](https://github.com/spindlebink/pink)

## Odin?

Odin is an absurdly well-designed programming language that's essentially all the good parts of C, plus a lot of more convenient features like generics, minus the 50-odd years of cruft C has accumulated while trying to stay up-to-date. You should definitely learn it. It's the ideal language for a minimalist framework like Pink.

## Project Goals?

Pink is *super* early in development right now, but progress is happening quickly.

On the design side, it targets:

* **Cleanness and orthogonality**
  * Components should do their own thing and do it well
  * Higher-level functionality builds on top of lower-level functionality
  * Few to no redundancies, and few to no black boxes
* **Self-evidence**
  * Robust docs at a later state, but functions should be understandable at a glance
  * You should be able to pick up the framework and use it on an introductory level even if you're given only an unexplained catalog of the framework's components
* **Control over convenience**
  * Pink is modeled after LÖVE, but its niche is a little lower-level than LÖVE: Odin is a very different language from Lua and implies a different level of control
  * Little to no hiding of implementation details
  * Access to the framework on multiple levels
    * For example: the current design draft for text renderering requires font cache structures to track rasterized glyphs in an atlas
      * Using a lot of different glyphs quickly means the rasterized glyphs may exceed atlas space, so we have to clear it and re-rasterize glyphs, which is a non-zero performance cost
      * By default, Pink will store its own font caches for fonts
      * But you should be able to also pass in a `pink.Font_Render_Cache` (or whatever it ends up being named) of your own to text rendering functions
        * This way, if you know what characters you're going to use for instances of text drawing, you can ensure the atlases are baked correctly and avoid cache rebuilds
* **Design features for programmers who want to make their own game engine but don't want to make their own game engine**
  * Doing lower level programming for game development is fun, but most people probably like the *theory* of writing a game engine more than actually writing it: GPU programming is complex, verbose, and often tedious; designing an effective API is a big task; concerns like text rendering are highly complex
  * Pink should be sufficiently low-level to provide high control from an engine built on top of it, but high-level enough for users to not worry about implementation details unless they want to
  * It should read as a collection of tools that complement each other well rather than a monolithic, my-way-or-the-highway engine

## Status?

We've got:

* Runtime callbacks (load, ready, update, fixed update, draw, and exit)
* Drawing rectangles and images with position, rotation, size, and color modulation

That's about it right now. I'm currently designing a text renderer.

The longer-term goals for this prototypical form of Pink are:

* Completing a renderer MVP
  * The renderer operates in immediate-mode using calls like `canvas_draw_rect` during an `on_draw` program hook
  * It also will feature a transformation and style state stack
  * You will be able to draw a few geometry primitives, images, image slices (i.e. from an atlas), and text
* Completing the input system MVP
  * Modeled after LÖVE, the input system works off program hooks--`on_mouse_down`, `on_key_down`, etc.
  * You'll also be able to retrieve the current input state of components on demand--`mouse_state(&state)`, `key_state(&state)`, etc.
* Documenting the framework's internals. Too few projects document their implementation details, which makes contribution difficult. It's a (possible pipe) dream of mine for this to become a Real Open Source Entity.

## Limitations?

Pretty much everything right now. Pink is very much an infant framework. It also currently runs exclusively on Linux.

## Contributing

Feel free! Fork and pull request. I'm just figuring this stuff out. It may or may not turn into anything.

Things that I'd most appreciate help with:
* Cross-platform support. Odin makes this super easy, but the Windows side of my desktop isn't set up for development and I haven't had the heart to wrestle with the Windows dev experience right now.
