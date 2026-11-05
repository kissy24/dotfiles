-- Neovim 0.12 native completion: buffer words and LSP completion use the native popup.
vim.opt.complete = { ".", "o" }
vim.opt.completeopt = { "menu", "menuone", "noselect", "popup" }
vim.opt.autocomplete = true
vim.opt.autocompletedelay = 100

vim.keymap.set("i", "<C-Space>", function()
    if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/completion" }) > 0 then
        vim.lsp.completion.get()
    else
        vim.api.nvim_feedkeys(vim.keycode("<C-n>"), "n", false)
    end
end, { desc = "Start native completion" })
vim.keymap.set("i", "<CR>", function()
    if vim.fn.pumvisible() == 1 and vim.fn.complete_info().selected >= 0 then
        return "<C-y>"
    end
    return "<CR>"
end, { expr = true, desc = "Accept selected completion or insert newline" })

-- Keep Tab indentation outside an active LSP snippet.
for key, direction in pairs({ ["<Tab>"] = 1, ["<S-Tab>"] = -1 }) do
    vim.keymap.set({ "i", "s" }, key, function()
        if vim.snippet.active({ direction = direction }) then
            vim.schedule(function() vim.snippet.jump(direction) end)
            return ""
        end
        return key
    end, { expr = true, desc = "Jump within native snippet" })
end

vim.opt.wildmode = "noselect:lastused,full"
vim.opt.wildoptions = "pum"
local group = vim.api.nvim_create_augroup("DotfilesNativeCompletion", { clear = true })
vim.api.nvim_create_autocmd("CmdlineChanged", {
    group = group,
    pattern = { ":", "/", "?" },
    callback = function() vim.fn.wildtrigger() end,
})
