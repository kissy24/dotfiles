#!/bin/bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export PYTHONDONTWRITEBYTECODE=1
exec python3 "$REPO_ROOT/scripts/dependency_observations.py" check
