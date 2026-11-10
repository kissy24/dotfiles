return {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    keys = {
        { "<leader>ff", "<cmd>FzfLua files<cr>", desc = "Find files / ファイル検索" },
        { "<leader>fg", "<cmd>FzfLua live_grep<cr>", desc = "Find text / 文字列検索" },
        { "<leader>fb", "<cmd>FzfLua buffers<cr>", desc = "Find buffers / 開いたファイル" },
        { "<leader>fh", "<cmd>FzfLua helptags<cr>", desc = "Find help / Neovimヘルプ" },
        { "<leader>fk", "<cmd>FzfLua keymaps<cr>", desc = "Find keymaps / キー操作一覧" },
        { "<leader>fr", "<cmd>FzfLua resume<cr>", desc = "Resume search / 前の検索を再開" },
        -- Keep the existing Telescope shortcuts during migration.
        { "ff", "<cmd>FzfLua files<cr>", desc = "Find files (legacy)" },
        { "fg", "<cmd>FzfLua live_grep<cr>", desc = "Find text (legacy)" },
        { "fb", "<cmd>FzfLua buffers<cr>", desc = "Find buffers (legacy)" },
        { "fn", "<cmd>FzfLua helptags<cr>", desc = "Find help (legacy)" },
    },
    opts = {
        -- Reuse Brewfile's fzf and rg; no build hook or optional plugins.
        fzf_bin = "fzf",
        defaults = {
            file_icons = false,
            git_icons = false,
            header = "Enter: open | Esc: cancel | F1: help | F4: preview",
        },
        winopts = {
            height = 0.85,
            width = 0.90,
            border = "rounded",
            preview = { layout = "flex", flip_columns = 120 },
        },
        fzf_opts = {
            ["--layout"] = "reverse",
            ["--info"] = "inline-right",
            ["--history"] = false, -- Do not persist search text to an fzf history file.
            ["--no-history"] = true, -- Also override a history path inherited from the shell.
        },
        keymap = {
            fzf = { true, ["ctrl-n"] = "down", ["ctrl-p"] = "up", ["esc"] = "abort" },
        },
        actions = {
            files = {
                true, -- Retain Enter, split, and hidden-file actions from the defaults.
                -- Avoid accidentally broadening a search to ignored files or link targets.
                ["alt-i"] = false,
                ["alt-f"] = false,
            },
        },
        previewers = {
            builtin = {
                -- Plain-text previews avoid filetype/modeline processing and external viewers.
                syntax = false,
                treesitter = { enabled = false },
                render_markdown = { enabled = false },
                snacks_image = { enabled = false },
                extensions = {},
                limit_b = 1024 * 1024,
            },
        },
        files = {
            previewer = "builtin",
            cmd = "rg --no-config --files --color=never --no-follow --glob '!.git'",
            hidden = true,
            follow = false,
            no_ignore = false,
        },
        grep = {
            previewer = "builtin",
            -- Pass the query through fzf-lua's escaping, never concatenate user input.
            rg_opts = "--no-config --column --line-number --no-heading --color=always"
                .. " --smart-case --fixed-strings --hidden --no-follow --glob '!.git' --max-columns=4096 -e",
            rg_glob = false, -- Treat ' --' as literal text, not additional search options.
        },
        buffers = {
            previewer = "builtin",
            sort_lastused = true,
            fzf_opts = { ["--header-lines"] = 0 }, -- Keep the current buffer selectable too.
        },
    },
}
