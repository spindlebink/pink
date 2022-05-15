/*
Pink Vulkan Renderer: Init

The forward-facing initialization and lifetime API for the renderer.
*/

package pink_vk

import "core:c"
import sdl "vendor:sdl2"
import vk "vendor:vulkan"

/*
Load Renderer

Loads the renderer to an initializable state. Uses SDL to load Vulkan.
*/

load :: proc() -> Response {
	if sdl.Vulkan_LoadLibrary(nil) < 0 do return .SDL_VULKAN_LOAD_LIBRARY_FAILED
	vk.load_proc_addresses(sdl.Vulkan_GetVkGetInstanceProcAddr())
	return .OK
}

/*
Initialize Renderer

Initializes the renderer on an SDL window.
*/

init :: proc(window: ^sdl.Window) -> Response {
	ctx.validation_layers_enabled = ODIN_DEBUG
	
	extension_count: u32
	sdl.Vulkan_GetInstanceExtensions(window, &extension_count, nil)
	resize(&runtime_extensions, int(extension_count))
	sdl.Vulkan_GetInstanceExtensions(window, &extension_count, raw_data(runtime_extensions))
	
	width, height: c.int
	sdl.Vulkan_GetDrawableSize(window, &width, &height)
	ctx.drawable_width, ctx.drawable_height = int(width), int(height)
	
	response := Response.OK

	append(&ctx.vertices, Vertex{{0.0, -0.5}, {1.0, 0.0, 0.0}})
	append(&ctx.vertices, Vertex{{0.5, 0.5}, {0.0, 1.0, 0.0}})
	append(&ctx.vertices, Vertex{{-0.5, 0.5}, {0.0, 0.0, 1.0}})
	
	if response = init_instance(&ctx); response != .OK do return response
	if response = init_surface(&ctx, window); response != .OK do return response
	if ctx.physical_device, response = select_physical_device(ctx.instance); response != .OK do return response
	if response = init_logical_device(&ctx); response != .OK do return response
	if response = init_pipeline(&ctx); response != .OK do return response
	if response = init_runtime(&ctx); response != .OK do return response

	return response
}

/*
Destroy Renderer

Destroys the renderer. The renderer currently supports only one lifetime
instance, so destruction of the renderer should only happen at the very end of
a program.
*/

destroy :: proc() -> Response {
	vk.DeviceWaitIdle(ctx.device)
	response := Response.OK
	
	if response = delete_runtime(&ctx); response != .OK do return response
	if response = delete_pipeline(&ctx); response != .OK do return response
	if response = delete_instance(&ctx); response != .OK do return response
	
	clear(&runtime_extensions)
	delete(runtime_extensions)
	delete(ctx.vertices)

	return response
}

/*
Draw Frame

Draws a frame.
*/

draw :: proc() -> Response {
	return render_frame(&ctx)
}

/*
Handle Resize

Invalidates the pipeline when the window changes size.
*/

handle_resize :: proc() -> Response {
	ctx.reinit_graphics_pipeline = true
	return .OK
}
