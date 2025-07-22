local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- カラースキームの設定
-- config.color_scheme = "Catppuccin Mocha"
-- config.color_scheme = "Tokyo Night Moon"
config.color_scheme = "GitHub Dark"

-- フォント設定
config.font = wezterm.font("HackGen35 Console NF", { weight = "Regular", italic = false })
if wezterm.target_triple:find("darwin") then
    config.font_size = 13.5
else
    config.font_size = 10.5
end

-- WSL Ubuntu をデフォルトシェルとして設定
if wezterm.target_triple:find("windows") then
    config.default_prog = { "wsl.exe", "~", "-d", "Ubuntu-20.04" }
end

-- タブバーの表示オプション(catpputin-mocha の設定を参考にした)
local HEADER = " "
local SYMBOL_COLOR = { '#89b4fa', '#9399b2' }
local FONT_COLOR = { '#cba6f7', '#9399b2' }
local BACK_COLOR = '#1e1e2e'
local HOVER_COLOR = '#45475a'

wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
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

-- ウィンドウの設定
-- config.window_background_opacity = 0.95
config.initial_cols = 150
config.initial_rows = 45
-- config.window_decorations = "TITLE"
local function BaseName(s)
    return string.gsub(s, '(.*[/\\])(.*)', '%2')
end

wezterm.on('format-window-title', function(tab)
    return BaseName(tab.active_pane.foreground_process_name)
end)

-- カーソルスタイルをバーに設定
config.default_cursor_style = "BlinkingBar"

-- 簡易的なアニメーション効果
config.animation_fps = 60
config.cursor_blink_rate = 500

-- ベルの設定
config.audible_bell = "Disabled"

-- ホットキー設定
config.keys = {
    { key = "C", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
    { key = "V", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
}

return config
