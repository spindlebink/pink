package main

import "core:fmt"
import "core:mem"
import "core:time"
import "pink"
import "pink/im_draw"
import "pink/image"
import "pink/text"
import "pink/fs"

// It's generally a good idea to store global program state stuff in its own
// structure rather than as separate floating variables. If we were making an
// actual game we'd be more careful+organized about this, but that's a different
// topic.
ctx: struct {
	wut_img: image.Image,
	typeface: text.Typeface,
	glyphset: text.Glyphset,
	layout: text.Layout,
}

// Added to app hooks during main proc. During `load`, you can preload resources
// and set up program-wide stuff.
on_load :: proc() {
	using ctx
	
	wut_img = image.load_from_bytes(#load("resources/wut.png"), image.Options{
		mag_filter = .Nearest,
		min_filter = .Nearest,
	})
	
	// Typefaces represent a font file. They serve little use outside of glyphsets.
	typeface = text.typeface_load_from_bytes(#load("resources/Dosis-Regular.ttf"))
	
	// We defined `ctx.glyphset` earlier, and it doesn't have an initialization
	// function, so we can use it right away. Here we're rendering some common
	// characters into the glyphset's atlas pages. We provide:
	// * The typeface to use for rasterization
	// * The size for letters within this character set to be rasterized at
	// * The character set to rasterize
	// Rasterizing a set of characters makes them drawable to a canvas context
	// through the `Glyphset` structure.
	text.glyphset_add(
		&glyphset,
		typeface,
		88.0,
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890, ?",
	)
	// Finally, we bake the glyphset, a fairly intensive process that packs our
	// glyphs and renders each pageful into a GPU-usable texture. 
	text.glyphset_bake(&glyphset)
	
	// Layouts allow us to lay out text from a typeface into lines and direct the
	// canvas system on how and where to draw image slices from a Glyphset.
	text.layout_init(&layout)
	
	// Layouts are completely glyphset-agnostic and represent only the computed
	// positions for glyphs. Here we append lines of various sizes to the layout.
	for text_size := f32(12); text_size < 88; text_size += 8 {
		text.layout_add(&layout, typeface, text_size, "Five great quacking zephyrs jolt my wax bed\n")
	}
	// You'll need to call `layout_update` after you're done adding text
	text.layout_update(&layout)

	// Finally, we bind a glyphset to the layout for drawing. This tells the
	// layout which glyphset to use to render its computed glyphs. In almost every
	// case, you'll want to bind a glyphset constructed from the same typeface you
	// used to calculate the layout.
	text.layout_bind_drawing_glyphset(&layout, &glyphset)
}

// Added to app hooks during main proc. Here we unload stuff we loaded during
// `on_load`.
on_exit :: proc() {
	using ctx
	
	image.destroy(wut_img)
	text.glyphset_destroy(glyphset)
	text.typeface_destroy(typeface)
	text.layout_destroy(layout)
}

on_draw :: proc() {
	using ctx
	
	// Draw a staggered grid of `wut_img`
	for x: f32 = 0; x < 8; x += 1 {
		for y: f32 = 0; y < 8; y += 1 {
			im_draw.image(
				wut_img,
				pink.Transform{
					rect = {
						x * 64 + f32(int(x + y) % 2) * 64,
						y * 64,
						64,
						64,
					},
				},
			)
		}
	}

	// And also draw our text layout
	im_draw.draw(layout, {rect = {0, 0, 0, 0}})
}

main :: proc() {
	tracker: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracker, context.allocator)
	defer mem.tracking_allocator_destroy(&tracker)
	context.allocator = mem.tracking_allocator(&tracker)
	defer if len(tracker.allocation_map) > 0 {
		fmt.eprintln()
		for _, v in tracker.allocation_map {
			fmt.eprintf("%v - leaked %v bytes\n", v.location, v.size)
		}
	}

	// A convenient way to configure your app is to copy the constant
	// `pink.DEFAULT_CONFIG` and only touch the parameters you need to change.
	conf := pink.DEFAULT_CONFIG
	conf.framerate_cap = 60.0

	pink.hooks.on_load = on_load
	pink.hooks.on_draw = on_draw
	pink.hooks.on_exit = on_exit

	pink.conf(conf)
	pink.load()
	pink.run()
	pink.exit()
}
