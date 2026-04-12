return {
    { "windwp/nvim-autopairs", config = true, lazy = false },
    {
        'MeanderingProgrammer/render-markdown.nvim',
        dependencies = { 'nvim-mini/mini.nvim' }, -- if you use the mini.nvim suite
        ---@module 'render-markdown'
        ---@type render.md.UserConfig
        opts = {},
    },
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
}
