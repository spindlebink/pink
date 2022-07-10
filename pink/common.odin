package pink

import "core:intrinsics"
import "core:math/linalg"

PINK_PINK :: Color{0.839215, 0.392157, 0.517647, 1.0}

@(private)
SHADER_HEADER :: #load("resources/shader_header.wgsl")

Color :: linalg.Vector4f32

Rect :: struct($N: typeid) where intrinsics.type_is_numeric(N) {
	x, y, w, h: N,
}

Recti :: Rect(int)
Rectf :: Rect(f32)
