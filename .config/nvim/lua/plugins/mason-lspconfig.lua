return {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
        "williamboman/mason.nvim",
        "neovim/nvim-lspconfig", -- Configure capabilities and servers before automatic enablement.
    },
    opts = {
        dotfiles_versions = {
            "lua_ls@3.19.2",   -- Lua
            "marksman@2026-02-08", -- Markdown
            "gopls@v0.24.0",    -- Go
        },
        ensure_installed = {},
        automatic_enable = true,
    },
}
