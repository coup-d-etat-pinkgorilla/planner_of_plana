import unittest
from unittest.mock import patch

from gui.viewer_shared import TacticalScreenshotBatchTask


class TacticalScreenshotBatchProgressTests(unittest.TestCase):
    def test_emits_progress_after_every_success_or_failure(self) -> None:
        task = TacticalScreenshotBatchTask(["one.png", "two.png", "three.png"])
        progress: list[tuple[int, int]] = []
        completed: list[tuple[object, object]] = []
        task.signals.progress.connect(lambda current, total: progress.append((current, total)))
        task.signals.completed.connect(lambda results, errors: completed.append((results, errors)))

        with patch(
            "gui.viewer_shared.parse_tactical_result_screenshot",
            side_effect=[object(), RuntimeError("broken"), object()],
        ):
            task.run()

        self.assertEqual([(1, 3), (2, 3), (3, 3)], progress)
        self.assertEqual(2, len(completed[0][0]))
        self.assertEqual(1, len(completed[0][1]))


if __name__ == "__main__":
    unittest.main()
