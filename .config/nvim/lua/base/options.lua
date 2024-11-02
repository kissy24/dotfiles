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
vim.o.termguicolors = true
vim.o.pumblend = 30

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

if vim.fn.has('wsl') == 1 then
    vim.g.clipboard = {
        name = 'win32yank',
        copy = {
            ['+'] = 'win32yank.exe -i --crlf',
            ['*'] = 'win32yank.exe -i --crlf',
        },
        paste = {
            ['+'] = 'win32yank.exe -o --lf',
            ['*'] = 'win32yank.exe -o --lf',
        },
        cache_enabled = 0,
    }
end
