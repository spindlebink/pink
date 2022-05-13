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
}
error_buf: [dynamic]Error

//****************************************************************************//
// Context Structure
//****************************************************************************//

VK_Context :: struct {
	instance: vk.Instance,
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
	using ctx
	log.debug("Initializing Vulkan...")

	if !create_instance(window) {
		return false
	}

	log.debug("Vulkan successfully initialized.")
	return true
}

//****************************************************************************//
// Destroy
//****************************************************************************//

destroy :: proc() {
	using ctx
	log.debug("Destroying Vulkan renderer...")

	vk.DestroyInstance(instance, nil)

	log.debug("Vulkan renderer successfully destroyed.")
}

//****************************************************************************//
// Create Vulkan Instance
//****************************************************************************//

@(private)
create_instance :: proc(window: ^sdl.Window) -> (ok: bool = true) {
	using ctx
	log.debug("Creating Vulkan instance...")

	app_info: vk.ApplicationInfo
	app_info.sType = vk.StructureType.APPLICATION_INFO

	create_info: vk.InstanceCreateInfo
	create_info.sType = vk.StructureType.INSTANCE_CREATE_INFO
	create_info.pApplicationInfo = &app_info

	// Check required extensions and add them
	extension_count: u32
	sdl.Vulkan_GetInstanceExtensions(window, &extension_count, nil)
	instance_extensions: [dynamic]cstring; defer delete(instance_extensions)
	resize(&instance_extensions, int(extension_count))
	sdl.Vulkan_GetInstanceExtensions(window, &extension_count, raw_data(instance_extensions))

	supported_extension_count: u32
	vk.EnumerateInstanceExtensionProperties(nil, &supported_extension_count, nil)
	supported_extensions: [dynamic]vk.ExtensionProperties; defer delete(supported_extensions)
	resize(&supported_extensions, int(supported_extension_count))
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
		supported_layers: [dynamic]vk.LayerProperties; defer delete(supported_layers)
		resize(&supported_layers, int(layer_count))
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
	
	result := vk.CreateInstance(&create_info, nil, &instance)
	log.debug("Instance creation result", result)
	if result != .SUCCESS {
		append(&error_buf, Error.VULKAN_CREATE_INSTANCE_FAILED)
		return false
	}
	
	vk.load_proc_addresses(instance)
	
	
	log.debug("Vulkan instance successfully created.")
	return true
}
