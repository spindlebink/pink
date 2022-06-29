//+private
package pink

import "core:c"
import "core:fmt"
import "core:sync"
import "core:thread"
import "core:time"
import sdl "vendor:sdl2"
import "wgpu/wgpu"

// ************************************************************************** //
// Types & Constants
// ************************************************************************** //

PRIMITIVE_VERTICES := []Vertex{
	// Quad
	Vertex{{-1.0, -1.0}},
	Vertex{{1.0, -1.0}},
	Vertex{{-1.0, 1.0}},
	Vertex{{-1.0, 1.0}},
	Vertex{{1.0, -1.0}},
	Vertex{{1.0, 1.0}},
}

Buffer :: struct {
	handle: wgpu.Buffer,
	size: int,
	usage_flags: wgpu.BufferUsageFlags,
}

Vertex :: struct {
	position: [2]f32,
}

Primitive_Instance :: struct {
	translation: [2]f32,
	scale: [2]f32,
	rotation: f32,
	modulation: [4]f32,
}

Draw_Command_Type :: enum {
	Rectangle_Primitive,
}

Draw_Command :: struct {
	type: Draw_Command_Type,
	count: u32,
}

Draw_State :: struct {
	color: Color,
}

graphics_state: struct {
	surface: wgpu.Surface,
	adapter: wgpu.Adapter,
	device: wgpu.Device,
	queue: wgpu.Queue,
	exiting: bool,
	swap_chain_expired: bool,
	swap_chain: wgpu.SwapChain,
	texture_format: wgpu.TextureFormat,
	render_pipeline: wgpu.RenderPipeline,
	command_encoder: wgpu.CommandEncoder,
	render_pass: wgpu.RenderPassEncoder,
	
	primitive_vertices: Buffer,
	primitive_vertex_data: []Vertex,
	primitive_instances: Buffer,
	primitive_instance_data: Dirty_Array(Primitive_Instance),

	draw_commands: Dirty_Array(Draw_Command),
	draw_state_stack: Dirty_Array(Draw_State),
	draw_state: ^Draw_State,
} = {
	primitive_vertices = Buffer{
		usage_flags = {.Vertex, .CopyDst},
	},
	primitive_vertex_data = PRIMITIVE_VERTICES,
	primitive_instances = Buffer{
		usage_flags = {.Vertex, .CopyDst},
	},
}

// ************************************************************************** //
// Helpers
// ************************************************************************** //

buffer_ensure_size :: proc(buffer: ^Buffer, size: int) {
	if size > buffer.size {
		// fmt.println("Resizing buffer to fit")
		if buffer.handle != nil do wgpu.BufferDestroy(buffer.handle)
		buffer.handle = wgpu.DeviceCreateBuffer(
			graphics_state.device,
			&wgpu.BufferDescriptor{
				usage = buffer.usage_flags,
				size = cast(c.uint64_t) size,
			},
		)
		buffer.size = size
	}
}

wgsl_shader_module_create :: proc(
	device: wgpu.Device,
	source: []u8,
) -> wgpu.ShaderModule {
	wgsl_descriptor := wgpu.ShaderModuleWGSLDescriptor{
		chain = wgpu.ChainedStruct{
			sType = .ShaderModuleWGSLDescriptor,
		},
		code = cast(cstring) raw_data(source),
	}
	descriptor := wgpu.ShaderModuleDescriptor{
		nextInChain = cast(^wgpu.ChainedStruct) &wgsl_descriptor,
	}
	shader_module := wgpu.DeviceCreateShaderModule(device, &descriptor)
	return shader_module
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
	if graphics_state.exiting do return
	fmt.eprintln("[wgpu]", message)
}

// ************************************************************************** //
// Load
// ************************************************************************** //

graphics_load :: proc() {
	debug_scope_push("init graphics"); defer debug_scope_pop()

	//
	// OS-specific initialization
	//
	when ODIN_OS == .Linux {
		wm_info: sdl.SysWMinfo
		sdl.GetVersion(&wm_info.version)
		info_response := sdl.GetWindowWMInfo(window_state.handle, &wm_info)

		debug_assert_fatal(
			cast(bool) info_response,
			"could not get window information",
		)
		debug_assert_fatal(
			wm_info.subsystem == .X11,
			"graphics support only available for X11",
		)

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

	wgpu.SetLogCallback(log_callback)
	wgpu.SetLogLevel(.Warn) // TODO: make configurable

	//
	// Adapter + device
	//
	{
		using graphics_state

		wgpu.InstanceRequestAdapter(
			nil,
			&wgpu.RequestAdapterOptions{
				compatibleSurface = surface,
				powerPreference = .HighPerformance, // TODO: make configurable
			},
			instance_request_adapter_callback,
			&adapter,
		)
		
		debug_assert_fatal(adapter != nil, "failed to obtain adapter")
		
		wgpu.AdapterRequestDevice(
			adapter,
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
			&device,
		)

		debug_assert_fatal(device != nil, "failed to obtain device")
			
		wgpu.DeviceSetUncapturedErrorCallback(
			device,
			uncaptured_error_callback,
			nil,
		)
		wgpu.DeviceSetDeviceLostCallback(
			device,
			device_lost_callback,
			nil,
		)
	}

	//
	// Rendering context
	//
	{
		using graphics_state

		texture_format = wgpu.SurfaceGetPreferredFormat(surface, adapter)
		core_shader := wgsl_shader_module_create(
			graphics_state.device,
			#load("shader.wgsl"),
		)

		// Vertex attributes

		primitive_vertices_attributes := []wgpu.VertexAttribute{
			wgpu.VertexAttribute{
				offset = c.uint64_t(offset_of(Vertex, position)),
				shaderLocation = 0,
				format = .Float32x2,
			},
		}

		primitive_instances_attributes := []wgpu.VertexAttribute{
			wgpu.VertexAttribute{
				offset = c.uint64_t(offset_of(Primitive_Instance, translation)),
				shaderLocation = 1,
				format = .Float32x2,
			},
			wgpu.VertexAttribute{
				offset = c.uint64_t(offset_of(Primitive_Instance, scale)),
				shaderLocation = 2,
				format = .Float32x2,
			},
			wgpu.VertexAttribute{
				offset = c.uint64_t(offset_of(Primitive_Instance, rotation)),
				shaderLocation = 3,
				format = .Float32,
			},
			wgpu.VertexAttribute{
				offset = c.uint64_t(offset_of(Primitive_Instance, modulation)),
				shaderLocation = 4,
				format = .Float32x4,
			},
		}
		
		primitive_vertices_layout := wgpu.VertexBufferLayout{
			arrayStride = c.uint64_t(size_of(Vertex)),
			stepMode = .Vertex,
			attributeCount = 1,
			attributes = cast([^]wgpu.VertexAttribute) raw_data(primitive_vertices_attributes),
		}

		primitive_instances_layout := wgpu.VertexBufferLayout{
			arrayStride = c.uint64_t(size_of(Primitive_Instance)),
			stepMode = .Instance,
			attributeCount = 4,
			attributes = cast([^]wgpu.VertexAttribute) raw_data(primitive_instances_attributes),
		}

		vertex_buffer_layouts := []wgpu.VertexBufferLayout{primitive_vertices_layout, primitive_instances_layout}
		
		// Pipeline

		render_pipeline = wgpu.DeviceCreateRenderPipeline(
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
					bufferCount = 2,
					buffers = cast([^]wgpu.VertexBufferLayout) raw_data(vertex_buffer_layouts),
				},
				fragment = &wgpu.FragmentState{
					module = core_shader,
					entryPoint = "fragment_main",
					targetCount = 1,
					targets = &wgpu.ColorTargetState{
						format = texture_format,
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
					frontFace = .CW,
					cullMode = .None,
				},
				multisample = wgpu.MultisampleState{
					count = 1,
					mask = wgpu.MultisampleStateMaskMax,
				},
			},
		) // wgpu.DeviceCreateRenderPipeline

		graphics_rebuild_swap_chain()
	}
	
	//
	// Drawing state
	//
	{
		using graphics_state
		
		dirty_array_push(&draw_state_stack, Draw_State{
			color = Color{1.0, 1.0, 1.0, 1.0},
		})
		draw_state = &draw_state_stack.data[0]
	}
}

// ************************************************************************** //
// Exit
// ************************************************************************** //

graphics_exit :: proc() {
	using graphics_state
	exiting = true
	if primitive_vertices.handle != nil do wgpu.BufferDestroy(primitive_vertices.handle)
	if primitive_instances.handle != nil do wgpu.BufferDestroy(primitive_instances.handle)
	if device != nil do wgpu.DeviceDestroy(device)
	delete(primitive_instance_data.data)
	delete(draw_commands.data)
	delete(draw_state_stack.data)
}

// ************************************************************************** //
// Context Management
// ************************************************************************** //

graphics_rebuild_swap_chain :: proc() {
	graphics_state.swap_chain_expired = false
	graphics_state.swap_chain = wgpu.DeviceCreateSwapChain(
		graphics_state.device,
		graphics_state.surface,
		&wgpu.SwapChainDescriptor{
			usage = {.RenderAttachment},
			format = graphics_state.texture_format,
			width = c.uint32_t(window_state.width),
			height = c.uint32_t(window_state.height),
			presentMode = .Fifo,
		},
	)
}

graphics_generate_buffers :: proc() {
	using graphics_state

	// Primitive buffer holds a single instance of vertex info for each primitive
	// type. We only want to write it once.
	@(static) generated_primitive_buffer := false
	if !generated_primitive_buffer {
		generated_primitive_buffer = true
		buffer_ensure_size(
			&primitive_vertices,
			len(primitive_vertex_data) * size_of(Vertex),
		)
		wgpu.QueueWriteBuffer(
			queue,
			primitive_vertices.handle,
			0,
			raw_data(primitive_vertex_data),
			len(primitive_vertex_data) * size_of(Vertex),
		)
	}
	
	// Write instance buffer
	
	if primitive_instance_data.head > 0 {
		data_size := primitive_instance_data.head * size_of(Primitive_Instance)
		buffer_ensure_size(&primitive_instances, data_size)
		wgpu.QueueWriteBuffer(
			queue,
			primitive_instances.handle,
			0,
			raw_data(primitive_instance_data.data),
			c.size_t(data_size),
		)
		
		dirty_array_clean(&primitive_instance_data)
	}
}

// ************************************************************************** //
// Render
// ************************************************************************** //

graphics_frame_begin :: proc() {
	using graphics_state

	if swap_chain_expired do graphics_rebuild_swap_chain()

	queue = wgpu.DeviceGetQueue(device)	

	next_texture := wgpu.SwapChainGetCurrentTextureView(swap_chain)
	debug_assert_fatal(next_texture != nil, "could not acquire next texture")

	command_encoder = wgpu.DeviceCreateCommandEncoder(
		device,
		&wgpu.CommandEncoderDescriptor{},
	)

	graphics_generate_buffers()

	render_pass = wgpu.CommandEncoderBeginRenderPass(
		command_encoder,
		&wgpu.RenderPassDescriptor{
			label = "Render Pass",
			colorAttachments = &wgpu.RenderPassColorAttachment{
				view = next_texture,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = wgpu.Color{0.0, 0.0, 0.0, 1.0},
			},
			colorAttachmentCount = 1,
		},
	)
	wgpu.RenderPassEncoderSetPipeline(render_pass, render_pipeline)
}

graphics_frame_render :: proc() {
	using graphics_state
	
	// Draw from buffers here
	wgpu.RenderPassEncoderSetVertexBuffer(
		render_pass,
		0,
		primitive_vertices.handle,
		0,
		wgpu.WHOLE_SIZE,
	)
	wgpu.RenderPassEncoderSetVertexBuffer(
		render_pass,
		1,
		primitive_instances.handle,
		0,
		wgpu.WHOLE_SIZE,
	)
	
	current_instance: u32 = 0
	for i := 0; i < draw_commands.head; i += 1 {
		command := draw_commands.data[i]
		switch command.type {
		case .Rectangle_Primitive:
			wgpu.RenderPassEncoderDraw(
				render_pass,
				6, // six vertices in a rectangle,
				c.uint32_t(command.count),
				0, // rectangle vertices are at the start of PRIMITIVE_VERTICES
				c.uint32_t(current_instance),
			)
		}
		current_instance += command.count
	}
	
	dirty_array_clean(&draw_commands)
}

graphics_frame_end :: proc() {
	using graphics_state

	wgpu.RenderPassEncoderEnd(render_pass)
	commands := wgpu.CommandEncoderFinish(
		command_encoder,
		&wgpu.CommandBufferDescriptor{},
	)
	wgpu.QueueSubmit(queue, 1, &commands)
	wgpu.SwapChainPresent(swap_chain)
}

// ************************************************************************** //
// Draw Commands
// ************************************************************************** //

draw_command_add_rectangle :: proc(x, y, w, h: f32) {
	using graphics_state
	
	win_w, win_h := f32(window_state.width), f32(window_state.height)
	scaled_x, scaled_y := (x + w * 0.5) / (win_w * 0.5) - 1.0, 1.0 - (y + h * 0.5) / (win_h * 0.5)
	scaled_w, scaled_h := w / win_w, h / win_h
	
	data := Primitive_Instance{
		translation = {scaled_x, scaled_y},
		scale = {scaled_w, scaled_h},
		rotation = 0.0,
		modulation = cast([4]f32) draw_state.color,
	}
	
	dirty_array_push(&primitive_instance_data, data)
	
	if draw_commands.head > 0 {
		top := &draw_commands.data[draw_commands.head - 1]
		if top.type == .Rectangle_Primitive {
			top.count += 1
		} else {
			dirty_array_push(&draw_commands, Draw_Command{
				type = .Rectangle_Primitive,
				count = 1,
			})
		}
	} else {
		dirty_array_push(&draw_commands, Draw_Command{
			type = .Rectangle_Primitive,
			count = 1,
		})
	}
}
