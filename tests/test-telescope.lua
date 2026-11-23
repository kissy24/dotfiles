-- Exercise real Telescope prompts and ripgrep in a configured child Neovim.
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/project", "p")
root = assert(vim.uv.fs_realpath(root))
local project = root .. "/project"
local query = [[literal.* $(touch TELESCOPE_QUERY_EXECUTED) ' " -- *.lua]]
local filename = [[space ' $(touch TELESCOPE_FILE_EXECUTED).unknown]]
vim.fn.writefile({ "first line", query, "vim: set tabstop=13:" }, project .. "/" .. filename)
vim.fn.writefile({ "hidden marker" }, project .. "/.visible-dotfile")
vim.fn.writefile({ ".env", "ignored/" }, project .. "/.gitignore")
vim.fn.writefile({ "private marker" }, project .. "/.env")
vim.fn.mkdir(project .. "/ignored", "p")
vim.fn.writefile({ "private marker" }, project .. "/ignored/private.txt")
vim.fn.writefile({ "private marker" }, root .. "/outside.txt")
assert(vim.uv.fs_symlink(root .. "/outside.txt", project .. "/linked.txt"))
assert(vim.uv.fs_symlink(root, project .. "/linked-dir"))
vim.fn.writefile({ string.rep("x", 1024 * 1024 + 1) }, project .. "/oversized.txt")
vim.fn.writefile({ "--no-ignore", "--follow", "--glob=!*.unknown" }, root .. "/ripgreprc")
vim.fn.system({ "git", "-C", project, "init", "-q" })
assert(vim.v.shell_error == 0)
vim.fn.writefile({ "private marker" }, project .. "/.git/private.txt")

local child = vim.fn.jobstart({ vim.v.progpath, "--embed", "--headless", "-i", "NONE" }, {
    rpc = true, env = { RIPGREP_CONFIG_PATH = root .. "/ripgreprc" },
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
        tostring(lua([[return vim.inspect({mode=vim.fn.mode(), file=vim.api.nvim_buf_get_name(0),
            lines=vim.api.nvim_buf_get_lines(0, 0, -1, false),
            messages=vim.api.nvim_exec2('messages', {output=true}).output})]])))
end
local function open(key)
    keys(key)
    wait([[return vim.bo.filetype == 'TelescopePrompt' and vim.fn.mode() == 'i']], "Picker did not open")
end
local function preview_contains(text)
    return string.format([[local p = test_picker()
        local b = p and p.previewer and p.previewer.state and p.previewer.state.bufnr
        if not b or not vim.api.nvim_buf_is_valid(b) then return false end
        local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
        for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(b, -1, 0, -1, {details=true})) do
            for _, chunk in ipairs(mark[4].virt_text or {}) do table.insert(lines, chunk[1]) end
        end
        return table.concat(lines, '\n'):find(%q, 1, true) ~= nil]], text)
end
local function close()
    keys("<Esc>")
    wait([[return not test_picker() and vim.fn.mode() == 'n']], "One Esc did not close the picker")
end

local ok, err = xpcall(function()
    lua("vim.o.columns = 160; vim.o.lines = 45; vim.cmd.cd(...)", project)
    assert(lua([[return not require('lazy.core.config').plugins['telescope.nvim']._.loaded]]))
    lua([[function _G.test_picker()
        local b = require('telescope.state').get_existing_prompt_bufnrs()[1]
        return b and require('telescope.actions.state').get_current_picker(b)
    end]])
    -- Start through the production shortcut, then inspect real finder output.
    open(" ff")
    wait([[local p = test_picker(); return p and p.manager and p.manager:num_results() == 4]],
        "Finder lost files or included ignored files/link targets")
    lua([[local p = test_picker()
        assert(p.prompt_title:find(p.cwd, 1, true), 'Search directory is not shown')
        local prompt = vim.api.nvim_win_get_position(p.prompt_win)
        local results = vim.api.nvim_win_get_position(p.results_win)
        assert(prompt[1] < results[1], 'Prompt should be above results')
        assert(table.concat(vim.api.nvim_buf_get_lines(p.results_border.bufnr, 0, -1, false), '\n'):find('F1: help', 1, true),
            'Operation hints are missing')
        local found = {}
        for entry in p.manager:iter() do found[entry.value] = true end
        for _, name in ipairs({'.env', 'ignored/private.txt', '.git/private.txt', 'linked.txt', 'linked-dir/outside.txt'}) do
            assert(not found[name], 'Finder included ' .. name)
        end
        assert(found['.visible-dotfile'] and found['.gitignore'], 'Hidden files should remain searchable')
    ]])
    keys("space")
    wait(preview_contains(query), "Special filename preview failed")
    assert(lua([[local b = test_picker().previewer.state.bufnr; return vim.bo[b].tabstop ~= 13]]),
        "Preview applied a modeline")
    keys("<F4>")
    wait([[local p = test_picker()
        local preview = require('telescope.state').get_status(p.prompt_bufnr).layout.preview
        return not preview or not vim.api.nvim_win_is_valid(preview.winid)
    ]], "F4 did not hide preview")
    keys("<F4>")
    wait(preview_contains(query), "F4 did not restore preview")
    keys("<F1>")
    wait([[for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):find('_TelescopeWhichKey$') then return true end
    end return false]], "F1 did not display operation help")
    keys("<F1>")
    keys("<CR>")
    wait(string.format([[return vim.api.nvim_buf_get_name(0) == %q and vim.fn.mode() == 'n']], project .. "/" .. filename),
        "Enter did not open the selected file")
    assert(vim.fn.filereadable(project .. "/TELESCOPE_FILE_EXECUTED") == 0, "Filename executed shell code")

    open(" fg")
    keys(query)
    wait(preview_contains(query), "Literal query with metacharacters did not match")
    keys("<CR>")
    wait([[return vim.api.nvim_win_get_cursor(0)[1] == 2 and vim.fn.mode() == 'n']], "Grep did not jump to match")
    assert(vim.fn.filereadable(project .. "/TELESCOPE_QUERY_EXECUTED") == 0, "Query executed shell code")
    open(" fr")
    wait(preview_contains(query), "Resume lost the previous search")
    close()

    -- A known visible match first confirms that the live job has run.
    open(" fg")
    keys("marker")
    wait([[local p = test_picker(); local selected = p and p:get_selection()
        return selected and p.manager and p.manager:num_results() == 1 and selected.text == 'hidden marker']], "Grep included ignored or linked content")
    close()
    open(" ff")
    keys("oversized")
    wait(preview_contains("File exceeds preview size limit"), "Oversized preview was not limited")
    close()
    open(" fb")
    wait(preview_contains(query), "Buffers did not include the current file")
    close()
    open(" fh")
    keys("usr_01.txt")
    wait(preview_contains("VIM USER MANUAL"), "Help did not preview documentation")
    close()
    open(" fk")
    keys("Find files")
    wait([[local p = test_picker(); return p and p.manager and p.manager:num_results() > 0]],
        "Keymap descriptions were not searchable")
    close()
    -- Restored native f motion must work without triggering a search.
    lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {'a f g b n'}); vim.api.nvim_win_set_cursor(0, {1, 0})]])
    keys("ff")
    wait([[return vim.api.nvim_win_get_cursor(0)[2] == 2 and not test_picker()]], "Native ff motion was lost")
end, debug.traceback)
pcall(vim.rpcrequest, child, "nvim_command", "qa!")
vim.fn.jobwait({ child }, 5000)
vim.fn.delete(root, "rf")
assert(ok, err)
print("Telescope search, exclusions, previews, and keymap tests passed.")
