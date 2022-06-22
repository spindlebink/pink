package pink_graphics

import "core:fmt"
import "core:mem"
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
	
	next_texture: wgpu.TextureView,
	command_encoder: wgpu.CommandEncoder,
	render_pass: wgpu.RenderPassEncoder,

	vertex_buffer: wgpu.Buffer,
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

	ctx.vertex_buffer = wgpu.DeviceCreateBuffer(
		ctx.device,
		&wgpu.BufferDescriptor{
			usage = {.Vertex},
			size = cast(u64) (size_of(Vertex) * len(VERTICES)),
			mappedAtCreation = true,
		},
	)
	
	vertex_attributes := []wgpu.VertexAttribute{
		wgpu.VertexAttribute{
			offset = cast(u64) offset_of(Vertex, position),
			shaderLocation = 0,
			format = .Float32x3,
		},
		wgpu.VertexAttribute{
			offset = cast(u64) offset_of(Vertex, color),
			shaderLocation = 1,
			format = .Float32x3,
		},
	}

	vertex_buffer_layout := wgpu.VertexBufferLayout{
		arrayStride = cast(u64) size_of(Vertex),
		stepMode = .Vertex,
		attributeCount = 2,
		attributes = raw_data(vertex_attributes),
	}
	
	range := cast([^]Vertex) wgpu.BufferGetMappedRange(ctx.vertex_buffer, 0, cast(uint) (size_of(Vertex) * len(VERTICES)))
	verts := VERTICES
	for i := 0; i < len(verts); i += 1 {
		range[i] = verts[i]
	}
	wgpu.BufferUnmap(ctx.vertex_buffer)

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
				bufferCount = 1,
				buffers = &vertex_buffer_layout,
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

	rebuild_swap_chain(cast(u32) window_width, cast(u32) window_height)
}

//
// Rebuild Swap Chain
//

rebuild_swap_chain :: proc(width: u32, height: u32) {
	fmt.println("Rebuilding swap chain")
	ctx.swap_chain = wgpu.DeviceCreateSwapChain(
		ctx.device,
		ctx.surface,
		&wgpu.SwapChainDescriptor{
			usage = {.RenderAttachment},
			format = ctx.swap_chain_texture_format,
			width = width,
			height = height,
			presentMode = .Fifo,
		},
	)
}

//
// Begin Rendering
//

begin_render :: proc() {
	ctx.next_texture = wgpu.SwapChainGetCurrentTextureView(ctx.swap_chain)
	if ctx.next_texture == nil {
		panic("Could not acquire next swap chain texture")
	}
	
	ctx.command_encoder = wgpu.DeviceCreateCommandEncoder(
		ctx.device,
		&wgpu.CommandEncoderDescriptor{},
	)
	
	ctx.render_pass = wgpu.CommandEncoderBeginRenderPass(
		ctx.command_encoder,
		&wgpu.RenderPassDescriptor{
			colorAttachments = &wgpu.RenderPassColorAttachment{
				view = ctx.next_texture,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = wgpu.Color{0.25, 0.25, 0.25, 1.0},
			},
			colorAttachmentCount = 1,
		},
	)
	
	wgpu.RenderPassEncoderSetPipeline(ctx.render_pass, ctx.render_pipeline)
	
	wgpu.RenderPassEncoderSetVertexBuffer(ctx.render_pass, 0, ctx.vertex_buffer, 0, wgpu.WHOLE_SIZE)
	wgpu.RenderPassEncoderDraw(ctx.render_pass, cast(u32) len(VERTICES), 1, 0, 0)
}

//
// End Rendering
//

end_render :: proc() {
	wgpu.RenderPassEncoderEnd(ctx.render_pass)
	
	queue := wgpu.DeviceGetQueue(ctx.device)
	cmd_buffer := wgpu.CommandEncoderFinish(
		ctx.command_encoder,
		&wgpu.CommandBufferDescriptor{},
	)
	
	wgpu.QueueSubmit(queue, 1, &cmd_buffer)
	wgpu.SwapChainPresent(ctx.swap_chain)
}
