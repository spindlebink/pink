package pink

import "core:intrinsics"

rect_trans :: #force_inline proc(
	x, y, w, h: $N,
) -> Transform where intrinsics.type_is_numeric(N) {
	return Transform{
		rect = {f32(x), f32(y), f32(w), f32(h)},
		rotation = 0,
	}
}

rect_trans_centered :: #force_inline proc(
	x, y, w, h: $N,
) -> Transform where intrinsics.type_is_numeric(N) {
	return Transform{
		rect = {f32(x), f32(y), f32(w), f32(h)},
		origin = {0.5, 0.5},
		rotation = 0,
	}
}
