require("base.options")
require("base.mappings")
require("base.lazy")

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
    pattern = "*",
    command = "checktime",
})
