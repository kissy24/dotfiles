return {
    {
        "nvim-treesitter/nvim-treesitter",
        lazy = false,
        build = ":TSUpdate",
        opts = {
            parsers = {
                "go",
                "gomod",
                "gosum",
                "gowork",
                "lua",
                "markdown",
                "markdown_inline",
                "python",
                "tsx",
                "typescript",
            },
            filetypes = {
                "go",
                "gomod",
                "gosum",
                "gowork",
                "lua",
                "markdown",
                "python",
                "typescript",
                "typescriptreact",
            },
        },
        config = function(_, opts)
            local group = vim.api.nvim_create_augroup("DotfilesTreesitter", { clear = true })

            vim.api.nvim_create_autocmd("FileType", {
                group = group,
                pattern = opts.filetypes,
                callback = function(args)
                    vim.treesitter.start(args.buf)
                end,
            })
        end,
    },
}
