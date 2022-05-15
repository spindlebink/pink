/*
Pink Vulkan Renderer: Types

Main renderer context struct and associated types.
*/

package pink_vk

import vk "vendor:vulkan"

MAX_FRAMES_IN_FLIGHT :: 2

Context :: struct {
	validation_layers_enabled: bool,
	
	drawable_width: int,
	drawable_height: int,
	
	instance: vk.Instance,
	physical_device: vk.PhysicalDevice,
	device: vk.Device,
	surface: vk.SurfaceKHR,
	
	swap_chain: Swap_Chain,
	queues: Queues,
	
	render_pass: vk.RenderPass,
	graphics_pipeline_layout: vk.PipelineLayout,
	graphics_pipeline: vk.Pipeline,
	reinit_graphics_pipeline: bool,

	command_pool: vk.CommandPool,
	command_buffers: [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,
	image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	in_flight_fences: [MAX_FRAMES_IN_FLIGHT]vk.Fence,
	
	current_frame: u32,
}

// Nilable u32 to store queue index
Queue_Index :: union{u32}

// Queue families the renderer requires to function
Queue_Family_Indices :: struct {
	graphics: Queue_Index,
	present: Queue_Index,
}

Queues :: struct {
	graphics: vk.Queue,
	present: vk.Queue,
}

QUEUE_FAMILY_COUNT :: 2

// Swap chain support on a device
Swap_Chain_Support :: struct {
	capabilities: vk.SurfaceCapabilitiesKHR,
	formats: [dynamic]vk.SurfaceFormatKHR,
	present_modes: [dynamic]vk.PresentModeKHR,
}

Swap_Chain :: struct {
	main: vk.SwapchainKHR,
	images: [dynamic]vk.Image,
	image_format: vk.Format,
	extent: vk.Extent2D,
	image_views: [dynamic]vk.ImageView,
	framebuffers: [dynamic]vk.Framebuffer,
}

@(private)
ctx: Context
