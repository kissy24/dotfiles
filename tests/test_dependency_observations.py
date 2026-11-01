#!/usr/bin/env python3
"""Trust-boundary regression tests: no network and no production state writes."""
import contextlib
import importlib.util
import io
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "observations", Path(__file__).resolve().parents[1] / "scripts/dependency_observations.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
SHA = "a" * 40
OTHER = "b" * 40
KEY = "example/action@" + SHA
NOW = module.epoch("2026-01-20T00:00:00Z")


class ObservationTests(unittest.TestCase):
    def check(self, record, key=KEY):
        with contextlib.redirect_stdout(io.StringIO()):
            return module.check_observations({key}, {"observations": record}, NOW)

    def test_unknown_and_backdated_commits_fail_closed(self):
        self.assertTrue(self.check({}))
        # An ancient committer date is never used as evidence of observation.
        self.assertTrue(self.check({KEY: {"first_seen": "2026-01-19T00:00:00Z",
                                          "committer_date": "2000-01-01T00:00:00Z"}}))

    def test_seven_day_boundary_and_future(self):
        self.assertFalse(self.check({KEY: {"first_seen": "2026-01-13T00:00:00Z"}}))
        self.assertTrue(self.check({KEY: {"first_seen": "2026-01-13T00:00:01Z"}}))
        self.assertTrue(self.check({KEY: {"first_seen": "2026-01-21T00:00:00Z"}}))

    def test_baseline_only_approves_exact_repository_and_sha(self):
        ledger = {KEY: {"baseline": True}}
        self.assertFalse(self.check(ledger))
        self.assertTrue(self.check(ledger, "example/action@" + OTHER))
        self.assertTrue(self.check(ledger, "attacker/action@" + SHA))

    def test_missing_ledger_is_an_error(self):
        api = module.GitHub()
        with patch.object(module, "local_files", return_value={}), \
                patch.object(module, "dependencies", return_value=({KEY}, set())), \
                patch.object(module, "GitHub", return_value=api), \
                patch.object(api, "ledger", return_value=(None, None)):
            with self.assertRaisesRegex(ValueError, "missing"):
                module.check(Path("/not-read"))

    def test_baseline_cannot_be_expanded_by_reinitialization(self):
        api = module.GitHub()
        with patch.object(module, "GitHub", return_value=api), \
                patch.object(api, "ledger", return_value=({"observations": {}}, SHA)):
            with self.assertRaisesRegex(ValueError, "refusing to expand"):
                module.observe(initialize=True)

    def test_declarations_are_data_and_versions_require_sha(self):
        files = {
            ".github/workflows/test.yml": "steps:\n  - uses: example/action@" + SHA + " # comment\n",
            ".pre-commit-config.yaml": "repos:\n  - repo: https://github.com/example/hook\n    rev: " + OTHER,
            ".config/nvim/lua/plugins/test.lua": 'os.execute("this must never execute")\nreturn {"example/plugin"}',
            ".config/nvim/lazy-lock.json": '{"plugin":{"commit":"' + SHA + '"}}',
            ".config/sheldon/plugins.toml": '[plugins.demo]\ngithub = "example/shell"\nrev = "' + OTHER + '"\n',
        }
        with patch.object(module.os, "system", side_effect=AssertionError("Executed PR code")):
            keys, _ = module.dependencies(files)
        self.assertIn(KEY, keys)
        self.assertIn("example/hook@" + OTHER, keys)
        self.assertIn("example/plugin@" + SHA, keys)
        self.assertIn("example/shell@" + OTHER, keys)
        files[".github/workflows/test.yml"] = "- uses: example/action@main"
        with self.assertRaises(ValueError):
            module.dependencies(files)

    def test_unpinned_shell_sources_cannot_enter_a_check(self):
        files = {".github/workflows/test.yml": "- uses: example/action@" + SHA,
                 ".config/sheldon/plugins.toml": '[plugins.demo]\ngithub = "example/shell"\n'}
        with self.assertRaises(ValueError):
            module.dependencies(files)
        keys, _ = module.dependencies(files, strict=False)
        self.assertEqual(keys, {KEY})

    def test_repository_declarations_parse(self):
        root = Path(__file__).resolve().parents[1]
        keys, npm = module.dependencies(module.local_files(root))
        self.assertGreater(len(keys), 20)
        self.assertGreater(len(npm), 20)


if __name__ == "__main__":
    unittest.main()
