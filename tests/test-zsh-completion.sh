#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/zsh-completion-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

# Exercise the actual initialization command without loading personal shell settings.
init=$(sed -n '/^autoload -Uz compinit /p' "$REPO_ROOT/.zshrc")
test -n "$init"
mkdir "$TMP_ROOT/safe" "$TMP_ROOT/unsafe"
printf '#compdef dotfiles-safe\n_arguments "*:file:_files"\n' > "$TMP_ROOT/safe/_dotfiles_safe"
printf '#compdef dotfiles-unsafe\n_arguments "*:file:_files"\n' > "$TMP_ROOT/unsafe/_dotfiles_unsafe"

ZDOTDIR="$TMP_ROOT" zsh -dfc '
    fpath=("$1/safe" "$1/unsafe" $fpath)
    eval "$2"
    [[ ${_comps[dotfiles-safe]} = _dotfiles_safe && ${_comps[dotfiles-unsafe]} = _dotfiles_unsafe ]]
' _ "$TMP_ROOT" "$init"
test -s "$TMP_ROOT/.zcompdump"

# A previously safe directory becomes writable by other users after caching.
chmod o+w "$TMP_ROOT/unsafe"
ZDOTDIR="$TMP_ROOT" zsh -dfc '
    fpath=("$1/safe" "$1/unsafe" $fpath)
    eval "$2"
    [[ ${fpath[(Ie)$1/unsafe]} = 0 && ${fpath[(Ie)$1/safe]} != 0 ]]
' _ "$TMP_ROOT" "$init"

echo "Zsh rejects insecure completion directories even with an existing dump."
