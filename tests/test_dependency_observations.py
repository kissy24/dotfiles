#!/usr/bin/env python3
"""Trust-boundary regression tests: no network and no production state writes."""
import contextlib
import importlib.util
import io
from pathlib import Path
import unittest
import tempfile
import sys
import json
import base64
import urllib.error
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "observations", Path(__file__).resolve().parents[1] / "scripts/dependency_observations.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
SHA = "a" * 40
OTHER = "b" * 40
KEY = "example/action@" + SHA
IDENTITY = 123
NOW = module.epoch("2026-01-20T00:00:00Z")


class ObservationTests(unittest.TestCase):
    def test_observation_requires_trusted_workflow_identity_and_job_time(self):
        run = {"path": module.OBSERVER, "head_branch": "main", "event": "schedule",
               "conclusion": "success", "head_sha": OTHER, "id": 123,
               "head_repository": {"full_name": module.REPOSITORY}}
        job = {"name": f"Observed {IDENTITY} {KEY}", "conclusion": "success", "completed_at": "2026-01-13T00:00:00Z"}
        def check(run_fields=None, job_fields=None):
            api = Mock()
            def request(path):
                if "/workflows/" in path:
                    return {"workflow_runs": [{**run, **(run_fields or {})}]}
                if "/jobs?" in path:
                    return {"jobs": [{**job, **(job_fields or {})}]}
                raise AssertionError(path)
            api.request.side_effect = request
            with patch.object(module, "public_commit", return_value=1):
                return module.observation_error(api, KEY, IDENTITY, NOW)
        self.assertIsNone(check())
        for change in ({"path": "other.yml"}, {"head_branch": "other"}, {"event": "pull_request"},
                       {"head_repository": {"full_name": "foreign/repo"}}, {"conclusion": "failure"}):
            self.assertTrue(check(run_fields=change))
        for change in ({"name": f"Observed 456 {KEY}"}, {"name": f"Observed {IDENTITY} example/action@{OTHER}"},
                       {"completed_at": "2026-01-13T00:00:01Z"}, {"conclusion": "skipped"}):
            self.assertTrue(check(job_fields=change))

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


class PublicationTests(unittest.TestCase):
    def test_compare_endpoint_is_allowed_but_traversal_is_not(self):
        api = module.GitHub()
        response = Mock()
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=None)
        response.read.return_value = b'{"status":"ahead"}'
        opener = Mock()
        opener.open.return_value = response
        with patch.object(module.urllib.request, "build_opener", return_value=opener):
            self.assertEqual(api.request("/repos/example/action/compare/" + SHA + "...main")["status"], "ahead")
            for path in ("//other.example/repos", "/repos/../secrets", "/repos/%2e%2e/secrets"):
                with self.assertRaises(ValueError):
                    api.request(path)

    def test_npm_multiline_tuples_and_integrity_are_not_skipped(self):
        digest = "sha512-" + "a" * 86 + "=="
        data = {"lockfileVersion": 1, "packages": {"demo": ["demo@1.0.0", "", {}, digest]}}
        files = {"packages/bun-lsp/bun.lock": json.dumps(data, indent=2)}
        self.assertEqual(module.npm_pins(files), {("demo", "1.0.0"): digest})
        registry = {"time": {"1.0.0": "2026-01-01T00:00:00Z"},
                    "versions": {"1.0.0": {"dist": {"integrity": digest}}}}
        self.assertEqual(module.npm_publication(registry, "demo", "1.0.0", digest), registry["time"]["1.0.0"])
        with self.assertRaises(ValueError):
            module.npm_publication(registry, "demo", "1.0.0", "sha512-tampered")
        data["packages"]["hidden"] = ["hidden@1.0.0", "https://example.test/unreviewed.tgz", {}, digest]
        files["packages/bun-lsp/bun.lock"] = json.dumps(data, indent=2)
        with self.assertRaises(ValueError):
            module.npm_pins(files)
        with self.assertRaises(ValueError):
            module.bun_lock_data('{"packages":{},"packages":{}}')

    def test_shared_age_boundary_unknown_and_invalid_dates(self):
        self.assertIsNone(module.age_error(KEY, "2026-01-13T00:00:00Z", NOW))
        self.assertIn("waiting", module.age_error(KEY, "2026-01-13T00:00:01Z", NOW))
        self.assertIn("future", module.age_error(KEY, "2026-01-21T00:00:00Z", NOW))
        self.assertIn("published_at=null", module.age_error(KEY, None, NOW))
        for value in ("2026-01-01", "not-a-date", 123):
            with self.assertRaises(ValueError):
                module.epoch(value)

    def api(self, releases):
        api = Mock()
        def request(path):
            if "/releases?" in path:
                return releases
            if "/commits/" in path:
                return {"sha": SHA}
            if "/compare/" in path:
                return {"status": "ahead"}
            return {"id": IDENTITY, "private": False, "default_branch": "main"}
        api.request.side_effect = request
        return api

    def test_exact_immutable_release_uses_publication_not_commit_date(self):
        release = {"immutable": True, "draft": False, "tag_name": "v1.0",
                   "published_at": "2026-01-01T00:00:00Z", "created_at": "2030-01-01T00:00:00Z"}
        api = self.api([release])
        self.assertEqual(module.release_publication(api, KEY), release["published_at"])
        self.assertEqual(module.public_commit(api, KEY), IDENTITY)
        release["immutable"] = False
        self.assertIsNone(module.release_publication(api, KEY))
        release["immutable"], release["draft"] = True, True
        self.assertIsNone(module.release_publication(api, KEY))

    def test_other_release_sha_cannot_age_a_new_commit(self):
        api = self.api([{"immutable": True, "tag_name": "old", "published_at": "2000-01-01T00:00:00Z"}])
        self.assertIsNone(module.release_publication(api, "example/action@" + OTHER))

    def test_private_missing_and_fork_only_commits_are_rejected(self):
        for responses in ([{"private": True}],
                          [{"id": IDENTITY, "private": False, "default_branch": "main"}, {"sha": OTHER}],
                          [{"id": IDENTITY, "private": False, "default_branch": "main"}, {"sha": SHA},
                           {"status": "diverged"}]):
            api = Mock()
            api.request.side_effect = responses
            with self.assertRaises(ValueError):
                module.public_commit(api, KEY)

    def test_published_version_can_pass_without_any_observation(self):
        api = self.api([])
        api.files.return_value = {".github/workflows/old.yml": "- uses: example/old@" + OTHER}
        files = {".github/workflows/new.yml": "- uses: " + KEY}
        with patch.object(module, "GitHub", return_value=api), \
                patch.object(module, "local_files", return_value=files), \
                patch.object(module, "trusted_exceptions", return_value={}), \
                patch.object(module, "release_publication", return_value="2000-01-01T00:00:00Z"), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(module.check(Path("/not-read")), 0)

    def test_observer_emits_only_publicly_verified_candidates(self):
        api = Mock()
        api.request.side_effect = lambda path: [] if "/pulls?" in path else {"object": {"sha": SHA}}
        api.files.side_effect = lambda repo, sha: {
            ".github/workflows/test.yml": "- uses: " + ("example/old@" + OTHER if sha == module.MIGRATION_MAIN else KEY)}
        for result, expected in [(ValueError("not reachable"), []), (IDENTITY, [f"{IDENTITY} {KEY}"])]:
            with tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp) / "output"
                with patch.dict(module.os.environ, {"GITHUB_OUTPUT": str(output)}), \
                        patch.object(module, "GitHub", return_value=api), \
                        patch.object(module, "release_publication", return_value=None), \
                        patch.object(module, "public_commit", side_effect=[result]):
                    module.observe()
                self.assertEqual(json.loads(output.read_text().split("=", 1)[1]), expected)

    def test_emergency_exception_is_read_only_from_main_and_expires(self):
        api = Mock()
        record = {"reason": "Critical security fix", "approval_url": "https://github.com/kissy24/dotfiles/pull/99",
                  "expires_at": "2026-01-21T00:00:00Z"}
        def result():
            return {"content": base64.b64encode(json.dumps({"exceptions": {KEY: record}}).encode()).decode()}
        api.request.return_value = result()
        self.assertIn(KEY, module.trusted_exceptions(api, NOW))
        self.assertTrue(api.request.call_args.args[0].endswith("?ref=main"))
        record["expires_at"] = "2026-01-20T00:00:00Z"
        api.request.return_value = result()
        self.assertEqual(module.trusted_exceptions(api, NOW), {})
        record["expires_at"] = "2030-01-20T00:00:00Z"
        api.request.return_value = result()
        with self.assertRaises(ValueError):
            module.trusted_exceptions(api, NOW)


if __name__ == "__main__":
    unittest.main()
