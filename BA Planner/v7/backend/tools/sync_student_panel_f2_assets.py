"""Copy only F2 recognition templates/ROIs from the read-only v6 reference."""
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
                           source_path=source, panel_state=identity))
    data = json.loads((V6 / "regions/student_data_regions.json").read_text(encoding="utf-8-sig"))["student_data"]
    regions = {k: data[k] for k in ("basic_info_button", "levelcheck_button", "star_menu_button",
        "weapon_menu_quit_button", "equipmentmenu_quit_button", "skillmenu_quit_button", "statmenu_quit_button")}
    regions["title"] = dict(x1=1030/2560, y1=145/1440, x2=1530/2560, y2=285/1440)
    # Alternate point inside the same known panel's X, offset from its region centre.
    regions["alternate_close_dx"] = .004
    path = DEST / "regions/student_panel_regions.json"
    path.write_text(json.dumps(regions, indent=2)+"\n", encoding="utf-8")
    record(path, "student-panel-regions", "adapted:../v6/regions/student_data_regions.json+core/scanner_shared.py")
    for state in ("weapon", "equipment", "skill", "stat", "basic", "level", "star"):
        filename = (f"student_panel_title_{state}.png" if state in ("weapon", "equipment", "skill", "stat")
                    else "student_data__"+{"basic":"basic_info", "level":"levelcheck", "star":"star_menu"}[state]+"_button_on.png")
        source = V6 / "templates/menu_detect_flag" / filename
        destination = DEST / "templates/student_panel" / filename
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        record(destination, "student-panel-template", "../v6/"+source.relative_to(V6).as_posix(), state)
    (DEST / "student_panel_manifest.json").write_text(json.dumps(dict(version=1,
        source_version="student-panel-f2-v6-2026-08-30", assets=assets), indent=2)+"\n", encoding="utf-8")
    print(f"F2: {len(assets)} recognition assets")


if __name__ == "__main__":
    main()
