-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
end
vim.opt.rtp:prepend(lazypath)

local plugins = {
    -- LSP
    {
        "neoclide/coc.nvim",
        branch = "release",
        build = ":CocUpdateSync",
        config = function() require("plugins.coc") end,
    },

    -- ColorScheme
    {
        "catppuccin/nvim",
        name = "catppuccin",
        priority = 1000, -- make sure to load this before all the other start plugins
        config = function()
            vim.cmd.colorscheme "catppuccin"
        end,
    },

    -- FileExplorer
    {
        "kyazdani42/nvim-tree.lua",
        requires = { "kyazdani42/nvim-web-devicons" },
        tag = "nightly",
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

    -- Statusline
    {
        "nvim-lualine/lualine.nvim",
        requires = { "kyazdani42/nvim-web-devicons" },
        opts = {}
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

    -- Git
    { "dinhhuy258/git.nvim",             opts = {} },
    { "lewis6991/gitsigns.nvim",         opts = {} },
}

require("lazy").setup(plugins)
vim.keymap.set("n", "Lh", "<cmd>Lazy home<CR>")
