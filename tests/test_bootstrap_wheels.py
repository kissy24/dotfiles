import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import bootstrap_wheels as wheels
from release_age import COOLDOWN_SECONDS, epoch


class WheelTests(unittest.TestCase):
    def test_only_verified_bytes_are_staged(self):
        name = "example-1-py3-none-any.whl"
        digest = hashlib.sha256(b"wheel").hexdigest()
        published = "2026-01-01T00:00:00Z"
        record = {"version": "1", "wheels": {name: digest}}
        upload = dict(filename=name, digests={"sha256": digest}, url="https://files.pythonhosted.org/example",
                      yanked=False, upload_time_iso_8601=published)
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp)
            for age, contents, success in [(COOLDOWN_SECONDS - 1, b"wheel", False),
                                           (COOLDOWN_SECONDS, b"other", False),
                                           (COOLDOWN_SECONDS, b"wheel", True)]:
                with patch.object(wheels, "fetch", side_effect=[json.dumps({"urls": [upload]}), contents]):
                    if success:
                        wheels.stage_package("example", record, dest, epoch(published) + age)
                        self.assertEqual((dest / name).read_bytes(), contents)
                    else:
                        with self.assertRaises(ValueError):
                            wheels.stage_package("example", record, dest, epoch(published) + age)
                        self.assertFalse((dest / name).exists())


if __name__ == "__main__":
    unittest.main()
