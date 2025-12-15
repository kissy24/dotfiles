return {
    'nvim-lualine/lualine.nvim',
    dependencies = {
        'nvim-tree/nvim-web-devicons',
        'lewis6991/gitsigns.nvim', -- Git情報用
    },
    event = 'VeryLazy',
    config = function()
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
                lualine_x = { 'searchcount', 'encoding', 'fileformat', 'filetype', 'lsp_status' },
                lualine_y = { 'progress' },
                lualine_z = { 'location' },
            },
            extensions = { 'nvim-tree', 'lazy', 'mason', 'trouble', 'toggleterm', 'oil' }
        }
        require('lualine').setup(config)
    end,
}
