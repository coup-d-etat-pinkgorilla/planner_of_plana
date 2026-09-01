"""Pin visually checked native1280 F5 frames as development regression, not holdout."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "backend/tests/fixtures/student_star_f5_live"


def main():
    DEST.mkdir(parents=True,exist_ok=True)
    assets = []
    for student,star in (("mika",5),("miyu",3)):
        for filename,state in (("opened","star"),("returned","basic")):
            source = f"debug/scanner_f5_live/{student}-star/{filename}.png"
            path = DEST/f"{student}-{state}.png"
            shutil.copy2(ROOT/source,path)
            assets.append(dict(file=path.name,source=source,state=state,student_star=star,
                               sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (DEST/"manifest.json").write_text(json.dumps(dict(version=1,actual_client_size=[1280,720],
        partition="development_regression_not_holdout_or_runtime_learning",assets=assets),indent=2)+"\n",encoding="utf-8")
    print(f"F5: {len(assets)} native1280 development frames")


if __name__ == "__main__": main()
