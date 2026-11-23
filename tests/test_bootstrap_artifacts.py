import datetime as dt
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import check_bottle_registry as registry
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
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            for name, (_, deps) in staged.copy().items():
                bottle = directory / (name + "--1.all.bottle.tar.gz")
                with tarfile.open(bottle, "w:gz") as archive:
                    archive.addfile(tarfile.TarInfo(name + "/1/.brew/" + name + ".rb"))
                staged[name] = (bottle, deps)
            with patch.object(bottles.subprocess, "run") as run:
                bottles.install(staged, {}, directory / "Cellar", directory, native_bottles=False)
            self.assertEqual([c.args[0][1] for c in run.call_args_list], ["install", "postinstall"] * 2)
            for i, name in enumerate(["lib", "missing"]):
                install, postinstall = run.call_args_list[i * 2:i * 2 + 2]
                self.assertIn("--ignore-dependencies", install.args[0])
                self.assertTrue(postinstall.args[0][-1].endswith("/" + name + "/1/.brew/" + name + ".rb"))
                self.assertNotIn("HOMEBREW_DEVELOPER", postinstall.kwargs["env"])
                self.assertFalse((directory / name).exists())

    def test_retry_uses_verified_recipe(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            recipe = Path("example/1/.brew/example.rb")
            installed = root / "Cellar" / recipe
            installed.parent.mkdir(parents=True)
            installed.touch()
            bottle = root / "example--1.all.bottle.tar.gz"
            with tarfile.open(bottle, "w:gz") as archive:
                archive.add(installed, arcname=str(recipe))
            marker = root / "example"
            marker.touch()
            tap = root / "local-tap"
            (tap / "Formula").mkdir(parents=True)
            metadata = json.dumps({"formulae": [{"keg_only": False}]})
            with patch.object(bottles.subprocess, "check_output", side_effect=[str(tap), metadata]), \
                    patch.object(bottles.subprocess, "run") as run:
                bottles.install({"example": (bottle, [])}, {}, root / "Cellar", root, native_bottles=True)
            commands = [c.args[0] for c in run.call_args_list]
            self.assertEqual([cmd[1] for cmd in commands], ["install", "link", "postinstall"])
            self.assertTrue(commands[-1][-1].startswith("dotfiles-local/verified-"))
            self.assertEqual((tap / "Formula/example.rb").read_bytes(), installed.read_bytes())
            self.assertFalse(marker.exists())

    def test_all_roots_have_public_evidence(self):
        records = json.loads((bottles.ROOT / "packages/homebrew-bottles.json").read_text())
        now = int(dt.datetime.now(dt.timezone.utc).timestamp())
        for name in bottles.roots() + ["gopls"]:
            self.assertRegex(records[name]["digest"], r"^[0-9a-f]{64}$")
            self.assertIsNone(bottles.age_error(name, records[name]["published_at"], now))
        with self.assertRaisesRegex(ValueError, "published_at=null"):
            bottles.stage("missing-date", {}, [], Path("."), now)

    def test_bootstrap_ruby_must_match_each_linux_digest(self):
        bootstrap = {"homebrew_commit": "a" * 40, "homebrew_portable_ruby": {"version": "4.0.9"}}
        tags = ["arm64_linux", "x86_64_linux"]
        index = {"manifests": [{"annotations": {"org.opencontainers.image.ref.name": "4.0.9." + tag,
                                                "sh.brew.bottle.digest": "b" * 64}} for tag in tags]}
        for tag in tags:
            with self.subTest(tag=tag):
                files = [io.BytesIO(b"4.0.9\n")]
                for arch in tags:
                    digest = ("c" if arch == tag else "b") * 64
                    files.append(io.BytesIO(f"ruby_TAG={arch}\nruby_SHA={digest}\n".encode()))
                with patch.object(registry, "fetch_index", return_value=(index, None, None)), \
                        patch.object(registry.urllib.request, "urlopen", side_effect=files):
                    with self.assertRaisesRegex(ValueError, "digest mismatch"):
                        registry.check_bootstrap_ruby(bootstrap, 0)

    def test_platform_selection(self):
        for tags in [["arm64_tahoe", "all"], ["sonoma", "all"], ["arm64_sonoma", "all"], ["x86_64_linux", "all"]]:
            records = bottles.locked_bottles(tags)
            self.assertTrue(records["openssl@3"]["version"].startswith("3.5."))
            self.assertEqual(records["gopls"]["version"], "0.23.0" if bottles.legacy_macos(tags) else "0.24.0")

    def test_asset_replacement_and_age(self):
        published = "2026-01-01T00:00:00Z"
        url = "https://github.com/org/proj/releases/download/v1/tool"
        checksum = "c" * 64
        asset = dict(id=3, name="tool", digest="sha256:" + checksum, updated_at=published, browser_download_url=url)
        api = Mock()
        api.request.return_value = dict(draft=False, published_at=published, assets=[asset])
        spec = dict(repository="org/proj", tag="v1", assets={"tool": dict(id=3, sha256=checksum, published_at=published)})
        now = epoch(published) + COOLDOWN_SECONDS
        self.assertEqual(release_asset(api, spec, "tool", now), (url, checksum))
        with self.assertRaises(ValueError):
            release_asset(api, spec, "tool", now - 1)
        asset["id"] = 4
        with self.assertRaises(ValueError):
            release_asset(api, spec, "tool", now)


if __name__ == "__main__":
    unittest.main()
