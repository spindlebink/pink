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
	VULKAN_NO_SUPPORTED_GPU,
}
error_buf: [dynamic]Error

//****************************************************************************//
// Context Structure
//****************************************************************************//

VK_Queue_Index :: union {u32}

VK_Queue_Families :: struct {
	graphics: VK_Queue_Index,
}

VK_Context :: struct {
	instance: vk.Instance,
	physical_device: vk.PhysicalDevice,
	device: vk.Device,
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

	if !create_instance(window) {
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

	vk.DestroyInstance(ctx.instance, nil)

	log.debug("Vulkan renderer successfully destroyed.")
}

//****************************************************************************//
// Create Vulkan Instance
//****************************************************************************//

@(private)
create_instance :: proc(window: ^sdl.Window) -> (ok: bool = true) {
	log.debug("Creating Vulkan instance...")

	app_info: vk.ApplicationInfo
	app_info.sType = vk.StructureType.APPLICATION_INFO

	create_info: vk.InstanceCreateInfo
	create_info.sType = vk.StructureType.INSTANCE_CREATE_INFO
	create_info.pApplicationInfo = &app_info

	// Check required extensions and add them
	extension_count: u32
	sdl.Vulkan_GetInstanceExtensions(window, &extension_count, nil)
	instance_extensions := make([]cstring, int(extension_count)); defer delete(instance_extensions)
	sdl.Vulkan_GetInstanceExtensions(window, &extension_count, raw_data(instance_extensions))

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
			append(&error_buf, Error.VULKAN_NO_SUPPORTED_GPU)
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
			if device_queue_families.graphics != nil {
				log.debugf("Found %s", device_properties.deviceName)
				ctx.physical_device = device
				if device_properties.deviceType == .DISCRETE_GPU {
					log.debug("Discrete GPU, using it")
					break
				}
			}
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
	}

	return
}

//****************************************************************************//
// Create Logical Device
//****************************************************************************//

@(private)
create_logical_device :: proc() -> (ok: bool = true) {
	return
}
