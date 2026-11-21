#!/bin/bash
# Give the verified upstream installer a Git remote containing only the approved release.
set -euo pipefail
installer=$1
pinfile=$2
revision=$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["homebrew_commit"])' "$pinfile")
version=$(python3 -I -c 'import json, sys; print(json.load(open(sys.argv[1]))["homebrew_version"])' "$pinfile")
mirror=$(mktemp -d)
trap 'rm -rf "$mirror"' EXIT
upstream=https://github.com/Homebrew/brew
git init --quiet --bare --initial-branch=main "$mirror"
git -C "$mirror" fetch --quiet --no-tags "$upstream" "refs/tags/$version:refs/tags/$version"
test "$(git -C "$mirror" rev-parse "refs/tags/$version^{commit}")" = "$revision"
git -C "$mirror" update-ref refs/heads/main "$revision"
# Keep the canonical origin in the installed repository. The URL rewrite only
# applies to children of this installer and its final brew update.
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.file://$mirror.insteadOf" GIT_CONFIG_VALUE_0="$upstream" \
    HOMEBREW_BREW_GIT_REMOTE="$upstream" NONINTERACTIVE=1 /bin/bash "$installer"
