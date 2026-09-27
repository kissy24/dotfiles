#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/nvim-check-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
export NVIM_LOG_FILE="$TMP_ROOT/nvim.log"

"$REPO_ROOT/scripts/run-nvim-check.sh" 'assert(1 + 1 == 2)' --clean -i NONE
"$REPO_ROOT/scripts/run-nvim-check.sh" 'assert(true)' --clean -i NONE \
    --cmd 'lua pcall(vim.keymap.del, "n", "<Plug>(dotfiles-missing-mapping)")'

expect_failure() {
    local message=$1 code=$2
    shift 2
    local status=0
    "$REPO_ROOT/scripts/run-nvim-check.sh" "$code" "$@" > "$TMP_ROOT/output" 2>&1 || status=$?
    test "$status" -eq 1
    grep -Fq "$message" "$TMP_ROOT/output"
}

expect_failure 'intentional assertion failure' \
    'assert(false, "intentional assertion failure")' --clean -i NONE
expect_failure 'intentional module failure' \
    'package.preload["dotfiles-test"] = function() error("intentional module failure") end; require("dotfiles-test")' \
    --clean -i NONE
expect_failure 'expected' 'local =' --clean -i NONE
expect_failure 'intentional command failure' \
    'vim.cmd([[throw "intentional command failure"]])' --clean -i NONE

echo "Neovim check exit-status tests passed."
