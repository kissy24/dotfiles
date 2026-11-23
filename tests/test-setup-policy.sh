#!/bin/bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/setup-policy-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
mkdir -p "$TMP_ROOT/bin"
python3 "$REPO_ROOT/tests/test_bootstrap_artifacts.py"
# Ensure the install path consumes an exact revision and verifies its bytes.
python3 - "$REPO_ROOT" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
pins = json.loads((root / 'packages/bootstrap.json').read_text())
assert re.fullmatch('[0-9a-f]{40}', pins['homebrew_install_commit'])
assert re.fullmatch('[0-9a-f]{64}', pins['homebrew_install_sha256'])
assert re.fullmatch(r'\d+\.\d+\.\d+', pins['pre_commit_version'])
PY
echo 'Setup preserves installed Homebrew versions and declares exact bootstrap pins.'

# Exercise checksum verification with harmless installer bytes, including Python
# optimization mode: a mismatch must never execute the downloaded program.
mkdir -p "$TMP_ROOT/repo/packages" "$TMP_ROOT/repo/scripts"
cat > "$TMP_ROOT/repo/scripts/run-homebrew-installer.sh" <<'RUN'
bash "$1"
RUN
cat > "$TMP_ROOT/installer.sh" <<'INSTALLER'
printf installed > "$BOOTSTRAP_TEST_MARKER"
INSTALLER
cat > "$TMP_ROOT/bin/curl" <<'CURL'
#!/bin/bash
cat "$BOOTSTRAP_TEST_SOURCE"
CURL
chmod +x "$TMP_ROOT/bin/curl"
function_text=$(sed -n '/^install_homebrew_from_pin() {/,/^}/p' "$REPO_ROOT/setup.sh")
for expected in correct wrong; do
    python3 - "$TMP_ROOT" "$expected" <<'PY'
import hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
checksum = hashlib.sha256((root / 'installer.sh').read_bytes()).hexdigest()
if sys.argv[2] == 'wrong':
    checksum = '0' * 64
(root / 'repo/packages/bootstrap.json').write_text(json.dumps({
    'homebrew_install_commit': 'a' * 40, 'homebrew_install_sha256': checksum}))
PY
    rm -f "$TMP_ROOT/executed"
    status=0
    PATH="$TMP_ROOT/bin:$PATH" PYTHONOPTIMIZE=1 \
        BOOTSTRAP_TEST_SOURCE="$TMP_ROOT/installer.sh" BOOTSTRAP_TEST_MARKER="$TMP_ROOT/executed" \
        bash -c 'set -euo pipefail; REPO_ROOT=$1; eval "$2"; install_homebrew_from_pin' \
        _ "$TMP_ROOT/repo" "$function_text" >/dev/null 2>&1 || status=$?
    if [ "$expected" = correct ]; then
        test "$status" -eq 0
        test -f "$TMP_ROOT/executed"
    else
        test "$status" -ne 0
        test ! -e "$TMP_ROOT/executed"
    fi
done
echo 'Installer checksum mismatches stop execution, including with Python optimization.'

# A newer upstream tag must be invisible to the real installer process.
git init -q -b main "$TMP_ROOT/upstream"
git -C "$TMP_ROOT/upstream" -c user.name=test -c user.email=test@example.org commit -q --allow-empty -m first
git -C "$TMP_ROOT/upstream" tag 1.0.0
revision=$(git -C "$TMP_ROOT/upstream" rev-parse HEAD)
git -C "$TMP_ROOT/upstream" -c user.name=test -c user.email=test@example.org commit -q --allow-empty -m next
git -C "$TMP_ROOT/upstream" tag 2.0.0
sed "s|^upstream=.*|upstream=file://$TMP_ROOT/upstream|" "$REPO_ROOT/scripts/run-homebrew-installer.sh" > "$TMP_ROOT/run-installer.sh"
printf '{"homebrew_commit":"%s","homebrew_version":"1.0.0"}\n' "$revision" > "$TMP_ROOT/release.json"
cat > "$TMP_ROOT/check-remote.sh" <<'CHECK'
set -euo pipefail
result=$(git ls-remote --tags "$FIXTURE_UPSTREAM")
test "$result" = "$(printf '%s\trefs/tags/1.0.0' "$EXPECTED_REVISION")"
CHECK
FIXTURE_UPSTREAM="file://$TMP_ROOT/upstream" EXPECTED_REVISION="$revision" \
    bash "$TMP_ROOT/run-installer.sh" "$TMP_ROOT/check-remote.sh" "$TMP_ROOT/release.json"

# A rejected dependency must stop the real setup entry point before any package
# manager or deployment is called. All files and commands below are test doubles.
mkdir -p "$TMP_ROOT/preflight/scripts/lib"
cp "$REPO_ROOT/setup.sh" "$TMP_ROOT/preflight/setup.sh"
: > "$TMP_ROOT/preflight/scripts/lib/dotfiles.sh"
cat > "$TMP_ROOT/preflight/scripts/check-dependency-cooldown.sh" <<'CHECK'
#!/bin/bash
test "${GITHUB_TOKEN:-}" = test-only-token || exit 24
exit 23
CHECK
chmod +x "$TMP_ROOT/preflight/scripts/check-dependency-cooldown.sh"
cat > "$TMP_ROOT/bin/brew" <<'BREW'
#!/bin/bash
touch "$POLICY_TEST_DIR/package-manager-called"
exit 1
BREW
status=0
GITHUB_TOKEN=test-only-token PATH="$TMP_ROOT/bin:$PATH" POLICY_TEST_DIR="$TMP_ROOT" \
    bash "$TMP_ROOT/preflight/setup.sh" --force > "$TMP_ROOT/preflight-output" 2>&1 || status=$?
test "$status" -eq 23
test ! -e "$TMP_ROOT/package-manager-called"

# Successful preflight must not leave credentials in dependency child processes.
gate=$(sed -n '/^dependency_check_token=/,/^unset dependency_check_token/p' "$REPO_ROOT/setup.sh")
cat > "$TMP_ROOT/preflight/scripts/check-dependency-cooldown.sh" <<'CHECK'
#!/bin/bash
test "${GITHUB_TOKEN:-}" = test-only-token
CHECK
GITHUB_TOKEN=test-only-token GH_TOKEN=test-only-token \
    bash -c 'set -euo pipefail; REPO_ROOT=$1; eval "$2"; test -z "${GITHUB_TOKEN:-}"; test -z "${GH_TOKEN:-}"' \
    _ "$TMP_ROOT/preflight" "$gate"
echo 'Publication preflight stops setup before changes and scopes API credentials.'
