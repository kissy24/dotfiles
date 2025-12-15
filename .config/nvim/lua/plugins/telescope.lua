return {
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.8",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "ff", "<cmd>lua require('telescope.builtin').find_files()<cr>", mode = "n" },
            { "fg", "<cmd>lua require('telescope.builtin').live_grep()<cr>",  mode = "n" },
            { "fb", "<cmd>lua require('telescope.builtin').buffers()<cr>",    mode = "n" },
            { "fn", "<cmd>lua require('telescope.builtin').help_tags()<cr>",  mode = "n" },
        },
        opts = {
            defaults = {
                vimgrep_arguments = {
                    "rg",
                    "--color=never",
                    "--no-heading",
                    "--with-filename",
                    "--line-number",
                    "--column",
                    "--smart-case",
                    "--hidden",
                    "--glob",
                    "!.git/*",
                },
            },
            pickers = {
                find_files = {
                    hidden = true, -- find_filesでも隠しファイルを表示
                    -- find_command も明示的に指定する場合（オプション）
                    find_command = { "rg", "--files", "--hidden", "--glob", "!.git/*" },
                },
            },
        },
    },
}
