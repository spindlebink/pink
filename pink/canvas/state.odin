package pk_canvas

import pk ".."

STATE_STACK_SIZE :: 1024

@(private)
EMPTY_STATE :: State{
	color = {1.0, 1.0, 1.0, 1.0},
	translation = {0.0, 0.0},
	rotation = 0.0,
}

// Canvas's current color and transform.
State :: struct {
	color: pk.Color,
	translation: [2]f32,
	rotation: f32,
}

@(private)
State_Memo :: struct {
	state: State,
	type: enum {
		All,
		Transform,
		Style,
	},
}

@(private)
push_memo :: proc(memo: State_Memo) {
	if _core.state_head >= STATE_STACK_SIZE {
		panic("canvas state stack overflow")
	}
	_core.state_stack[_core.state_head] = memo
}

push :: #force_inline proc() { push_memo(State_Memo{_core.state, .All}) }
push_style :: #force_inline proc() { push_memo(State_Memo{_core.state, .Style}) }
push_transform :: #force_inline proc() { push_memo(State_Memo{_core.state, .Transform}) }

pop :: proc() {
	if _core.state_head == 0 {
		_core.state = EMPTY_STATE
	} else {
		_core.state_head -= 1
		memo := _core.state_stack[_core.state_head]
		switch memo.type {
		case .All:
			_core.state = memo.state
		case .Transform:
			_core.state.translation = memo.state.translation
		case .Style:
			_core.state.color = memo.state.color
		}
	}
}

set_color_rgba :: #force_inline proc(r, g, b, a: f32) {
	_core.state.color.r = r
	_core.state.color.g = g
	_core.state.color.b = b
	_core.state.color.a = a
}

set_color_rgb :: #force_inline proc(r, g, b: f32) {
	_core.state.color.r = r
	_core.state.color.g = g
	_core.state.color.b = b
}

set_color_struct :: #force_inline proc(color := pk.Color{1.0, 1.0, 1.0, 1.0}) {
	_core.state.color = color
}

set_color :: proc{
	set_color_struct,
	set_color_rgba,
	set_color_rgb,
}

translate :: #force_inline proc(x, y: f32) {
	_core.state.translation[0] += x
	_core.state.translation[1] += y
}
