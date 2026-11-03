local name = assert(vim.env.DOTFILES_TEST_LSP, "DOTFILES_TEST_LSP is required")
local client
assert(vim.wait(15000, function()
    client = vim.lsp.get_clients({ bufnr = 0, name = name })[1]
    return client and client.initialized
end, 100), name .. " did not initialize")
assert(client.config.cmd[1] == "bun", name .. " must run through Bun")

-- Initialization alone does not prove that tsserver or Pyright can analyze code.
-- Both fixtures deliberately assign a string to a numeric variable on line 1.
if name == "ts_ls" or name == "pyright" then
    local function type_error(diagnostics, is_lsp)
        for _, diagnostic in ipairs(diagnostics) do
            local line = is_lsp and diagnostic.range.start.line or diagnostic.lnum
            if line == 0 and diagnostic.severity == vim.diagnostic.severity.ERROR then
                return true
            end
        end
        return false
    end

    -- Pyright dynamically registers pull diagnostics; request them explicitly
    -- in this headless check rather than waiting for a push notification.
    if name == "pyright" then
        assert(vim.wait(15000, function()
            return client:supports_method("textDocument/diagnostic")
        end, 100), "Pyright did not register pull diagnostics")
        local response, err = client:request_sync("textDocument/diagnostic", {
            textDocument = { uri = vim.uri_from_bufnr(0) },
            identifier = "Pyright",
        }, 30000, 0)
        assert(response and not response.err, vim.inspect(err or response))
        assert(type_error(response.result.items, true), "Pyright did not report the deliberate type error")
    else
        local namespace = vim.lsp.diagnostic.get_namespace(client.id)
        assert(vim.wait(30000, function()
            return type_error(vim.diagnostic.get(0, { namespace = namespace }), false)
        end, 100), name .. " did not report the deliberate type error")
    end
end

print(name .. " Bun LSP smoke test passed.")
