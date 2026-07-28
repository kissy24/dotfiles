#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
REPO_ROOT=$(cd "$SCRIPT_DIR" && pwd)
FORCE=0

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--force]

  --force    Replace existing dotfiles instead of skipping them
  --help     Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --force)
            FORCE=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

install_ubuntu_prerequisites() {
    echo "Installing Ubuntu prerequisites..."
    mapfile -t apt_packages < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$REPO_ROOT/packages/apt.txt")
    sudo apt-get update
    sudo apt-get install -y "${apt_packages[@]}"
}

ensure_platform_prerequisites() {
    case "$(uname)" in
        Darwin)
            command -v curl >/dev/null 2>&1 || {
                echo "Error: curl is required on macOS." >&2
                exit 1
            }
            ;;
        Linux)
            if ! command -v apt-get >/dev/null 2>&1; then
                echo "Error: Linux support requires an Ubuntu/Debian environment with apt-get." >&2
                exit 1
            fi
            install_ubuntu_prerequisites
            ;;
        *)
            echo "Error: Unsupported OS." >&2
            exit 1
            ;;
    esac
}

ensure_mise() {
    export PATH="$HOME/.local/bin:$PATH"
    "$REPO_ROOT/scripts/install-mise.sh"
    command -v mise >/dev/null 2>&1 || {
        echo "Error: mise installation did not provide a mise command." >&2
        exit 1
    }
}

install_mise_tools() {
    echo "Installing locked mise tools..."
    mise trust "$REPO_ROOT/.config/mise/config.toml"
    (cd "$REPO_ROOT" && mise install --locked)
    export PATH="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"
}

remove_legacy_tmux_symlink() {
    local legacy_source="$REPO_ROOT/.tmux.conf"
    local legacy_dest="$HOME/.tmux.conf"

    if [ -L "$legacy_dest" ] && [ "$(readlink "$legacy_dest")" = "$legacy_source" ]; then
        echo "Removing legacy tmux config link: $legacy_dest"
        rm "$legacy_dest"
    fi
}

create_symlinks() {
    local dotfile_sources=(
        "$REPO_ROOT/.zshrc"
        "$REPO_ROOT/.local/bin/pkgupd"
        "$REPO_ROOT/.config/mise"
        "$REPO_ROOT/.config/herdr/config.toml"
        "$REPO_ROOT/.config/starship.toml"
        "$REPO_ROOT/.config/nvim"
        "$REPO_ROOT/.config/wezterm"
        "$REPO_ROOT/.config/sheldon"
        "$REPO_ROOT/.config/lazygit"
        "$REPO_ROOT/.config/gh"
    )
    local dotfile_dests=(
        "$HOME/.zshrc"
        "$HOME/.local/bin/pkgupd"
        "$HOME/.config/mise"
        "$HOME/.config/herdr/config.toml"
        "$HOME/.config/starship.toml"
        "$HOME/.config/nvim"
        "$HOME/.config/wezterm"
        "$HOME/.config/sheldon"
        "$HOME/.config/lazygit"
        "$HOME/.config/gh"
    )
    local i src dest

    echo "Creating symlinks..."
    for i in "${!dotfile_sources[@]}"; do
        src=${dotfile_sources[$i]}
        dest=${dotfile_dests[$i]}
        mkdir -p "$(dirname "$dest")"

        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            echo "- Link already exists: $dest"
            continue
        fi
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ "$FORCE" -ne 1 ]; then
                echo "- Skipping existing path: $dest (use --force to replace)"
                continue
            fi
            echo "- Replacing existing path: $dest"
            rm -rf "$dest"
        fi
        echo "- Creating link: $dest -> $src"
        ln -s "$src" "$dest"
    done
}

install_bun_language_servers() {
    local data_home=${XDG_DATA_HOME:-$HOME/.local/share}
    local lsp_dir="$data_home/dotfiles-lsp"

    echo "Installing Bun-managed language servers..."
    mkdir -p "$lsp_dir"
    cp "$REPO_ROOT/packages/bun-lsp/package.json" "$lsp_dir/package.json"
    cp "$REPO_ROOT/packages/bun-lsp/bun.lock" "$lsp_dir/bun.lock"
    (cd "$lsp_dir" && bun install --frozen-lockfile)
}

install_pre_commit() {
    export PATH="$HOME/.local/bin:$PATH"
    echo "Installing pre-commit via uv..."
    uv tool install pre-commit
    pre-commit install --install-hooks
    pre-commit install --hook-type commit-msg --install-hooks
}

ensure_platform_prerequisites
ensure_mise
remove_legacy_tmux_symlink
create_symlinks
install_mise_tools
install_bun_language_servers
install_pre_commit

echo "Syncing Neovim plugins and Mason-managed language servers..."
nvim --headless -c 'Lazy sync' -c 'qa'

echo "Locking Sheldon plugins..."
sheldon lock

echo "Setup complete. Restart your terminal."
