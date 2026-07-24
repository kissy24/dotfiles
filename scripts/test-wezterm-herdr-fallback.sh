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

marker="$TMP_ROOT/fallback"
test "${launch_command%exec zsh -l}" != "$launch_command"
test_launch_command="${launch_command%exec zsh -l}: > \"\${HERDR_TEST_FALLBACK_MARKER}\""
IFS= read -r -d '' test_harness <<'EOF' || true
herdr() { return "$HERDR_TEST_STATUS"; }
eval "$HERDR_TEST_LAUNCH_COMMAND"
EOF

HERDR_TEST_LAUNCH_COMMAND="$test_launch_command" \
    HERDR_TEST_STATUS=0 \
    HERDR_TEST_FALLBACK_MARKER="$marker" \
    "$ZSH_BIN" -fc "$test_harness"
test ! -e "$marker"

HERDR_TEST_LAUNCH_COMMAND="$test_launch_command" \
    HERDR_TEST_STATUS=1 \
    HERDR_TEST_FALLBACK_MARKER="$marker" \
    "$ZSH_BIN" -fc "$test_harness" 2>"$TMP_ROOT/stderr"
test -e "$marker"
grep -Fq "hrrでセッションを再起動できます" "$TMP_ROOT/stderr"

echo "WezTerm Herdr fallback tests passed."
