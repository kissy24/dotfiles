-- Invoked by setup only: loading a file in Neovim never installs an LSP.
local registry = require("mason-registry")
local refreshed, refresh_error = false, nil
registry.refresh(function(success, result)
    refreshed = true
    if not success then refresh_error = vim.inspect(result) end
end)
assert(vim.wait(120000, function() return refreshed end, 100), "Mason registry refresh timed out")
assert(not refresh_error, refresh_error)
local mapping = require("mason-lspconfig.mappings").get_mason_map().lspconfig_to_package
for _, spec in ipairs(require("plugins.mason-lspconfig").opts.dotfiles_versions) do
    local server, version = spec:match("^([^@]+)@(.+)$")
    assert(server and version, "LSP must have an exact version: " .. spec)
    local pkg = registry.get_package(assert(mapping[server], server))
    local receipt = pkg:is_installed() and pkg:get_receipt():or_else(nil)
    local id = receipt and receipt.source and receipt.source.id or ""
    if id:sub(-#version - 1) ~= "@" .. version then
        local finished, succeeded = false, false
        pkg:install({ version = version }):once("closed", function()
            succeeded = pkg:is_installed()
            local installed = succeeded and pkg:get_receipt():or_else(nil)
            local installed_id = installed and installed.source and installed.source.id or ""
            succeeded = succeeded and installed_id:sub(-#version - 1) == "@" .. version
            finished = true
        end)
        assert(vim.wait(600000, function() return finished end, 100), "LSP installation timed out: " .. spec)
        assert(succeeded, "LSP installation failed: " .. spec)
    end
end
