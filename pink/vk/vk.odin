package pink_vk

import "core:c"
import "core:log"
import "core:os"
import "core:fmt"
import "core:math/bits"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"

Error :: enum{
	SDL_VULKAN_LOAD_FAILED,
	VULKAN_CREATE_INSTANCE_FAILED,
	VULKAN_REQUIRED_EXTENSION_UNSUPPORTED,
	VULKAN_VALIDATION_LAYER_UNSUPPORTED,
	NO_VULKAN_SUPPORTED_GPU,
	VULKAN_NO_SUITABLE_GPU,
	VULKAN_CREATE_DEVICE_FAILED,
	SDL_VULKAN_CREATE_SURFACE_FAILED,
	VULKAN_CREATE_SWAP_CHAIN_FAILED,
	VULKAN_CREATE_IMAGE_VIEW_FAILED,
	VULKAN_CREATE_SHADER_MODULE_FAILED,
	VULKAN_CREATE_RENDER_PASS_FAILED,
	VULKAN_CREATE_PIPELINE_LAYOUT_FAILED,
	VULKAN_CREATE_GRAPHICS_PIPELINES_FAILED,
	VULKAN_CREATE_FRAMEBUFFER_FAILED,
	VULKAN_CREATE_COMMAND_POOL_FAILED,
	VULKAN_ALLOCATE_COMMAND_BUFFERS_FAILED,
	VULKAN_BEGIN_COMMAND_BUFFER_FAILED,
	VULKAN_END_COMMAND_BUFFER_FAILED,
	VULKAN_CREATE_SYNC_OBJECTS_FAILED,
	VULKAN_QUEUE_SUBMIT_FAILED,
}
error_buf: [dynamic]Error

DEFAULT_VERTEX_SHADER_SPV :: "shader.vert.spv"
DEFAULT_FRAGMENT_SHADER_SPV :: "shader.frag.spv"

//****************************************************************************//
// Context Structure
//****************************************************************************//

VK_Context :: struct {
	window: ^sdl.Window,
	instance: vk.Instance,
	physical_device: vk.PhysicalDevice,
	device: vk.Device,
	surface: vk.SurfaceKHR,

	graphics_queue: vk.Queue,
	present_queue: vk.Queue,

	swap_chain: vk.SwapchainKHR,
	swap_chain_images: [dynamic]vk.Image,
	swap_chain_image_format: vk.Format,
	swap_chain_extent: vk.Extent2D,
	swap_chain_image_views: [dynamic]vk.ImageView,
	swap_chain_framebuffers: [dynamic]vk.Framebuffer,
	
	render_pass: vk.RenderPass,
	pipeline_layout: vk.PipelineLayout,
	graphics_pipeline: vk.Pipeline,

	command_pool: vk.CommandPool,
	command_buffer: vk.CommandBuffer,
	
	image_available_semaphore: vk.Semaphore,
	render_finished_semaphore: vk.Semaphore,
	in_flight_fence: vk.Fence,
}

VALIDATION_LAYERS: []cstring : {
	"VK_LAYER_KHRONOS_validation",
}

DEVICE_EXTENSIONS: []cstring : {
	vk.KHR_SWAPCHAIN_EXTENSION_NAME,
}

@(private)
ctx: VK_Context

//****************************************************************************//
// VK Data Structures & Helpers
//****************************************************************************//

// Queue family indices
VK_Queue_Families :: struct {
	graphics: VK_Queue_Index,
	present: VK_Queue_Index,
}

VK_Queue_Index :: union {u32}

QUEUE_FAMILY_COUNT :: 2

@(private)
required_queue_families_available :: proc(queue_families: VK_Queue_Families) -> bool {
	return queue_families.graphics != nil && queue_families.present != nil
}

// Swap chain support
VK_Swap_Chain_Support_Details :: struct {
	capabilities: vk.SurfaceCapabilitiesKHR,
	formats: [dynamic]vk.SurfaceFormatKHR,
	present_modes: [dynamic]vk.PresentModeKHR,
}

@(private)
query_swap_chain_support :: proc(device: vk.PhysicalDevice) -> (details: VK_Swap_Chain_Support_Details) {
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, ctx.surface, &details.capabilities)
	format_count: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(device, ctx.surface, &format_count, nil)
	if format_count != 0 {
		resize(&details.formats, int(format_count))
		vk.GetPhysicalDeviceSurfaceFormatsKHR(device, ctx.surface, &format_count, raw_data(details.formats))
	}
	present_mode_count: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(device, ctx.surface, &present_mode_count, nil)
	if present_mode_count != 0 {
		resize(&details.present_modes, int(present_mode_count))
		vk.GetPhysicalDeviceSurfacePresentModesKHR(device, ctx.surface, &present_mode_count, raw_data(details.present_modes))
	}
	return
}

@(private)
delete_swap_chain_data :: proc(swap_chain_support: VK_Swap_Chain_Support_Details) {
	delete(swap_chain_support.formats)
	delete(swap_chain_support.present_modes)
}

//****************************************************************************//
// Load
//****************************************************************************//

load :: proc() -> (ok := true) {
	log.debug("Loading Vulkan...")

	if sdl.Vulkan_LoadLibrary(nil) < 0 {
		fmt.eprintln("Couldn't load Vulkan library")
		append(&error_buf, Error.SDL_VULKAN_LOAD_FAILED)
		return false
	}
	
	vk.load_proc_addresses(sdl.Vulkan_GetVkGetInstanceProcAddr())

	log.debug("Vulkan successfully loaded.")
	return true
}

//****************************************************************************//
// Initialize
//****************************************************************************//

init :: proc(window: ^sdl.Window) -> (ok := true) {
	log.debug("Initializing Vulkan...")
	ctx.window = window

	if !create_instance() do return false

	if !sdl.Vulkan_CreateSurface(window, ctx.instance, &ctx.surface) {
		append(&error_buf, Error.SDL_VULKAN_CREATE_SURFACE_FAILED)
		return false
	}

	if !select_physical_device() do return false
	if !create_logical_device() do return false
	if !create_swap_chain() do return false
	if !create_image_views() do return false
	if !create_render_pass() do return false
	if !create_graphics_pipeline() do return false
	if !create_framebuffers() do return false
	if !create_command_pool() do return false
	if !create_command_buffer() do return false
	if !create_sync_objects() do return false
	
	log.debug("Vulkan successfully initialized.")
	return
}

//****************************************************************************//
// Draw Frame
//****************************************************************************//

draw_frame :: proc() -> (ok := true) {
	vk.WaitForFences(ctx.device, 1, &ctx.in_flight_fence, true, bits.U64_MAX)
	vk.ResetFences(ctx.device, 1, &ctx.in_flight_fence)
	
	image_index: u32
	vk.AcquireNextImageKHR(ctx.device, ctx.swap_chain, bits.U64_MAX, ctx.image_available_semaphore, 0, &image_index)
	vk.ResetCommandBuffer(ctx.command_buffer, {})
	record_command_buffer(ctx.command_buffer, image_index)
	
	submit_info: vk.SubmitInfo
	submit_info.sType = .SUBMIT_INFO

	wait_semaphores := []vk.Semaphore{ctx.image_available_semaphore}
	wait_stages := []vk.PipelineStageFlags{{.COLOR_ATTACHMENT_OUTPUT}}
	
	submit_info.waitSemaphoreCount = 1
	submit_info.pWaitSemaphores = raw_data(wait_semaphores)
	submit_info.pWaitDstStageMask = raw_data(wait_stages)
	
	submit_info.commandBufferCount = 1
	submit_info.pCommandBuffers = &ctx.command_buffer
	
	signal_semaphores := []vk.Semaphore{ctx.render_finished_semaphore}
	submit_info.signalSemaphoreCount = 1
	submit_info.pSignalSemaphores = raw_data(signal_semaphores)
	
	if vk.QueueSubmit(ctx.graphics_queue, 1, &submit_info, ctx.in_flight_fence) != .SUCCESS {
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
	
	return
}

//****************************************************************************//
// Destroy
//****************************************************************************//

destroy :: proc() {
	log.debug("Destroying Vulkan renderer...")

	vk.DeviceWaitIdle(ctx.device)
	
	vk.DestroySemaphore(ctx.device, ctx.image_available_semaphore, nil)
	vk.DestroySemaphore(ctx.device, ctx.render_finished_semaphore, nil)
	vk.DestroyFence(ctx.device, ctx.in_flight_fence, nil)
	vk.DestroyCommandPool(ctx.device, ctx.command_pool, nil)

	for framebuffer in ctx.swap_chain_framebuffers {
		vk.DestroyFramebuffer(ctx.device, framebuffer, nil)
	}
	
	vk.DestroyPipeline(ctx.device, ctx.graphics_pipeline, nil)
	vk.DestroyPipelineLayout(ctx.device, ctx.pipeline_layout, nil)
	vk.DestroyRenderPass(ctx.device, ctx.render_pass, nil)
	
	for image_view in ctx.swap_chain_image_views {
		vk.DestroyImageView(ctx.device, image_view, nil)
	}

	vk.DestroySwapchainKHR(ctx.device, ctx.swap_chain, nil)
	vk.DestroySurfaceKHR(ctx.instance, ctx.surface, nil)
	vk.DestroyDevice(ctx.device, nil)
	vk.DestroyInstance(ctx.instance, nil)
	delete(ctx.swap_chain_images)
	delete(ctx.swap_chain_image_views)
	delete(ctx.swap_chain_framebuffers)
	clear(&error_buf)

	log.debug("Vulkan renderer successfully destroyed.")
}

//****************************************************************************//
// Create Vulkan Instance
//****************************************************************************//

@(private)
create_instance :: proc() -> (ok := true) {
	log.debug("Creating Vulkan instance...")

	app_info: vk.ApplicationInfo
	app_info.sType = .APPLICATION_INFO

	create_info: vk.InstanceCreateInfo
	create_info.sType = .INSTANCE_CREATE_INFO
	create_info.pApplicationInfo = &app_info

	// Check required extensions and add them
	extension_count: u32
	sdl.Vulkan_GetInstanceExtensions(ctx.window, &extension_count, nil)
	instance_extensions := make([]cstring, int(extension_count)); defer delete(instance_extensions)
	sdl.Vulkan_GetInstanceExtensions(ctx.window, &extension_count, raw_data(instance_extensions))

	supported_extension_count: u32
	vk.EnumerateInstanceExtensionProperties(nil, &supported_extension_count, nil)
	supported_extensions := make([]vk.ExtensionProperties, int(supported_extension_count)); defer delete(supported_extensions)
	vk.EnumerateInstanceExtensionProperties(nil, &supported_extension_count, raw_data(supported_extensions))
	
	all_supported := true
	for required_extension in instance_extensions {
		found := false
		for supported_extension in &supported_extensions {
			if (transmute(cstring) &supported_extension.extensionName) == required_extension {
				found = true
				break
			}
		}
		all_supported &&= found
		log.debug("Require extension:", required_extension, "(", found ? "supported" : "NOT supported!", ")")
	}
	
	if !all_supported {
		append(&error_buf, Error.VULKAN_REQUIRED_EXTENSION_UNSUPPORTED)
		return false
	}
	
	create_info.enabledExtensionCount = extension_count
	create_info.ppEnabledExtensionNames = raw_data(instance_extensions)
	create_info.enabledLayerCount = 0
	
	// Check validation layers and add them if in debug mode
	when ODIN_DEBUG {
		log.debug("Checking validation layer support...")
		layer_count: u32
		vk.EnumerateInstanceLayerProperties(&layer_count, nil)
		supported_layers := make([]vk.LayerProperties, int(layer_count)); defer delete(supported_layers)
		vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(supported_layers))

		all_layers_supported := true
		for layer_name in VALIDATION_LAYERS {
			found := false
			for supported_layer in &supported_layers {
				if (transmute(cstring) &supported_layer.layerName) == layer_name {
					found = true
					break
				}
			}
			all_layers_supported &&= found
			log.debug("Validation layer:", layer_name, "(", found ? "supported" : "NOT supported!", ")")
			if !all_supported {
				append(&error_buf, Error.VULKAN_VALIDATION_LAYER_UNSUPPORTED)
				return false
			}
		}

		log.debug("All required validation layers are supported.")
		create_info.enabledLayerCount = u32(len(VALIDATION_LAYERS))
		create_info.ppEnabledLayerNames = raw_data(VALIDATION_LAYERS)
	}
	
	result := vk.CreateInstance(&create_info, nil, &ctx.instance)
	log.debug("Instance creation result", result)
	if result != .SUCCESS {
		append(&error_buf, Error.VULKAN_CREATE_INSTANCE_FAILED)
		return false
	}
	
	vk.load_proc_addresses(ctx.instance)
	log.debug("Vulkan instance successfully created.")
	return
}

//****************************************************************************//
// Select Physical Device
//****************************************************************************//

@(private)
select_physical_device :: proc() -> (ok := true) {
	log.debug("Selecting physical Vulkan device...")
	{
		device_count: u32
		vk.EnumeratePhysicalDevices(ctx.instance, &device_count, nil)
		if device_count == 0 {
			append(&error_buf, Error.NO_VULKAN_SUPPORTED_GPU)
			return false
		}
		devices := make([]vk.PhysicalDevice, int(device_count)); defer delete(devices)
		vk.EnumeratePhysicalDevices(ctx.instance, &device_count, raw_data(devices))
	
		for device in &devices {
			device_properties: vk.PhysicalDeviceProperties
			device_features: vk.PhysicalDeviceFeatures
			vk.GetPhysicalDeviceProperties(device, &device_properties)
			vk.GetPhysicalDeviceFeatures(device, &device_features)
			
			// Validate that the device is usable
			if can_use_physical_device(device) {
				log.debugf("Found %s", device_properties.deviceName)
				ctx.physical_device = device
				if device_properties.deviceType == .DISCRETE_GPU {
					log.debug("Discrete GPU, using it")
					break
				}
			}
		}
		
		if ctx.physical_device == nil {
			append(&error_buf, Error.VULKAN_NO_SUITABLE_GPU)
			return false
		}
	}
	log.debug("Physical Vulkan device good to go.")
	return
}

@(private)
can_use_physical_device :: proc(device: vk.PhysicalDevice) -> bool {
	device_queue_families := find_queue_families(device)
	extensions_supported := check_device_extension_support(device)
	swap_chain_supported := false
	if extensions_supported {
		swap_chain_support := query_swap_chain_support(device); defer delete_swap_chain_data(swap_chain_support)
		swap_chain_supported = len(swap_chain_support.formats) != 0 && len(swap_chain_support.present_modes) != 0
	}
	return required_queue_families_available(device_queue_families)  && extensions_supported && swap_chain_supported
}

@(private)
find_queue_families :: proc(device: vk.PhysicalDevice) -> (queue_families: VK_Queue_Families) {
	queue_family_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)
	device_queue_families := make([]vk.QueueFamilyProperties, int(queue_family_count)); defer delete(device_queue_families)
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, raw_data(device_queue_families))
	for queue_family, index in &device_queue_families {
		if .GRAPHICS in queue_family.queueFlags && queue_families.graphics == nil {
			queue_families.graphics = u32(index)
		}
		present_support: b32 = false
		vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(index), ctx.surface, &present_support)
		if present_support {
			queue_families.present = u32(index)
		}
	}
	return
}

@(private)
check_device_extension_support :: proc(device: vk.PhysicalDevice) -> bool {
	extension_count: u32
	vk.EnumerateDeviceExtensionProperties(device, nil, &extension_count, nil)
	available_extensions := make([]vk.ExtensionProperties, int(extension_count)); defer delete(available_extensions)
	vk.EnumerateDeviceExtensionProperties(device, nil, &extension_count, raw_data(available_extensions))
	all_available := true
	for required_extension in DEVICE_EXTENSIONS {
		found := false
		for available_extension in &available_extensions {
			if (transmute(cstring) &available_extension.extensionName) == required_extension {
				found = true
				break
			}
		}
		all_available &&= found
	}
	return all_available
}

//****************************************************************************//
// Create Logical Device
//****************************************************************************//

@(private)
create_logical_device :: proc() -> (ok := true) {
	log.debug("Creating logical Vulkan device...")
	queue_families := find_queue_families(ctx.physical_device)
	
	queue_create_infos := make([dynamic]vk.DeviceQueueCreateInfo, QUEUE_FAMILY_COUNT); defer delete(queue_create_infos)
	queue_priorities := make([]f32, QUEUE_FAMILY_COUNT); defer delete(queue_priorities)
	queue_indices: []u32 = {queue_families.graphics.(u32), queue_families.present.(u32)}
	
	for queue_family_index, index in queue_indices {
		queue_create_info: vk.DeviceQueueCreateInfo
		queue_create_info.sType = .DEVICE_QUEUE_CREATE_INFO
		queue_create_info.queueFamilyIndex = queue_family_index
		queue_create_info.queueCount = 1
		queue_create_info.pQueuePriorities = raw_data(queue_priorities)
		queue_create_infos[index] = queue_create_info
	}
	
	device_features: vk.PhysicalDeviceFeatures

	create_info: vk.DeviceCreateInfo
	create_info.sType = .DEVICE_CREATE_INFO
	create_info.queueCreateInfoCount = u32(len(queue_create_infos))
	create_info.pQueueCreateInfos = raw_data(queue_create_infos)
	create_info.pEnabledFeatures = &device_features
	create_info.enabledExtensionCount = u32(len(DEVICE_EXTENSIONS))
	create_info.ppEnabledExtensionNames = raw_data(DEVICE_EXTENSIONS)
	
	when ODIN_DEBUG {
		create_info.enabledLayerCount = u32(len(VALIDATION_LAYERS))
		create_info.ppEnabledLayerNames = raw_data(VALIDATION_LAYERS)
	} else {
		create_info.enabledLayerCount = 0
	}
	
	if vk.CreateDevice(ctx.physical_device, &create_info, nil, &ctx.device) != .SUCCESS {
		append(&error_buf, Error.VULKAN_CREATE_DEVICE_FAILED)
		return false
	}
	
	log.debug("Retrieving queue handles")
	vk.GetDeviceQueue(ctx.device, queue_families.graphics.(u32), 0, &ctx.graphics_queue)
	vk.GetDeviceQueue(ctx.device, queue_families.present.(u32), 0, &ctx.present_queue)
	
	log.debug("Logical Vulkan device good to go.")
	return
}

//****************************************************************************//
// Create Swap Chain
//****************************************************************************//

@(private)
create_swap_chain :: proc() -> (ok := true) {
	log.debug("Creating swap chain...")
	swap_chain_support := query_swap_chain_support(ctx.physical_device); defer delete_swap_chain_data(swap_chain_support)
	surface_format := choose_swap_surface_format(&swap_chain_support.formats)
	present_mode := choose_swap_present_mode(&swap_chain_support.present_modes)
	extent := choose_swap_extent(&swap_chain_support.capabilities)
	
	image_count := swap_chain_support.capabilities.minImageCount + 1
	if swap_chain_support.capabilities.maxImageCount > 0 && image_count > swap_chain_support.capabilities.maxImageCount {
		image_count = swap_chain_support.capabilities.maxImageCount
	}
	
	create_info: vk.SwapchainCreateInfoKHR
	create_info.sType = .SWAPCHAIN_CREATE_INFO_KHR
	create_info.surface = ctx.surface
	create_info.minImageCount = image_count
	create_info.imageFormat = surface_format.format
	create_info.imageColorSpace = surface_format.colorSpace
	create_info.imageExtent = extent
	create_info.imageArrayLayers = 1
	create_info.imageUsage = {.COLOR_ATTACHMENT}
	
	queue_families := find_queue_families(ctx.physical_device)
	queue_indices: []u32 = {queue_families.graphics.(u32), queue_families.present.(u32)}
	if queue_families.graphics != queue_families.present {
		create_info.imageSharingMode = .CONCURRENT
		create_info.queueFamilyIndexCount = QUEUE_FAMILY_COUNT
		create_info.pQueueFamilyIndices = raw_data(queue_indices)
	} else {
		create_info.imageSharingMode = .EXCLUSIVE
		create_info.queueFamilyIndexCount = 0
		create_info.pQueueFamilyIndices = nil
	}
	
	create_info.preTransform = swap_chain_support.capabilities.currentTransform
	create_info.compositeAlpha = {.OPAQUE}
	create_info.presentMode = present_mode
	create_info.clipped = true
	create_info.oldSwapchain = 0
	
	if vk.CreateSwapchainKHR(ctx.device, &create_info, nil, &ctx.swap_chain) != .SUCCESS {
		append(&error_buf, Error.VULKAN_CREATE_SWAP_CHAIN_FAILED)
		return false
	}
	
	vk.GetSwapchainImagesKHR(ctx.device, ctx.swap_chain, &image_count, nil)
	resize(&ctx.swap_chain_images, int(image_count))
	vk.GetSwapchainImagesKHR(ctx.device, ctx.swap_chain, &image_count, raw_data(ctx.swap_chain_images))

	ctx.swap_chain_image_format = surface_format.format
	ctx.swap_chain_extent = extent

	log.debug("Swap chain created successfully.")
	return
}

@(private)
choose_swap_surface_format :: proc(available_formats: ^[dynamic]vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
	for available_format in available_formats {
		if available_format.format == .B8G8R8A8_SRGB && available_format.colorSpace == .SRGB_NONLINEAR {
			return available_format
		}
	}
	return available_formats[0]
}

@(private)
choose_swap_present_mode :: proc(available_modes: ^[dynamic]vk.PresentModeKHR) -> vk.PresentModeKHR {
	for available_mode in available_modes {
		if available_mode == .MAILBOX {
			return available_mode
		}
	}
	return vk.PresentModeKHR.FIFO
}

@(private)
choose_swap_extent :: proc(capabilities: ^vk.SurfaceCapabilitiesKHR) -> vk.Extent2D {
	if capabilities.currentExtent.width != bits.U32_MAX {
		return capabilities.currentExtent
	} else {
		actual_extent: vk.Extent2D
		width, height: c.int
		sdl.Vulkan_GetDrawableSize(ctx.window, &width, &height)
		actual_extent.width = clamp(u32(width), capabilities.minImageExtent.width, capabilities.maxImageExtent.width)
		actual_extent.height = clamp(u32(height), capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
		return actual_extent
	}
}

//****************************************************************************//
// Create Image Views
//****************************************************************************//

@(private)
create_image_views :: proc() -> (ok := true) {
	log.debug("Creating swap chain image views...")
	resize(&ctx.swap_chain_image_views, len(ctx.swap_chain_images))
	
	for swap_chain_image, index in ctx.swap_chain_images {
		log.debugf("Creating swap chain image view #%d", index)
		create_info: vk.ImageViewCreateInfo
		create_info.sType = .IMAGE_VIEW_CREATE_INFO
		create_info.image = swap_chain_image
		create_info.viewType = .D2
		create_info.format = ctx.swap_chain_image_format
		create_info.components.r = .IDENTITY
		create_info.components.g = .IDENTITY
		create_info.components.b = .IDENTITY
		create_info.components.a = .IDENTITY
		create_info.subresourceRange.aspectMask = {.COLOR}
		create_info.subresourceRange.baseMipLevel = 0
		create_info.subresourceRange.levelCount = 1
		create_info.subresourceRange.baseArrayLayer = 0
		create_info.subresourceRange.layerCount = 1
		if vk.CreateImageView(ctx.device, &create_info, nil, &ctx.swap_chain_image_views[index]) != .SUCCESS {
			append(&error_buf, Error.VULKAN_CREATE_IMAGE_VIEW_FAILED)
			return false
		}
	}

	log.debug("Swap chain image views created successfully.")
	return
}

//****************************************************************************//
// Create Render Pass
//****************************************************************************//

@(private)
create_render_pass :: proc() -> (ok := true) {
	log.debug("Creating render pass...")
	color_attachment: vk.AttachmentDescription
	color_attachment.format = ctx.swap_chain_image_format
	color_attachment.samples = {._1}
	color_attachment.loadOp = .CLEAR
	color_attachment.storeOp = .STORE
	color_attachment.stencilLoadOp = .DONT_CARE
	color_attachment.stencilStoreOp = .DONT_CARE
	color_attachment.initialLayout = .UNDEFINED
	color_attachment.finalLayout = .PRESENT_SRC_KHR
	
	color_attachment_ref: vk.AttachmentReference
	color_attachment_ref.attachment = 0
	color_attachment_ref.layout = .COLOR_ATTACHMENT_OPTIMAL
	
	subpass: vk.SubpassDescription
	subpass.pipelineBindPoint = .GRAPHICS
	subpass.colorAttachmentCount = 1
	subpass.pColorAttachments = &color_attachment_ref
	
	render_pass_info: vk.RenderPassCreateInfo
	render_pass_info.sType = .RENDER_PASS_CREATE_INFO
	render_pass_info.attachmentCount = 1
	render_pass_info.pAttachments = &color_attachment
	render_pass_info.subpassCount = 1
	render_pass_info.pSubpasses = &subpass
	
	dependency: vk.SubpassDependency
	dependency.srcSubpass = vk.SUBPASS_EXTERNAL
	dependency.dstSubpass = 0
	dependency.srcStageMask = {.COLOR_ATTACHMENT_OUTPUT}
	dependency.srcAccessMask = {}
	dependency.dstStageMask = {.COLOR_ATTACHMENT_OUTPUT}
	dependency.dstAccessMask = {.COLOR_ATTACHMENT_WRITE}
	
	render_pass_info.dependencyCount = 1
	render_pass_info.pDependencies = &dependency
	
	if vk.CreateRenderPass(ctx.device, &render_pass_info, nil, &ctx.render_pass) != .SUCCESS {
		append(&error_buf, Error.VULKAN_CREATE_RENDER_PASS_FAILED)
		return false
	}

	log.debug("Render pass created successfully.")
	return
}

//****************************************************************************//
// Create Graphics Pipeline
//****************************************************************************//

@(private)
create_graphics_pipeline :: proc() -> (ok := true) {
	log.debug("Creating graphics pipeline...")
	
	vertex_shader_module, fragment_shader_module: vk.ShaderModule
	vertex_module_created, fragment_module_created: bool
	log.debug("Loading vertex shader...")
	if !create_shader_module(&vertex_shader_module, #load(DEFAULT_VERTEX_SHADER_SPV)) {
		append(&error_buf, Error.VULKAN_CREATE_SHADER_MODULE_FAILED)
		return false
	}

	log.debug("Loading fragment shader...")
	if !create_shader_module(&fragment_shader_module, #load(DEFAULT_FRAGMENT_SHADER_SPV)) {
		append(&error_buf, Error.VULKAN_CREATE_SHADER_MODULE_FAILED)
		return false
	}
	
	vert_stage_info: vk.PipelineShaderStageCreateInfo
	vert_stage_info.sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	vert_stage_info.stage = {.VERTEX}
	vert_stage_info.module = vertex_shader_module
	vert_stage_info.pName = "main"
	
	frag_stage_info: vk.PipelineShaderStageCreateInfo
	frag_stage_info.sType = .PIPELINE_SHADER_STAGE_CREATE_INFO
	frag_stage_info.stage = {.FRAGMENT}
	frag_stage_info.module = fragment_shader_module
	frag_stage_info.pName = "main"
	
	shader_stages: []vk.PipelineShaderStageCreateInfo = {vert_stage_info, frag_stage_info}
	
	vert_input_info: vk.PipelineVertexInputStateCreateInfo
	vert_input_info.sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO
	vert_input_info.vertexBindingDescriptionCount = 0
	vert_input_info.vertexAttributeDescriptionCount = 0
	
	input_assembly: vk.PipelineInputAssemblyStateCreateInfo
	input_assembly.sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO
	input_assembly.topology = .TRIANGLE_LIST
	input_assembly.primitiveRestartEnable = false
	
	viewport: vk.Viewport
	viewport.x, viewport.y = 0.0, 0.0
	viewport.width, viewport.height = f32(ctx.swap_chain_extent.width), f32(ctx.swap_chain_extent.height)
	viewport.minDepth, viewport.maxDepth = 0.0, 1.0
	
	scissor: vk.Rect2D
	scissor.offset = {0, 0}
	scissor.extent = ctx.swap_chain_extent
	
	viewport_state: vk.PipelineViewportStateCreateInfo
	viewport_state.sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO
	viewport_state.viewportCount = 1
	viewport_state.pViewports = &viewport
	viewport_state.scissorCount = 1
	viewport_state.pScissors = &scissor
	
	rasterizer: vk.PipelineRasterizationStateCreateInfo
	rasterizer.sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO
	rasterizer.depthClampEnable = false
	rasterizer.rasterizerDiscardEnable = false
	rasterizer.polygonMode = .FILL
	rasterizer.lineWidth = 1.0
	rasterizer.cullMode = {.BACK}
	rasterizer.frontFace = .CLOCKWISE
	rasterizer.depthBiasEnable = false
	rasterizer.depthBiasConstantFactor = 0.0
	rasterizer.depthBiasClamp = 0.0
	rasterizer.depthBiasSlopeFactor = 0.0
	
	multisampling: vk.PipelineMultisampleStateCreateInfo
	multisampling.sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO
	multisampling.sampleShadingEnable = false
	multisampling.rasterizationSamples = {._1}
	multisampling.minSampleShading = 1.0
	multisampling.pSampleMask = nil
	multisampling.alphaToCoverageEnable = false
	multisampling.alphaToOneEnable = false
	
	color_blend_attachment: vk.PipelineColorBlendAttachmentState
	color_blend_attachment.colorWriteMask = {.R, .G, .B, .A}
	color_blend_attachment.blendEnable = false
	color_blend_attachment.srcColorBlendFactor = .SRC_ALPHA
	color_blend_attachment.dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA
	color_blend_attachment.colorBlendOp = .ADD
	color_blend_attachment.srcAlphaBlendFactor = .ONE
	color_blend_attachment.dstAlphaBlendFactor = .ZERO
	color_blend_attachment.alphaBlendOp = .ADD
	
	color_blending: vk.PipelineColorBlendStateCreateInfo
	color_blending.sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO
	color_blending.logicOpEnable = false
	color_blending.logicOp = .COPY
	color_blending.attachmentCount = 1
	color_blending.pAttachments = &color_blend_attachment
	color_blending.blendConstants[0] = 0.0
	color_blending.blendConstants[1] = 0.0
	color_blending.blendConstants[2] = 0.0
	color_blending.blendConstants[3] = 0.0
	
	dynamic_states: []vk.DynamicState = {.VIEWPORT, .LINE_WIDTH}
	dynamic_state: vk.PipelineDynamicStateCreateInfo
	dynamic_state.sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO
	dynamic_state.dynamicStateCount = u32(len(dynamic_states))
	dynamic_state.pDynamicStates = raw_data(dynamic_states)
	
	pipeline_layout_info: vk.PipelineLayoutCreateInfo
	pipeline_layout_info.sType = .PIPELINE_LAYOUT_CREATE_INFO
	pipeline_layout_info.setLayoutCount = 0
	pipeline_layout_info.pSetLayouts = nil
	pipeline_layout_info.pushConstantRangeCount = 0
	pipeline_layout_info.pPushConstantRanges = nil
	
	if vk.CreatePipelineLayout(ctx.device, &pipeline_layout_info, nil, &ctx.pipeline_layout) != .SUCCESS {
		append(&error_buf, Error.VULKAN_CREATE_PIPELINE_LAYOUT_FAILED)
		return false
	}
	
	pipeline_info: vk.GraphicsPipelineCreateInfo
	pipeline_info.sType = .GRAPHICS_PIPELINE_CREATE_INFO
	pipeline_info.stageCount = u32(len(shader_stages))
	pipeline_info.pStages = raw_data(shader_stages)
	pipeline_info.pVertexInputState = &vert_input_info
	pipeline_info.pInputAssemblyState = &input_assembly
	pipeline_info.pViewportState = &viewport_state
	pipeline_info.pRasterizationState = &rasterizer
	pipeline_info.pMultisampleState = &multisampling
	pipeline_info.pDepthStencilState = nil
	pipeline_info.pColorBlendState = &color_blending
	pipeline_info.pDynamicState = nil
	pipeline_info.layout = ctx.pipeline_layout
	pipeline_info.renderPass = ctx.render_pass
	pipeline_info.subpass = 0
	pipeline_info.basePipelineHandle = 0
	pipeline_info.basePipelineIndex = -1
	
	if vk.CreateGraphicsPipelines(ctx.device, 0, 1, &pipeline_info, nil, &ctx.graphics_pipeline) != .SUCCESS {
		append(&error_buf, Error.VULKAN_CREATE_GRAPHICS_PIPELINES_FAILED)
		return false
	}

	vk.DestroyShaderModule(ctx.device, fragment_shader_module, nil)
	vk.DestroyShaderModule(ctx.device, vertex_shader_module, nil)
	log.debug("Graphics pipeline created successfully.")
	return
}

@(private)
create_shader_module :: proc(shader_module: ^vk.ShaderModule, code: []u8) -> (ok := true) {
	log.debug("Creating shader module...")
	create_info: vk.ShaderModuleCreateInfo
	create_info.sType = .SHADER_MODULE_CREATE_INFO
	create_info.codeSize = len(code)
	create_info.pCode = cast(^u32) raw_data(code)
	
	if vk.CreateShaderModule(ctx.device, &create_info, nil, shader_module) != .SUCCESS {
		return false
	}
	
	log.debug("Shader module created successfully.")
	return
}

//****************************************************************************//
// Create Framebuffers
//****************************************************************************//

@(private)
create_framebuffers :: proc() -> (ok := true) {
	log.debug("Creating framebuffers...")
	resize(&ctx.swap_chain_framebuffers, len(ctx.swap_chain_image_views))
	
	for image_view, index in &ctx.swap_chain_image_views {
		attachments := []vk.ImageView{image_view}
		
		framebuffer_info: vk.FramebufferCreateInfo
		framebuffer_info.sType = .FRAMEBUFFER_CREATE_INFO
		framebuffer_info.renderPass = ctx.render_pass
		framebuffer_info.attachmentCount = 1
		framebuffer_info.pAttachments = raw_data(attachments)
		framebuffer_info.width = ctx.swap_chain_extent.width
		framebuffer_info.height = ctx.swap_chain_extent.height
		framebuffer_info.layers = 1
		
		if vk.CreateFramebuffer(ctx.device, &framebuffer_info, nil, &ctx.swap_chain_framebuffers[index]) != .SUCCESS {
			append(&error_buf, Error.VULKAN_CREATE_FRAMEBUFFER_FAILED)
			return false
		}
	}
	
	log.debug("Framebuffers created successfully.")
	return
}

//****************************************************************************//
// Create Command Pool
//****************************************************************************//

@(private)
create_command_pool :: proc() -> (ok := true) {
	log.debug("Creating command pool...")
	
	queue_family_indices := find_queue_families(ctx.physical_device)
	pool_info: vk.CommandPoolCreateInfo
	pool_info.sType = .COMMAND_POOL_CREATE_INFO
	pool_info.flags = {.RESET_COMMAND_BUFFER}
	pool_info.queueFamilyIndex = queue_family_indices.graphics.(u32)
	
	if vk.CreateCommandPool(ctx.device, &pool_info, nil, &ctx.command_pool) != .SUCCESS {
		append(&error_buf, Error.VULKAN_CREATE_COMMAND_POOL_FAILED)
		return false
	}
	
	log.debug("Command pool created successfully.")
	return
}

//****************************************************************************//
// Create Command Buffer
//****************************************************************************//

@(private)
create_command_buffer :: proc() -> (ok := true) {
	log.debug("Creating command buffer...")
	
	alloc_info: vk.CommandBufferAllocateInfo
	alloc_info.sType = .COMMAND_BUFFER_ALLOCATE_INFO
	alloc_info.commandPool = ctx.command_pool
	alloc_info.level = .PRIMARY
	alloc_info.commandBufferCount = 1
	
	if vk.AllocateCommandBuffers(ctx.device, &alloc_info, &ctx.command_buffer) != .SUCCESS {
		append(&error_buf, Error.VULKAN_ALLOCATE_COMMAND_BUFFERS_FAILED)
		return false
	}
	
	log.debug("Command buffer created successfully.")
	return
}

//****************************************************************************//
// Record Command Buffer
//****************************************************************************//

@(private)
record_command_buffer :: proc(command_buffer: vk.CommandBuffer, image_index: u32) -> (ok := true) {
	begin_info: vk.CommandBufferBeginInfo
	begin_info.sType = .COMMAND_BUFFER_BEGIN_INFO
	begin_info.flags = {}
	begin_info.pInheritanceInfo = nil
	
	if vk.BeginCommandBuffer(command_buffer, &begin_info) != .SUCCESS {
		append(&error_buf, Error.VULKAN_BEGIN_COMMAND_BUFFER_FAILED)
		return false
	}
	
	render_pass_info: vk.RenderPassBeginInfo
	render_pass_info.sType = .RENDER_PASS_BEGIN_INFO
	render_pass_info.renderPass = ctx.render_pass
	render_pass_info.framebuffer = ctx.swap_chain_framebuffers[image_index]
	render_pass_info.renderArea.offset = {0, 0}
	render_pass_info.renderArea.extent = ctx.swap_chain_extent
	
	clear_color := vk.ClearValue{color = vk.ClearColorValue{float32 = {0.0, 0.0, 0.0, 1.0}}}
	render_pass_info.clearValueCount = 1
	render_pass_info.pClearValues = &clear_color
	
	vk.CmdBeginRenderPass(command_buffer, &render_pass_info, .INLINE)
	vk.CmdBindPipeline(command_buffer, .GRAPHICS, ctx.graphics_pipeline)
	vk.CmdDraw(command_buffer, 3, 1, 0, 0)
	vk.CmdEndRenderPass(command_buffer)
	
	if vk.EndCommandBuffer(command_buffer) != .SUCCESS {
		append(&error_buf, Error.VULKAN_END_COMMAND_BUFFER_FAILED)
		return false
	}

	return
}

//****************************************************************************//
// Create Sync Objects
//****************************************************************************//

@(private)
create_sync_objects :: proc() -> (ok := true) {
	semaphore_info: vk.SemaphoreCreateInfo
	semaphore_info.sType = .SEMAPHORE_CREATE_INFO
	
	fence_info: vk.FenceCreateInfo
	fence_info.sType = .FENCE_CREATE_INFO
	fence_info.flags = {.SIGNALED}
	
	if vk.CreateSemaphore(ctx.device, &semaphore_info, nil, &ctx.image_available_semaphore) != .SUCCESS ||
		 vk.CreateSemaphore(ctx.device, &semaphore_info, nil, &ctx.render_finished_semaphore) != .SUCCESS ||
		 vk.CreateFence(ctx.device, &fence_info, nil, &ctx.in_flight_fence) != .SUCCESS {
		append(&error_buf, Error.VULKAN_CREATE_SYNC_OBJECTS_FAILED)
		return false
	}
	
	return
}

