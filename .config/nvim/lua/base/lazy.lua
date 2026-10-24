-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local lockfile = vim.fn.stdpath("config") .. "/lazy-lock.json"
    local lock = vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))
    local commit = assert(lock["lazy.nvim"].commit, "lazy.nvim is missing from the lockfile")
    local output = vim.fn.system({ "git", "clone", "--filter=blob:none", "--no-checkout", lazyrepo, lazypath })
    assert(vim.v.shell_error == 0, "lazy.nvim clone failed: " .. output)
    output = vim.fn.system({ "git", "-C", lazypath, "checkout", "--detach", commit })
    assert(vim.v.shell_error == 0, "lazy.nvim checkout failed: " .. output)
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    spec = "plugins",
    rocks = {
        enabled = false,
        hererocks = false,
    },
})
vim.keymap.set("n", "<leader>lh", "<cmd>Lazy home<CR>")
