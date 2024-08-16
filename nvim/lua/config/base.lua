-- BASE SETTINGS

-- 1.Options

-- 1.1.Disable unwanted default plug-ins
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

-- 1.2.Display
vim.o.number = true
vim.o.title = true
vim.o.cursorline = true
vim.o.list = true
vim.o.listchars = "tab:»･,trail:･,space:･"
vim.o.wrap = false
vim.o.showmode = false

-- 1.3.Tab
vim.o.expandtab = true
vim.o.shiftround = true
vim.o.shiftwidth = 4
vim.o.showtabline = 2

-- 1.4.Indent
vim.o.autoindent = true
vim.o.smartindent = true

-- 1.5.Swap, Backup
vim.o.swapfile = false
vim.o.writebackup = false
vim.o.backup = false

-- 1.6.Search
vim.o.hlsearch = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.incsearch = true
vim.o.wrapscan = true

-- 1.7.Split
vim.o.splitbelow = true
vim.o.splitright = true

-- 1.8.Other
vim.o.hidden = true
vim.o.history = 1000
vim.opt.clipboard:append({ unnamedeplus = true })
vim.o.mouse = ""

-- 2.Mapping

-- 2.1.ExitInsertMode
vim.keymap.set("i", "jj", "<ESC>", { silent = true })

-- 2.2.MovingPane
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- 2.3.Split
vim.keymap.set('n', 'ss', ':split<Return><C-w>w')
vim.keymap.set('n', 'sv', ':vsplit<Return><C-w>w')

-- 2.4.YankRegister
vim.keymap.set("n", "pp", "\"0p")
vim.keymap.set("n", "PP", "\"0P")

-- 2.5.CheckHealth
vim.keymap.set("n", "ch", "<cmd>checkhealth<CR>")
