return {
    "williamboman/mason-lspconfig.nvim",
    dependencies = {
        "williamboman/mason.nvim",
        "neovim/nvim-lspconfig", -- Configure capabilities and servers before automatic enablement.
    },
    opts = {
        ensure_installed = {},
        automatic_enable = { exclude = { "ts_ls", "lua_ls", "marksman", "gopls" } },
    },
}
