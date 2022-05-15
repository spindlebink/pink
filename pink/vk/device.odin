/*
Pink Vulkan Renderer: Device

Sets up the Vulkan instance and physical and logical devices.
*/

//+private
package pink_vk

import sdl "vendor:sdl2"
import vk "vendor:vulkan"

// Validation layers to add when requested. This defaults to whenever ODIN_DEBUG
// has been set (i.e. through `-debug` compiler flag).
VALIDATION_LAYERS :: []cstring {
	"VK_LAYER_KHRONOS_validation",
}

// Device extensions we need to load.
DEVICE_EXTENSIONS :: []cstring {
	vk.KHR_SWAPCHAIN_EXTENSION_NAME,
}

// Populated elsewhere based on SDL's required extensions
runtime_extensions: [dynamic]cstring

DEVICE_PRIORITY_UNSUPPORTED :: 0
DEVICE_PRIORITY_SUPPORTED :: 1
DEVICE_PRIORITY_DESIRABLE :: 2

/*
Initialize Instance

Initializes a Vulkan `vk.Instance`. Loads instance extensions from
`runtime_extensions`, which is populated on render initialization according to
`sdl.Vulkan_GetInstanceExtensions`.
*/

init_instance :: proc(ctx: ^Context) -> Response {
	create_info := vk.InstanceCreateInfo{
		sType = .INSTANCE_CREATE_INFO,
		pApplicationInfo = &vk.ApplicationInfo{
			sType = .APPLICATION_INFO,
		},
	}
	
	// Ensure all required extensions are supported, then add extension to the
	// `create_info`
	{
		supported_extension_count: u32
		vk.EnumerateInstanceExtensionProperties(nil, &supported_extension_count, nil)
		supported_extensions := make([]vk.ExtensionProperties, int(supported_extension_count)); defer delete(supported_extensions)
		vk.EnumerateInstanceExtensionProperties(nil, &supported_extension_count, raw_data(supported_extensions))
	
		for required_extension in &runtime_extensions {
			found := false
			for supported_extension in &supported_extensions {
				if (transmute(cstring) &supported_extension.extensionName) == required_extension {
					found = true
					break
				}
			}
			if !found do return .VULKAN_REQUIRED_EXTENSION_UNSUPPORTED
		}

		create_info.enabledExtensionCount = u32(len(runtime_extensions))
		create_info.ppEnabledExtensionNames = raw_data(runtime_extensions)
	}
	
	// Check validation layers and add if we're supposed to
	if ctx.validation_layers_enabled {
		layer_count: u32
		vk.EnumerateInstanceLayerProperties(&layer_count, nil)
		supported_layers := make([]vk.LayerProperties, int(layer_count)); defer delete(supported_layers)
		vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(supported_layers))

		for layer_name in VALIDATION_LAYERS {
			found := false
			for supported_layer in &supported_layers {
				if (transmute(cstring) &supported_layer.layerName) == layer_name {
					found = true
					break
				}
			}
			if !found do return .VULKAN_VALIDATION_LAYER_UNSUPPORTED
		}

		create_info.enabledLayerCount = u32(len(VALIDATION_LAYERS))
		create_info.ppEnabledLayerNames = raw_data(VALIDATION_LAYERS)
	} else {
		create_info.enabledLayerCount = 0
	}

	// Now try actually creating the instance
	result := vk.CreateInstance(&create_info, nil, &ctx.instance)
	if result != .SUCCESS do return .VULKAN_CREATE_INSTANCE_FAILED
	
	vk.load_proc_addresses(ctx.instance)
	return .OK
}

/*
Initialize Surface

Initializes a rendering surface from an SDL window.
*/

init_surface :: proc(ctx: ^Context, window: ^sdl.Window) -> Response {
	if !sdl.Vulkan_CreateSurface(window, ctx.instance, &ctx.surface) do return .SDL_VULKAN_CREATE_SURFACE_FAILED
	return .OK
}

/*
Select Physical Device

Selects a Vulkan-supported physical device for the renderer to use.
*/

select_physical_device :: proc(instance: vk.Instance) -> (vk.PhysicalDevice, Response) {
	device: vk.PhysicalDevice
	
	device_count: u32
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)
	if device_count == 0 do return device, Response.NO_VULKAN_SUPPORTED_DEVICE
	
	devices := make([]vk.PhysicalDevice, int(device_count)); defer delete(devices)
	vk.EnumeratePhysicalDevices(instance, &device_count, raw_data(devices))
	
	best_device_priority := 0
	for prospective_device in &devices {
		prospective_priority := get_physical_device_priority(prospective_device)
		if prospective_priority > best_device_priority {
			device = prospective_device
			best_device_priority = prospective_priority
		}
	}
	
	if best_device_priority == 0 {
		return device, Response.VULKAN_NO_SUITABLE_DEVICE
	} else {
		return device, Response.OK
	}
}

/*
Get Physical Device Priority

Calculates priority for a given physical device. Discrete GPUs are given the
highest priority. Returns 0 if the device doesn't support all required renderer
features.
*/

get_physical_device_priority :: proc(physical_device: vk.PhysicalDevice) -> int {
	device_queue_families := get_queue_family_indices(physical_device)
	if device_queue_families.graphics == nil || device_queue_families.present == nil {
		return DEVICE_PRIORITY_UNSUPPORTED
	}
	
	extensions_supported := check_device_extension_support(physical_device)
	if !extensions_supported {
		return DEVICE_PRIORITY_UNSUPPORTED
	}

	if extensions_supported {
		swap_chain_support := get_device_swap_chain_support(physical_device); defer destroy_swap_chain_support(swap_chain_support)
		if len(swap_chain_support.formats) == 0 || len(swap_chain_support.present_modes) == 0 {
			return DEVICE_PRIORITY_UNSUPPORTED
		}
	}
	
	device_properties: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(physical_device, &device_properties)
	if device_properties.deviceType == .DISCRETE_GPU {
		return DEVICE_PRIORITY_DESIRABLE
	} else {
		return DEVICE_PRIORITY_SUPPORTED
	}
}

/*
Check Device Extension Support

Checks whether a device supports all extensions listed in `DEVICE_EXTENSIONS`.
*/

check_device_extension_support :: proc(device: vk.PhysicalDevice) -> bool {
	extension_count: u32
	vk.EnumerateDeviceExtensionProperties(device, nil, &extension_count, nil)
	available_extensions := make([]vk.ExtensionProperties, int(extension_count)); defer delete(available_extensions)
	vk.EnumerateDeviceExtensionProperties(device, nil, &extension_count, raw_data(available_extensions))
	
	for required_extension in DEVICE_EXTENSIONS {
		found := false
		for available_extension in &available_extensions {
			if (transmute(cstring) &available_extension.extensionName) == required_extension {
				found = true
				break
			}
		}
		if !found do return false
	}
	
	return true
}

/*
Initialize Logical Device

Initializes a Vulkan logical device given a physical device.
*/

init_logical_device :: proc(ctx: ^Context) -> Response {
	queue_families := get_queue_family_indices(ctx.physical_device)

	queue_create_infos: [QUEUE_FAMILY_COUNT]vk.DeviceQueueCreateInfo
	queue_priorities: [QUEUE_FAMILY_COUNT]f32
	queue_indices := []u32{queue_families.graphics.(u32), queue_families.present.(u32)}
	
	for queue_family_index, i in queue_indices {
		queue_create_infos[i] = vk.DeviceQueueCreateInfo{
			sType = .DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = queue_family_index,
			queueCount = 1,
			pQueuePriorities = &queue_priorities[0],
		}
	}
	
	create_info := vk.DeviceCreateInfo{
		sType = .DEVICE_CREATE_INFO,
		queueCreateInfoCount = QUEUE_FAMILY_COUNT,
		pQueueCreateInfos = &queue_create_infos[0],
		pEnabledFeatures = &vk.PhysicalDeviceFeatures{},
		enabledExtensionCount = u32(len(DEVICE_EXTENSIONS)),
		ppEnabledExtensionNames = raw_data(DEVICE_EXTENSIONS),
	}
	
	if ctx.validation_layers_enabled {
		create_info.enabledLayerCount = u32(len(VALIDATION_LAYERS))
		create_info.ppEnabledLayerNames = raw_data(VALIDATION_LAYERS)
	}
	
	if vk.CreateDevice(ctx.physical_device, &create_info, nil, &ctx.device) != .SUCCESS do return .VULKAN_CREATE_DEVICE_FAILED
	
	vk.GetDeviceQueue(ctx.device, queue_families.graphics.(u32), 0, &ctx.queues.graphics)
	vk.GetDeviceQueue(ctx.device, queue_families.present.(u32), 0, &ctx.queues.present)
	
	return .OK
}

/*
Delete Instance

Cleans up logical device, physical device, surface, and Vulkan instance.
*/
delete_instance :: proc(ctx: ^Context) -> Response {
	vk.DestroySurfaceKHR(ctx.instance, ctx.surface, nil)
	vk.DestroyDevice(ctx.device, nil)
	vk.DestroyInstance(ctx.instance, nil)
	
	return .OK
}
