return {
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        opts = {
            direction = "float",
            float_opts = {
                border = "rounded",
                width = math.floor(vim.o.columns * 0.8),
                height = math.floor(vim.o.lines * 0.7),
                winblend = 0,
            },
        },
        keys = {
            { "tm",    "<cmd>ToggleTerm<cr>", mode = "n" },
            { "<ESC>", "<C-\\><C-n>",         mode = "t" },
        }
    },

    {
        "folke/noice.nvim",
        event = "VeryLazy",
        opts = {},
        dependencies = {
            "MunifTanjim/nui.nvim",
            {
                "rcarriga/nvim-notify",
                config = function()
                    require("notify").setup({
                        -- notify.nvim のオプション
                        background_colour = "#000000",
                        stages = "fade_in_slide_out",
                        timeout = 3000,
                        -- ここに他の notify オプション追加可能
                    })
                end,
            },
        }
    },

    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {},
        keys = {
            {
                "<leader>?",
                function()
                    require("which-key").show({ global = false })
                end,
                desc = "Buffer Local Keymaps (which-key)",
            },
        },
    },

    { "windwp/nvim-autopairs", config = true, lazy = false },

    { "monaqa/dial.nvim" },
}
