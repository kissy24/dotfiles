#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/pkgupd-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT

FAKE_BIN=$TMP_ROOT/bin
TEST_HOME=$TMP_ROOT/home
MISE_LOG=$TMP_ROOT/mise.log
mkdir -p "$FAKE_BIN" "$TEST_HOME/.local/bin"

cat > "$FAKE_BIN/mise" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s|%s\n' "$PWD" "$*" >> "$PKGUPD_TEST_MISE_LOG"
if [ "${1:-}" = "--version" ]; then
    echo "2026.7.7 test"
fi
EOF
chmod +x "$FAKE_BIN/mise"

ln -s "$REPO_ROOT/.local/bin/pkgupd" "$TEST_HOME/.local/bin/pkgupd"
ln -s "$FAKE_BIN/mise" "$TEST_HOME/.local/bin/mise"

HOME="$TEST_HOME" \
    PATH="$FAKE_BIN:/usr/bin:/bin" \
    PKGUPD_TEST_MISE_LOG="$MISE_LOG" \
    "$TEST_HOME/.local/bin/pkgupd" --tools-only >/dev/null

grep -Fqx "$REPO_ROOT|install --locked" "$MISE_LOG"

if HOME="$TEST_HOME" \
    PATH="$FAKE_BIN:/usr/bin:/bin" \
    PKGUPD_TEST_MISE_LOG="$MISE_LOG" \
    "$TEST_HOME/.local/bin/pkgupd" --homebrew-only >/dev/null 2>&1; then
    echo "pkgupd accepted the removed --homebrew-only option." >&2
    exit 1
fi

echo "pkgupd mise tests passed."
