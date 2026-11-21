"""Install native language servers from checked release assets and a verified gopls bottle."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import tarfile
import tempfile

from dependency_observations import GitHub
from install_bottles import ROOT, host_tags, locked_bottles, stage, verified_bytes
from release_assets import locked_asset, release_asset


def unpack_lua(archive, destination):
    with tarfile.open(archive, "r:gz") as source:
        for member in source:
            relative = Path(member.name)
            if relative.is_absolute() or ".." in relative.parts or not (member.isdir() or member.isfile()):
                raise ValueError("Unexpected entry in LuaLS archive: " + member.name)
            path = destination / relative
            if member.isdir():
                path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                with source.extractfile(member) as contents, path.open("xb") as output:
                    shutil.copyfileobj(contents, output)
                path.chmod(0o755 if member.mode & 0o111 else 0o644)


def install():
    base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "dotfiles-lsp/native"
    base.mkdir(parents=True, exist_ok=True)
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    specs = json.loads((ROOT / "packages/native-lsp.json").read_text())
    bottles = locked_bottles(host_tags())
    osname = {"Darwin": "darwin", "Linux": "linux"}[platform.system()]
    arch = {"arm64": "arm64", "aarch64": "arm64", "x86_64": "x64"}[platform.machine()]
    lua = "lua-language-server-" + specs["lua"]["tag"] + "-" + osname + "-" + arch + ".tar.gz"
    marksman = "marksman-macos" if osname == "darwin" else "marksman-linux-" + arch
    assets = {name: locked_asset(specs[name], filename, now)
              for name, filename in (("lua", lua), ("marksman", marksman))}
    identity = hashlib.sha256((assets["lua"][1] + assets["marksman"][1] + bottles["gopls"]["digest"]).encode()).hexdigest()
    target = base / identity
    with tempfile.TemporaryDirectory(dir=base) as tmp:
        work = Path(tmp)
        if not target.is_dir():
            output = work / "tools"
            output.mkdir()
            for name, (url, digest) in assets.items():
                archive = work / name
                verified_bytes(url, digest, archive, [])
                if name == "lua":
                    unpack_lua(archive, output / "lua")
                else:
                    archive.rename(output / "marksman")
                    (output / "marksman").chmod(0o755)
            bottle, deps = stage("gopls", bottles["gopls"], host_tags(), work, now)
            if deps:
                raise ValueError("gopls bottle requires external runtime dependencies")
            with tarfile.open(bottle, "r:gz") as archive:
                member = archive.getmember("gopls/" + bottles["gopls"]["version"] + "/bin/gopls")
                if not member.isfile():
                    raise ValueError("Unexpected gopls executable")
                with archive.extractfile(member) as src, (output / "gopls").open("xb") as dst:
                    shutil.copyfileobj(src, dst)
            (output / "gopls").chmod(0o755)
            try:
                output.rename(target)
            except OSError:
                if not target.is_dir():
                    raise
        link = work / "current"
        link.symlink_to(identity)
        os.replace(link, base / "current")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify publication of all native release assets")
    if parser.parse_args().check:
        api = GitHub()
        now = int(dt.datetime.now(dt.timezone.utc).timestamp())
        specs = list(json.loads((ROOT / "packages/native-lsp.json").read_text()).values())
        specs.append(json.loads((ROOT / "packages/bootstrap.json").read_text())["openssl_source"])
        for spec in specs:
            for filename in spec["assets"]:
                release_asset(api, spec, filename, now)
    else:
        install()
