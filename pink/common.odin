package pink

import "core:fmt"
import "core:math/linalg"
import sdl "vendor:sdl2"

// ************************************************************************** //
// Type Definitions & Constants
// ************************************************************************** //

Color :: linalg.Vector4f32

PINK :: Color{0.839215, 0.392157, 0.517647, 1.0}

// ************************************************************************** //
// Procedures
// ************************************************************************** //

// Prints an error message. Use for recoverable errors.
error_report :: proc(error: $E/Error) {
	msg := fmt.aprintf("Error [%s]: %s", error.type, error.message); defer delete(msg)
	fmt.eprintln(msg)
}

// Reports a fatal error via a message box. Use for unrecoverable errors.
error_report_fatal :: proc(error: $E/Error) {
	msg := fmt.aprintf(
		"Fatal error (%s): %s. The program will now close.",
		error.type,
		error.message,
	)
	defer delete(msg)
	fmt.eprintln(msg)
	sdl.ShowSimpleMessageBox(
		{.ERROR},
		"Unrecoverable Error",
		cast(cstring) raw_data(msg),
		nil,
	)
}
