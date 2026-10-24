local config = require("lazy.core.config")
local git = require("lazy.manage.git")
local lock = vim.json.decode(table.concat(vim.fn.readfile(config.options.lockfile), "\n"))

for name, plugin in pairs(config.plugins) do
    if not plugin._.is_local then
        local expected = assert(lock[name], name .. " is missing from the lockfile")
        local commit = vim.fn.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }):gsub("%s+$", "")
        assert(vim.v.shell_error == 0, "Cannot read installed revision: " .. name)
        assert(commit == expected.commit, name .. " does not match the lockfile")
        local info = assert(git.info(plugin.dir))
        assert((info.branch or git.get_branch(plugin)) == expected.branch,
            name .. " would change the branch in the lockfile")
        for _, task in ipairs(plugin._.tasks or {}) do
            assert(not task:has_errors(), name .. " has a failed installation task")
        end
    end
end
print("Neovim plugins match the lockfile.")
