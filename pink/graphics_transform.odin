package pink

import "core:math/linalg"

Coord :: struct {
	x: f32,
	y: f32,
}

Transform :: linalg.Matrix4x4f32

// TODO
transform_translate :: proc(what: Transform, by: Coord) -> Transform {
	return what
}

// TODO
transform_scale :: proc(what: Transform, by: Coord) -> Transform {
	return what
}

// TODO
transform_rotate :: proc(what: Transform, by: f32) -> Transform {
	return what
}

// TODO
coord_transform :: proc(what: Coord, by: Transform) -> Coord {
	return what
}

// TODO
coord_translate :: proc(what: Coord, by: Transform) -> Coord {
	return what
}

// TODO
coord_scale :: proc(what: Coord, by: Transform) -> Coord {
	return what
}

// TODO
coord_rotate :: proc(what: Coord, by: Transform) -> Coord {
	return what
}
