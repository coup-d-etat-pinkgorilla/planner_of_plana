"""Copy F3 recognition-only v6 assets; never used by runtime."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
V6 = ROOT.parent / "v6"
DEST = ROOT / "backend/assets/recognition/v1"


def main():
    assets = []
    def record(path, purpose, source, identity=None):
        raw = path.read_bytes()
        assets.append(dict(path=path.relative_to(DEST).as_posix(), scan_kind="student", purpose=purpose,
                           required=True, bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest(),
                           source_path=source, potential_value=identity))
    basic = json.loads((V6 / "regions/student_normal_info_regions.json").read_text(encoding="utf-8-sig"))
    data = json.loads((V6 / "regions/student_data_regions.json").read_text(encoding="utf-8-sig"))["student_data"]
    detail = json.loads((V6 / "regions/student_statmenu_regions.json").read_text(encoding="utf-8-sig"))
    regions = dict(basic={key: basic[f"basic_additional_badge_{key}"] for key in ("hp", "atk", "heal")},
                   detail=detail, stat_menu_button=data["stat_menu_button"])
    path = DEST / "regions/student_potential_regions.json"
    path.write_text(json.dumps(regions, indent=2)+"\n", encoding="utf-8")
    record(path, "student-potential-regions", "adapted:../v6/regions/student_{normal_info,data,statmenu}_regions.json")
    for folder in ("basic_additional_stat_values", "stat_hp", "stat_atk", "stat_heal"):
        for source in sorted((V6 / "templates" / folder).glob("*.png")):
            if not source.stem.isdigit() or not 0 <= int(source.stem) <= 25:
                continue
            destination = DEST / "templates/student_potential" / folder / source.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            record(destination, "student-potential-template", "../v6/"+source.relative_to(V6).as_posix(),
                   ("basic" if folder.startswith("basic") else folder[5:])+":"+source.stem)
    (DEST / "student_potential_manifest.json").write_text(json.dumps(dict(version=1,
        source_version="student-potential-f3-v6-2026-08-31", assets=assets), indent=2)+"\n", encoding="utf-8")
    print(f"F3: {len(assets)} recognition assets")


if __name__ == "__main__":
    main()
