local oil = require("oil")
assert(package.loaded["oil-git"], "oil-git.nvim did not initialize")
local root = assert(vim.uv.fs_realpath(assert(vim.env.DOTFILES_OIL_TEST_DIR)))
local file = root .. "/child/file with spaces.txt"
local toggle = assert(vim.fn.maparg("<leader>j", "n", false, true).callback)

local function select_entry(name)
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
    local enter = assert(vim.fn.maparg("<CR>", "n", false, true).callback)
    enter()
end

local function column(win)
    return vim.api.nvim_win_get_position(win)[2]
end

-- Exercise actual mappings with either split direction, including a lone Oil window.
vim.o.columns = 160
for _, splitright in ipairs({ true, false }) do
    vim.o.splitright = splitright
    vim.cmd("only!")
    vim.cmd("edit " .. vim.fn.fnameescape(file))
    local first = vim.api.nvim_get_current_win()
    vim.cmd("rightbelow vsplit")
    local editor = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(first)
    toggle()
    local sidebar = vim.api.nvim_get_current_win()
    assert(vim.bo.filetype == "oil", "Oil sidebar did not open")
    assert(column(sidebar) > column(editor), "Oil must open at the far right")
    assert(vim.api.nvim_win_get_width(sidebar) == 30, "Oil sidebar width changed")

    oil.open(root)
    select_entry("child")
    assert(vim.wait(5000, function()
        return oil.get_current_dir() == root .. "/child/"
    end, 20), "Directory selection did not navigate within Oil")
    assert(vim.api.nvim_get_current_win() == sidebar, "Directory selection left the sidebar")
    assert(#vim.api.nvim_tabpage_list_wins(0) == 3, "Directory selection created a split")

    select_entry("file with spaces.txt")
    assert(vim.api.nvim_get_current_win() == editor, "File did not open in the left neighbor")
    assert(vim.api.nvim_buf_get_name(0) == file, "Wrong file opened")
    assert(vim.bo[vim.api.nvim_win_get_buf(sidebar)].filetype == "oil", "Oil was replaced")
    toggle()
    assert(not vim.api.nvim_win_is_valid(sidebar), "Toggle did not close Oil")
    assert(#vim.api.nvim_tabpage_list_wins(0) == 2, "Toggle closed an editing window")

    toggle()
    sidebar = vim.api.nvim_get_current_win()
    vim.cmd("only!")
    select_entry("file with spaces.txt")
    assert(#vim.api.nvim_tabpage_list_wins(0) == 2, "Lone Oil did not create an editor")
    assert(column(vim.api.nvim_get_current_win()) < column(sidebar), "New editor must be left of Oil")
    assert(vim.api.nvim_buf_get_name(0) == file, "Lone Oil opened the wrong file")
    assert(vim.bo[vim.api.nvim_win_get_buf(sidebar)].filetype == "oil", "Lone Oil was replaced")
    toggle()
end
print("Oil right sidebar tests passed.")
