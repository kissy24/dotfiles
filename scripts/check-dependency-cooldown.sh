#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GITHUB_API_URL=${GITHUB_API_URL:-https://api.github.com}
NPM_REGISTRY_URL=${NPM_REGISTRY_URL:-https://registry.npmjs.org}
COOLDOWN_DAYS=${COOLDOWN_DAYS:-7}
NOW_EPOCH=${NOW_EPOCH:-$(date +%s)}

if ! [[ $COOLDOWN_DAYS =~ ^[0-9]+$ ]]; then
    echo "ERROR: COOLDOWN_DAYS must be a non-negative integer: $COOLDOWN_DAYS" >&2
    exit 2
fi
if ! [[ $NOW_EPOCH =~ ^[0-9]+$ ]]; then
    echo "ERROR: NOW_EPOCH must be a non-negative integer: $NOW_EPOCH" >&2
    exit 2
fi
[ -f "$REPO_ROOT/flake.lock" ] || {
    echo "ERROR: Missing locked Nix dependency file: flake.lock" >&2
    exit 1
}

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

failures=0
cooldown_seconds=$((COOLDOWN_DAYS * 24 * 60 * 60))

fetch() {
    local url=$1
    shift
    curl --fail --silent --show-error --location --retry 3 "$@" "$url"
}

to_epoch() {
    python3 -c 'import datetime, sys; print(int(datetime.datetime.fromisoformat(sys.stdin.read().strip().replace("Z", "+00:00")).timestamp()))'
}

check_age() {
    local dependency=$1
    local published_at=$2
    local published_epoch age_days

    if ! published_epoch=$(printf '%s' "$published_at" | to_epoch); then
        echo "ERROR: Could not parse publish time for $dependency: $published_at" >&2
        failures=$((failures + 1))
        return
    fi

    if (( published_epoch > NOW_EPOCH )); then
        echo "ERROR: Publish time is in the future for $dependency: $published_at" >&2
        failures=$((failures + 1))
        return
    fi

    age_days=$(((NOW_EPOCH - published_epoch) / 86400))
    if (( NOW_EPOCH - published_epoch < cooldown_seconds )); then
        echo "ERROR: Dependency is only ${age_days} day(s) old; require ${COOLDOWN_DAYS}: $dependency ($published_at)" >&2
        failures=$((failures + 1))
    else
        echo "OK: $dependency (${age_days} day(s) old)"
    fi
}

check_epoch_age() {
    local dependency=$1
    local published_epoch=$2
    local age_days

    if ! [[ $published_epoch =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid lock timestamp for $dependency: $published_epoch" >&2
        failures=$((failures + 1))
        return
    fi
    if (( published_epoch > NOW_EPOCH )); then
        echo "ERROR: Lock timestamp is in the future for $dependency: $published_epoch" >&2
        failures=$((failures + 1))
        return
    fi

    age_days=$(((NOW_EPOCH - published_epoch) / 86400))
    if (( NOW_EPOCH - published_epoch < cooldown_seconds )); then
        echo "ERROR: Dependency is only ${age_days} day(s) old; require ${COOLDOWN_DAYS}: $dependency" >&2
        failures=$((failures + 1))
    else
        echo "OK: $dependency (${age_days} day(s) old)"
    fi
}

collect_github_refs() {
    awk '
        /^[[:space:]]*-[[:space:]]repo:[[:space:]]https:\/\/github\.com\// {
            repo = $0
            sub(/^.*github\.com\//, "", repo)
            sub(/\.git[[:space:]]*$/, "", repo)
            next
        }
        /^[[:space:]]*rev:/ && repo != "" {
            ref = $0
            sub(/^.*rev:[[:space:]]*/, "", ref)
            print repo "|" ref
            repo = ""
        }
    ' "$REPO_ROOT/.pre-commit-config.yaml"

    find "$REPO_ROOT/.github/workflows" -type f \( -name '*.yml' -o -name '*.yaml' \) \
        -exec sed -nE 's/.*uses:[[:space:]]*([[:alnum:]_.-]+\/[[:alnum:]_.-]+)@([^[:space:]#]+).*/\1|\2/p' {} +
}

check_github_refs() {
    local refs_file=$TMP_ROOT/github-refs.txt
    local repository ref response published_at
    local -a headers=(
        --header "Accept: application/vnd.github+json"
        --header "X-GitHub-Api-Version: 2022-11-28"
    )

    collect_github_refs | sort -u > "$refs_file"
    if [[ -n ${GITHUB_TOKEN:-} ]]; then
        headers+=(--header "Authorization: Bearer $GITHUB_TOKEN")
    fi

    echo "Checking GitHub dependency ref ages..."
    while IFS='|' read -r repository ref; do
        [[ -n $repository && -n $ref ]] || continue
        if ! response=$(fetch "$GITHUB_API_URL/repos/$repository/commits/$ref" "${headers[@]}"); then
            echo "ERROR: Could not read GitHub ref metadata: $repository@$ref" >&2
            failures=$((failures + 1))
            continue
        fi

        if ! published_at=$(printf '%s' "$response" | python3 -c 'import json, sys; print(json.load(sys.stdin)["commit"]["committer"]["date"])'); then
            echo "ERROR: Could not read commit time for GitHub ref: $repository@$ref" >&2
            failures=$((failures + 1))
            continue
        fi
        check_age "$repository@$ref" "$published_at"
    done < "$refs_file"
}

collect_npm_packages() {
    sed -nE 's/^[[:space:]]*"[^"]+": \["(@?[^"]+)@([^"]+)",.*/\1|\2/p' \
        "$REPO_ROOT/packages/bun-lsp/bun.lock" | sort -u
}

check_npm_packages() {
    local packages_file=$TMP_ROOT/npm-packages.txt
    local package version response published_at

    collect_npm_packages > "$packages_file"
    echo "Checking npm package release ages..."
    while IFS='|' read -r package version; do
        [[ -n $package && -n $version ]] || continue
        if ! response=$(fetch "$NPM_REGISTRY_URL/$package"); then
            echo "ERROR: Could not read npm package metadata: $package@$version" >&2
            failures=$((failures + 1))
            continue
        fi

        if ! published_at=$(printf '%s' "$response" | python3 -c 'import json, sys; version = sys.argv[1]; print(json.load(sys.stdin)["time"][version])' "$version"); then
            echo "ERROR: Could not read npm publish time: $package@$version" >&2
            failures=$((failures + 1))
            continue
        fi
        check_age "$package@$version" "$published_at"
    done < "$packages_file"
}

check_nix_flake_inputs() {
    local dependency published_epoch

    echo "Checking Nix flake input ages..."
    while IFS='|' read -r dependency published_epoch; do
        [[ -n $dependency && -n $published_epoch ]] || continue
        check_epoch_age "$dependency" "$published_epoch"
    done < <(
        python3 - "$REPO_ROOT/flake.lock" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as lock_file:
    lock = json.load(lock_file)

for name, node in sorted(lock.get("nodes", {}).items()):
    locked = node.get("locked", {})
    modified = locked.get("lastModified")
    if modified is None:
        continue
    owner = locked.get("owner")
    repo = locked.get("repo")
    revision = locked.get("rev", "")
    if owner and repo:
        label = f"{owner}/{repo}@{revision}"
    else:
        label = name
    print(f"{label}|{modified}")
PY
    )
}

check_github_refs
check_npm_packages
check_nix_flake_inputs

if (( failures > 0 )); then
    echo "Dependency cooldown check failed with $failures error(s)." >&2
    exit 1
fi

echo "All pinned dependencies satisfy the ${COOLDOWN_DAYS}-day cooldown."
