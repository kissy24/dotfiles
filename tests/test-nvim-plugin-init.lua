-- Verify that splitting plugin specs preserves startup configuration and dependencies.
assert(vim.g.colors_name == "catppuccin-mocha", "Catppuccin did not initialize")
assert(package.loaded["gitsigns"], "Gitsigns did not initialize")
assert(package.loaded["fidget"], "Fidget did not initialize")
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
assert(lsp.ts_ls.capabilities.textDocument.completion.completionItem.snippetSupport,
    "LSP completion capabilities were lost")
for _, name in ipairs({ "ts_ls", "html", "cssls", "jsonls", "pyright" }) do
    assert(lsp[name].cmd[1] == "bun", name .. " no longer uses Bun")
    assert(vim.lsp.is_enabled(name), name .. " was not enabled")
end
assert(#vim.api.nvim_get_autocmds({ event = "LspAttach" }) > 0, "LSP attach handler was lost")

local cmp = require("cmp")
local function source_names(sources)
    return vim.tbl_map(function(source) return source.name end, sources)
end
assert(vim.deep_equal(source_names(cmp.get_config().sources), { "nvim_lsp", "buffer" }),
    "Insert-mode completion sources changed")
local cmdline = require("cmp.config").cmdline
for _, mode in ipairs({ "/", "?" }) do
    assert(vim.deep_equal(source_names(cmdline[mode].sources), { "buffer" }),
        "Search completion sources changed")
end
assert(vim.deep_equal(source_names(cmdline[":"].sources), { "path", "cmdline" }),
    "Command-line completion sources changed")

local plugins = require("lazy.core.config").plugins
assert(not plugins["lazygit.nvim"]._.loaded, "LazyGit should remain lazy-loaded")
assert(vim.fn.exists(":LazyGit") == 2, "LazyGit command was not registered")
assert(vim.fn.maparg("<leader>lg", "n") ~= "", "LazyGit mapping was lost")

print("Neovim plugin initialization tests passed.")
