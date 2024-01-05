-- nvim-tree
vim.keymap.set("n", "tr", ":NvimTreeToggle<cr>", { silent = true })

-- Telescope
local builtin = require('telescope.builtin')
vim.keymap.set("n", "ff", "<cmd>lua require('telescope.builtin').find_files()<cr>")
vim.keymap.set("n", "fg", "<cmd>lua require('telescope.builtin').live_grep()<cr>")
vim.keymap.set("n", "fb", "<cmd>lua require('telescope.builtin').buffers()<cr>")
vim.keymap.set("n", "fh", "<cmd>lua require('telescope.builtin').help_tags()<cr>")

-- markdown-pewview
vim.keymap.set("n", "md", "<Plug>MarkdownPreviewToggle")
