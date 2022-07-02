package pink

import "core:fmt"
import sdl "vendor:sdl2"

// ************************************************************************** //
// Procedures
// ************************************************************************** //

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
