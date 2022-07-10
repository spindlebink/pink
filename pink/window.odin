package pink

import "core:c"
import "core:fmt"
import sdl "vendor:sdl2"
import "render/wgpu"

// Window information.
Window :: struct {
	title: string,
	width: int,
	height: int,
	minimized: bool,

	core: Window_Core,
}

Window_Core :: struct {
	sdl_handle: ^sdl.Window,
	sdl_flags: sdl.WindowFlags,
}

// Initializes the game window.
_window_init :: proc(
	window: ^Window,
) -> bool {
	when ODIN_OS == .Linux {
		// TODO: do we actually need this? WGPU initializes regardless. More research.
		window.core.sdl_flags += {.VULKAN}
	}
	
	window.core.sdl_handle = sdl.CreateWindow(
		cast(cstring) raw_data(window.title),
		sdl.WINDOWPOS_UNDEFINED,
		sdl.WINDOWPOS_UNDEFINED,
		i32(window.width),
		i32(window.height),
		window.core.sdl_flags,
	)
	
	if window.core.sdl_handle == nil {
		fmt.eprintln("Failed to create window")
		return false
	}

	_window_fetch_info(window)
	
	return true
}

// Destroys the game window.
_window_destroy :: proc(
	window: ^Window,
) -> bool {
	delete(window.title)
	sdl.DestroyWindow(window.core.sdl_handle)
	
	return true
}

// Updates window information.
_window_fetch_info :: proc(
	window: ^Window,
) {
	w, h: i32
	window.core.sdl_flags =
		transmute(sdl.WindowFlags)sdl.GetWindowFlags(window.core.sdl_handle)
	sdl.GetWindowSize(window.core.sdl_handle, &w, &h)
	window.width, window.height = int(w), int(h)
	window.minimized = .MINIMIZED in window.core.sdl_flags
}

// Obtains a WGPU surface from an initialized window.
_window_create_wgpu_surface :: proc(
	window: ^Window,
) -> (wgpu.Surface, bool) {
	surf: wgpu.Surface

	when ODIN_OS == .Linux {
		wm_info: sdl.SysWMinfo
		sdl.GetVersion(&wm_info.version)

		if !sdl.GetWindowWMInfo(window.core.sdl_handle, &wm_info) {
			fmt.eprintln("Could not obtain window manager info from window")
			return nil, false
		}

		if wm_info.subsystem != .X11 {
			fmt.eprintln("Unsupported window manager")
			return nil, false
		}

		surface_descriptor := wgpu.SurfaceDescriptorFromXlibWindow{
			chain = wgpu.ChainedStruct{
				sType = .SurfaceDescriptorFromXlibWindow,
			},
			display = wm_info.info.x11.display,
			window = c.uint32_t(wm_info.info.x11.window),
		}

		surf = wgpu.InstanceCreateSurface(
			nil,
			&wgpu.SurfaceDescriptor{
				nextInChain = cast(^wgpu.ChainedStruct) &surface_descriptor,
			},
		)
	}

	return surf, true
}
