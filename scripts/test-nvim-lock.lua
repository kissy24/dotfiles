local config = require("lazy.core.config")
local lock = vim.json.decode(table.concat(vim.fn.readfile(config.options.lockfile), "\n"))

for name, plugin in pairs(config.plugins) do
    if not plugin._.is_local then
        local expected = assert(lock[name], name .. " is missing from the lockfile")
        local commit = vim.fn.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }):gsub("%s+$", "")
        assert(vim.v.shell_error == 0, "Cannot read installed revision: " .. name)
        assert(commit == expected.commit, name .. " does not match the lockfile")
        for _, task in ipairs(plugin._.tasks or {}) do
            assert(not task:has_errors(), name .. " has a failed installation task")
        end
    end
end
print("Neovim plugins match the lockfile.")
