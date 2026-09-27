#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=scripts/lib/dotfiles.sh
source "$REPO_ROOT/scripts/lib/dotfiles.sh"
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfile-links-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

fixture_repo="$TMP_ROOT/repo"
target_home="$TMP_ROOT/home"
while IFS= read -r path; do
    mkdir -p "$(dirname "$fixture_repo/$path")"
    case "$path" in
        .config/nvim|.config/wezterm|.config/sheldon|.config/lazygit)
            mkdir -p "$fixture_repo/$path" ;;
        *) printf 'managed\n' > "$fixture_repo/$path" ;;
    esac
done < <(managed_dotfile_paths)

mkdir -p "$target_home/.config/nvim" "$target_home/.config/gh"
printf 'original shell\n' > "$target_home/.zshrc"
printf 'original editor\n' > "$target_home/.config/nvim/init.lua"
printf 'local gh config\n' > "$target_home/.config/gh/config.yml"
printf 'local auth sentinel\n' > "$target_home/.config/gh/hosts.yml"
chmod 600 "$target_home/.config/gh/hosts.yml"
ln -s missing-relative-target "$target_home/.zshenv"

create_symlinks "$fixture_repo" "$target_home" 0 >/dev/null
test ! -L "$target_home/.zshrc"
grep -qx 'original shell' "$target_home/.zshrc"
grep -qx 'original editor' "$target_home/.config/nvim/init.lua"
grep -qx 'local gh config' "$target_home/.config/gh/config.yml"
test "$(readlink "$target_home/.zshenv")" = missing-relative-target
test -z "$(find "$target_home" -name '*.backup-*' -print)"

create_symlinks "$fixture_repo" "$target_home" 1 >/dev/null
grep -qx 'original shell' "$target_home"/.zshrc.backup-*/original
grep -qx 'original editor' "$target_home"/.config/nvim.backup-*/original/init.lua
grep -qx 'local gh config' "$target_home"/.config/gh/config.yml.backup-*/original
test "$(readlink "$target_home"/.zshenv.backup-*/original)" = missing-relative-target
test ! -L "$target_home/.config/gh"
test "$(readlink "$target_home/.config/gh/config.yml")" = "$fixture_repo/.config/gh/config.yml"
grep -qx 'local auth sentinel' "$target_home/.config/gh/hosts.yml"
test -n "$(find "$target_home/.config/gh/hosts.yml" -perm 600 -print)"

# Repeated setup must not back up links that are already managed.
before=$(find "$target_home" -name '*.backup-*' -print | sort)
create_symlinks "$fixture_repo" "$target_home" 1 >/dev/null
test "$before" = "$(find "$target_home" -name '*.backup-*' -print | sort)"

# A second conflict gets its own backup, even within the same second.
rm "$target_home/.zshrc"
printf 'second shell\n' > "$target_home/.zshrc"
create_symlinks "$fixture_repo" "$target_home" 1 >/dev/null
test "$(find "$target_home" -name '.zshrc.backup-*' | wc -l | tr -d ' ')" = 2
grep -qx 'original shell' "$target_home"/.zshrc.backup-*/original
grep -qx 'second shell' "$target_home"/.zshrc.backup-*/original

remove_symlinks "$fixture_repo" "$target_home" >/dev/null
test ! -L "$target_home/.zshrc"
test ! -e "$target_home/.config/gh/config.yml"
grep -qx 'local auth sentinel' "$target_home/.config/gh/hosts.yml"
grep -qx 'original shell' "$target_home"/.zshrc.backup-*/original

# Migrate the old managed directory link without touching its source.
legacy_home="$TMP_ROOT/legacy"
mkdir -p "$legacy_home/.config"
printf 'legacy auth sentinel\n' > "$fixture_repo/.config/gh/hosts.yml"
chmod 600 "$fixture_repo/.config/gh/hosts.yml"
ln -s "$fixture_repo/.config/gh" "$legacy_home/.config/gh"
create_symlinks "$fixture_repo" "$legacy_home" 0 >/dev/null
test ! -L "$legacy_home/.config/gh"
test -L "$legacy_home/.config/gh/config.yml"
grep -qx 'legacy auth sentinel' "$legacy_home/.config/gh/hosts.yml"
test -n "$(find "$legacy_home/.config/gh/hosts.yml" -perm 600 -print)"
test "$(readlink "$legacy_home"/.config/gh.backup-*/original)" = "$fixture_repo/.config/gh"
test ! -L "$fixture_repo/.config/gh/config.yml"
grep -qx managed "$fixture_repo/.config/gh/config.yml"
remove_symlinks "$fixture_repo" "$legacy_home" >/dev/null
grep -qx 'legacy auth sentinel' "$legacy_home/.config/gh/hosts.yml"
grep -qx 'legacy auth sentinel' "$fixture_repo/.config/gh/hosts.yml"

# Uninstall must also safely handle an unmigrated directory link.
rm -r "$legacy_home/.config/gh"
ln -s "$fixture_repo/.config/gh" "$legacy_home/.config/gh"
remove_symlinks "$fixture_repo" "$legacy_home" >/dev/null
test ! -L "$legacy_home/.config/gh"
grep -qx managed "$fixture_repo/.config/gh/config.yml"

# Unrelated directory links stay untouched, even with --force.
external_home="$TMP_ROOT/external"
mkdir -p "$external_home/.config" "$TMP_ROOT/other-gh"
printf 'external config\n' > "$TMP_ROOT/other-gh/config.yml"
ln -s "$TMP_ROOT/other-gh" "$external_home/.config/gh"
create_symlinks "$fixture_repo" "$external_home" 1 >/dev/null
remove_symlinks "$fixture_repo" "$external_home" >/dev/null
test "$(readlink "$external_home/.config/gh")" = "$TMP_ROOT/other-gh"
grep -qx 'external config' "$TMP_ROOT/other-gh/config.yml"

echo "Dotfile backup, migration, and uninstall tests passed."
