return {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
        "williamboman/mason.nvim",
        "neovim/nvim-lspconfig", -- Configure capabilities and servers before automatic enablement.
    },
    opts = {
        ensure_installed = {
            "lua_ls",   -- Lua
            "marksman", -- Markdown
            "gopls",    -- Go
        },
        automatic_enable = true,
    },
}
