"""C1c: inventory scan commits merge into the account and are pinned to the catalog revision."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from core.inventory_catalog import CATALOG_REVISION
from core.repository_store import JsonRepository
from core.scanner_session import ScannerError, ScannerSessionService


MANDRAGORA = "Item_Icon_Material_Mandragora_0"
NOTE_0, NOTE_1, NOTE_2 = (f"Item_Icon_SkillBook_Abydos_{tier}" for tier in range(3))


def saved(key: str, quantity: str) -> dict:
    return {"key": key, "quantity": quantity, "item_id": key}


def scanned(key: str, quantity: str, slot: int | None) -> dict:
    return {"key": key, "quantity": quantity, "item_id": key, "name": None, "observed_slot": slot,
            "profile_id": "tech_notes", "inventory_scan_profile": "tech_notes"}


class ScannerInventoryCommitC1cTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = TemporaryDirectory()
        self.repository = JsonRepository(Path(self.directory.name))
        self.profile_id = self.repository.create_profile("c1c", "create")["profile"]["profile_id"]
        revision = self.repository.get_state(self.profile_id)["revision"]
        self.repository.update_inventory(self.profile_id, {"version": 1, "entries": [
            saved(MANDRAGORA, "5"), saved(NOTE_0, "3"), saved(NOTE_1, "9"), saved(NOTE_2, "4"),
        ]}, revision, "seed")
        self.services: list[ScannerSessionService] = []

    def tearDown(self) -> None:
        for service in self.services:
            service.close()
        self.directory.cleanup()

    def commit(self, payload: dict) -> dict:
        ids = iter(["s1", "c1"])
        service = ScannerSessionService(
            target_provider=lambda: [{"target_id": "w1", "title": "Blue Archive", "status": "ready"}],
            student_matcher=lambda *_args: [],
            inventory_matcher=lambda *_args: [{"payload": payload, "evidence": [], "review_required": False}],
            repository=self.repository,
            asset_status=lambda: {"ready": True, "manifest_version": 1, "missing": []},
            id_factory=lambda: next(ids),
        )
        self.services.append(service)
        service.start("inventory", "w1", profile_id=self.profile_id, inventory_scan_profile="tech_notes")
        service.wait("s1")
        revision = self.repository.get_state(self.profile_id)["revision"]
        return service.commit(session_id="s1", generation=1, candidate_id="c1", candidate_revision=1,
                              profile_id=self.profile_id, expected_repository_revision=revision,
                              idempotency_key="commit")

    def quantities(self) -> dict[str, str | None]:
        entries = self.repository.get_state(self.profile_id)["inventory"]["entries"]
        return {entry["item_id"] or entry["key"]: entry["quantity"] for entry in entries}

    def test_profile_scan_commit_upserts_and_keeps_every_other_saved_entry(self) -> None:
        self.commit({"version": 1, "catalog_revision": CATALOG_REVISION, "entries": [
            scanned(NOTE_0, "7", 3), scanned(NOTE_1, "0", None),
        ]})
        # Other profiles survive; unseen same-profile items keep their saved count.
        self.assertEqual({MANDRAGORA: "5", NOTE_0: "7", NOTE_1: "0", NOTE_2: "4"}, self.quantities())
        stored = self.repository.get_state(self.profile_id)["inventory"]
        self.assertEqual(CATALOG_REVISION, stored["catalog_revision"])
        self.assertNotIn("inventory_scan_profile", {key for entry in stored["entries"] for key in entry})

    def test_missing_or_stale_catalog_revision_rejects_commit_without_writing(self) -> None:
        before = self.repository.get_state(self.profile_id)
        for revision, code in ((None, "catalog_revision_missing"), ("0" * 64, "catalog_revision_mismatch")):
            with self.subTest(code=code):
                payload = {"version": 1, "entries": [scanned(NOTE_0, "7", 3)]}
                if revision is not None:
                    payload["catalog_revision"] = revision
                with self.assertRaises(ScannerError) as raised:
                    self.commit(payload)
                self.assertEqual(code, raised.exception.code)
                self.assertEqual({"expected": CATALOG_REVISION, "received": revision}, raised.exception.details)
                self.assertEqual(before, self.repository.get_state(self.profile_id))


if __name__ == "__main__":
    unittest.main()
