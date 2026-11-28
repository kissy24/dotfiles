#!/bin/bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/.." && pwd)
tmp_root=$(mktemp -d)
trap 'rm -rf "$tmp_root"' EXIT
mkdir -p "$tmp_root/bin" "$tmp_root/config/nvim" "$tmp_root/config/sheldon"
export PATH="$tmp_root/bin:$PATH" XDG_CONFIG_HOME="$tmp_root/config" CALLS="$tmp_root/calls"
unset NVIM_APPNAME SHELDON_CONFIG_DIR SHELDON_CONFIG_FILE
cat > "$tmp_root/bin/nvim" <<'NVIM'
#!/bin/bash
set -eu
test "$DOTFILES_NVIM_CHECK" = 'vim.cmd("Lazy! restore")'
test "$2" = -u
test "$3" = "$XDG_CONFIG_HOME/nvim/init.lua"
echo nvim >> "$CALLS"
NVIM
cat > "$tmp_root/bin/sheldon" <<'SHELDON'
#!/bin/bash
set -eu
test "$1" = --config-file
test "$2" = "$XDG_CONFIG_HOME/sheldon/plugins.toml"
test "$3" = lock
echo sheldon >> "$CALLS"
SHELDON
chmod +x "$tmp_root/bin/nvim" "$tmp_root/bin/sheldon"
touch "$XDG_CONFIG_HOME/nvim/init.lua" "$XDG_CONFIG_HOME/sheldon/plugins.toml"
"$repo_root/scripts/restore-plugins.sh"
test ! -e "$CALLS"

# A legacy parent link and separate managed links resolve to the same configuration.
mv "$XDG_CONFIG_HOME" "$tmp_root/personal"
ln -s "$repo_root/.config" "$XDG_CONFIG_HOME"
"$repo_root/scripts/restore-plugins.sh"
test "$(cat "$CALLS")" = "$(printf 'nvim\nsheldon')"
unlink "$XDG_CONFIG_HOME"
mkdir "$XDG_CONFIG_HOME"
ln -s "$repo_root/.config/nvim" "$XDG_CONFIG_HOME/nvim"
ln -s "$repo_root/.config/sheldon" "$XDG_CONFIG_HOME/sheldon"
: > "$CALLS"
NVIM_APPNAME=personal "$repo_root/scripts/restore-plugins.sh"
SHELDON_CONFIG_FILE="$tmp_root/personal/sheldon/plugins.toml" "$repo_root/scripts/restore-plugins.sh"
test "$(cat "$CALLS")" = "$(printf 'sheldon\nnvim')"
