# Pink

![BSD-3 License](https://img.shields.io/badge/license-BSD--3-green.svg)
![Cool](https://img.shields.io/badge/very%20cool%3F-yeah-orange.svg)

A game framework in [the Odin programming language](https://odin-lang.org) modeled after [LÖVE](https://love2d.org).

* [Codeberg repo](https://codeberg.org/spindlebink/pink)
* [GitHub mirror](https://github.com/spindlebink/pink)

**Pink is in early development and is missing a lot of basic features.** If you're wanting to make a game *now*, and you're hankering for the framework experience, I recommend:

* [LÖVE if you're generally a fan of good things](https://love2d.org)
* [Raylib if you're set on Odin](https://pkg.odin-lang.org/vendor/raylib/)--there are vendor bindings for it

## Project Goals

It's still early, but progress happens quickly. Pink is designed for:

* **Cleanness and orthogonality**: each component should do a single thing and do it well.
* **Control over convenience**: although Pink takes after LÖVE, our niche is lower-level, so our mechanics should reflect that.

## Status

**We're in the middle of an API redesign and reimplementation, so functionality has regressed.** The high-water mark for what's been supported incorporates:

* A window context and runtime callbacks
* An immediate-mode canvas renderer
  * Rectangle primitives
  * Images and slices of images
  * Text
* Typefaces and text layout

Goals for an initial version are:

* A renderer equipped to handle a decent subset of indie-budget 2D games
  * An immediate-mode canvas API
  * Shape primitives, images, and text as initial drawables
  * A canvas state stack
* A window context with callback-based input and lifetime handling
* Documentation for the framework's user-facing API and for its internals

## Contributing

Feel free! Fork and pull request. I'd most appreciate help with:

* Cross-platform support. Odin makes this super easy, but the Windows side of my desktop isn't set up for development and I haven't had the heart to wrestle with the Windows dev experience right now.

## License

BSD 3-clause. Under it, you can:
* Modify the framework and redistribute it
* Place a warranty on it
* Use the framework in a closed-source project
