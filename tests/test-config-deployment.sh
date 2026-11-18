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
mkdir -p "$fixture_repo/scripts"
cp "$REPO_ROOT/.local/bin/pkgupd" "$fixture_repo/.local/bin/pkgupd"
chmod +x "$fixture_repo/.local/bin/pkgupd"
cp "$REPO_ROOT/scripts/"{homebrew_release_age,release_age,dependency_observations}.py "$fixture_repo/scripts/"
# Revert known snapshot links, preserving the old release and link backups.
snapshot="$XDG_DATA_HOME/dotfiles/releases/previous"
mkdir -p "$snapshot"
cp -R "$fixture_repo/." "$snapshot/"
ln -s "$snapshot" "$XDG_DATA_HOME/dotfiles/current"
create_symlinks "$XDG_DATA_HOME/dotfiles/current" "$target_home" 0 >/dev/null
deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null
while IFS= read -r path; do
    test "$(readlink "$target_home/$path")" = "$fixture_repo/$path"
done < <(managed_dotfile_paths)
test "$(readlink "$target_home"/.zshrc.backup-*/original)" = "$XDG_DATA_HOME/dotfiles/current/.zshrc"
test "$(readlink "$XDG_DATA_HOME/dotfiles/current")" = "$snapshot"
grep -qx trusted "$snapshot/.zshrc"
# The linked command must resolve its helpers in the checkout.
mkdir -p "$TMP_ROOT/bin"
cat > "$TMP_ROOT/bin/brew" <<'BREW'
#!/bin/bash
case "$1" in
    outdated) printf '{"formulae":[{"name":"demo","current_version":"1.0"}]}\n' ;;
    upgrade) exit 99 ;;
esac
BREW
chmod +x "$TMP_ROOT/bin/brew"
PATH="$TMP_ROOT/bin:$PATH" "$target_home/.local/bin/pkgupd" --homebrew-only > "$TMP_ROOT/update.log" 2>&1 || {
    cat "$TMP_ROOT/update.log" >&2
    exit 1
}
grep -q 'demo 1.0.*published_at=null' "$TMP_ROOT/update.log"
# Checkout edits, including local config, are visible without deploying again.
printf 'edited\n' > "$fixture_repo/.zshrc"
printf 'local value\n' > "$fixture_repo/.config/nvim/local.txt"
grep -qx edited "$target_home/.zshrc"
grep -qx 'local value' "$target_home/.config/nvim/local.txt"
grep -qx trusted "$snapshot/.zshrc"
# Repeated deployment creates neither snapshots nor extra backups.
before=$(find "$target_home" -name '*.backup-*' -print | sort)
deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null
test "$before" = "$(find "$target_home" -name '*.backup-*' -print | sort)"
test "$(find "$XDG_DATA_HOME/dotfiles/releases" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" = 1
# Unrelated files and links remain untouched, even at a managed leaf.
rm "$target_home/.zshrc" "$target_home/.zshenv"
printf 'local config\n' > "$target_home/.zshrc"
ln -s missing-relative-target "$target_home/.zshenv"
deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null
grep -qx 'local config' "$target_home/.zshrc"
test "$(readlink "$target_home/.zshenv")" = missing-relative-target
remove_symlinks "$fixture_repo" "$target_home" >/dev/null
test ! -L "$target_home/.config/nvim"
test "$(readlink "$target_home/.zshenv")" = missing-relative-target
grep -qx 'local config' "$target_home/.zshrc"
grep -qx edited "$fixture_repo/.zshrc"
grep -qx trusted "$snapshot/.zshrc"
echo 'Direct configuration links reflect checkout edits and preserve previous snapshots.'
