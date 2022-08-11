-- Requirements
require("mappings")
require("options")
require("plugins")

-- Commands
vim.cmd [[autocmd BufWritePost plugins.lua PackerCompile]]
vim.cmd("colorscheme nordfox")
