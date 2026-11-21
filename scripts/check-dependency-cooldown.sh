#!/bin/bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PYTHONDONTWRITEBYTECODE=1
python3 "$REPO_ROOT/scripts/dependency_observations.py" check
python3 "$REPO_ROOT/scripts/bootstrap_wheels.py"
python3 "$REPO_ROOT/scripts/install_native_lsp.py" --check
