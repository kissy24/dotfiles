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

migrate_gh_directory() {
    local repo_root=$1 target_home=$2
    local dest="$target_home/.config/gh" staging

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
    local repo_root=$1 target_home=$2 force=$3
    local path src dest

    migrate_gh_directory "$repo_root" "$target_home"
    echo "Creating symlinks..."
    while IFS= read -r path; do
        src="$repo_root/$path"
        dest="$target_home/$path"
        # Do not write through a directory link managed by someone else.
        if [ "$path" = .config/gh/config.yml ] && [ -L "$target_home/.config/gh" ]; then
            echo "- Skipping unmanaged GitHub CLI directory link: $target_home/.config/gh"
            continue
        fi
        mkdir -p "$(dirname "$dest")"
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
            echo "- Link already exists: $dest"
            continue
        fi
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ "$force" -ne 1 ]; then
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
        # An old directory link is removed below; never delete through it.
        if [ "$path" = .config/gh/config.yml ] && [ -L "$target_home/.config/gh" ]; then
            continue
        fi
        if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$repo_root/$path" ]; then
            echo "- Removing link: $dest"
            rm "$dest"
        elif [ -e "$dest" ] || [ -L "$dest" ]; then
            echo "- Skipping unmanaged path: $dest"
        fi
    done < <(managed_dotfile_paths; printf '%s\n' .tmux.conf .config/gh)
}
