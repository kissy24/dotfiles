"""Bind GitHub release assets to an exact upload, byte digest and publication time."""
from urllib.parse import quote

from release_age import age_error, epoch


def locked_asset(spec, filename, now):
    pin = spec["assets"][filename]
    error = age_error(filename, pin["published_at"], now)
    if error:
        raise ValueError(error)
    return ("https://github.com/" + spec["repository"] + "/releases/download/" + spec["tag"] + "/" + filename,
            pin["sha256"])


def release_asset(api, spec, filename, now):
    release = api.request("/repos/" + spec["repository"] + "/releases/tags/" + quote(spec["tag"], safe=""))
    pin = spec["assets"][filename]
    matches = [a for a in release["assets"] if a["id"] == pin["id"] and a["name"] == filename]
    if release["draft"] or len(matches) != 1 or matches[0]["digest"] != "sha256:" + pin["sha256"]:
        raise ValueError("Release does not contain the pinned asset: " + filename)
    asset = matches[0]
    published = max((release["published_at"], asset["updated_at"]), key=epoch)
    if published != pin["published_at"]:
        raise ValueError("Release date mismatch: " + filename)
    url, _ = locked_asset(spec, filename, now)
    if asset["browser_download_url"] != url:
        raise ValueError("Release URL mismatch: " + filename)
    return url, pin["sha256"]
