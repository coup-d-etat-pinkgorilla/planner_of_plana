from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "backend" / "tests" / "fixtures" / "student_weapon_s2w_v6_parity.json"
SCREENSHOT_ROOT = Path.home() / "Pictures" / "Screenshots" / "BA"
OUTPUT = FIXTURE.parent / "student_weapon_s2w_v6_parity" / "state"


def export() -> int:
    payload = json.loads(FIXTURE.read_text(encoding="utf-8"))
    region = payload["basic_state_region"]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    count = 0
    for record in payload["state_visual_truth"]:
        source = SCREENSHOT_ROOT / record["source_file"]
        content = source.read_bytes()
        digest = hashlib.sha256(content).hexdigest()
        if digest != record["sha256"]:
            raise ValueError(f"source hash mismatch: {source}")
        with Image.open(source) as frame:
            crop = frame.crop((
                round(frame.width * float(region["x1"])),
                round(frame.height * float(region["y1"])),
                round(frame.width * float(region["x2"])),
                round(frame.height * float(region["y2"])),
            )).convert("RGB")
        destination = OUTPUT / f"{record['expected']}.png"
        crop.save(destination)
        crop.close()
        record["fixture_crop"] = destination.relative_to(FIXTURE.parent).as_posix()
        record["fixture_crop_sha256"] = hashlib.sha256(destination.read_bytes()).hexdigest()
        count += 1
    FIXTURE.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return count


if __name__ == "__main__":
    print(export())
