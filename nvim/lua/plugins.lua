local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable", -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
    -- Installer
    "folke/lazy.nvim",

    -- LSP
    {
        "neoclide/coc.nvim",
        branch = "release",
        config = function() require("plugins.coc") end,
    },

    -- ColorScheme
    {
        "projekt0n/github-nvim-theme",
        lazy = false,    -- make sure we load this during startup if it is your main colorscheme
        priority = 1000, -- make sure to load this before all the other start plugins
        config = function()
            require("github-theme").setup({})
            vim.cmd("colorscheme github_dark_dimmed")
        end,
    },

    -- FileExplorer
    {
        "kyazdani42/nvim-tree.lua",
        requires = { "kyazdani42/nvim-web-devicons" },
        tag = "nightly",
        config = function() require("nvim-tree").setup() end,
    },

    -- Tab
    {
        'romgrk/barbar.nvim',
        dependencies = {
            'lewis6991/gitsigns.nvim',     -- OPTIONAL: for git status
            'nvim-tree/nvim-web-devicons', -- OPTIONAL: for file icons
        },
        init = function() vim.g.barbar_auto_setup = false end,
        opts = {
            -- lazy.nvim will automatically call setup for you. put your options here, anything missing will use the default:
            -- animation = true,
            -- insert_at_start = true,
            -- …etc.
        },
        version = '^1.0.0', -- optional: only update when a new 1.x version is released
    },

    -- Terminal
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        opts = { --[[ things you want to change go here]] }
    },

    -- FuzzyFinder
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.5",
        requires = { "nvim-lua/plenary.nvim" }
    },

    "nvim-lua/plenary.nvim",

    -- Statusline
    {
        "nvim-lualine/lualine.nvim",
        after = colorscheme,
        requires = { "kyazdani42/nvim-web-devicons", opt = true },
        config = function() require("lualine").setup() end,
    },

    -- Treesitter
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate"
    },

    -- Markdown
    {
        "iamcco/markdown-preview.nvim",
        cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
        ft = { "markdown" },
        build = function() vim.fn["mkdp#util#install"]() end,
    },

    -- Git
    {
        "dinhhuy258/git.nvim",
        config = function() require('git').setup() end,
    },

    {
        "lewis6991/gitsigns.nvim",
        config = function() require('gitsigns').setup() end,
    },

    -- Note
    {
        'gsuuon/note.nvim',
        opts = {
            -- Spaces are note roots. These directories should contain a `./notes` directory (will be made if not).
            -- Defaults to { '~' }.
            spaces = {
                '~',
                -- '~/projects/foo'
            },

            -- Set keymap = false to disable keymapping
            -- keymap = {
            --   prefix = '<leader>n'
            -- }
        },
        cmd = 'Note',
        ft = 'note'
    }

}

require("lazy").setup(plugins)
require("plugins.mappings")
