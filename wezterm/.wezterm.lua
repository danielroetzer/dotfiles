local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'Catppuccin Mocha'
config.font_size = 14

-- hide_tab_bar_if_only_one_tab = true
enable_tab_bar = false

config.window_background_opacity = 0.7

return config
