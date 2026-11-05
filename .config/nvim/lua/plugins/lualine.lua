return {
    'nvim-lualine/lualine.nvim',
    dependencies = {
        'nvim-tree/nvim-web-devicons',
        'lewis6991/gitsigns.nvim', -- Git情報用
    },
    event = 'VeryLazy',
    config = function()
        -- vim.lsp.status() consumes progress messages. Cache each update so a
        -- second redraw does not erase it before it can be read.
        local progress, generation = "", 0
        local group = vim.api.nvim_create_augroup("DotfilesLspProgress", { clear = true })
        vim.api.nvim_create_autocmd("LspProgress", {
            group = group,
            callback = function()
                progress = vim.lsp.status()
                generation = generation + 1
                local current = generation
                require("lualine").refresh({ place = { "statusline" } })
                vim.defer_fn(function()
                    if generation == current then
                        progress = ""
                        require("lualine").refresh({ place = { "statusline" } })
                    end
                end, 2000)
            end,
        })
        local config = {
            options = {
                theme = 'iceberg_dark',
                component_separators = { left = '', right = '' },
                section_separators = { left = '', right = '' },
                globalstatus = true,
            },
            sections = {
                lualine_a = { 'mode' },
                lualine_b = { 'branch', 'diff', 'diagnostics' },
                lualine_c = { 'filename', 'filesize' },
                lualine_x = { 'searchcount', 'encoding', 'fileformat', 'filetype', { function() return progress end } },
                lualine_y = { 'progress' },
                lualine_z = { 'location' },
            },
            extensions = { 'oil', 'lazy', 'mason' }
        }
        require('lualine').setup(config)
    end,
}
