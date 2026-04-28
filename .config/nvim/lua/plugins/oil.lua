return {
    'stevearc/oil.nvim',
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "malewicz1337/oil-git.nvim",
    },
    config = function(_, opts)
        require("oil").setup(opts)
        require("oil-git").setup()
    end,
    opts = {
        default_file_explorer = true,
        columns = { "icon" },
        win_options = {
            wrap = false,
            signcolumn = "yes",
            cursorcolumn = false,
            foldcolumn = "0",
            spell = false,
            list = false,
            conceallevel = 3,
            concealcursor = "nvic",
        },
        delete_to_trash = true,
        skip_confirm_for_simple_edits = true,
        view_options = {
            show_hidden = true,
        },
        keymaps = {
            ["g?"] = "actions.show_help",
            -- Enterの挙動をカスタマイズ
            ["<CR>"] = {
                desc = "Open file in the window to the right",
                callback = function()
                    local oil = require("oil")
                    local entry = oil.get_cursor_entry()
                    if not entry then
                        return
                    end

                    if entry.type == "directory" then
                        -- ディレクトリならそのままoil内で展開
                        oil.select()
                    else
                        -- ファイルなら右側のウィンドウに移動して開く
                        local path = oil.get_current_dir() .. entry.name
                        vim.cmd("wincmd l") -- 右のウィンドウへ移動

                        -- もし移動先もoilバッファだった（＝右側にウィンドウがなかった）場合はsplitを作る
                        if vim.bo.filetype == "oil" then
                            vim.cmd("vsplit")
                        end

                        vim.cmd("edit " .. vim.fn.fnameescape(path))
                    end
                end,
            },
            ["<C-s>"] = "actions.select_vsplit",
            ["<C-h>"] = "actions.select_split",
            ["<C-t>"] = "actions.select_tab",
            ["<C-p>"] = "actions.preview",
            ["q"] = "actions.close",
            ["<Esc>"] = "actions.close",
            ["<C-l>"] = "actions.refresh",
            ["-"] = "actions.parent",
            ["_"] = "actions.open_cwd",
            ["`"] = "actions.cd",
            ["~"] = "actions.tcd",
            ["gs"] = "actions.change_sort",
            ["gx"] = "actions.open_external",
            ["g."] = "actions.toggle_hidden",
            ["g\\"] = "actions.toggle_trash",
        },
    },
    keys = {
        {
            "<leader>j",
            function()
                local oil = require("oil")
                local found_win = nil

                -- 全てのウィンドウをチェックして oil バッファを探す
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                    local buf = vim.api.nvim_win_get_buf(win)
                    if vim.bo[buf].filetype == "oil" then
                        found_win = win
                        break
                    end
                end

                if found_win then
                    -- oil バッファが見つかったらそのウィンドウを閉じる
                    vim.api.nvim_win_close(found_win, true)
                else
                    -- 見つからなければ新しくサイドバーとして開く
                    vim.cmd("topleft vsplit | vertical resize 30")
                    oil.open()
                end
            end,
            desc = "Toggle Oil sidebar",
        },
    },
}
