#!/usr/bin/env python3
"""Read dependency declarations as data and keep first observations outside PRs.

Only the trusted main-branch observer receives contents:write. The PR checker
can read the ledger but cannot create records or approve a migration baseline.
"""
import argparse
import base64
import datetime as dt
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

from release_age import age_error, epoch, COOLDOWN_SECONDS

REPOSITORY = "kissy24/dotfiles"
STATE_BRANCH = "chore/dependency-observations"
STATE_FILE = "observations.json"
# Existing, reviewed main pins are migration approvals, not publication evidence.
MIGRATION_MAIN = "a83ade427f8c29ca2399615e5f74a112362f5cdb"
SHA = re.compile(r"[0-9a-f]{40}\Z")
REPO = r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"


def relevant(path):
    return (path in {".pre-commit-config.yaml", ".config/sheldon/plugins.toml",
                     ".config/nvim/lazy-lock.json", "packages/bootstrap.json",
                     "packages/bun-lsp/bun.lock", "packages/dependency-exceptions.json"}
            or (path.startswith(".github/workflows/") and path.endswith((".yml", ".yaml")))
            or (path.startswith(".config/nvim/lua/") and path.endswith(".lua")))


def local_files(root):
    names = subprocess.check_output(["git", "-C", str(root), "ls-files", "-z"], text=True).split("\0")
    # Include newly added declarations during local validation, but never follow links.
    names += [str(p.relative_to(root)) for p in (root / "packages").glob("bootstrap.json")]
    result = {}
    for name in sorted(set(filter(relevant, names))):
        path = root / name
        if path.is_symlink() or any(p.is_symlink() for p in path.parents if p != root):
            # /tmp itself may be a platform symlink. Check only repository children.
            if path.resolve() != root.resolve() / name:
                raise ValueError("Declaration escapes repository: " + name)
        result[name] = path.read_text()
    return result


def dependencies(files, strict=True):
    """No shell, YAML tags, Lua evaluation, package installation, or PR imports."""
    github = set()

    def add(repository, commit):
        if not re.fullmatch(REPO, repository) or not SHA.fullmatch(commit):
            raise ValueError("Git dependencies require a full SHA: " + repository)
        github.add(repository.lower() + "@" + commit)

    hooks = files.get(".pre-commit-config.yaml", "")
    for repository, ref in re.findall(
        r"repo:\s*https://github\.com/(" + REPO + r")\s*\n\s*rev:\s*([^\s#]+)", hooks
    ):
        add(repository.removesuffix(".git"), ref)
    if hooks.count("- repo:") != len(re.findall(
        r"repo:\s*https://github\.com/(" + REPO + r")\s*\n\s*rev:\s*([^\s#]+)", hooks
    )):
        raise ValueError("Unsupported pre-commit source")
    for path, content in files.items():
        if path.startswith(".github/workflows/"):
            for ref in re.findall(r"\buses:\s*[\"']?([^\s\"'#]+)", content):
                if ref.startswith("./"):
                    continue
                match = re.fullmatch("(" + REPO + r")(?:/[^@]+)?@([0-9a-f]{40})", ref)
                if not match:
                    raise ValueError("Action must use a full GitHub SHA: " + ref)
                add(*match.groups())
    sheldon = files.get(".config/sheldon/plugins.toml", "")
    for block in re.split(r"(?m)^\[plugins\.", sheldon)[1:]:
        repository = re.search(r'(?m)^github\s*=\s*"(' + REPO + ')"', block)
        revision = re.search(r'(?m)^rev\s*=\s*"([0-9a-f]{40})"', block)
        if repository and revision:
            add(repository[1], revision[1])
        elif strict:
            raise ValueError("Sheldon sources must have github and an exact rev")
    bootstrap = json.loads(files.get("packages/bootstrap.json", "{}"))
    if bootstrap:
        add("Homebrew/install", bootstrap["homebrew_install_commit"])
        if "homebrew_commit" in bootstrap:
            add("Homebrew/brew", bootstrap["homebrew_commit"])
        if not re.fullmatch(r"[0-9a-f]{64}", bootstrap["homebrew_install_sha256"]):
            raise ValueError("Homebrew installer requires SHA256")
        if not re.fullmatch(r"\d+\.\d+\.\d+", bootstrap["pre_commit_version"]):
            raise ValueError("pre-commit must have an exact version")
    repos = {"lazy.nvim": "folke/lazy.nvim"}
    for path, content in files.items():
        if path.startswith(".config/nvim/lua/"):
            matches = re.findall(r'["\'](' + REPO + r')["\']', content)
            for repository in matches:
                repos[repository.split("/")[-1]] = repository
            alias = re.search(r'\bname\s*=\s*["\']([^"\']+)["\']', content)
            if alias and matches:
                repos[alias[1]] = matches[0]
    for name, pin in json.loads(files.get(".config/nvim/lazy-lock.json", "{}" )).items():
        if name not in repos:
            raise ValueError("Cannot map locked Neovim plugin: " + name)
        add(repos[name], pin["commit"])
    npm = set(npm_pins(files))
    if not github:
        raise ValueError("No pinned Git dependencies found")
    return github, npm


def bun_lock_data(source):
    """Decode trailing-comma JSON without rewriting string contents or running Bun."""
    decoder = json.JSONDecoder()
    output, index = [], 0
    while index < len(source):
        char = source[index]
        if char == '"':
            _, end = decoder.raw_decode(source, index)
            output.append(source[index:end])
            index = end
            continue
        if char == "," and source[index + 1:].lstrip().startswith(("}", "]")):
            index += 1
            continue
        output.append(char)
        index += 1
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Duplicate Bun lock key: " + key)
            result[key] = value
        return result
    return json.loads("".join(output), object_pairs_hook=unique)


def npm_pins(files):
    pins = {}
    lock = files.get("packages/bun-lsp/bun.lock", "")
    if not lock:
        return pins
    data = bun_lock_data(lock)
    if data.get("lockfileVersion") != 1 or not isinstance(data.get("packages"), dict):
        raise ValueError("Unsupported Bun lock format")
    for entry in data["packages"].values():
        if not isinstance(entry, list) or len(entry) != 4 or entry[1] != "" or not isinstance(entry[0], str):
            raise ValueError("Only integrity-pinned npm registry entries are supported")
        name, version = entry[0].rsplit("@", 1)
        if not re.fullmatch(r"(?:@[a-z0-9_.-]+/)?[a-z0-9_.-]+", name):
            raise ValueError("Invalid npm package name")
        if not re.fullmatch(r"[0-9][0-9A-Za-z.+-]*", version):
            raise ValueError("npm version must be exact")
        if not isinstance(entry[3], str) or not re.fullmatch(r"sha512-[A-Za-z0-9+/]+={0,2}", entry[3]):
            raise ValueError("npm registry entry requires SHA512 integrity: " + name)
        key = name, version
        if key in pins and pins[key] != entry[3]:
            raise ValueError("Conflicting npm integrity: " + name)
        pins[key] = entry[3]
    if not pins:
        raise ValueError("No supported npm packages found in the Bun lockfile")
    return pins


def npm_publication(data, name, version, integrity):
    if data["versions"][version]["dist"].get("integrity") != integrity:
        raise ValueError("npm registry integrity mismatch: " + name + "@" + version)
    return data["time"][version]


class GitHub:
    def __init__(self):
        self.cache = {}

    def request(self, path, data=None, method=None):
        segments = urllib.parse.unquote(path.split("?", 1)[0]).split("/")
        if not path.startswith("/") or path.startswith("//") or ".." in segments:
            raise ValueError("Invalid API path")
        cacheable = data is None and method is None
        if cacheable and path in self.cache:
            return self.cache[path]
        headers = {"Accept": "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28"}
        token = os.environ.get("GITHUB_TOKEN")
        if token:
            headers["Authorization"] = "Bearer " + token
        if data is not None:
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request("https://api.github.com" + path,
                                         data=None if data is None else json.dumps(data).encode(),
                                         headers=headers, method=method)
        # Never send the token to a different host via redirect.
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, hdrs, newurl):
                raise ValueError("GitHub API redirect rejected")
        with urllib.request.build_opener(NoRedirect).open(request, timeout=60) as response:
            body = response.read(8 * 1024 * 1024 + 1)
            if len(body) > 8 * 1024 * 1024:
                raise ValueError("API response too large")
            result = json.loads(body)
            if cacheable:
                self.cache[path] = result
            return result

    def files(self, repository, sha):
        if not re.fullmatch(REPO, repository) or not SHA.fullmatch(sha):
            raise ValueError("Invalid candidate repository or SHA")
        prefix = "/repos/" + repository
        tree = self.request(prefix + "/git/trees/" + sha + "?recursive=1")
        if tree.get("truncated"):
            raise ValueError("Truncated repository tree")
        files = {}
        for entry in tree["tree"]:
            if not relevant(entry["path"]):
                continue
            if entry["type"] != "blob" or entry["mode"] not in {"100644", "100755"}:
                raise ValueError("Declaration is not a regular file")
            if entry.get("size", 0) > 1024 * 1024:
                raise ValueError("Declaration too large")
            key = repository, entry["sha"]
            if key not in self.cache:
                blob = self.request(prefix + "/git/blobs/" + entry["sha"])
                self.cache[key] = base64.b64decode(blob["content"]).decode()
            files[entry["path"]] = self.cache[key]
        return files

    def ledger(self):
        try:
            ref = self.request(f"/repos/{REPOSITORY}/git/ref/heads/{STATE_BRANCH}")
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None, None
            raise
        sha = ref["object"]["sha"]
        data = self.request(f"/repos/{REPOSITORY}/contents/{STATE_FILE}?ref={sha}")
        ledger = json.loads(base64.b64decode(data["content"]))
        if ledger.get("schema") != 1 or not isinstance(ledger.get("observations"), dict):
            raise ValueError("Invalid observation ledger")
        return ledger, sha

    def write_ledger(self, ledger, parent):
        prefix = f"/repos/{REPOSITORY}"
        content = json.dumps(ledger, indent=2, sort_keys=True) + "\n"
        blob = self.request(prefix + "/git/blobs", {"content": content, "encoding": "utf-8"})
        tree = self.request(prefix + "/git/trees", {"tree": [
            {"path": STATE_FILE, "mode": "100644", "type": "blob", "sha": blob["sha"]}]})
        commit = self.request(prefix + "/git/commits", {
            "message": "chore: record dependency observations", "tree": tree["sha"],
            "parents": [parent] if parent else []})
        if parent:
            self.request(prefix + "/git/refs/heads/" + STATE_BRANCH,
                         {"sha": commit["sha"], "force": False}, "PATCH")
        else:
            self.request(prefix + "/git/refs", {"ref": "refs/heads/" + STATE_BRANCH, "sha": commit["sha"]})


def public_commit(api, key, require_default=True):
    repository, sha = key.split("@")
    metadata = api.request("/repos/" + repository)
    if metadata.get("private") is not False or metadata.get("archived") or metadata.get("disabled"):
        raise ValueError("Dependency must be public and maintained: " + repository)
    commit = api.request("/repos/" + repository + "/commits/" + sha)
    if commit.get("sha") != sha:
        raise ValueError("Dependency commit does not match: " + key)
    # The commit API alone can resolve objects from a fork network. Require the
    # exact commit to be reachable from this repository's default branch.
    if require_default:
        branch = urllib.parse.quote(metadata["default_branch"], safe="")
        comparison = api.request("/repos/" + repository + "/compare/" + sha + "..." + branch)
        if comparison.get("status") not in {"ahead", "identical"}:
            raise ValueError("Commit is not on the public default-branch history: " + key)
    return metadata["id"]


def release_publication(api, key):
    """Only an immutable release binds its publication time to today's exact SHA.

    Mutable release/tag associations are not historical evidence. They fall
    back to verified public observation, never a commit or tagger timestamp.
    """
    repository, sha = key.split("@")
    for page in range(1, 11):
        releases = api.request(f"/repos/{repository}/releases?per_page=100&page={page}")
        for release in releases:
            if release.get("draft") or not release.get("immutable"):
                continue
            tag = urllib.parse.quote(release["tag_name"], safe="")
            commit = api.request(f"/repos/{repository}/commits/{tag}")
            if commit.get("sha") == sha:
                published = release["published_at"]
                epoch(published)
                return published
        if len(releases) < 100:
            return None
    raise ValueError("Too many releases; cannot determine publication: " + key)


def check_observations(keys, ledger, now, identities=None):
    errors = []
    for key in sorted(keys):
        record = ledger["observations"].get(key, {})
        if record.get("baseline") is True:
            print("OK (migration baseline): " + key)
            continue
        if (not record.get("verified_public_at") or identities is None
                or record.get("repository_id") != identities.get(key)):
            errors.append(key + ": no verified public observation (legacy first_seen is not evidence)")
            continue
        error = age_error(key, record["verified_public_at"], now)
        if error:
            errors.append(error)
        else:
            print("OK (verified public observation): " + key)
    return errors


def registry_json(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def trusted_exceptions(api, now):
    # A proposed PR cannot approve its own exception: read main, not the checkout.
    try:
        result = api.request(f"/repos/{REPOSITORY}/contents/packages/dependency-exceptions.json?ref=main")
    except urllib.error.HTTPError as error:
        if error.code == 404:
            return {}
        raise
    data = json.loads(base64.b64decode(result["content"]))["exceptions"]
    allowed = {}
    for key, record in data.items():
        if not (re.fullmatch(REPO + r"@[0-9a-f]{40}", key)
                or re.fullmatch(r"npm:(?:@[a-z0-9_.-]+/)?[a-z0-9_.-]+@[0-9][0-9A-Za-z.+-]*", key)
                or re.fullmatch(r"pypi:pre-commit@[0-9]+\.[0-9]+\.[0-9]+", key)):
            raise ValueError("Exception must identify an exact dependency: " + key)
        if not record.get("reason") or not str(record.get("approval_url", "")).startswith(
                "https://github.com/" + REPOSITORY + "/pull/"):
            raise ValueError("Exception requires a reason and approval PR: " + key)
        remaining = epoch(record["expires_at"]) - now
        if remaining > COOLDOWN_SECONDS:
            raise ValueError("Exception cannot last more than 7 days: " + key)
        if remaining > 0:
            allowed[key] = record
    return allowed


def check(root):
    files = local_files(root)
    keys, npm = dependencies(files)
    api = GitHub()
    ledger, _ = api.ledger()
    if ledger is None:
        ledger = {"observations": {}}  # Dated releases do not require a local ledger.
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    # Freeze the migration to reviewed main; PR declarations cannot add approvals.
    approved, _ = dependencies(api.files(REPOSITORY, MIGRATION_MAIN), strict=False)
    exceptions = trusted_exceptions(api, now)
    errors = []
    for key in sorted(keys):
        if key in approved:
            print("OK (approved main migration): " + key)
            continue
        try:
            published = release_publication(api, key)
            identity = public_commit(api, key, require_default=published is None)
            if key in exceptions:
                print("OK (explicit time-limited exception): " + key)
                continue
            if published is not None:
                error = age_error(key, published, now)
                if error:
                    errors.append(error)
                else:
                    print("OK (release published " + published + "): " + key)
            else:
                errors.extend(check_observations({key}, ledger, now, {key: identity}))
        except (ValueError, KeyError, urllib.error.HTTPError) as error:
            errors.append(key + ": " + str(error))
    integrities = npm_pins(files)
    for name, version in sorted(npm):
        data = registry_json("https://registry.npmjs.org/" + urllib.parse.quote(name, safe="@/"))
        published = npm_publication(data, name, version, integrities[(name, version)])
        error = age_error(name + "@" + version, published, now)
        if error and "npm:" + name + "@" + version not in exceptions:
            errors.append(error)
    bootstrap = json.loads(files.get("packages/bootstrap.json", "{}"))
    if bootstrap:
        version = bootstrap["pre_commit_version"]
        data = registry_json("https://pypi.org/pypi/pre-commit/" + version + "/json")
        uploads = data["urls"]
        if not uploads or any(item.get("yanked") for item in uploads):
            errors.append("pre-commit: missing or yanked distribution")
        else:
            published = max((item["upload_time_iso_8601"] for item in uploads), key=epoch)
            error = age_error("pre-commit@" + version, published, now)
            if error and "pypi:pre-commit@" + version not in exceptions:
                errors.append(error)
    if errors:
        for error in errors:
            print("ERROR: " + error, file=sys.stderr)
        return 1
    print("All managed pins satisfy the publication-age policy.")
    return 0


def server_time():
    # Obtain the timestamp AFTER verifying the public object, not before it.
    request = urllib.request.Request("https://api.github.com/rate_limit?observation=" + uuid.uuid4().hex,
                                     headers={"Cache-Control": "no-cache"})
    with urllib.request.urlopen(request, timeout=60) as response:
        from email.utils import parsedate_to_datetime
        return parsedate_to_datetime(response.headers["Date"]).isoformat()


def observe(initialize=False, candidate=None):
    api = GitHub()
    ledger, parent = api.ledger()
    if initialize and ledger is not None:
        raise ValueError("Migration baseline already exists; refusing to expand it")
    if not initialize and ledger is None:
        raise ValueError("Explicit initialization is required")
    main = api.request(f"/repos/{REPOSITORY}/git/ref/heads/main")["object"]["sha"]
    if initialize:
        keys, _ = dependencies(api.files(REPOSITORY, main), strict=False)
        ledger = {"schema": 1, "baseline_commit": main, "observations": {
            key: {"baseline": True} for key in sorted(keys)}}
    before = json.dumps(ledger, sort_keys=True)
    candidates = [(REPOSITORY, main)]
    if candidate:
        candidates.append((REPOSITORY, candidate))
    else:
        for page in range(1, 11):
            pulls = api.request(f"/repos/{REPOSITORY}/pulls?state=open&per_page=100&page={page}")
            candidates += [(p["head"]["repo"]["full_name"], p["head"]["sha"]) for p in pulls if p["head"]["repo"]]
            if len(pulls) < 100:
                break
        else:
            raise ValueError("Too many open PRs")
    for repository, sha in candidates:
        try:
            keys, _ = dependencies(api.files(repository, sha), strict=False)
        except (ValueError, KeyError, urllib.error.HTTPError) as error:
            print("Cannot observe candidate " + sha + ": " + type(error).__name__, file=sys.stderr)
            continue
        for key in sorted(keys):
            old = ledger["observations"].get(key, {})
            if old.get("baseline"):
                continue
            try:
                published = release_publication(api, key)
                identity = public_commit(api, key, require_default=published is None)
                if published is not None:
                    continue  # No local waiting period for independently dated releases.
                if old.get("verified_public_at") and old.get("repository_id") == identity:
                    continue
                ledger["observations"][key] = {
                    "verified_public_at": server_time(), "repository_id": identity, "candidate": sha,
                }
            except (ValueError, KeyError, urllib.error.HTTPError) as error:
                print("Cannot verify public dependency " + key + ": " + str(error), file=sys.stderr)
    if initialize or json.dumps(ledger, sort_keys=True) != before:
        api.write_ledger(ledger, parent)
        print("Updated trusted dependency observations.")
    else:
        print("No new dependency observations.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check", "observe", "initialize"])
    parser.add_argument("--candidate", help="Additional commit in the canonical repository to observe")
    args = parser.parse_args()
    if args.command == "check":
        return check(Path(__file__).resolve().parent.parent)
    observe(args.command == "initialize", args.candidate)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print("ERROR: " + str(error), file=sys.stderr)
        sys.exit(1)
