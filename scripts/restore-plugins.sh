#!/bin/bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
nvim_dir="$config_home/${NVIM_APPNAME:-nvim}"
if [ "$nvim_dir" -ef "$repo_root/.config/nvim" ]; then
    echo "Restoring locked Neovim plugins..."
    "$repo_root/scripts/run-nvim-check.sh" 'vim.cmd("Lazy! restore")' -u "$nvim_dir/init.lua"
else
    echo "- Skipping Neovim plugin restore: $nvim_dir is not the checkout configuration"
fi

sheldon_dir=${SHELDON_CONFIG_DIR:-$config_home/sheldon}
sheldon_config=${SHELDON_CONFIG_FILE:-$sheldon_dir/plugins.toml}
if [ "$sheldon_config" -ef "$repo_root/.config/sheldon/plugins.toml" ]; then
    echo "Locking Sheldon plugins..."
    sheldon --config-file "$sheldon_config" lock
else
    echo "- Skipping Sheldon lock: $sheldon_config is not the checkout configuration"
fi
