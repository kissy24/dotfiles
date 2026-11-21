"""Install missing Brewfile tools from verified, platform-specific Homebrew bottles."""
import argparse
import concurrent.futures
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import tarfile
import tempfile
import urllib.request

from release_age import age_error
from release_assets import locked_asset

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


def legacy_macos(tags):
    return "sonoma" in tags or tags[0] == "arm64_sonoma"


def locked_bottles(tags):
    records = json.loads((ROOT / "packages/homebrew-bottles.json").read_text())
    if legacy_macos(tags):
        records.update(json.loads((ROOT / "packages/homebrew-bottles-intel.json").read_text()))
    return records


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


def stage_bottle(name, record, tags, directory, now):
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


def stage(name, record, tags, directory, now):
    if name != "openssl@3" or not legacy_macos(tags):
        return stage_bottle(name, record, tags, directory, now)
    # The last Intel bottle was built from an EOL OpenSSL series. Use the
    # reviewed recipe from the LTS bottle and its matching official source.
    bottle, deps = stage_bottle(name, record, ["arm64_tahoe"], directory, now)
    spec = json.loads((ROOT / "packages/bootstrap.json").read_text())["openssl_source"]
    filename = "openssl-" + record["version"] + ".tar.gz"
    url, digest = locked_asset(spec, filename, now)
    path = directory / record["version"] / (name + ".rb")
    path.parent.mkdir()
    with tarfile.open(bottle) as archive:
        recipe = archive.extractfile(f"{name}/{record['version']}/.brew/{name}.rb").read().decode()
    declaration = f'  url "{url}"\n  sha256 "{digest}"'
    if declaration not in recipe:
        raise ValueError("OpenSSL source does not match the verified Homebrew formula")
    source = directory / filename
    verified_bytes(url, digest, source, [])
    # Homebrew verifies the same checksum when it stages the private local copy.
    path.write_text(recipe.replace(declaration, f'  url "{source.as_uri()}"\n  sha256 "{digest}"', 1))
    return path, deps


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


def install(staged, env, cellar, pending_dir):
    while staged:
        ready = [name for name, (_, deps) in staged.items() if not any(dep in staged for dep in deps)]
        if not ready:
            raise ValueError("Cycle in bottle dependencies: " + ", ".join(sorted(staged)))
        for name in sorted(ready):
            bottle, _ = staged.pop(name)
            if bottle.suffix == ".rb":
                version = bottle.parent.name
                mode = "--build-from-source"
            else:
                version = bottle.name.split("--", 1)[1].split(".bottle", 1)[0].rsplit(".", 1)[0]
                mode = "--force-bottle"
            recipe = Path(name) / version / ".brew" / (name + ".rb")
            if mode == "--force-bottle":
                with tarfile.open(bottle) as archive:
                    if not archive.getmember(str(recipe)).isfile():
                        raise ValueError("Missing formula in locked bottle: " + name)
            # Keep a marker until the matching keg's post-install has succeeded.
            # A failed or interrupted pour may already be listed by brew.
            marker = pending_dir / name
            marker.touch()
            subprocess.run(["brew", "install", "--formula", mode, "--ignore-dependencies",
                            "--skip-post-install", str(bottle)], env=dict(env, HOMEBREW_DEVELOPER="1"), check=True)
            subprocess.run(["brew", "postinstall", str(cellar / recipe)], env=env, check=True)
            marker.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--download-only", action="store_true", help="verify a fresh installation in a temporary directory")
    args = parser.parse_args()
    records = locked_bottles(host_tags())
    env = dict(os.environ, HOMEBREW_NO_AUTO_UPDATE="1", HOMEBREW_NO_INSTALL_UPGRADE="1",
               HOMEBREW_NO_INSTALL_CLEANUP="1", HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK="1")
    env.pop("HOMEBREW_DEVELOPER", None)
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    with tempfile.TemporaryDirectory(prefix="dotfiles-bottles-") as tmp:
        if args.download_only:
            prepare(roots(), set(), records, host_tags(), Path(tmp), now)
            return
        state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "dotfiles/bottles"
        pending_dir = state / "pending"
        pending_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
        with (state / "install.lock").open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            cellar = Path(subprocess.check_output(["brew", "--cellar"], text=True, env=env).strip())
            installed = set(subprocess.check_output(["brew", "list", "--formula", "-1"], text=True, env=env).splitlines())
            pending = {p.name for p in pending_dir.iterdir() if p.name in records}
            staged = prepare(set(roots()) | pending, installed - pending, records, host_tags(), Path(tmp), now)
            install(staged, env, cellar, pending_dir)


if __name__ == "__main__":
    main()
