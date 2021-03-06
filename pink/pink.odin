package pink

import "core:intrinsics"
import "core:math/linalg"

PINK_PINK :: Color{0.839215, 0.392157, 0.517647, 1.0}

Color :: linalg.Vector4f32

Rect :: struct($N: typeid) where intrinsics.type_is_numeric(N) {
	x, y, w, h: N,
}

Recti :: Rect(int)
Rectf :: Rect(f32)

Transform :: struct {
	using rect: Rectf,
	origin: [2]f32,
	rotation: f32,
}
