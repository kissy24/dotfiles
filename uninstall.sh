#!/bin/bash
set -eu

# Uninstallation script for the dotfiles repository.

SCRIPT_DIR=$(dirname "$0")
REPO_ROOT=$(cd "$SCRIPT_DIR" && pwd)

# --- Helper Functions ---

remove_symlinks() {
    local dotfile_dests=(
        "$HOME/.zshrc"
        "$HOME/.tmux.conf"
        "$HOME/.config/starship.toml"
        "$HOME/.config/nvim"
        "$HOME/.config/wezterm"
        "$HOME/.config/sheldon"
        "$HOME/.config/lazygit"
        "$HOME/.config/gh"
    )

    echo "Removing symlinks and restoring backups..."
    for dest in "${dotfile_dests[@]}"; do
        if [ -L "$dest" ]; then
            echo "- Removing link: $dest"
            rm "$dest"
            
            if [ -e "$dest.bak" ]; then
                echo "- Restoring backup: $dest.bak -> $dest"
                mv "$dest.bak" "$dest"
            fi
        elif [ -e "$dest" ]; then
            echo "- Skipping $dest (not a symbolic link)"
        fi
    done
    echo "Symlink removal complete."
}

uninstall_macos() {
    echo "Uninstalling dependencies for macOS..."
    if command -v brew &> /dev/null; then
        echo "Removing packages via Homebrew..."
        brew uninstall git starship rust lazygit node ripgrep fd gh tmux zoxide fzf go
        
        echo "Removing Neovim from /usr/local..."
        sudo rm -rf /usr/local/bin/nvim /usr/local/share/nvim /usr/local/lib/nvim /usr/local/share/man/man1/nvim.1
    fi
}

uninstall_ubuntu() {
    echo "Uninstalling dependencies for Ubuntu..."
    
    echo "Removing packages via apt..."
    sudo apt purge -y git curl build-essential pkg-config libssl-dev nodejs npm ripgrep fd-find tmux zoxide fzf golang-go gh
    sudo apt autoremove -y

    echo "Removing Neovim..."
    sudo rm -f /usr/local/bin/nvim

    echo "Removing n (Node.js manager) if exists..."
    sudo npm uninstall -g n || true
}

# --- Main Execution ---

# 1. Determine OS
OS=""
case "$(uname)" in
    "Linux") OS="Linux" ;; 
    "Darwin") OS="Darwin" ;; 
    *) echo "Error: Unsupported OS." >&2; exit 1 ;; 
esac

echo "Running uninstallation for $OS..."

# 2. Confirm with user
echo "Warning: This will uninstall tools and remove symlinks."
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 1
fi

# 3. Remove symlinks
echo "--- Removing symlinks ---"
remove_symlinks

# 4. Uninstall dependencies
echo "--- Uninstalling dependencies ---"
if [ "$OS" = "Darwin" ]; then
    uninstall_macos
elif [ "$OS" = "Linux" ]; then
    uninstall_ubuntu
fi

# 5. Remove standalone tools
echo "--- Removing standalone tools ---"

if [ -d "$HOME/.cargo" ]; then
    echo "Removing Rust (rustup)..."
    rustup self uninstall -y || rm -rf "$HOME/.cargo" "$HOME/.rustup"
fi

if [ -d "$HOME/.local/bin/uv" ] || command -v uv &> /dev/null; then
    echo "Removing uv..."
    rm -rf "$HOME/.local/bin/uv" "$HOME/.cargo/bin/uv"
fi

if [ -d "$HOME/.bun" ]; then
    echo "Removing bun..."
    rm -rf "$HOME/.bun"
fi

if [ -f "/usr/local/bin/starship" ]; then
    echo "Removing starship..."
    sudo rm -f /usr/local/bin/starship
fi

if [ -f "/usr/local/bin/lazygit" ]; then
    echo "Removing lazygit..."
    sudo rm -f /usr/local/bin/lazygit
fi

echo "-------------------------------------"
echo "Uninstallation complete! Please restart your terminal."
