"""Verify that a reviewed multi-platform bottle index was publicly registered before the cutoff."""
import concurrent.futures
import datetime as dt
import json
from pathlib import Path
import re
import sys
import tempfile
import urllib.request
from urllib.parse import quote

from dependency_observations import GitHub
from install_bottles import fetch_index
from release_age import age_error

PACKAGES = Path(__file__).resolve().parents[1] / "packages"


def verify(name, record, now):
    image = "core/" + name.replace("@", "/").replace("+", "x")
    api = GitHub()
    prefix = "/orgs/Homebrew/packages/container/" + quote(image, safe="")
    package = api.request(prefix)
    if package["visibility"] != "public":
        raise ValueError("Non-public package: " + name)
    version = api.request(prefix + "/versions/" + str(int(record["id"])))
    digest = record["digest"]
    if not re.fullmatch("[0-9a-f]{64}", digest) or version["name"] != "sha256:" + digest:
        raise ValueError("Registry index digest mismatch: " + name)
    published = version["created_at"]
    error = age_error(name, published, now)
    if error:
        raise ValueError(error)
    if published != record["published_at"]:
        raise ValueError("Registry publication date mismatch: " + name)
    return published


def check_bootstrap_ruby(bootstrap, now):
    record = bootstrap["homebrew_portable_ruby"]
    with tempfile.TemporaryDirectory(prefix="dotfiles-ruby-") as tmp:
        index, _, _ = fetch_index("portable-ruby", record, Path(tmp), now)
    digests = {m["annotations"]["org.opencontainers.image.ref.name"]: m["annotations"]["sh.brew.bottle.digest"]
               for m in index["manifests"]}
    base = "https://raw.githubusercontent.com/Homebrew/brew/" + bootstrap["homebrew_commit"] + "/Library/Homebrew/vendor/"
    with urllib.request.urlopen(base + "portable-ruby-version", timeout=30) as response:
        if response.read().decode().strip() != record["version"]:
            raise ValueError("Homebrew portable Ruby version mismatch")
    for architecture in ("arm64-linux", "x86_64-linux"):
        with urllib.request.urlopen(base + "portable-ruby-" + architecture, timeout=30) as response:
            values = dict(line.split("=", 1) for line in response.read().decode().splitlines())
        if digests[record["version"] + "." + values["ruby_TAG"]] != values["ruby_SHA"]:
            raise ValueError("Homebrew portable Ruby digest mismatch: " + architecture)


def main():
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    bootstrap = json.loads((PACKAGES / "bootstrap.json").read_text())
    if sys.argv[1:] == ["--bootstrap-runtime"]:
        check_bootstrap_ruby(bootstrap, now)
        return
    runtime = bootstrap["homebrew_portable_ruby"]
    print("portable-ruby", verify("portable-ruby", runtime, now), flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for lock in sorted(PACKAGES.glob("homebrew-bottles*.json")):
            records = json.loads(lock.read_text())
            jobs = {name: pool.submit(verify, name, record, now) for name, record in records.items()}
            for name, job in jobs.items():
                print(lock.stem, name, job.result(), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError) as error:
        sys.exit("Homebrew registry verification failed: " + str(error))
