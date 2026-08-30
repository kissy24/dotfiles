#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCE_CONFIG="$REPO_ROOT/.wslconfig"
ACTION=${1:-0}

if [ "${DOTFILES_TEST_WSL:-0}" != 1 ]; then
    if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
        exit 0
    fi
    if ! command -v powershell.exe >/dev/null 2>&1 || ! command -v wslpath >/dev/null 2>&1; then
        echo "- Skipping Windows .wslconfig: Windows interop is unavailable"
        exit 0
    fi
fi

if [ -n "${WSL_CONFIG_DEST:-}" ]; then
    dest=$WSL_CONFIG_DEST
else
    windows_profile=$(powershell.exe -NoProfile -NonInteractive -Command \
        '[Environment]::GetFolderPath("UserProfile")' | tr -d '\r')
    dest=$(wslpath -u "${windows_profile}\\.wslconfig")
fi

mkdir -p "$(dirname "$dest")"
if [ "$ACTION" = remove ]; then
    if cmp -s "$SOURCE_CONFIG" "$dest"; then
        rm "$dest"
        echo "- Removed managed Windows config: $dest"
    else
        echo "- Keeping unmanaged Windows config: $dest"
    fi
    exit 0
fi

if cmp -s "$SOURCE_CONFIG" "$dest"; then
    echo "- Windows config already installed: $dest"
    exit 0
fi
if [ -e "$dest" ] && [ "$ACTION" -ne 1 ]; then
    echo "- Skipping existing Windows config: $dest (use --force to replace)"
    exit 0
fi

cp "$SOURCE_CONFIG" "$dest"
echo "- Installed Windows config: $dest"
echo "  Run 'wsl.exe --shutdown' from PowerShell after setup to apply it."
