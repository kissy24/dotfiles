#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
REPO_ROOT=$(cd "$SCRIPT_DIR" && pwd)
REMOVE_PACKAGES=0

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--packages]

By default only managed symlinks are removed.

  --packages  Also uninstall packages declared in the Brewfile
  --help      Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --packages) REMOVE_PACKAGES=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Error: Unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

remove_symlinks() {
    local dest expected
    local dotfile_paths=(
        .zshrc
        .tmux.conf
        .config/starship.toml
        .config/nvim
        .config/wezterm
        .config/sheldon
        .config/lazygit
        .config/gh
    )

    echo "Removing managed symlinks..."
    for expected in "${dotfile_paths[@]}"; do
        dest="$HOME/$expected"
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$REPO_ROOT/$expected" ]; then
            echo "- Removing link: $dest"
            rm "$dest"
        elif [ -e "$dest" ] || [ -L "$dest" ]; then
            echo "- Skipping unmanaged path: $dest"
        fi
    done
}

brew_packages_from() {
    sed -n 's/^brew "\([^"]*\)".*/\1/p' "$1"
}

remove_brew_packages() {
    local package
    while IFS= read -r package; do
        if brew list --formula "$package" >/dev/null 2>&1; then
            brew uninstall "$package"
        fi
    done < <(brew_packages_from "$REPO_ROOT/Brewfile")
}

remove_symlinks

if [ "$REMOVE_PACKAGES" -eq 1 ]; then
    echo "This removes declared packages even if they existed before setup."
    read -r -p "Continue? (y/N): " reply
    case "$reply" in [Yy]) ;; *) echo "Package removal cancelled."; exit 0 ;; esac

    if ! command -v brew >/dev/null 2>&1 && [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    command -v brew >/dev/null 2>&1 || { echo "Error: Homebrew not found." >&2; exit 1; }

    export PATH="$HOME/.local/bin:$PATH"
    if command -v pre-commit >/dev/null 2>&1; then
        pre-commit uninstall || true
        pre-commit uninstall --hook-type commit-msg || true
    fi
    command -v uv >/dev/null 2>&1 && uv tool uninstall pre-commit || true
    rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles-lsp"
    remove_brew_packages
fi

echo "Uninstallation complete."
