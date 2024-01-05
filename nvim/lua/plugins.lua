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
    { "folke/lazy.nvim" },

    -- LSP
    { "neoclide/coc.nvim", branch = "release" },

    -- ColorScheme
    "EdenEast/nightfox.nvim",

    -- FileExplorer
    {
        "kyazdani42/nvim-tree.lua",
        requires = { "kyazdani42/nvim-web-devicons" },
        tag = "nightly"
    },

    -- FuzzyFinder
    {
        "nvim-telescope/telescope.nvim",
        tag = "0.1.5",
        requires = { "nvim-lua/plenary.nvim" }
    },

    {
        "nvim-lua/plenary.nvim"
    },

    -- Statusline
    {
        "nvim-lualine/lualine.nvim",
        after = colorscheme,
        requires = { "kyazdani42/nvim-web-devicons", opt = true }
    },

    -- Treesitter
    {
        "nvim-treesitter/nvim-treesitter",
    },

    -- Markdown
    {
        "iamcco/markdown-preview.nvim",
        run = function() vim.fn["mkdp#util#install"]() end,
    },

    {
        "iamcco/markdown-preview.nvim",
        run = "cd app && npm install",
        setup = function() vim.g.mkdp_filetypes = { "markdown" } end,
        ft = { "markdown" }
    },

    -- Git
    "dinhhuy258/git.nvim",
    "lewis6991/gitsigns.nvim",
}

require("lazy").setup(plugins)

require("plugins.coc")
require("plugins.mappings")

require("lualine").setup()
require("nvim-tree").setup()
require('git').setup()
require('gitsigns').setup()

vim.cmd("colorscheme nordfox")
