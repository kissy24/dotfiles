#!/bin/bash
set -euo pipefail

NIX_VERSION=2.35.1
NIX_INSTALL_URL="https://releases.nixos.org/nix/nix-${NIX_VERSION}/install"

load_nix_environment() {
    local profile_script

    for profile_script in \
        /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
        "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
        if [ -r "$profile_script" ]; then
            # shellcheck disable=SC1090
            . "$profile_script"
            break
        fi
    done
}

load_nix_environment
if command -v nix >/dev/null 2>&1; then
    echo "Nix is already installed."
    exit 0
fi

command -v curl >/dev/null 2>&1 || {
    echo "Error: curl is required to install Nix." >&2
    exit 1
}

case "$(uname -s)" in
    Darwin)
        install_mode=--daemon
        ;;
    Linux)
        if [ "$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]')" = systemd ]; then
            install_mode=--daemon
        else
            install_mode=--no-daemon
        fi
        ;;
    *)
        echo "Error: Nix installation is supported only on macOS and Linux." >&2
        exit 1
        ;;
esac

installer=$(mktemp "${TMPDIR:-/tmp}/install-nix.XXXXXX")
trap 'rm -f "$installer"' EXIT

echo "Installing Nix ${NIX_VERSION} (${install_mode})..."
curl \
    --proto '=https' \
    --tlsv1.2 \
    --fail \
    --silent \
    --show-error \
    --location \
    "$NIX_INSTALL_URL" \
    --output "$installer"
NIX_INSTALLER_NO_MODIFY_PROFILE=1 sh "$installer" "$install_mode" --yes
