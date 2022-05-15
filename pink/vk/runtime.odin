/*
Pink Vulkan Renderer: Runtime

Manages drawing each frame.
*/

//+private
package pink_vk

import "core:math/bits"
import "core:mem"
import vk "vendor:vulkan"

/*
Initialize Runtime

Initializes the renderer's runtime drawing components--e.g. command pool,
semaphores, fences, etc.
*/
init_runtime :: proc(ctx: ^Context) -> Response {
	response := Response.OK
	
	if response = init_commands(ctx); response != .OK do return response
	if response = init_sync_objects(ctx); response != .OK do return response
	if response = init_vertex_buffer(ctx); response != .OK do return response
	
	return response
}

/*
Delete Runtime

Destroys Vulkan objects associated with the runtime components and frees all
memory. The runtime can't be recovered after this.
*/

delete_runtime :: proc(ctx: ^Context) -> Response {
	vk.DestroyBuffer(ctx.device, ctx.vertex_buffer, nil)
	vk.FreeMemory(ctx.device, ctx.vertex_buffer_memory, nil)

	for i := 0; i < MAX_FRAMES_IN_FLIGHT; i += 1 {
		vk.DestroySemaphore(ctx.device, ctx.image_available_semaphores[i], nil)
		vk.DestroySemaphore(ctx.device, ctx.render_finished_semaphores[i], nil)
		vk.DestroyFence(ctx.device, ctx.in_flight_fences[i], nil)
	}

	vk.DestroyCommandPool(ctx.device, ctx.command_pool, nil)
	
	return .OK
}

/*
Initialize Vertex Buffer

Initializes the vertex buffer.
*/

init_vertex_buffer :: proc(ctx: ^Context) -> Response {
	buffer_size := vk.DeviceSize(size_of(ctx.vertices[0]) * len(ctx.vertices))
	
	staging_buffer: vk.Buffer
	staging_buffer_memory: vk.DeviceMemory
	
	init_response := init_buffer(
		ctx,
		buffer_size,
		{.TRANSFER_SRC},
		{.HOST_VISIBLE, .HOST_COHERENT},
		&staging_buffer,
		&staging_buffer_memory,
	)
	if init_response != .OK do return init_response
	
	data: rawptr
	vk.MapMemory(ctx.device, staging_buffer_memory, 0, buffer_size, {}, &data)
	mem.copy(data, raw_data(ctx.vertices), int(buffer_size))
	vk.UnmapMemory(ctx.device, staging_buffer_memory)
		
	init_buffer(ctx, buffer_size, {.TRANSFER_DST, .VERTEX_BUFFER}, {.DEVICE_LOCAL}, &ctx.vertex_buffer, &ctx.vertex_buffer_memory)
	
	copy_buffer(ctx, staging_buffer, ctx.vertex_buffer, buffer_size)
	vk.DestroyBuffer(ctx.device, staging_buffer, nil)
	vk.FreeMemory(ctx.device, staging_buffer_memory, nil)
	
	return .OK
}

/*
Initialize Buffer

Helper proc to initialize a Vulkan buffer of any sort.
*/

init_buffer :: proc(ctx: ^Context, size: vk.DeviceSize, usage: vk.BufferUsageFlags, properties: vk.MemoryPropertyFlags, buffer: ^vk.Buffer, buffer_memory: ^vk.DeviceMemory) -> Response {
	buffer_create_info := vk.BufferCreateInfo{
		sType = .BUFFER_CREATE_INFO,
		size = size,
		usage = usage,
		sharingMode = .EXCLUSIVE,
		flags = {},
	}
	
	if vk.CreateBuffer(ctx.device, &buffer_create_info, nil, buffer) != .SUCCESS do return Response.VULKAN_CREATE_BUFFER_FAILED
	
	memory_requirements: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(ctx.device, buffer^, &memory_requirements)
	
	found_memory_type, success := find_memory_type(ctx, memory_requirements.memoryTypeBits, {.HOST_VISIBLE, .HOST_COHERENT})
	if !success do return .VULKAN_NO_SUITABLE_MEMORY_TYPE

	allocate_info := vk.MemoryAllocateInfo{
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = memory_requirements.size,
		memoryTypeIndex = found_memory_type,
	}
	
	if vk.AllocateMemory(ctx.device, &allocate_info, nil, buffer_memory) != .SUCCESS do return Response.VULKAN_ALLOCATE_MEMORY_FAILED
	vk.BindBufferMemory(ctx.device, buffer^, buffer_memory^, 0)

	return .OK
}

/*
Copy Buffer

Copies from one buffer to another.
*/

copy_buffer :: proc(ctx: ^Context, src: vk.Buffer, dst: vk.Buffer, size: vk.DeviceSize) {
	allocate_info := vk.CommandBufferAllocateInfo{
		sType = .COMMAND_BUFFER_ALLOCATE_INFO,
		level = .PRIMARY,
		commandPool = ctx.command_pool,
		commandBufferCount = 1,
	}
	
	command_buffer: vk.CommandBuffer
	vk.AllocateCommandBuffers(ctx.device, &allocate_info, &command_buffer)
	
	begin_info := vk.CommandBufferBeginInfo{
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT},
	}
	
	vk.BeginCommandBuffer(command_buffer, &begin_info)
	
	copy_region := vk.BufferCopy{
		srcOffset = 0,
		dstOffset = 0,
		size = size,
	}
	
	vk.CmdCopyBuffer(command_buffer, src, dst, 1, &copy_region)
	vk.EndCommandBuffer(command_buffer)
	
	submit_info := vk.SubmitInfo{
		sType = .SUBMIT_INFO,
		commandBufferCount = 1,
		pCommandBuffers = &command_buffer,
	}

	vk.QueueSubmit(ctx.queues.graphics, 1, &submit_info, 0)
	vk.QueueWaitIdle(ctx.queues.graphics)
	vk.FreeCommandBuffers(ctx.device, ctx.command_pool, 1, &command_buffer)
}

/*
Find Memory Type
*/

find_memory_type :: proc(ctx: ^Context, type_filter: u32, properties: vk.MemoryPropertyFlags) -> (u32, bool) {
	memory_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(ctx.physical_device, &memory_properties)
	
	for i: u32 = 0; i < memory_properties.memoryTypeCount; i += 1 {
		if (type_filter & (1 << i) != 0) && (memory_properties.memoryTypes[i].propertyFlags & properties == properties) {
			return i, true
		}
	}

	return 0, false
}

/*
Initialize Commands

Initializes the renderer's command pool and buffers.
*/

init_commands :: proc(ctx: ^Context) -> Response {
	// Create the command pool
	{
		queue_family_indices := get_queue_family_indices(ctx.physical_device)
		pool_create_info := vk.CommandPoolCreateInfo{
			sType = .COMMAND_POOL_CREATE_INFO,
			flags = {.RESET_COMMAND_BUFFER},
			queueFamilyIndex = queue_family_indices.graphics.(u32),
		}
	
		if vk.CreateCommandPool(ctx.device, &pool_create_info, nil, &ctx.command_pool) != .SUCCESS do return .VULKAN_CREATE_COMMAND_POOL_FAILED
	}
	
	// Create the command buffers
	{
		allocate_info := vk.CommandBufferAllocateInfo{
			sType = .COMMAND_BUFFER_ALLOCATE_INFO,
			commandPool = ctx.command_pool,
			level = .PRIMARY,
			commandBufferCount = MAX_FRAMES_IN_FLIGHT,
		}
		
		if vk.AllocateCommandBuffers(ctx.device, &allocate_info, &ctx.command_buffers[0]) != .SUCCESS do return .VULKAN_ALLOCATE_COMMAND_BUFFERS_FAILED
	}
	
	return .OK
}

/*
Initialize Sync Objects

Initializes the renderer's semaphores and fences.
*/

init_sync_objects :: proc(ctx: ^Context) -> Response {
	semaphore_create_info := vk.SemaphoreCreateInfo{
		sType = .SEMAPHORE_CREATE_INFO,
	}
	
	fence_create_info := vk.FenceCreateInfo{
		sType = .FENCE_CREATE_INFO,
		flags = {.SIGNALED},
	}
	
	for i := 0; i < MAX_FRAMES_IN_FLIGHT; i += 1 {
		if vk.CreateSemaphore(ctx.device, &semaphore_create_info, nil, &ctx.image_available_semaphores[i]) != .SUCCESS do return Response.VULKAN_CREATE_SEMAPHORE_FAILED
		if vk.CreateSemaphore(ctx.device, &semaphore_create_info, nil, &ctx.render_finished_semaphores[i]) != .SUCCESS do return Response.VULKAN_CREATE_SEMAPHORE_FAILED
		if vk.CreateFence(ctx.device, &fence_create_info, nil, &ctx.in_flight_fences[i]) != .SUCCESS do return Response.VULKAN_CREATE_FENCE_FAILED
	}
	
	return .OK
}

/*
Render Frame

Renders the next frame.
*/

render_frame :: proc(ctx: ^Context) -> Response {
	response := Response.OK

	vk.WaitForFences(ctx.device, 1, &ctx.in_flight_fences[ctx.current_frame], true, bits.U64_MAX)
	
	image_index: u32
	next_image_result := vk.AcquireNextImageKHR(ctx.device, ctx.swap_chain.main, bits.U64_MAX, ctx.image_available_semaphores[ctx.current_frame], 0, &image_index)
	if next_image_result == .ERROR_OUT_OF_DATE_KHR || next_image_result == .SUBOPTIMAL_KHR || ctx.reinit_graphics_pipeline {
		ctx.reinit_graphics_pipeline = false
		reinit_pipeline(ctx)
		return .OK
	} else if next_image_result != .SUCCESS && next_image_result != .SUBOPTIMAL_KHR {
		return .VULKAN_ACQUIRE_NEXT_IMAGE_FAILED
	}
	
	vk.ResetFences(ctx.device, 1, &ctx.in_flight_fences[ctx.current_frame])
	vk.ResetCommandBuffer(ctx.command_buffers[ctx.current_frame], {})
	
	if response = record_command_buffer(ctx.command_buffers[ctx.current_frame], image_index); response != .OK do return response

	wait_semaphores := []vk.Semaphore{ctx.image_available_semaphores[ctx.current_frame]}
	wait_stages := []vk.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}
	signal_semaphores := []vk.Semaphore{ctx.render_finished_semaphores[ctx.current_frame]}

	submit_info := vk.SubmitInfo{
		sType = .SUBMIT_INFO,
		waitSemaphoreCount = 1,
		pWaitSemaphores = &wait_semaphores[0],
		pWaitDstStageMask = &wait_stages[0],
		signalSemaphoreCount = 1,
		pSignalSemaphores = &signal_semaphores[0],
		commandBufferCount = 1,
		pCommandBuffers = &ctx.command_buffers[ctx.current_frame],
	}
	
	if vk.QueueSubmit(ctx.queues.graphics, 1, &submit_info, ctx.in_flight_fences[ctx.current_frame]) != .SUCCESS do return Response.VULKAN_QUEUE_SUBMIT_FAILED

	present_info := vk.PresentInfoKHR{
		sType = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores = &signal_semaphores[0],
		swapchainCount = 1,
		pSwapchains = &ctx.swap_chain.main,
		pImageIndices = &image_index,
		pResults = nil,
	}
	
	vk.QueuePresentKHR(ctx.queues.present, &present_info)
	ctx.current_frame = (ctx.current_frame + 1) % MAX_FRAMES_IN_FLIGHT

	return response
}

/*
Record Command Buffer

Records the necessary rendering commands into a command buffer.
*/

record_command_buffer :: proc(command_buffer: vk.CommandBuffer, image_index: u32) -> Response {
	begin_info := vk.CommandBufferBeginInfo{
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {},
		pInheritanceInfo = nil,
	}
	
	if vk.BeginCommandBuffer(command_buffer, &begin_info) != .SUCCESS do return .VULKAN_BEGIN_COMMAND_BUFFER_FAILED
	
	render_pass_begin_info := vk.RenderPassBeginInfo{
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = ctx.render_pass,
		framebuffer = ctx.swap_chain.framebuffers[image_index],
		renderArea = vk.Rect2D{
			offset = {0, 0},
			extent = ctx.swap_chain.extent,
		},
		clearValueCount = 1,
		pClearValues = &vk.ClearValue{
			color = vk.ClearColorValue{float32 = {0.0, 0.0, 0.0, 1.0}},
		},
	}
	
	vk.CmdBeginRenderPass(command_buffer, &render_pass_begin_info, .INLINE)
	vk.CmdBindPipeline(command_buffer, .GRAPHICS, ctx.graphics_pipeline)
	
	vertex_buffers := []vk.Buffer{ctx.vertex_buffer}
	offsets := []vk.DeviceSize{0}
	vk.CmdBindVertexBuffers(command_buffer, 0, 1, &vertex_buffers[0], &offsets[0])
	
	vk.CmdDraw(command_buffer, 3, 1, 0, 0)
	vk.CmdEndRenderPass(command_buffer)
	
	if vk.EndCommandBuffer(command_buffer) != .SUCCESS do return .VULKAN_END_COMMAND_BUFFER_FAILED
	return .OK
}
