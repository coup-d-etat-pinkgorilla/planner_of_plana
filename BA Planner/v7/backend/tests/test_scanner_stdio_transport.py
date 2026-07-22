from __future__ import annotations

import io
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import unittest

from core.application_protocol_v1 import ApplicationProtocolV1
from core.jsonl_multiplexer import JsonlMultiplexer
from core.repository_store import JsonRepository
from core.scanner_session import ScannerSessionService
from core.stdio_server import serve


def request(request_id: str, method: str, payload: dict) -> dict:
    return {"protocol": 1, "id": request_id, "type": "request", "method": method, "payload": payload}


class ScannerStdioTransportTests(unittest.TestCase):
    def test_start_response_precedes_fast_worker_events(self) -> None:
        with TemporaryDirectory() as root:
            repository = JsonRepository(Path(root))
            service = ScannerSessionService(
                target_provider=lambda: [{"target_id": "w1", "title": "BA", "status": "ready"}],
                student_matcher=lambda *_args: [{
                    "candidate_id": "c1",
                    "payload": {"version": 1, "student_id": "shiroko", "values": {"level": 90}},
                    "evidence": [{"field": "level", "status": "ok", "source": "fixture", "confidence": 1.0}],
                }],
                inventory_matcher=lambda *_args: [],
                repository=repository,
                asset_status=lambda: {"ready": True, "manifest_version": 1, "missing": []},
                id_factory=lambda: "s1",
            )
            protocol = ApplicationProtocolV1(storage_root=Path(root), scanner_service=service)
            stdin = io.StringIO(json.dumps(request("start", "scanner.session.start", {"scan_kind": "student", "target_id": "w1"})) + "\n")
            stdout = io.StringIO()
            serve(stdin, stdout, io.StringIO(), protocol=protocol)
            messages = [json.loads(line) for line in stdout.getvalue().splitlines()]
            self.assertEqual("response", messages[0]["type"])
            self.assertEqual("scanner.session.start", messages[0]["method"])
            self.assertEqual("terminal", messages[-1]["payload"]["event_kind"])
            self.assertEqual(1, sum(item.get("payload", {}).get("event_kind") == "terminal" for item in messages))

    def test_backpressure_coalesces_progress_but_preserves_reliable_events(self) -> None:
        stdout = io.StringIO()
        output = JsonlMultiplexer(stdout, capacity=2)
        output.publish_response({"protocol": 1, "id": "r", "type": "response", "method": "scanner.session.start", "payload": {"session_id": "s", "generation": 1, "scan_kind": "student"}})
        for sequence in range(1, 101):
            output.publish_event({"protocol": 1, "type": "event", "method": "scanner.session.event", "payload": {"session_id": "s", "generation": 1, "sequence": sequence, "scan_kind": "student", "event_kind": "progress", "current": sequence, "total": 100, "message_key": "scan"}})
        output.publish_event({"protocol": 1, "type": "event", "method": "scanner.session.event", "payload": {"session_id": "s", "generation": 1, "sequence": 101, "scan_kind": "student", "event_kind": "candidate", "candidate": {}}})
        output.publish_event({"protocol": 1, "type": "event", "method": "scanner.session.event", "payload": {"session_id": "s", "generation": 1, "sequence": 102, "scan_kind": "student", "event_kind": "terminal", "outcome": "completed"}})
        output.close()
        messages = [json.loads(line) for line in stdout.getvalue().splitlines()]
        kinds = [item.get("payload", {}).get("event_kind") for item in messages]
        self.assertIn("candidate", kinds)
        self.assertEqual("terminal", kinds[-1])
        self.assertLess(kinds.count("progress"), 100)
        sequences = [item["payload"]["sequence"] for item in messages if item["type"] == "event"]
        self.assertEqual(sequences, sorted(sequences))

    def test_real_process_serves_asset_readiness_and_windows_target_list(self) -> None:
        backend = Path(__file__).parents[1]
        process = subprocess.Popen(
            [sys.executable, "-m", "core.backend_process"], cwd=backend,
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding="utf-8",
        )
        requests = [
            request("assets", "scanner.recognition.status", {}),
            request("targets", "scanner.target.list", {}),
        ]
        stdout, stderr = process.communicate("\n".join(json.dumps(item) for item in requests) + "\n", timeout=10)
        self.assertEqual(0, process.returncode, stderr)
        responses = [json.loads(line) for line in stdout.splitlines()]
        self.assertEqual(["assets", "targets"], [item["id"] for item in responses])
        self.assertTrue(responses[0]["payload"]["ready"])
        self.assertEqual(16, responses[0]["payload"]["asset_count"])
        self.assertIsInstance(responses[1]["payload"]["targets"], list)


if __name__ == "__main__":
    unittest.main()
