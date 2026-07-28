#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
REPO_ROOT=$(cd "$SCRIPT_DIR" && pwd)
REMOVE_PACKAGES=0

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--packages]

By default only managed symlinks are removed.

  --packages  Also uninstall tools declared in the mise config
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
        .local/bin/pkgupd
        .config/mise
        .config/herdr/config.toml
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

remove_mise_tools() {
    local tool
    local -a tools=()

    while IFS= read -r tool; do
        tools+=("$tool")
    done < <(
        awk '
            /^\[tools\]$/ { in_tools = 1; next }
            /^\[/ { in_tools = 0 }
            in_tools && /^[[:alnum:]_-]+[[:space:]]*=/ {
                name = $0
                sub(/[[:space:]]*=.*/, "", name)
                print name
            }
        ' "$REPO_ROOT/.config/mise/config.toml"
    )

    if [ "${#tools[@]}" -gt 0 ]; then
        (cd "$REPO_ROOT" && mise uninstall --yes "${tools[@]}")
    fi
}

if [ "$REMOVE_PACKAGES" -eq 1 ]; then
    echo "This removes declared packages even if they existed before setup."
    read -r -p "Continue? (y/N): " reply
    case "$reply" in [Yy]) ;; *) echo "Package removal cancelled."; exit 0 ;; esac

    export PATH="$HOME/.local/bin:${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"
    command -v mise >/dev/null 2>&1 || { echo "Error: mise not found." >&2; exit 1; }
    if command -v pre-commit >/dev/null 2>&1; then
        pre-commit uninstall || true
        pre-commit uninstall --hook-type commit-msg || true
    fi
    command -v uv >/dev/null 2>&1 && uv tool uninstall pre-commit || true
    rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles-lsp"
    remove_mise_tools
fi

remove_symlinks

echo "Uninstallation complete."
