return {
    -- LSP Client (nvim-lspconfig)
    {
        "neovim/nvim-lspconfig",
        dependencies = {
            "williamboman/mason.nvim",
            "williamboman/mason-lspconfig.nvim",
            "hrsh7th/nvim-cmp",
            "hrsh7th/cmp-nvim-lsp",
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

            -- mason-lspconfig の設定
            require("mason-lspconfig").setup({
                ensure_installed = {
                    "lua_ls", -- Lua
                    "ts_ls", -- TypeScript/JavaScript
                    "html", -- HTML
                    "cssls", -- CSS
                    "jsonls", -- JSON
                    "marksman", -- Markdown
                    "pyright", -- Python
                    "gopls", -- Go
                },
            })

            -- LSPのキーマップ設定
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(args)
                    local bufnr = args.buf
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    -- LSP機能を有効にするバッファのオプションを設定
                    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

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

                    -- 保存時に自動フォーマット
                    if client and client.supports_method("textDocument/formatting") then
                        vim.api.nvim_create_autocmd("BufWritePre", {
                            group = vim.api.nvim_create_augroup("Format_" .. bufnr, { clear = true }),
                            buffer = bufnr,
                            callback = function()
                                vim.lsp.buf.format({ bufnr = bufnr })
                            end,
                        })
                    end
                end,
            })

            -- 共通のcapabilitiesを設定
            local capabilities = require("cmp_nvim_lsp").default_capabilities()

            -- Lua LSP (lua_ls) の設定
            vim.lsp.config.lua_ls = {
                cmd = { "lua-language-server" },
                filetypes = { "lua" },
                root_markers = { ".luarc.json", ".luarc.jsonc", ".luacheckrc", ".stylua.toml", "stylua.toml", "selene.toml", "selene.yml", ".git" },
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
            }

            -- Python LSP (pyright) の設定
            vim.lsp.config.pyright = {
                cmd = { "pyright-langserver", "--stdio" },
                filetypes = { "python" },
                root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile", "pyrightconfig.json", ".git" },
                capabilities = capabilities,
            }

            -- Go LSP (gopls) の設定
            vim.lsp.config.gopls = {
                cmd = { "gopls" },
                filetypes = { "go", "gomod", "gowork", "gotmpl" },
                root_markers = { "go.work", "go.mod", ".git" },
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
            }

            -- Markdown LSP (marksman) の設定
            vim.lsp.config.marksman = {
                cmd = { "marksman", "server" },
                filetypes = { "markdown", "markdown.mdx" },
                root_markers = { ".marksman.toml", ".git" },
                capabilities = capabilities,
            }

            -- HTML LSP (html) の設定
            vim.lsp.config.html = {
                cmd = { "vscode-html-language-server", "--stdio" },
                filetypes = { "html", "templ" },
                root_markers = { "package.json", ".git" },
                capabilities = capabilities,
            }

            -- CSS LSP (cssls) の設定
            vim.lsp.config.cssls = {
                cmd = { "vscode-css-language-server", "--stdio" },
                filetypes = { "css", "scss", "less" },
                root_markers = { "package.json", ".git" },
                capabilities = capabilities,
            }

            -- JSON LSP (jsonls) の設定
            vim.lsp.config.jsonls = {
                cmd = { "vscode-json-language-server", "--stdio" },
                filetypes = { "json", "jsonc" },
                root_markers = { "package.json", ".git" },
                capabilities = capabilities,
            }

            -- TypeScript/JavaScript LSP (ts_ls) の設定
            vim.lsp.config.ts_ls = {
                cmd = { "typescript-language-server", "--stdio" },
                filetypes = { "javascript", "javascriptreact", "javascript.jsx", "typescript", "typescriptreact", "typescript.tsx" },
                root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
                capabilities = capabilities,
            }

            -- LSPサーバーを有効化
            vim.lsp.enable("lua_ls")
            vim.lsp.enable("pyright")
            vim.lsp.enable("gopls")
            vim.lsp.enable("marksman")
            vim.lsp.enable("html")
            vim.lsp.enable("cssls")
            vim.lsp.enable("jsonls")
            vim.lsp.enable("ts_ls")

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
                    ['<CR>'] = cmp.mapping.confirm({ select = true }),
                }),
                sources = cmp.config.sources({
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                }),
            })

            -- コマンドライン補完 (任意)
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

            -- LSPの進捗表示 (fidget.nvim を使う場合)
            require("fidget").setup({})
        end,
    },
}
