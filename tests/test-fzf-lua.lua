-- Exercise the real fzf terminal and providers in a configured child Neovim.
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/project", "p")
root = assert(vim.uv.fs_realpath(root))
local project = root .. "/project"
local query = [[literal.* $(touch FZF_QUERY_EXECUTED) ' " -- *.lua]]
local filename = [[space ' $(touch FZF_FILE_EXECUTED).txt]]
vim.fn.writefile({ "first line", query, "vim: set tabstop=13:" }, project .. "/" .. filename)
vim.fn.writefile({ "hidden marker" }, project .. "/.visible-dotfile")
vim.fn.writefile({ ".env", "ignored/" }, project .. "/.gitignore")
vim.fn.writefile({ "private marker" }, project .. "/.env")
vim.fn.mkdir(project .. "/ignored", "p")
vim.fn.writefile({ "private marker" }, project .. "/ignored/private.txt")
vim.fn.writefile({ "outside marker" }, root .. "/outside.txt")
assert(vim.uv.fs_symlink(root .. "/outside.txt", project .. "/linked.txt"))
assert(vim.uv.fs_symlink(root, project .. "/linked-dir"))
vim.fn.system({ "git", "-C", project, "init", "-q" })
assert(vim.v.shell_error == 0)
vim.fn.writefile({ "private marker" }, project .. "/.git/private.txt")

local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-i", "NONE" }, {
    rpc = true,
    env = { FZF_DEFAULT_OPTS = "--history=" .. vim.fn.shellescape(root .. "/fzf-history") },
})
assert(child > 0)
local function lua(code, ...)
    local result = vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
    if result ~= vim.NIL then return result end
end
local function keys(input)
    vim.rpcrequest(child, "nvim_input", input)
end
local function wait(code, message)
    assert(vim.wait(15000, function() return lua(code) end, 20), message .. "\n" ..
        tostring(lua([[return vim.inspect({mode=vim.fn.mode(), file=vim.api.nvim_buf_get_name(0), lines=vim.api.nvim_buf_get_lines(0, 0, -1, false), messages=vim.api.nvim_exec2('messages', {output=true}).output})]])))
end
local function preview_contains(text)
    return string.format([[local w = require('fzf-lua.win').__SELF()
        local p = w and w._previewer
        local b = p and p.preview_bufnr
        return b and vim.api.nvim_buf_is_valid(b)
            and table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), '\n'):find(%q, 1, true) ~= nil]], text)
end
local function close()
    keys("<Esc>")
    wait([[local w = require('fzf-lua.win').__SELF(); return (not w or not w.fzf_winid or not vim.api.nvim_win_is_valid(w.fzf_winid)) and vim.fn.mode() == 'n']], "Esc did not close search")
end
local ok, err = xpcall(function()
    lua("vim.o.columns = 160; vim.o.lines = 45; vim.cmd.cd(...)", project)
    -- The new shortcut must load the plugin and start an actual fzf process.
    keys(" ff")
    wait([[return package.loaded['fzf-lua'] ~= nil and vim.bo.filetype == 'fzf' and vim.fn.mode() == 't']],
        "File search did not lazy-load")
    keys("space")
    wait(preview_contains(query), "File preview did not show literal content")
    wait([[local w = require('fzf-lua.win').__SELF()
        return w and table.concat(vim.api.nvim_buf_get_lines(w.fzf_bufnr, 0, -1, false), '\n'):find('F1: help', 1, true) ~= nil]],
        "Basic operation hints were missing")
    assert(lua([[local w = require('fzf-lua.win').__SELF()
        local b = w._previewer.preview_bufnr
        return vim.bo[b].tabstop ~= 13 and vim.bo[b].filetype == '' and vim.bo[b].syntax == '']]),
        "Preview processed filetypes or modelines")
    keys("<F1>")
    wait([[return require('fzf-lua.win.help').win ~= nil]], "F1 help did not open")
    keys("<F1>")
    wait([[return require('fzf-lua.win.help').win == nil]], "F1 help did not close")
    keys("<CR>")
    wait(string.format("return vim.api.nvim_buf_get_name(0) == %q and vim.fn.mode() == 'n'", project .. "/" .. filename),
        "Enter did not safely open the selected filename")
    assert(vim.fn.filereadable(project .. "/FZF_FILE_EXECUTED") == 0, "Filename executed a shell command")

    -- Inspect real provider output, using the normalized production options.
    local output = lua([[local c = require('fzf-lua.config')
        local o = c.normalize_opts({}, 'files')
        local cmd = require('fzf-lua.providers.files').get_files_cmd(o)
        local lines = vim.fn.systemlist(cmd)
        assert(vim.v.shell_error == 0)
        assert(o.actions['alt-i'] == false and o.actions['alt-f'] == false)
        assert(o.fzf_opts['--history'] == false)
        return lines]])
    local found = {}
    for _, name in ipairs(output) do found[name] = true end
    assert(found[filename] and found[".visible-dotfile"], "Visible/hidden files were lost")
    for _, name in ipairs({ ".env", "ignored/private.txt", ".git/private.txt", "linked.txt", "linked-dir/outside.txt" }) do
        assert(not found[name], "Search included excluded file: " .. name)
    end

    keys(" fg")
    wait("return vim.bo.filetype == 'fzf' and vim.fn.mode() == 't'", "Text search did not open")
    keys(query)
    wait(preview_contains(query), "Literal search with shell metacharacters did not match")
    keys("<CR>")
    wait(string.format([[return vim.api.nvim_buf_get_name(0) == %q
        and vim.api.nvim_win_get_cursor(0)[1] == 2 and vim.fn.mode() == 'n']], project .. "/" .. filename),
        "Text search did not jump to its match")
    assert(vim.fn.filereadable(project .. "/FZF_QUERY_EXECUTED") == 0, "Query executed a shell command")
    keys(" fr")
    wait(preview_contains(query), "Resume lost the previous search")
    close()

    -- Grep must enforce the same exclusions; use the provider's command builder.
    lua([[local c = require('fzf-lua.config')
        local o = c.normalize_opts({ search = 'private marker' }, 'grep')
        local cmd = require('fzf-lua.make_entry').get_grep_cmd(o, o.search)
        local output = vim.fn.system(cmd)
        assert(vim.v.shell_error == 1 and output == '', 'Grep leaked ignored content: ' .. output)]])

    for _, key in ipairs({ " fb", "fb" }) do
        keys(key)
        wait(preview_contains(query), "Buffer search did not preview the open file")
        close()
    end
    for _, key in ipairs({ " fh", "fn" }) do
        keys(key)
        wait("return vim.bo.filetype == 'fzf' and vim.fn.mode() == 't'", "Help search did not open")
        keys("usr_01.txt")
        wait(preview_contains("VIM USER MANUAL"), "Help search did not preview documentation")
        close()
    end
    keys(" fk")
    wait("return vim.bo.filetype == 'fzf' and vim.fn.mode() == 't'", "Keymap search did not open")
    keys("Find files")
    wait([[local w = require('fzf-lua.win').__SELF()
        return w and table.concat(vim.api.nvim_buf_get_lines(w.fzf_bufnr, 0, -1, false), '\n'):find('Find files', 1, true) ~= nil]],
        "Keymap descriptions were missing")
    close()
    -- fzf may create an empty file while parsing inherited options before --no-history.
    assert(vim.fn.getfsize(root .. "/fzf-history") <= 0, "Search history was written to disk")
end, debug.traceback)
pcall(vim.rpcrequest, child, "nvim_command", "qa!")
vim.fn.jobwait({ child }, 5000)
vim.fn.delete(root, "rf")
assert(ok, err)
print("fzf-lua search, exclusions, previews, and keymap tests passed.")
