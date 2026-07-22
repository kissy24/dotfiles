#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/pkgupd-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

FAKE_BIN=$TMP_ROOT/bin
STATE_HOME=$TMP_ROOT/state
BREW_LOG=$TMP_ROOT/brew.log
OUTDATED_JSON=$TMP_ROOT/outdated.json
mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/brew" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$PKGUPD_TEST_BREW_LOG"
if [ "$1" = "outdated" ]; then
    cat "$PKGUPD_TEST_OUTDATED_JSON"
fi
EOF
chmod +x "$FAKE_BIN/brew"

write_outdated() {
    local formula_version=$1
    local cask_version=$2
    printf '{"formulae":[{"name":"demo-formula","current_version":"%s"}],"casks":[{"name":"demo-cask","current_version":"%s"}]}\n' \
        "$formula_version" "$cask_version" > "$OUTDATED_JSON"
}

run_pkgupd() {
    local now_epoch=$1
    PATH="$FAKE_BIN:$PATH" \
        XDG_STATE_HOME="$STATE_HOME" \
        PKGUPD_COOLDOWN_DAYS=7 \
        PKGUPD_NOW_EPOCH="$now_epoch" \
        PKGUPD_TEST_BREW_LOG="$BREW_LOG" \
        PKGUPD_TEST_OUTDATED_JSON="$OUTDATED_JSON" \
        "$REPO_ROOT/.local/bin/pkgupd" --homebrew-only >/dev/null
}

write_outdated 2.0.0 3.0.0
run_pkgupd 100000
if grep -q '^upgrade ' "$BREW_LOG"; then
    echo "pkgupd upgraded a newly observed version." >&2
    exit 1
fi

: > "$BREW_LOG"
run_pkgupd $((100000 + 7 * 86400 - 1))
if grep -q '^upgrade ' "$BREW_LOG"; then
    echo "pkgupd upgraded before the cooldown elapsed." >&2
    exit 1
fi

write_outdated 2.1.0 3.1.0
: > "$BREW_LOG"
run_pkgupd $((100000 + 7 * 86400))
if grep -q '^upgrade ' "$BREW_LOG"; then
    echo "pkgupd did not reset the cooldown for a new target version." >&2
    exit 1
fi

: > "$BREW_LOG"
run_pkgupd $((100000 + 14 * 86400))
grep -q '^upgrade --formula demo-formula$' "$BREW_LOG"
grep -q '^upgrade --cask demo-cask$' "$BREW_LOG"

echo "pkgupd cooldown tests passed."
