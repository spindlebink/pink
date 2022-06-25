//+private
package pink

import "core:c"
import "core:fmt"
import sdl "vendor:sdl2"
import "wgpu/wgpu"

Primitive_Type :: enum u8 {
	Quad,
}

Primitive :: struct {
	type: Primitive_Type,
	data: Coord,
}

// Holds draw commands.
Draw_Command :: struct {
	primitive: Primitive,
	transform: Transform,
}

// Holds commands applied to the renderer context--transformations, clears, etc.
Context_Command :: struct {
}

graphics_state: struct {
	destroying: bool,

	surface: wgpu.Surface,
	adapter: wgpu.Adapter,
	device: wgpu.Device,

	swap_chain: wgpu.SwapChain,
	texture_format: wgpu.TextureFormat,
	render_pipeline: wgpu.RenderPipeline,

	command_encoder: wgpu.CommandEncoder,
	render_pass_encoder: wgpu.RenderPassEncoder,

	vertex_buffer_size: u64,
	vertex_buffer: wgpu.Buffer,
	index_buffer_size: u64,
	index_buffer: wgpu.Buffer,

	draw_stack: [dynamic]Draw_Command,
}

// WGPU callbacks

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
	adapter_props: wgpu.AdapterProperties
	wgpu.AdapterGetProperties(adapter, &adapter_props)
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
	fmt.eprintln("[wgpu]", message)
	debug_assert_fatal(false, "WGPU error")
}

device_lost_callback :: proc(
	reason: wgpu.DeviceLostReason,
	message: cstring,
	userdata: rawptr,
) {
	if graphics_state.destroying do return
	
	fmt.eprintln("[wgpu]", message)
	debug_assert_fatal(false, "WGPU device lost")
}

// Graphics procedures

// Initializes the graphics context on a given SDL window.
graphics_init :: proc(window: ^sdl.Window) {
	debug_scope_push("init graphics"); defer debug_scope_pop()

	when ODIN_OS == .Linux {
		wm_info: sdl.SysWMinfo
		sdl.GetVersion(&wm_info.version)
		info_response := sdl.GetWindowWMInfo(window, &wm_info)

		debug_assert_fatal(cast(bool) info_response, "could not get window information")
		debug_assert_fatal(wm_info.subsystem == .X11, "graphics support only available for X11")

		surface_descriptor := wgpu.SurfaceDescriptorFromXlibWindow{
			chain = wgpu.ChainedStruct{
				sType = .SurfaceDescriptorFromXlibWindow,
			},
			display = wm_info.info.x11.display,
			window = cast(c.uint32_t) wm_info.info.x11.window,
		}
		graphics_state.surface = wgpu.InstanceCreateSurface(
			nil,
			&wgpu.SurfaceDescriptor{
				nextInChain = cast(^wgpu.ChainedStruct) &surface_descriptor,
			},
		)
	}

	debug_assert_fatal(graphics_state.surface != nil, "failed to initialize graphics surface")	
	
	wgpu.SetLogCallback(log_callback)
	wgpu.SetLogLevel(.Warn)
	
	wgpu.InstanceRequestAdapter(
		nil,
		&wgpu.RequestAdapterOptions{
			compatibleSurface = graphics_state.surface,
			powerPreference = .HighPerformance, // TODO: make configurable
		},
		instance_request_adapter_callback,
		&graphics_state.adapter,
	)
	
	debug_assert_fatal(graphics_state.adapter != nil, "failed to obtain adapter")
	
	wgpu.AdapterRequestDevice(
		graphics_state.adapter,
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
		adapter_request_device_callback,
		&graphics_state.device,
	)

	debug_assert_fatal(graphics_state.device != nil, "failed to obtain device")
	
	wgpu.DeviceSetUncapturedErrorCallback(
		graphics_state.device,
		uncaptured_error_callback,
		nil,
	)
	wgpu.DeviceSetDeviceLostCallback(
		graphics_state.device,
		device_lost_callback,
		nil,
	)

	graphics_state.texture_format = wgpu.SurfaceGetPreferredFormat(
		graphics_state.surface,
		graphics_state.adapter,
	)
	
	core_shader := create_wgsl_shader_module(
		graphics_state.device,
		#load("shader.wgsl"),
	)
	
	vertex_attributes := [ATTRIBUTE_COUNT]wgpu.VertexAttribute{
		wgpu.VertexAttribute{
			offset = cast(c.uint64_t) offset_of(Vertex, position),
			shaderLocation = 0,
			format = .Float32x2,
		},
		wgpu.VertexAttribute{
			offset = cast(c.uint64_t) offset_of(Vertex, color),
			shaderLocation = 1,
			format = .Float32x4,
		},
		wgpu.VertexAttribute{
			offset = cast(c.uint64_t) offset_of(Vertex, texture_coord),
			shaderLocation = 2,
			format = .Float32x2,
		},
	}

	vertex_buffer_layout := wgpu.VertexBufferLayout{
		arrayStride = cast(c.uint64_t) size_of(Vertex),
		stepMode = .Vertex,
		attributeCount = ATTRIBUTE_COUNT,
		attributes = cast([^]wgpu.VertexAttribute) &vertex_attributes,
	}

	graphics_state.render_pipeline = wgpu.DeviceCreateRenderPipeline(
		graphics_state.device,
		&wgpu.RenderPipelineDescriptor{
			label = "Render pipeline",
			layout = wgpu.DeviceCreatePipelineLayout(
				graphics_state.device,
				&wgpu.PipelineLayoutDescriptor{},
			),
			vertex = wgpu.VertexState{
				module = core_shader,
				entryPoint = "vertex_main",
				bufferCount = 1,
				buffers = &vertex_buffer_layout,
			},
			fragment = &wgpu.FragmentState{
				module = core_shader,
				entryPoint = "fragment_main",
				targetCount = 1,
				targets = &wgpu.ColorTargetState{
					format = graphics_state.texture_format,
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
			primitive = wgpu.PrimitiveState{
				topology = .TriangleList,
				stripIndexFormat = .Undefined,
				frontFace = .CCW,
				cullMode = .Back,
			},
			multisample = wgpu.MultisampleState{
				count = 1,
				mask = wgpu.MultisampleStateMaskMax,
			},
		},
	)
	
	graphics_rebuild_swap_chain()
}

graphics_rebuild_swap_chain :: proc() {
	fmt.println("Rebuilding swap chain")
	graphics_state.swap_chain = wgpu.DeviceCreateSwapChain(
		graphics_state.device,
		graphics_state.surface,
		&wgpu.SwapChainDescriptor{
			usage = {.RenderAttachment},
			format = graphics_state.texture_format,
			width = cast(c.uint32_t) window_state.width,
			height = cast(c.uint32_t) window_state.height,
			presentMode = .Fifo,
		},
	)
}

graphics_destroy :: proc() {
	graphics_state.destroying = true
	delete(graphics_state.draw_stack)
	if graphics_state.vertex_buffer != nil {
		wgpu.BufferDestroy(graphics_state.vertex_buffer)
	}
	if graphics_state.index_buffer != nil {
		wgpu.BufferDestroy(graphics_state.index_buffer)
	}
	if graphics_state.device != nil {
		wgpu.DeviceDestroy(graphics_state.device)
	}
}

// Submits a draw command to the current draw stack.
graphics_submit_draw_command :: proc(command: Draw_Command) {
	append(&graphics_state.draw_stack, command)
}

// Generates the renderer's vertex buffer from the current draw command queue.
graphics_gen_vertex_buffer:: proc() {
	// until renderer is actually written, we only want to generate the VB once
	@(static) dbg_already_gen := false
	
	if dbg_already_gen do return
	dbg_already_gen = true
	
	fmt.println("Generating POC vertex buffer")
	
	vertices := renderer_poc_vertices()
	graphics_state.vertex_buffer = wgpu.DeviceCreateBuffer(
		graphics_state.device,
		&wgpu.BufferDescriptor{
			usage = {.Vertex},
			size = cast(c.uint64_t) (size_of(Vertex) * len(vertices)),
			mappedAtCreation = true,
		},
	)
	
	range := cast([^]Vertex) wgpu.BufferGetMappedRange(
		graphics_state.vertex_buffer,
		0,
		cast(c.size_t) (size_of(Vertex) * len(vertices)),
	)
	for i := 0; i < len(vertices); i += 1 {
		range[i] = vertices[i]
	}
	wgpu.BufferUnmap(graphics_state.vertex_buffer)
}

// Finishes collecting draw commands, generates the vertex buffer for this
// frame, and renders it on the GPU. Called once per frame.
graphics_render :: proc() {
	graphics_gen_vertex_buffer()
	
	next_texture := wgpu.SwapChainGetCurrentTextureView(graphics_state.swap_chain)
	
	if next_texture == nil {
		panic("Could not acquire next swap chain texture")
	}
	command_encoder := wgpu.DeviceCreateCommandEncoder(
		graphics_state.device,
		&wgpu.CommandEncoderDescriptor{},
	)

	render_pass := wgpu.CommandEncoderBeginRenderPass(
		command_encoder,
		&wgpu.RenderPassDescriptor{
			label = "Render pass",
			colorAttachments = &wgpu.RenderPassColorAttachment{
				view = next_texture,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = wgpu.Color{0.0, 0.0, 0.0, 1.0},
			},
			colorAttachmentCount = 1,
		},
	)

	wgpu.RenderPassEncoderSetPipeline(
		render_pass,
		graphics_state.render_pipeline,
	)
	wgpu.RenderPassEncoderSetVertexBuffer(
		render_pass,
		0,
		graphics_state.vertex_buffer,
		0,
		wgpu.WHOLE_SIZE,
	)

	// BEGIN DRAW CALLS
	
	wgpu.RenderPassEncoderDraw(render_pass, 3, 1, 0, 0)
	
	// END DRAW CALLS

	wgpu.RenderPassEncoderEnd(render_pass)

	queue := wgpu.DeviceGetQueue(graphics_state.device)
	cmd_buffer := wgpu.CommandEncoderFinish(
		command_encoder,
		&wgpu.CommandBufferDescriptor{},
	)
	
	wgpu.QueueSubmit(queue, 1, &cmd_buffer)
	wgpu.SwapChainPresent(graphics_state.swap_chain)
}
