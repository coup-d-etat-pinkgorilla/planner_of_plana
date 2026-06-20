from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import update_wizard


def _write_manifest(release_root: Path, version: str, mtime_ns: int) -> None:
    release_dir = release_root / version
    release_dir.mkdir(parents=True)
    manifest = release_dir / update_wizard.ASSET_MANIFEST_NAME
    manifest.write_text(json.dumps({"asset_version": version}), encoding="utf-8")
    os.utime(manifest, ns=(mtime_ns, mtime_ns))


class UpdateWizardVersionDetectionTests(unittest.TestCase):
    def test_latest_release_uses_most_recent_manifest_not_largest_version(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            release_root = Path(raw_dir)
            _write_manifest(release_root, "4.0.1", 1_000_000_000)
            _write_manifest(release_root, "0.6.2", 2_000_000_000)

            with patch.object(update_wizard, "RELEASE_DIR", release_root):
                self.assertEqual(update_wizard._latest_release_version(), "0.6.2")

    def test_latest_release_uses_version_as_equal_mtime_tiebreaker(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            release_root = Path(raw_dir)
            _write_manifest(release_root, "0.6.1", 1_000_000_000)
            _write_manifest(release_root, "0.6.2", 1_000_000_000)

            with patch.object(update_wizard, "RELEASE_DIR", release_root):
                self.assertEqual(update_wizard._latest_release_version(), "0.6.2")


if __name__ == "__main__":
    unittest.main()
