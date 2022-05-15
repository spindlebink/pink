/*
Pink Vulkan Renderer: Types

Main renderer context struct and associated types.
*/

package pink_vk

import "core:math/linalg/glsl"
import vk "vendor:vulkan"

MAX_FRAMES_IN_FLIGHT :: 2

/*
Context

Global rendering context.
*/

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

	vertices: [dynamic]Vertex,
	vertex_buffer: vk.Buffer,
	vertex_buffer_memory: vk.DeviceMemory,
}

// Global context instance
@(private)
ctx: Context

/*
Queue Index, Queue Family Indices, and Queues

* Nilable u32 to store a single queue index
* Structure to hold each queue we need for a renderer
* Structure to hold Vulkan queue references corresponding to selected indices
*/

QUEUE_FAMILY_COUNT :: 2

Queue_Index :: union{u32}

Queue_Family_Indices :: struct {
	graphics: Queue_Index,
	present: Queue_Index,
}

Queues :: struct {
	graphics: vk.Queue,
	present: vk.Queue,
}

/*
Swap Chain Support and Swap Chain

* Structure to hold capabilities, formats, and present modes from Vulkan
* Render context's swap chain information--the `SwapchainKHR`, images, views,
  framebuffers, and everything else that's part of the swap chain state
*/

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

/*
Vertex

A vertex which can be sent to the GPU.
*/

Vertex :: struct {
	pos: glsl.vec2,
	color: glsl.vec3,
}

VERTEX_INPUT_BINDING_DESCRIPTION :: vk.VertexInputBindingDescription{
	binding = 0,
	stride = size_of(Vertex),
	inputRate = .VERTEX,
}

VERTEX_INPUT_ATTRIBUTE_DESCRIPTIONS :: [2]vk.VertexInputAttributeDescription{
	{
		binding = 0,
		location = 0,
		format = .R32G32_SFLOAT,
		offset = u32(offset_of(Vertex, pos)),
	},
	{
		binding = 0,
		location = 1,
		format = .R32G32B32_SFLOAT,
		offset = u32(offset_of(Vertex, color)),
	},
}
