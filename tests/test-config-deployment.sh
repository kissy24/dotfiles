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
done < <(deployment_payload_paths)
cp "$REPO_ROOT/.local/bin/pkgupd" "$fixture_repo/.local/bin/pkgupd"
chmod +x "$fixture_repo/.local/bin/pkgupd"
cp "$REPO_ROOT/scripts/"{homebrew_release_age,release_age,dependency_observations}.py "$fixture_repo/scripts/"
git -C "$fixture_repo" init -q
git -C "$fixture_repo" config user.name 'Deployment Test'
git -C "$fixture_repo" config user.email test@example.invalid
git -C "$fixture_repo" config core.hooksPath /dev/null
git -C "$fixture_repo" config commit.gpgsign false
git -C "$fixture_repo" add -- .zshrc .zshenv .local .config scripts
git -C "$fixture_repo" commit -qm 'Initial trusted config'
# Migrate the old direct links without --force, keeping a backup.
create_symlinks "$fixture_repo" "$target_home" 0 >/dev/null
deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null
test "$(readlink "$target_home/.zshrc")" = "$XDG_DATA_HOME/dotfiles/current/.zshrc"
test -n "$(find "$target_home" -name '.zshrc.backup-*' -print)"
# The deployed command must find its helpers without accessing the source tree.
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
printf '\n# unreviewed helper change\n' >> "$fixture_repo/scripts/release_age.py"
if deploy_dotfiles "$fixture_repo" "$target_home" 0 >/dev/null 2>&1; then
    echo 'Dirty helper deployment unexpectedly succeeded' >&2; exit 1
fi
git -C "$fixture_repo" checkout -- scripts/release_age.py
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
