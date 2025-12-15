# Dotfiles

![GitHub](https://img.shields.io/github/license/kissy24/dotfiles)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/kissy24/dotfiles)

```sh
❯ tree -a -d -I '.git'
.
├── .config
│   ├── fish
│   ├── lazygit
│   ├── nvim
│   │   └── lua
│   │       ├── base
│   │       └── plugins
│   ├── sheldon
│   └── wezterm
├── .github
│   └── workflows
└── .vscode
```

## Supported OS

- Ubuntu
- MacOS

## Development Environment


| Category          | Tools / Technologies                                   |
|-------------------|--------------------------------------------------------|
| Terminal Emulator | WezTerm                                                |
| Multiplexer       | tmux (independent of WezTerm)                          |
| Editors           | Neovim, Visual Studio Code                             |
| Shell Environment | Zsh, Fish, Starship (prompt), Sheldon (plugin manager) |
| Version Control   | Lazygit                                                |

## Neovim Plugins

```lua

  Total: 38 plugins

  Loaded (35)
    ● barbar.nvim 12.74ms  BufReadPre
    ● catppuccin 0.1ms  start
    ● cmp-nvim-lsp 0.08ms  nvim-lspconfig
    ● cmp_luasnip 0.03ms  nvim-lspconfig
    ● dial.nvim 2.64ms  start
    ● fidget.nvim 0.66ms  nvim-lspconfig
    ● git-blame.nvim 1.76ms  VeryLazy
    ● git.nvim 1.18ms  start
    ● github-theme 7.22ms  start
    ● gitsigns.nvim 2.09ms  start
    ● kanagawa 1.04ms  start
    ● lazy.nvim 3.92ms  init.lua
    ● lazygit.nvim 34.77ms  <leader>lg
    ● lsp_signature.nvim 0.41ms  nvim-lspconfig
    ● lspkind.nvim 0.86ms  nvim-lspconfig
    ● lualine.nvim 5.32ms  VeryLazy
    ● LuaSnip 3.64ms  nvim-lspconfig
    ● markdown-preview.nvim 0.71ms  markdown
    ● mason-lspconfig.nvim 0.36ms  nvim-lspconfig
    ● mason.nvim 0.34ms  nvim-lspconfig
    ● noice.nvim 3.82ms  VeryLazy
    ● none-ls.nvim 0.68ms  nvim-lspconfig
    ● nui.nvim 0.73ms  noice.nvim
    ● nvim-autopairs 2.19ms  start
    ● nvim-cmp 1.74ms  nvim-lspconfig
    ● nvim-lspconfig 37.61ms  start
    ● nvim-notify 2.07ms  noice.nvim
    ● nvim-tree.lua 13.14ms  tr
    ● nvim-treesitter 11.28ms  render-markdown.nvim
    ● nvim-web-devicons 0.11ms  render-markdown.nvim
    ● oil.nvim 2.56ms  start
    ● plenary.nvim 2.14ms  lazygit.nvim
    ● render-markdown.nvim 12.5ms  start
    ● tokyonight.nvim 0.05ms  start
    ● which-key.nvim 1.4ms  VeryLazy

  Not Loaded (3)
    ○ diffview.nvim  <leader>hd  <leader>hf 
    ○ telescope.nvim  fb  fg  fn  ff 
    ○ toggleterm.nvim  <ESC> (t)  tm 
```

## Install

It is assumed that `zsh` and `wezterm` are already installed.

1. Download
   ```sh
    git clone https://github.com/kissy24/dotfiles.git
    cd dotfiles
   ```
2. Setup
   ```sh
    ./setup.sh
   ```

## Author

kissy24
