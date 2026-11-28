#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
REPO_ROOT=$(cd "$SCRIPT_DIR" && pwd)
REMOVE_PACKAGES=0

# shellcheck source=scripts/lib/dotfiles.sh
source "$REPO_ROOT/scripts/lib/dotfiles.sh"

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--packages]

Remove managed symlinks and the Windows .wslconfig if its contents match.

  --packages  Also remove pre-commit, managed LSPs, and installed Brewfile formulae
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

if [ "$REMOVE_PACKAGES" -eq 1 ]; then
    echo "This removes managed configuration, LSPs, pre-commit, and Brewfile packages, including pre-existing packages."
    read -r -p "Continue? (y/N): " reply || reply=
    case "$reply" in [Yy]) ;; *) echo "Uninstallation cancelled."; exit 0 ;; esac
fi

remove_symlinks "${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/current" "$HOME"
remove_symlinks "$REPO_ROOT" "$HOME"
"$REPO_ROOT/scripts/install-wsl-config.sh" remove

if [ "$REMOVE_PACKAGES" -eq 1 ]; then
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
