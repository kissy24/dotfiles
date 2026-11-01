#!/bin/bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=scripts/lib/dotfiles.sh
source "$REPO_ROOT/scripts/lib/dotfiles.sh"
force=0
case "${1:-}" in
    --force) force=1 ;;
    '') ;;
    *) echo "Usage: ./scripts/deploy-config.sh [--force]" >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || exit 2
deploy_dotfiles "$REPO_ROOT" "$HOME" "$force"
