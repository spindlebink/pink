package pk_render

import "core:c"
import "core:fmt"
import sdl "vendor:sdl2"
import "wgpu"
import pk ".."

@(init, private)
_module_init :: proc() {
	pk._core.hooks.ren_init = init
	pk._core.hooks.ren_destroy = destroy
	pk._core.hooks.ren_frame_begin = frame_begin
	pk._core.hooks.ren_frame_end = frame_end
}

MAX_BIND_GROUPS :: #config(PK_RENDER_MAX_BIND_GROUPS, 4)
USE_PUSH_CONSTANTS :: #config(PK_RENDER_USE_PUSH_CONSTANTS, false)
MAX_PUSH_CONSTANT_SIZE :: #config(PK_RENDER_MAX_PUSH_CONSTANT_SIZE, size_of(uint) * 4)

texture_bind_group_layout: wgpu.BindGroupLayout
uniform_bind_group_layout: wgpu.BindGroupLayout

// Core state. Shouldn't generally be accessed user-side.
_core: Core

@(private)
Core :: struct {
	surface: wgpu.Surface,
	adapter: wgpu.Adapter,
	device: wgpu.Device,
	queue: wgpu.Queue,
	cmd_encoder: wgpu.CommandEncoder,
	ren_tex_format: wgpu.TextureFormat,
	swap_chain: wgpu.SwapChain,
	swap_tex_view: wgpu.TextureView,
	swap_chain_expired: bool,
	width: uint,
	height: uint,
	size_changed: bool,
	fresh: bool,
	exiting: bool,
	vsync: bool,
	frame_began: bool,
}

/*
 * WGPU callbacks
 */

@(private)
on_log :: proc(level: wgpu.LogLevel, msg: cstring) {
	fmt.println(msg)
}

@(private)
on_instance_request_adapter :: proc(
	status: wgpu.RequestAdapterStatus,
	adapter: wgpu.Adapter,
	msg: cstring,
	userdata: rawptr,
) {
	if status == .Success {
		adapter_result := cast(^wgpu.Adapter) userdata
		adapter_result^ = adapter
	}
}

@(private)
on_adapter_request_device :: proc(
	status: wgpu.RequestDeviceStatus,
	device: wgpu.Device,
	msg: cstring,
	userdata: rawptr,
) {
	if status == .Success {
		device_result := cast(^wgpu.Device) userdata
		device_result^ = device
	}
}

@(private)
on_uncaptured_error :: proc(
	type: wgpu.ErrorType,
	msg: cstring,
	userdata: rawptr,
) {
	fmt.eprintln(msg)
	panic("uncaptured GPU error")
}

@(private)
on_device_lost :: proc(
	reason: wgpu.DeviceLostReason,
	msg: cstring,
	userdata: rawptr,
) {
	if !_core.exiting {
		panic(string(msg))
	}
}

/*
 * Initialize
 */

init :: proc() {
	wgpu.SetLogCallback(on_log)
	wgpu.SetLogLevel(.Warn)

	// Initialize surface
	when ODIN_OS == .Linux {
		wm_info: sdl.SysWMinfo
		sdl.GetVersion(&wm_info.version)

		if !sdl.GetWindowWMInfo(pk.window._sdl_handle, &wm_info) {
			panic("could not obtain WM info from window")
		}

		if wm_info.subsystem != .X11 {
			panic("unsupported window manager")
		}

		surface_descriptor := wgpu.SurfaceDescriptorFromXlibWindow{
			chain = wgpu.ChainedStruct{
				sType = .SurfaceDescriptorFromXlibWindow,
			},
			display = wm_info.info.x11.display,
			window = c.uint32_t(wm_info.info.x11.window),
		}

		_core.surface = wgpu.InstanceCreateSurface(
			nil,
			&wgpu.SurfaceDescriptor{
				nextInChain = cast(^wgpu.ChainedStruct) &surface_descriptor,
			},
		)
	}

	wgpu.InstanceRequestAdapter(
		nil,
		&wgpu.RequestAdapterOptions{
			compatibleSurface = _core.surface,
			powerPreference = .HighPerformance,
		},
		on_instance_request_adapter,
		&_core.adapter,
	)

	if _core.adapter == nil { panic("could not obtain GPU adapter") }
	if _core.device != nil {
		wgpu.DeviceDestroy(_core.device)
		wgpu.DeviceDrop(_core.device)
	}

	native_features := wgpu.NativeFeature{}
	limits_extras := wgpu.RequiredLimitsExtras{}

	when USE_PUSH_CONSTANTS {
		native_features = .PUSH_CONSTANTS
		limits_extras = {
			chain = wgpu.ChainedStruct{
				next = nil,
				sType = wgpu.SType(wgpu.NativeSType.RequiredLimitsExtras),
			},
			maxPushConstantSize = c.uint32_t(MAX_PUSH_CONSTANT_SIZE),
		}
	}

	wgpu.AdapterRequestDevice(
		_core.adapter,
		&wgpu.DeviceDescriptor{
			nextInChain = cast(^wgpu.ChainedStruct)&wgpu.DeviceExtras{
				chain = wgpu.ChainedStruct{
					next = nil,
					sType = wgpu.SType(wgpu.NativeSType.DeviceExtras),
				},
				nativeFeatures = native_features,
			},
			requiredLimits = &wgpu.RequiredLimits{
				limits = wgpu.Limits{
					maxBindGroups = c.uint32_t(MAX_BIND_GROUPS),
				},
				nextInChain = cast(^wgpu.ChainedStruct)&limits_extras,
			},
			defaultQueue = wgpu.QueueDescriptor{},
		},
		on_adapter_request_device,
		&_core.device,
	)

	if _core.device == nil { panic("could not obtain GPU device") }

	_core.queue = wgpu.DeviceGetQueue(_core.device)
	wgpu.DeviceSetUncapturedErrorCallback(_core.device, on_uncaptured_error, nil)
	wgpu.DeviceSetDeviceLostCallback(_core.device, on_device_lost, nil)

	pref := wgpu.SurfaceGetPreferredFormat(_core.surface, _core.adapter)
	if pref == .BGRA8Unorm || pref == .BGRA8UnormSrgb {
		_core.ren_tex_format = .BGRA8UnormSrgb
	} else if pref == .RGBA8Unorm || pref == .RGBA8UnormSrgb {
		_core.ren_tex_format = .RGBA8UnormSrgb
	} else {
		panic("unknown GPU error: noncompliant with WebGPU spec")
	}

	// Create texture bind group layout
	{
		group_entries := []wgpu.BindGroupLayoutEntry{
			wgpu.BindGroupLayoutEntry{
				binding = 0,
				visibility = {.Fragment},
				texture = wgpu.TextureBindingLayout{
					multisampled = false,
					viewDimension = .D2,
					sampleType = .Float,
				},
			},
			wgpu.BindGroupLayoutEntry{
				binding = 1,
				visibility = {.Fragment},
				sampler = wgpu.SamplerBindingLayout{
					type = .Filtering,
				},
			},
		}

		texture_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
			_core.device,
			&wgpu.BindGroupLayoutDescriptor{
				entryCount = c.uint32_t(len(group_entries)),
				entries = raw_data(group_entries),
			},
		)
	}
	
	// Create uniform bind group layout
	{
		group_entries := []wgpu.BindGroupLayoutEntry{
			wgpu.BindGroupLayoutEntry{
				binding = 0,
				visibility = {.Vertex, .Fragment},
				buffer = wgpu.BufferBindingLayout{type = .Uniform},
			},
		}
		
		uniform_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
			_core.device,
			&wgpu.BindGroupLayoutDescriptor{
				entryCount = c.uint32_t(len(group_entries)),
				entries = raw_data(group_entries),
			},
		)
	}

	_core.fresh = true
}

/*
 * Destroy
 */

destroy :: proc() {
	_core.exiting = true
	if texture_bind_group_layout != nil {
		wgpu.BindGroupLayoutDrop(texture_bind_group_layout)
	}
	if _core.device != nil {
		wgpu.DeviceDestroy(_core.device)
		wgpu.DeviceDrop(_core.device)
	}
}

/*
 * Frame Begin/End
 */

frame_begin :: proc() {
	if _core.frame_began { return }

	if _core.swap_chain_expired || _core.width != pk.window.width || _core.height != pk.window.height {
		_core.width = pk.window.width
		_core.height = pk.window.height
		swap_chain_rebuild()
	}
	
	_core.swap_tex_view = wgpu.SwapChainGetCurrentTextureView(_core.swap_chain)
	if _core.swap_tex_view == nil {
		panic("could not obtain next swap chain texture view")
	}
	
	_core.cmd_encoder = wgpu.DeviceCreateCommandEncoder(
		_core.device,
		&wgpu.CommandEncoderDescriptor{},
	)
	_core.frame_began = true
}

frame_end :: proc() {
	if !_core.frame_began { return }
	_core.fresh = false
	
	commands := wgpu.CommandEncoderFinish(
		_core.cmd_encoder,
		&wgpu.CommandBufferDescriptor{},
	)
	wgpu.QueueSubmit(_core.queue, 1, &commands)
	wgpu.SwapChainPresent(_core.swap_chain)
	wgpu.TextureViewDrop(_core.swap_tex_view)
	_core.frame_began = false
}

/*
 * Swap Chain Management
 */

swap_chain_invalidate :: proc() {
	_core.swap_chain_expired = true
}

@(private)
swap_chain_rebuild :: proc() {
	_core.swap_chain_expired = false
	_core.swap_chain = wgpu.DeviceCreateSwapChain(
		_core.device,
		_core.surface,
		&wgpu.SwapChainDescriptor{
			usage = {.RenderAttachment},
			format = _core.ren_tex_format,
			width = c.uint32_t(_core.width),
			height = c.uint32_t(_core.height),
			presentMode = .Fifo if _core.vsync else .Immediate,
		}
	)
}
