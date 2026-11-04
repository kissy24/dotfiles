-- Verify that splitting plugin specs preserves startup configuration and dependencies.
assert(vim.g.colors_name == "catppuccin-mocha", "Catppuccin did not initialize")
assert(package.loaded["gitsigns"], "Gitsigns did not initialize")
assert(require("mason").has_setup, "Mason did not initialize")
assert(require("mason.settings").current.ui.icons.package_installed == "✓", "Mason options were lost")

local mason_lsp = require("mason-lspconfig.settings").current
assert(mason_lsp.automatic_enable == true, "Mason LSP automatic enablement was lost")
assert(vim.deep_equal(mason_lsp.ensure_installed, {}), "Editor startup must not install language servers")
local pins = require("plugins.mason-lspconfig").opts.dotfiles_versions
assert(#pins == 3, "Mason language server selection changed")
for _, spec in ipairs(pins) do
    assert(spec:match("^[^@]+@[^@]+$"), "Mason language server must have an exact version")
end

local lsp = vim.lsp.config
assert(lsp.lua_ls.settings.Lua.diagnostics.globals[1] == "vim", "Lua LSP settings were lost")
assert(lsp.gopls.settings.gopls.staticcheck, "Go LSP settings were lost")
assert(vim.lsp.protocol.make_client_capabilities().textDocument.completion.completionItem.snippetSupport,
    "LSP completion capabilities were lost")
for _, name in ipairs({ "ts_ls", "html", "cssls", "jsonls", "pyright" }) do
    assert(lsp[name].cmd[1] == "bun", name .. " no longer uses Bun")
    assert(vim.lsp.is_enabled(name), name .. " was not enabled")
end
assert(#vim.api.nvim_get_autocmds({ event = "LspAttach" }) > 0, "LSP attach handler was lost")

local plugins = require("lazy.core.config").plugins
for _, name in ipairs({ "nvim-cmp", "cmp-buffer", "cmp-path", "cmp-cmdline", "cmp-nvim-lsp",
    "fidget.nvim", "git-blame.nvim" }) do
    assert(not plugins[name], name .. " must not be installed")
end
assert(not plugins["lazygit.nvim"]._.loaded, "LazyGit should remain lazy-loaded")
assert(vim.fn.exists(":LazyGit") == 2, "LazyGit command was not registered")
assert(vim.fn.maparg("<leader>lg", "n") ~= "", "LazyGit mapping was lost")

print("Neovim plugin initialization tests passed.")
