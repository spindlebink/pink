//+private
package pink

import "core:intrinsics"

// ************************************************************************** //
// Type Definitions
// ************************************************************************** //

Error :: struct($T: typeid)
	where intrinsics.type_is_enum(T) {
	type: T,
	message: string,
}
