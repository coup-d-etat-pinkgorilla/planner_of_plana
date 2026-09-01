"""Recognition-only F4 slice from v6; no runtime v6 dependency."""
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
        assets.append(dict(path=path.relative_to(DEST).as_posix(),scan_kind="student",purpose=purpose,
                           required=True,bytes=len(raw),sha256=hashlib.sha256(raw).hexdigest(),
                           source_path=source,level_value=identity))
    source = V6 / "regions/student_level_info_regions.json"
    path = DEST / "regions/student_level_regions.json"
    path.write_text(json.dumps(json.loads(source.read_text(encoding="utf-8-sig")),indent=2)+"\n",encoding="utf-8")
    record(path,"student-level-regions","../v6/regions/student_level_info_regions.json")
    for position in (1,2):
        for digit in range(1 if position == 1 else 0,10):
            source = V6 / f"templates/studentlevel_digit{position}/{position}_{digit}.png"
            path = DEST / f"templates/student_level/{position}_{digit}.png"
            path.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,path)
            record(path,"student-level-template","../v6/"+source.relative_to(V6).as_posix(),f"{position}:{digit}")
    (DEST/"student_level_manifest.json").write_text(json.dumps(dict(version=1,
        source_version="student-level-f4-v6-2026-08-31",assets=assets),indent=2)+"\n",encoding="utf-8")
    print(f"F4: {len(assets)} recognition assets")


if __name__ == "__main__": main()
