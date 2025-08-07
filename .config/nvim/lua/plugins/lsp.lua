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

      -- mason-lspconfig の設定:
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",         -- Lua
          "ts_ls",       -- TypeScript/JavaScript
          "html",           -- HTML
          "cssls",          -- CSS
          "jsonls",         -- JSON
          "marksman",       -- Markdown
          "pyright",        -- Python
          "gopls",          -- Go
        },
      })

      -- nvim-lspconfig の設定
      local lspconfig = require("lspconfig")

      -- LSPのキーマップ設定 (on_attach 関数内で定義)
      local on_attach = function(client, bufnr)
        -- LSP機能を有効にするバッファのオプションを設定 (任意)
        vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

        -- 以下のキーマップは、LSPがアタッチされたバッファでのみ有効になります
        local opts = { noremap = true, silent = true }
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
        if client.supports_method("textDocument/formatting") then
          vim.api.nvim_create_autocmd("BufWritePre", {
            group = vim.api.nvim_create_augroup("Format", { clear = true }),
            buffer = bufnr,
            callback = function()
              vim.lsp.buf.format({ bufnr = bufnr })
            end,
          })
        end
      end

      -- 各LSPサーバーのセットアップは、lspconfig.<server_name>.setup{} の形式で直接記述します。
      local common_lsp_opts = {
          on_attach = on_attach,
          capabilities = require("cmp_nvim_lsp").default_capabilities(), -- nvim-cmpと連携する場合
      }

      -- Lua LSP (lua_ls) の設定
      lspconfig.lua_ls.setup(vim.tbl_deep_extend("force", common_lsp_opts, {
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
      }))

      -- Python LSP (pyright) の設定
      lspconfig.pyright.setup(vim.tbl_deep_extend("force", common_lsp_opts, {
          -- settings = { ... } など、pyright 固有の設定をここに追加
      }))

      -- Go LSP (gopls) の設定
      lspconfig.gopls.setup(vim.tbl_deep_extend("force", common_lsp_opts, {
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
      }))

      -- Markdown LSP (marksman) の設定
      lspconfig.marksman.setup(vim.tbl_deep_extend("force", common_lsp_opts, {
          -- settings = { ... } など、marksman 固有の設定をここに追加
      }))

      -- HTML LSP (html) の設定 (通常、特別な設定は不要)
      lspconfig.html.setup(common_lsp_opts)

      -- CSS LSP (cssls) の設定 (通常、特別な設定は不要)
      lspconfig.cssls.setup(common_lsp_opts)

      -- JSON LSP (jsonls) の設定 (通常、特別な設定は不要)
      lspconfig.jsonls.setup(common_lsp_opts)

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
          ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' }, -- For luasnip users.
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