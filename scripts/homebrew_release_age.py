#!/usr/bin/env python3
"""Select only Homebrew artifacts with verifiable publication evidence.

No first-seen ledger: missing evidence stays unknown, however long we wait.
Homebrew formula bottles do not expose a supported publication timestamp here.
For now only dependency-free official casks served as immutable GitHub release
assets with a matching digest can be upgraded automatically.
"""
import datetime as dt
import json
from pathlib import Path
import re
import subprocess
import sys
import urllib.parse

from dependency_observations import GitHub
from release_age import age_error, epoch


def publication(kind, info, version, api):
    """Homebrew adapter: return publication evidence, never an inferred date."""
    def unknown(reason):
        return {"published_at": None, "reason": reason}
    if kind == "formula":
        return unknown("Homebrew bottle/build publication evidence is unavailable; review manually")
    if info.get("tap") != "homebrew/cask" or info.get("version") != version:
        return unknown("unsupported tap or candidate version changed")
    if set(info.get("depends_on") or {}) - {"macos", "arch"} or info.get("auto_updates"):
        return unknown("dependencies or self-updates are outside the verified artifact")
    checksum = info.get("sha256", "")
    if not isinstance(checksum, str) or not re.fullmatch(r"[0-9a-f]{64}", checksum):
        return unknown("an exact SHA256 is required")
    match = re.fullmatch(r"https://github.com/([\w.-]+/[\w.-]+)/releases/download/([^/]+)/([^/?#]+)",
                         info.get("url", ""))
    if not match:
        return unknown("no supported release-asset URL")
    repository, tag, filename = match.groups()
    release = api.request(f"/repos/{repository}/releases/tags/{tag}")
    if release.get("draft") or not release.get("immutable"):
        return unknown("release does not bind publication time to immutable assets")
    assets = [a for a in release["assets"] if a["name"] == urllib.parse.unquote(filename)]
    if len(assets) != 1 or assets[0].get("digest") != "sha256:" + checksum:
        return unknown("release asset digest does not match the Homebrew candidate")
    return {"published_at": release["published_at"], "reason": "immutable release asset and SHA256 match"}


def candidate_publication(kind, name, version, get_info, api):
    try:
        info = get_info(kind, name) if kind == "cask" else {}
        evidence = publication(kind, info, version, api)
        if evidence["published_at"] is not None:
            epoch(evidence["published_at"])
        return evidence
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        return {"published_at": None, "reason": "could not verify publication: " + str(error)}


def select(candidates, get_info, api, now):
    eligible = []
    for group, kind in (("formulae", "formula"), ("casks", "cask")):
        for candidate in candidates.get(group, []):
            name, version = candidate["name"], candidate["current_version"]
            if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9@+_.-]*", name):
                print("SKIP unsupported Homebrew name: " + repr(name), file=sys.stderr)
                continue
            evidence = candidate_publication(kind, name, version, get_info, api)
            published = evidence["published_at"]
            reason = age_error(name + "@" + version, published, now)
            if published is None:
                reason += "; " + evidence["reason"]
            if reason:
                print(f"SKIP {kind} {name} {version}: {reason}", file=sys.stderr)
            else:
                print(f"ELIGIBLE {kind} {name} {version}: published_at={published}", file=sys.stderr)
                eligible.append((kind, name))
    return eligible


def main():
    def get_info(kind, name):
        data = json.loads(subprocess.check_output(["brew", "info", "--json=v2", "--" + kind, name], text=True))
        return data["formulae" if kind == "formula" else "casks"][0]

    candidates = json.loads(Path(sys.argv[1]).read_text())
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    for kind, name in select(candidates, get_info, GitHub(), now):
        print(kind + "\t" + name)


if __name__ == "__main__":
    main()
