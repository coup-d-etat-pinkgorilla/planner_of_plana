from __future__ import annotations

import argparse
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MATRIX = ROOT / "backend/tests/fixtures/scanner_fallback_restoration/restoration-matrix.json"
OUTPUT = ROOT / "docs/migration/scanner-fallback-restoration/f12-r01-r24-audit.json"

PHASE_EVIDENCE = {
    "F1": ("backend/tests/test_scanner_fallback_f1.py", "backend/tests/fixtures/scanner_fallback_restoration/f1-capture-input-parity.json", "docs/migration/scanner-fallback-restoration/f1-results.md", "native1280"),
    "F2": ("backend/tests/test_student_panel_f2.py", "backend/tests/fixtures/scanner_fallback_restoration/f2-panel-parity.json", "docs/migration/scanner-fallback-restoration/f2-results.md", "native1280"),
    "F3": ("backend/tests/test_student_potential_f3.py", "backend/tests/fixtures/student_potential_f3_v6_parity.json", "docs/migration/scanner-fallback-restoration/f3-results.md", "native1280+native2560"),
    "F4": ("backend/tests/test_student_level_f4.py", "backend/tests/fixtures/student_level_f4_v6_parity.json", "docs/migration/scanner-fallback-restoration/f4-results.md", "native1280"),
    "F5": ("backend/tests/test_student_star_f5.py", "backend/tests/fixtures/student_star_f5_v6_parity.json", "docs/migration/scanner-fallback-restoration/f5-results.md", "native1280"),
    "F6": ("backend/tests/test_student_skill_f6.py", "backend/tests/fixtures/student_skill_f6_v6_parity.json", "docs/migration/scanner-fallback-restoration/f6-results.md", "native1280"),
    "F7": ("backend/tests/test_student_equipment_f7.py", "backend/tests/fixtures/student_equipment_f7_v6_parity.json", "docs/migration/scanner-fallback-restoration/f7-results.md", "native1280; native2560 favorite-lock fixture only"),
    "F8": ("backend/tests/test_student_identity_f8.py", "backend/tests/fixtures/student_identity_f8_v6_parity.json", "docs/migration/scanner-fallback-restoration/f8-results.md", "native1280+multi-form"),
    "F9": ("backend/tests/test_inventory_detail_f9.py", "backend/tests/fixtures/inventory_detail_f9_v6_parity.json", "docs/migration/scanner-fallback-restoration/f9-results.md", "native1280"),
    "F10": ("backend/tests/test_inventory_navigation_f10.py", "backend/tests/fixtures/inventory_navigation_f10_v6_parity.json", "docs/migration/scanner-fallback-restoration/f10-results.md", "native1280"),
    "F11": ("backend/tests/test_session_calibration_f11.py", "backend/tests/fixtures/session_calibration_f11_v6_parity.json", "docs/migration/scanner-fallback-restoration/f11-results.md", "native1280 level; equipment integration pending F12"),
}


def _symbol_status(symbol: str) -> dict[str, object]:
    path_text, name = symbol.split(":", 1)
    path = ROOT / path_text
    terminal = name.rsplit(".", 1)[-1]
    text = path.read_text(encoding="utf-8") if path.is_file() else ""
    return {"symbol": symbol, "file_exists": path.is_file(), "name_present": terminal in text}


def build_audit() -> dict[str, object]:
    matrix = json.loads(MATRIX.read_text(encoding="utf-8"))
    rows = []
    for source in matrix["rows"]:
        test, fixture, result, live = PHASE_EVIDENCE[source["phase"]]
        artifacts = {name: {"path": value, "exists": (ROOT / value).exists()} for name, value in {
            "test": test, "fixture": fixture, "result": result,
        }.items()}
        symbols = [_symbol_status(item) for item in source["v7_symbols"]]
        rows.append({
            "id": source["id"],
            "phase": source["phase"],
            "dependency_group": source["dependency_group"],
            "implementation": symbols,
            "artifacts": artifacts,
            "historical_live_coverage": live,
            "historical_evidence_refs": source.get("evidence_refs", []),
            "trace_partition": "historical_native_scan",
            "audit_pass": all(a["exists"] for a in artifacts.values()) and all(s["file_exists"] and s["name_present"] for s in symbols),
        })
    ids = [row["id"] for row in rows]
    return {
        "schema_version": 1,
        "scope": "F12 R01-R24 implementation/artifact/fixture/test/historical-live traceability",
        "source_matrix": str(MATRIX.relative_to(ROOT)).replace("\\", "/"),
        "evidence_partition_rule": "Historical native scans, fixed-frame replay, old JSON replay and new F12 native scans remain separate.",
        "rows": rows,
        "summary": {
            "row_count": len(rows),
            "ids_complete": ids == [f"R{i:02d}" for i in range(1, 25)],
            "passed": sum(bool(row["audit_pass"]) for row in rows),
            "failed": [row["id"] for row in rows if not row["audit_pass"]],
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    audit = build_audit()
    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(audit["summary"], ensure_ascii=False))
    if audit["summary"]["failed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
