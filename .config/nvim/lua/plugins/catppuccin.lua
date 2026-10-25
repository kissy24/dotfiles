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
                    RenderMarkdownCheckedText = { fg = colors.overlay1, strikethrough = true },
                }
                local headings = {
                    colors.lavender, colors.blue, colors.text,
                    colors.text, colors.subtext1, colors.subtext0,
                }
                for level, color in ipairs(headings) do
                    highlights["@markup.heading." .. level .. ".markdown"] = { fg = color, bold = true }
                    highlights["RenderMarkdownH" .. level] = { fg = color, bold = true }
                    highlights["RenderMarkdownH" .. level .. "Bg"] = { fg = color, bold = true, bg = "NONE" }
                end
                return highlights
            end,
        })

        vim.cmd.colorscheme("catppuccin-mocha")
    end,
}
