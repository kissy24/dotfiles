#!/bin/bash
set -euo pipefail

case "$#:${1-}" in
    0:|1:--before-setup)
        echo "Checking configuration deployment, setup policy, and dependency cooldown..."
        ./tests/test-dotfile-links.sh
        ./tests/test-config-deployment.sh
        PYTHONDONTWRITEBYTECODE=1 python3 tests/test_config_parent_links.py
        ./tests/test-setup-policy.sh
        ./tests/test-dependency-cooldown.sh
        if [ "$#" -eq 1 ]; then exit 0; fi
        ;;
    1:--after-setup) ;;
    *) echo "Usage: $0 [--before-setup|--after-setup]" >&2; exit 2 ;;
esac

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

python3 tests/test_bootstrap_wheels.py

echo "Checking Neovim failure propagation..."
./tests/test-nvim-check.sh

echo "Checking locked Neovim plugin revisions..."
./scripts/run-nvim-check.sh 'dofile("tests/test-nvim-lock.lua")'

echo "Checking Neovim plugin initialization..."
./scripts/run-nvim-check.sh 'dofile("tests/test-nvim-plugin-init.lua")'

echo "Checking Telescope search, previews, and keymaps..."
nvim --headless -u NONE -i NONE -l tests/test-telescope.lua

echo "Checking native completion, LSP progress, and Gitsigns blame..."
nvim --headless -u NONE -i NONE -l tests/test-native-editor.lua

echo "Checking CLI startup..."
git --version >/dev/null
lazygit --version >/dev/null
gh --version >/dev/null
sheldon source >/dev/null

echo "Checking the Zsh prompt..."
ZDOTDIR="$TMP_ROOT" zsh -df tests/test-zsh-prompt.zsh "$TMP_ROOT"

echo "Checking cached Zsh completions..."
ZSH_COMPLETION_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/zsh"
test -s "$ZSH_COMPLETION_DIR/uv.zsh"
test -s "$ZSH_COMPLETION_DIR/herdr.zsh"
zsh -dfc 'autoload -Uz compinit && compinit -i; source "$1"; source "$2"' \
    _ "$ZSH_COMPLETION_DIR/uv.zsh" "$ZSH_COMPLETION_DIR/herdr.zsh"

echo "Checking Zsh completion permission checks..."
./tests/test-zsh-completion.sh

echo "Checking Zsh environment initialization with an existing Cargo environment..."
mkdir -p "$TMP_ROOT/zsh-home/.cargo"
printf 'export DOTFILES_TEST_CARGO_LOADED=1\n' > "$TMP_ROOT/zsh-home/.cargo/env"
HOME="$TMP_ROOT/zsh-home" ZDOTDIR="$TMP_ROOT/zsh-home" zsh -dfc '
    unset DOTFILES_TEST_CARGO_LOADED skip_global_compinit
    source "$1" || exit 1
    [[ "$skip_global_compinit" = 1 && -z "${DOTFILES_TEST_CARGO_LOADED:-}" ]]
' _ "$PWD/.zshenv"

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

editor_popup=$(bun -e '
    import assert from "node:assert/strict";
    import config from "./.config/herdr/config.toml";
    assert.equal(config.keys.prefix, "ctrl+b");
    for (const [key, tool] of [["prefix+ctrl+g", "lazygit"], ["prefix+ctrl+e", "nvim"]]) {
        const bindings = config.keys.command.filter(binding => binding.key === key);
        assert.equal(bindings.length, 1, key);
        assert.equal(bindings[0].type, "popup", key);
        assert.equal(bindings[0].command.split(" ")[0], tool, key);
        if (tool === "nvim") console.log(bindings[0].command);
    }
')
(
    cd "$TMP_ROOT/project"
    sh -c "$editor_popup \"\$@\"" _ --headless -i NONE \
        -c 'if &filetype !=# "oil" || bufname() !=# "oil://" . getcwd() . "/" | cquit 1 | endif' -c qa
)
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
./tests/test-wezterm-herdr-fallback.sh

echo "Checking zoxide database operations..."
mkdir -p "$TMP_ROOT/zoxide-data"
_ZO_DATA_DIR="$TMP_ROOT/zoxide-data" zoxide add "$TMP_ROOT/project"
test "$(_ZO_DATA_DIR="$TMP_ROOT/zoxide-data" zoxide query project)" = "$TMP_ROOT/project"

echo "Checking Bun execution..."
test "$(bun -e 'console.log(1 + 1)')" = "2"

echo "Checking publication-aware updates and unknown-date notifications..."
./tests/test-pkgupd.sh

echo "Checking Go compilation and execution..."
printf 'package main\nimport "fmt"\nfunc main() { fmt.Print("ok") }\n' > "$TMP_ROOT/main.go"
test "$(go run "$TMP_ROOT/main.go")" = "ok"

echo "Checking Python execution through uv..."
test "$(uv run --no-project --python "$(command -v python3)" python -c 'print(1 + 1)')" = "2"

echo "Checking that JS and TS buffers keep ts_ls disabled..."
mkdir -p "$TMP_ROOT/typescript"
printf '{"private":true}\n' > "$TMP_ROOT/typescript/package.json"
for ext in js jsx ts tsx; do
    touch "$TMP_ROOT/typescript/smoke.$ext"
    ./scripts/run-nvim-check.sh '
        assert(not vim.lsp.is_enabled("ts_ls"), "ts_ls was enabled")
        assert(#vim.lsp.get_clients({ name = "ts_ls" }) == 0, "ts_ls started")
    ' "$TMP_ROOT/typescript/smoke.$ext"
done

echo "Checking Python, HTML, CSS, and JSON language servers through Bun..."
mkdir -p "$TMP_ROOT/bun-lsp"
git -C "$TMP_ROOT/bun-lsp" init -q
# An invalid project-local runtime config must not prevent any managed LSP from starting.
printf '[invalid TOML\n' > "$TMP_ROOT/bun-lsp/bunfig.toml"
printf '{"typeCheckingMode":"basic"}\n' > "$TMP_ROOT/bun-lsp/pyrightconfig.json"
printf 'answer: int = "wrong"\n' > "$TMP_ROOT/bun-lsp/smoke.py"
printf '<!doctype html><html><body>smoke</body></html>\n' > "$TMP_ROOT/bun-lsp/smoke.html"
printf 'body { color: red; }\n' > "$TMP_ROOT/bun-lsp/smoke.css"
printf '{"answer":42}\n' > "$TMP_ROOT/bun-lsp/smoke.json"
for spec in pyright:py html:html cssls:css jsonls:json; do
    (
        repo_root=$PWD
        cd "$TMP_ROOT/bun-lsp"
        DOTFILES_TEST_LSP="${spec%%:*}" DOTFILES_TEST_ROOT="$repo_root" "$repo_root/scripts/run-nvim-check.sh" \
            'dofile(vim.env.DOTFILES_TEST_ROOT .. "/tests/test-bun-lsp.lua")' "smoke.${spec##*:}"
    )
done

echo "Checking Neovim Markdown rendering with bundled parsers..."
mkdir -p "$TMP_ROOT/markdown"
cp tests/fixtures/markdown.md "$TMP_ROOT/markdown/smoke.md"
./scripts/run-nvim-check.sh 'dofile("tests/test-markdown-render.lua")' "$TMP_ROOT/markdown/smoke.md"

echo "Checking the Oil floating explorer and file navigation..."
mkdir -p "$TMP_ROOT/oil/child"
printf 'Oil float test\n' > "$TMP_ROOT/oil/child/file with spaces.txt"
DOTFILES_OIL_TEST_DIR="$TMP_ROOT/oil" ./scripts/run-nvim-check.sh \
    'dofile("tests/test-oil-float.lua")'

echo "All smoke tests passed."
