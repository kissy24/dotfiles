return {
    {
        "kyazdani42/nvim-tree.lua",
        requires = { "kyazdani42/nvim-web-devicons", "nvim-telescope/telescope.nvim" },
        version = "*",
        opts = {
            on_attach = function(bufnr)
                local api = require('nvim-tree.api')

                -- デフォルトのキーマップを適用
                api.config.mappings.default_on_attach(bufnr)

                -- ff: find_files（ファイル名検索）
                vim.keymap.set('n', 'ff', function()
                    local node = api.tree.get_node_under_cursor()
                    local path = node.absolute_path or vim.fn.getcwd()

                    if vim.fn.isdirectory(path) == 0 then
                        path = vim.fn.fnamemodify(path, ':h')
                    end

                    require('telescope.builtin').find_files({
                        cwd = path,
                        hidden = true, -- Telescopeの設定を継承しつつ明示的に指定
                    })
                end, { buffer = bufnr, desc = 'Telescope find files' })

                -- fg: live_grep（ファイル内容検索）
                vim.keymap.set('n', 'fg', function()
                    local node = api.tree.get_node_under_cursor()
                    local path = node.absolute_path or vim.fn.getcwd()

                    if vim.fn.isdirectory(path) == 0 then
                        path = vim.fn.fnamemodify(path, ':h')
                    end

                    require('telescope.builtin').live_grep({ cwd = path })
                    -- live_grepはdefaultsのvimgrep_argumentsを自動的に使用
                end, { buffer = bufnr, desc = 'Telescope live grep' })
            end,
        },
        keys = { { "tr", "<cmd>NvimTreeToggle<cr>", mode = "n", { silent = true } } }
    },
}
