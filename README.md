# Dotfiles

[![License: MIT](https://img.shields.io/github/license/kissy24/dotfiles)](LICENSE)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/kissy24/dotfiles)

Personal development environment for macOS and Ubuntu. The setup script installs the
command-line tools used by these dotfiles and links the configuration files into
`$HOME`.

## Supported environments

- macOS (Homebrew is required)
- Ubuntu and other Debian-based Linux distributions that provide `apt`
- x86_64 (the Neovim downloads in `setup.sh` are architecture-specific)

Zsh and WezTerm must already be installed. On Windows, the WezTerm configuration can
launch `Ubuntu-24.04` in WSL, but the setup script itself must be run inside macOS or
Linux.

## Included tools

| Category | Tools |
| --- | --- |
| Terminal | WezTerm, tmux |
| Shell | Zsh, Starship, Sheldon, zoxide, fzf |
| Editor | Neovim (nightly on macOS, latest AppImage on Linux) |
| Git | Git, GitHub CLI, Lazygit |
| Languages and runtimes | Bun, Go, Rust, uv |
| Search | ripgrep, fd |

Neovim uses `lazy.nvim` and includes LSP support, completion, Telescope search, Oil
file navigation, Git integrations, and the Catppuccin Mocha theme. Mason installs
language servers for Lua, TypeScript/JavaScript, HTML, CSS, JSON, Markdown, Python,
and Go.

## Managed configuration

```text
.
├── .config
│   ├── gh
│   ├── lazygit
│   ├── nvim
│   │   └── lua
│   │       ├── base
│   │       └── plugins
│   ├── sheldon
│   ├── wezterm
│   └── starship.toml
├── .github
│   └── workflows
├── .tmux.conf
├── .zshrc
├── setup.sh
└── uninstall.sh
```

`setup.sh` creates the following symbolic links:

| Repository source | Destination |
| --- | --- |
| `.zshrc` | `~/.zshrc` |
| `.tmux.conf` | `~/.tmux.conf` |
| `.config/starship.toml` | `~/.config/starship.toml` |
| `.config/nvim` | `~/.config/nvim` |
| `.config/wezterm` | `~/.config/wezterm` |
| `.config/sheldon` | `~/.config/sheldon` |
| `.config/lazygit` | `~/.config/lazygit` |
| `.config/gh` | `~/.config/gh` |

If a destination already exists, it is moved to the same path with a `.bak` suffix
before the link is created. GitHub CLI credentials in `.config/gh/hosts.yml` are not
tracked.

## Installation

Install [WezTerm](https://wezterm.org/) and Zsh first. On macOS, also install
[Homebrew](https://brew.sh/). Then run:

```sh
git clone https://github.com/kissy24/dotfiles.git
cd dotfiles
bash ./setup.sh
```

The script installs system packages, so it may request `sudo`. It then creates the
links, installs Bun and Sheldon, synchronizes Neovim plugins, and locks Sheldon
plugins. Restart the terminal after it completes.

The terminal configuration expects the `HackGen Console NF` font. Install it
separately if it is not already available.

## Uninstallation

```sh
bash ./uninstall.sh
```

The uninstaller asks for confirmation, removes the managed links, restores matching
`.bak` files, and removes the packages and standalone tools listed in the script—even
if they existed before setup was run. Review it before uninstalling on a machine where
those tools are shared with another environment.

## Development

The GitHub Actions workflow validates setup, symlink creation, and uninstallation on
Ubuntu and macOS. Optional local checks use `pre-commit`:

```sh
pre-commit install
pre-commit install --hook-type commit-msg
pre-commit run --all-files
```

## License

[MIT](LICENSE)
