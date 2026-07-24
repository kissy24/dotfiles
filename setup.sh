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

install_nix_packages() {
    local profile_dir=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles
    local profile=$profile_dir/nix-profile
    local -a nix_args=(--extra-experimental-features "nix-command flakes")

    mkdir -p "$profile_dir"
    echo "Installing packages from the locked Nix flake..."
    if [ -e "$profile" ] || [ -L "$profile" ]; then
        nix "${nix_args[@]}" profile upgrade \
            --profile "$profile" \
            --all \
            --no-write-lock-file
    else
        nix "${nix_args[@]}" profile add \
            --profile "$profile" \
            "$REPO_ROOT#dotfiles" \
            --no-write-lock-file
    fi
    export PATH="$profile/bin:$PATH"
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

"$REPO_ROOT/scripts/install-nix.sh"
load_nix_environment
command -v nix >/dev/null 2>&1 || {
    echo "Error: Nix was installed but is not available in this shell." >&2
    exit 1
}
install_nix_packages
remove_legacy_tmux_symlink
create_symlinks
install_bun_language_servers
install_pre_commit

echo "Syncing Neovim plugins and Mason-managed language servers..."
nvim --headless -c 'Lazy sync' -c 'qa'

echo "Locking Sheldon plugins..."
sheldon lock

echo "Setup complete. Restart your terminal."
