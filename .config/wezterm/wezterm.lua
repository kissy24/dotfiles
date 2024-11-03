local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- カラースキームの設定
config.color_scheme = "Catppuccin Macchiato"

-- フォント設定
config.font = wezterm.font("HackGen35 Console NF", { weight = "Regular", italic = false })
if wezterm.target_triple:find("darwin") then
    config.font_size = 13.5
else
    config.font_size = 10.5
end

-- WSL Ubuntu 20.04 をデフォルトシェルとして設定
if wezterm.target_triple:find("windows") then
    config.default_prog = { "wsl.exe", "~", "-d", "Ubuntu-20.04" }
end

-- タブバーの表示オプション
config.hide_tab_bar_if_only_one_tab = true

-- ウィンドウの設定
config.window_background_opacity = 0.9
config.initial_cols = 150
config.initial_rows = 45

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
