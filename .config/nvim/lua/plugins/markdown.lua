return {
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        ft = { "markdown" },
        build = function() vim.fn["mkdp#util#install"]() end,
        keys = { { "md", "<Plug>MarkdownPreviewToggle", mode = "n" } }
    },

    --{
    --   'MeanderingProgrammer/render-markdown.nvim',
    --    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
    --    ---@module 'render-markdown'
    --    ---@type render.md.UserConfig
    --    opts = {
    --        latex = { enabled = false },
    --    },
    --},
}
