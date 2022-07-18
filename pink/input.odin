package pink

import "core:fmt"
import sdl "vendor:sdl2"

Modifier_Key :: enum {
	L_Shift,
	R_Shift,
	L_Ctrl,
	R_Ctrl,
	L_Alt,
	R_Alt,
	L_Super,
	R_Super,
	Num_Lock,
	Caps_Lock,
	Scroll_Lock,
	Ctrl,
	Shift,
	Alt,
	Super,
}
Modifier_Keys :: bit_set[Modifier_Key]

Key :: enum {
	Escape,
	F1,
	F2,
	F3,
	F4,
	F5,
	F6,
	F7,
	F8,
	F9,
	F10,
	F11,
	F12,
	Print_Screen,
	Scroll_Lock,
	Pause,
	Mute,
	Volume_Down,
	Volume_Up,
	Grave,
	Num_1,
	Num_2,
	Num_3,
	Num_4,
	Num_5,
	Num_6,
	Num_7,
	Num_8,
	Num_9,
	Num_0,
	Minus,
	Equal,
	Backspace,
	Tab,
	A,
	B,
	C,
	D,
	E,
	F,
	G,
	H,
	I,
	J,
	K,
	L,
	M,
	N,
	O,
	P,
	Q,
	R,
	S,
	T,
	U,
	V,
	W,
	X,
	Y,
	Z,
	L_Bracket,
	R_Bracket,
	Backslash,
	Caps_Lock,
	Semicolon,
	Apostrophe,
	Enter,
	L_Shift,
	Comma,
	Period,
	Slash,
	R_Shift,
	L_Ctrl,
	L_Super,
	L_Alt,
	Space,
	R_Alt,
	R_Super,
	Fn,
	R_Ctrl,
	Insert,
	Home,
	Page_Up,
	Delete,
	End,
	Page_Down,
	Up,
	Left,
	Down,
	Right,
	Num_Lock,
	Keypad_Slash,
	Keypad_Star,
	Keypad_Minus,
	Keypad_Plus,
	Keypad_Enter,
	Keypad_0,
	Keypad_1,
	Keypad_2,
	Keypad_3,
	Keypad_4,
	Keypad_5,
	Keypad_6,
	Keypad_7,
	Keypad_8,
	Keypad_9,
	Keypad_Period,
}
Keys :: bit_set[Key]

@(private)
sdl_key_lookups := map[sdl.Scancode]Key{
	.A = .A,
	.B = .B,
	.C = .C,
	.D = .D,
	.E = .E,
	.F = .F,
	.G = .G,
	.H = .H,
	.I = .I,
	.J = .J,
	.K = .K,
	.L = .L,
	.M = .M,
	.N = .N,
	.O = .O,
	.P = .P,
	.Q = .Q,
	.R = .R,
	.S = .S,
	.T = .T,
	.U = .U,
	.V = .V,
	.W = .W,
	.X = .X,
	.Y = .Y,
	.Z = .Z,
	.NUM1 = .Num_1,
	.NUM2 = .Num_2,
	.NUM3 = .Num_3,
	.NUM4 = .Num_4,
	.NUM5 = .Num_5,
	.NUM6 = .Num_6,
	.NUM7 = .Num_7,
	.NUM8 = .Num_8,
	.NUM9 = .Num_9,
	.NUM0 = .Num_0,
	.RETURN = .Enter,
	.ESCAPE = .Escape,
	.BACKSPACE = .Backspace,
	.TAB = .Tab,
	.SPACE = .Space,
	.MINUS = .Minus,
	.EQUALS = .Equal,
	.LEFTBRACKET = .L_Bracket,
	.RIGHTBRACKET = .R_Bracket,
	.BACKSLASH = .Backslash,
	.SEMICOLON = .Semicolon,
	.APOSTROPHE = .Apostrophe,
	.GRAVE = .Grave,
	.COMMA = .Comma,
	.PERIOD = .Period,
	.SLASH = .Slash,
	.CAPSLOCK = .Caps_Lock,
	.F1 = .F1,
	.F2 = .F2,
	.F3 = .F3,
	.F4 = .F4,
	.F5 = .F5,
	.F6 = .F6,
	.F7 = .F7,
	.F8 = .F8,
	.F9 = .F9,
	.F10 = .F10,
	.F11 = .F11,
	.F12 = .F12,
	.PRINTSCREEN = .Print_Screen,
	.SCROLLLOCK = .Scroll_Lock,
	.PAUSE = .Pause,
	.INSERT = .Insert,
	.DELETE = .Delete,
	.HOME = .Home,
	.END = .End,
	.PAGEUP = .Page_Up,
	.PAGEDOWN = .Page_Down,
	.RIGHT = .Right,
	.LEFT = .Left,
	.UP = .Up,
	.DOWN = .Down,
	.KP_DIVIDE = .Keypad_Slash,
	.KP_MULTIPLY = .Keypad_Star,
	.KP_MINUS = .Keypad_Minus,
	.KP_PLUS = .Keypad_Plus,
	.KP_ENTER = .Keypad_Enter,
	.KP_PERIOD = .Keypad_Period,
	.KP_1 = .Keypad_1,
	.KP_2 = .Keypad_2,
	.KP_3 = .Keypad_3,
	.KP_4 = .Keypad_4,
	.KP_5 = .Keypad_5,
	.KP_6 = .Keypad_6,
	.KP_7 = .Keypad_7,
	.KP_8 = .Keypad_8,
	.KP_9 = .Keypad_9,
	.KP_0 = .Keypad_0,
	.MUTE = .Mute,
	.VOLUMEUP = .Volume_Up,
	.VOLUMEDOWN = .Volume_Down,
	.LCTRL = .L_Ctrl,
	.LSHIFT = .L_Shift,
	.LALT = .L_Alt,
	.LGUI = .L_Super,
	.RCTRL = .R_Ctrl,
	.RSHIFT = .R_Shift,
	.RALT = .R_Alt,
	.RGUI = .R_Super,
}

@(private)
sdl_mod_key_lookups := map[sdl.KeymodFlag]Modifier_Key{
	.LSHIFT = .L_Shift,
	.RSHIFT = .R_Shift,
	.LCTRL = .L_Ctrl,
	.RCTRL = .R_Ctrl,
	.LALT = .L_Alt,
	.RALT = .R_Alt,
	.LGUI = .L_Super,
	.RGUI = .R_Super,
	.NUM = .Num_Lock,
	.CAPS = .Caps_Lock,
}

@(private)
mouse_button_from_sdl :: proc(button: u8) -> Mouse_Button {
	if button == sdl.BUTTON_LEFT {
		return .Left
	} else if button == sdl.BUTTON_RIGHT {
		return .Right
	} else if button == sdl.BUTTON_MIDDLE {
		return .Middle
	}
	return .Left
}

@(private)
key_mod_state_from_sdl :: proc() -> Modifier_Keys {
	mods: Modifier_Keys
	sdl_mods := sdl.GetModState()
	
	for key_mod in sdl.KeymodFlag {
		if key_mod in sdl_mods {
			if pk_mod, found := sdl_mod_key_lookups[key_mod]; found {
				mods += {pk_mod}
			}
		}
	}
	
	if .LSHIFT in sdl_mods || .RSHIFT in sdl_mods do mods += {.Shift}
	if .LALT in sdl_mods || .RALT in sdl_mods do mods += {.Alt}
	if .LCTRL in sdl_mods || .RCTRL in sdl_mods do mods += {.Ctrl}
	if .LGUI in sdl_mods || .RGUI in sdl_mods do mods += {.Super}
	
	return mods
}

@(private)
key_state_from_sdl :: proc() -> Keys {
	keys: Keys
	state := sdl.GetKeyboardState(nil)
	for scancode in sdl.Scancode {
		if state[int(scancode)] != 0 {
			if pk_key, found := sdl_key_lookups[scancode]; found {
				keys += {pk_key}
			}
		}
	}
	return keys
}

// @(private)
// key_state_from_sdl :: proc(
// 	state: ^map[Key]bool,
// ) {
// 	sdl_state := sdl.GetKeyboardState(nil)
// 	for scancode in sdl.Scancode {
// 		if pk_key, found := sdl_key_lookups[scancode]; found {
// 			state[pk_key] = sdl_state[int(scancode)] != 0
// 		}
// 	}
// }
