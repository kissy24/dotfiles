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

REPOSITORY = "kissy24/dotfiles"
STATE_BRANCH = "chore/dependency-observations"
STATE_FILE = "observations.json"
SHA = re.compile(r"[0-9a-f]{40}\Z")
REPO = r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+"


def relevant(path):
    return (path in {".pre-commit-config.yaml", ".config/sheldon/plugins.toml",
                     ".config/nvim/lazy-lock.json", "packages/bootstrap.json",
                     "packages/bun-lsp/bun.lock"}
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
    npm = set(re.findall(r'^\s*"[^"]+": \["(@?[^"\n]+)@([^"\n]+)",',
                         files.get("packages/bun-lsp/bun.lock", ""), re.M))
    if not github:
        raise ValueError("No pinned Git dependencies found")
    return github, npm


class GitHub:
    def __init__(self):
        self.cache = {}

    def request(self, path, data=None, method=None):
        if not path.startswith("/") or ".." in path:
            raise ValueError("Invalid API path")
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
            return json.loads(body)

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


def epoch(value):
    return int(dt.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())


def check_observations(keys, ledger, now, days=7):
    errors = []
    for key in sorted(keys):
        record = ledger["observations"].get(key)
        if record is None:
            errors.append(key + ": not yet observed by the trusted observer")
        elif record.get("baseline") is True:
            print("OK (migration baseline): " + key)
        else:
            age = now - epoch(record["first_seen"])
            if age < days * 86400:
                errors.append(key + ": fewer than 7 days since first observation (" + record["first_seen"] + ")")
            else:
                print("OK (observed): " + key)
    return errors


def check(root):
    keys, npm = dependencies(local_files(root))
    api = GitHub()
    ledger, _ = api.ledger()
    if ledger is None:
        raise ValueError("Trusted ledger is missing; initialize it explicitly before checking dependencies")
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    errors = check_observations(keys, ledger, now)
    for name, version in sorted(npm):
        url = "https://registry.npmjs.org/" + urllib.parse.quote(name, safe="@/")
        with urllib.request.urlopen(url, timeout=60) as response:
            published = json.load(response)["time"][version]
        if now - epoch(published) < 7 * 86400:
            errors.append(name + "@" + version + ": fewer than 7 days since npm publication")
    if errors:
        for error in errors:
            print("ERROR: " + error, file=sys.stderr)
        return 1
    print("All dependencies satisfy the cooldown policy.")
    return 0


def observe(initialize=False, candidate=None):
    api = GitHub()
    ledger, parent = api.ledger()
    if initialize and ledger is not None:
        raise ValueError("Migration baseline already exists; refusing to expand it")
    if not initialize and ledger is None:
        raise ValueError("Explicit initialization is required")
    main = api.request(f"/repos/{REPOSITORY}/git/ref/heads/main")["object"]["sha"]
    # GitHub's server clock, never a contributor-supplied Git commit timestamp.
    # A freshly created GitHub blob/commit is not a clock. Read the HTTPS Date header.
    request = urllib.request.Request("https://api.github.com/rate_limit?observation=" + uuid.uuid4().hex,
                                     headers={"Cache-Control": "no-cache"})
    with urllib.request.urlopen(request, timeout=60) as response:
        from email.utils import parsedate_to_datetime
        timestamp = parsedate_to_datetime(response.headers["Date"]).isoformat()
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
        for key in keys:
            ledger["observations"].setdefault(key, {"first_seen": timestamp, "candidate": sha})
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
