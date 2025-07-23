-- Pull in the wezterm API
local wezterm = require "wezterm"

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
    config = wezterm.config_builder()
end

config.front_end = "OpenGL"
config.enable_wayland = false

config.default_prog = {"tmux"}
config.font = wezterm.font "JetBrainsMono Nerd Font"
config.font_size = 9.0
config.window_background_opacity = 0.8

config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false

-- Acceptable values are SteadyBlock, BlinkingBlock, SteadyUnderline, BlinkingUnderline, SteadyBar, and BlinkingBar.
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 530
-- Linear - the fade happens at a constant rate.
-- Ease - The fade starts slowly, accelerates sharply, and then slows gradually towards the end. This is the default.
-- EaseIn - The fade starts slowly, and then progressively speeds up until the end, at which point it stops abruptly.
-- EaseInOut - The fade starts slowly, speeds up, and then slows down towards the end.
-- EaseOut - The fade starts abruptly, and then progressively slows down towards the end.
-- {CubicBezier={0.0, 0.0, 0.58, 1.0}} - an arbitrary cubic bezier with the specified parameters.
-- Constant - Evaluates as 0 regardless of time. Useful to implement a step transition at the end of the duration. (Since: Version 20220408-101518-b908e2dd)
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

config.colors = {
    cursor_bg = "white",
    cursor_fg = "black"
}

config.window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0
}

config.keys = {{
    key = "_",
    mods = "SHIFT | ALT | CTRL",
    action = wezterm.action.SplitVertical {
        domain = "CurrentPaneDomain"
    }
}, {
    key = "|",
    mods = "SHIFT | ALT | CTRL",
    action = wezterm.action.SplitHorizontal {
        domain = "CurrentPaneDomain"
    }
}}

config.launch_menu = {{
    label = 'tmux',
    args = {'tmux'}
}, {
    label = 'dev-machine',
    args = {'ssh dev-machine'}
    -- cwd = "/some/path"
    -- set_environment_variables = { FOO = "bar" },
}, {
    label = 'vdi-linux',
    args = {'ssh vdi-linux'}
}}

-- config.color_scheme = "Builtin Dark"
-- config.color_scheme = 'CGA'
-- config.color_scheme = 'Paul Millr (Gogh)'

-- colors based on hyper: https://github.com/alacritty/alacritty-theme/blob/master/themes/hyper.yaml
config.colors = {
    -- The default text color
    foreground = '#ffffff',
    -- The default background color
    background = '#000000',

    -- Overrides the cell background color when the current cell is occupied by the
    -- cursor and the cursor style is set to Block
    cursor_bg = '#ffffff',
    -- Overrides the text color when the current cell is occupied by the cursor
    cursor_fg = '#ff00ff',
    -- Specifies the border color of the cursor when the cursor style is set to Block,
    -- or the color of the vertical or horizontal bar when the cursor style is set to
    -- Bar or Underline.
    cursor_border = '#ffffff',

    selection_fg = 'black',
    selection_bg = '#ffffff',

    -- The color of the scrollbar "thumb"; the portion that represents the current viewport
    scrollbar_thumb = '#ffffff',

    -- The color of the split lines between panes
    split = '#ffffff',

    ansi = {'#000000', '#fe0100', '#33ff00', '#feff00', '#0066ff', '#cc00ff', '#00ffff', '#d0d0d0'},
    brights = {'#808080', '#fe0100', '#33ff00', '#feff00', '#0066ff', '#cc00ff', '#00ffff', '#FFFFFF'},

    -- Arbitrary colors of the palette in the range from 16 to 255
    -- indexed = {
    --     [136] = '#af8700'
    -- },

    -- Since: 20220319-142410-0fcdea07
    -- When the IME, a dead key or a leader key are being processed and are effectively
    -- holding input pending the result of input composition, change the cursor
    -- to this color to give a visual cue about the compose state.
    compose_cursor = 'orange',

    -- Colors for copy_mode and quick_select
    -- available since: 20220807-113146-c2fee766
    -- In copy_mode, the color of the active text is:
    -- 1. copy_mode_active_highlight_* if additional text was selected using the mouse
    -- 2. selection_* otherwise
    copy_mode_active_highlight_bg = {
        Color = '#000000'
    },
    -- use `AnsiColor` to specify one of the ansi color palette values
    -- (index 0-15) using one of the names "Black", "Maroon", "Green",
    --  "Olive", "Navy", "Purple", "Teal", "Silver", "Grey", "Red", "Lime",
    -- "Yellow", "Blue", "Fuchsia", "Aqua" or "White".
    copy_mode_active_highlight_fg = {
        AnsiColor = 'Black'
    },
    copy_mode_inactive_highlight_bg = {
        Color = '#52ad70'
    },
    copy_mode_inactive_highlight_fg = {
        AnsiColor = 'White'
    },

    quick_select_label_bg = {
        Color = 'peru'
    },
    quick_select_label_fg = {
        Color = '#ffffff'
    },
    quick_select_match_bg = {
        AnsiColor = 'Navy'
    },
    quick_select_match_fg = {
        Color = '#ffffff'
    }
}

-- and finally, return the configuration to wezterm
return config
