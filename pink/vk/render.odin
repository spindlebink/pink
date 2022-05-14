package pink_vk

import sdl "vendor:sdl2"
import vk "vendor:vulkan"
import "core:math/bits"
import "core:log"

//****************************************************************************//
// Load + Initialize + Destroy
//****************************************************************************//

load :: proc() -> (ok := true) {
	log.debug("Loading Vulkan...")

	if sdl.Vulkan_LoadLibrary(nil) < 0 {
		append(&error_buf, Error.SDL_VULKAN_LOAD_FAILED)
		return false
	}
	
	vk.load_proc_addresses(sdl.Vulkan_GetVkGetInstanceProcAddr())

	log.debug("Vulkan successfully loaded.")
	return true
}

init :: proc(window: ^sdl.Window) -> (ok := true) {
	ctx.window = window
	ok = create_context()
	return
}

destroy :: proc() -> (ok := true) {
	destroy_context()
	return
}

//****************************************************************************//
// Draw Frame
//****************************************************************************//

draw_frame :: proc() -> (ok := true) {
	vk.WaitForFences(ctx.device, 1, &ctx.in_flight_fences[ctx.current_frame], true, bits.U64_MAX)
	
	image_index: u32
	result := vk.AcquireNextImageKHR(ctx.device, ctx.swap_chain, bits.U64_MAX, ctx.image_available_semaphores[ctx.current_frame], 0, &image_index)
	
	if result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR || ctx.framebuffer_resized {
		ctx.framebuffer_resized = false
		recreate_swap_chain()
		return
	} else if result != .SUCCESS && result != .SUBOPTIMAL_KHR {
		append(&error_buf, Error.VULKAN_ACQUIRE_NEXT_IMAGE_FAILED)
		return false
	}
	
	vk.ResetFences(ctx.device, 1, &ctx.in_flight_fences[ctx.current_frame])
	vk.ResetCommandBuffer(ctx.command_buffers[ctx.current_frame], {})
	record_command_buffer(ctx.command_buffers[ctx.current_frame], image_index)
	
	submit_info: vk.SubmitInfo
	submit_info.sType = .SUBMIT_INFO

	wait_semaphores := []vk.Semaphore{ctx.image_available_semaphores[ctx.current_frame]}
	wait_stages := []vk.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}
	
	submit_info.waitSemaphoreCount = 1
	submit_info.pWaitSemaphores = raw_data(wait_semaphores)
	submit_info.pWaitDstStageMask = raw_data(wait_stages)
	
	submit_info.commandBufferCount = 1
	submit_info.pCommandBuffers = &ctx.command_buffers[ctx.current_frame]
	
	signal_semaphores := []vk.Semaphore{ctx.render_finished_semaphores[ctx.current_frame]}
	submit_info.signalSemaphoreCount = 1
	submit_info.pSignalSemaphores = raw_data(signal_semaphores)
	
	if vk.QueueSubmit(ctx.graphics_queue, 1, &submit_info, ctx.in_flight_fences[ctx.current_frame]) != .SUCCESS {
		append(&error_buf, Error.VULKAN_QUEUE_SUBMIT_FAILED)
		return false
	}
	
	present_info: vk.PresentInfoKHR
	present_info.sType = .PRESENT_INFO_KHR
	present_info.waitSemaphoreCount = 1
	present_info.pWaitSemaphores = raw_data(signal_semaphores)

	swap_chains := []vk.SwapchainKHR{ctx.swap_chain}
	present_info.swapchainCount = 1
	present_info.pSwapchains = raw_data(swap_chains)
	present_info.pImageIndices = &image_index
	present_info.pResults = nil
	
	vk.QueuePresentKHR(ctx.present_queue, &present_info)
	ctx.current_frame = (ctx.current_frame + 1) % MAX_FRAMES_IN_FLIGHT
	
	return
}

//****************************************************************************//
// Other Procs
//****************************************************************************//

trigger_resize :: proc() {
	ctx.framebuffer_resized = true
}
