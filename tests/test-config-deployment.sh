#!/bin/bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=scripts/lib/dotfiles.sh
source "$REPO_ROOT/scripts/lib/dotfiles.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/config-deployment-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
fixture_repo="$TMP_ROOT/repo"
target_home="$TMP_ROOT/home"
export XDG_DATA_HOME="$TMP_ROOT/data"
mkdir -p "$fixture_repo" "$target_home"
while IFS= read -r path; do
    mkdir -p "$(dirname "$fixture_repo/$path")"
    case "$path" in
        .config/nvim|.config/wezterm|.config/sheldon|.config/lazygit)
            mkdir -p "$fixture_repo/$path"
            printf 'trusted\n' > "$fixture_repo/$path/config.txt" ;;
        *) printf 'trusted\n' > "$fixture_repo/$path" ;;
    esac
done < <(managed_dotfile_paths)
git -C "$fixture_repo" init -q
git -C "$fixture_repo" config user.name 'Deployment Test'
git -C "$fixture_repo" config user.email test@example.invalid
git -C "$fixture_repo" config core.hooksPath /dev/null
git -C "$fixture_repo" config commit.gpgsign false
git -C "$fixture_repo" add -- .zshrc .zshenv .local .config
git -C "$fixture_repo" commit -qm 'Initial trusted config'
# Migrate the old direct links without --force, keeping a backup.
create_symlinks "$fixture_repo" "$target_home" 0 >/dev/null
deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null
test "$(readlink "$target_home/.zshrc")" = "$XDG_DATA_HOME/dotfiles/current/.zshrc"
test -n "$(find "$target_home" -name '.zshrc.backup-*' -print)"
# An untracked secret is never included in a snapshot.
printf 'private local value\n' > "$fixture_repo/.config/nvim/local-secret.txt"
deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null
test ! -e "$target_home/.config/nvim/local-secret.txt"
# Editing or checking out a different revision cannot change active config.
printf 'unreviewed\n' > "$fixture_repo/.zshrc"
grep -qx trusted "$target_home/.zshrc"
if deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null 2>&1; then
    echo 'Dirty config deployment unexpectedly succeeded' >&2; exit 1
fi
git -C "$fixture_repo" add -- .zshrc
git -C "$fixture_repo" commit -qm 'Different branch content'
grep -qx trusted "$target_home/.zshrc"
# Only explicit deployment changes the active configuration.
deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null
grep -qx unreviewed "$target_home/.zshrc"
# Existing unrelated paths remain untouched.
rm "$target_home/.zshrc"
printf 'local config\n' > "$target_home/.zshrc"
deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null
grep -qx 'local config' "$target_home/.zshrc"
# Tracked symlinks cannot escape from the snapshot.
rm "$fixture_repo/.zshrc"
ln -s "$fixture_repo/.zshenv" "$fixture_repo/.zshrc"
git -C "$fixture_repo" add -- .zshrc
git -C "$fixture_repo" commit -qm 'Symlink escape test'
if deploy_dotfiles "$fixture_repo" "$target_home" 1 >/dev/null 2>&1; then
    echo 'Symlink escape deployment unexpectedly succeeded' >&2; exit 1
fi
grep -qx 'local config' "$target_home/.zshrc"
remove_symlinks "$XDG_DATA_HOME/dotfiles/current" "$target_home" >/dev/null
test ! -L "$target_home/.zshenv"
echo 'Configuration snapshots isolate live settings from edits and branch changes.'
