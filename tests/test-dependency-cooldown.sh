#!/bin/bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_ROOT/tests/test_dependency_observations.py"
PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_ROOT/tests/test_homebrew_release_age.py"
