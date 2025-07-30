return {
    { "dinhhuy258/git.nvim",     opts = {} },
    { "lewis6991/gitsigns.nvim", opts = {} },
    {
        "sindrets/diffview.nvim",
        opts = {},
        keys = {
            { "<leader>hd", "<cmd>DiffviewOpen HEAD~1<CR>",   mode = "n" },
            { "<leader>hf", "<cmd>DiffviewFileHistory %<CR>", mode = "n" },
        }
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
