vim.cmd [[packadd packer.nvim]]

require "packer".startup(function()
    use { "wbthomason/packer.nvim", opt = true }

    -- LSP
    use {'neoclide/coc.nvim', branch = 'release'}

    -- ColorScheme
    use "EdenEast/nightfox.nvim"

    -- FileExplorer
    use {
        "kyazdani42/nvim-tree.lua",
        requires = { "kyazdani42/nvim-web-devicons" },
        tag = "nightly"
    }

    -- FuzzyFinder
    use {
        'nvim-telescope/telescope.nvim', tag = '0.1.0',
        requires = { { 'nvim-lua/plenary.nvim' } }
    }

    -- Statusline
    use({
        "nvim-lualine/lualine.nvim",
        after = colorscheme,
        requires = { "kyazdani42/nvim-web-devicons", opt = true }
    })
end)
