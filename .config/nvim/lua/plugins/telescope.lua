local function picker(name, title, scoped)
    return function()
        local opts = { prompt_title = title }
        if scoped then
            opts.cwd = vim.fn.getcwd()
            opts.prompt_title = title .. " [" .. vim.fn.fnamemodify(opts.cwd, ":~") .. "]"
        end
        require("telescope.builtin")[name](opts)
    end
end

return {
    {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        cmd = "Telescope",
        keys = {
            { "<leader>ff", picker("find_files", "Files", true), desc = "Find files / ファイル検索" },
            { "<leader>fg", picker("live_grep", "Text (literal)", true), desc = "Find text / 文字列検索" },
            { "<leader>fb", picker("buffers", "Buffers"), desc = "Find buffers / 開いたファイル" },
            { "<leader>fh", picker("help_tags", "Help"), desc = "Find help / Neovimヘルプ" },
            { "<leader>fk", picker("keymaps", "Keymaps"), desc = "Find keymaps / キー操作一覧" },
            { "<leader>fr", function() require("telescope.builtin").resume() end,
                desc = "Resume search / 前の検索を再開" },
        },
        opts = function()
            local actions = require("telescope.actions")
            local toggle_preview = require("telescope.actions.layout").toggle_preview
            local help = {
                function(bufnr)
                    -- The pinned picker only names n/i; completion submodes also need help.
                    actions.which_key(bufnr, { only_show_current_mode = false })
                end,
                type = "action",
                opts = { desc = "Show picker help" },
            }
            return {
                defaults = {
                    sorting_strategy = "ascending",
                    layout_strategy = "horizontal",
                    layout_config = {
                        width = 0.9,
                        height = 0.85,
                        prompt_position = "top",
                        preview_width = 0.5,
                        preview_cutoff = 100,
                    },
                    results_title = "Enter: open | Esc: close | F1: help",
                    mappings = {
                        i = { ["<Esc>"] = actions.close, ["<F1>"] = help,
                            ["<F4>"] = toggle_preview },
                        n = { ["<Esc>"] = actions.close, ["<F1>"] = help,
                            ["<F4>"] = toggle_preview },
                    },
                    preview = {
                        filesize_limit = 1,
                        -- Avoid the pinned previewer's shell-based `file` invocation.
                        check_mime_type = false,
                    },
                    vimgrep_arguments = {
                        "rg", "--no-config", "--color=never", "--no-heading", "--with-filename",
                        "--line-number", "--column", "--smart-case", "--fixed-strings",
                        "--hidden", "--no-follow", "--glob", "!.git",
                    },
                },
                pickers = {
                    find_files = {
                        find_command = { "rg", "--no-config", "--files", "--hidden",
                            "--no-follow", "--glob", "!.git" },
                    },
                    buffers = { sort_mru = true, ignore_current_buffer = false },
                },
            }
        end,
    },
}
