#!/bin/bash
set -euo pipefail

TMP_ROOT=$(mktemp -d)
TMUX_SESSION="dotfiles-smoke-$$"

cleanup() {
    tmux kill-session -t "$TMUX_SESSION" >/dev/null 2>&1 || true
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

echo "Checking CLI startup..."
git --version >/dev/null
lazygit --version >/dev/null
gh --version >/dev/null
starship prompt >/dev/null
sheldon source >/dev/null

echo "Checking ripgrep search..."
printf 'alpha\nbeta\n' > "$TMP_ROOT/search.txt"
test "$(rg --no-filename '^beta$' "$TMP_ROOT/search.txt")" = "beta"

echo "Checking fzf filtering..."
test "$(printf 'apple\nbanana\n' | fzf --filter=banana)" = "banana"

echo "Checking tmux session lifecycle..."
tmux new-session -d -s "$TMUX_SESSION"
test "$(tmux display-message -p -t "$TMUX_SESSION" '#S')" = "$TMUX_SESSION"
tmux kill-session -t "$TMUX_SESSION"

echo "Checking zoxide database operations..."
mkdir -p "$TMP_ROOT/zoxide-data" "$TMP_ROOT/project"
_ZO_DATA_DIR="$TMP_ROOT/zoxide-data" zoxide add "$TMP_ROOT/project"
test "$(_ZO_DATA_DIR="$TMP_ROOT/zoxide-data" zoxide query project)" = "$TMP_ROOT/project"

echo "Checking Bun execution..."
test "$(bun -e 'console.log(1 + 1)')" = "2"

echo "Checking Go compilation and execution..."
printf 'package main\nimport "fmt"\nfunc main() { fmt.Print("ok") }\n' > "$TMP_ROOT/main.go"
test "$(go run "$TMP_ROOT/main.go")" = "ok"

echo "Checking Python execution through uv..."
test "$(uv run --no-project --python "$(command -v python3)" python -c 'print(1 + 1)')" = "2"

echo "Checking Neovim plugin loading and Bun-managed TypeScript LSP..."
mkdir -p "$TMP_ROOT/typescript"
printf '{"private":true}\n' > "$TMP_ROOT/typescript/package.json"
printf 'const answer: number = 42\n' > "$TMP_ROOT/typescript/smoke.ts"
nvim --headless "$TMP_ROOT/typescript/smoke.ts" \
    "+lua assert(vim.fn.exists(':Lazy') == 2, 'Lazy command is unavailable')" \
    "+lua local attached = vim.wait(15000, function() return #vim.lsp.get_clients({ bufnr = 0, name = 'ts_ls' }) > 0 end, 100); assert(attached, 'ts_ls did not attach')" \
    "+qa"

echo "All smoke tests passed."
