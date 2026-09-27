#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
REPO_ROOT=$(cd "$SCRIPT_DIR" && pwd)
FORCE=0

# shellcheck source=scripts/lib/dotfiles.sh
source "$REPO_ROOT/scripts/lib/dotfiles.sh"

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--force]

  --force    Back up and replace existing dotfiles instead of skipping them
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

install_bun_language_servers() {
    local data_home=${XDG_DATA_HOME:-$HOME/.local/share}
    local lsp_dir="$data_home/dotfiles-lsp"

    echo "Installing Bun-managed language servers..."
    mkdir -p "$lsp_dir"
    cp "$REPO_ROOT/packages/bun-lsp/package.json" "$lsp_dir/package.json"
    cp "$REPO_ROOT/packages/bun-lsp/bun.lock" "$lsp_dir/bun.lock"
    (cd "$lsp_dir" && bun install --frozen-lockfile)
}

generate_zsh_caches() {
    local cache_home=${XDG_CACHE_HOME:-$HOME/.cache}
    local completion_dir="$cache_home/dotfiles/zsh"
    local zcompdump=${ZDOTDIR:-$HOME}/.zcompdump
    local temp_file

    echo "Generating Zsh completion caches..."
    mkdir -p "$completion_dir"

    temp_file=$(mktemp "$completion_dir/uv.zsh.XXXXXX")
    uv generate-shell-completion zsh > "$temp_file"
    mv "$temp_file" "$completion_dir/uv.zsh"

    temp_file=$(mktemp "$completion_dir/herdr.zsh.XXXXXX")
    herdr completion zsh > "$temp_file"
    mv "$temp_file" "$completion_dir/herdr.zsh"

    zsh -dfc 'autoload -Uz compinit && compinit -i -d "$1"' _ "$zcompdump"
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
create_symlinks "$REPO_ROOT" "$HOME" "$FORCE"
echo "Configuring WSL startup..."
"$REPO_ROOT/scripts/install-wsl-config.sh" "$FORCE"
install_bun_language_servers
generate_zsh_caches
install_pre_commit

echo "Syncing Neovim plugins and Mason-managed language servers..."
"$REPO_ROOT/scripts/run-nvim-check.sh" 'vim.cmd("Lazy! sync")'

echo "Installing configured Tree-sitter parsers..."
"$REPO_ROOT/scripts/run-nvim-check.sh" \
    "local parsers = require('plugins.treesitter')[1].opts.parsers; local task = require('nvim-treesitter').install(parsers, { max_jobs = 4 }); assert(task:wait(300000), 'Tree-sitter parser installation failed')"

echo "Locking Sheldon plugins..."
sheldon lock

echo "Setup complete. Restart your terminal."
