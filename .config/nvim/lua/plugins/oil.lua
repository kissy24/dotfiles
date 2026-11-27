local float_win_options = {
    winblend = 0,
    winhighlight = "Normal:OilFloat,NormalFloat:OilFloat,FloatBorder:OilFloatBorder,FloatTitle:OilFloatTitle",
}

return {
    'stevearc/oil.nvim',
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "malewicz1337/oil-git.nvim",
    },
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
        float = {
            max_width = 0.8,
            max_height = 0.8,
            border = "rounded",
            win_options = float_win_options,
        },
        preview_win = {
            win_options = float_win_options,
        },
        delete_to_trash = true,
        skip_confirm_for_simple_edits = true,
        view_options = {
            show_hidden = true,
        },
        keymaps = {
            ["g?"] = "actions.show_help",
            ["<CR>"] = "actions.select",
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
                require("oil").toggle_float()
            end,
            desc = "Toggle Oil floating explorer",
        },
    },
}
