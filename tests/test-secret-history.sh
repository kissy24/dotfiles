#!/bin/bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/secret-history-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
cp "$REPO_ROOT/.pre-commit-config.yaml" "$TMP_ROOT/.pre-commit-config.yaml"
git -C "$TMP_ROOT" init -q
git -C "$TMP_ROOT" config user.name 'Secret Scan Test'
git -C "$TMP_ROOT" config user.email test@example.invalid
git -C "$TMP_ROOT" config core.hooksPath /dev/null
git -C "$TMP_ROOT" config commit.gpgsign false
# Random, nonfunctional test data. Never use a real credential or print the value.
python3 - "$TMP_ROOT/config.txt" <<'PY'
import pathlib, secrets, sys
pathlib.Path(sys.argv[1]).write_text('api_key = "' + secrets.token_urlsafe(32) + '"\n')
PY
git -C "$TMP_ROOT" add -- .pre-commit-config.yaml config.txt
git -C "$TMP_ROOT" commit -qm 'Add synthetic nonfunctional credential'
git -C "$TMP_ROOT" rm -q config.txt
git -C "$TMP_ROOT" commit -qm 'Remove synthetic credential'
(cd "$TMP_ROOT" && pre-commit run betterleaks-working-tree --hook-stage manual --all-files) > "$TMP_ROOT/working.log" 2>&1
status=0
(cd "$TMP_ROOT" && pre-commit run betterleaks-history --hook-stage manual --all-files) > "$TMP_ROOT/history.log" 2>&1 || status=$?
test "$status" -eq 1
grep -q generic-api-key "$TMP_ROOT/history.log"
echo 'History scanning catches credentials removed by a later commit.'
