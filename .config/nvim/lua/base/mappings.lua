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
