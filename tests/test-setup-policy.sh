#!/bin/bash
set -euo pipefail
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/setup-policy-test.XXXXXX")
trap 'rm -rf "$TMP_ROOT"' EXIT
mkdir -p "$TMP_ROOT/bin"
# Simulate an installed older package and a missing new dependency. The installer
# must fill the missing dependency without upgrading the existing one.
printf 'old\n' > "$TMP_ROOT/installed"
cat > "$TMP_ROOT/bin/brew" <<'BREW'
#!/bin/bash
set -euo pipefail
no_upgrade=0
for arg in "$@"; do [ "$arg" != --no-upgrade ] || no_upgrade=1; done
if [ "$no_upgrade" = 0 ] || [ "${HOMEBREW_NO_INSTALL_UPGRADE:-0}" != 1 ]; then
    printf 'new\n' > "$POLICY_TEST_DIR/installed"
fi
printf 'installed\n' > "$POLICY_TEST_DIR/missing"
BREW
chmod +x "$TMP_ROOT/bin/brew"
function_text=$(sed -n '/^install_brew_packages() {/,/^}/p' "$REPO_ROOT/setup.sh")
PATH="$TMP_ROOT/bin:$PATH" POLICY_TEST_DIR="$TMP_ROOT" \
    bash -c 'REPO_ROOT=$1; eval "$2"; install_brew_packages' _ "$REPO_ROOT" "$function_text" >/dev/null
grep -qx old "$TMP_ROOT/installed"
grep -qx installed "$TMP_ROOT/missing"
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
mkdir -p "$TMP_ROOT/repo/packages"
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
