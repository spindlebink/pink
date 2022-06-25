package pink

Config :: struct {
	window_title: string,
	window_width: u32,
	window_height: u32,
	framerate_fixed: f64,
	framerate_cap: f64,
}

DEFAULT_CONFIG :: Config{
	window_title = "Window",
	window_width = 800,
	window_height = 600,
	framerate_fixed = 60.0,
	framerate_cap = 120.0,
}

config_fill_defaults :: proc(config: ^Config) {
	if config.window_title == "" {
		config.window_title = DEFAULT_CONFIG.window_title
	}
	if config.window_width == 0 {
		config.window_width = DEFAULT_CONFIG.window_width
	}
	if config.window_height == 0 {
		config.window_height = DEFAULT_CONFIG.window_height
	}
	if config.framerate_fixed == 0.0 {
		config.framerate_fixed = DEFAULT_CONFIG.framerate_fixed
	}
	if config.framerate_cap == 0.0 {
		config.framerate_cap = DEFAULT_CONFIG.framerate_cap
	}
}
