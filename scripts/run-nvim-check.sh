#!/bin/bash
set -euo pipefail

# Usage: run-nvim-check.sh 'Lua assertions or setup code' [Neovim arguments...]
check=${1:?Lua check is required}
shift

# :lua errors followed by :qa normally leave Neovim with status 0.
# Catch check errors and explicitly propagate failure to the shell. Do not use
# v:errmsg: plugins can leave a stale error there even after handling it.
DOTFILES_NVIM_CHECK="$check" nvim --headless "$@" -c 'lua
local ok, err = xpcall(function()
    local check = assert(loadstring(vim.env.DOTFILES_NVIM_CHECK))
    check()
end, debug.traceback)
if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
end
' -c 'qa!'
