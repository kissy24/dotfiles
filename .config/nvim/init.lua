-- Requirements
require("mappings")
require("options")
require("plugins")
require('lualine').setup()
require("nvim-tree").setup()

-- Commands
vim.cmd [[autocmd BufWritePost plugins.lua PackerCompile]]
vim.cmd("colorscheme nordfox")
