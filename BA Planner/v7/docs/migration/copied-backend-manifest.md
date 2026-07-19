# Copied backend manifest

2026-07-19 기준 v6에서 가져온 첫 backend slice입니다. source hash는 복사 직전
v6 파일의 SHA-256입니다.

| v6 source | mode | SHA-256 |
| --- | --- | --- |
| `core/planning.py` | exact | `3b9c57e33d975cb79aae7593f7070735f26524cf4ad889df0aa4af98b6a30c55` |
| `core/planning_calc.py` | import adapted | `9609c58378bb88073160d68134a2139a40d8270df24a6e42bdeb8586b1c366e2` |
| `core/student_meta.py` | import adapted | `6847ba2de66fda1c9b526e0074e4c1449bd58da91cb878da83e0b3a85f3f4989` |
| `core/student_meta_types.py` | exact | `890a4755d3bdc80edbd822c34e972ac0d25c845503202f77ef051ddc7d91fd66` |
| `core/student_meta_data.py` | exact/generated | `17b5cb32ab749c12f9609e5adb63e9efd03b952477bb7714363bb530509869a0` |
| `core/equipment_items.py` | exact | `b130ac42120efa1522f61461cb5b0f479267c90fad67ec66bb24d036119b8c5e` |
| `core/schale_skill_material_map.py` | exact | `b7123032b658d7d8d49d5018aa3768d91ac79260c5413fa5b498c9e2d772726c` |
| `data/planning/*` | exact | 개별 JSON은 Git diff와 parity test로 추적 |

`import adapted`는 계산이나 lookup 동작을 바꾸지 않고 v6 `core.config` 의존을
v7 `core.runtime_paths`로 교체한 것을 뜻합니다.

