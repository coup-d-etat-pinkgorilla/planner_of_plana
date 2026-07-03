from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from PIL import Image

from core.tactical_screenshot import (
    _slot_crop,
    collect_tactical_screenshot_images,
    is_tactical_screenshot_image,
    tactical_screenshot_date_from_path,
)


class TacticalScreenshotFolderTest(unittest.TestCase):
    def _image(self, path: Path, size: tuple[int, int]) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGB", size, "black").save(path)

    def test_collects_recursive_16_9_images_only(self) -> None:
        with TemporaryDirectory() as tmp:
            root = Path(tmp)
            good = root / "260606" / "a.png"
            nested = root / "260607" / "nested" / "b.jpg"
            wrong_ratio = root / "260607" / "portrait.png"
            not_image = root / "260608" / "notes.txt"
            self._image(good, (1920, 1080))
            self._image(nested, (2560, 1440))
            self._image(wrong_ratio, (1000, 1000))
            not_image.parent.mkdir(parents=True, exist_ok=True)
            not_image.write_text("skip", encoding="utf-8")

            paths = collect_tactical_screenshot_images(root)

            self.assertEqual([good, nested], paths)
            self.assertTrue(is_tactical_screenshot_image(good))
            self.assertFalse(is_tactical_screenshot_image(wrong_ratio))

    def test_uses_manual_tactical_roi_profile_for_slot_crop(self) -> None:
        image = Image.new("RGB", (2560, 1440), "black")

        crop = _slot_crop(image, 0)

        self.assertEqual((114, 93), crop.size)
    def test_reads_match_date_from_nearest_date_folder(self) -> None:
        self.assertEqual(
            "2026-06-06",
            tactical_screenshot_date_from_path(Path("root") / "260606" / "shot.png"),
        )
        self.assertEqual(
            "2026-07-02",
            tactical_screenshot_date_from_path(Path("root") / "2026-07-02" / "nested" / "shot.png"),
        )
        self.assertEqual("", tactical_screenshot_date_from_path(Path("root") / "misc" / "shot.png"))


if __name__ == "__main__":
    unittest.main()