#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/zsh-completion-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

# Exercise the actual initialization command without loading personal shell settings.
init=$(sed -n '/^typeset -U fpath$/p; /^autoload -Uz compinit /p' "$REPO_ROOT/.zshrc")
test -n "$init"
# Use the system's compinit helpers and only the two fixture completion paths.
# Runner-specific completion directories can independently invalidate the dump.
compinit_dir=$(zsh -dfc 'files=($^fpath/compinit(N)); (( $#files )) && print -r -- "${files[1]:h}"')
export _compdir='' # Keep compaudit from discovering extra system completion paths.
mkdir "$TMP_ROOT/safe" "$TMP_ROOT/unsafe"
printf '#compdef dotfiles-safe\n_arguments "*:file:_files"\n' > "$TMP_ROOT/safe/_dotfiles_safe"
printf '#compdef dotfiles-unsafe\n_arguments "*:file:_files"\n' > "$TMP_ROOT/unsafe/_dotfiles_unsafe"

ZDOTDIR="$TMP_ROOT" zsh -dfc '
    fpath=("$1/safe" "$1/unsafe" "$3")
    eval "$2"
    [[ ${_comps[dotfiles-safe]} = _dotfiles_safe && ${_comps[dotfiles-unsafe]} = _dotfiles_unsafe ]]
' _ "$TMP_ROOT" "$init" "$compinit_dir"
test -s "$TMP_ROOT/.zcompdump"

# An inherited duplicate must not trigger a rebuild on the next startup.
echo '# dotfiles-cache-marker' >> "$TMP_ROOT/.zcompdump"
ZDOTDIR="$TMP_ROOT" zsh -dfc '
    fpath=("$1/safe" "$1/unsafe" "$1/safe" "$3")
    eval "$2"
    [[ ${_comps[dotfiles-safe]} = _dotfiles_safe ]]
' _ "$TMP_ROOT" "$init" "$compinit_dir"
if ! grep -qx '# dotfiles-cache-marker' "$TMP_ROOT/.zcompdump"; then
    echo "Duplicate completion path caused the dump to be rebuilt." >&2
    exit 1
fi

# A previously safe directory becomes writable by other users after caching.
chmod o+w "$TMP_ROOT/unsafe"
ZDOTDIR="$TMP_ROOT" zsh -dfc '
    fpath=("$1/safe" "$1/unsafe" "$3")
    eval "$2"
    [[ ${fpath[(Ie)$1/unsafe]} = 0 && ${fpath[(Ie)$1/safe]} != 0 ]]
' _ "$TMP_ROOT" "$init" "$compinit_dir"

echo "Zsh rejects insecure completion directories even with an existing dump."
