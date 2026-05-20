return {
    {
        'projekt0n/github-nvim-theme',
        name = 'github-theme',
        lazy = false,
        priority = 1000,
        config = function()
            require('github-theme').setup({
                options = {
                    transparent = true,
                }
            })
            vim.cmd([[colorscheme github_dark_dimmed]])
        end,
    },
    { "lewis6991/gitsigns.nvim", opts = {} },
    {
        "kdheepak/lazygit.nvim",
        lazy = true,
        cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = { { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" } },
    },
    {
        "f-person/git-blame.nvim",
        event = "VeryLazy",
        opts = {
            enabled = true,
            message_template = " <summary> • <date> • <author> • <<sha>>",
            date_format = "%Y-%m-%d %H:%M:%S",
            virtual_text_column = 1,
        }
    },
}
