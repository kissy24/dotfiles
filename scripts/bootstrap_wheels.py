"""Stage only reviewed wheels whose exact PyPI upload is at least seven days old."""
import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
from pathlib import Path
import platform
import re
import sys
import urllib.request
from urllib.parse import urlsplit

from dependency_observations import GitHub, trusted_exceptions
from release_age import age_error, epoch

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "packages" / "bootstrap-wheels.json"


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def stage_package(name, record, directory, now):
    version = record["version"]
    data = json.loads(fetch(f"https://pypi.org/pypi/{name}/{version}/json"))
    uploads = {item["filename"]: item for item in data["urls"]}
    for filename, checksum in record["wheels"].items():
        item = uploads[filename]
        if not re.fullmatch(r"[\w.+-]+\.whl", filename) or not re.fullmatch("[0-9a-f]{64}", checksum):
            raise ValueError("Invalid wheel lock entry: " + filename)
        if item["yanked"] or item["digests"]["sha256"] != checksum:
            raise ValueError("PyPI withdrew or changed " + filename)
        error = age_error(filename, item["upload_time_iso_8601"], now)
        if error:
            # An approved exception applies only to the exact pre-commit
            # version. Digest, yank and file identity checks are unconditional.
            if (name != "pre-commit" or epoch(item["upload_time_iso_8601"]) > now
                    or "pypi:pre-commit@" + version not in trusted_exceptions(GitHub(), now)):
                raise ValueError(error)
        url = urlsplit(item["url"])
        if (url.scheme, url.netloc) != ("https", "files.pythonhosted.org"):
            raise ValueError("Unexpected wheel origin: " + filename)
        if directory is None or not platform_wheel(filename):
            continue
        contents = fetch(item["url"])
        if hashlib.sha256(contents).hexdigest() != checksum:
            raise ValueError("Downloaded wheel digest mismatch: " + filename)
        (directory / filename).write_bytes(contents)


def platform_wheel(filename):
    tags = filename.removesuffix(".whl").rsplit("-", 1)[1].split(".")
    if "any" in tags:
        return True
    machine = platform.machine().lower()
    if sys.platform == "darwin":
        return any(tag.startswith("macosx_") and tag.endswith(("_" + machine, "_universal2")) for tag in tags)
    return any(tag.startswith("manylinux") and tag.endswith("_" + machine) for tag in tags)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path, help="new private wheelhouse for installation")
    args = parser.parse_args()
    records = json.loads(LOCK.read_text())
    expected = json.loads((ROOT / "packages/bootstrap.json").read_text())["pre_commit_version"]
    if records["pre-commit"]["version"] != expected or any(not r["wheels"] for r in records.values()):
        raise ValueError("Incomplete wheel lock or mismatched pre-commit version")
    if args.directory:
        args.directory.mkdir(mode=0o700, exist_ok=False)
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        jobs = [pool.submit(stage_package, name, record, args.directory, now) for name, record in records.items()]
        for job in jobs:
            job.result()


if __name__ == "__main__":
    main()
