-- e.g. ~/.config/nvim/lua/plugins/oil.lua
return {
    "stevearc/oil.nvim",
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
        view_options = { show_hidden = true },
        float = {
            padding = 2,
            max_width = 80,
            max_height = 30,
            border = "rounded",
            win_options = {
                winblend = 10,     -- 半透明（浮遊感）
                wrap = false,      -- 横スクロールを有効にする
                number = false,    -- 行番号OFF
                relativenumber = false,
                cursorline = true, -- カーソル行ハイライト
            },
        },
    },
    keys = {
        { "<Space>j", "<CMD>Oil --float<CR>", mode = "n", desc = "Open parent directory", { silent = true } },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
}
