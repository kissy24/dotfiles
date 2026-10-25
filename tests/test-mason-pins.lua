-- Exercise the real installer with fake packages; never download or modify tools.
local pins = dofile('.config/nvim/lua/plugins/mason-lspconfig.lua').opts.dotfiles_versions
local packages, mapping = {}, {}
for _, pin in ipairs(pins) do
    local name, version = pin:match('^([^@]+)@(.+)$')
    mapping[name] = name
    packages[name] = { version = version, installs = 0 }
end
package.loaded['plugins.mason-lspconfig'] = dofile('.config/nvim/lua/plugins/mason-lspconfig.lua')
package.loaded['mason-lspconfig.mappings'] = { get_mason_map = function()
    return { lspconfig_to_package = mapping }
end }
package.loaded['mason-registry'] = {
    refresh = function(callback) callback(true, {}) end,
    get_package = function(name) return packages[name] end,
}
for _, pkg in pairs(packages) do
    function pkg:is_installed() return self.installed ~= nil end
    function pkg:get_receipt()
        return { or_else = function() return { source = { id = 'pkg:test@' .. self.installed } } end }
    end
    function pkg:install(opts)
        self.installs = self.installs + 1
        assert(opts.version == self.version, 'Installer requested an unpinned version')
        return { once = function(_, event, callback)
            assert(event == 'closed')
            if not self.fail then self.installed = opts.version end
            callback()
        end }
    end
end
-- One correct installation, one old version and one missing package.
packages.lua_ls.installed = packages.lua_ls.version
packages.marksman.installed = 'old'
dofile('.config/nvim/install-lsp.lua')
assert(packages.lua_ls.installs == 0, 'Correct version was reinstalled')
assert(packages.marksman.installs == 1, 'Existing wrong version was not replaced')
assert(packages.gopls.installs == 1, 'Missing package was not installed')
dofile('.config/nvim/install-lsp.lua')
assert(packages.marksman.installs == 1 and packages.gopls.installs == 1, 'Repeated setup reinstalled pinned versions')
packages.gopls.installed = 'old'
packages.gopls.fail = true
local ok, err = pcall(dofile, '.config/nvim/install-lsp.lua')
assert(not ok and tostring(err):find('installation failed'), 'Failed package replacement was silently accepted')
print('Mason pins skip matching versions, replace old versions, and propagate failures.')
