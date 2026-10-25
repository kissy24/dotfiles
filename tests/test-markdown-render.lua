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
    wait_for(function() return #marks() > 0 and not vim.wo.number end, "Markdown did not render")
    assert(not vim.wo.list and not vim.wo.cursorline, "Editor decorations remain visible")
    assert(vim.wo.wrap and vim.wo.linebreak and vim.wo.breakindent, "Readable wrapping was not applied")
end
local function raw()
    wait_for(function() return #marks() == 0 and vim.wo.number end, "Raw view was not restored")
    assert(vim.wo.list and vim.wo.cursorline, "Editor options were not restored")
    assert(vim.wo.conceallevel == 0, "Markdown source remains concealed")
end

vim.o.lines = 50
vim.o.columns = 100
render.render({ buf = buf })
rendered()
local decorations = vim.inspect(marks())
for _, element in ipairs({ "RenderMarkdownH1Bg", "RenderMarkdownCode", "☐", "☑", "╭", "Note" }) do
    assert(decorations:find(element, 1, true), "Missing rendered element: " .. element)
end
local heading = vim.api.nvim_get_hl(0, { name = "RenderMarkdownH1Bg", link = false })
assert(heading.bold and not heading.bg, "Heading should be bold without a background band")

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
        raw()
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
vim.cmd("buffer " .. buf)
rendered()
vim.cmd.colorscheme("catppuccin-mocha")
heading = vim.api.nvim_get_hl(0, { name = "RenderMarkdownH1Bg", link = false })
assert(heading.bold and not heading.bg, "Markdown colors were lost after reloading the theme")
assert(vim.deep_equal(original, vim.api.nvim_buf_get_lines(buf, 0, -1, false)),
    "Rendering modified the Markdown source")
print("Markdown rendering and raw-view restoration tests passed.")
