-- Exit insert mode with jj
vim.keymap.set("i", "jj", "<ESC>", { silent = true })
vim.keymap.set("i", "っj", "<ESC>", { silent = true })

-- Moving the pane
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- Use yank register
vim.keymap.set("n", "pp", "\"0p")
vim.keymap.set("n", "PP", "\"0P")

-- Terminal mode
vim.keymap.set("n", "tm", "<cmd>belowright new<CR><cmd>terminal<CR>", { silent = true })
vim.keymap.set("t", "<ESC>", "<C-\\><C-n>")
vim.cmd [[autocmd TermOpen * :startinsert]]
vim.cmd [[autocmd TermOpen * setlocal norelativenumber]]
vim.cmd [[autocmd TermOpen * setlocal nonumber]]
