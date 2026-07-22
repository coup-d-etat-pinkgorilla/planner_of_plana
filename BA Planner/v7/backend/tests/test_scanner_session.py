from __future__ import annotations

from copy import deepcopy
from threading import Event
import time
import unittest

from core.scanner_session import ScannerError, ScannerEventCursor, ScannerSessionService
from core.scanner_protocol_v1 import ScannerProtocolV1


STUDENT = {
    "version": 1,
    "student_id": "shiroko",
    "values": {"level": 90},
    "provenance": {"level": "scanner"},
}


class FakeRepository:
    def __init__(self) -> None:
        self.state = {"profile_id": "p1", "revision": 0, "students": [], "inventory": {"version": 1, "entries": []}, "goals": {"version": 1, "goals": []}}
        self.results: dict[str, dict] = {}

    def get_state(self, profile_id: str) -> dict:
        if profile_id != "p1":
            raise RuntimeError("profile not found")
        return deepcopy(self.state)

    def update_students(self, profile_id: str, students: list[dict], expected_revision: int, idempotency_key: str) -> dict:
        if idempotency_key in self.results:
            return deepcopy(self.results[idempotency_key])
        if expected_revision != self.state["revision"]:
            raise RuntimeError("revision conflict")
        self.state["students"] = deepcopy(students)
        self.state["revision"] += 1
        result = {"profile_id": profile_id, "revision": self.state["revision"]}
        self.results[idempotency_key] = deepcopy(result)
        return result

    def update_inventory(self, profile_id: str, inventory: dict, expected_revision: int, idempotency_key: str) -> dict:
        if idempotency_key in self.results:
            return deepcopy(self.results[idempotency_key])
        if expected_revision != self.state["revision"]:
            raise RuntimeError("revision conflict")
        self.state["inventory"] = deepcopy(inventory)
        self.state["revision"] += 1
        result = {"profile_id": profile_id, "revision": self.state["revision"]}
        self.results[idempotency_key] = deepcopy(result)
        return result


class ScannerSessionTests(unittest.TestCase):
    def service(self, matcher, *, events=None) -> ScannerSessionService:
        ids = iter(["s1", "c1", "s2", "c2"])
        return ScannerSessionService(
            target_provider=lambda: [{"target_id": "w1", "title": "Blue Archive", "status": "ready"}],
            student_matcher=matcher,
            inventory_matcher=matcher,
            repository=FakeRepository(),
            asset_status=lambda: {"ready": True, "manifest_version": 1, "missing": []},
            event_sink=(events if events is not None else []).append,
            id_factory=lambda: next(ids),
        )

    @staticmethod
    def candidate(*, uncertain=False) -> list[dict]:
        return [{
            "payload": deepcopy(STUDENT),
            "evidence": [{"field": "level", "status": "uncertain" if uncertain else "ok", "source": "fixture", "confidence": 0.6 if uncertain else 0.99}],
            "review_required": uncertain,
        }]

    def test_worker_emits_strict_sequence_candidate_then_one_terminal(self) -> None:
        events: list[dict] = []
        service = self.service(lambda _target, _cancel, progress: (progress(1, None, "scanner.identify"), self.candidate())[1], events=events)
        started = service.start("student", "w1")
        service.wait(started["session_id"])
        snapshot = service.snapshot("s1", 1)
        sequences = [item["payload"]["sequence"] for item in snapshot["events"]]
        self.assertEqual(list(range(1, len(sequences) + 1)), sequences)
        self.assertEqual("completed", snapshot["terminal"])
        self.assertEqual(1, sum(item["payload"]["event_kind"] == "terminal" for item in events))
        self.assertEqual("candidate", events[-2]["payload"]["event_kind"])
        service.close()

    def test_cancel_is_idempotent_and_stops_post_terminal_events(self) -> None:
        entered = Event()

        def matcher(_target, cancel, _progress):
            entered.set()
            cancel.wait(1)
            return self.candidate()

        service = self.service(matcher)
        started = service.start("student", "w1")
        self.assertTrue(entered.wait(1))
        self.assertTrue(service.cancel("s1", 1)["accepted"])
        service.wait("s1")
        self.assertFalse(service.cancel("s1", 1)["accepted"])
        snapshot = service.snapshot("s1", 1)
        self.assertEqual("cancelled", snapshot["terminal"])
        self.assertEqual([], snapshot["candidates"])
        self.assertEqual("terminal", snapshot["events"][-1]["payload"]["event_kind"])
        service.close()

    def test_review_revision_and_explicit_idempotent_commit(self) -> None:
        service = self.service(lambda *_args: self.candidate(uncertain=True))
        started = service.start("student", "w1")
        service.wait("s1")
        with self.assertRaisesRegex(ScannerError, "review"):
            service.commit(session_id="s1", generation=1, candidate_id="c1", candidate_revision=1, profile_id="p1", expected_repository_revision=0, idempotency_key="commit-1")
        reviewed = service.review("s1", 1, "c1", 1, STUDENT, approve=True, reason="user checked OCR")
        self.assertEqual(2, reviewed["revision"])
        self.assertTrue(reviewed["approved"])
        with self.assertRaisesRegex(ScannerError, "stale"):
            service.review("s1", 1, "c1", 1, STUDENT, approve=True, reason="stale")
        first = service.commit(session_id="s1", generation=1, candidate_id="c1", candidate_revision=2, profile_id="p1", expected_repository_revision=0, idempotency_key="commit-1")
        retry = service.commit(session_id="s1", generation=1, candidate_id="c1", candidate_revision=2, profile_id="p1", expected_repository_revision=0, idempotency_key="commit-1")
        self.assertEqual(first, retry)
        self.assertEqual(1, first["revision"])
        service.close()

    def test_stale_generation_and_event_cursor_policy(self) -> None:
        service = self.service(lambda *_args: self.candidate())
        service.start("student", "w1")
        service.wait("s1")
        with self.assertRaisesRegex(ScannerError, "stale"):
            service.snapshot("s1", 2)
        cursor = ScannerEventCursor("s1", 1)
        event = lambda seq, kind="phase": {"payload": {"session_id": "s1", "generation": 1, "sequence": seq, "event_kind": kind}}
        self.assertEqual("accepted", cursor.consume(event(1)))
        self.assertEqual("duplicate_or_out_of_order", cursor.consume(event(1)))
        self.assertEqual("snapshot_required", cursor.consume(event(3)))
        self.assertEqual("accepted", cursor.consume(event(2, "terminal")))
        self.assertEqual("after_terminal", cursor.consume(event(3)))
        self.assertEqual("stale", cursor.consume({"payload": {"session_id": "old", "generation": 1, "sequence": 1}}))
        service.close()

    def test_protocol_dispatch_is_strict_and_correlated(self) -> None:
        service = self.service(lambda *_args: self.candidate())
        protocol = ScannerProtocolV1(service)
        listed = protocol.handle({"protocol": 1, "id": "r1", "type": "request", "method": "scanner.target.list", "payload": {}})
        self.assertEqual("r1", listed["id"])
        self.assertEqual("ready", listed["payload"]["targets"][0]["status"])
        invalid = protocol.handle({"protocol": 1, "id": "r2", "type": "request", "method": "scanner.session.start", "payload": {"scan_kind": "student", "target_id": "w1", "extra": True}})
        self.assertEqual("invalid_payload", invalid["payload"]["error"]["code"])
        service.close()


if __name__ == "__main__":
    unittest.main()
