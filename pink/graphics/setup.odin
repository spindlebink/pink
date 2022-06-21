package pink_graphics

import "core:fmt"
import sdl "vendor:sdl2"
import "wgpu/wgpu"

Backend :: enum {
	Undefined,
	WebGPU,
	D3D11,
	D3D12,
	Metal,
	Vulkan,
	OpenGL,
	OpenGLES,
}

@(private)
Context :: struct {
	backend: Backend,
	surface: wgpu.Surface,
	adapter: wgpu.Adapter,
	device: wgpu.Device,

	swap_chain_texture_format: wgpu.TextureFormat,
	swap_chain: wgpu.SwapChain,

	render_pipeline_layout: wgpu.PipelineLayout,
	render_pipeline: wgpu.RenderPipeline,
}

@(private)
ctx: Context

//
// WGPU Callbacks
//

@(private)
log_callback :: proc(
	level: wgpu.LogLevel,
	message: cstring,
) {
	fmt.println("[wgpu]", message)
}

@(private)
uncaptured_error_callback :: proc(
	type: wgpu.ErrorType,
	message: cstring,
	userdata: rawptr,
) {
	fmt.println("[wgpu]", message)
	panic("Uncaptured WGPU error")
}

@(private)
device_lost_callback :: proc(
	reason: wgpu.DeviceLostReason,
	message: cstring,
	userdata: rawptr,
) {
	fmt.println("[wgpu]", message)
	panic("WGPU device lost")
}

@(private)
request_adapter_callback :: proc(
	status: wgpu.RequestAdapterStatus,
	adapter: wgpu.Adapter,
	message: cstring,
	userdata: rawptr,
) {
	adapter_props: wgpu.AdapterProperties
	wgpu.AdapterGetProperties(adapter, &adapter_props)
	if status == .Success {
		user_adapter := cast(^wgpu.Adapter) userdata
		user_adapter^ = adapter
	}
}

@(private)
request_device_callback :: proc(
	status: wgpu.RequestDeviceStatus,
	received: wgpu.Device,
	message: cstring,
	userdata: rawptr,
) {
	if status == .Success {
		user_device := cast(^wgpu.Device) userdata
		user_device^ = received
	}
}

//
// Init
//

init :: proc(window: ^sdl.Window) {
	wgpu.SetLogCallback(log_callback)
	wgpu.SetLogLevel(.Warn)

	when ODIN_OS == .Linux {
		ctx.backend = .Vulkan

		wm_info: sdl.SysWMinfo
		sdl.GetVersion(&wm_info.version)
		info_response := sdl.GetWindowWMInfo(window, &wm_info)
		fmt.assertf(cast(bool) info_response, "Could not get SDL window info")

		if wm_info.subsystem == .X11 {
			surface_descriptor := wgpu.SurfaceDescriptorFromXlibWindow{
				chain = wgpu.ChainedStruct{
					sType = .SurfaceDescriptorFromXlibWindow,
				},
				display = wm_info.info.x11.display,
				window = cast(u32) wm_info.info.x11.window,
			}

			ctx.surface = wgpu.InstanceCreateSurface(
				nil,
				&wgpu.SurfaceDescriptor{
					nextInChain = cast(^wgpu.ChainedStruct) &surface_descriptor,
				},
			)
		} else {
			panic("Graphics system only supports X11")
		}
	}

	fmt.assertf(ctx.surface != nil, "Failed to initialize graphics surface")

	wgpu.InstanceRequestAdapter(
		nil,
		&wgpu.RequestAdapterOptions{
			compatibleSurface = ctx.surface,
			powerPreference = .HighPerformance,
		},
		request_adapter_callback,
		&ctx.adapter,
	)

	wgpu.AdapterRequestDevice(
		ctx.adapter,
		&wgpu.DeviceDescriptor{
			nextInChain = cast(^wgpu.ChainedStruct) &wgpu.DeviceExtras{
				chain = wgpu.ChainedStruct{
					sType = cast(wgpu.SType) wgpu.NativeSType.DeviceExtras,
				},
			},
			requiredLimits = &wgpu.RequiredLimits{
				limits = wgpu.Limits{
					maxBindGroups = 1,
				},
			},
			defaultQueue = wgpu.QueueDescriptor{},
		},
		request_device_callback,
		&ctx.device,
	)

	wgpu.DeviceSetUncapturedErrorCallback(ctx.device, uncaptured_error_callback, nil)
	wgpu.DeviceSetDeviceLostCallback(ctx.device, device_lost_callback, nil)

	core_shader := create_wgsl_shader_module(ctx.device, #load("shader.wgsl"))
	ctx.swap_chain_texture_format = wgpu.SurfaceGetPreferredFormat(ctx.surface, ctx.adapter)

	ctx.render_pipeline_layout = wgpu.DeviceCreatePipelineLayout(
		ctx.device,
		&wgpu.PipelineLayoutDescriptor{},
	)

	ctx.render_pipeline = wgpu.DeviceCreateRenderPipeline(
		ctx.device,
		&wgpu.RenderPipelineDescriptor{
			label = "Render pipeline",
			layout = ctx.render_pipeline_layout,
			vertex = wgpu.VertexState{
				module = core_shader,
				entryPoint = "vs_main",
			},
			primitive = wgpu.PrimitiveState{
				topology = .TriangleList,
				stripIndexFormat = .Undefined,
				frontFace = .CCW,
				cullMode = .None,
			},
			multisample = wgpu.MultisampleState{
				count = 1,
				mask = wgpu.MultisampleStateMaskMax,
			},
			fragment = &wgpu.FragmentState{
				module = core_shader,
				entryPoint = "fs_main",
				targetCount = 1,
				targets = &wgpu.ColorTargetState{
					format = ctx.swap_chain_texture_format,
					blend = &wgpu.BlendState{
						color = wgpu.BlendComponent{
							srcFactor = .One,
							dstFactor = .Zero,
							operation = .Add,
						},
						alpha = wgpu.BlendComponent{
							srcFactor = .One,
							dstFactor = .Zero,
							operation = .Add,
						},
					},
					writeMask = wgpu.ColorWriteMaskFlagsAll,
				},
			},
		},
	)

	window_width, window_height: i32
	sdl.GetWindowSize(window, &window_width, &window_height)

	ctx.swap_chain = wgpu.DeviceCreateSwapChain(
		ctx.device,
		ctx.surface,
		&wgpu.SwapChainDescriptor{
			usage = {.RenderAttachment},
			format = ctx.swap_chain_texture_format,
			width = cast(u32) window_width,
			height = cast(u32) window_height,
			presentMode = .Fifo,
		},
	)
}
