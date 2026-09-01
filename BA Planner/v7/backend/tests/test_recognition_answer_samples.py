from __future__ import annotations

from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from PIL import Image

from core.recognition_answer_samples import RecognitionAnswerSampleStore
from core.studio_numeric_bank import StudioNumericBank


PROFILE_A = "a" * 24
PROFILE_B = "b" * 24


def mask(points: set[tuple[int, int]]) -> Image.Image:
    image = Image.new("L", (8, 12))
    for point in points:
        image.putpixel(point, 255)
    return image


class RecognitionAnswerSampleTests(unittest.TestCase):
    def test_numeric_samples_are_profile_and_resolution_scoped(self) -> None:
        with TemporaryDirectory() as temporary:
            store = RecognitionAnswerSampleStore(Path(temporary))
            source = mask({(3, y) for y in range(2, 10)})
            try:
                sample_id = store.save_numeric(
                    PROFILE_A, (1280, 720), field="student_level",
                    roi_name="studentlevel_digit1", digit="1", mask=source,
                    candidate_id="candidate-1",
                )
            finally:
                source.close()

            matching = store.load_numeric(PROFILE_A, (1280, 720))
            self.assertEqual([sample_id], [sample.sample_id for sample in matching])
            self.assertEqual("1", matching[0].digit)
            self.assertEqual((), store.load_numeric(PROFILE_A, (2560, 1440)))
            self.assertEqual((), store.load_numeric(PROFILE_B, (1280, 720)))
            store.close(matching)

    def test_inventory_samples_accumulate_without_touching_bundled_assets(self) -> None:
        with TemporaryDirectory() as temporary:
            store = RecognitionAnswerSampleStore(Path(temporary))
            crop = Image.new("RGB", (24, 20), (20, 30, 40))
            try:
                first = store.save_inventory(
                    PROFILE_A, (1280, 720), item_id="item_1", crop=crop,
                    candidate_id="candidate-1", observed_slot=2,
                )
                second = store.save_inventory(
                    PROFILE_A, (1280, 720), item_id="item_1", crop=crop,
                    candidate_id="candidate-2", observed_slot=2,
                )
            finally:
                crop.close()
            loaded = store.load_inventory(PROFILE_A, (1280, 720))
            self.assertEqual({first, second}, {sample.sample_id for sample in loaded})
            self.assertTrue(all(sample.item_id == "item_1" for sample in loaded))
            store.close(loaded)

    def test_user_numeric_sample_has_tie_breaking_precedence(self) -> None:
        vertical = {(3, y) for y in range(2, 10)}
        templates = {
            "roi": {
                str(digit): mask(vertical if digit == 0 else {(digit % 6 + 1, 5)})
                for digit in range(10)
            }
        }
        bank = StudioNumericBank(templates)
        user = mask(vertical)
        cell = Image.new("RGB", (8, 12))
        for point in vertical:
            cell.putpixel(point, (255, 255, 255))
        try:
            bank.add_user_template("roi", "8", user, sample_id="reviewed-8")
            result = bank.match(
                (cell,), field="student_level", roi_names=("roi",),
            )
            self.assertEqual(8, result.value)
            self.assertTrue(result.used_user_sample)
            self.assertGreaterEqual(result.margin, 0.079)
        finally:
            user.close()
            cell.close()
            bank.close()


if __name__ == "__main__":
    unittest.main()
