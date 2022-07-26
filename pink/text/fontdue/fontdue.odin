package fontdue

when ODIN_OS == .Linux || ODIN_OS == .Darwin {
	foreign import ftd "system:fontdue_native"
}

import "core:c"

// Types

CoordinateSystem :: enum c.int {
	PositiveYUp,
	PositiveYDown,
}

HorizontalAlign :: enum c.int {
	Left,
	Center,
	Right,
}

VerticalAlign :: enum c.int {
	Top,
	Middle,
	Bottom,
}

WrapStyle :: enum c.int {
	Word,
	Letter,
}

Font :: rawptr

FontSettings :: struct {
	collection_index: c.uint32_t,
	scale: c.float,
}

Char :: c.uint32_t

GlyphMapping :: struct {
	character: Char,
	index: c.uint16_t,
}

LineMetrics :: struct {
	ascent: c.float,
	descent: c.float,
	line_gap: c.float,
	new_line_size: c.float,
}

OutlineBounds :: struct {
	xmin: c.float,
	ymin: c.float,
	width: c.float,
	height: c.float,
}

Metrics :: struct {
	xmin: c.int32_t,
	ymin: c.int32_t,
	width: c.size_t,
	height: c.size_t,
	advance_width: c.float,
	advance_height: c.float,
	bounds: OutlineBounds,
}

GlyphBitmap :: struct {
	metrics: Metrics,
	data: [^]c.uint8_t,
	data_length: c.size_t,
}

GlyphRasterConfig :: struct {
	glyph_index: c.uint16_t,
	px: c.float,
	font_hash: c.uintptr_t,
}

OpaqueCharacterData :: [1]c.uint8_t

CharacterData :: struct {
	_cd: OpaqueCharacterData,
}

Layout :: rawptr

LayoutSettings :: struct {
	x: c.float,
	y: c.float,
	constrain_width: c.bool,
	max_width: c.float,
	constrain_height: c.bool,
	max_height: c.float,
	horizontal_align: HorizontalAlign,
	vertical_align: VerticalAlign,
	wrap_style: WrapStyle,
	wrap_hard_breaks: c.bool,
}

LinePosition :: struct {
	baseline_y: c.float,
	padding: c.float,
	max_ascent: c.float,
	min_descent: c.float,
	max_line_gap: c.float,
	max_new_line_size: c.float,
	glyph_start: c.size_t,
	glyph_end: c.size_t,
}

GlyphUserData :: rawptr

TextStyle :: struct {
	text: cstring,
	px: c.float,
	font_index: c.uintptr_t,
	user_data: GlyphUserData,
}

GlyphPosition :: struct {
	key: GlyphRasterConfig,
	font_index: c.uintptr_t,
	parent: Char,
	x: c.float,
	y: c.float,
	width: c.size_t,
	height: c.size_t,
	byte_offset: c.size_t,
	char_data: CharacterData,
	user_data: GlyphUserData,
}

// Function

@(link_prefix = "ftd_")
foreign ftd {
	// Font functions
	
	font_new_from_bytes :: proc(
		bytes: [^]c.uint8_t,
		size: c.size_t,
		settings: FontSettings,
	) -> Font ---

	font_free :: proc(
		font: Font,
	) ---
	
	font_chars :: proc(
		font: Font,
		chars: [^]GlyphMapping,
	) ---
	
	font_char_count :: proc(
		font: Font,
	) -> c.size_t ---

	font_horizontal_line_metrics :: proc(
		font: Font,
		px: c.float,
		line_metrics: ^LineMetrics,
	) -> c.bool ---

	font_vertical_line_metrics :: proc(
		font: Font,
		px: c.float,
		line_metrics: ^LineMetrics,
	) -> c.bool ---
	
	font_units_per_em :: proc(
		font: Font,
	) -> c.float ---
	
	font_scale_factor :: proc(
		font: Font,
		px: c.float,
	) -> c.float ---
	
	font_horizontal_kern :: proc(
		font: Font,
		left: Char,
		right: Char,
		px: c.float,
		kerning: ^c.float,
	) -> c.bool ---
	
	font_horizontal_kern_indexed :: proc(
		font: Font,
		left: c.uint16_t,
		right: c.uint16_t,
		px: c.float,
		kerning: ^c.float,
	) -> c.bool ---
	
	font_metrics :: proc(
		font: Font,
		character: Char,
		px: c.float,
		metrics: ^Metrics,
	) ---
	
	font_metrics_indexed :: proc(
		font: Font,
		index: c.uint16_t,
		px: c.float,
		metrics: ^Metrics,
	) ---
	
	font_rasterize_config :: proc(
		font: Font,
		config: GlyphRasterConfig,
		bitmap: ^GlyphBitmap,
	) ---
	
	font_rasterize :: proc(
		font: Font,
		character: Char,
		px: c.float,
		bitmap: ^GlyphBitmap,
	) ---

	font_rasterize_config_subpixel :: proc(
		font: Font,
		config: GlyphRasterConfig,
		bitmap: ^GlyphBitmap,
	) ---
	
	font_rasterize_subpixel :: proc(
		font: Font,
		character: Char,
		px: c.float,
		bitmap: ^GlyphBitmap,
	) ---

	font_rasterize_indexed :: proc(
		font: Font,
		index: c.uint16_t,
		px: c.float,
		bitmap: ^GlyphBitmap,
	) ---

	font_rasterize_indexed_subpixel :: proc(
		font: Font,
		index: c.uint16_t,
		px: c.float,
		bitmap: ^GlyphBitmap,
	) ---
	
	font_lookup_glyph_index :: proc(
		font: Font,
		character: Char,
	) -> c.uint16_t ---
	
	font_glyph_count :: proc(
		font: Font,
	) -> c.uint16_t ---
	
	// Character data functions
	
	char_data_classify :: proc(
		character: Char,
		index: c.uint16_t,
		data: ^CharacterData,
	) ---
	
	char_data_rasterize :: proc(
		char_data: CharacterData,
	) -> c.bool ---

	char_data_is_whitespace :: proc(
		char_data: CharacterData,
	) -> c.bool ---
	
	char_data_is_control :: proc(
		char_data: CharacterData,
	) -> c.bool ---
	
	char_data_is_missing :: proc(
		char_data: CharacterData,
	) -> c.bool ---
	
	// Layout functions
	
	layout_new :: proc(
		coordinate_system: CoordinateSystem,
	) -> Layout ---
	
	layout_free :: proc(
		layout: Layout,
	) ---
	
	layout_reset :: proc(
		layout: Layout,
		settings: LayoutSettings,
	) ---
	
	layout_clear :: proc(
		layout: Layout,
	) ---
	
	layout_height :: proc(
		layout: Layout,
	) -> c.float ---
	
	layout_lines_count :: proc(
		layout: Layout,
	) -> c.uint16_t ---
	
	layout_lines :: proc(
		layout: Layout,
		lines: [^]LinePosition,
	) -> c.bool ---
	
	layout_append :: proc(
		layout: Layout,
		fonts: [^]Font,
		font_count: c.size_t,
		style: TextStyle,
	) ---
	
	layout_glyphs :: proc(
		layout: Layout,
		glyphs: [^]GlyphPosition,
	) ---
	
	layout_glyphs_count :: proc(
		layout: Layout,
	) -> c.size_t ---
}
