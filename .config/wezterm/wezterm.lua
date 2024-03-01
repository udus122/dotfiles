-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- appearance
config.color_scheme = 'MaterialDesignColors'
config.window_background_opacity = 0.85

-- font
config.font = wezterm.font('Hack Nerd Font Mono')
config.font_size = 16
config.use_ime = true

-- tab
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true

return config
