package pink_render

import "core:c"
import "../wgpu"

BUFFER_RESIZE_CAPACITY_MULTIPLIER :: 1.5

Buffer :: struct($Data: typeid) {
	ptr: wgpu.Buffer,
	size: int,
	data: [dynamic]Data,
	usage_flags: wgpu.BufferUsageFlags,
}

buffer_destroy :: proc(
	buffer: ^Buffer($Data),
) {
	if buffer.ptr != nil {
		wgpu.BufferDestroy(buffer.ptr)
		wgpu.BufferDrop(buffer.ptr)
	}
	delete(buffer.data)
}

buffer_queue_copy_data :: proc(
	buffer: ^Buffer($Data),
	renderer: ^Context,
	clear_on_finished := true,
) {
	new_size := len(buffer.data) * size_of(Data)

	if new_size > buffer.size {
		if buffer.ptr != nil {
			wgpu.BufferDestroy(buffer.ptr)
			wgpu.BufferDrop(buffer.ptr)
		}
		target_size := int(f64(new_size) * BUFFER_RESIZE_CAPACITY_MULTIPLIER)
		buffer.size = new_size
		buffer.ptr = wgpu.DeviceCreateBuffer(
			renderer.device,
			&wgpu.BufferDescriptor{
				usage = buffer.usage_flags,
				size = c.uint64_t(new_size),
			},
		)
	}

	if len(buffer.data) > 0 {
		wgpu.QueueWriteBuffer(
			renderer.queue,
			buffer.ptr,
			0,
			raw_data(buffer.data),
			c.size_t(new_size),
		)

		if clear_on_finished do clear(&buffer.data)
	}
}
