from __future__ import annotations

import threading
import time
import unittest

from core.lobby_watcher import LobbyWatcher


class LobbyWatcherLoopTests(unittest.TestCase):
    def test_running_loop_waits_between_checks(self) -> None:
        watcher = LobbyWatcher({})
        watcher.INTERVAL_RUNNING = 0.20
        first_check = threading.Event()
        check_count = 0

        def check() -> None:
            nonlocal check_count
            check_count += 1
            first_check.set()

        watcher._check = check
        watcher.start()
        try:
            self.assertTrue(first_check.wait(timeout=1.0))
            time.sleep(0.05)
            self.assertEqual(1, check_count)
        finally:
            watcher.stop()


if __name__ == "__main__":
    unittest.main()
