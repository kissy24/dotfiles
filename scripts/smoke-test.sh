#!/bin/bash
set -euo pipefail

TMP_ROOT=$(mktemp -d /tmp/dotfiles-smoke.XXXXXX)
HERDR_SESSION_NAME="dotfiles-smoke-$$"
HERDR_SERVER_PID=""
HERDR_TEST_CONFIG="$TMP_ROOT/config/herdr/config.toml"

cleanup() {
    HERDR_CONFIG_PATH="$HERDR_TEST_CONFIG" \
        XDG_CONFIG_HOME="$TMP_ROOT/config" \
        herdr session stop "$HERDR_SESSION_NAME" >/dev/null 2>&1 || true
    if [ -n "$HERDR_SERVER_PID" ]; then
        kill "$HERDR_SERVER_PID" >/dev/null 2>&1 || true
        wait "$HERDR_SERVER_PID" >/dev/null 2>&1 || true
    fi
    rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

echo "Checking CLI startup..."
git --version >/dev/null
lazygit --version >/dev/null
gh --version >/dev/null
STARSHIP_CONFIG="$PWD/.config/starship.toml" \
    starship prompt --cmd-duration 500 >/dev/null
sheldon source >/dev/null

echo "Checking ripgrep search..."
printf 'alpha\nbeta\n' > "$TMP_ROOT/search.txt"
test "$(rg --no-filename '^beta$' "$TMP_ROOT/search.txt")" = "beta"

echo "Checking fzf filtering..."
test "$(printf 'apple\nbanana\n' | fzf --filter=banana)" = "banana"

echo "Checking Herdr configuration and session lifecycle..."
mkdir -p "$TMP_ROOT/config/herdr" "$TMP_ROOT/project"
cp "$PWD/.config/herdr/config.toml" "$HERDR_TEST_CONFIG"
HERDR_CONFIG_PATH="$HERDR_TEST_CONFIG" \
    XDG_CONFIG_HOME="$TMP_ROOT/config" \
    herdr --session "$HERDR_SESSION_NAME" server >/dev/null 2>&1 &
HERDR_SERVER_PID=$!
for _ in {1..50}; do
    if HERDR_CONFIG_PATH="$HERDR_TEST_CONFIG" \
        XDG_CONFIG_HOME="$TMP_ROOT/config" \
        herdr --session "$HERDR_SESSION_NAME" workspace list >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
HERDR_CONFIG_PATH="$HERDR_TEST_CONFIG" \
    XDG_CONFIG_HOME="$TMP_ROOT/config" \
    herdr --session "$HERDR_SESSION_NAME" workspace list >/dev/null
HERDR_CONFIG_PATH="$HERDR_TEST_CONFIG" \
    XDG_CONFIG_HOME="$TMP_ROOT/config" \
    herdr --session "$HERDR_SESSION_NAME" workspace create \
        --cwd "$TMP_ROOT/project" \
        --label project \
        --focus >/dev/null
HERDR_CONFIG_PATH="$HERDR_TEST_CONFIG" \
    XDG_CONFIG_HOME="$TMP_ROOT/config" \
    herdr --session "$HERDR_SESSION_NAME" workspace list | grep -q project
HERDR_CONFIG_PATH="$HERDR_TEST_CONFIG" \
    XDG_CONFIG_HOME="$TMP_ROOT/config" \
    herdr session stop "$HERDR_SESSION_NAME" >/dev/null
wait "$HERDR_SERVER_PID"
HERDR_SERVER_PID=""

echo "Checking zoxide database operations..."
mkdir -p "$TMP_ROOT/zoxide-data"
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
    "+lua local attached = vim.wait(15000, function() local clients = vim.lsp.get_clients({ bufnr = 0, name = 'ts_ls' }); return #clients > 0 and clients[1].initialized end, 100); assert(attached, 'ts_ls did not initialize')" \
    "+qa"

echo "Checking Neovim Markdown rendering with built-in parsers..."
mkdir -p "$TMP_ROOT/markdown"
printf '# Smoke test\n\n- Markdown rendering\n' > "$TMP_ROOT/markdown/smoke.md"
nvim --headless "$TMP_ROOT/markdown/smoke.md" \
    "+lua assert(vim.treesitter.language.add('markdown'), 'built-in markdown parser is unavailable')" \
    "+lua assert(vim.treesitter.language.add('markdown_inline'), 'built-in markdown_inline parser is unavailable')" \
    "+lua local parser = vim.treesitter.get_parser(0, 'markdown'); assert(#parser:parse() > 0, 'Markdown parsing failed')" \
    "+lua assert(package.loaded['render-markdown'], 'render-markdown.nvim did not load')" \
    "+lua assert(vim.fn.exists(':RenderMarkdown') == 2, 'RenderMarkdown command is unavailable')" \
    "+qa"

echo "All smoke tests passed."
