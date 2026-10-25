#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dependency-cooldown-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
mkdir -p "$TMP_ROOT/repo/scripts" "$TMP_ROOT/repo/.github/workflows" \
    "$TMP_ROOT/repo/packages/bun-lsp" "$TMP_ROOT/bin"
cp "$REPO_ROOT/scripts/check-dependency-cooldown.sh" "$TMP_ROOT/repo/scripts/"

cat > "$TMP_ROOT/repo/.pre-commit-config.yaml" <<'EOF'
repos:
  - repo: https://github.com/example/hook
    rev: 3e8a8703264a2f4a69428a0aa4dcb512790b2c8c  # v6.0.0
EOF
cat > "$TMP_ROOT/repo/.github/workflows/test.yml" <<'EOF'
steps:
  - uses: example/action@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
EOF
cat > "$TMP_ROOT/repo/packages/bun-lsp/bun.lock" <<'EOF'
{
  "packages": {
    "demo": ["demo@1.0.0", "", {}, "test-integrity"],
  }
}
EOF
cat > "$TMP_ROOT/bin/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
url=${!#}
printf '%s\n' "$url" >> "$COOLDOWN_TEST_LOG"
case "$url" in
    https://api.github.com/repos/example/hook/commits/3e8a8703264a2f4a69428a0aa4dcb512790b2c8c|\
    https://api.github.com/repos/example/action/commits/9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0)
        printf '{"commit":{"committer":{"date":"%s"}}}\n' "$COOLDOWN_TEST_DATE" ;;
    https://registry.npmjs.org/demo)
        printf '{"time":{"1.0.0":"%s"}}\n' "$COOLDOWN_TEST_DATE" ;;
    *) echo "Unexpected metadata URL: $url" >&2; exit 1 ;;
esac
EOF
chmod +x "$TMP_ROOT/bin/curl"

for published in 2026-01-01T00:00:00Z 2026-01-19T00:00:00Z; do
    status=0
    : > "$TMP_ROOT/requests"
    PATH="$TMP_ROOT/bin:$PATH" \
        GITHUB_TOKEN='' GITHUB_API_URL=https://api.github.com NPM_REGISTRY_URL=https://registry.npmjs.org \
        COOLDOWN_DAYS=7 NOW_EPOCH=1768867200 \
        COOLDOWN_TEST_DATE="$published" COOLDOWN_TEST_LOG="$TMP_ROOT/requests" \
        "$TMP_ROOT/repo/scripts/check-dependency-cooldown.sh" > "$TMP_ROOT/output" 2>&1 || status=$?
    test "$(wc -l < "$TMP_ROOT/requests" | tr -d ' ')" = 3
    if [ "$published" = 2026-01-01T00:00:00Z ]; then
        test "$status" -eq 0
    else
        test "$status" -eq 1
        grep -q 'failed with 3 error(s)' "$TMP_ROOT/output"
    fi
done
echo "Dependency cooldown checks parse SHA comments and reject recent dependencies."
