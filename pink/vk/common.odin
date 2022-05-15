/*
Pink Vulkan Renderer: Common

Vulkan querying and access methods used throughout the renderer. If a proc needs
to be regularly used in multiple files, it goes here.
*/

//+private
package pink_vk

import vk "vendor:vulkan"

/*
Get Queue Family Indices

Obtains required queue family indices from a physical device.
*/

get_queue_family_indices :: proc(device: vk.PhysicalDevice) -> Queue_Family_Indices {
	queue_families: Queue_Family_Indices

	queue_family_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, nil)
	device_queue_families := make([]vk.QueueFamilyProperties, int(queue_family_count)); defer delete(device_queue_families)
	vk.GetPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, raw_data(device_queue_families))
	
	for queue_family, index in &device_queue_families {
		// Assign graphics queue family if it's available and unassigned
		if .GRAPHICS in queue_family.queueFlags && queue_families.graphics == nil {
			queue_families.graphics = u32(index)
		}
		
		// Assign present queue family if it's available
		// Vulkan doesn't want us using the same index for multiple purposes so we
		// need to check for that as well
		if queue_families.graphics != nil && queue_families.graphics.(u32) != u32(index) {
			present_support: b32 = false
			vk.GetPhysicalDeviceSurfaceSupportKHR(device, u32(index), ctx.surface, &present_support)
			if present_support && queue_families.present == nil {
				queue_families.present = u32(index)
			}
		}
		
		if queue_families.graphics != nil && queue_families.present != nil {
			break
		}
	}
	
	return queue_families
}

/*
Get Device Swap Chain Support

Allocates and returns a `Swap_Chain_Support` based on the capabilities of a
physical device.
*/

get_device_swap_chain_support :: proc(device: vk.PhysicalDevice) -> Swap_Chain_Support {
	swap_chain_support: Swap_Chain_Support
	format_count: u32
	present_mode_count: u32
	
	vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(device, ctx.surface, &swap_chain_support.capabilities)

	vk.GetPhysicalDeviceSurfaceFormatsKHR(device, ctx.surface, &format_count, nil)
	if format_count > 0 {
		resize(&swap_chain_support.formats, int(format_count))
		vk.GetPhysicalDeviceSurfaceFormatsKHR(device, ctx.surface, &format_count, raw_data(swap_chain_support.formats))
	}

	vk.GetPhysicalDeviceSurfacePresentModesKHR(device, ctx.surface, &present_mode_count, nil)
	if present_mode_count > 0 {
		resize(&swap_chain_support.present_modes, int(present_mode_count))
		vk.GetPhysicalDeviceSurfacePresentModesKHR(device, ctx.surface, &format_count, raw_data(swap_chain_support.present_modes))
	}
	
	return swap_chain_support
}

/*
Destroy Swap Chain Support

Swap chain support structs have dynamic array members, so they need to be
properly freed when we're done using them.

TODO: Is there a way to initialize arrays on the stack with runtime lengths?
*/

destroy_swap_chain_support :: proc(swap_chain_support: Swap_Chain_Support) {
	delete(swap_chain_support.formats)
	delete(swap_chain_support.present_modes)
}
