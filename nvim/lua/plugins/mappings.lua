-- nvim-tree
vim.keymap.set("n", "tr", "<cmd>NvimTreeToggle<cr>", { silent = true })

-- Telescope
local builtin = require('telescope.builtin')
vim.keymap.set("n", "ff", "<cmd>lua require('telescope.builtin').find_files()<cr>")
vim.keymap.set("n", "fg", "<cmd>lua require('telescope.builtin').live_grep()<cr>")
vim.keymap.set("n", "fb", "<cmd>lua require('telescope.builtin').buffers()<cr>")
vim.keymap.set("n", "fh", "<cmd>lua require('telescope.builtin').help_tags()<cr>")

-- markdown-preview
vim.keymap.set("n", "md", "<Plug>MarkdownPreviewToggle")

-- barbar
local opts = { noremap = true, silent = true }
-- Move to previous/next
vim.keymap.set('n', '<Space>h', '<Cmd>BufferPrevious<CR>', opts)
vim.keymap.set('n', '<Space>l', '<Cmd>BufferNext<CR>', opts)

-- Toggleterm
vim.keymap.set('n', 'tm', '<cmd>ToggleTerm<cr>')
vim.keymap.set("t", "<ESC>", "<C-\\><C-n>")
