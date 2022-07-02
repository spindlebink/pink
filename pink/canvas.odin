package pink

// ************************************************************************** //
// Type Definitions
// ************************************************************************** //

Canvas_Error_Type :: enum {
	None,
	Init_Failed,
}

Canvas_Error :: Error(Canvas_Error_Type)

// ************************************************************************** //
// Procedures
// ************************************************************************** //

// Returns `true` if the canvas system has encountered no errors or if any
// errors have been marked as handled.
canvas_ok :: proc() -> bool {
	return canvas_state.error.type == .None
}

// Returns any error the canvas system last experienced.
canvas_error :: proc() -> Canvas_Error {
	return canvas_state.error
}

// Marks any error the canvas system has received as handled.
canvas_clear_error :: proc() {
	canvas_state.error.type = .None
}
