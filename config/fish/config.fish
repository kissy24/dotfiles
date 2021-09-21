# --- bobthefish settings ---
# vi mode
fish_vi_key_bindings
set -g theme_display_vi yes
# font 依存をなくす
set -g theme_powerline_fonts no
set -g theme_nerd_fonts no
# color scheme
set -g theme_color_scheme nord
# details
set -g theme_date_format "+%F %H:%M"
set -g theme_display_git_master_branch yes
set -g theme_display_cmd_duration yes
set -g theme_newline_cursor yes
set -g theme_newline_prompt '$ '
set -g fish_prompt_pwd_dir_length 0
