package pink_render

import "core:c"
import "core:fmt"
import sdl "vendor:sdl2"
import "wgpu"

// A WGPU rendering context, bringing together all WGPU components necessary to
// draw things to the screen. Context beyond these members (i.e. pipelines) is
// done on a module-local level.
Context :: struct {
	surface: wgpu.Surface,
	adapter: wgpu.Adapter,
	device: wgpu.Device,
	queue: wgpu.Queue,
	swap_chain: wgpu.SwapChain,
	command_encoder: wgpu.CommandEncoder,
	render_texture_format: wgpu.TextureFormat,
	render_pass_encoder: wgpu.RenderPassEncoder,
	basic_texture_bind_group_layout: wgpu.BindGroupLayout,
	swap_texture_view: wgpu.TextureView,
	swap_chain_expired: bool,
	render_width: u32,
	render_height: u32,
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
	context_init(cast(^Context) userdata)
	fmt.eprintln("[wgpu]", message)
}

// Initializes a rendering context.
context_init :: proc(
	ren: ^Context,
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
			requiredLimits = &wgpu.RequiredLimits{
				limits = wgpu.Limits{
					maxBindGroups = 1,
				},
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

	ren.render_texture_format = wgpu.SurfaceGetPreferredFormat(
		ren.surface,
		ren.adapter,
	)

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

	ren.basic_texture_bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		ren.device,
		&wgpu.BindGroupLayoutDescriptor{
			label = "CanvasImagePipelineBindGroupLayout",
			entryCount = c.uint32_t(len(group_entries)),
			entries = ([^]wgpu.BindGroupLayoutEntry)(raw_data(group_entries)),
		},
	)

	ren.fresh = true
	ren.swap_chain_expired = true

	return true
}

// Destroys a renderer context.
context_destroy :: proc(
	ren: ^Context,
) -> bool {
	ren.exiting = true

	wgpu.BindGroupLayoutDrop(ren.basic_texture_bind_group_layout)

	if ren.device != nil {
		wgpu.DeviceDestroy(ren.device)
		wgpu.DeviceDrop(ren.device)
	}

	return true
}

// Creates a texture bind group based off the basic texture bind group layout.
context_create_basic_texture_bind_group :: proc(
	ren: ^Context,
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
			layout = ren.basic_texture_bind_group_layout,
			entryCount = c.uint32_t(len(entries)),
			entries = ([^]wgpu.BindGroupEntry)(raw_data(entries)),
		},
	)
}

// Begins a ren context frame.
//
// This:
// * Recreates the swap chain if it's been marked as expired
// * Fetches the device queue and next swap chain texture view
// * Creates a command encoder for the frame
// * Begins a ren pass using the current swap chain texture view
context_begin_frame :: proc(
	ren: ^Context,
) -> bool {
	if ren.swap_chain_expired || ren.fresh {
		context_recreate_swap_chain(ren)
	}
	
	ren.queue = wgpu.DeviceGetQueue(ren.device)
	ren.swap_texture_view = wgpu.SwapChainGetCurrentTextureView(ren.swap_chain)
	
	if ren.swap_texture_view == nil {
		// TODO: error
		// _prog_error_report(Error(Render_Error){
		// 	type = .Frame_Failed,
		// 	message = "Could not obtain next swap chain texture view",
		// })
		return false
	}
	
	ren.command_encoder = wgpu.DeviceCreateCommandEncoder(
		ren.device,
		&wgpu.CommandEncoderDescriptor{},
	)
	
	ren.render_pass_encoder = wgpu.CommandEncoderBeginRenderPass(
		ren.command_encoder,
		&wgpu.RenderPassDescriptor{
			label = "RenderPass",
			colorAttachments = &wgpu.RenderPassColorAttachment{
				view = ren.swap_texture_view,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = wgpu.Color{0.0, 0.0, 0.0, 1.0},
			},
			colorAttachmentCount = 1,
		},
	)
	
	return true
}

// Finishes a ren context frame.
//
// This:
// * Ends the ren pass
// * Submits the ren pass command encoder to the ren queue
// * Presents the swap chain
context_end_frame :: proc(
	ren: ^Context,
) -> bool {
	ren.fresh = false
	
	wgpu.RenderPassEncoderEnd(ren.render_pass_encoder)
	commands := wgpu.CommandEncoderFinish(
		ren.command_encoder,
		&wgpu.CommandBufferDescriptor{},
	)
	wgpu.QueueSubmit(ren.queue, 1, &commands)
	wgpu.SwapChainPresent(ren.swap_chain)
	wgpu.TextureViewDrop(ren.swap_texture_view)
	
	return true
}

// Recreates the swap chain on a ren context using the current `render_width`
// and `render_height`. This will automatically be called at frame begin if
// `swap_chain_expired` has been set and should not be called manually.
context_recreate_swap_chain :: proc(
	ren: ^Context,
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
context_resize :: proc(
	ren: ^Context,
	width: int,
	height: int,
) {
	ren.swap_chain_expired = true
	ren.render_width = u32(width)
	ren.render_height = u32(height)
}
