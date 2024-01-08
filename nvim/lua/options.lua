-- Disable unwanted default plug-ins
vim.g.loaded_gzip = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1
vim.g.loaded_netrwFileHandlers = 1

-- Display
vim.o.number = true
vim.o.title = true
vim.o.cursorline = true
vim.o.list = true
vim.o.wrap = false
vim.o.showmode = false

-- Tab
vim.o.expandtab = true
vim.o.shiftround = true
vim.o.shiftwidth = 4
vim.o.showtabline = 2

-- Indent
vim.o.autoindent = true
vim.o.smartindent = true

-- Swap, Backup
vim.o.swapfile = false
vim.o.writebackup = false
vim.o.backup = false

-- Search
vim.o.hlsearch = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.incsearch = true
vim.o.wrapscan = true

-- Split
vim.o.splitbelow = true
vim.o.splitright = true

-- Other
vim.o.hidden = true
vim.o.history = 1000
vim.opt.clipboard:append({ unnamedeplus = true })
vim.o.mouse = ""
