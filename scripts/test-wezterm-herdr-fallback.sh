#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/wezterm-herdr-test.XXXXXX")
ZSH_BIN=$(command -v zsh)
trap 'rm -rf "$TMP_ROOT"' EXIT

launch_command=$(
    sed -n 's/^local launch_command = "\(.*\)"$/\1/p' \
        "$REPO_ROOT/.config/wezterm/wezterm.lua" |
        sed 's/\\\\/\\/g'
)
test -n "$launch_command"

mkdir -p "$TMP_ROOT/bin"
cat > "$TMP_ROOT/bin/herdr" <<'EOF'
#!/bin/sh
exit "${HERDR_TEST_STATUS:-0}"
EOF
cat > "$TMP_ROOT/bin/zsh" <<'EOF'
#!/bin/sh
: > "$HERDR_TEST_FALLBACK_MARKER"
EOF
chmod +x "$TMP_ROOT/bin/herdr" "$TMP_ROOT/bin/zsh"

marker="$TMP_ROOT/fallback"
PATH="$TMP_ROOT/bin:/usr/bin:/bin" \
    HERDR_TEST_STATUS=0 \
    HERDR_TEST_FALLBACK_MARKER="$marker" \
    "$ZSH_BIN" -fc "$launch_command"
test ! -e "$marker"

PATH="$TMP_ROOT/bin:/usr/bin:/bin" \
    HERDR_TEST_STATUS=1 \
    HERDR_TEST_FALLBACK_MARKER="$marker" \
    "$ZSH_BIN" -fc "$launch_command" 2>"$TMP_ROOT/stderr"
test -e "$marker"
grep -Fq "hrrでセッションを再起動できます" "$TMP_ROOT/stderr"

echo "WezTerm Herdr fallback tests passed."
