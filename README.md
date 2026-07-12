# Dotfiles

[![License: MIT](https://img.shields.io/github/license/kissy24/dotfiles)](LICENSE)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/kissy24/dotfiles)

Personal development environment for macOS and Ubuntu/WSL. Homebrew installs the
shared command-line tools and the setup script links the configuration files into
`$HOME`.

## Requirements

- macOS or an Ubuntu/Debian environment with `apt-get`
- Zsh and WezTerm
- `HackGen Console NF`
- Homebrew on macOS

On Ubuntu, the setup script installs Homebrew and its apt prerequisites. Zsh,
WezTerm, and the font must be installed separately.

## Installation

Install the complete environment with:

```sh
git clone https://github.com/kissy24/dotfiles.git
cd dotfiles
./setup.sh
```

Existing dotfiles are skipped by default. Use `./setup.sh --force` to replace
them with managed symbolic links. This permanently removes the paths being
replaced, so review them first.

Package declarations live in `Brewfile`, `packages/apt.txt`, and
`packages/bun-lsp/package.json`. Sheldon and Mason
dependencies remain in their respective configuration files.

## Included environment

- Starship, Sheldon, zoxide, and fzf integration for Zsh
- tmux session and pane management
- Neovim stable with Lazy.nvim, completion, Telescope, Oil, Git integration,
  and LSP support
- Bun-only JavaScript/TypeScript tooling; Node.js and npm are not installed
- Go with gopls
- uv with pre-commit and Python tooling

The fzf Zsh integration enables Ctrl-R history search, Ctrl-T file selection,
Alt-C directory selection, and fuzzy completion.

## Managed configuration

`setup.sh` creates links for `.zshrc`, `.tmux.conf`, and the
Starship, Neovim, WezTerm, Sheldon, Lazygit, and GitHub CLI configurations.

Neovim plugins are synchronized with Lazy.nvim. Lua, Markdown, and Go language
servers are managed by Mason. TypeScript/JavaScript, HTML, CSS, JSON, and Python
language servers are installed from the tracked Bun manifest and run with Bun.

## Uninstallation

The safe default removes only symbolic links managed by this repository:

```sh
./uninstall.sh
```

Package removal must be explicitly requested and confirmed:

```sh
./uninstall.sh --packages
```

This removes declared packages even if they existed before this setup was run.

## Development

The GitHub Actions workflow validates the scripts on Ubuntu and macOS. Local
checks are installed through uv during setup:

```sh
./scripts/smoke-test.sh
pre-commit run --all-files
```

The smoke test exercises CLI startup, ripgrep and fzf searches, a tmux session,
zoxide database operations, Bun/Go/Python execution, and a TypeScript Language
Server attachment inside headless Neovim. GUI rendering and GitHub authentication
remain manual checks.

## License

[MIT](LICENSE)
