from __future__ import annotations

from copy import deepcopy
from threading import Event
import time
import unittest

from core.scanner_session import ScannerError, ScannerEventCursor, ScannerSessionService
from core.scanner_protocol_v1 import ScannerProtocolV1
from core.repository_store import RepositoryError
from core.student_stats_catalog import load_student_stat_catalog


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
            raise RepositoryError(
                "revision_conflict", "revision conflict",
                details={"current_revision": self.state["revision"]},
            )
        self.state["students"] = deepcopy(students)
        self.state["revision"] += 1
        result = {"profile_id": profile_id, "revision": self.state["revision"]}
        self.results[idempotency_key] = deepcopy(result)
        return result

    def update_inventory(self, profile_id: str, inventory: dict, expected_revision: int, idempotency_key: str) -> dict:
        if idempotency_key in self.results:
            return deepcopy(self.results[idempotency_key])
        if expected_revision != self.state["revision"]:
            raise RepositoryError(
                "revision_conflict", "revision conflict",
                details={"current_revision": self.state["revision"]},
            )
        self.state["inventory"] = deepcopy(inventory)
        self.state["revision"] += 1
        result = {"profile_id": profile_id, "revision": self.state["revision"]}
        self.results[idempotency_key] = deepcopy(result)
        return result


class ScannerSessionTests(unittest.TestCase):
    def service(self, matcher, *, events=None, student_validator=None, candidate_review_hook=None) -> ScannerSessionService:
        ids = iter(["s1", "c1", "s2", "c2"])
        return ScannerSessionService(
            target_provider=lambda: [{"target_id": "w1", "title": "Blue Archive", "status": "ready"}],
            student_matcher=matcher,
            inventory_matcher=matcher,
            repository=FakeRepository(),
            asset_status=lambda: {"ready": True, "manifest_version": 1, "missing": []},
            event_sink=(events if events is not None else []).append,
            id_factory=lambda: next(ids),
            student_validator=student_validator,
            candidate_review_hook=candidate_review_hook,
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
        self.assertEqual(1, len(snapshot["candidates"]))
        self.assertEqual("candidate", snapshot["events"][-2]["payload"]["event_kind"])
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
        self.assertEqual("p1", first["profile_id"])
        service.close()

    def test_only_explicit_student_revalidation_trains_hidden_candidate_specimen(self) -> None:
        calls: list[tuple] = []

        def matcher(target, *_args):
            self.assertEqual("p1", target["profile_id"])
            candidate = self.candidate(uncertain=True)[0]
            candidate["_answer_specimen"] = {
                "source_size": (1280, 720),
                "numeric_groups": {},
            }
            return [candidate]

        service = self.service(matcher, candidate_review_hook=lambda *args: calls.append(args))
        service.start("student", "w1", profile_id="p1")
        service.wait("s1")
        wire = service.candidate("s1", 1, "c1")
        self.assertNotIn("_answer_specimen", wire)
        service.review(
            "s1", 1, "c1", 1, STUDENT, approve=False,
            reason="user checked OCR",
        )
        self.assertEqual([], calls)
        service.review(
            "s1", 1, "c1", 2, STUDENT, approve=False,
            reason="edited_and_revalidated_in_scan_page",
        )
        self.assertEqual(1, len(calls))
        self.assertEqual(("student", "p1", "c1"), calls[0][:3])
        service.close()

    def test_inventory_specimen_trains_only_on_explicit_approval(self) -> None:
        calls: list[tuple] = []
        inventory = {
            "version": 1,
            "entries": [{
                "key": "item_1", "quantity": "12", "item_id": "item_1",
                "name": None, "observed_slot": 0, "profile_id": "visible-grid",
            }],
        }

        def matcher(*_args):
            return [{
                "payload": inventory,
                "evidence": [],
                "review_required": True,
                "_answer_specimen": {"source_size": (1280, 720), "slot_crops": {}},
            }]

        service = self.service(matcher, candidate_review_hook=lambda *args: calls.append(args))
        service.start("inventory", "w1", profile_id="p1")
        service.wait("s1")
        service.review("s1", 1, "c1", 1, inventory, approve=False, reason="looked_only")
        self.assertEqual([], calls)
        service.review("s1", 1, "c1", 2, inventory, approve=True, reason="approved_in_inventory_page")
        self.assertEqual(1, len(calls))
        self.assertEqual(("inventory", "p1", "c1"), calls[0][:3])
        service.close()

    def test_student_matcher_can_stream_field_feedback_before_candidate(self) -> None:
        events: list[dict] = []

        def matcher(_target, _cancel, progress):
            self.assertTrue(getattr(progress, "supports_feedback", False))
            progress(1, 4, "scanner.student.identify", {
                "student_id": "shiroko",
                "field": "level",
                "values": {"level": 90},
            })
            return self.candidate()

        service = self.service(matcher, events=events)
        started = service.start("student", "w1")
        service.wait(started["session_id"])
        kinds = [item["payload"]["event_kind"] for item in events]
        self.assertEqual(
            ["phase", "progress", "feedback", "candidate", "terminal"],
            kinds,
        )
        self.assertEqual(
            {"level": 90},
            events[2]["payload"]["values"],
        )
        service.close()

    def test_full_scan_aggregates_all_candidate_relationship_ranks_before_validation(self) -> None:
        class Validator:
            def __init__(self):
                self.catalog = load_student_stat_catalog()
                self.contexts = []

            def __call__(self, _payload, _profile_id, relationship_ranks):
                self.contexts.append(dict(relationship_ranks or {}))
                return {
                    "field": "student_stat_validation", "status": "verified",
                    "source": "fixture", "details": {"validation_status": "verified"},
                }

        validator = Validator()
        first = deepcopy(STUDENT)
        first["student_id"] = "shiroko"
        first["values"]["bond_rank"] = 29
        second = deepcopy(STUDENT)
        second["student_id"] = "shiroko_swimsuit"
        second["values"]["bond_rank"] = 24
        service = self.service(
            lambda *_args: [
                {"payload": first, "evidence": [], "review_required": False},
                {"payload": second, "evidence": [], "review_required": False},
            ],
            student_validator=validator,
        )
        started = service.start("student", "w1", "p1", "full")
        service.wait(started["session_id"])
        self.assertEqual("full", started["student_scan_mode"])
        self.assertEqual(2, len(service.snapshot("s1", 1)["candidates"]))
        self.assertEqual(
            [{10010: 29, 20027: 24}, {10010: 29, 20027: 24}],
            validator.contexts,
        )
        service.close()

    def test_scan_workspace_revalidation_is_distinct_from_hold(self) -> None:
        validator = lambda _payload, _profile_id, _relationship_ranks=None: {
            "field": "student_stat_validation",
            "status": "verified",
            "source": "fixture",
        }
        service = self.service(
            lambda *_args: self.candidate(uncertain=True),
            student_validator=validator,
        )
        service.start("student", "w1", "p1")
        service.wait("s1")

        held = service.review(
            "s1", 1, "c1", 1, STUDENT,
            approve=False,
            reason="user held candidate",
        )
        self.assertTrue(held["review_required"])
        self.assertEqual("uncertain", held["evidence"][0]["status"])

        revalidated = service.review(
            "s1", 1, "c1", held["revision"], STUDENT,
            approve=False,
            reason="edited_and_revalidated_in_scan_page",
        )
        self.assertFalse(revalidated["review_required"])
        self.assertFalse(revalidated["approved"])
        self.assertEqual("verified", revalidated["evidence"][0]["status"])
        self.assertEqual("user_review", revalidated["evidence"][0]["source"])
        service.close()

    def test_shadow_evidence_does_not_force_review(self) -> None:
        def matcher(*_args):
            return [{
                "payload": STUDENT,
                "evidence": [{
                    "field": "equip1_level",
                    "status": "shadow",
                    "source": "equipment_binary_shadow",
                }],
                "review_required": False,
            }]

        validator = lambda _payload, _profile_id, _relationship_ranks=None: {
            "field": "student_stat_validation",
            "status": "verified",
            "source": "fixture",
        }
        service = self.service(matcher, student_validator=validator)
        service.start("student", "w1", "p1")
        service.wait("s1")
        candidate = service.candidate("s1", 1, "c1")
        self.assertFalse(candidate["review_required"])
        service.close()

    def test_single_scan_rank_context_revalidates_before_commit(self) -> None:
        def validator(_payload, _profile_id, relationship_ranks):
            verified = relationship_ranks == {10098: 24}
            return {
            "field": "student_stat_validation",
            "status": "verified" if verified else "dependency_missing",
            "source": "fixture",
            "details": {"validation_status": "verified" if verified else "dependency_missing"},
            }
        service = self.service(
            lambda *_args: self.candidate(),
            student_validator=validator,
        )
        service.start("student", "w1", "p1")
        service.wait("s1")
        candidate = service.candidate("s1", 1, "c1")
        self.assertTrue(candidate["review_required"])
        self.assertEqual("dependency_missing", candidate["evidence"][-1]["status"])
        with self.assertRaisesRegex(ScannerError, "review"):
            service.commit(
                session_id="s1", generation=1, candidate_id="c1",
                candidate_revision=1, profile_id="p1", expected_repository_revision=0,
                idempotency_key="missing-rank",
            )
        candidate = service.review(
            "s1", 1, "c1", 1, STUDENT, approve=False,
            reason="edited_and_revalidated_in_scan_page",
            relationship_ranks={10098: 24},
        )
        self.assertFalse(candidate["review_required"])
        self.assertEqual("verified", candidate["evidence"][-1]["status"])
        committed = service.commit(
            session_id="s1", generation=1, candidate_id="c1",
            candidate_revision=2, profile_id="p1", expected_repository_revision=0,
            idempotency_key="rank-confirmed",
        )
        self.assertEqual(1, committed["revision"])
        service.close()

    def test_empty_full_scan_revalidation_does_not_erase_batch_relationship_context(self) -> None:
        contexts: list[dict[int, int]] = []
        expected_context: dict[int, int] | None = None

        def validator(_payload, _profile_id, relationship_ranks):
            nonlocal expected_context
            context = dict(relationship_ranks or {})
            contexts.append(context)
            if expected_context is None:
                expected_context = context
            verified = bool(context) and context == expected_context
            return {
                "field": "student_stat_validation",
                "status": "verified" if verified else "dependency_missing",
                "source": "fixture",
                "details": {
                    "validation_status": "verified" if verified else "dependency_missing"
                },
            }
        validator.catalog = load_student_stat_catalog()

        first = deepcopy(STUDENT)
        first["student_id"] = "shiroko"
        first["values"]["bond_rank"] = 29
        second = deepcopy(STUDENT)
        second["student_id"] = "shiroko_swimsuit"
        second["values"]["bond_rank"] = 24
        service = self.service(
            lambda *_args: [
                {"payload": first, "evidence": [], "review_required": False},
                {"payload": second, "evidence": [], "review_required": False},
            ],
            student_validator=validator,
        )
        service.start("student", "w1", "p1", "full")
        service.wait("s1")
        candidate = service.snapshot("s1", 1)["candidates"][0]
        revalidated = service.revalidate(
            "s1",
            1,
            candidate["candidate_id"],
            candidate["revision"],
            {},
        )
        self.assertEqual("verified", revalidated["evidence"][-1]["status"])
        self.assertEqual(contexts[0], contexts[-1])
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

    def test_inventory_scan_profile_crosses_protocol_without_using_account_profile(self) -> None:
        seen = {}

        def matcher(target, *_args):
            seen.update(target)
            return self.candidate()

        service = self.service(matcher)
        protocol = ScannerProtocolV1(service)
        response = protocol.handle({
            "protocol": 1, "id": "inventory", "type": "request",
            "method": "scanner.session.start",
            "payload": {
                "scan_kind": "inventory", "target_id": "w1",
                "profile_id": "account-profile", "inventory_scan_profile": "tech_notes",
            },
        })
        service.wait(response["payload"]["session_id"])
        self.assertEqual("tech_notes", seen["inventory_scan_profile"])
        self.assertEqual("account-profile", seen["profile_id"])
        invalid = protocol.handle({
            "protocol": 1, "id": "student", "type": "request",
            "method": "scanner.session.start",
            "payload": {
                "scan_kind": "student", "target_id": "w1",
                "inventory_scan_profile": "tech_notes",
            },
        })
        self.assertEqual("invalid_payload", invalid["payload"]["error"]["code"])
        service.close()

    def test_protocol_serializes_repository_revision_conflict(self) -> None:
        service = self.service(lambda *_args: self.candidate())
        protocol = ScannerProtocolV1(service)
        service.start("student", "w1", "p1")
        service.wait("s1")
        service._repository.state["revision"] = 1
        response = protocol.handle({
            "protocol": 1,
            "id": "conflict",
            "type": "request",
            "method": "scanner.candidate.commit",
            "payload": {
                "session_id": "s1",
                "generation": 1,
                "candidate_id": "c1",
                "candidate_revision": 1,
                "profile_id": "p1",
                "expected_repository_revision": 0,
                "idempotency_key": "conflict",
            },
        })
        self.assertEqual("revision_conflict", response["payload"]["error"]["code"])
        self.assertIn("revision conflict", response["payload"]["error"]["message"])
        service.close()

    def test_profile_scoped_second_pass_revalidation_replaces_only_stat_evidence(self) -> None:
        calls: list[str | None] = []

        def validator(_payload, profile_id, _relationship_ranks=None):
            calls.append(profile_id)
            status = "dependency_missing" if len(calls) == 1 else "verified"
            return {
                "field": "student_stat_validation", "status": status,
                "source": "fixture", "details": {"validation_status": status},
            }

        service = self.service(lambda *_args: self.candidate(), student_validator=validator)
        started = service.start("student", "w1", "p1")
        service.wait(started["session_id"])
        first = service.candidate("s1", 1, "c1")
        self.assertEqual("dependency_missing", first["evidence"][-1]["status"])
        second = service.revalidate("s1", 1, "c1", first["revision"])
        self.assertEqual(2, second["revision"])
        self.assertEqual("verified", second["evidence"][-1]["status"])
        self.assertEqual(["p1", "p1"], calls)
        self.assertEqual("second_pass_revalidation", second["audit"][-1]["source"])
        service.close()


if __name__ == "__main__":
    unittest.main()
