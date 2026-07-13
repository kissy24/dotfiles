return {
    {
        "catppuccin/nvim",
        name = "catppuccin",
        lazy = false,
        priority = 1000,
        config = function()
            require("catppuccin").setup({
                flavour = "mocha",
                transparent_background = true,
                float = {
                    transparent = true,
                },
            })

            vim.cmd.colorscheme("catppuccin-mocha")
        end,
    },
    { "lewis6991/gitsigns.nvim", opts = {} },
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown" },
        dependencies = { "nvim-tree/nvim-web-devicons" },
        opts = {},
    },
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
