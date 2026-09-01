from __future__ import annotations

from pathlib import Path

from core.recognition_assets import RecognitionAssetCatalog
from core.recognition_answer_samples import RecognitionAnswerSampleStore
from core.repository_store import JsonRepository
from core.scanner_matchers import (
    EquipmentMenuCaptureAdapter, InventoryMatcherAdapter, StudentMatcherAdapter,
    WeaponMenuCaptureAdapter, StatMenuCaptureAdapter, LevelMenuCaptureAdapter, StarMenuCaptureAdapter, SkillMenuCaptureAdapter,
)
from core.scanner_session import ScannerSessionService
from core.student_candidate_validation import StudentCandidateValidator
from core.student_panel_recovery import StudentPanelRecovery
from core.student_identity_recovery import StudentEntryRecovery
from core.student_form_recovery import StudentFormRecovery
from core.inventory_detail_recovery import InventoryDetailRecognizer, InventoryDetailRecovery
from core.inventory_navigation import InventoryNavigation
from core.tactical_lobby_scanner import TacticalLobbyMatcherAdapter
from core.tactical_v2 import TacticalV2Store
from core.windows_scanner_adapter import WindowsCaptureInputAdapter


def build_scanner_service(storage_root: Path) -> ScannerSessionService:
    catalog = RecognitionAssetCatalog()
    catalog.verify()
    windows = WindowsCaptureInputAdapter()
    repository = JsonRepository(storage_root)
    answer_samples = RecognitionAnswerSampleStore(storage_root)
    tactical = TacticalV2Store(storage_root, repository)
    panels = StudentPanelRecovery(windows, catalog)
    student_matcher = StudentMatcherAdapter(
        windows, catalog, equipment_menu=EquipmentMenuCaptureAdapter(windows, catalog, recovery=panels),
        weapon_menu=WeaponMenuCaptureAdapter(windows, catalog, recovery=panels),
        stat_menu=StatMenuCaptureAdapter(windows, catalog, recovery=panels),
        level_menu=LevelMenuCaptureAdapter(windows, catalog, recovery=panels),
        star_menu=StarMenuCaptureAdapter(windows, catalog, recovery=panels),
        skill_menu=SkillMenuCaptureAdapter(windows, catalog, recovery=panels),
        answer_samples=answer_samples,
        entry_recovery=StudentEntryRecovery(windows, catalog, panels),
        form_recovery=StudentFormRecovery(windows, catalog.region_for_purpose('student', 'student-identity-regions')),
    )
    inventory_detail = InventoryDetailRecognizer(catalog)
    inventory_matcher = InventoryMatcherAdapter(
        windows, catalog, answer_samples=answer_samples,
        detail_recovery=InventoryDetailRecovery(windows,inventory_detail),
        navigation=InventoryNavigation(windows,catalog,inventory_detail),
    )

    def train_answer(
        scan_kind: str, profile_id: str, candidate_id: str,
        specimen: dict, payload: dict, _reason: str, _approve: bool,
    ) -> int:
        matcher = student_matcher if scan_kind == "student" else inventory_matcher
        return matcher.train_user_answer(profile_id, candidate_id, specimen, payload)

    def close_resources():
        student_matcher.potential_recognizer.close()
        student_matcher.level_recognizer.close()
        student_matcher.star_recognizer.close()
        student_matcher.skill_recognizer.close()
        student_matcher.equipment_controls.close()
        student_matcher.identity_recognizer.close()
        student_matcher.entry_recovery.close()
        inventory_matcher.detail_recovery.recognizer.close()
        inventory_matcher.navigation.close()
        panels.close()
        windows.close()

    return ScannerSessionService(
        target_provider=windows,
        student_matcher=student_matcher,
        inventory_matcher=inventory_matcher,
        tactical_lobby_matcher=TacticalLobbyMatcherAdapter(windows, catalog),
        tactical_lobby_committer=lambda profile_id, payload, revision, key: tactical.commit_lobby(
            profile_id, payload, "", "", [], revision, key
        ),
        repository=repository,
        asset_status=catalog.verify,
        student_validator=StudentCandidateValidator(repository),
        candidate_review_hook=train_answer,
        resource_close_hook=close_resources,
    )
