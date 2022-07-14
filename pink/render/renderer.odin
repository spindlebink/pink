package pink_render

import "core:c"
import "core:fmt"
import "core:math/linalg"
import sdl "vendor:sdl2"
import "wgpu"

MAX_BIND_GROUPS :: 2
MAX_PUSH_CONSTANT_SIZE :: 0

// A WGPU rendering context, bringing together all WGPU components necessary to
// draw things to the screen. Context beyond these members (i.e. pipelines) is
// done on a module-local level.
Renderer :: struct {
	surface: wgpu.Surface,
	adapter: wgpu.Adapter,
	device: wgpu.Device,

	queue: wgpu.Queue,
	command_encoder: wgpu.CommandEncoder,

	render_pass: Render_Pass,

	render_texture_format: wgpu.TextureFormat,

	texture_bind_group_layout: wgpu.BindGroupLayout,

	swap_chain: wgpu.SwapChain,
	swap_texture_view: wgpu.TextureView,
	swap_chain_expired: bool,

	render_width: u32,
	render_height: u32,
	size_changed: bool,
	fresh: bool,
	exiting: bool,
	vsync: bool,
}

// Log callback for WGPU.
@(private)
wgpu_log_callback :: proc(
	level: wgpu.LogLevel,
	message: cstring,
) {
	fmt.println("[wgpu]", message)
}

// Adapter request callback for WGPU.
@(private)
wgpu_instance_request_adapter_callback :: proc(
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

// Device request callback for WGPU.
@(private)
wgpu_adapter_request_device_callback :: proc(
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

// Uncaptured error callback for WGPU.
@(private)
wgpu_uncaptured_error_callback :: proc(
	type: wgpu.ErrorType,
	message: cstring,
	userdata: rawptr,
) {
	fmt.eprintln(message)
}

// Device lost callback for WGPU.
@(private)
wgpu_device_lost_callback :: proc(
	reason: wgpu.DeviceLostReason,
	message: cstring,
	userdata: rawptr,
) {
	renderer_init(cast(^Renderer) userdata)
	fmt.eprintln("[wgpu]", message)
}

// Creates a texture bind group based off the basic texture bind group layout.
renderer_create_texture_bind_group :: proc(
	ren: ^Renderer,
	view: wgpu.TextureView,
	sampler: wgpu.Sampler,
) -> wgpu.BindGroup {
	entries := []wgpu.BindGroupEntry{
		wgpu.BindGroupEntry{
			binding = 0,
			textureView = view,
		},
		wgpu.BindGroupEntry{
			binding = 1,
			sampler = sampler,
		},
	}

	return wgpu.DeviceCreateBindGroup(
		ren.device,
		&wgpu.BindGroupDescriptor{
			layout = ren.texture_bind_group_layout,
			entryCount = c.uint32_t(len(entries)),
			entries = ([^]wgpu.BindGroupEntry)(raw_data(entries)),
		},
	)
}

// Begins a render context frame.
//
// This:
// * Recreates the swap chain if it's been marked as expired
// * Fetches the device queue and next swap chain texture view
// * Creates a command encoder for the frame
renderer_begin_frame :: proc(
	ren: ^Renderer,
) -> bool {
	if ren.swap_chain_expired || ren.fresh {
		renderer_recreate_swap_chain(ren)
	}
	
	ren.queue = wgpu.DeviceGetQueue(ren.device)
	ren.swap_texture_view = wgpu.SwapChainGetCurrentTextureView(ren.swap_chain)
	
	if ren.swap_texture_view == nil do return false
	
	ren.command_encoder = wgpu.DeviceCreateCommandEncoder(
		ren.device,
		&wgpu.CommandEncoderDescriptor{},
	)
	
	return true
}

// Finishes a render context frame.
//
// This:
// * Submits the command encoder to the ren queue
// * Presents the swap chain
renderer_end_frame :: proc(
	ren: ^Renderer,
) -> bool {
	ren.fresh = false
	ren.size_changed = false

	commands := wgpu.CommandEncoderFinish(
		ren.command_encoder,
		&wgpu.CommandBufferDescriptor{},
	)
	wgpu.QueueSubmit(ren.queue, 1, &commands)
	wgpu.SwapChainPresent(ren.swap_chain)
	wgpu.TextureViewDrop(ren.swap_texture_view)
	
	return true
}

// Recreates the swap chain on a render context using the current `render_width`
// and `render_height`. This will automatically be called at frame begin if
// `swap_chain_expired` has been set and should not be called manually.
renderer_recreate_swap_chain :: proc(
	ren: ^Renderer,
) {
	ren.swap_chain_expired = false
	ren.swap_chain = wgpu.DeviceCreateSwapChain(
		ren.device,
		ren.surface,
		&wgpu.SwapChainDescriptor{
			usage = {.RenderAttachment},
			format = ren.render_texture_format,
			width = c.uint32_t(ren.render_width),
			height = c.uint32_t(ren.render_height),
			presentMode = .Fifo if ren.vsync else .Immediate,
		},
	)
}

// Marks the swap chain as expired and sets the new swap chain size to `width`/
// `height`.
renderer_resize :: proc(
	ren: ^Renderer,
	width: int,
	height: int,
) {
	if u32(width) != ren.render_width || u32(height) != ren.render_height {
		ren.size_changed = true
		ren.swap_chain_expired = true
		ren.render_width = u32(width)
		ren.render_height = u32(height)
	}
}

renderer_compute_window_to_device_matrix :: #force_inline proc(
	ren: ^Renderer,
) -> linalg.Matrix4x4f32 {
	w_s := 2.0 / f32(ren.render_width)
	h_s := 2.0 / f32(ren.render_height)
	return linalg.Matrix4x4f32{
		w_s, 0.0, 0.0, 0.0,
		0.0, h_s, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		-1.0, 1.0, 0.0, 1.0,
	}
}

// Initializes a rendering context.
renderer_init :: proc(
	ren: ^Renderer,
) -> bool {
	wgpu.SetLogCallback(wgpu_log_callback)
	wgpu.SetLogLevel(.Warn)
	
	wgpu.InstanceRequestAdapter(
		nil,
		&wgpu.RequestAdapterOptions{
			compatibleSurface = ren.surface,
			powerPreference = .HighPerformance, // TODO: make configurable
		},
		wgpu_instance_request_adapter_callback,
		&ren.adapter,
	)
	
	if ren.adapter == nil {
		fmt.eprintln("Could not obtain GPU adapter")
		return false
	}
	
	if ren.device != nil {
		wgpu.DeviceDestroy(ren.device)
		wgpu.DeviceDrop(ren.device)
	}
		
	wgpu.AdapterRequestDevice(
		ren.adapter,
		&wgpu.DeviceDescriptor{
			nextInChain = cast(^wgpu.ChainedStruct)&wgpu.DeviceExtras{
				chain = wgpu.ChainedStruct{
					next = nil,
					sType = wgpu.SType(wgpu.NativeSType.DeviceExtras),
				},
				nativeFeatures = .PUSH_CONSTANTS,
			},
			requiredLimits = &wgpu.RequiredLimits{
				limits = wgpu.Limits{
					maxBindGroups = c.uint32_t(MAX_BIND_GROUPS),
				},
				nextInChain = cast(^wgpu.ChainedStruct)&wgpu.RequiredLimitsExtras{
					chain = wgpu.ChainedStruct{
						next = nil,
						sType = wgpu.SType(wgpu.NativeSType.RequiredLimitsExtras),
					},
					maxPushConstantSize = c.uint32_t(MAX_PUSH_CONSTANT_SIZE),
				}
			},
			defaultQueue = wgpu.QueueDescriptor{},
		},
		wgpu_adapter_request_device_callback,
		&ren.device,
	)
	
	if ren.device == nil {
		fmt.eprintln("Could not obtain GPU device")
		return false
	}
	
	wgpu.DeviceSetUncapturedErrorCallback(
		ren.device,
		wgpu_uncaptured_error_callback,
		nil,
	)
	wgpu.DeviceSetDeviceLostCallback(
		ren.device,
		wgpu_device_lost_callback,
		ren,
	)

	preferred := wgpu.SurfaceGetPreferredFormat(
		ren.surface,
		ren.adapter,
	)

	if preferred == .BGRA8Unorm {
		ren.render_texture_format = .BGRA8UnormSrgb
	} else if preferred == .RGBA8Unorm {
		ren.render_texture_format = .RGBA8UnormSrgb
	} else {
		panic("unknown GPU error occurred--spec noncompliant")
	}

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

	ren.texture_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		ren.device,
		&wgpu.BindGroupLayoutDescriptor{
			entryCount = c.uint32_t(len(group_entries)),
			entries = ([^]wgpu.BindGroupLayoutEntry)(raw_data(group_entries)),
		},
	)
	
	ren.fresh = true
	ren.swap_chain_expired = true

	return true
}

// Destroys a renderer context.
renderer_destroy :: proc(
	ren: ^Renderer,
) -> bool {
	ren.exiting = true

	wgpu.BindGroupLayoutDrop(ren.texture_bind_group_layout)

	if ren.device != nil {
		wgpu.DeviceDestroy(ren.device)
		wgpu.DeviceDrop(ren.device)
	}

	return true
}
