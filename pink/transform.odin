package pink

import "core:intrinsics"

xywh :: proc(
	x, y, w, h: $N,
) -> Transform where intrinsics.type_is_numeric(N) {
	return Transform{
		rect = {f32(x), f32(y), f32(w), f32(h)},
		rotation = 0,
	}
}
