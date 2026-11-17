"""Publication adapters must not turn unknown dates into invented timestamps."""
import contextlib
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import homebrew_release_age as brew
from release_age import epoch

NOW = epoch("2026-01-20T00:00:00Z")


class HomebrewPublicationTests(unittest.TestCase):
    def setUp(self):
        self.info = {"tap": "homebrew/cask", "version": "1.0", "sha256": "a" * 64,
                     "url": "https://github.com/example/app/releases/download/v1.0/app.zip"}
        self.release = {"immutable": True, "published_at": "2026-01-01T00:00:00Z",
                        "assets": [{"name": "app.zip", "digest": "sha256:" + "a" * 64}]}
        self.api = Mock()
        self.api.request.return_value = self.release

    def publication(self):
        return brew.publication("cask", self.info, "1.0", self.api)

    def select(self):
        candidates = {"casks": [{"name": "app", "current_version": "1.0"}]}
        with contextlib.redirect_stderr(io.StringIO()) as log:
            eligible = brew.select(candidates, lambda *_: self.info, self.api, NOW)
        return eligible, log.getvalue()

    def test_old_release_is_immediately_eligible_without_first_seen(self):
        eligible, log = self.select()
        self.assertEqual(eligible, [("cask", "app")])
        self.assertIn("published_at=2026-01-01", log)

    def test_young_release_waits_by_publication_date(self):
        self.release["published_at"] = "2026-01-19T00:00:00Z"
        eligible, log = self.select()
        self.assertEqual(eligible, [])
        self.assertIn("waiting until", log)

    def test_formula_date_is_unknown_not_an_upstream_or_commit_date(self):
        info = {"published_at": "2000-01-01T00:00:00Z", "commit_date": "2000-01-01T00:00:00Z"}
        self.assertIsNone(brew.publication("formula", info, "1.0", self.api)["published_at"])
        self.api.request.assert_not_called()

    def test_missing_date_does_not_hide_update_notifications(self):
        self.release["published_at"] = None
        eligible, log = self.select()
        self.assertEqual(eligible, [])
        self.assertIn("app 1.0", log)
        self.assertIn("published_at=null", log)

    def test_mutable_asset_cannot_reuse_old_release_date(self):
        self.release["immutable"] = False
        self.assertIsNone(self.publication()["published_at"])

    def test_digest_must_match_the_selected_artifact(self):
        self.release["assets"][0]["digest"] = "sha256:" + "b" * 64
        self.assertIsNone(self.publication()["published_at"])

    def test_changed_version_or_dependencies_are_held(self):
        self.info["version"] = "1.1"
        self.assertIsNone(self.publication()["published_at"])
        self.info["version"] = "1.0"
        self.info["depends_on"] = {"formula": ["unknown"]}
        self.assertIsNone(self.publication()["published_at"])

    def test_unknown_url_or_network_failure_has_no_date(self):
        self.info["url"] = "https://example.test/app.zip"
        self.assertIsNone(self.publication()["published_at"])
        eligible, log = self.select()
        self.assertEqual(eligible, [])
        self.assertIn("published_at=null", log)
        self.info["url"] = "https://github.com/example/app/releases/download/v1.0/app.zip"
        self.api.request.side_effect = OSError("unavailable")
        eligible, log = self.select()
        self.assertEqual(eligible, [])
        self.assertIn("published_at=null", log)


if __name__ == "__main__":
    unittest.main()
