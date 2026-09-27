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

echo "Checking setup backups and GitHub CLI migration..."
./scripts/test-dotfile-links.sh

echo "Checking Neovim failure propagation..."
./scripts/test-nvim-check.sh

echo "Checking CLI startup..."
git --version >/dev/null
lazygit --version >/dev/null
gh --version >/dev/null
tree-sitter --version >/dev/null
STARSHIP_CONFIG="$PWD/.config/starship.toml" \
    starship prompt --cmd-duration 500 >/dev/null
sheldon source >/dev/null

echo "Checking cached Zsh completions..."
ZSH_COMPLETION_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/zsh"
test -s "$ZSH_COMPLETION_DIR/uv.zsh"
test -s "$ZSH_COMPLETION_DIR/herdr.zsh"
zsh -dfc 'autoload -Uz compinit && compinit -C; source "$1"; source "$2"' \
    _ "$ZSH_COMPLETION_DIR/uv.zsh" "$ZSH_COMPLETION_DIR/herdr.zsh"
test "$(zsh -dfc 'source "$1"; print -r -- "$skip_global_compinit"' _ "$PWD/.zshenv")" = 1

echo "Checking safe WSL configuration installation..."
WSL_CONFIG_DEST="$TMP_ROOT/windows/.wslconfig" DOTFILES_TEST_WSL=1 \
    ./scripts/install-wsl-config.sh
cmp .wslconfig "$TMP_ROOT/windows/.wslconfig"
printf 'sentinel\n' > "$TMP_ROOT/windows/.wslconfig"
WSL_CONFIG_DEST="$TMP_ROOT/windows/.wslconfig" DOTFILES_TEST_WSL=1 \
    ./scripts/install-wsl-config.sh
test "$(cat "$TMP_ROOT/windows/.wslconfig")" = sentinel
WSL_CONFIG_DEST="$TMP_ROOT/windows/.wslconfig" DOTFILES_TEST_WSL=1 \
    ./scripts/install-wsl-config.sh 1
cmp .wslconfig "$TMP_ROOT/windows/.wslconfig"
grep -qx sentinel "$TMP_ROOT"/windows/.wslconfig.backup-*/original
WSL_CONFIG_DEST="$TMP_ROOT/windows/.wslconfig" DOTFILES_TEST_WSL=1 \
    ./scripts/install-wsl-config.sh remove
test ! -e "$TMP_ROOT/windows/.wslconfig"

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

echo "Checking WezTerm fallback after Herdr startup failure..."
./scripts/test-wezterm-herdr-fallback.sh

echo "Checking zoxide database operations..."
mkdir -p "$TMP_ROOT/zoxide-data"
_ZO_DATA_DIR="$TMP_ROOT/zoxide-data" zoxide add "$TMP_ROOT/project"
test "$(_ZO_DATA_DIR="$TMP_ROOT/zoxide-data" zoxide query project)" = "$TMP_ROOT/project"

echo "Checking Bun execution..."
test "$(bun -e 'console.log(1 + 1)')" = "2"

echo "Checking package update cooldown..."
./scripts/test-pkgupd.sh

echo "Checking Go compilation and execution..."
printf 'package main\nimport "fmt"\nfunc main() { fmt.Print("ok") }\n' > "$TMP_ROOT/main.go"
test "$(go run "$TMP_ROOT/main.go")" = "ok"

echo "Checking Python execution through uv..."
test "$(uv run --no-project --python "$(command -v python3)" python -c 'print(1 + 1)')" = "2"

echo "Checking configured Tree-sitter parsers..."
./scripts/run-nvim-check.sh '
local treesitter = require("nvim-treesitter")
local installed = treesitter.get_installed("parsers")
for _, lang in ipairs(require("plugins.treesitter")[1].opts.parsers) do
    assert(vim.list_contains(installed, lang), lang .. " parser is not managed by nvim-treesitter")
    assert(vim.treesitter.language.add(lang), lang .. " parser is unavailable")
    assert(#vim.treesitter.get_string_parser("", lang):parse() > 0, lang .. " parsing failed")
end
'

echo "Checking Neovim plugin loading, TypeScript parsing, and Bun-managed LSP..."
mkdir -p "$TMP_ROOT/typescript"
printf '{"private":true}\n' > "$TMP_ROOT/typescript/package.json"
printf 'const answer: number = 42\n' > "$TMP_ROOT/typescript/smoke.ts"
./scripts/run-nvim-check.sh '
assert(vim.fn.exists(":Lazy") == 2, "Lazy command is unavailable")
local parser = vim.treesitter.get_parser(0, "typescript")
assert(#parser:parse() > 0, "TypeScript parsing failed")
local attached = vim.wait(15000, function()
    local clients = vim.lsp.get_clients({ bufnr = 0, name = "ts_ls" })
    return #clients > 0 and clients[1].initialized
end, 100)
assert(attached, "ts_ls did not initialize")
' "$TMP_ROOT/typescript/smoke.ts"

echo "Checking Neovim Markdown rendering with managed parsers..."
mkdir -p "$TMP_ROOT/markdown"
printf '# Smoke test\n\n- Markdown rendering\n' > "$TMP_ROOT/markdown/smoke.md"
./scripts/run-nvim-check.sh '
assert(vim.treesitter.language.add("markdown"), "managed markdown parser is unavailable")
assert(vim.treesitter.language.add("markdown_inline"), "managed markdown_inline parser is unavailable")
local parser = vim.treesitter.get_parser(0, "markdown")
assert(#parser:parse() > 0, "Markdown parsing failed")
assert(package.loaded["render-markdown"], "render-markdown.nvim did not load")
assert(vim.fn.exists(":RenderMarkdown") == 2, "RenderMarkdown command is unavailable")
' "$TMP_ROOT/markdown/smoke.md"

echo "All smoke tests passed."
