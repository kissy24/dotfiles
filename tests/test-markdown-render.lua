local render = require("render-markdown")
local state = require("render-markdown.state")
assert(#state.validate() == 0, vim.inspect(state.validate()))
assert(vim.treesitter.language.add("markdown"), "Markdown parser is unavailable")
assert(vim.treesitter.language.add("markdown_inline"), "Inline Markdown parser is unavailable")
assert(#vim.treesitter.get_parser(0, "markdown"):parse() > 0, "Markdown parsing failed")

local buf = vim.api.nvim_get_current_buf()
local original = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local ns = assert(vim.api.nvim_get_namespaces()["render-markdown.nvim"])
local function marks()
    return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
end
local function wait_for(predicate, message)
    assert(vim.wait(5000, predicate, 20), message)
    -- Let the plugin's debounce interval finish before the next user action.
    vim.wait(state.config.debounce + 20)
end
local function rendered()
    wait_for(function() return #marks() > 0 and not vim.wo.list end, "Markdown did not render")
    assert(not vim.wo.list, "Whitespace decorations remain visible")
    assert(vim.wo.cursorline and vim.wo.cursorlineopt == "both", "Current task must stay highlighted, including wraps")
    assert(vim.opt_local.winhighlight:get().CursorLine == "RenderMarkdownCursorLine",
        "Markdown focus highlight was not applied")
    assert(vim.wo.number, "Line numbers must remain available for navigation")
    assert(vim.wo.wrap and not vim.wo.linebreak and vim.wo.breakindent, "Japanese wrapping was not applied")
end
local function raw()
    wait_for(function() return #marks() == 0 and vim.wo.list end, "Raw view was not restored")
    assert(vim.wo.list and vim.wo.cursorline, "Editor options were not restored")
    assert(vim.wo.conceallevel == 0, "Markdown source remains concealed")
    assert(vim.wo.winhighlight == state.config.win_options.winhighlight.default,
        "Markdown focus colors leaked into raw view")
    assert(vim.wo.cursorlineopt == state.config.win_options.cursorlineopt.default,
        "Raw cursorline options were not restored")
end

vim.o.lines = 50
vim.o.columns = 100
vim.api.nvim_win_set_cursor(0, { #original, 0 })
render.render({ buf = buf })
rendered()
local decorations = vim.inspect(marks())
for _, element in ipairs({ "RenderMarkdownH1Bg", "RenderMarkdownCode", "[ ]", "[x]", "╭", "Note" }) do
    assert(decorations:find(element, 1, true), "Missing rendered element: " .. element)
end
local heading = vim.api.nvim_get_hl(0, { name = "RenderMarkdownH1Bg", link = false })
assert(heading.bold and heading.bg, "Top headings need a subtle background")

local function check_focus_colors()
    local palette = require("catppuccin.palettes").get_palette("mocha")
    local function color(name) return tonumber(palette[name]:sub(2), 16) end
    local focus = vim.api.nvim_get_hl(0, { name = "RenderMarkdownCursorLine", link = false })
    local unchecked = vim.api.nvim_get_hl(0, { name = "RenderMarkdownUnchecked", link = false })
    local checked = vim.api.nvim_get_hl(0, { name = "RenderMarkdownChecked", link = false })
    local text = vim.api.nvim_get_hl(0, { name = "RenderMarkdownCheckedText", link = false })
    assert(focus.bg == color("surface0"), "Focused task needs a visible background")
    assert(unchecked.fg == color("yellow") and unchecked.bold, "Unchecked tasks need a distinct icon")
    assert(checked.fg == color("green") and checked.bold, "Checked tasks need a distinct icon")
    assert(text.fg == color("subtext0") and not text.strikethrough, "Completed text should stay readable without a strike")
    for capture, expected in pairs({ unchecked = "yellow", checked = "green" }) do
        local source = vim.api.nvim_get_hl(0, { name = "@markup.list." .. capture .. ".markdown", link = false })
        assert(source.fg == color(expected) and source.bold, "Focused source checkbox lost its contrast")
    end
end
check_focus_colors()

-- Check actual screen attributes in empty cells: the band must follow the cursor.
local task_rows = {}
for row, line in ipairs(original) do
    if line:match("^%- %[[ x]%]") then task_rows[#task_rows + 1] = row end
end
assert(#task_rows >= 2, "Fixture needs adjacent tasks")
local function focus(row)
    vim.api.nvim_win_set_cursor(0, { row, 2 })
    vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
    rendered()
    vim.cmd("redraw!")
end
local function row_attr(row)
    local screen = vim.fn.screenpos(0, row, 1)
    assert(screen.row > 0, "Task must be visible on screen")
    return vim.fn.screenattr(screen.row, vim.o.columns - 2)
end
focus(task_rows[1])
local active, inactive = row_attr(task_rows[1]), row_attr(task_rows[2])
assert(active ~= inactive, "Focused task has no visible background band")
focus(task_rows[2])
assert(row_attr(task_rows[1]) == inactive and row_attr(task_rows[2]) == active,
    "Focus band did not move to the next task")

local long_task = task_rows[#task_rows]
focus(long_task)
local first_screen_row = vim.fn.screenpos(0, long_task, 1).row
local next_screen_row = vim.fn.screenpos(0, long_task + 1, 1).row
assert(next_screen_row > first_screen_row + 1, "Fixture must exercise a wrapped task")
for row = first_screen_row, next_screen_row - 1 do
    assert(vim.fn.screenattr(row, vim.o.columns - 2) == active, "Wrapped task lost its focus band")
end

-- Focused tasks expose their real source; other tasks retain colored markers.
local function assert_source_row(row)
    for _, mark in ipairs(marks()) do
        if mark[2] == row - 1 then
            local details = mark[4]
            assert(not details.conceal and not details.virt_text,
                "Current task still has concealed or overlaid syntax")
        end
    end
end
for row, line in ipairs(original) do
    if line:match("^%s*%- %[[ x%-]%]") then
        for _, col in ipairs({ 0, assert(line:find("[", 1, true)) - 1, #line - 1 }) do
            vim.api.nvim_win_set_cursor(0, { row, col })
            vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
            rendered()
            assert_source_row(row)
        end
    end
end
-- Task text must not move horizontally when the source is revealed.
focus(task_rows[1])
local source_col = vim.fn.screenpos(0, task_rows[1], 7).col
focus(task_rows[2])
vim.cmd("redraw!")
assert(vim.fn.screenpos(0, task_rows[1], 7).col == source_col, "Task text shifted when focus moved")
focus(long_task)
assert(vim.fn.screenpos(0, long_task, 7).row == vim.fn.screenpos(0, long_task, 1).row,
    "Japanese task text was pushed below its checkbox")

vim.api.nvim_win_set_cursor(0, { task_rows[1], 0 })
render.disable()
raw()
render.enable()
rendered()

vim.cmd("normal! v")
raw()
vim.cmd("execute \"normal! \\<Esc>\"")
rendered()

-- Keep insert mode active until the asynchronous rendering update has completed.
local insert_ok, insert_error
vim.defer_fn(function()
    insert_ok, insert_error = pcall(function()
        assert(vim.api.nvim_get_mode().mode == "i", "Insert mode was not entered")
        rendered()
        assert_source_row(task_rows[1])
    end)
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
end, state.config.debounce + 100)
vim.api.nvim_feedkeys("i", "xt!", false)
assert(insert_ok, insert_error)
rendered()

-- The same window must recover its code-editing options when leaving Markdown.
vim.cmd("enew")
vim.bo.filetype = "lua"
assert(vim.wo.number and vim.wo.list and vim.wo.cursorline, "Markdown options leaked into Lua")
assert(vim.wo.winhighlight == state.config.win_options.winhighlight.default,
    "Markdown focus colors leaked into Lua")
assert(vim.wo.cursorlineopt == state.config.win_options.cursorlineopt.default,
    "Markdown cursorline options leaked into Lua")
vim.cmd("buffer " .. buf)
rendered()
vim.cmd.colorscheme("catppuccin-mocha")
heading = vim.api.nvim_get_hl(0, { name = "RenderMarkdownH1Bg", link = false })
assert(heading.bold and heading.bg, "Markdown colors were lost after reloading the theme")
check_focus_colors()
assert(vim.deep_equal(original, vim.api.nvim_buf_get_lines(buf, 0, -1, false)),
    "Rendering modified the Markdown source")
print("Markdown rendering and raw-view restoration tests passed.")
