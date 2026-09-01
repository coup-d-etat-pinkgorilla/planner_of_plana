"""Fixed v6 recognition assets for F6; no runtime v6 dependency."""
import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[2]
V6 = ROOT.parent / "v6"
DEST = ROOT / "backend/assets/recognition/v1"


def main():
    assets = []
    def record(path, purpose, source, value=None):
        data = path.read_bytes()
        assets.append(dict(path=path.relative_to(DEST).as_posix(), scan_kind="student", purpose=purpose,
            required=True, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), source_path=source,
            skill_value=value))
    regions = json.loads((V6/"regions/student_skillmenu_regions.json").read_text(encoding="utf-8-sig"))
    basic = json.loads((V6/"regions/student_data_regions.json").read_text(encoding="utf-8-sig"))
    regions["skill_menu_button"] = basic["student_data"]["skill_menu_button"]
    path = DEST/"regions/student_skill_regions.json"
    path.write_text(json.dumps(regions,indent=2)+"\n",encoding="utf-8")
    record(path,"student-skill-regions","../v6/regions/student_skillmenu_regions.json + student_data_regions.json:skill_menu_button")
    for field,folder,prefix,maximum in (("ex_skill","EX_Skill","EX_Skill",5),("skill1","Skill1","Skill_1",10),
                                      ("skill2","Skill2","Skill_2",10),("skill3","Skill3","Skill_3",10)):
        for label in [str(n) for n in range(1,maximum+1)]+(["locked"] if field in {"skill2","skill3"} else []):
            source = f"templates/{folder}/{prefix}_{label}.png"
            path = DEST/f"templates/student_skill/{field}/{label}.png"
            path.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(V6/source,path)
            record(path,"student-skill-template","../v6/"+source,f"{field}:{label}")
    for label in ("true","false"):
        source = f"templates/skillcheck/{label}.png"
        path = DEST/f"templates/student_skill/check/{label}.png"
        path.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(V6/source,path)
        record(path,"student-skill-check-template","../v6/"+source,label)
    (DEST/"student_skill_manifest.json").write_text(json.dumps(dict(version=1,
        source_version="student-skill-f6-v6-2026-08-31",assets=assets),indent=2)+"\n",encoding="utf-8")
    print(f"F6: {len(assets)} recognition assets")


if __name__ == "__main__": main()
