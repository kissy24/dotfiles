-- Drive a real configured Neovim through RPC; exercise menus, not just options.
local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.writefile({ '{"private":true}' }, root .. "/package.json")
vim.fn.writefile({ "const message = 'hello';", "message." }, root .. "/completion.ts")
vim.fn.writefile({ "nativeBufferCandidate", "" }, root .. "/words.txt")
local function git(...)
    local args = { "git", "-C", root }
    vim.list_extend(args, { ... })
    local out = vim.fn.system(args)
    assert(vim.v.shell_error == 0, out)
end
git("init", "-q")
git("add", "words.txt")
git("-c", "user.name=Native Test", "-c", "user.email=native@example.test", "commit", "-qm", "native blame fixture")
local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-i", "NONE" }, { rpc = true })
assert(child > 0)
local function lua(code, ...)
    local result = vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
    if result ~= vim.NIL then return result end
end
local function keys(input)
    vim.rpcrequest(child, "nvim_input", input)
end
local function wait(code, message)
    local done = vim.wait(15000, function() return lua(code) end, 20)
    if not done then
        error(message .. "\n" .. vim.inspect(lua([[return {
            mode=vim.fn.mode(), line=vim.api.nvim_get_current_line(),
            info=vim.fn.complete_info(), messages=vim.api.nvim_exec2('messages', {output=true}).output,
        }]])))
    end
end
local function has_item(word)
    return string.format([[for _, item in ipairs(vim.fn.complete_info().items) do
        if item.word == %q then return true end
    end return false]], word)
end
local ok, err = xpcall(function()
    -- Embedded headless Nvim has no UI; deliver the event that releases VeryLazy.
    lua("vim.api.nvim_exec_autocmds('UIEnter', {modeline=false})")
    wait("return require('lazy.core.config').plugins['lualine.nvim']._.loaded ~= nil",
        "Lualine did not initialize after UIEnter")
    lua("vim.cmd.edit(...)", root .. "/words.txt")
    wait("return vim.b.gitsigns_head ~= nil", "Gitsigns did not attach")
    wait([[local b = vim.b.gitsigns_blame_line_dict
        return b and b.author == 'Native Test' and b.summary == 'native blame fixture']],
        "Current-line blame did not identify the committed author/summary")
    -- Actual virtual text must be visible, not only cached blame metadata.
    wait([[for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, {details=true})) do
        for _, chunk in ipairs(mark[4].virt_text or {}) do
            if chunk[1]:find('native blame fixture', 1, true) and chunk[1]:find('Native Test', 1, true) then return true end
        end
    end return false]], "Gitsigns blame virtual text is missing")
    lua("vim.api.nvim_win_set_cursor(0, {2, 0})")
    keys("inativeBuf")
    wait(has_item("nativeBufferCandidate"), "Buffer autocompletion did not appear")
    keys("<C-n><CR><Esc>")
    wait("return vim.api.nvim_get_current_line() == 'nativeBufferCandidate'", "Enter did not accept buffer completion")
    keys("oordinary<CR><Esc>")
    wait("return vim.api.nvim_buf_line_count(0) == 4", "Enter without selection must insert a newline")
    for _, prefix in ipairs({ "/", "?" }) do
        keys(prefix .. "nativeBuf")
        wait("return vim.fn.wildmenumode() == 1", "Search completion menu did not appear")
        keys("<Tab>")
        wait("return vim.fn.getcmdline() == 'nativeBufferCandidate'", "Search word was not completed")
        keys("<C-c>")
        wait("return vim.fn.mode() == 'n'", "Search did not close")
    end
    keys(":ed")
    wait("return vim.fn.wildmenumode() == 1", "Command completion did not appear")
    keys("<C-c>")
    wait("return vim.fn.mode() == 'n'", "Command line did not close")
    keys(":edit " .. root .. "/wor")
    wait("return vim.fn.wildmenumode() == 1", "Path completion did not appear")
    keys("<Tab>")
    wait("return vim.fn.getcmdline():match('words.txt$') ~= nil", "Path was not completed")
    keys("<C-c>")
    wait("return vim.fn.mode() == 'n'", "Path command did not close")
    lua("vim.cmd('edit! ' .. vim.fn.fnameescape(...))", root .. "/completion.ts")
    wait([[local c = vim.lsp.get_clients({bufnr=0, name='ts_ls'})[1]
        return c and c.initialized and #vim.api.nvim_get_autocmds({event="InsertCharPre", buffer=0}) > 0]], "TypeScript LSP did not initialize")
    lua("vim.api.nvim_win_set_cursor(0, {2, 8})")
    keys("AtoU")
    wait(has_item("toUpperCase"), "LSP autocompletion did not appear after typing letters")
    keys("<C-n><CR><Esc>")
    wait("return vim.api.nvim_get_current_line():find('message.toUpperCase', 1, true) ~= nil",
        "Native LSP completion was not accepted")
    keys("A<C-e><C-Space>")
    wait("return vim.fn.pumvisible() == 1", "Manual native completion did not appear")
    keys("<C-e><Esc>")
    wait("return vim.fn.pumvisible() == 0", "Completion cancellation failed")
    -- Exercise both directions through native snippet fields.
    lua("vim.api.nvim_buf_set_lines(0, 0, -1, false, {''}); vim.api.nvim_win_set_cursor(0, {1, 0})")
    keys("i")
    wait("return vim.fn.mode() == 'i'", "Insert mode did not start")
    lua([[vim.snippet.expand('call(${1:first}, ${2:second})$0')]])
    keys("<Tab>")
    wait("return vim.api.nvim_win_get_cursor(0)[2] == 12", "Tab did not jump to the second snippet field")
    keys("<S-Tab>")
    wait("return vim.api.nvim_win_get_cursor(0)[2] == 5", "Shift-Tab did not return to the first snippet field")
    lua("vim.snippet.stop()")
    keys("<Esc>")
    wait("return vim.fn.mode() == 'n'", "Snippet selection did not close")
    -- Send real progress through the LSP handler and inspect the rendered statusline.
    lua([[vim.o.columns = 200; vim.schedule(function()
        local c = vim.lsp.get_clients({name='ts_ls'})[1]
        vim.lsp.handlers['$/progress'](nil, {token='native-test', value={kind='begin', title='Native progress'}}, {client_id=c.id})
    end)]])
    wait("return require('lualine').statusline(true):find('Native progress', 1, true) ~= nil",
        "Native LSP progress did not reach the statusline")
    wait("return require('lualine').statusline(true):find('Native progress', 1, true) == nil",
        "Old progress must clear after the last update")
end, debug.traceback)
pcall(vim.rpcrequest, child, "nvim_command", "qa!")
vim.fn.jobwait({ child }, 5000)
vim.fn.delete(root, "rf")
assert(ok, err)
print("Native completion, LSP progress, and Gitsigns blame tests passed.")
