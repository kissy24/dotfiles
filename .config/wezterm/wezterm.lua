local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- WSL Ubuntu をデフォルトシェルとして設定
if wezterm.target_triple:find("windows") then
    config.default_prog = { "wsl.exe", "~", "-d", "Ubuntu-24.04" }
end

-- カラースキームの設定
config.color_scheme = 'Catppuccin Mocha'

-- フォント設定
config.font = wezterm.font("HackGen Console NF")
if wezterm.target_triple:find("darwin") then
    config.font_size = 13.5
else
    config.font_size = 11
end
config.use_ime                        = true

-- ウィンドウの設定
config.window_background_opacity      = 0.7
config.win32_system_backdrop          = 'Acrylic'
config.macos_window_background_blur   = 20
config.initial_cols                   = 180
config.initial_rows                   = 50
config.window_decorations             = "RESIZE"
config.enable_tab_bar                 = false

-- カーソルスタイルをバーに設定
config.default_cursor_style           = "BlinkingBar"

-- 簡易的なアニメーション効果
config.animation_fps                  = 60
config.cursor_blink_rate              = 500

-- ベルの設定
config.audible_bell                   = "Disabled"

-- ホットキー設定
config.keys                           = {
    { key = "C", mods = "CTRL", action = wezterm.action.CopyTo("Clipboard") },
    { key = "V", mods = "CTRL", action = wezterm.action.PasteFrom("Clipboard") },
}

config.window_frame                   = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
}

config.window_background_gradient     = {
    colors = { "#181825", "#11111b" },
}

local function BaseName(s)
    return string.gsub(s, '(.*[/\\])(.*)', '%2')
end

wezterm.on('format-window-title', function(tab)
    return BaseName(tab.active_pane.foreground_process_name)
end)

return config
