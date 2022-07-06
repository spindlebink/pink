package pink

import "core:c"
import "wgpu"

DYNAMIC_BUFFER_RESIZE_CAPACITY_MULTIPLIER :: 1.5

Dynamic_Buffer :: struct($Data: typeid) {
	ptr: wgpu.Buffer,
	size: int,
	data: [dynamic]Data,
	usage_flags: wgpu.BufferUsageFlags,
}

_dynamic_buffer_destroy :: proc(
	buffer: ^Dynamic_Buffer($Data),
) {
	if buffer.ptr != nil {
		wgpu.BufferDestroy(buffer.ptr)
		wgpu.BufferDrop(buffer.ptr)
	}
	delete(buffer.data)
}

_dynamic_buffer_copy_vertices :: proc(
	buffer: ^Dynamic_Buffer($Data),
	renderer: ^Renderer,
	clear_on_finished := true,
) {
	new_size = len(buffer.data) * size_of(Data)
	if new_size > buffer.size {
		if buffer.ptr != nil {
			wgpu.BufferDestroy(buffer.ptr)
			wgpu.BufferDrop(buffer.ptr)
		}
		target_size := int(f64(new_size) * DYNAMIC_BUFFER_RESIZE_CAPACITY_MULTIPLIER)
		buffer.size = new_size
		buffer.ptr = wgpu.DeviceCreateBuffer(
			renderer.device,
			&wgpu.BufferDescriptor{
				usage = buffer.usage_flags,
				size = c.uint64_t(new_size),
			},
		)
	}

	// TODO: queue the copy operation
}
