import datetime as dt
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import install_bottles as bottles
from install_native_lsp import release_asset
from release_age import COOLDOWN_SECONDS, epoch


class ArtifactTests(unittest.TestCase):
    def test_roots_and_dependencies(self):
        calls = []

        def stage(name, *_):
            calls.append(name)
            return Path(name), ["lib", "existing"] if name == "missing" else []

        with patch.object(bottles, "stage", side_effect=stage):
            staged = bottles.prepare(["existing", "missing"], {"existing"}, dict.fromkeys(["missing", "lib"]),
                                     [], Path("."), 0)
        self.assertEqual(calls, ["missing", "lib"])
        with patch.object(bottles.subprocess, "run") as run:
            bottles.install(staged, {})
            self.assertEqual([c.args[0][-1] for c in run.call_args_list], ["lib", "missing"])
            for call in run.call_args_list:
                self.assertIn("--ignore-dependencies", call.args[0])

    def test_all_roots_have_public_evidence(self):
        records = json.loads((bottles.ROOT / "packages/homebrew-bottles.json").read_text())
        now = int(dt.datetime.now(dt.timezone.utc).timestamp())
        for name in bottles.roots() + ["gopls"]:
            self.assertRegex(records[name]["digest"], r"^[0-9a-f]{64}$")
            self.assertIsNone(bottles.age_error(name, records[name]["published_at"], now))
        with self.assertRaisesRegex(ValueError, "published_at=null"):
            bottles.stage("missing-date", {}, [], Path("."), now)

    def test_asset_replacement_and_age(self):
        published = "2026-01-01T00:00:00Z"
        url = "https://github.com/org/proj/releases/download/v1/tool"
        checksum = "c" * 64
        asset = dict(id=3, name="tool", digest="sha256:" + checksum, updated_at=published, browser_download_url=url)
        api = Mock()
        api.request.return_value = dict(draft=False, published_at=published, assets=[asset])
        spec = dict(repository="org/proj", tag="v1", assets={"tool": dict(id=3, sha256=checksum)})
        now = epoch(published) + COOLDOWN_SECONDS
        self.assertEqual(release_asset(api, spec, "tool", now), (url, checksum))
        with self.assertRaises(ValueError):
            release_asset(api, spec, "tool", now - 1)
        asset["id"] = 4
        with self.assertRaises(ValueError):
            release_asset(api, spec, "tool", now)


if __name__ == "__main__":
    unittest.main()
