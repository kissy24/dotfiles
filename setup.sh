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

load_brew_environment() {
    if command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
    elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
}

install_homebrew_on_ubuntu() {
    echo "Installing Ubuntu prerequisites for Homebrew..."
    mapfile -t apt_packages < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$REPO_ROOT/packages/apt.txt")
    sudo apt-get update
    sudo apt-get install -y "${apt_packages[@]}"

    if ! command -v brew >/dev/null 2>&1 && [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        echo "Installing Homebrew..."
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    load_brew_environment
}

ensure_homebrew() {
    case "$(uname)" in
        Darwin)
            load_brew_environment
            if ! command -v brew >/dev/null 2>&1; then
                echo "Error: Homebrew is required on macOS. Install it from https://brew.sh/ first." >&2
                exit 1
            fi
            ;;
        Linux)
            if ! command -v apt-get >/dev/null 2>&1; then
                echo "Error: Linux support requires an Ubuntu/Debian environment with apt-get." >&2
                exit 1
            fi
            install_homebrew_on_ubuntu
            ;;
        *)
            echo "Error: Unsupported OS." >&2
            exit 1
            ;;
    esac
}

install_brew_packages() {
    echo "Installing Homebrew packages..."
    brew bundle install --jobs=1 --file="$REPO_ROOT/Brewfile"
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

ensure_homebrew
install_brew_packages
remove_legacy_tmux_symlink
create_symlinks
install_bun_language_servers
install_pre_commit

echo "Syncing Neovim plugins and Mason-managed language servers..."
nvim --headless -c 'Lazy sync' -c 'qa'

echo "Locking Sheldon plugins..."
sheldon lock

echo "Setup complete. Restart your terminal."
