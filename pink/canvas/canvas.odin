package pk_canvas

import "core:fmt"
import "core:math/linalg"
import pk ".."
import "../render"

@(init, private)
_module_init :: proc() {
	pk._core.hooks.cnv_init = init
	pk._core.hooks.cnv_destroy = destroy
	pk._core.hooks.cnv_frame_begin = frame_begin
	pk._core.hooks.cnv_frame_end = frame_end
}

_core: Core

@(private)
Core :: struct {
	frame_began: bool,
	pass: render.Pass,
	hooks: Core_Hooks,
}

@(private)
Core_Hooks :: struct {
	imd_init: proc(),
	imd_destroy: proc(),
	imd_flush: proc(^render.Pass),
}

/*
 * Initialize
 */

init :: proc() {
	if _core.hooks.imd_init != nil { _core.hooks.imd_init() }
}

/*
 * Destroy
 */

destroy :: proc() {
	if _core.hooks.imd_destroy != nil { _core.hooks.imd_destroy() }
}

/*
 * Frame Begin/End
 */

frame_begin :: proc() {
	if _core.frame_began { return }
	
	_core.pass = render.pass_begin()
	_core.frame_began = true
}

frame_end :: proc() {
	if !_core.frame_began { return }

	if _core.hooks.imd_flush != nil { _core.hooks.imd_flush(&_core.pass) }

	render.pass_end(_core.pass)
	_core.frame_began = false
}
