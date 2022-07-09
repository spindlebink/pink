# Text Rendering Design

Scratchpad for designing how text rendering will work.

We use Fontdue for rendering and probably for layout as well. It provides:

* Methods to obtain a SDF bitmap from font glyphs
* Methods to lay out text which return glyph position information for each one

I can think of several levels of robustness/completeness for an eventual Pink text renderer:

* Unreasonably naive: stepping through each letter, rendering it, generating a texture, and pushing it to the GPU with a draw call
	* Re-renders text every single time a letter is requested
	* Easy to implement, sloppy as hell
* Storing a hash map of letters with textures, adding to the hash map when a letter is required, pushing to GPU
	* 1 draw call per glyph, which would need to be addressed in a final version
* Texture cache based on last-used basis, rendering glyphs to a GPU texture and clipping them out for characters i.e. I think the standard way
	* Initial version might lay out font cache in a grid, but later there's [rect packing here](https://web.archive.org/web/20220120051005/https://blackpawn.com/texts/lightmaps/)--research other methods as well
		* Depending on how easy the algorithm ends up being to implement, we might skip the grid version and go right for the packed one
		* Although speed isn't *that* important, since we'll be only adding to the font cache when the charset gets too big
	* For one immediate-mode call, we:
		* Lay out glyphs w/ fontdue layout method, which is fast and does no rendering
		* Generate instance vertices for each glyph
			* X/Y/width/height, UV scale from font atlas
		* Push it to the draw command queue like anything else
	* Render text with a single draw call this way, since all text from one font would use a single texture
		* Case to catch: what happens if text that's supposed to be rendered in one draw call exceeds the font cache texture?
			* When fonts are bigger, it would likely be fairly common
			* Hyper-hyper edge case note: single letter too big for texture at all
			* If we determine this happening, split text rendering into multiple draw commands w/ another font cache texture
				* The font cache system will need to be its own data structure with its own management methods--design in this doc
			* Doing so should be telegraphed from the font cache
				* Ideally with a configurable, rotating set of cache textures which can be written to and swapped out on demand

## Prior Art

* [FontStash](https://github.com/memononen/fontstash)
	* Good description of caching:
		```
		fonsDrawText() {
			foreach (glyph in input string) {
				if (internal buffer full) {
					updateTexture()
					render()
				}
				add glyph to internal draw buffer
			}
			updateTexture()
			render()
		}
		```

## Process

Pink divides rendering into two phases: collecting draw commands and executing them on the GPU.

Type drafting:

* Font struct, created from byte data, incorporating one or more faces at a uniform size
	* Incorporate a render cache as well. One per face?
	* Lower-level control: you can pass a render cache into text drawing functions to keep from using the font's built-in one and potentially save cache rebuilds if you know the characters you're using
* Render cache
	* Query UVs, generate queue commands to copy a rasterized glyph bitmap to cache texture
	* Cache holds bitmap data only for as long as it takes to copy it to the texture
		* This happens during flush, during the render frame prior to actually drawing anything
	* Configurable texture size

Process stuff:

* To queue for drawing (i.e. canvas call)
	* For each unique glyph in the string
		* Add glyph to list of glyphs we need this frame
			* If it's already in the texture, we're good
			* Otherwise, attempt to pack it into the CPU-side rect layout
				* If it packs, mark the glyph as needing uploading to the GPU and proceed
				* Otherwise, when we reach this point during render we *first* need to flush all outstanding text drawing commands, clear the cache, and begin again
		* Store coordinates of layout
		* Can we actually do this all during render? Then a draw text command just takes text and cycles them per the `fonsDrawText` pseudocode above

Pseudocode:

```odin
case Canvas_Text_Draw_Command:
	to_draw := cmd.text
	for character in to_draw { // character here is a glyph position, not just a letter
		if ok := font_cache_ensure(character); ok {
			// code path if the character is either already in the font cache or is able to be packed into it--i.e. don't need to flush+rebuild cache
			append_vertex_buffer_glyph_data(font_cache_get_vertex_data(character))
		} else {
			flush_and_do_draw_calls_for_current_glyph_data()
			// clear the current texture and write the last waiting bitmap (stored in memory at font_cache_ensure) to the new one
			font_cache_next()
		}
		flush_and_do_draw_calls_for_current_glyph_data()
	}
```
