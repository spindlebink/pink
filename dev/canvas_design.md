# Canvas system design scratchpad

The current system works well, but I want to make sure everything's thought through for this rewrite.

Things that don't work in the current system:
* It's not very scalable engine-side.
	* Adding new drawing types means implementing a whole new pipeline/painter
	* In a redesign, we should really evaluate how many types of painters we need
* It's easy to break the batcher
	* This may be inherent to auto-batching methods
	* Check in on `sokol_gp`'s auto-batching: it's slightly more sophisticated and may be worth implementing in a future version
* There's no clear path toward custom shaders
	* Could creating a shader = making a new set of painters?

API drafting:
```odin
frame_begin()
frame_end()

push(scope)
pop()
translate(x, y)
scale(x, y)
rotate(r)
set_color(color)

draw_rect(transform)
draw_img(img, transform, slice_recti)
```
