return {
    {
        'romgrk/barbar.nvim',
        dependencies = {
            'lewis6991/gitsigns.nvim',
            'nvim-tree/nvim-web-devicons',
        },
        event = "BufReadPre",
        init = function() vim.g.barbar_auto_setup = false end,
        opts = {
            exclude_name = {
                "[No Name]",
            },
        },
        keys = {
            { "<Space>h", "<Cmd>BufferPrevious<CR>", mode = "n", { silent = true } },
            { "<Space>l", "<Cmd>BufferNext<CR>",     mode = "n", { silent = true } },
            { "<Space>x", "<Cmd>BufferClose<CR>",    mode = "n", { silent = true } },
        }
    },
}
