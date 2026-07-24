#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/pkgupd-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

FAKE_BIN=$TMP_ROOT/bin
STATE_HOME=$TMP_ROOT/state
NIX_LOG=$TMP_ROOT/nix.log
PROFILE=$STATE_HOME/dotfiles/nix-profile
mkdir -p "$FAKE_BIN" "$(dirname "$PROFILE")"
touch "$PROFILE"

cat > "$FAKE_BIN/nix" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$PKGUPD_TEST_NIX_LOG"
EOF
chmod +x "$FAKE_BIN/nix"

PATH="$FAKE_BIN:$PATH" \
    XDG_STATE_HOME="$STATE_HOME" \
    PKGUPD_TEST_NIX_LOG="$NIX_LOG" \
    "$REPO_ROOT/.local/bin/pkgupd" >/dev/null

grep -Fqx -- \
    "--extra-experimental-features nix-command flakes profile upgrade --profile $PROFILE --all --no-write-lock-file" \
    "$NIX_LOG"

if "$REPO_ROOT/.local/bin/pkgupd" --homebrew-only >/dev/null 2>&1; then
    echo "pkgupd accepted the removed --homebrew-only option." >&2
    exit 1
fi

echo "pkgupd Nix profile tests passed."
