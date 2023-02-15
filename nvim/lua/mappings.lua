-- Exit insert mode with jj
vim.keymap.set("i", "jj", "<ESC>", { silent = true })
vim.keymap.set("i", "っj", "<ESC>", { silent = true })

-- Moving the pane
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")

-- terminal mode
vim.keymap.set("n", "tm", "<cmd>belowright new<CR><cmd>terminal<CR>", { silent = true})
vim.cmd [[autocmd TermOpen * :startinsert]]
vim.cmd [[autocmd TermOpen * setlocal norelativenumber]]
vim.cmd [[autocmd TermOpen * setlocal nonumber]]

-- nvim-tree
vim.keymap.set("n", "tr", ":NvimTreeToggle<cr>", { silent = true })

-- Telescope
vim.keymap.set("n", "ff", "<cmd>lua require('telescope.builtin').find_files()<cr>")
vim.keymap.set("n", "fg", "<cmd>lua require('telescope.builtin').live_grep()<cr>")
vim.keymap.set("n", "fb", "<cmd>lua require('telescope.builtin').buffers()<cr>")
vim.keymap.set("n", "fh", "<cmd>lua require('telescope.builtin').help_tags()<cr>")

-- markdown-pewview
vim.keymap.set("n", "<C-p>", "<Plug>MarkdownPreviewToggle")
