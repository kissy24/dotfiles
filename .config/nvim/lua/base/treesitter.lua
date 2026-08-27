local M = {}

M.parsers = {
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
}

function M.setup()
    local group = vim.api.nvim_create_augroup("DotfilesTreesitter", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = {
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
        callback = function(args)
            vim.treesitter.start(args.buf)
        end,
    })
end

return M
