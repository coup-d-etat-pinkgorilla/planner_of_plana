from __future__ import annotations

import sys
from pathlib import Path

from core.application_protocol_v1 import ApplicationProtocolV1
from core.repository_store import JsonRepository
from core.runtime_paths import resolve_repository_root
from core.scanner_session import ScannerSessionService
from core.stdio_server import serve
from core.recognition_answer_samples import RecognitionAnswerSampleStore
from tests.test_recognition_sample_safety_o1 import cells, training_adapter


def _student_matcher(_target, _cancel, progress):
    progress(1, 1, "scanner_e2e_fixture")
    return [{
        "candidate_id": "scanner-e2e-candidate",
        "payload": {
            "version": 1,
            "student_id": "airi",
            "values": {"level": 90, "bond_rank": 20},
            "provenance": {"level": "scanner-e2e-fixture"},
        },
        "evidence": [{
            "field": "level",
            "status": "uncertain",
            "source": "scanner-e2e-fixture",
            "confidence": 0.6,
        }, {"field": "bond_rank", "status": "uncertain", "source": "scanner-e2e-fixture"}],
        "review_required": True,
        "_answer_specimen": {"source_size": (1280, 720), "numeric_groups": {
            "basic_relationship_rank_studio_2_cells": cells(26),
        }},
    }]


def _student_validator(payload, profile_id, _relationship_ranks=None):
    level = payload.get("values", {}).get("level")
    verified = level == 91 and payload.get("values", {}).get("bond_rank") == 26
    return {
        "field": "student_stat_validation",
        "status": "verified" if verified else "suspicious",
        "source": "scanner-e2e-validator",
        "confidence": 1.0 if verified else 0.0,
        "note": "edited level accepted" if verified else "level requires review",
        "details": {
            "validation_status": "verified" if verified else "suspicious",
            "profile_id": profile_id,
            "expected_level": 91,
            "observed_level": level,
        },
    }


def main() -> None:
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    storage_root = resolve_repository_root()
    repository = JsonRepository(storage_root)
    adapter = training_adapter(RecognitionAnswerSampleStore(storage_root))
    service = ScannerSessionService(
        target_provider=lambda: [{
            "target_id": "scanner-e2e-target",
            "title": "Scanner E2E Fixture",
            "status": "ready",
            "foreground": False,
        }],
        student_matcher=_student_matcher,
        inventory_matcher=lambda *_args: [],
        repository=repository,
        asset_status=lambda: {
            "ready": True,
            "manifest_version": 1,
            "asset_count": 16,
            "missing": [],
            "corrupt": [],
        },
        student_validator=_student_validator,
        candidate_review_hook=lambda _kind, profile, candidate, specimen, payload, _reason, _approve, fields:
            adapter.train_user_answer(profile, candidate, specimen, payload, fields),
    )
    serve(protocol=ApplicationProtocolV1(
        storage_root=Path(storage_root),
        scanner_service=service,
    ))


if __name__ == "__main__":
    main()
