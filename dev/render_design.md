# Render design scratchpad

The current abstraction (`pink/render`) is a little cobbled-together based on need.

Things that are good about it:
* Very little abstraction from WGPU--the render system should just be a set of tools that makes working with WGPU easier, not an attempt at *further* abstracting an already abstracted system

Things that are bad about it:
* Messy and unfocused, without a good sense of how types interact
* Brittle, exposes information on an as-needed basis, when we need something new exposed it usually involves library-wide renaming and modification
* The `Painter` struct is too abstracted

Design thoughts forthcoming.
