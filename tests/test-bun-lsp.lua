local name = assert(vim.env.DOTFILES_TEST_LSP, "DOTFILES_TEST_LSP is required")
local client
assert(vim.wait(15000, function()
    client = vim.lsp.get_clients({ bufnr = 0, name = name })[1]
    return client and client.initialized
end, 100), name .. " did not initialize")
assert(client.config.cmd[1] == "bun", name .. " must run through Bun")
assert(vim.fn.maparg("<leader>cf", "n", false, true).desc, "LSP format mapping is missing")
assert(vim.fn.maparg("<leader>f", "n") == "", "LSP format must not shadow the search prefix")

-- The Python fixture assigns a string to an int on line 1.
if name == "pyright" then
    assert(vim.wait(15000, function()
        return client:supports_method("textDocument/diagnostic")
    end, 100), "Pyright did not register pull diagnostics")
    local response, err = client:request_sync("textDocument/diagnostic", {
        textDocument = { uri = vim.uri_from_bufnr(0) },
        identifier = "Pyright",
    }, 30000, 0)
    assert(response and not response.err, vim.inspect(err or response))
    assert(vim.iter(response.result.items):any(function(diagnostic)
        return diagnostic.range.start.line == 0 and diagnostic.severity == vim.diagnostic.severity.ERROR
    end), "Pyright did not report the deliberate type error")
end

print(name .. " Bun LSP smoke test passed.")
