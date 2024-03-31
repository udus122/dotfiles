-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

-- exit_behavior
config.window_close_confirmation = 'NeverPrompt'

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

-- leader
config.leader = { key = 'b', mods = 'CTRL', timeout_milliseconds = 2000 }

-- key assignment
config.keys = {
    { key = 'p', mods = 'SUPER|SHIFT', action = wezterm.action.ActivateCommandPalette },
    -- Make Option-Left equivalent to Alt-b which many line editors interpret as backward-word
    { key="LeftArrow", mods="OPT", action=wezterm.action{ SendString="\x1bb" } },
    -- Make Option-Right equivalent to Alt-f; forward-word
    { key="RightArrow", mods="OPT", action=wezterm.action{ SendString="\x1bf" } },
    { key = '"', mods = 'LEADER', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = '%', mods = 'LEADER', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = 'h', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Left' },
    { key = 'j', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Down' },
    { key = 'k', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Up' },
    { key = 'l', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Right' },
    { key = '[', mods = 'LEADER', action = wezterm.action.ActivateCopyMode },
    { key = 'b', mods = 'LEADER|CTRL', action = wezterm.action.SendKey { key = 'b', mods = 'CTRL' } },
    { key = 'UpArrow', mods = 'SHIFT', action = wezterm.action.ScrollToPrompt(-1) },
    { key = 'DownArrow', mods = 'SHIFT', action = wezterm.action.ScrollToPrompt(1) },
}

return config
