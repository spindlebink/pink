//+private
package pink

import "core:c"
import "core:fmt"
import sdl "vendor:sdl2"
import "wgpu/wgpu"

render_state := Render_State{
}

// ************************************************************************** //
// Type Definitions & Constants
// ************************************************************************** //

Render_Error_Type :: enum {
	None,
	Init_Failed,
	Uncaptured_WGPU_Error,
	Frame_Begin_Failed,
}

Render_Error :: Error(Render_Error_Type)

ERROR_WINDOW_INFO_FAILED :: "Failed to collect window info"
ERROR_WM_UNSUPPORTED :: "Unsupported window manager"
ERROR_REQUEST_ADAPTER_FAILED :: "Failed to obtain GPU adapter"
ERROR_REQUEST_DEVICE_FAILED :: "Failed to obtain GPU device"
ERROR_GET_SWAP_CHAIN_TEXTURE_FAILED :: "Failed to get the next frame's texture view"

Render_State :: struct {
	surface: wgpu.Surface,
	adapter: wgpu.Adapter,
	device: wgpu.Device,
	queue: wgpu.Queue,
	swap_chain: wgpu.SwapChain,
	command_encoder: wgpu.CommandEncoder,
	render_pass_encoder: wgpu.RenderPassEncoder,
	current_texture_view: wgpu.TextureView,

	error: Render_Error,
	exiting: bool,

	swap_chain_invalid: bool,
	context_fresh: bool,
	texture_format: wgpu.TextureFormat,
}

Render_Buffer :: struct {
	handle: wgpu.Buffer,
	size: int,
	usage_flags: wgpu.BufferUsageFlags,
}

// ************************************************************************** //
// WGPU Callbacks
// ************************************************************************** //

log_callback :: proc(
	level: wgpu.LogLevel,
	message: cstring,
) {
	fmt.println("[wgpu]", message)
}

instance_request_adapter_callback :: proc(
	status: wgpu.RequestAdapterStatus,
	adapter: wgpu.Adapter,
	message: cstring,
	userdata: rawptr,
) {
	if status == .Success {
		adapter_result := cast(^wgpu.Adapter) userdata
		adapter_result^ = adapter
	}
}

adapter_request_device_callback :: proc(
	status: wgpu.RequestDeviceStatus,
	device: wgpu.Device,
	message: cstring,
	userdata: rawptr,
) {
	if status == .Success {
		device_result := cast(^wgpu.Device) userdata
		device_result^ = device
	}
}

uncaptured_error_callback :: proc(
	type: wgpu.ErrorType,
	message: cstring,
	userdata: rawptr,
) {
	render_state.error = Render_Error{
		type = .Uncaptured_WGPU_Error,
		message = string(message),
	}
}

device_lost_callback :: proc(
	reason: wgpu.DeviceLostReason,
	message: cstring,
	userdata: rawptr,
) {
	if render_state.exiting do return
	render_obtain_context()
	fmt.eprintln("[wgpu]", message)
}

// ************************************************************************** //
// Procedures
// ************************************************************************** //

// Returns `true` if the runtime system has encountered no errors or if any
// errors have been marked as handled.
render_ok :: proc() -> bool {
	return render_state.error.type == .None
}

// Returns any error the runtime system last experienced.
render_error :: proc() -> Render_Error {
	return render_state.error
}

// Marks any error the runtime system has received as handled.
render_clear_error :: proc() {
	render_state.error.type = .None
}

// Ensures that a `Render_Buffer` has a size of at least `size`, recreating it
// if necessary.
render_buffer_ensure_size :: proc(buffer: ^Render_Buffer, size: int) {
	if size > buffer.size {
		if buffer.handle != nil do wgpu.BufferDestroy(buffer.handle)
		buffer.handle = wgpu.DeviceCreateBuffer(
			render_state.device,
			&wgpu.BufferDescriptor{
				usage = buffer.usage_flags,
				size = cast(c.uint64_t) size,
			},
		)
		buffer.size = size
	}
}

// Creates a WGPU shader module out of WGSL source.
render_shader_module_create_wgsl :: proc(source: []u8) -> wgpu.ShaderModule {
	wgsl_descriptor := wgpu.ShaderModuleWGSLDescriptor{
		chain = wgpu.ChainedStruct{
			sType = .ShaderModuleWGSLDescriptor,
		},
		code = cast(cstring) raw_data(source),
	}
	descriptor := wgpu.ShaderModuleDescriptor{
		nextInChain = cast(^wgpu.ChainedStruct) &wgsl_descriptor,
	}
	return wgpu.DeviceCreateShaderModule(render_state.device, &descriptor)
}

// Initializes the WGPU context.
render_init :: proc() -> bool {
	using render_state

	wgpu.SetLogCallback(log_callback)
	wgpu.SetLogLevel(.Warn)

	when ODIN_OS == .Linux {
		wm_info: sdl.SysWMinfo
		sdl.GetVersion(&wm_info.version)

		if !sdl.GetWindowWMInfo(runtime_state.window.handle, &wm_info) {
			error = Render_Error{
				type = .Init_Failed,
				message = ERROR_WINDOW_INFO_FAILED,
			}
			return false
		}

		if wm_info.subsystem != .X11 {
			error = Render_Error{
				type = .Init_Failed,
				message = ERROR_WM_UNSUPPORTED,
			}
			return false
		}

		surface_descriptor := wgpu.SurfaceDescriptorFromXlibWindow{
			chain = wgpu.ChainedStruct{
				sType = .SurfaceDescriptorFromXlibWindow,
			},
			display = wm_info.info.x11.display,
			window = c.uint32_t(wm_info.info.x11.window),
		}

		surface = wgpu.InstanceCreateSurface(
			nil,
			&wgpu.SurfaceDescriptor{
				nextInChain = cast(^wgpu.ChainedStruct) &surface_descriptor,
			},
		)
	}

	if !render_obtain_context() {
		return false
	}

	render_invalidate_swap_chain()

	return true
}

// Requests an adapter and device from WGPU.
render_obtain_context :: proc() -> bool {
	using render_state
	
	wgpu.InstanceRequestAdapter(
		nil,
		&wgpu.RequestAdapterOptions{
			compatibleSurface = surface,
			powerPreference = .HighPerformance,
		},
		instance_request_adapter_callback,
		&adapter,
	)
	
	if adapter == nil {
		error = Render_Error{
			type = .Init_Failed,
			message = ERROR_REQUEST_ADAPTER_FAILED,
		}
		return false
	}
	
	wgpu.AdapterRequestDevice(
		adapter,
		&wgpu.DeviceDescriptor{
			requiredLimits = &wgpu.RequiredLimits{
				limits = wgpu.Limits{
					maxBindGroups = 1,
				},
			},
			defaultQueue = wgpu.QueueDescriptor{},
		},
		adapter_request_device_callback,
		&device,
	)
	
	if device == nil {
		error = Render_Error{
			type = .Init_Failed,
			message = ERROR_REQUEST_DEVICE_FAILED,
		}
		return false
	}
	
	wgpu.DeviceSetUncapturedErrorCallback(device, uncaptured_error_callback, nil)
	wgpu.DeviceSetDeviceLostCallback(device, device_lost_callback, nil)

	texture_format = wgpu.SurfaceGetPreferredFormat(surface, adapter)
	context_fresh = true

	return true
}

// Rebuilds the swap chain. Called at the beginning of a frame when the swap
// chain has been invalidated. You shouldn't call this yourself: the
// invalidation step ensures we only call it at most once in a frame.
render_recreate_swap_chain :: proc() {
	using render_state

	swap_chain_invalid = false
	swap_chain = wgpu.DeviceCreateSwapChain(
		device,
		surface,
		&wgpu.SwapChainDescriptor{
			usage = {.RenderAttachment},
			format = texture_format,
			width = c.uint32_t(runtime_window_width()),
			height = c.uint32_t(runtime_window_height()),
			presentMode = .Fifo if runtime_state.config.vsync_enabled else .Immediate,
		},
	)
}

// Begins a new rendering frame.
render_begin_frame :: proc() -> bool {
	using render_state

	if swap_chain_invalid do render_recreate_swap_chain()
	queue = wgpu.DeviceGetQueue(device)
	current_texture_view = wgpu.SwapChainGetCurrentTextureView(swap_chain)
	
	if current_texture_view == nil {
		error = Render_Error{
			type = .Frame_Begin_Failed,
			message = ERROR_GET_SWAP_CHAIN_TEXTURE_FAILED,
		}
		return false
	}
	
	command_encoder = wgpu.DeviceCreateCommandEncoder(
		device,
		&wgpu.CommandEncoderDescriptor{},
	)

	render_pass_encoder = wgpu.CommandEncoderBeginRenderPass(
		command_encoder,
		&wgpu.RenderPassDescriptor{
			label = "Render Pass",
			colorAttachments = &wgpu.RenderPassColorAttachment{
				view = current_texture_view,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = wgpu.Color{0.0, 0.0, 0.0, 1.0},
			},
			colorAttachmentCount = 1,
		},
	)

	return true
}

// Finishes the current rendering frame and presents it.
render_end_frame :: proc() -> bool {
	using render_state
	
	context_fresh = false
	wgpu.RenderPassEncoderEnd(render_pass_encoder)
	commands := wgpu.CommandEncoderFinish(
		command_encoder,
		&wgpu.CommandBufferDescriptor{},
	)
	wgpu.QueueSubmit(queue, 1, &commands)
	wgpu.SwapChainPresent(swap_chain)

	return true
}

// Returns whether the render context was recreated since last frame.
render_context_fresh :: proc() -> bool {
	return render_state.context_fresh
}

// Marks the swap chain as needing to be recreated next frame.
render_invalidate_swap_chain :: proc() {
	render_state.swap_chain_invalid = true
}

// Cleans up renderer members that need cleaning up. The render context should
// be assumed to be unrecoverable after this call.
render_exit :: proc() -> bool {
	using render_state
	
	exiting = true
	
	if device != nil do wgpu.DeviceDestroy(device)
	
	return true
}
