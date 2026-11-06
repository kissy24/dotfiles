return {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
        -- Reveal the current line; keep surrounding context rendered while typing.
        render_modes = { "n", "c", "i" },
        anti_conceal = { enabled = true, above = 0, below = 0 },
        sign = { enabled = false },
        heading = {
            icons = {}, -- Keep # markers so heading levels remain explicit.
            sign = false,
            width = "block",
            right_pad = 1,
            border = false,
        },
        code = {
            sign = false,
            width = "block",
            left_pad = 1,
            right_pad = 1,
            border = "thin",
            language_icon = false,
            language_name = true,
            language_pad = 1,
            inline_pad = 1,
        },
        bullet = { icons = { "•", "◦", "▪" } },
        checkbox = {
            -- Match source width: the cursor can address each character in [ ].
            bullet = true,
            unchecked = { icon = "[ ]" },
            checked = { icon = "[x]", scope_highlight = "RenderMarkdownCheckedText" },
            custom = { todo = { raw = "[-]", rendered = "[-]", highlight = "RenderMarkdownTodo" } },
        },
        quote = { icon = "│" },
        pipe_table = {
            preset = "round",
            cell = "padded",
            padding = 1,
            alignment_indicator = "─",
        },
        win_options = {
            list = { default = vim.wo.list, rendered = false },
            cursorline = { default = vim.wo.cursorline, rendered = true },
            cursorlineopt = { default = vim.wo.cursorlineopt, rendered = "both" },
            winhighlight = {
                default = vim.wo.winhighlight,
                rendered = "CursorLine:RenderMarkdownCursorLine,CursorLineNr:RenderMarkdownCursorLineNr",
            },
            wrap = { default = vim.wo.wrap, rendered = true },
            -- Avoid orphaned list markers before long Japanese text without spaces.
            linebreak = { default = vim.wo.linebreak, rendered = false },
            breakindent = { default = vim.wo.breakindent, rendered = true },
        },
    },
}
