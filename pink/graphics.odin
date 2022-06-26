//+private
package pink

import "core:c"
import "core:fmt"
import "core:mem"
import sdl "vendor:sdl2"
import "wgpu/wgpu"

graphics_state: struct {
	destroying: bool,

	surface: wgpu.Surface,
	adapter: wgpu.Adapter,
	device: wgpu.Device,
}

// WGPU callbacks

log_callback :: proc(
	level: wgpu.LogLevel,
	message: cstring,
) {
	fmt.println("[wgpu]", message)
}

instance_request_adapter_callback :: proc(
	status: wgpu.RequestAdapterStatus,
	adapter: wgpu.Adapter,
	message: cstring,
	userdata: rawptr,
) {
	adapter_props: wgpu.AdapterProperties
	wgpu.AdapterGetProperties(adapter, &adapter_props)
	if status == .Success {
		adapter_result := cast(^wgpu.Adapter) userdata
		adapter_result^ = adapter
	}
}

adapter_request_device_callback :: proc(
	status: wgpu.RequestDeviceStatus,
	device: wgpu.Device,
	message: cstring,
	userdata: rawptr,
) {
	if status == .Success {
		device_result := cast(^wgpu.Device) userdata
		device_result^ = device
	}
}

uncaptured_error_callback :: proc(
	type: wgpu.ErrorType,
	message: cstring,
	userdata: rawptr,
) {
	fmt.eprintln("[wgpu]", message)
	debug_assert_fatal(false, "WGPU error")
}

device_lost_callback :: proc(
	reason: wgpu.DeviceLostReason,
	message: cstring,
	userdata: rawptr,
) {
	if graphics_state.destroying do return
	
	fmt.eprintln("[wgpu]", message)
	debug_assert_fatal(false, "WGPU device lost")
}

// Graphics procedures

// Initializes the graphics context on a given SDL window.
graphics_init :: proc(window: ^sdl.Window) {
	debug_scope_push("init graphics"); defer debug_scope_pop()

	when ODIN_OS == .Linux {
		wm_info: sdl.SysWMinfo
		sdl.GetVersion(&wm_info.version)
		info_response := sdl.GetWindowWMInfo(window, &wm_info)

		debug_assert_fatal(cast(bool) info_response, "could not get window information")
		debug_assert_fatal(wm_info.subsystem == .X11, "graphics support only available for X11")

		surface_descriptor := wgpu.SurfaceDescriptorFromXlibWindow{
			chain = wgpu.ChainedStruct{
				sType = .SurfaceDescriptorFromXlibWindow,
			},
			display = wm_info.info.x11.display,
			window = cast(c.uint32_t) wm_info.info.x11.window,
		}
		graphics_state.surface = wgpu.InstanceCreateSurface(
			nil,
			&wgpu.SurfaceDescriptor{
				nextInChain = cast(^wgpu.ChainedStruct) &surface_descriptor,
			},
		)
	}

	debug_assert_fatal(graphics_state.surface != nil, "failed to initialize graphics surface")	
	
	wgpu.SetLogCallback(log_callback)
	wgpu.SetLogLevel(.Warn)
	
	wgpu.InstanceRequestAdapter(
		nil,
		&wgpu.RequestAdapterOptions{
			compatibleSurface = graphics_state.surface,
			powerPreference = .HighPerformance, // TODO: make configurable
		},
		instance_request_adapter_callback,
		&graphics_state.adapter,
	)
	
	debug_assert_fatal(graphics_state.adapter != nil, "failed to obtain adapter")
	
	wgpu.AdapterRequestDevice(
		graphics_state.adapter,
		&wgpu.DeviceDescriptor{
			nextInChain = cast(^wgpu.ChainedStruct) &wgpu.DeviceExtras{
				chain = wgpu.ChainedStruct{
					sType = cast(wgpu.SType) wgpu.NativeSType.DeviceExtras,
				},
			},
			requiredLimits = &wgpu.RequiredLimits{
				limits = wgpu.Limits{
					maxBindGroups = 1,
				},
			},
			defaultQueue = wgpu.QueueDescriptor{},
		},
		adapter_request_device_callback,
		&graphics_state.device,
	)

	debug_assert_fatal(graphics_state.device != nil, "failed to obtain device")
	
	wgpu.DeviceSetUncapturedErrorCallback(
		graphics_state.device,
		uncaptured_error_callback,
		nil,
	)
	wgpu.DeviceSetDeviceLostCallback(
		graphics_state.device,
		device_lost_callback,
		nil,
	)
	
	render_init()
}

graphics_destroy :: proc() {
	graphics_state.destroying = true
	render_destroy()
	if graphics_state.device != nil {
		wgpu.DeviceDestroy(graphics_state.device)
	}
}
