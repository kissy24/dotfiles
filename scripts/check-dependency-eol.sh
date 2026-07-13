#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GITHUB_API_URL=${GITHUB_API_URL:-https://api.github.com}
HOMEBREW_FORMULA_API_URL=${HOMEBREW_FORMULA_API_URL:-https://formulae.brew.sh/api/formula}

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

failures=0

fetch() {
    local url=$1
    shift
    curl --fail --silent --show-error --location --retry 3 "$@" "$url"
}

is_true() {
    local field=$1
    grep -Eq "\"${field}\"[[:space:]]*:[[:space:]]*true"
}

collect_github_repositories() {
    {
        sed -nE "s/^[[:space:]]*[{'\"]?[[:space:]]*['\"]([[:alnum:]_.-]+\/[[:alnum:]_.-]+)['\"].*/\1/p" \
            "$REPO_ROOT"/.config/nvim/lua/plugins/*.lua
        sed -nE 's/.*github[[:space:]]*=[[:space:]]*"([[:alnum:]_.-]+\/[[:alnum:]_.-]+)".*/\1/p' \
            "$REPO_ROOT/.config/sheldon/plugins.toml"
        sed -nE 's#.*https://github\.com/([[:alnum:]_.-]+/[[:alnum:]_.-]+)(\.git)?.*#\1#p' \
            "$REPO_ROOT/.pre-commit-config.yaml" \
            "$REPO_ROOT/.config/nvim/lua/base/lazy.lua"
        find "$REPO_ROOT/.github/workflows" -type f \( -name '*.yml' -o -name '*.yaml' \) \
            -exec sed -nE 's/.*uses:[[:space:]]*([[:alnum:]_.-]+\/[[:alnum:]_.-]+)@.*/\1/p' {} +
    } | sed 's/\.git$//' | sort -u
}

check_github_repositories() {
    local repositories_file=$TMP_ROOT/github-repositories.txt
    local repository response
    local -a headers=(
        --header "Accept: application/vnd.github+json"
        --header "X-GitHub-Api-Version: 2022-11-28"
    )

    collect_github_repositories > "$repositories_file"
    if [[ -n ${GITHUB_TOKEN:-} ]]; then
        headers+=(--header "Authorization: Bearer $GITHUB_TOKEN")
    fi

    echo "Checking GitHub dependency repositories..."
    while IFS= read -r repository; do
        [[ -n $repository ]] || continue
        if ! response=$(fetch "$GITHUB_API_URL/repos/$repository" "${headers[@]}"); then
            echo "ERROR: Could not read GitHub repository metadata: $repository" >&2
            failures=$((failures + 1))
            continue
        fi

        if printf '%s' "$response" | is_true archived; then
            echo "ERROR: GitHub dependency is archived: $repository" >&2
            failures=$((failures + 1))
        elif printf '%s' "$response" | is_true disabled; then
            echo "ERROR: GitHub dependency is disabled: $repository" >&2
            failures=$((failures + 1))
        else
            echo "OK: $repository"
        fi
    done < "$repositories_file"
}

check_homebrew_formulae() {
    local formula response

    echo "Checking Homebrew formula lifecycle metadata..."
    while IFS= read -r formula; do
        [[ -n $formula ]] || continue
        if ! response=$(fetch "$HOMEBREW_FORMULA_API_URL/$formula.json"); then
            echo "ERROR: Could not read Homebrew formula metadata: $formula" >&2
            failures=$((failures + 1))
            continue
        fi

        if printf '%s' "$response" | is_true disabled; then
            echo "ERROR: Homebrew formula is disabled: $formula" >&2
            failures=$((failures + 1))
        elif printf '%s' "$response" | is_true deprecated; then
            echo "ERROR: Homebrew formula is deprecated: $formula" >&2
            failures=$((failures + 1))
        else
            echo "OK: $formula"
        fi
    done < <(sed -nE 's/^brew "([^"]+)".*/\1/p' "$REPO_ROOT/Brewfile")
}

check_github_repositories
check_homebrew_formulae

if (( failures > 0 )); then
    echo "Dependency EOL check failed with $failures error(s)." >&2
    exit 1
fi

echo "All dependency lifecycle checks passed."
