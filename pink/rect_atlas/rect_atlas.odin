package rect_atlas

import "core:intrinsics"

Atlas :: struct($R: typeid)
	where intrinsics.type_has_field(R, "x") &&
				intrinsics.type_has_field(R, "y") &&
				intrinsics.type_has_field(R, "w") &&
				intrinsics.type_has_field(R, "h") &&
				intrinsics.type_is_numeric(intrinsics.type_field_type(R, "x")) &&
				intrinsics.type_is_numeric(intrinsics.type_field_type(R, "y")) &&
				intrinsics.type_is_numeric(intrinsics.type_field_type(R, "w")) &&
				intrinsics.type_is_numeric(intrinsics.type_field_type(R, "h")) {
	spaces: [dynamic]R,
}

// Cases for splitting empty space in an atlas.
Atlas_Split_Result :: enum {
	Too_Small,
	Just_Right,
	Once,
	Twice,
}

// Clears a rect atlas and sets it up for packing with a given space size.
atlas_clear :: proc(
	atlas: ^Atlas($R),
	side_size: $N,
) where intrinsics.type_is_numeric(N) {
	clear(&atlas.spaces)
	append(&atlas.spaces, R{
		x = 0,
		y = 0,
		w = side_size,
		h = side_size,
	})
}

// Destroys a rect atlas.
atlas_destroy :: proc(
	atlas: Atlas($R),
) {
	delete(atlas.spaces)
}

// Packs a rectangle into an atlas if it fits. Returns whether or not it could
// be packed. Sets `rect`'s `x`/`y` if it fits.
atlas_pack :: proc(
	atlas: ^Atlas($R),
	rect: ^R,
) -> bool {
	for i := len(atlas.spaces) - 1; i >= 0; i -= 1 {
		space := atlas.spaces[i]
		target_space := i
		if rect.w <= space.w && rect.h <= space.h {
			atlas.spaces[target_space] = atlas.spaces[len(atlas.spaces) - 1]
			pop(&atlas.spaces)
			small_split := R{}
			big_split := R{}
			split_result := _atlas_split(
				atlas,
				rect^,
				space,
				&small_split,
				&big_split,
			)
			switch split_result {
			case .Too_Small:
				append(&atlas.spaces, space)
			case .Just_Right:
				rect.x, rect.y = space.x, space.y
				return true
			case .Once:
				rect.x, rect.y = space.x, space.y
				append(&atlas.spaces, small_split)
				return true
			case .Twice:
				rect.x, rect.y = space.x, space.y
				append(&atlas.spaces, big_split)
				append(&atlas.spaces, small_split)
				return true
			}
		}
	}
	return false
}

// Split a space to fit a rectangle into it, retrieving the size for the smaller
// and larger splits if they're calculated.
//
// We take an atlas parameter but don't use it so that we can use its type
// specification.
_atlas_split :: proc(
	atlas: ^Atlas($R),
	rect: R,
	space: R,
	small: ^R,
	big: ^R,
) -> Atlas_Split_Result {
	free_w, free_h := space.w - rect.w, space.h - rect.h

	// Rect won't fit into space/rect fits perfectly into space
	if free_w < 0 || free_h < 0 do return .Too_Small
	if free_w == 0 && free_h == 0 do return .Just_Right
	
	// Rect fits perfectly in one dimension = create only one split
	if free_w > 0 && free_h == 0 {
		small.x = space.x + rect.w
		small.y = space.y
		small.w = space.w - rect.w
		small.h = space.h
		return .Once
	} else if free_w == 0 && free_h > 0 {
		small.x = space.x
		small.y = space.y + rect.h
		small.w = space.w
		small.h = space.h - rect.h
		return .Once
	}
	
	// Otherwise two splits
	if free_w > free_h {
		big.x = space.x + rect.w
		big.y = space.y
		big.w = free_w
		big.h = space.h
		small.x = space.x
		small.y = space.y + rect.h
		small.w = rect.w
		small.h = free_h
	} else {
		big.x = space.x
		big.y = space.y + rect.h
		big.w = space.w
		big.h = free_h
		small.x = space.x + rect.w
		small.y = space.y
		small.w = free_w
		small.h = rect.h
	}

	return .Twice
}
