local oil = require("oil")
assert(package.loaded["oil-git"], "oil-git.nvim did not initialize")
assert(require("oil-git")._is_initialized(), "oil-git.nvim initialization did not finish")
local root = assert(vim.uv.fs_realpath(assert(vim.env.DOTFILES_OIL_TEST_DIR)))
local file = root .. "/child/file with spaces.txt"

local function press(key)
    local keys = vim.api.nvim_replace_termcodes(key, true, false, true)
    vim.api.nvim_feedkeys(keys, "mx", false)
end

local function focus_entry(name)
    assert(vim.wait(5000, function()
        for line = 1, vim.api.nvim_buf_line_count(0) do
            local entry = oil.get_entry_on_line(0, line)
            if entry and entry.name == name then
                vim.api.nvim_win_set_cursor(0, { line, 0 })
                return true
            end
        end
        return false
    end, 20), "Oil entry did not load: " .. name)
end

local function check_float(win)
    local config = vim.api.nvim_win_get_config(win)
    assert(config.relative == "editor" and config.border, "Expected a bordered float")
    assert(vim.wo[win].winblend == 0, "Oil float is blended")
    local highlights = vim.api.nvim_win_call(win, function() return vim.opt_local.winhighlight:get() end)
    for _, group in ipairs({ "NormalFloat", "FloatBorder", "FloatTitle" }) do
        local target = assert(highlights[group], "Missing local highlight for " .. group)
        assert(vim.api.nvim_get_hl(0, { name = target, link = false }).bg, group .. " is transparent")
    end
end

vim.o.columns = 160
vim.cmd("vsplit")
vim.cmd.lcd(vim.fn.fnameescape(root))
local editor = vim.api.nvim_get_current_win()
local layout = vim.fn.winlayout()
press("<leader>j")
local float = vim.api.nvim_get_current_win()
assert(vim.bo.filetype == "oil", "Oil did not open")
check_float(float)
assert(vim.deep_equal(vim.fn.winlayout(), layout), "Oil changed the split layout")

focus_entry("child")
press("<CR>")
focus_entry("file with spaces.txt")
assert(vim.api.nvim_get_current_win() == float, "Directory selection left the float")

press("<C-p>")
local function preview_window()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.wo[win].previewwindow and vim.w[win].oil_entry_id == oil.get_cursor_entry().id then
            return win
        end
    end
end
assert(vim.wait(5000, preview_window), "Oil preview did not open")
local preview = preview_window()
check_float(preview)
press("<C-p>")
assert(vim.wait(5000, function() return not vim.api.nvim_win_is_valid(preview) end), "Preview stayed open")

press("<CR>")
assert(vim.wait(5000, function() return vim.api.nvim_buf_get_name(0) == file end), "Wrong file opened")
assert(not vim.api.nvim_win_is_valid(float), "File selection left Oil open")
assert(vim.api.nvim_get_current_win() == editor, "File selection did not return to the original window")
assert(vim.deep_equal(vim.fn.winlayout(), layout), "File selection changed the split layout")

for _, key in ipairs({ "<leader>j", "q", "<Esc>" }) do
    press("<leader>j")
    focus_entry("file with spaces.txt")
    press(key)
    assert(vim.api.nvim_get_current_win() == editor and vim.api.nvim_buf_get_name(0) == file,
        key .. " did not return to the original file")
end
for _, group in ipairs({ "Normal", "NormalFloat" }) do
    assert(not vim.api.nvim_get_hl(0, { name = group, link = false }).bg, group .. " lost transparency")
end
print("Oil floating explorer tests passed.")
