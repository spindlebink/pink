package pink

Rect_Atlas :: struct {
	spaces: [dynamic]Rect,
}

// Cases for splitting empty space in an atlas.
Rect_Atlas_Split_Result :: enum {
	Too_Small,
	Just_Right,
	Once,
	Twice,
}

// Clears a rect atlas and sets it up for packing with a given space size.
rect_atlas_clear :: proc(atlas: ^Rect_Atlas, side_size: int) {
	clear(&atlas.spaces)
	append(&atlas.spaces, Rect{0, 0, side_size, side_size})
}

// Destroys a rect atlas.
rect_atlas_destroy :: proc(atlas: ^Rect_Atlas) {
	delete(atlas.spaces)
}

// Packs a rectangle into an atlas if it fits. Returns whether or not it could
// be packed. Sets `rect`'s `x`/`y` if it fits.
rect_atlas_pack :: proc(atlas: ^Rect_Atlas, rect: ^Rect) -> bool {
	for i := len(atlas.spaces) - 1; i >= 0; i -= 1 {
		space := atlas.spaces[i]
		target_space := i
		if rect.w <= space.w && rect.h <= space.h {
			atlas.spaces[target_space] = atlas.spaces[len(atlas.spaces) - 1]
			pop(&atlas.spaces)
			small_split := Rect{}
			big_split := Rect{}
			split_result := _rect_atlas_split(
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
_rect_atlas_split :: proc(
	rect: Rect,
	space: Rect,
	small: ^Rect,
	big: ^Rect,
) -> Rect_Atlas_Split_Result {
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
