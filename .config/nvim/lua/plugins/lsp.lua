return {
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/nvim-cmp",
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            "j-hui/fidget.nvim",
        },
        config = function()
            -- -------------------------------------------------------
            -- mason
            -- -------------------------------------------------------
            require("mason").setup({
                ui = {
                    icons = {
                        package_installed   = "✓",
                        package_pending     = "➜",
                        package_uninstalled = "✗",
                    },
                },
            })

            -- -------------------------------------------------------
            -- mason-lspconfig
            -- -------------------------------------------------------
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            vim.lsp.config("*", { capabilities = capabilities })
            vim.lsp.config("lua_ls", {
                settings = {
                    Lua = {
                        runtime = { version = "LuaJIT" },
                        workspace = {
                            checkThirdParty = false,
                            library = { vim.env.VIMRUNTIME },
                        },
                        diagnostics = { globals = { "vim" } },
                    },
                },
            })
            vim.lsp.config("gopls", {
                settings = {
                    gopls = {
                        completeUnimported = true,
                        usePlaceholders    = true,
                        analyses           = {
                            unusedparams = true,
                            shadow       = true,
                        },
                        staticcheck        = true,
                    },
                },
            })

            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls",   -- Lua
                    "marksman", -- Markdown
                    "gopls",    -- Go
                },
                automatic_enable = true,
            })

            -- npm由来のLanguage ServerはNode/MasonではなくBunで管理する。
            local data_home = vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")
            local bun_lsp_bin = data_home .. "/dotfiles-lsp/node_modules/.bin/"
            local bun_servers = {
                ts_ls = "typescript-language-server",
                html = "vscode-html-language-server",
                cssls = "vscode-css-language-server",
                jsonls = "vscode-json-language-server",
                pyright = "pyright-langserver",
            }
            for server_name, executable in pairs(bun_servers) do
                vim.lsp.config(server_name, {
                    cmd = { "bun", bun_lsp_bin .. executable, "--stdio" },
                })
                vim.lsp.enable(server_name)
            end

            -- -------------------------------------------------------
            -- LspAttach: キーマップ & 保存時フォーマット
            -- -------------------------------------------------------
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local bufnr = args.buf
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if not client then return end

                    -- キーマップ
                    local opts = { noremap = true, silent = true, buffer = bufnr }
                    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
                    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
                    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
                    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                    vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end, opts)
                    vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
                    vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
                    vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)

                    -- 保存時: organizeImports → format
                    local group = vim.api.nvim_create_augroup("LspFormatAndOrganize_" .. bufnr, { clear = true })
                    vim.api.nvim_create_autocmd("BufWritePre", {
                        group    = group,
                        buffer   = bufnr,
                        callback = function()
                            -- organizeImports（Go / TypeScript 等）
                            local params = vim.lsp.util.make_range_params(0, "utf-8")
                            params.context = { only = { "source.organizeImports" } }
                            local results = vim.lsp.buf_request_sync(
                                bufnr, "textDocument/codeAction", params, 1000
                            )
                            for _, res in pairs(results or {}) do
                                for _, r in pairs(res.result or {}) do
                                    if r.edit then
                                        vim.lsp.util.apply_workspace_edit(r.edit, "utf-8")
                                    elseif r.command then
                                        vim.lsp.buf.execute_command(r.command)
                                    end
                                end
                            end

                            -- フォーマット
                            if client.supports_method("textDocument/formatting") then
                                vim.lsp.buf.format({ bufnr = bufnr })
                            end
                        end,
                    })
                end,
            })

            -- -------------------------------------------------------
            -- nvim-cmp
            -- -------------------------------------------------------
            local cmp = require("cmp")

            cmp.setup({
                mapping = cmp.mapping.preset.insert({
                    ['<C-b>']     = cmp.mapping.scroll_docs(-4),
                    ['<C-f>']     = cmp.mapping.scroll_docs(4),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-e>']     = cmp.mapping.abort(),
                    ['<CR>']      = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
                }),
                sources = cmp.config.sources(
                    { { name = 'nvim_lsp' } },
                    { { name = 'buffer' } }
                ),
            })

            cmp.setup.cmdline({ '/', '?' }, {
                mapping = cmp.mapping.preset.cmdline(),
                sources = { { name = 'buffer' } },
            })

            cmp.setup.cmdline(':', {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources(
                    { { name = 'path' } },
                    { { name = 'cmdline' } }
                ),
            })

            -- -------------------------------------------------------
            -- fidget（LSP進捗表示）
            -- -------------------------------------------------------
            require("fidget").setup()
        end,
    },
}
