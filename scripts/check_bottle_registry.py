"""Verify that a reviewed multi-platform bottle index was publicly registered before the cutoff."""
import concurrent.futures
import datetime as dt
import json
from pathlib import Path
import re
import sys
from urllib.parse import quote

from dependency_observations import GitHub
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
    if record.get("published_at") and published != record["published_at"]:
        raise ValueError("Registry publication date mismatch: " + name)
    return published


def main():
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
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
