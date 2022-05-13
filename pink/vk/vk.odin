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
}
error_buf: [dynamic]Error

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

load :: proc() -> (ok: bool = true) {
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

init :: proc(window: ^sdl.Window) -> (ok: bool = true) {
	log.debug("Initializing Vulkan...")
	ctx.window = window

	if !create_instance() {
		return false
	}

	if !sdl.Vulkan_CreateSurface(window, ctx.instance, &ctx.surface) {
		append(&error_buf, Error.SDL_VULKAN_CREATE_SURFACE_FAILED)
		return false
	}

	if !select_physical_device() {
		return false
	}
	
	if !create_logical_device() {
		return false
	}
	
	if !create_swap_chain() {
		return false
	}
	
	log.debug("Vulkan successfully initialized.")
	return
}

//****************************************************************************//
// Destroy
//****************************************************************************//

destroy :: proc() {
	log.debug("Destroying Vulkan renderer...")

	vk.DestroySwapchainKHR(ctx.device, ctx.swap_chain, nil)
	vk.DestroySurfaceKHR(ctx.instance, ctx.surface, nil)
	vk.DestroyDevice(ctx.device, nil)
	vk.DestroyInstance(ctx.instance, nil)
	delete(ctx.swap_chain_images)
	clear(&error_buf)

	log.debug("Vulkan renderer successfully destroyed.")
}

//****************************************************************************//
// Create Vulkan Instance
//****************************************************************************//

@(private)
create_instance :: proc() -> (ok: bool = true) {
	log.debug("Creating Vulkan instance...")

	app_info: vk.ApplicationInfo
	app_info.sType = vk.StructureType.APPLICATION_INFO

	create_info: vk.InstanceCreateInfo
	create_info.sType = vk.StructureType.INSTANCE_CREATE_INFO
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
select_physical_device :: proc() -> (ok: bool = true) {
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
create_logical_device :: proc() -> (ok: bool = true) {
	log.debug("Creating logical Vulkan device...")
	queue_families := find_queue_families(ctx.physical_device)
	
	queue_create_infos := make([dynamic]vk.DeviceQueueCreateInfo, QUEUE_FAMILY_COUNT); defer delete(queue_create_infos)
	queue_priorities := make([]f32, QUEUE_FAMILY_COUNT); defer delete(queue_priorities)
	queue_indices: []u32 = {queue_families.graphics.(u32), queue_families.present.(u32)}
	
	for queue_family_index, index in queue_indices {
		queue_create_info: vk.DeviceQueueCreateInfo
		queue_create_info.sType = vk.StructureType.DEVICE_QUEUE_CREATE_INFO
		queue_create_info.queueFamilyIndex = queue_family_index
		queue_create_info.queueCount = 1
		queue_create_info.pQueuePriorities = raw_data(queue_priorities)
		queue_create_infos[index] = queue_create_info
	}
	
	device_features: vk.PhysicalDeviceFeatures

	create_info: vk.DeviceCreateInfo
	create_info.sType = vk.StructureType.DEVICE_CREATE_INFO
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
create_swap_chain :: proc() -> (ok: bool = true) {
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
	create_info.sType = vk.StructureType.SWAPCHAIN_CREATE_INFO_KHR
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
