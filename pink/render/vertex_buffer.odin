package pink_render

import "core:c"
import "wgpu"

BUFFER_INITIAL_LENGTH :: 40
BUFFER_RESIZE_CAPACITY_MULTIPLIER :: 1.5

Vertex_Buffer :: struct($Data: typeid) {
	ptr: wgpu.Buffer,
	size: int,
	data: [dynamic]Data,
	usage_flags: wgpu.BufferUsageFlags,
}

// Initializes a buffer.
vbuffer_init :: proc(
	renderer: ^Context,
	buffer: ^Vertex_Buffer($Data),
	initial_length := BUFFER_INITIAL_LENGTH,
) {
	if initial_length > 0 {
		buffer.size = initial_length * size_of(Data)
		buffer.ptr = wgpu.DeviceCreateBuffer(
			renderer.device,
			&wgpu.BufferDescriptor{
				usage = buffer.usage_flags,
				size = c.uint64_t(initial_length * size_of(Data)),
			},
		)
	}
}

// Destroys a buffer.
vbuffer_destroy :: proc(
	buffer: ^Vertex_Buffer($Data),
) {
	if buffer.ptr != nil {
		wgpu.BufferDestroy(buffer.ptr)
		wgpu.BufferDrop(buffer.ptr)
	}
	delete(buffer.data)
}

// Ensures the data array is at least `size`.
vbuffer_reserve :: #force_inline proc(
	buffer: ^Vertex_Buffer($D),
	size: int,
) {
	reserve(&buffer.data, size)
}

// Appends data to the buffer.
vbuffer_append :: #force_inline proc(
	buffer: ^Vertex_Buffer($D),
	data: D,
) {
	append(&buffer.data, data)
}

// Copies data from `buffer.data` to the GPU-side buffer, resizing it if need
// be.
vbuffer_queue_copy_data :: proc(
	renderer: ^Context,
	buffer: ^Vertex_Buffer($Data),
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
