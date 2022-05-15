/*
Pink Vulkan Renderer: Runtime

Manages drawing each frame.
*/

//+private
package pink_vk

import "core:math/bits"
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
	
	return response
}

/*
Delete Runtime

Destroys Vulkan objects associated with the runtime components and frees all
memory. The runtime can't be recovered after this.
*/

delete_runtime :: proc(ctx: ^Context) -> Response {
	for i := 0; i < MAX_FRAMES_IN_FLIGHT; i += 1 {
		vk.DestroySemaphore(ctx.device, ctx.image_available_semaphores[i], nil)
		vk.DestroySemaphore(ctx.device, ctx.render_finished_semaphores[i], nil)
		vk.DestroyFence(ctx.device, ctx.in_flight_fences[i], nil)
	}

	vk.DestroyCommandPool(ctx.device, ctx.command_pool, nil)
	
	return .OK
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
	vk.CmdDraw(command_buffer, 3, 1, 0, 0)
	vk.CmdEndRenderPass(command_buffer)
	
	if vk.EndCommandBuffer(command_buffer) != .SUCCESS do return .VULKAN_END_COMMAND_BUFFER_FAILED
	return .OK
}
