from __future__ import annotations

import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from core import config


class ProfileAccountPortraitTest(unittest.TestCase):
    def test_defaults_to_hasumi_and_saves_per_profile(self) -> None:
        with TemporaryDirectory() as temp_dir:
            config_path = Path(temp_dir) / "config.json"
            config_path.write_text(
                json.dumps(
                    {
                        "active_profile": "Account A",
                        "profiles": [
                            {"name": "Account A", "key": "account_a"},
                            {"name": "Account B", "key": "account_b"},
                        ],
                    }
                ),
                encoding="utf-8",
            )

            with patch.object(config, "CONFIG_FILE", config_path):
                self.assertEqual(config.get_profile_account_portrait(), ("hasumi", 1))

                config.set_profile_account_portrait("hoshino_battle", 2)
                self.assertEqual(
                    config.get_profile_account_portrait("Account A"),
                    ("hoshino_battle", 2),
                )
                self.assertEqual(
                    config.get_profile_account_portrait("Account B"),
                    ("hasumi", 1),
                )

                stored = json.loads(config_path.read_text(encoding="utf-8"))
                first, second = stored["profiles"]
                self.assertEqual(first["account_portrait_student_id"], "hoshino_battle")
                self.assertEqual(first["account_portrait_form_index"], 2)
                self.assertNotIn("account_portrait_student_id", second)


if __name__ == "__main__":
    unittest.main()
