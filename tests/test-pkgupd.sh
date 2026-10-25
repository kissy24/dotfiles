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
if [ "$1" = "${PKGUPD_TEST_BREW_FAILURE:-}" ]; then
    exit 1
fi
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

# Simulate Linux without invoking the host's package managers or sudo.
APT_LOG=$TMP_ROOT/apt.log
cat > "$FAKE_BIN/uname" <<'EOF'
#!/bin/sh
echo Linux
EOF
cat > "$FAKE_BIN/apt-get" <<'EOF'
#!/bin/sh
exit 0
EOF
cat > "$FAKE_BIN/sudo" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PKGUPD_TEST_APT_LOG"
if [ "$2" = "${PKGUPD_TEST_APT_FAILURE:-}" ]; then
    exit 1
fi
EOF
chmod +x "$FAKE_BIN/uname" "$FAKE_BIN/apt-get" "$FAKE_BIN/sudo"

run_linux_pkgupd() {
    local brew_failure=$1 apt_failure=$2
    shift 2
    : > "$BREW_LOG"
    : > "$APT_LOG"
    local status=0
    PATH="$FAKE_BIN:$PATH" \
        XDG_STATE_HOME="$STATE_HOME" \
        PKGUPD_COOLDOWN_DAYS=0 \
        PKGUPD_TEST_BREW_LOG="$BREW_LOG" \
        PKGUPD_TEST_OUTDATED_JSON="$OUTDATED_JSON" \
        PKGUPD_TEST_APT_LOG="$APT_LOG" \
        PKGUPD_TEST_BREW_FAILURE="$brew_failure" \
        PKGUPD_TEST_APT_FAILURE="$apt_failure" \
        "$REPO_ROOT/.local/bin/pkgupd" "$@" > "$TMP_ROOT/output" 2>&1 || status=$?
    test "$status" -eq "${EXPECTED_STATUS:-1}"
}

for failure in update outdated upgrade cleanup; do
    run_linux_pkgupd "$failure" ''
    grep -qx 'apt-get upgrade -y' "$APT_LOG"
    grep -qx 'apt-get autoclean' "$APT_LOG"
    grep -q 'Homebrew=1 APT=0' "$TMP_ROOT/output"
    if [ "$failure" != cleanup ] && grep -qx cleanup "$BREW_LOG"; then
        echo "Homebrew continued after a failed $failure command." >&2
        exit 1
    fi
done

run_linux_pkgupd '' update
grep -qx cleanup "$BREW_LOG"
test "$(wc -l < "$APT_LOG" | tr -d ' ')" = 1
grep -q 'Homebrew=0 APT=1' "$TMP_ROOT/output"

run_linux_pkgupd update update
grep -qx 'apt-get update' "$APT_LOG"
grep -q 'Homebrew=1 APT=1' "$TMP_ROOT/output"

run_linux_pkgupd update '' --homebrew-only
test ! -s "$APT_LOG"
EXPECTED_STATUS=0 run_linux_pkgupd '' ''
grep -qx cleanup "$BREW_LOG"
grep -qx 'apt-get autoclean' "$APT_LOG"

echo "pkgupd isolates Homebrew and APT failures and reports their status."
