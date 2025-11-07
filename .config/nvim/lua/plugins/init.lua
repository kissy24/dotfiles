return {
    -- FileExplorer
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

    -- Tab
    {
        'romgrk/barbar.nvim',
        dependencies = {
            'lewis6991/gitsigns.nvim',
            'nvim-tree/nvim-web-devicons',
        },
        init = function() vim.g.barbar_auto_setup = false end,
        opts = {},
        version = '^1.0.0', -- optional: only update when a new 1.x version is released
        keys = {
            { "<Space>h", "<Cmd>BufferPrevious<CR>", mode = "n", { silent = true } },
            { "<Space>l", "<Cmd>BufferNext<CR>",     mode = "n", { silent = true } },
        }
    },

    -- Terminal
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        opts = {},
        keys = {
            { "tm",    "<cmd>ToggleTerm<cr>", mode = "n" },
            { "<ESC>", "<C-\\><C-n>",         mode = "t" },
        }
    },

    -- FuzzyFinder
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.8",
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "ff", "<cmd>lua require('telescope.builtin').find_files()<cr>", mode = "n" },
            { "fg", "<cmd>lua require('telescope.builtin').live_grep()<cr>",  mode = "n" },
            { "fb", "<cmd>lua require('telescope.builtin').buffers()<cr>",    mode = "n" },
            { "fn", "<cmd>lua require('telescope.builtin').help_tags()<cr>",  mode = "n" },
        },
        opts = {
            defaults = {
                vimgrep_arguments = {
                    "rg",
                    "--color=never",
                    "--no-heading",
                    "--with-filename",
                    "--line-number",
                    "--column",
                    "--smart-case",
                    "--hidden",
                    "--glob",
                    "!.git/*",
                },
            },
            pickers = {
                find_files = {
                    hidden = true, -- find_filesでも隠しファイルを表示
                    -- find_command も明示的に指定する場合（オプション）
                    find_command = { "rg", "--files", "--hidden", "--glob", "!.git/*" },
                },
            },
        },
    },

    -- Treesitter
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

    -- Markdown
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        ft = { "markdown" },
        build = function() vim.fn["mkdp#util#install"]() end,
        keys = { { "md", "<Plug>MarkdownPreviewToggle", mode = "n" } }
    },

    {
        'MeanderingProgrammer/render-markdown.nvim',
        dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' }, -- if you prefer nvim-web-devicons
        ---@module 'render-markdown'
        ---@type render.md.UserConfig
        opts = {},
    },

    -- Noice
    {
        "folke/noice.nvim",
        event = "VeryLazy",
        opts = {},
        dependencies = {
            "MunifTanjim/nui.nvim",
            "rcarriga/nvim-notify",
        }
    },

    -- Help
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {},
        keys = {
            {
                "<leader>?",
                function()
                    require("which-key").show({ global = false })
                end,
                desc = "Buffer Local Keymaps (which-key)",
            },
        },
    },

    { "windwp/nvim-autopairs",           config = true,           lazy = false },
}
