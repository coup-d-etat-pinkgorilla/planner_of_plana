from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
from threading import Event
import unittest

from jsonschema import Draft202012Validator
from PIL import Image, ImageDraw

from core.recognition_assets import RecognitionAssetCatalog
from core.scanner_matchers import Match, ratio_crop
from core.scanner_session import ScannerError, ScannerSessionService
from core.tactical_lobby_scanner import TacticalLobbyMatcherAdapter, canonical_tactical_lobby_candidate


FIXTURE = Path(__file__).parents[2] / "docs" / "migration" / "p8-tactical-lobby-scanner" / "artifacts" / "tactical_lobby_2560x1440.png"
EXPECTED = [
    (5, "마리나9데스티니", "tsubaki", "hibiki", "michiru_dress"),
    (6, "우그웃", "eimi", "michiru_dress", "yakumo"),
    (7, "메라조마", "tsubaki", "michiru_dress", "hibiki"),
]


class Capture:
    def __init__(self, frame: Image.Image) -> None:
        self.frame = frame

    def capture(self, _target):
        return self.frame

    def scroll(self, _target, _delta):
        raise AssertionError("lobby scan must not scroll")

    def wait_stable(self, _target, _cancel, timeout=2.0):
        return self.frame


class TacticalLobbyScannerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.frame = Image.open(FIXTURE).convert("RGB")
        self.catalog = RecognitionAssetCatalog()

    def scan(self, frame: Image.Image, **kwargs):
        adapter = TacticalLobbyMatcherAdapter(
            Capture(frame), self.catalog,
            clock=lambda: datetime(2026, 7, 29, tzinfo=timezone.utc), **kwargs,
        )
        result = adapter({}, Event(), lambda *_args: None)[0]
        canonical_tactical_lobby_candidate(result["payload"])
        return result

    def assert_expected(self, payload):
        self.assertEqual(8, payload["current_rank"]["value"])
        actual = []
        for row in payload["rows"]:
            deck = row["public_defense"]
            actual.append((
                row["rank"]["value"], row["opponent"]["display_name"],
                deck["strikers"][0]["student_id"],
                deck["specials"][0]["student_id"], deck["specials"][1]["student_id"],
            ))
            self.assertEqual([None, None, None], [slot["student_id"] for slot in deck["strikers"][1:]])
        self.assertEqual(EXPECTED, actual)

    def test_reference_fixture_is_one_confirmed_refresh_candidate(self):
        result = self.scan(self.frame)
        self.assertFalse(result["review_required"])
        self.assertEqual("confirmed", result["payload"]["review_status"])
        self.assert_expected(result["payload"])
        self.assertEqual(17, len(result["evidence"]))

    def test_ratio_rois_preserve_semantics_at_supported_scales(self):
        generations = set()
        for size in ((2560, 1440), (1920, 1080), (1280, 720)):
            with self.subTest(size=size):
                resized = self.frame.resize(size, Image.Resampling.LANCZOS)
                result = self.scan(resized)
                self.assert_expected(result["payload"])
                self.assertEqual("confirmed", result["payload"]["review_status"])
                generations.add(result["payload"]["refresh_generation"])
        self.assertEqual(1, len(generations))

    def test_partial_occlusion_keeps_proposal_but_requires_review(self):
        frame = self.frame.copy()
        region = self.catalog.region("tactical_lobby")["rows"][1]["name"]
        crop = ratio_crop(frame, region)
        box = (
            round(frame.width * region["x1"]), round(frame.height * region["y1"]),
            round(frame.width * region["x2"]), round(frame.height * region["y2"]),
        )
        ImageDraw.Draw(frame).rectangle(box, fill=(12, 12, 12))
        result = self.scan(frame)
        opponent = result["payload"]["rows"][1]["opponent"]
        self.assertIsNone(opponent["display_name"])
        self.assertIsInstance(opponent["proposed_display_name"], str)
        self.assertEqual("review_required", result["payload"]["review_status"])
        self.assertTrue(result["review_required"])
        self.assertGreater(crop.width, 0)

    def test_similar_name_low_margin_is_not_auto_confirmed(self):
        adapter = TacticalLobbyMatcherAdapter(Capture(self.frame), self.catalog)

        class AmbiguousNames:
            def match(self, _image, **_kwargs):
                return Match("마리나9데스티니", 0.99, 0.001)

        adapter.name_matcher = AmbiguousNames()
        result = adapter({}, Event(), lambda *_args: None)[0]
        self.assertTrue(result["review_required"])
        self.assertTrue(all(row["opponent"]["display_name"] is None for row in result["payload"]["rows"]))
        self.assertTrue(all(row["opponent"]["proposed_display_name"] == "마리나9데스티니" for row in result["payload"]["rows"]))

    def test_cancelled_before_capture_returns_no_candidate(self):
        cancel = Event()
        cancel.set()
        adapter = TacticalLobbyMatcherAdapter(Capture(self.frame), self.catalog)
        self.assertEqual([], adapter({}, cancel, lambda *_args: None))

    def test_session_start_snapshot_review_and_unconfigured_persistence_boundary(self):
        adapter = TacticalLobbyMatcherAdapter(
            Capture(self.frame), self.catalog,
            clock=lambda: datetime(2026, 7, 29, tzinfo=timezone.utc),
        )

        class Repository:
            def get_state(self, _profile_id):
                raise AssertionError("P8 must not read tactical persistence")

        ids = iter(["session-1", "candidate-1"])
        service = ScannerSessionService(
            target_provider=lambda: [{"target_id": "w1", "title": "Blue Archive", "status": "ready"}],
            student_matcher=lambda *_args: [], inventory_matcher=lambda *_args: [],
            tactical_lobby_matcher=adapter, repository=Repository(),
            asset_status=self.catalog.verify, id_factory=lambda: next(ids),
        )
        started = service.start("tactical_lobby", "w1")
        service.wait(started["session_id"])
        snapshot = service.snapshot("session-1", 1)
        self.assertEqual("completed", snapshot["terminal"])
        self.assertEqual("tactical_lobby", snapshot["scan_kind"])
        candidate = snapshot["candidates"][0]
        schema = Draft202012Validator(
            json.loads(
                (Path(__file__).parents[2] / "contracts" / "scanner-protocol-v1.schema.json").read_text(encoding="utf-8")
            )
        )
        candidate_event = next(
            event for event in snapshot["events"]
            if event["payload"]["event_kind"] == "candidate"
        )
        self.assertEqual([], list(schema.iter_errors(candidate_event)))
        edited = candidate["payload"]
        edited["rows"][0]["opponent"]["display_name"] = "검토된 이름"
        reviewed = service.review(
            "session-1", 1, "candidate-1", 1, edited,
            approve=True, reason="user verified lobby",
        )
        self.assertTrue(reviewed["approved"])
        self.assertEqual(2, reviewed["revision"])
        with self.assertRaisesRegex(ScannerError, "not configured"):
            service.commit(
                session_id="session-1", generation=1,
                candidate_id="candidate-1", candidate_revision=2,
                profile_id="p1", expected_repository_revision=0,
                idempotency_key="p8-no-write",
            )
        service.close()

    def test_session_commit_delegates_confirmed_lobby_to_p9_store_boundary(self):
        adapter = TacticalLobbyMatcherAdapter(
            Capture(self.frame), self.catalog,
            clock=lambda: datetime(2026, 7, 29, tzinfo=timezone.utc),
        )
        calls = []

        class Repository:
            pass

        def commit(profile_id, payload, revision, key):
            calls.append((profile_id, payload["refresh_generation"], revision, key))
            return {"revision": 1, "scan_id": "scan-1", "candidate_ids": ["a", "b", "c"], "created": True}

        ids = iter(["session-1", "candidate-1"])
        service = ScannerSessionService(
            target_provider=lambda: [{"target_id": "w1", "title": "Blue Archive", "status": "ready"}],
            student_matcher=lambda *_args: [], inventory_matcher=lambda *_args: [],
            tactical_lobby_matcher=adapter, tactical_lobby_committer=commit,
            repository=Repository(), asset_status=self.catalog.verify,
            id_factory=lambda: next(ids),
        )
        service.start("tactical_lobby", "w1")
        service.wait("session-1")
        result = service.commit(
            session_id="session-1", generation=1, candidate_id="candidate-1",
            candidate_revision=1, profile_id="p1", expected_repository_revision=0,
            idempotency_key="persist-lobby",
        )
        self.assertEqual("scan-1", result["scan_id"])
        self.assertEqual([("p1", "refresh-2aeb4c6b33d7d87b8d5c4f1b", 0, "persist-lobby")], calls)
        service.close()


if __name__ == "__main__":
    unittest.main()
