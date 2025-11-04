#!/bin/bash
set -eu

# Main setup script for the dotfiles repository.

SCRIPT_DIR=$(dirname "$0")
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

# --- Helper Functions ---

install_for_macos() {
    echo "Installing dependencies for macOS..."
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew is not installed. Please install it first." >&2
        exit 1
    fi
    
    echo "Installing packages via Homebrew..."
    brew install git starship rust lazygit node

    echo "Installing Neovim (nightly) for macOS..."
    local temp_dir
    temp_dir=$(mktemp -d)
    
    (
        cd "$temp_dir"
        echo "Downloading Neovim..."
        curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim-macos-x86_64.tar.gz
        
        echo "Extracting Neovim..."
        tar xzf nvim-macos-x86_64.tar.gz
        
        echo "Installing Neovim to /usr/local..."
        sudo rsync -a --delete nvim-macos-x86_64/ /usr/local/
    )
    
    echo "Cleaning up..."
    rm -rf "$temp_dir"
    
    echo "Neovim installation complete."

    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # The 'uv' installer places the binary in ~/.cargo/bin or ~/.local/bin
    # Ensure ~/.local/bin is in PATH for subsequent commands if needed,
    # but typically the user's shell config handles this for new sessions.
    # If you need 'uv' immediately in this script, uncomment the next line:
    # source "$HOME/.local/bin/env"
}

install_for_ubuntu() {
    echo "Installing dependencies for Ubuntu..."
    
    echo "Updating apt repositories..."
    sudo apt update
    
    echo "Installing packages via apt..."
    sudo apt install -y git curl build-essential pkg-config libssl-dev nodejs npm

    echo "Installing and configuring latest Node.js via n..."
    sudo npm install -g n
    sudo n stable
    sudo apt purge -y nodejs npm

    echo "Installing Neovim (latest) for Linux..."
    curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
    chmod u+x nvim-linux-x86_64.appimage
    sudo mv nvim-linux-x86_64.appimage /usr/local/bin/nvim

    echo "Installing Rust toolchain via rustup..."
    curl --proto '=https' -sSf https://sh.rustup.rs | sh -s -- -y

    echo "Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y

    echo "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    sudo install lazygit /usr/local/bin
    rm lazygit.tar.gz lazygit

    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    # The 'uv' installer places the binary in ~/.cargo/bin or ~/.local/bin
    # Ensure ~/.local/bin is in PATH for subsequent commands if needed,
    # but typically the user's shell config handles this for new sessions.
    # If you need 'uv' immediately in this script, uncomment the next line:
    # source "$HOME/.local/bin/env"

}

create_symlinks() {
    local dotfile_sources=(
        "$REPO_ROOT/.zshrc"
        "$REPO_ROOT/.config/starship.toml"
        "$REPO_ROOT/.config/nvim"
        "$REPO_ROOT/.config/wezterm"
        "$REPO_ROOT/.config/sheldon"
        "$REPO_ROOT/.config/lazygit"
    )
    local dotfile_dests=(
        "$HOME/.zshrc"
        "$HOME/.config/starship.toml"
        "$HOME/.config/nvim"
        "$HOME/.config/wezterm"
        "$HOME/.config/sheldon"
        "$HOME/.config/lazygit"
    )

    echo "Creating symlinks..."
    for i in "${!dotfile_sources[@]}"; do
        src="${dotfile_sources[$i]}"
        dest="${dotfile_dests[$i]}"
        mkdir -p "$(dirname "$dest")"
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
                echo "- Link already exists for $dest"
                continue
            else
                echo "- Backing up existing file/directory: $dest"
                mv "$dest" "$dest.bak"
            fi
        fi
        echo "- Creating link: $dest -> $src"
        ln -s "$src" "$dest"
    done
    echo "Symlink creation complete."
}

# --- Main Execution ---

# 1. Determine OS
OS=""
case "$(uname)" in
    "Linux") OS="Linux" ;; 
    "Darwin") OS="Darwin" ;; 
    *) echo "Error: Unsupported OS." >&2; exit 1 ;; 
esac

echo "Running setup for $OS..."

# 2. Install dependencies
echo "--- Installing dependencies ---"
if [ "$OS" = "Darwin" ]; then
    install_for_macos
elif [ "$OS" = "Linux" ]; then
    if ! command -v apt &> /dev/null; then
        echo "Error: This Linux script is for Debian-based systems (like Ubuntu) using apt." >&2
        exit 1
    fi
    install_for_ubuntu
fi

# If on Linux, rustup will have installed cargo to ~/.cargo/bin. Add it to the PATH for this session.
if [ "$OS" = "Linux" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# 3. Create symlinks
echo "--- Creating symlinks ---"
create_symlinks

# 4. Post-installation steps
echo "--- Running post-installation steps ---"

if command -v cargo &> /dev/null; then
    echo "Installing/Updating sheldon via cargo..."
    cargo install sheldon
else
    echo "Warning: cargo not found. Skipping sheldon installation." >&2
fi

if command -v nvim &> /dev/null; then
    echo "Syncing Neovim plugins..."
    nvim --headless -c 'Lazy sync' -c 'qa'
else
    echo "Warning: nvim not found. Skipping Neovim plugin sync." >&2
fi

if command -v sheldon &> /dev/null; then
    echo "Locking sheldon plugins..."
    sheldon lock
else
    echo "Warning: sheldon not found. Skipping sheldon lock." >&2
fi

echo "-------------------------------------"
echo "Setup complete! Please restart your terminal."