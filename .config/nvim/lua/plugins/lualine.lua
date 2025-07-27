return {
    'nvim-lualine/lualine.nvim',
    dependencies = {
        'nvim-tree/nvim-web-devicons',
        'lewis6991/gitsigns.nvim', -- Git情報用
    },
    event = 'VeryLazy',
    config = function()
        -- TokyoNight-Moon カラーパレット
        local colors = {
            bg       = '#222436',
            fg       = '#c8d3f5',
            yellow   = '#ffc777',
            cyan     = '#86e1fc',
            darkblue = '#3e68d7',
            green    = '#c3e88d',
            orange   = '#ff966c',
            violet   = '#c099ff',
            magenta  = '#c099ff',
            blue     = '#82aaff',
            red      = '#ff757f',
            gray1    = '#828bb8',
            gray2    = '#444a73',
            gray3    = '#2d3f76',
        }

        -- Evil テーマ
        local evil_theme = {
            normal = {
                a = { fg = colors.bg, bg = colors.gray1, gui = 'bold' },
                b = { fg = colors.fg, bg = colors.gray3 },
                c = { fg = colors.gray1, bg = colors.bg },
            },
            insert = {
                a = { fg = colors.bg, bg = colors.blue, gui = 'bold' },
                b = { fg = colors.fg, bg = colors.gray3 },
                c = { fg = colors.gray1, bg = colors.bg },
            },
            visual = {
                a = { fg = colors.bg, bg = colors.yellow, gui = 'bold' },
                b = { fg = colors.fg, bg = colors.gray3 },
                c = { fg = colors.gray1, bg = colors.bg },
            },
            replace = {
                a = { fg = colors.bg, bg = colors.red, gui = 'bold' },
                b = { fg = colors.fg, bg = colors.gray3 },
                c = { fg = colors.gray1, bg = colors.bg },
            },
            command = {
                a = { fg = colors.bg, bg = colors.green, gui = 'bold' },
                b = { fg = colors.fg, bg = colors.gray3 },
                c = { fg = colors.gray1, bg = colors.bg },
            },
            terminal = {
                a = { fg = colors.bg, bg = colors.cyan, gui = 'bold' },
                b = { fg = colors.fg, bg = colors.gray3 },
                c = { fg = colors.gray1, bg = colors.bg },
            },
            inactive = {
                a = { fg = colors.gray1, bg = colors.bg, gui = 'bold' },
                b = { fg = colors.gray1, bg = colors.bg },
                c = { fg = colors.gray1, bg = colors.bg },
            }
        }

        -- カスタムコンポーネント関数
        local conditions = {
            buffer_not_empty = function()
                return vim.fn.empty(vim.fn.expand('%:t')) ~= 1
            end,
            hide_in_width = function()
                return vim.fn.winwidth(0) > 80
            end,
            check_git_workspace = function()
                local filepath = vim.fn.expand('%:p:h')
                local gitdir = vim.fn.finddir('.git', filepath .. ';')
                return gitdir and #gitdir > 0 and #gitdir < #filepath
            end,
        }

        -- LSPクライアント表示
        local function lsp_client()
            local clients = vim.lsp.get_clients({ bufnr = 0 })
            if next(clients) == nil then
                return ''
            end

            local client_names = {}
            for _, client in pairs(clients) do
                table.insert(client_names, client.name)
            end
            return '  ' .. table.concat(client_names, ', ')
        end

        -- ファイルサイズ表示
        local function filesize()
            local size = vim.fn.getfsize(vim.fn.expand('%'))
            if size <= 0 then return '' end

            local units = { 'B', 'KB', 'MB', 'GB' }
            local i = 1
            while size > 1024 and i < #units do
                size = size / 1024
                i = i + 1
            end
            return string.format('%.1f%s', size, units[i])
        end

        -- モード表示のカスタマイズ
        local mode_map = {
            ['n']     = 'NORMAL',
            ['no']    = 'OP-PENDING',
            ['nov']   = 'OP-PENDING',
            ['noV']   = 'OP-PENDING',
            ['no\22'] = 'OP-PENDING',
            ['niI']   = 'NORMAL',
            ['niR']   = 'NORMAL',
            ['niV']   = 'NORMAL',
            ['nt']    = 'TERMINAL',
            ['ntT']   = 'TERMINAL',
            ['v']     = 'VISUAL',
            ['vs']    = 'VISUAL',
            ['V']     = 'V-LINE',
            ['Vs']    = 'V-LINE',
            ['\22']   = 'V-BLOCK',
            ['\22s']  = 'V-BLOCK',
            ['s']     = 'SELECT',
            ['S']     = 'S-LINE',
            ['\19']   = 'S-BLOCK',
            ['i']     = 'INSERT',
            ['ic']    = 'INSERT',
            ['ix']    = 'INSERT',
            ['R']     = 'REPLACE',
            ['Rc']    = 'REPLACE',
            ['Rx']    = 'REPLACE',
            ['Rv']    = 'V-REPLACE',
            ['Rvc']   = 'V-REPLACE',
            ['Rvx']   = 'V-REPLACE',
            ['c']     = 'COMMAND',
            ['cv']    = 'EX',
            ['ce']    = 'EX',
            ['r']     = 'REPLACE',
            ['rm']    = 'MORE',
            ['r?']    = 'CONFIRM',
            ['!']     = 'SHELL',
            ['t']     = 'TERMINAL',
        }

        local config = {
            options = {
                theme = evil_theme,
                component_separators = { left = '', right = '' },
                section_separators = { left = '', right = '' },
                disabled_filetypes = { statusline = {}, winbar = {} },
                ignore_focus = {},
                always_divide_middle = true,
                globalstatus = true,
                refresh = {
                    statusline = 1000,
                    tabline = 1000,
                    winbar = 1000,
                }
            },
            sections = {
                lualine_a = {
                    {
                        'mode',
                        fmt = function(str)
                            return '  ' .. (mode_map[vim.fn.mode()] or str)
                        end,
                    },
                },
                lualine_b = {
                    {
                        'branch',
                        icon = '',
                        color = { fg = colors.violet, gui = 'bold' },
                        cond = conditions.check_git_workspace,
                    },
                    {
                        'diff',
                        symbols = { added = ' ', modified = ' ', removed = ' ' },
                        diff_color = {
                            added = { fg = colors.green },
                            modified = { fg = colors.orange },
                            removed = { fg = colors.red },
                        },
                        cond = conditions.hide_in_width,
                    },
                },
                lualine_c = {
                    {
                        'filename',
                        cond = conditions.buffer_not_empty,
                        color = { fg = colors.magenta, gui = 'bold' },
                        path = 1,
                        symbols = {
                            modified = '  ',
                            readonly = '  ',
                            unnamed = '[No Name]',
                            newfile = '[New]',
                        }
                    },
                    {
                        filesize,
                        cond = conditions.buffer_not_empty and conditions.hide_in_width,
                        color = { fg = colors.gray1 },
                    },
                },
                lualine_x = {
                    {
                        'diagnostics',
                        sources = { 'nvim_diagnostic' },
                        symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' },
                        diagnostics_color = {
                            error = { fg = colors.red },
                            warn = { fg = colors.yellow },
                            info = { fg = colors.cyan },
                            hint = { fg = colors.blue },
                        },
                    },
                    {
                        lsp_client,
                        color = { fg = colors.cyan },
                        cond = conditions.hide_in_width,
                    },
                    {
                        'encoding',
                        fmt = string.upper,
                        cond = conditions.hide_in_width,
                        color = { fg = colors.green, gui = 'bold' },
                    },
                    {
                        'fileformat',
                        fmt = string.upper,
                        icons_enabled = true,
                        color = { fg = colors.green, gui = 'bold' },
                        cond = conditions.hide_in_width,
                    },
                    {
                        'filetype',
                        color = { fg = colors.blue },
                        cond = conditions.hide_in_width,
                    },
                },
                lualine_y = {
                    {
                        'progress',
                        color = { fg = colors.fg, gui = 'bold' },
                    },
                },
                lualine_z = {
                    {
                        'location',
                        color = { fg = colors.fg, gui = 'bold' },
                    },
                },
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = {
                    {
                        'filename',
                        cond = conditions.buffer_not_empty,
                        color = { fg = colors.gray1 },
                    }
                },
                lualine_x = { 'location' },
                lualine_y = {},
                lualine_z = {}
            },
            tabline = {},
            winbar = {},
            inactive_winbar = {},
            extensions = { 'neo-tree', 'lazy', 'mason', 'trouble', 'toggleterm' }
        }

        require('lualine').setup(config)
    end,
}
