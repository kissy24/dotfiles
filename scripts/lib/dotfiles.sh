#!/bin/bash
# Shared by setup, uninstall, and isolated filesystem tests.

backup_path() {
    local dest=$1 backup_dir
    backup_dir=$(mktemp -d "${dest}.backup-$(date +%Y%m%d-%H%M%S).XXXXXX") || return
    mv "$dest" "$backup_dir/original" || return
    echo "- Backed up: $dest -> $backup_dir/original"
}

managed_dotfile_paths() {
    cat <<'EOF'
.zshrc
.zshenv
.local/bin/pkgupd
.config/herdr/config.toml
.config/starship.toml
.config/nvim
.config/wezterm
.config/sheldon
.config/lazygit
.config/gh/config.yml
EOF
}

# Do not mutate a managed leaf through a symlinked parent inside the target home.
has_symlink_parent() {
    local target_home=$1 path=$2 parent
    parent=${path%/*}
    [ "$parent" != "$path" ] || return 1
    while :; do
        [ ! -L "$target_home/$parent" ] || return 0
        case "$parent" in
            */*) parent=${parent%/*} ;;
            *) break ;;
        esac
    done
    return 1
}

migrate_gh_directory() {
    local repo_root=$1 target_home=$2
    local dest="$target_home/.config/gh" staging

    has_symlink_parent "$target_home" .config/gh && return 0
    # Only migrate the directory link created by earlier versions of setup.
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$repo_root/.config/gh" ]; then
        staging=$(mktemp -d "$target_home/.config/.gh-migration.XXXXXX")
        # Keep hosts.yml and any other local files, including their permissions.
        cp -pR "$dest/." "$staging/"
        rm "$staging/config.yml"
        ln -s "$repo_root/.config/gh/config.yml" "$staging/config.yml"
        backup_path "$dest"
        mv "$staging" "$dest"
        echo "- Migrated GitHub CLI directory link: $dest"
    fi
}

create_symlinks() {
    local repo_root=$1 target_home=$2 force=$3 legacy_root=${4:-}
    local path src dest

    migrate_gh_directory "$repo_root" "$target_home"
    echo "Creating symlinks..."
    while IFS= read -r path; do
        src="$repo_root/$path"
        dest="$target_home/$path"
        if has_symlink_parent "$target_home" "$path"; then
            echo "- Skipping path below a directory link: $dest"
            continue
        fi
        mkdir -p "$(dirname "$dest")"
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            echo "- Link already exists: $dest"
            continue
        fi
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ "$force" -ne 1 ] && { [ -z "$legacy_root" ] || [ ! -L "$dest" ] || [ "$(readlink "$dest")" != "$legacy_root/$path" ]; }; then
                echo "- Skipping existing path: $dest (use --force to replace)"
                continue
            fi
            backup_path "$dest"
        fi
        echo "- Creating link: $dest -> $src"
        ln -s "$src" "$dest"
    done < <(managed_dotfile_paths)
}

remove_symlinks() {
    local repo_root=$1 target_home=$2
    local path dest

    echo "Removing managed symlinks..."
    while IFS= read -r path; do
        dest="$target_home/$path"
        # Remove only the managed leaf; never delete through a linked parent.
        if has_symlink_parent "$target_home" "$path"; then
            echo "- Skipping path below a directory link: $dest"
            continue
        fi
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$repo_root/$path" ]; then
            echo "- Removing link: $dest"
            rm "$dest"
        elif [ -e "$dest" ] || [ -L "$dest" ]; then
            echo "- Skipping unmanaged path: $dest"
        fi
    done < <(managed_dotfile_paths; printf '%s\n' .config/gh)
}

# Keep configuration in the checkout. Retain legacy parent directory links,
# and replace only known snapshot leaf links without requiring --force.
deploy_dotfiles() {
    local repo_root=$1 target_home=$2 force=$3
    local data_home=${XDG_DATA_HOME:-$target_home/.local/share}
    create_symlinks "$repo_root" "$target_home" "$force" "$data_home/dotfiles/current"
    echo "Configuration links point to checkout: $repo_root"
}
