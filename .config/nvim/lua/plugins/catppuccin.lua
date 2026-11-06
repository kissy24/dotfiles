return {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
        require("catppuccin").setup({
            flavour = "mocha",
            transparent_background = true,
            float = {
                transparent = true,
            },
            custom_highlights = function(colors)
                local highlights = {
                    RenderMarkdownBullet = { fg = colors.subtext0 },
                    RenderMarkdownTableHead = { fg = colors.lavender, bold = true },
                    RenderMarkdownTableRow = { fg = colors.overlay1 },
                    RenderMarkdownCursorLine = { bg = colors.surface0 },
                    RenderMarkdownCursorLineNr = { fg = colors.lavender, bold = true },
                    RenderMarkdownUnchecked = { fg = colors.yellow, bold = true },
                    RenderMarkdownChecked = { fg = colors.green, bold = true },
                    RenderMarkdownCheckedText = { fg = colors.subtext0 },
                    ["@markup.list.unchecked.markdown"] = { fg = colors.yellow, bold = true },
                    ["@markup.list.checked.markdown"] = { fg = colors.green, bold = true },
                }
                local headings = {
                    colors.lavender, colors.blue, colors.teal,
                    colors.peach, colors.mauve, colors.subtext1,
                }
                for level, color in ipairs(headings) do
                    highlights["@markup.heading." .. level .. ".markdown"] = { fg = color, bold = true }
                    highlights["RenderMarkdownH" .. level] = { fg = color, bold = true }
                    highlights["RenderMarkdownH" .. level .. "Bg"] = {
                        fg = color, bold = true, bg = level <= 2 and colors.mantle or "NONE",
                    }
                end
                return highlights
            end,
        })

        vim.cmd.colorscheme("catppuccin-mocha")
    end,
}
