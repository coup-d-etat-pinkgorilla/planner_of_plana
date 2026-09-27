"""C1 inventory evidence contract: legacy diagnostic names map to the current meaning."""
import unittest

from core.scanner_matchers import LEGACY_INVENTORY_EVIDENCE_SOURCES, canonical_inventory_evidence
from core.scanner_session import ScannerError, ScannerSessionService


class InventoryEvidenceContractC1Tests(unittest.TestCase):
    def test_legacy_sources_and_zero_fill_fields_map_to_current_contract(self):
        entries = [
            {"key": "Item_Icon_SkillBook_Abydos_0", "quantity": "7", "observed_slot": 3},
            {"key": "Item_Icon_SkillBook_Abydos_1", "quantity": "0", "observed_slot": None},
        ]
        legacy = [
            {"field": "entries[3].item_id", "status": "uncertain", "source": "detail_template_fallback", "confidence": .7, "note": "margin=0.01"},
            {"field": "scroll_overlap", "status": "ok", "source": "verified_row_overlap", "confidence": 1.0, "note": "rows=3;reason=verified_row_overlap"},
            {"field": "scroll_overlap", "status": "ok", "source": "verified_row_overlap", "confidence": 1.0, "note": "rows=4;reason=verified_no_motion"},
            {"field": "entries[1].quantity", "status": "ok", "source": "verified_profile_zero_fill", "confidence": 1.0, "note": "verified"},
        ]
        current = canonical_inventory_evidence(legacy, entries)
        self.assertEqual(
            [("entries[3].item_id", "grid_same_crop_rematch"), ("scroll_overlap", "verified_row_overlap"),
             ("scroll_overlap", "verified_no_motion"), ("zero_fill[Item_Icon_SkillBook_Abydos_1].quantity", "verified_profile_zero_fill")],
            [(item["field"], item["source"]) for item in current],
        )
        self.assertEqual("detail_template_fallback", legacy[0]["source"])  # input is not mutated
        self.assertEqual(current, canonical_inventory_evidence(current, entries))  # idempotent
        self.assertEqual({"detail_template_fallback": "grid_same_crop_rematch"}, LEGACY_INVENTORY_EVIDENCE_SOURCES)

    def test_scan_profile_entry_field_stays_out_of_the_repository_payload(self):
        payload = {"version": 1, "entries": [{
            "key": "Item_Icon_SkillBook_Abydos_0", "quantity": "7", "item_id": "Item_Icon_SkillBook_Abydos_0",
            "name": None, "observed_slot": 3, "profile_id": "tech_notes", "inventory_scan_profile": "tech_notes",
        }]}
        snapshot = ScannerSessionService._validated_payload("inventory", payload)
        self.assertNotIn("inventory_scan_profile", snapshot.to_dict()["entries"][0])
        self.assertEqual("tech_notes", payload["entries"][0]["inventory_scan_profile"])
        payload["entries"][0]["inventory_scan_profile"] = "credits"
        with self.assertRaises(ScannerError):
            ScannerSessionService._validated_payload("inventory", payload)


if __name__ == "__main__":
    unittest.main()
