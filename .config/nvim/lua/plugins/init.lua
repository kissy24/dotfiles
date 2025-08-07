return {
    -- FileExplorer
    {
        "kyazdani42/nvim-tree.lua",
        requires = { "kyazdani42/nvim-web-devicons" },
        version = "*",
        opts = {},
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
        }
    },

    -- Treesitter
    { "nvim-treesitter/nvim-treesitter", build = ":TSUpdateSync", opts = {} },

    -- Markdown
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        ft = { "markdown" },
        build = function() vim.fn["mkdp#util#install"]() end,
        keys = { { "md", "<Plug>MarkdownPreviewToggle", mode = "n" } }
    },

    {
        "MeanderingProgrammer/render-markdown.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
        ---@module "render-markdown"
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

    { "windwp/nvim-autopairs", config = true, lazy = false },
}
