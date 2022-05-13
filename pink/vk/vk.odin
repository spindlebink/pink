package pink_vk

import "core:log"
import "core:os"
import "core:fmt"
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
}
error_buf: [dynamic]Error

//****************************************************************************//
// Context Structure
//****************************************************************************//

VK_Queue_Index :: union {u32}

VK_Queue_Families :: struct {
	graphics: VK_Queue_Index,
	present: VK_Queue_Index,
}

VK_Context :: struct {
	window: ^sdl.Window,
	instance: vk.Instance,
	physical_device: vk.PhysicalDevice,
	device: vk.Device,
	surface: vk.SurfaceKHR,
	graphics_queue: vk.Queue,
	present_queue: vk.Queue,
}

validation_layers: []cstring : {
	"VK_LAYER_KHRONOS_validation",
}

@(private)
ctx: VK_Context

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

	log.debug("Vulkan successfully initialized.")
	return
}

//****************************************************************************//
// Destroy
//****************************************************************************//

destroy :: proc() {
	log.debug("Destroying Vulkan renderer...")

	vk.DestroySurfaceKHR(ctx.instance, ctx.surface, nil)
	vk.DestroyDevice(ctx.device, nil)
	vk.DestroyInstance(ctx.instance, nil)
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
		for layer_name in validation_layers {
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
		create_info.enabledLayerCount = u32(len(validation_layers))
		create_info.ppEnabledLayerNames = raw_data(validation_layers)
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
			device_queue_families := find_queue_families(device)
			if device_queue_families.graphics != nil && device_queue_families.present != nil {
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

//****************************************************************************//
// Create Logical Device
//****************************************************************************//

@(private)
create_logical_device :: proc() -> (ok: bool = true) {
	log.debug("Creating logical Vulkan device...")
	queue_families := find_queue_families(ctx.physical_device)
	
	queue_create_infos := make([dynamic]vk.DeviceQueueCreateInfo, 2); defer delete(queue_create_infos)
	queue_priorities := make([]f32, 2); defer delete(queue_priorities)
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
	create_info.enabledExtensionCount = 0
	
	when ODIN_DEBUG {
		create_info.enabledLayerCount = u32(len(validation_layers))
		create_info.ppEnabledLayerNames = raw_data(validation_layers)
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
