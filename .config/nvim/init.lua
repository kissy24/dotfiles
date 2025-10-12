require("base.options")
require("base.mappings")
require("base.lazy")

-- 外部からファイルを変更されたら反映する
vim.api.nvim_create_autocmd({ "WinEnter", "FocusGained", "BufEnter" }, {
    pattern = "*",
    command = "checktime",
})
