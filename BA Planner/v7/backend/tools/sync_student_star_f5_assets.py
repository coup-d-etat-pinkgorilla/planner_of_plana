"""Copy only the fixed F5 recognition slice, never v6 runtime code."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
V6 = ROOT.parent / "v6"
DEST = ROOT / "backend/assets/recognition/v1"


def main():
    assets = []
    def copy(source, relative, purpose, value=None):
        path = DEST / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(V6 / source, path)
        content = path.read_bytes()
        assets.append(dict(path=relative, scan_kind="student", purpose=purpose, required=True,
                           bytes=len(content), sha256=hashlib.sha256(content).hexdigest(),
                           source_path="../v6/" + source, star_value=value))
    copy("regions/student_star_region.json", "regions/student_star_regions.json", "student-star-regions")
    for value in range(1, 6):
        copy(f"templates/star/star_{value}.png", f"templates/student_star/star_{value}.png",
             "student-star-template", str(value))
    (DEST / "student_star_manifest.json").write_text(json.dumps(dict(version=1,
        source_version="student-star-f5-v6-2026-08-31", assets=assets), indent=2)+"\n", encoding="utf-8")
    print(f"F5: {len(assets)} recognition assets")


if __name__ == "__main__": main()
