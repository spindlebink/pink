package pk_render

import "core:c"
import "wgpu"

BUFFER_INITIAL_SIZE :: 128

// Buffer holding vertex or instance data.
Buffer :: struct {
	size: uint,
	usage: Buffer_Usage,
	_wgpu_handle: wgpu.Buffer,
}

Buffer_Usage :: enum {
	Vertex,
	Instance,
	Uniform,
	Index,
}

Buffer_Layout :: struct {
	usage: Buffer_Usage,
	stride: uint,
	attributes: []Attribute,
}

buffer_init :: proc(buffer: ^Buffer, size: uint = BUFFER_INITIAL_SIZE) {
	buffer.size = size
	buffer._wgpu_handle = wgpu.DeviceCreateBuffer(
		_core.device,
		&wgpu.BufferDescriptor{
			usage = buffer.usage == .Vertex || buffer.usage == .Instance ? {.Vertex, .CopyDst} : {.Uniform, .CopyDst}, // TODO: index buffers
			size = c.uint64_t(size)
		}
	)
}

buffer_destroy :: proc(buffer: Buffer) {
	if buffer._wgpu_handle != nil {
		wgpu.BufferDestroy(buffer._wgpu_handle)
		wgpu.BufferDrop(buffer._wgpu_handle)
	}
}

buffer_copy :: proc(buffer: ^Buffer, data: []$Data) {
	if len(data) > 0 {
		if uint(len(data) * size_of(Data)) > buffer.size {
			panic("buffer capacity too small")
		}
		wgpu.QueueWriteBuffer(
			_core.queue,
			buffer._wgpu_handle,
			0,
			raw_data(data),
			c.size_t(len(data) * size_of(Data)),
		)
	}
}
