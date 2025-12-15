return {
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdateSync",
        config = function(_, opts)
            require("nvim-treesitter.configs").setup(opts)
        end,
        opts = {
            ensure_installed = {
                "bash",
                "css",
                "go",
                "html",
                "javascript",
                "json",
                "lua",
                "markdown",
                "python",
                "typescript",
                "vim",
                "yaml",
            },
            sync_install = false,
            auto_install = true,
            highlight = {
                enable = true,
                additional_vim_regex_highlighting = false,
            },
        },
    },
}
