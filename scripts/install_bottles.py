"""Install missing Brewfile tools from verified, platform-specific Homebrew bottles."""
import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import tempfile
import urllib.request

from release_age import age_error

ROOT = Path(__file__).resolve().parents[1]
HEX = re.compile(r"[0-9a-f]{64}")
REF = re.compile(r"(.+)\.(all|(?:arm64_|x86_64_)?[a-z_]+)(?:\.(\d+))?")
REGISTRY = "https://ghcr.io"
MACOS = {27: "golden_gate", 26: "tahoe", 15: "sequoia", 14: "sonoma"}


def host_tags():
    machine = platform.machine()
    if platform.system() == "Linux":
        return [{"aarch64": "arm64_linux", "x86_64": "x86_64_linux"}[machine], "all"]
    major = int(platform.mac_ver()[0].split(".")[0])
    prefix = {"arm64": "arm64_", "x86_64": ""}[machine]
    return [prefix + tag for version, tag in MACOS.items() if version <= major] + ["all"]


def roots():
    names = []
    for line in (ROOT / "Brewfile").read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        match = re.fullmatch(r'brew "([a-z0-9@+._-]+)"', line)
        if not match:
            raise ValueError("Unsupported Brewfile entry: " + line)
        names.append(match[1])
    return names


def verified_bytes(url, digest, destination, headers):
    if not HEX.fullmatch(digest):
        raise ValueError("Invalid SHA256")
    # curl strips Authorization when following a registry redirect to a different host.
    subprocess.run(["curl", "-q", "--proto", "=https", "--proto-redir", "=https", "--fail",
                    "--silent", "--show-error", "--location", "--retry", "3",
                    *headers, "--output", str(destination), url], check=True)
    h = hashlib.sha256()
    with destination.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            h.update(chunk)
    if h.hexdigest() != digest:
        raise ValueError("SHA256 mismatch: " + destination.name)


def stage(name, record, tags, directory, now):
    error = age_error(name, record.get("published_at"), now)
    if error:
        raise ValueError(error)
    image = "homebrew/core/" + name.replace("@", "/").replace("+", "x")
    with urllib.request.urlopen(f"{REGISTRY}/token?service=ghcr.io&scope=repository:{image}:pull", timeout=60) as r:
        token = json.load(r)["token"]
    headers = ["-H", "Authorization: Bearer " + token]
    base = REGISTRY + "/v2/" + image
    index = directory / (name + ".index")
    digest = record["digest"]
    verified_bytes(base + "/manifests/sha256:" + digest, digest, index,
                   headers + ["-H", "Accept: application/vnd.oci.image.index.v1+json"])
    variants = {}
    for manifest in json.loads(index.read_bytes())["manifests"]:
        ann = manifest["annotations"]
        match = REF.fullmatch(ann["org.opencontainers.image.ref.name"])
        if match and "sh.brew.tab" in ann:
            variants[match[2]] = (match, ann)
    tag = next((t for t in tags if t in variants), None)
    if tag is None:
        raise ValueError(f"No locked bottle for {name} on {tags}")
    match, ann = variants[tag]
    version, _, rebuild = match.groups()
    if not re.fullmatch(r"[a-zA-Z0-9._+-]+", version):
        raise ValueError("Invalid bottle version")
    if not re.fullmatch(re.escape(version) + r"(?:-\d+)?", record["version"]):
        raise ValueError("Bottle version/rebuild mismatch: " + name)
    basename = name + "--" + version + "." + tag + ".bottle"
    bottle = directory / (basename + ("." + rebuild if rebuild else "") + ".tar.gz")
    digest = ann["sh.brew.bottle.digest"].removeprefix("sha256:")
    verified_bytes(base + "/blobs/sha256:" + digest, digest, bottle, headers)
    tab = json.loads(ann["sh.brew.tab"])
    sidecar = {name: {"bottle": {"tags": {tag: {"tab": tab}}}}}
    (directory / (basename + ".json")).write_text(json.dumps(sidecar))
    return bottle, [dep["full_name"] for dep in tab.get("runtime_dependencies", [])]


def prepare(names, installed, records, tags, directory, now):
    pending = set(names) - installed
    staged = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        while pending:
            jobs = {name: pool.submit(stage, name, records[name], tags, directory, now) for name in sorted(pending)}
            for name, job in jobs.items():
                staged[name] = job.result()
            pending = {dep for _, deps in staged.values() for dep in deps} - staged.keys() - installed
    return staged


def install(staged, env):
    while staged:
        ready = [name for name, (_, deps) in staged.items() if not any(dep in staged for dep in deps)]
        if not ready:
            raise ValueError("Cycle in bottle dependencies: " + ", ".join(sorted(staged)))
        for name in sorted(ready):
            bottle, _ = staged.pop(name)
            subprocess.run(["brew", "install", "--formula", "--force-bottle", "--ignore-dependencies", str(bottle)], env=env, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download-only", action="store_true", help="verify a fresh installation in a temporary directory")
    args = parser.parse_args()
    records = json.loads((ROOT / "packages/homebrew-bottles.json").read_text())
    env = dict(os.environ, HOMEBREW_NO_AUTO_UPDATE="1", HOMEBREW_NO_INSTALL_UPGRADE="1",
               HOMEBREW_NO_INSTALL_CLEANUP="1", HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK="1",
               HOMEBREW_DEVELOPER="1")
    installed = set() if args.download_only else set(subprocess.check_output(
        ["brew", "list", "--formula", "-1"], text=True, env=env).splitlines())
    with tempfile.TemporaryDirectory(prefix="dotfiles-bottles-") as tmp:
        staged = prepare(roots(), installed, records, host_tags(), Path(tmp),
                         int(dt.datetime.now(dt.timezone.utc).timestamp()))
        if not args.download_only:
            install(staged, env)


if __name__ == "__main__":
    main()
