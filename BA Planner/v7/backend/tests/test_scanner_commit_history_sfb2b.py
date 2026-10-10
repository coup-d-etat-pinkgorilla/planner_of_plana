"""Applied-source S-FB2b integration + memory regressions; factory OS is mocked."""
import ast
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from datetime import datetime, timezone
import json
import os
from pathlib import Path
from threading import Event
import tempfile
import unittest

from jsonschema import Draft202012Validator
from core.inventory_catalog import CATALOG_REVISION
from core.repository_dto import canonical_json
from core.repository_store import JsonRepository
from core.scanner_session import ScannerError, ScannerSessionService
from core.scanner_protocol_v1 import ScannerProtocolV1

ROOT = Path(__file__).resolve().parents[2]
REPO = ROOT
AT = datetime(2026, 10, 10, 7, 0, tzinfo=timezone.utc)


class LossPort:
    def __init__(self, repo):
        self.repo, self.lose = repo, False
        self.reads, self.calls = 0, []

    def get_state(self, profile_id):
        self.reads += 1
        return self.repo.get_state(profile_id)

    def _update(self, bucket, profile_id, value, expected, key, history_context):
        self.calls.append(canonical_json({"bucket": bucket, "value": value,
                                         "expected": expected, "key": key,
                                         "context": history_context.to_wire()}))
        update = self.repo.update_students if bucket == "students" else self.repo.update_inventory
        response = update(profile_id, value, expected, key, history_context=history_context)
        if self.lose:
            self.lose = False
            raise OSError("synthetic response lost after durable write")
        return response

    def update_students(self, profile_id, value, expected, key, *, history_context=None):
        return self._update("students", profile_id, value, expected, key, history_context)

    def update_inventory(self, profile_id, value, expected, key, *, history_context=None):
        return self._update("inventory", profile_id, value, expected, key, history_context)


class ScannerCommitHistoryIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads((ROOT / "contracts/fixtures/scanner_commit_history_sfb2b_v1.json").read_text(encoding="utf-8"))

    def setup_case(self, case=None, *, port_class=LossPort, hook=None):
        case = deepcopy(case or self.fixture["cases"][0])
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        repo = JsonRepository(Path(temporary.name), clock=lambda: AT)
        pid = repo.create_profile("Synthetic preparation", "prepare")["profile"]["profile_id"]
        bucket = "students" if case["kind"] == "student" else "inventory"
        update = repo.update_students if bucket == "students" else repo.update_inventory
        update(pid, case["initial"], 0, "seed", manual=True)
        port = port_class(repo)
        ids = iter(["session", "candidate"])
        service = ScannerSessionService(
            target_provider=lambda: [{"target_id": "synthetic", "status": "ready", "title": "fixture",
                                      "inventory_scan_profile": case["raw_profile"]}],
            student_matcher=lambda *_: [{"payload": case["candidate"], "evidence": []}],
            inventory_matcher=lambda *_: [{"payload": case["candidate"], "evidence": []}],
            repository=port, asset_status=lambda: {"ready": True}, id_factory=lambda: next(ids),
            candidate_review_hook=hook, executor=NoWorkerExecutor(),
        )
        self.addCleanup(service.close)
        session = _Session("session", 1, case["kind"],
                           {"inventory_scan_profile": case["raw_profile"]}, pid, terminal="completed")
        candidate = service._make_candidate(session, {"candidate_id": "candidate",
                                            "payload": case["candidate"], "evidence": []})
        session.candidates[candidate.candidate_id] = candidate
        service._sessions[session.session_id] = session
        revision = 1
        if case["reviewed"] is not None:
            reviewed = service.review("session", 1, "candidate", 1, case["reviewed"], approve=True, reason="explicit synthetic review")
            revision = reviewed["revision"]
        request = dict(session_id="session", generation=1, candidate_id="candidate", candidate_revision=revision,
                       profile_id=pid, expected_repository_revision=1, idempotency_key="scan")
        return repo, port, service, request, case

    def test_shared_first_nochange_partial_alias_and_raw_profile_cases(self):
        for case in self.fixture["cases"]:
            with self.subTest(case=case["id"]):
                repo, port, service, request, case = self.setup_case(case)
                result = service.commit(**request)
                self.assertEqual(set(self.fixture["public_success_keys"]), set(result))
                self.assertEqual(2, result["revision"])
                record = service._current_commits[("session", "scan")]
                self.assertIsNone(record.request)
                self.assertEqual(canonical_json(request), record.public_request_json)
                context = json.loads(port.calls[0])["context"]
                self.assertEqual(case["applied_keys"], context["applied_keys"])
                self.assertEqual(case["excluded_keys"], context["excluded_keys"])
                self.assertEqual(case["raw_profile"], context["inventory_scan_profile"])
                self.assertIsNone(context["retry_of"])
                event = repo._profile(request["profile_id"])["current_history"]["events"][-1]
                changes = event["student_changes"] + event["inventory_changes"]
                self.assertEqual(case["nochange"], not changes)
                self.assertEqual("scan", event["source"])
                self.assertNotIn("excluded_keys", event)
                self.assertNotIn("retry_of", event)
                before = repo._profile_path(request["profile_id"]).read_bytes()
                result["revision"] = 999
                self.assertEqual(2, service.commit(**request)["revision"])
                self.assertEqual(1, port.reads)
                self.assertEqual(1, len(port.calls))
                self.assertEqual(before, repo._profile_path(request["profile_id"]).read_bytes())

    def test_pending_response_loss_external_write_repository_restart_replays_frozen_request(self):
        for case in self.fixture["cases"][:2]:
            with self.subTest(case=case["id"]):
                repo, port, service, request, _ = self.setup_case(case)
                port.lose = True
                with self.assertRaises(OSError):
                    service.commit(**request)
                frozen = port.calls[0]
                bucket = "students" if case["kind"] == "student" else "inventory"
                changed = deepcopy(repo.get_state(request["profile_id"])[bucket])
                if bucket == "students":
                    changed[-1]["values"]["level"] = 42
                    repo.update_students(request["profile_id"], changed, 2, "external", manual=True)
                else:
                    changed["entries"][-1]["quantity"] = "42"
                    repo.update_inventory(request["profile_id"], changed, 2, "external", manual=True)
                before = repo._profile_path(request["profile_id"]).read_bytes()
                port.repo = JsonRepository(repo.root, clock=lambda: self.fail("Replay sampled clock"))
                self.assertEqual(2, service.commit(**request)["revision"])
                self.assertEqual([frozen, frozen], port.calls)
                self.assertEqual(1, port.reads)
                self.assertEqual(before, repo._profile_path(request["profile_id"]).read_bytes())
                self.assertEqual(changed, port.repo.get_state(request["profile_id"])[bucket])

    def test_same_key_changed_public_fields_conflict_before_candidate_revision_lookup(self):
        repo, port, service, request, _ = self.setup_case()
        service.commit(**request)
        for change in ({"expected_repository_revision": 2}, {"candidate_revision": 2},
                       {"candidate_id": "different"}, {"profile_id": "different-profile"}, {"generation": 2}):
            with self.subTest(change=change), self.assertRaises(ScannerError) as caught:
                service.commit(**{**request, **change})
            self.assertEqual("idempotency_conflict", caught.exception.code)
        self.assertEqual(1, port.reads)
        self.assertEqual(1, len(port.calls))

    def test_review_after_response_loss_cannot_replace_original_frozen_payload(self):
        repo, port, service, request, case = self.setup_case()
        port.lose = True
        with self.assertRaises(OSError):
            service.commit(**request)
        changed = deepcopy(case["candidate"])
        changed["values"]["level"] = 55
        service.review("session", 1, "candidate", 1, changed, approve=True, reason="later review")
        self.assertEqual(2, service.commit(**request)["revision"])
        self.assertEqual(port.calls[0], port.calls[1])
        actual = next(row for row in repo.get_state(request["profile_id"])["students"] if row["student_id"] == "aru")
        self.assertEqual(case["candidate"], actual)

    def test_two_concurrent_same_requests_freeze_and_write_once(self):
        entered, release = Event(), Event()
        class BlockingPort(LossPort):
            def update_students(self, *args, history_context=None):
                entered.set()
                if not release.wait(2):
                    raise RuntimeError("synthetic synchronization timed out")
                return super().update_students(*args, history_context=history_context)
        repo, port, service, request, _ = self.setup_case(port_class=BlockingPort)
        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(service.commit, **request)
            self.assertTrue(entered.wait(1))
            second = pool.submit(service.commit, **request)
            release.set()
            self.assertEqual(first.result(timeout=2), second.result(timeout=2))
        self.assertEqual(1, port.reads)
        self.assertEqual(1, len(port.calls))
        self.assertEqual(1, repo._profile(request["profile_id"])["current_history"]["total_counts"]["scan"])

    def test_empty_all_excluded_reject_before_get_state_or_write_and_unknown_slot_has_no_key(self):
        case = deepcopy(next(case for case in self.fixture["cases"] if case["id"] == "inventory_partial_first"))
        case["reviewed"]["entries"] = []
        repo, port, service, request, _ = self.setup_case(case)
        service._sessions["session"].candidates["candidate"].answer_specimen = {"unresolved_slots": {7: {"profile": "tech_notes"}}}
        before = repo._profile_path(request["profile_id"]).read_bytes()
        with self.assertRaises(ScannerError) as caught:
            service.commit(**request)
        self.assertEqual("invalid_candidate", caught.exception.code)
        self.assertEqual("empty_scan_scope", caught.exception.details["reason"])
        self.assertEqual((0, []), (port.reads, port.calls))
        self.assertEqual(before, repo._profile_path(request["profile_id"]).read_bytes())

    def test_alias_collision_rejects_before_merge_can_silently_drop_duplicate(self):
        case = deepcopy(self.fixture["cases"][4])
        case["candidate"]["entries"].append({"key": "Item_Icon_SkillBook_Ultimate", "quantity": "1"})
        repo, port, service, request, _ = self.setup_case(case)
        with self.assertRaises(ScannerError) as caught:
            service.commit(**request)
        self.assertEqual("duplicate_identity", caught.exception.details["reason"])
        self.assertEqual((0, []), (port.reads, port.calls))

    def test_legacy_four_argument_callback_and_internal_typeerror_are_called_once(self):
        from tests.test_scanner_session import FakeRepository
        repo, port, service, request, _ = self.setup_case()
        legacy = FakeRepository()
        service._repository = legacy
        request["profile_id"], request["expected_repository_revision"] = "p1", 0
        first = service.commit(**request)
        self.assertEqual(first, service.commit(**request))
        self.assertEqual(1, legacy.state["revision"])
        class BrokenPort(LossPort):
            def update_students(self, *args, history_context=None):
                self.calls.append("inside callback")
                raise TypeError("synthetic callback failure")
        repo, broken, service, request, _ = self.setup_case(port_class=BrokenPort)
        with self.assertRaises(TypeError):
            service.commit(**request)
        self.assertEqual(["inside callback"], broken.calls)

    def test_commit_and_receipt_replay_never_train_review_samples(self):
        calls = []
        case = deepcopy(next(case for case in self.fixture["cases"] if case["id"] == "inventory_partial_first"))
        case["reviewed"] = None
        repo, port, service, request, _ = self.setup_case(case, hook=lambda *args: calls.append(args))
        item = service._sessions["session"].candidates["candidate"]
        item.answer_specimen = {"synthetic": {}}
        service.review("session", 1, "candidate", 1, case["candidate"], approve=True, reason="explicit approval")
        request["candidate_revision"] = 2
        self.assertEqual(1, len(calls))
        port.lose = True
        with self.assertRaises(OSError):
            service.commit(**request)
        service.commit(**request)
        service.commit(**request)
        self.assertEqual(1, len(calls))

    def test_public_forged_flat_source_retry_are_rejected_and_new_process_has_no_session(self):
        repo, port, service, request, _ = self.setup_case()
        protocol = ScannerProtocolV1(service)
        for key in ("history_context", "source", "retry_of"):
            wire = {"protocol": 1, "id": "forged", "type": "request", "method": "scanner.candidate.commit",
                    "payload": {**request, key: "forged"}}
            self.assertEqual("invalid_payload", protocol.handle(wire)["payload"]["error"]["code"])
        service.commit(**request)
        fresh = ScannerSessionService(target_provider=lambda: [], student_matcher=lambda *_: [],
            inventory_matcher=lambda *_: [], repository=port, asset_status=lambda: {"ready": True},
            executor=NoWorkerExecutor())
        self.addCleanup(fresh.close)
        with self.assertRaises(ScannerError) as caught:
            fresh.commit(**request)
        self.assertEqual("session_not_found", caught.exception.code)

    def test_shared_public_fixture_and_factory_repository_wiring_are_unchanged(self):
        schema = json.loads((REPO / "contracts/scanner-protocol-v1.schema.json").read_text(encoding="utf-8"))
        fixture = json.loads((REPO / "contracts/fixtures/scanner_protocol_v1.json").read_text(encoding="utf-8"))
        validator = Draft202012Validator(schema)
        for case in fixture["cases"]:
            self.assertEqual(case["valid"], not list(validator.iter_errors(case["message"])))
        tree = ast.parse((REPO / "backend/core/scanner_runtime.py").read_text(encoding="utf-8"))
        names = [node.func.id for node in ast.walk(tree) if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)]
        self.assertIn("JsonRepository", names)
        self.assertIn("ScannerSessionService", names)

    def test_actual_rebase_import_reexport_is_the_same_function(self):
        from core.repository_inventory import rebase_inventory_snapshot as pure
        from core.repository_store import rebase_inventory_snapshot as reexport
        self.assertIs(pure, reexport)

    def test_actual_cleanup_failure_after_receipt_does_not_repeat_durable_write_or_clock(self):
        repo, port, service, request, _ = self.setup_case()
        clock = []
        repo._clock = lambda: clock.append(True) or AT
        item = service._sessions["session"].candidates["candidate"]
        item.answer_specimen = {"synthetic-opaque": object()}
        cleanup = []
        def fail_cleanup(specimen):
            cleanup.append(specimen)
            raise ValueError("synthetic actual-store cleanup failure")
        service._close_specimen = fail_cleanup
        with self.assertRaisesRegex(ValueError, "synthetic actual-store cleanup failure"):
            service.commit(**request)
        record = service._current_commits[("session", "scan")]
        self.assertIsNone(record.request)
        self.assertIsNotNone(record.response_json)
        self.assertEqual(item.answer_specimen, {})
        before = repo._profile_path(request["profile_id"]).read_bytes()
        event = repo._profile(request["profile_id"])["current_history"]
        self.assertEqual(event["total_counts"]["scan"], 1)
        self.assertEqual(service.commit(**request)["revision"], 2)
        self.assertEqual((port.reads, len(port.calls), len(clock), len(cleanup)), (1, 1, 1, 1))
        self.assertEqual(repo._profile_path(request["profile_id"]).read_bytes(), before)
        # Test cleanup must not invoke the intentionally failing callback again.
        service._close_specimen = ScannerSessionService._close_specimen

    def test_os_mocked_actual_runtime_factory_wires_typed_repository_without_worker(self):
        import importlib.util
        import inspect
        import sys
        from contextlib import ExitStack
        from types import ModuleType
        from unittest.mock import MagicMock, patch

        # Import the real factory source without importing recognition/OS implementations.
        # Keep repository_store, scanner_session and runtime_paths real in this wiring test.
        module_exports = {
            "core.recognition_assets": {"RecognitionAssetCatalog"},
            "core.recognition_answer_samples": {"RecognitionAnswerSampleStore"},
            "core.scanner_matchers": {"EquipmentMenuCaptureAdapter", "InventoryMatcherAdapter", "StudentMatcherAdapter",
                "WeaponMenuCaptureAdapter", "StatMenuCaptureAdapter", "LevelMenuCaptureAdapter", "StarMenuCaptureAdapter", "SkillMenuCaptureAdapter"},
            "core.student_matcher_adapter": {"EquipmentMenuCaptureAdapter", "StudentMatcherAdapter",
                "WeaponMenuCaptureAdapter", "StatMenuCaptureAdapter", "LevelMenuCaptureAdapter", "StarMenuCaptureAdapter", "SkillMenuCaptureAdapter"},
            "core.inventory_matcher_adapter": {"InventoryMatcherAdapter"},
            "core.student_candidate_validation": {"StudentCandidateValidator"},
            "core.student_panel_recovery": {"StudentPanelRecovery"},
            "core.student_identity_recovery": {"StudentEntryRecovery"},
            "core.student_form_recovery": {"StudentFormRecovery"},
            "core.inventory_detail_recovery": {"InventoryDetailRecognizer", "InventoryDetailRecovery"},
            "core.inventory_navigation": {"InventoryNavigation"},
            "core.tactical_lobby_scanner": {"TacticalLobbyMatcherAdapter"},
            "core.tactical_v2": {"TacticalV2Store"},
            "core.windows_scanner_adapter": {"WindowsCaptureInputAdapter"},
            "core.recognition_synth_provider": {"SynthProvider"},
        }
        factory_path = Path(__file__).resolve().parents[1] / "core/scanner_runtime.py"
        imported = {}
        for node in ast.parse(factory_path.read_text(encoding="utf-8")).body:
            if isinstance(node, ast.ImportFrom) and node.module in module_exports:
                self.assertTrue({alias.name for alias in node.names} <= module_exports[node.module])
                imported[node.module] = node.names
            elif isinstance(node, ast.ImportFrom) and node.module and node.module.startswith("core."):
                self.assertIn(node.module, {"core.repository_store", "core.scanner_session", "core.runtime_paths"})

        modules, stubs = {}, {}
        for name, aliases in imported.items():
            module = ModuleType(name)
            for alias in aliases:
                constructor = MagicMock(name=f"{name}.{alias.name}")
                setattr(module, alias.name, constructor)
                stubs[alias.asname or alias.name] = constructor
            modules[name] = module
        name = "_sfb_factory_wiring_runtime"
        spec = importlib.util.spec_from_file_location(name, factory_path)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        runtime = importlib.util.module_from_spec(spec)
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        with ExitStack() as stack:
            stack.enter_context(patch.dict(sys.modules, {**modules, name: runtime}))
            spec.loader.exec_module(runtime)
            self.assertEqual(Path(runtime.__file__).resolve(), factory_path.resolve())
            self.assertIs(runtime.JsonRepository, JsonRepository)
            self.assertIs(runtime.ScannerSessionService, ScannerSessionService)
            stack.enter_context(patch.object(runtime, "resolve_extracted_asset_root", return_value=Path(temporary.name)))
            stack.enter_context(patch.object(runtime, "resolve_synth_cache_root", return_value=Path(temporary.name)))
            executor = NoWorkerExecutor()
            stack.enter_context(patch.object(runtime, "ScannerSessionService",
                side_effect=lambda **kwargs: ScannerSessionService(**kwargs, executor=executor)))
            actual = runtime.build_scanner_service(Path(temporary.name))
            self.addCleanup(actual.close)
            self.assertIsInstance(actual._repository, JsonRepository)
            self.assertIs(actual._executor, executor)
            self.assertIn("history_context", inspect.signature(actual._repository.update_students).parameters)
            self.assertIn("history_context", inspect.signature(actual._repository.update_inventory).parameters)
            self.assertIs(actual._target_provider, stubs["WindowsCaptureInputAdapter"].return_value)
            stubs["WindowsCaptureInputAdapter"].assert_called_once_with()
            stubs["WindowsCaptureInputAdapter"].return_value.assert_not_called()
            self.assertEqual(actual._sessions, {})
            # Real typed repository commit, direct synthetic session; no start/matcher/OS worker.
            actual._repository._clock = lambda: AT
            actual._student_validator = None
            pid = actual._repository.create_profile("Synthetic factory", "factory-profile")["profile"]["profile_id"]
            session = _Session("factory-session", 1, "student", {}, pid, terminal="completed")
            item = actual._make_candidate(session, {"candidate_id": "factory-candidate",
                  "payload": {"version": 1, "student_id": "aru", "values": {"level": 10}}, "evidence": []})
            session.candidates[item.candidate_id] = item
            actual._sessions[session.session_id] = session
            result = actual.commit(session_id=session.session_id, generation=1, candidate_id=item.candidate_id,
                  candidate_revision=item.revision, profile_id=pid, expected_repository_revision=0, idempotency_key="factory-scan")
            self.assertEqual(result["revision"], 1)
            event = actual._repository._profile(pid)["current_history"]["events"][-1]
            self.assertEqual(event["source"], "scan")
            self.assertEqual(event["applied_scope"], {"student_ids": ["aru"], "resource_keys": []})
            self.assertIsNone(actual._current_commits[(session.session_id, "factory-scan")].request)


from copy import deepcopy
from pathlib import Path
import json
import unittest
from unittest.mock import patch

from core.inventory_catalog import BY_KEY, CATALOG_REVISION
from core.repository_dto import canonical_json
from core.repository_inventory import rebase_inventory_snapshot
from core.scanner_session import ScannerSessionService, ScannerError, _Session

ROOT = Path(__file__).resolve().parents[2]
PID = 'a'*24
REQUEST_KEYS = {'session_id', 'generation', 'candidate_id', 'candidate_revision', 'profile_id',
                'expected_repository_revision', 'idempotency_key'}
SUCCESS_KEYS = {'candidate_id', 'candidate_revision', 'profile_id', 'revision'}

class NoWorkerExecutor:
    def submit(self, *args, **kwargs):
        raise AssertionError('No scanner worker thread permitted in memory refinements')

class MemoryPort:
    """Independent durable replay model, entirely dictionaries/counters in memory."""
    def __init__(self, *, large=False, loss=False):
        self.state = {'profile_id': PID, 'revision': 0,
                      'students': [{'version': 1, 'student_id': f'unrelated-{i:04d}',
                                    'values': {}, 'provenance': {'synthetic-source': 'snapshot-' + 'x'*128}} for i in range(700 if large else 2)],
                      'inventory': {'version': 1, 'entries': []}, 'goals': []}
        self.reads = self.writes = self.applies = self.clock = 0
        self.loss = loss
        self.cache = {}
        self.calls = []

    def get_state(self, profile_id):
        self.reads += 1
        return deepcopy(self.state)

    def update_students(self, profile_id, value, expected_revision, key, *, history_context=None):
        return self._write('students', profile_id, value, expected_revision, key, history_context)

    def update_inventory(self, profile_id, value, expected_revision, key, *, history_context=None):
        return self._write('inventory', profile_id, value, expected_revision, key, history_context)

    def _write(self, bucket, profile_id, value, expected, key, context):
        self.writes += 1
        request = {'bucket': bucket, 'profile_id': profile_id, 'value': deepcopy(value),
                   'expected': expected, 'key': key, 'context': context.to_wire() if context else None}
        self.calls.append(deepcopy(request))
        signature = canonical_json(request)
        identity = (profile_id, key)
        if identity in self.cache:
            stored, response = self.cache[identity]
            if stored != signature:
                raise ValueError('Memory model durable idempotency conflict')
            return deepcopy(response)
        if expected != self.state['revision']:
            raise ValueError('Memory model revision conflict')
        self.applies += 1
        self.clock += 1
        self.state[bucket] = deepcopy(value)
        self.state['revision'] += 1
        response = {'revision': self.state['revision']}
        self.cache[identity] = (signature, deepcopy(response))
        if self.loss:
            self.loss = False
            raise OSError('synthetic memory response loss after durable model apply')
        return response

    def external_write(self):
        self.state['revision'] += 1
        self.state['students'].append({'version': 1, 'student_id': 'external', 'values': {'level': 77}})

def service(port, kind='student', *, register=True):
    learning = []
    result = ScannerSessionService(target_provider=lambda: [], student_matcher=lambda *_: None,
        inventory_matcher=lambda *_: None, repository=port, asset_status=lambda: {},
        executor=NoWorkerExecutor(), candidate_review_hook=lambda *args: learning.append(args) or 1,
        id_factory=lambda: 'synthetic-candidate')
    session = _Session('synthetic-session', 3, kind, {'inventory_scan_profile': ' 未知 raw '}, PID,
                       terminal='completed')
    payload = {'version': 1, 'student_id': 'aru', 'values': {'level': 10}} if kind == 'student' else \
        {'version': 1, 'catalog_revision': CATALOG_REVISION,
         'entries': [{'key': 'Item_Icon_SkillBook_Ultimate_Piece', 'quantity': '7'}]}
    item = result._make_candidate(session, {'payload': payload, 'evidence': [],
                                          'candidate_id': 'synthetic-candidate'})
    item.approved = True
    session.candidates[item.candidate_id] = item
    if register:
        result._sessions[session.session_id] = session
    return result, session, item, learning

def request(session, item, key='original-key'):
    return {'session_id': session.session_id, 'generation': session.generation,
            'candidate_id': item.candidate_id, 'candidate_revision': item.revision,
            'profile_id': PID, 'expected_repository_revision': 0, 'idempotency_key': key}

def counts(port, learning, cleanup):
    return port.reads, port.writes, port.applies, port.clock, len(learning), len(cleanup)

class ScannerCommitHistoryRefinementMemoryTests(unittest.TestCase):
    def test_success_signature_and_exact_response_remain_while_large_snapshot_is_released(self):
        port = MemoryPort(large=True)
        scanner, session, item, learning = service(port)
        req = request(session, item)
        cleanup = []
        scanner._close_specimen = lambda specimen: cleanup.append(specimen)
        response = scanner.commit(**req)
        receipt = scanner._current_commits[(session.session_id, req['idempotency_key'])]
        self.assertEqual(set(req), REQUEST_KEYS)
        self.assertEqual(set(response), SUCCESS_KEYS)
        self.assertGreater(len(canonical_json(port.calls[0]['value'])), 100000)
        self.assertIsNone(receipt.request)
        self.assertEqual(receipt.public_request_json, canonical_json(req))
        self.assertEqual(receipt.response_json, canonical_json(response))
        self.assertFalse(receipt.in_flight)
        # Real service review changes candidate revision/payload, without specimen/sample storage.
        scanner.review(session.session_id, session.generation, item.candidate_id, item.revision,
                       {'version': 1, 'student_id': 'aru', 'values': {'level': 20}}, approve=True, reason='synthetic-memory-edit')
        self.assertEqual(item.revision, req['candidate_revision'] + 1)
        port.external_write()
        before = counts(port, learning, cleanup)
        current = deepcopy(port.state)
        replay = scanner.commit(**req)
        self.assertEqual(replay, response)
        replay['revision'] = 999
        self.assertEqual(scanner.commit(**req), response)
        self.assertEqual(port.state, current)
        self.assertEqual(counts(port, learning, cleanup), before)

    def test_changed_generation_conflicts_before_session_stale_on_success(self):
        port = MemoryPort()
        scanner, session, item, _ = service(port)
        req = request(session, item)
        scanner.commit(**req)
        before = (port.reads, port.writes)
        with self.assertRaises(ScannerError) as caught:
            scanner.commit(**{**req, 'generation': session.generation + 1})
        self.assertEqual(caught.exception.code, 'idempotency_conflict')
        self.assertEqual((port.reads, port.writes), before)

    def test_pending_loss_preserves_full_submission_and_identical_replay_after_mutation(self):
        port = MemoryPort(large=True, loss=True)
        scanner, session, item, learning = service(port)
        req = request(session, item)
        with self.assertRaisesRegex(OSError, 'synthetic memory response loss'):
            scanner.commit(**req)
        receipt = scanner._current_commits[(session.session_id, req['idempotency_key'])]
        frozen = receipt.request
        self.assertIsNotNone(frozen)
        self.assertIsNone(receipt.response_json)
        self.assertFalse(receipt.in_flight)
        frozen_json = frozen.current_json
        context = frozen.context.to_wire()
        self.assertIsNone(context['retry_of'])
        scanner.review(session.session_id, session.generation, item.candidate_id, item.revision,
                       {'version': 1, 'student_id': 'aru', 'values': {'level': 20}}, approve=True, reason='synthetic-memory-edit')
        port.external_write()
        before = deepcopy(port.state)
        replay = scanner.commit(**req)
        self.assertEqual(replay['revision'], 1)
        self.assertEqual(port.reads, 1)
        self.assertEqual((port.writes, port.applies, port.clock), (2, 1, 1))
        self.assertEqual(port.calls[0], port.calls[1])
        self.assertEqual(canonical_json(port.calls[1]['value']), frozen_json)
        self.assertEqual(port.calls[1]['context'], context)
        self.assertEqual(port.state, before)
        self.assertEqual(learning, [])
        self.assertIsNone(receipt.request)

    def test_changed_generation_and_other_explicit_fields_conflict_while_pending(self):
        port = MemoryPort(loss=True)
        scanner, session, item, _ = service(port)
        req = request(session, item)
        with self.assertRaises(OSError): scanner.commit(**req)
        for field, value in [('generation', 4), ('candidate_id', 'different'), ('candidate_revision', 2),
                             ('profile_id', 'b'*24), ('expected_repository_revision', 1)]:
            with self.subTest(field=field), self.assertRaises(ScannerError) as caught:
                scanner.commit(**{**req, field: value})
            self.assertEqual(caught.exception.code, 'idempotency_conflict')
        self.assertEqual((port.reads, port.writes), (1, 1))
        self.assertIsNotNone(scanner._current_commits[(session.session_id, req['idempotency_key'])].request)

    def test_cleanup_failure_occurs_after_ready_receipt_and_snapshot_release(self):
        port = MemoryPort(large=True)
        scanner, session, item, learning = service(port)
        item.answer_specimen = {'synthetic-opaque': object()}
        req = request(session, item)
        cleanup = []
        def fail_cleanup(specimen):
            cleanup.append(specimen)
            raise ValueError('synthetic cleanup failure')
        scanner._close_specimen = fail_cleanup
        with self.assertRaisesRegex(ValueError, 'synthetic cleanup failure'):
            scanner.commit(**req)
        receipt = scanner._current_commits[(session.session_id, req['idempotency_key'])]
        self.assertIsNone(receipt.request)
        self.assertIsNotNone(receipt.response_json)
        self.assertFalse(receipt.in_flight)
        self.assertEqual(item.answer_specimen, {})
        before = counts(port, learning, cleanup)
        response = scanner.commit(**req)
        self.assertEqual(response, {'candidate_id': item.candidate_id, 'candidate_revision': 1, 'profile_id': PID, 'revision': 1})
        self.assertEqual(counts(port, learning, cleanup), before)
        self.assertEqual(before, (1, 1, 1, 1, 0, 1))

    def test_inventory_alias_memory_commit_uses_shared_rebase_and_releases_snapshot(self):
        port = MemoryPort()
        scanner, session, item, _ = service(port, 'inventory')
        req = request(session, item)
        response = scanner.commit(**req)
        self.assertEqual(response['revision'], 1)
        call = port.calls[0]
        self.assertEqual(call['value']['entries'][0]['key'], 'Item_Icon_SkillBook_Ultimate')
        self.assertEqual(call['context']['applied_keys'], ['Item_Icon_SkillBook_Ultimate'])
        self.assertEqual(call['context']['inventory_scan_profile'], ' 未知 raw ')
        self.assertIsNone(scanner._current_commits[(session.session_id, req['idempotency_key'])].request)

    def test_signature_unavailable_writes_zero_and_keeps_pending(self):
        port = MemoryPort()
        scanner, session, item, _ = service(port)
        req = request(session, item)
        with patch('core.scanner_session.inspect.signature', side_effect=ValueError('synthetic missing signature')):
            with self.assertRaises(ScannerError) as caught:
                scanner.commit(**req)
        self.assertEqual(caught.exception.code, 'persistence_deferred')
        self.assertEqual(port.writes, 0)
        receipt = scanner._current_commits[(session.session_id, req['idempotency_key'])]
        self.assertIsNotNone(receipt.request)
        self.assertFalse(receipt.in_flight)

    def test_internal_type_error_never_calls_compatibility_fallback(self):
        port = MemoryPort()
        calls = []
        def failure(profile_id, value, expected, key, *, history_context=None):
            calls.append(history_context)
            raise TypeError('synthetic internal writer failure')
        port.update_students = failure
        scanner, session, item, _ = service(port)
        req = request(session, item)
        with self.assertRaisesRegex(TypeError, 'synthetic internal writer failure'):
            scanner.commit(**req)
        self.assertEqual(len(calls), 1)
        self.assertIsNotNone(calls[0])
        self.assertIsNotNone(scanner._current_commits[(session.session_id, req['idempotency_key'])].request)

    def test_old_four_argument_callback_is_called_once_before_receipt_replay(self):
        port = MemoryPort()
        calls = []
        def legacy(profile_id, value, expected, key):
            calls.append((profile_id, deepcopy(value), expected, key))
            return {'revision': 71}
        port.update_students = legacy
        scanner, session, item, _ = service(port)
        req = request(session, item)
        response = scanner.commit(**req)
        self.assertEqual(response['revision'], 71)
        self.assertEqual(scanner.commit(**req), response)
        self.assertEqual(len(calls), 1)

    def test_first_bad_generation_keeps_legacy_stale_generation_without_state_read(self):
        port = MemoryPort()
        scanner, session, item, _ = service(port)
        req = request(session, item)
        with self.assertRaises(ScannerError) as caught:
            scanner.commit(**{**req, 'generation': 4})
        self.assertEqual(caught.exception.code, 'stale_generation')
        self.assertEqual((port.reads, port.writes), (0, 0))

    def test_fresh_service_without_session_cannot_restore_old_public_commit(self):
        port = MemoryPort()
        first, session, item, _ = service(port)
        req = request(session, item)
        first.commit(**req)
        second, _, _, _ = service(port, register=False)
        with self.assertRaises(ScannerError) as caught:
            second.commit(**req)
        self.assertEqual(caught.exception.code, 'session_not_found')
        self.assertEqual((port.reads, port.writes), (1, 1))

    def test_original_helper_memory_oracle_parity_and_input_nonmutation(self):
        fixture = json.loads((ROOT / 'contracts/fixtures/scanner_commit_history_sfb2b_v1.json').read_text(encoding='utf-8'))
        self.assertEqual(len(fixture['helper_parity_cases']), 6)
        for case in fixture['helper_parity_cases']:
            with self.subTest(case=case['id']):
                original = deepcopy(case['input'])
                result = rebase_inventory_snapshot(case['input'])
                self.assertEqual(result, case['expected'])
                self.assertEqual(case['input'], original)
                self.assertEqual(result['catalog_revision'], CATALOG_REVISION)
        alias = fixture['helper_parity_cases'][0]['expected']['entries'][0]
        self.assertEqual(alias['observed_slot'], 42)
        self.assertEqual(alias['index'], BY_KEY['Item_Icon_SkillBook_Ultimate'].order_index)
        self.assertEqual(fixture['helper_parity_cases'][1]['expected']['entries'][0]['observed_slot'], 77)
        self.assertIsNone(fixture['helper_parity_cases'][3]['expected']['entries'][0].get('observed_slot'))

    def test_fixture_original_six_and_public_wire_keys_remain_unchanged(self):
        fixture = json.loads((ROOT / 'contracts/fixtures/scanner_commit_history_sfb2b_v1.json').read_text(encoding='utf-8'))
        self.assertEqual(len(fixture['cases']), 6)
        self.assertEqual(set(fixture['public_commit_request_keys']), REQUEST_KEYS)
        self.assertEqual(set(fixture['public_success_keys']), SUCCESS_KEYS)
        self.assertEqual(len(fixture['refinement_cases']), 7)




if __name__ == "__main__":
    unittest.main()
