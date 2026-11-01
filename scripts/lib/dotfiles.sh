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
    local repo_root=$1 target_home=$2 force=$3 legacy_root=${4:-}
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
    done < <(managed_dotfile_paths; printf '%s\n' .config/gh)
}

# Publish committed files only. Branch switches and edits cannot change this copy.
deploy_dotfiles() {
    local repo_root=$1 target_home=$2 force=$3
    local data_home=${XDG_DATA_HOME:-$target_home/.local/share}
    local deployment="$data_home/dotfiles" revision staging path
    local -a paths=()
    while IFS= read -r path; do paths+=("$path"); done < <(managed_dotfile_paths)
    revision=$(git -C "$repo_root" rev-parse HEAD) || return
    if ! git -C "$repo_root" diff --quiet HEAD -- "${paths[@]}"; then
        echo "Error: Commit or discard managed configuration edits before deployment." >&2
        return 1
    fi
    mkdir -p "$deployment/releases"
    chmod 700 "$deployment" "$deployment/releases"
    staging=$(mktemp -d "$deployment/releases/$revision.XXXXXX") || return
    if ! git -C "$repo_root" archive HEAD -- "${paths[@]}" | tar -xf - -C "$staging"; then
        rm -rf "$staging"
        return 1
    fi
    # Tracked links could lead back to an editable checkout or outside the snapshot.
    if [ -n "$(find "$staging" -type l -print -quit)" ]; then
        echo "Error: Managed configuration must not contain symbolic links." >&2
        rm -rf "$staging"
        return 1
    fi
    printf '%s\n' "$revision" > "$staging/.revision"
    # Preserve GitHub credentials before replacing a legacy directory link.
    migrate_gh_directory "$repo_root" "$target_home"
    python3 - "$deployment/current" "$staging" <<'DEPLOY' || return
import os, sys, tempfile
current, target = sys.argv[1:]
with tempfile.TemporaryDirectory(dir=os.path.dirname(current)) as temporary:
    link = os.path.join(temporary, "current")
    os.symlink(target, link)
    os.replace(link, current)
DEPLOY
    create_symlinks "$deployment/current" "$target_home" "$force" "$repo_root"
    echo "Activated configuration commit: $revision"
}
