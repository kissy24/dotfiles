#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$0")
REPO_ROOT=$(cd "$SCRIPT_DIR" && pwd)
FORCE=0

# shellcheck source=scripts/lib/dotfiles.sh
source "$REPO_ROOT/scripts/lib/dotfiles.sh"

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--force]

  --force    Back up and replace existing dotfiles instead of skipping them
  --help     Show this help
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --force)
            FORCE=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

load_brew_environment() {
    if command -v brew >/dev/null 2>&1; then
        eval "$(brew shellenv)"
    elif [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
}

install_homebrew_from_pin() {
    local installer commit checksum
    commit=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["homebrew_install_commit"])' "$REPO_ROOT/packages/bootstrap.json")
    checksum=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["homebrew_install_sha256"])' "$REPO_ROOT/packages/bootstrap.json")
    installer=$(mktemp)
    curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
        "https://raw.githubusercontent.com/Homebrew/install/$commit/install.sh" > "$installer" || {
        rm -f "$installer"
        return 1
    }
    if ! python3 - "$installer" "$checksum" <<'VERIFY'
import hashlib, pathlib, sys
if hashlib.sha256(pathlib.Path(sys.argv[1]).read_bytes()).hexdigest() != sys.argv[2]:
    raise SystemExit("Homebrew installer checksum mismatch")
VERIFY
    then
        rm -f "$installer"
        return 1
    fi
    local status=0
    bash "$REPO_ROOT/scripts/run-homebrew-installer.sh" "$installer" "$REPO_ROOT/packages/bootstrap.json" || status=$?
    rm -f "$installer"
    return "$status"
}

install_homebrew_on_ubuntu() {
    echo "Installing Ubuntu prerequisites for Homebrew..."
    mapfile -t apt_packages < <(sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$REPO_ROOT/packages/apt.txt")
    sudo apt-get update
    sudo apt-get install -y "${apt_packages[@]}"

    if ! command -v brew >/dev/null 2>&1 && [ ! -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
        echo "Installing Homebrew..."
        install_homebrew_from_pin
    fi
    load_brew_environment
}

ensure_homebrew() {
    case "$(uname)" in
        Darwin)
            load_brew_environment
            if ! command -v brew >/dev/null 2>&1; then
                echo "Error: Homebrew is required on macOS. Install it from https://brew.sh/ first." >&2
                exit 1
            fi
            ;;
        Linux)
            if ! command -v apt-get >/dev/null 2>&1; then
                echo "Error: Linux support requires an Ubuntu/Debian environment with apt-get." >&2
                exit 1
            fi
            install_homebrew_on_ubuntu
            ;;
        *)
            echo "Error: Unsupported OS." >&2
            exit 1
            ;;
    esac
}

install_brew_packages() {
    echo "Installing Homebrew packages..."
    python3 "$REPO_ROOT/scripts/install_bottles.py"
}

install_bun_language_servers() {
    local data_home=${XDG_DATA_HOME:-$HOME/.local/share}
    local lsp_dir="$data_home/dotfiles-lsp"

    echo "Installing Bun-managed language servers..."
    mkdir -p "$lsp_dir"
    cp "$REPO_ROOT/packages/bun-lsp/package.json" "$lsp_dir/package.json"
    cp "$REPO_ROOT/packages/bun-lsp/bun.lock" "$lsp_dir/bun.lock"
    (cd "$lsp_dir" && bun install --frozen-lockfile)
}

generate_zsh_caches() {
    local cache_home=${XDG_CACHE_HOME:-$HOME/.cache}
    local completion_dir="$cache_home/dotfiles/zsh"
    local zcompdump=${ZDOTDIR:-$HOME}/.zcompdump
    local temp_file

    echo "Generating Zsh completion caches..."
    mkdir -p "$completion_dir"

    temp_file=$(mktemp "$completion_dir/uv.zsh.XXXXXX")
    uv generate-shell-completion zsh > "$temp_file"
    mv "$temp_file" "$completion_dir/uv.zsh"

    temp_file=$(mktemp "$completion_dir/herdr.zsh.XXXXXX")
    herdr completion zsh > "$temp_file"
    mv "$temp_file" "$completion_dir/herdr.zsh"

    zsh -dfc 'autoload -Uz compinit && compinit -i -d "$1"' _ "$zcompdump"
}

install_pre_commit() (
    export PATH="$HOME/.local/bin:$PATH"
    echo "Installing pre-commit via uv..."
    local version stage
    stage=$(mktemp -d)
    trap 'rm -rf "$stage"' EXIT
    python3 "$REPO_ROOT/scripts/bootstrap_wheels.py" "$stage/wheels"
    export PIP_CONFIG_FILE=/dev/null PIP_NO_INDEX=1 PIP_FIND_LINKS="$stage/wheels"
    export PIP_NO_CACHE_DIR=1 VIRTUALENV_NO_PERIODIC_UPDATE=1
    version=$(python3 -I -c 'import json,sys; print(json.load(open(sys.argv[1]))["pre_commit_version"])' "$REPO_ROOT/packages/bootstrap.json")
    uv --no-config --no-cache tool install --no-index --find-links "$stage/wheels" --no-build \
        --python "$(brew --prefix python@3.13)/bin/python3.13" "pre-commit==$version"
    (cd "$REPO_ROOT" && pre-commit install --install-hooks)
    (cd "$REPO_ROOT" && pre-commit install --hook-type commit-msg --install-hooks)
)

# Stop before installing packages or deploying configuration. Keep API credentials
# scoped to the checker, rather than exposing them to dependency setup programs.
dependency_check_token=${GITHUB_TOKEN:-${GH_TOKEN:-}}
unset GITHUB_TOKEN GH_TOKEN
if [ -z "$dependency_check_token" ] && command -v gh >/dev/null 2>&1; then
    dependency_check_token=$(gh auth token 2>/dev/null || true)
fi
GITHUB_TOKEN="$dependency_check_token" "$REPO_ROOT/scripts/check-dependency-cooldown.sh"
unset dependency_check_token

ensure_homebrew
install_brew_packages
deploy_dotfiles "$REPO_ROOT" "$HOME" "$FORCE"
echo "Configuring WSL startup..."
"$REPO_ROOT/scripts/install-wsl-config.sh" "$FORCE"
install_bun_language_servers
generate_zsh_caches
install_pre_commit

echo "Installing verified native language servers..."
python3 "$REPO_ROOT/scripts/install_native_lsp.py"
"$REPO_ROOT/scripts/restore-plugins.sh"

echo "Setup complete. Restart your terminal."
