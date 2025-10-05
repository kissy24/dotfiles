return {
    -- ColorScheme
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000,
    },

    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd([[colorscheme tokyonight-moon]])
        end,
    },

    {
        'projekt0n/github-nvim-theme',
        name = 'github-theme',
        lazy = false,
        priority = 1000,
        opts = {},
        -- config = function()
        --     vim.cmd([[colorscheme github_dark_dimmed]])
        -- end,
    },
}
