#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
REPO_ROOT=$(cd "$SCRIPT_DIR" && pwd)
REMOVE_PACKAGES=0

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [--packages]

By default only managed symlinks are removed.

  --packages  Also remove the dedicated dotfiles Nix package profile
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

load_nix_environment() {
    local profile_script

    for profile_script in \
        /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
        "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
        if [ -r "$profile_script" ]; then
            # shellcheck disable=SC1090
            . "$profile_script"
            break
        fi
    done
}

remove_symlinks

if [ "$REMOVE_PACKAGES" -eq 1 ]; then
    echo "This removes the dedicated dotfiles Nix profile and managed user tools."
    read -r -p "Continue? (y/N): " reply
    case "$reply" in [Yy]) ;; *) echo "Package removal cancelled."; exit 0 ;; esac

    export PATH="$HOME/.local/bin:$PATH"
    if command -v pre-commit >/dev/null 2>&1; then
        pre-commit uninstall || true
        pre-commit uninstall --hook-type commit-msg || true
    fi
    command -v uv >/dev/null 2>&1 && uv tool uninstall pre-commit || true
    rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles-lsp"

    profile=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/nix-profile
    if [ -e "$profile" ] || [ -L "$profile" ]; then
        load_nix_environment
        command -v nix >/dev/null 2>&1 || {
            echo "Error: Nix is required to remove the dotfiles package profile." >&2
            exit 1
        }
        nix --extra-experimental-features "nix-command flakes" \
            profile remove --profile "$profile" --all
    fi
fi

echo "Uninstallation complete."
