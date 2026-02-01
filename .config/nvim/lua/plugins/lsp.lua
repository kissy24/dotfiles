return {
    -- LSP Client (nvim-lspconfig)
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
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            "j-hui/fidget.nvim",
            "nvim-tree/nvim-web-devicons",
            "onsails/lspkind.nvim",
            "nvimtools/none-ls.nvim",
            "ray-x/lsp_signature.nvim",
        },
        config = function()
            -- mason.nvim の設定
            require("mason").setup({
                ui = {
                    icons = {
                        package_installed = "✓",
                        package_pending = "➜",
                        package_uninstalled = "✗",
                    },
                },
            })

            -- 共通のcapabilitiesを設定
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            -- mason-lspconfig の設定
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls",   -- Lua
                    "ts_ls",    -- TypeScript/JavaScript
                    "html",     -- HTML
                    "cssls",    -- CSS
                    "jsonls",   -- JSON
                    "marksman", -- Markdown
                    "pyright",  -- Python
                    "gopls",    -- Go
                },
                handlers = {
                    -- デフォルトハンドラ (設定が不要なサーバー用)
                    function(server_name)
                        require("lspconfig")[server_name].setup({
                            capabilities = capabilities,
                        })
                    end,

                    -- Lua LSP (lua_ls) の個別設定
                    ["lua_ls"] = function()
                        require("lspconfig").lua_ls.setup({
                            capabilities = capabilities,
                            settings = {
                                Lua = {
                                    runtime = {
                                        version = "LuaJIT",
                                    },
                                    workspace = {
                                        checkThirdParty = false,
                                        library = {
                                            vim.env.VIMRUNTIME,
                                        },
                                    },
                                    diagnostics = {
                                        globals = { "vim" },
                                    },
                                },
                            },
                        })
                    end,

                    -- Go LSP (gopls) の個別設定
                    ["gopls"] = function()
                        require("lspconfig").gopls.setup({
                            capabilities = capabilities,
                            settings = {
                                gopls = {
                                    completeUnimported = true,
                                    usePlaceholders = true,
                                    analyses = {
                                        unusedparams = true,
                                        shadow = true,
                                    },
                                    staticcheck = true,
                                },
                            },
                        })
                    end,
                },
            })

            -- LSPのキーマップ設定
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local bufnr = args.buf
                    local client = vim.lsp.get_client_by_id(args.data.client_id)

                    -- LSP機能を有効にするバッファのオプションを設定
                    -- omnifuncはlspconfigが自動的に設定することが多いが、明示的に設定しても良い
                    if client.server_capabilities.completionProvider then
                        vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
                    end

                    -- キーマップ設定
                    local opts = { noremap = true, silent = true, buffer = bufnr }
                    vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
                    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
                    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
                    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
                    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
                    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
                    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
                    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
                    vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format { async = true } end, opts)

                    -- diagnostics (診断メッセージ)
                    vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
                    vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
                    vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)

                    -- 保存時に import を整理してからフォーマットする（LSP が対応していれば）
                    if client then
                        local group = vim.api.nvim_create_augroup("LspFormatAndOrganize_" .. bufnr, { clear = true })
                        vim.api.nvim_create_autocmd("BufWritePre", {
                            group = group,
                            buffer = bufnr,
                            callback = function()
                                -- 1) source.organizeImports を要求して適用（対応していれば）
                                local params = vim.lsp.util.make_range_params()
                                params.context = { only = { "source.organizeImports" } }

                                local results = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 1000)
                                for _, res in pairs(results or {}) do
                                    for _, r in pairs(res.result or {}) do
                                        if r.edit then
                                            vim.lsp.util.apply_workspace_edit(r.edit, "utf-8")
                                        elseif r.command then
                                            vim.lsp.buf.execute_command(r.command)
                                        end
                                    end
                                end

                                -- 2) その後フォーマット（必要なら同期で）
                                if client.supports_method and client.supports_method("textDocument/formatting") then
                                    vim.lsp.buf.format({ bufnr = bufnr })
                                end
                            end,
                        })
                    end


                    -- lsp_signature の設定 (アタッチ時)
                    require("lsp_signature").on_attach({
                        bind = true,
                        handler_opts = {
                            border = "rounded"
                        }
                    }, bufnr)
                end,
            })

            -- nvim-cmp の設定
            local cmp = require("cmp")
            local luasnip = require("luasnip")

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                mapping = cmp.mapping.preset.insert({
                    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
                    ['<C-f>'] = cmp.mapping.scroll_docs(4),
                    ['<C-Space>'] = cmp.mapping.complete(),
                    ['<C-e>'] = cmp.mapping.abort(),
                    ['<CR>'] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),

                }),
                sources = cmp.config.sources({
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                }, {
                    { name = 'buffer' },
                }),
            })

            -- コマンドライン補完
            cmp.setup.cmdline({ '/', '?' }, {
                mapping = cmp.mapping.preset.cmdline(),
                sources = {
                    { name = 'buffer' }
                }
            })
            cmp.setup.cmdline(':', {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources({
                    { name = 'path' }
                }, {
                    { name = 'cmdline' }
                })
            })

            -- LSPの進捗表示
            require("fidget").setup({
                notification = {
                    window = {
                        avoid = { "NvimTree" },
                    },
                },
            })
        end,
    },
}

