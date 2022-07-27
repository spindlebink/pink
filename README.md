# Pink

![BSD-3 License](https://img.shields.io/badge/license-BSD--3-green.svg)
![Cool](https://img.shields.io/badge/very%20cool%3F-yeah-orange.svg)

A game framework in [the Odin programming language](https://odin-lang.org) modeled after [LÖVE](https://love2d.org).

> **Pink is in early development and is missing a lot of basic features.** If you're wanting to make a game *now*, and you're hankering for the framework experience, I recommend:
> * [LÖVE if you're generally a fan of good things](https://love2d.org)
> * [Raylib if you're set on Odin](https://pkg.odin-lang.org/vendor/raylib/): there are vendor bindings for it

## Status

Pink is still early in development. It's not ready for use yet. Most features are missing, and it only runs on Linux at the moment. If you're intrepid enough, you're welcome to try it out:

```sh
# Clone the repository
git clone https://codeberg.org/spindlebink/pink
cd pink && git submodule update --init

# Download and build the libraries Pink depends on
./prereqs_linux.sh

# Run `main.odin`
odin run .
```

## Contributing

Feel free! Fork and pull request. I'd most appreciate help with:

* Cross-platform support. Odin makes this super easy, but the Windows side of my desktop isn't set up for development and I haven't had the heart to wrestle with the Windows dev experience right now.

## License

BSD 3-clause. Under it, you can:
* Modify the framework and redistribute it
* Place a warranty on it
* Use the framework in a closed-source project
