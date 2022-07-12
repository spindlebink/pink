package pink_render

import "core:c"
import "wgpu"

UNIFORM_BUFFER_RESIZE_CAPACITY_MULTIPLIER :: 1.5

Uniform_Buffer :: struct($Data: typeid) {
	ptr: wgpu.Buffer,
	bind_group_layout: wgpu.BindGroupLayout,
	bind_group: wgpu.BindGroup,
	data: Data,
	usage_flags: wgpu.BufferUsageFlags,
}

// Initializes a uniform buffer.
ubuffer_init :: proc(
	renderer: ^Renderer,
	buffer: ^Uniform_Buffer($Data),
) {
	buffer.ptr = wgpu.DeviceCreateBuffer(
		renderer.device,
		&wgpu.BufferDescriptor{
			usage = buffer.usage_flags,
			size = c.uint64_t(size_of(Data)),
		},
	)

	layout_entries := []wgpu.BindGroupLayoutEntry{
		wgpu.BindGroupLayoutEntry{
			binding = 0,
			visibility = {.Vertex, .Fragment},
			buffer = wgpu.BufferBindingLayout{type = .Uniform},
		},
	}

	buffer.bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		renderer.device,
		&wgpu.BindGroupLayoutDescriptor{
			entryCount = c.uint32_t(len(layout_entries)),
			entries = ([^]wgpu.BindGroupLayoutEntry)(raw_data(layout_entries)),
		},
	)

	bind_group_entries := []wgpu.BindGroupEntry{
		wgpu.BindGroupEntry{
			binding = 0,
			buffer = buffer.ptr,
			offset = 0,
			size = c.uint64_t(size_of(Data)),
		},
	}

	buffer.bind_group = wgpu.DeviceCreateBindGroup(
		renderer.device,
		&wgpu.BindGroupDescriptor{
			layout = buffer.bind_group_layout,
			entryCount = c.uint32_t(len(bind_group_entries)),
			entries = ([^]wgpu.BindGroupEntry)(raw_data(bind_group_entries)),
		},
	)
}

// Destroys a uniform buffer.
ubuffer_destroy :: proc(
	buffer: ^Uniform_Buffer($Data),
) {
	if buffer.ptr != nil {
		wgpu.BufferDestroy(buffer.ptr)
		wgpu.BufferDrop(buffer.ptr)
	}
	if buffer.bind_group != nil {
		wgpu.BindGroupDrop(buffer.bind_group)
		wgpu.BindGroupLayoutDrop(buffer.bind_group_layout)
	}
}

// Copies data from `buffer.data` to the GPU-side buffer, resizing it if need
// be.
ubuffer_queue_copy_data :: proc(
	renderer: ^Renderer,
	buffer: ^Uniform_Buffer($Data),
) {
	wgpu.QueueWriteBuffer(
		renderer.queue,
		buffer.ptr,
		0,
		&buffer.data,
		c.size_t(size_of(Data)),
	)
}
