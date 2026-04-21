local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- WSL Ubuntu をデフォルトシェルとして設定
if wezterm.target_triple:find("windows") then
    config.default_prog = { "wsl.exe", "~", "-d", "Ubuntu-24.04" }
end

-- カラースキームの設定
config.color_scheme = "Github Dark (Gogh)"

-- フォント設定
config.font = wezterm.font("HackGen Console NF")
if wezterm.target_triple:find("darwin") then
    config.font_size = 13.5
else
    config.font_size = 11
end
config.use_ime = true

-- タブバーの表示オプション(catpputin-mocha の設定を参考にした)
local HEADER = " "
local SYMBOL_COLOR = { '#58a6ff', '#484f58' }
local FONT_COLOR = { '#c9d1d9', '#8b949e' }
local BACK_COLOR = 'none'
local HOVER_COLOR = 'none'

-- ウィンドウの設定
config.initial_cols = 180
config.initial_rows = 47
config.window_decorations = "RESIZE"
config.show_new_tab_button_in_tab_bar = false

-- カーソルスタイルをバーに設定
config.default_cursor_style = "BlinkingBar"

-- 簡易的なアニメーション効果
config.animation_fps = 60
config.cursor_blink_rate = 500

-- ベルの設定
config.audible_bell = "Disabled"

-- ホットキー設定
config.keys = {
    { key = "C", mods = "CTRL", action = wezterm.action.CopyTo("Clipboard") },
    { key = "V", mods = "CTRL", action = wezterm.action.PasteFrom("Clipboard") },
}

config.window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
}

config.window_background_gradient = {
    colors = { "#22272e", "#1c2128" },
}

wezterm.on('format-tab-title', function(tab, hover)
    local index = tab.is_active and 1 or 2
    local bg = hover and HOVER_COLOR or BACK_COLOR
    local zoomed = tab.active_pane.is_zoomed and '🔎 ' or ' '
    return {
        { Foreground = { Color = SYMBOL_COLOR[index] } },
        { Background = { Color = bg } },
        { Text = HEADER .. zoomed },
        { Foreground = { Color = FONT_COLOR[index] } },
        { Background = { Color = bg } },
        { Text = tab.active_pane.title },
    }
end)

local function BaseName(s)
    return string.gsub(s, '(.*[/\\])(.*)', '%2')
end

wezterm.on('format-window-title', function(tab)
    return BaseName(tab.active_pane.foreground_process_name)
end)

return config
