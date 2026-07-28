#!/bin/bash
set -euo pipefail

MISE_VERSION=v2026.7.7
INSTALL_PATH=${MISE_INSTALL_PATH:-$HOME/.local/bin/mise}
RELEASE_BASE_URL="https://github.com/jdx/mise/releases/download/$MISE_VERSION"

if command -v mise >/dev/null 2>&1; then
    existing_path=$(command -v mise)
    if [ "$existing_path" != "$INSTALL_PATH" ]; then
        echo "Using externally managed mise: $existing_path"
        exit 0
    fi

    current_version=$(mise --version | awk 'NR == 1 { print $1 }')
    if [ "$current_version" = "${MISE_VERSION#v}" ]; then
        echo "mise $MISE_VERSION is already installed: $INSTALL_PATH"
        exit 0
    fi
fi

command -v curl >/dev/null 2>&1 || {
    echo "Error: curl is required to install mise." >&2
    exit 1
}

case "$(uname -s)" in
    Darwin) platform=macos ;;
    Linux) platform=linux ;;
    *)
        echo "Error: Unsupported OS for mise installation." >&2
        exit 1
        ;;
esac

case "$(uname -m)" in
    arm64|aarch64) arch=arm64 ;;
    x86_64|amd64) arch=x64 ;;
    *)
        echo "Error: Unsupported architecture for mise installation." >&2
        exit 1
        ;;
esac

asset="mise-${MISE_VERSION}-${platform}-${arch}"
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/mise-install.XXXXXX")
trap 'rm -rf "$tmp_root"' EXIT

echo "Installing mise $MISE_VERSION..."
curl --fail --silent --show-error --location \
    "$RELEASE_BASE_URL/$asset" \
    --output "$tmp_root/$asset"
curl --fail --silent --show-error --location \
    "$RELEASE_BASE_URL/SHASUMS256.txt" \
    --output "$tmp_root/SHASUMS256.txt"

expected_checksum=$(awk -v asset="./$asset" '$2 == asset { print $1 }' "$tmp_root/SHASUMS256.txt")
if [ -z "$expected_checksum" ]; then
    echo "Error: mise checksum is missing for $asset." >&2
    exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
    actual_checksum=$(sha256sum "$tmp_root/$asset" | awk '{ print $1 }')
elif command -v shasum >/dev/null 2>&1; then
    actual_checksum=$(shasum -a 256 "$tmp_root/$asset" | awk '{ print $1 }')
else
    echo "Error: sha256sum or shasum is required to verify mise." >&2
    exit 1
fi

if [ "$actual_checksum" != "$expected_checksum" ]; then
    echo "Error: mise checksum verification failed for $asset." >&2
    exit 1
fi

mkdir -p "$(dirname "$INSTALL_PATH")"
chmod 0755 "$tmp_root/$asset"
mv "$tmp_root/$asset" "$INSTALL_PATH"
echo "Installed mise to $INSTALL_PATH"
