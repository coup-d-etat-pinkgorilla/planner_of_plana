# 작업 결과

## 작업 정보

- 작업 ID: `student-scan-v7-session-s3b-archive-validation`
- 상태: `COMPLETED`
- 입력 파일: `input.md`
- 원본: `C:\Users\brigh\Pictures\Screenshots\BA` (read-only)
- 범위: S3B 추가 실측 검증. Production 승격, S4/S5는 제외.

## 수행 내용

- PNG 194장을 조사했다. 2560x1440 179장, 1275x720 8장, 2559x1439 4장,
  1276x752 2장, 1920x1080 1장이다.
- 숫자 ROI를 무조건 읽지 않고 실제 runtime 순서인 student ID → metadata family → icon tier
  gate 뒤 binary shadow를 적용했다. 116개 exact 2560x1440 화면에서 298개 ROI가 유효했다.
- 64명 학생, Badge/Bag/Charm/Gloves/Hairpin/Hat/Necklace/Shoes/Watch 9 families,
  slot 1/2/3, tier T1-T10을 포함한다.
- 298개 ROI를 4배 확대한 opaque RGB contact sheet 7장에 예측과 함께 표시하고 전부 육안
  대조했다. 298/298 level pair가 일치했고 false positive와 fallback은 0이었다.
- 실제 값은 10/20/21/30/37/40/43/45/50/54/55/59/60/65/70이다. Position 1은 모든
  유효 tens digit 1-7을 포함하고 position 2는 0/1/3/4/5/7/9를 포함한다. Score 범위는
  0.521064-0.650632, margin 범위는 0.043264-0.117650이다.
- 원본 전체 화면은 runtime asset이나 repo fixture로 복제하지 않았다. 대신 298개 48x36
  ROI를 960x540 test-only atlas로 묶고 source filename/SHA-256, student/family/tier/slot,
  육안 ground truth와 atlas 좌표를 manifest에 보존했다. 새 회귀는 atlas 298/298을 재생한다.
- 기존 Mika/Hibiki smoke와 합치면 316/316 level pairs, 632/632 digit cells이 정확하며
  committed false positive는 0이다.
- 근거가 크게 늘었지만 position-2 digit 2/6/8, 실제 single-digit blank와 non-Lv70
  1280x720이 없다. 따라서 production 승격은 하지 않았고 `binary_production_enabled=false`,
  generated/menu fallback과 S4/S5를 그대로 유지했다.

## 결과물

| 경로 | 설명 | 크기 | SHA-256 |
|---|---|---:|---|
| `artifacts/archive_manifest.json` | 298개 육안 답지·source hash·atlas 좌표·coverage/confusion | 177,994 bytes | `226cbeaecdf2b5782f3b2ea0158a9e8b98f0f0766c5896204573e5aa26305b92` |
| `artifacts/archive_predictions_raw.json` | 194장/582 slot의 ID-family-tier gate와 raw prediction | 447,823 bytes | `4ecff92ba97299c9825bb89b9108ee66171467d61256f0a1ddd0568009dfb6ed` |
| `artifacts/benchmark_raw.json` | 기존 smoke와 archive를 결합한 316-pair benchmark | 11,519 bytes | `3bca9d8d3e187150505b1d2489360bd2c7c9f9ecf28dde0820e0cb0bcb72f5d8` |
| `artifacts/contact_sheets.zip` | 육안 검토용 4x RGB contact sheets 7장 | 1,058,551 bytes | `3bdfdff044f78a46729eb8b6dd25f433e7fc2cfd8dc75d63c1f3319915132036` |
| `artifacts/roi_atlas.png` | portable test-only 298-ROI atlas, 960x540 | 414,887 bytes | `f2e68f8003edcb8495dcc6fbeb79af01c32f57ee9116ef57abaf5d416ea72df8` |
| `artifacts/source_and_tests.zip` | analyzer, benchmark, test, fixture와 workflow/status | 539,121 bytes | `37ff7e8591fd963a71e54b44af1e2ea023c20173a15c5f4f60990c8de7bc713d` |
| `artifacts/verification.txt` | 실행 결과와 remaining production gates | 1,862 bytes | `84f69d022af48f6e24ef802b7b26c159a22a9c91f1b1a1b5a2a44919a83a3d97` |
| `artifacts/MASTER_PROMPT.md` | 수신·육안 재검토·재실행 지침 | 1,294 bytes | `8a0561c6411381d001b1bb3aa97904556d7ddb39662fb8b4af5b8a132655d358` |

## 요구사항 확인

| 요구사항 | 결과 | 근거 |
|---|---|---|
| source folder read-only 조사 | `PASS` | 194 PNG inventory; 원본 미수정 |
| runtime ID/family/tier gate 적용 | `PASS` | raw predictions 582 records |
| 독립 runtime template | `PASS` | menu templates 사용; archive crop은 runtime asset 아님 |
| 육안 ground truth | `PASS` | 7 contact sheets, 298 ROI 전수 대조 |
| archive 정확도/false positive | `PASS` | 298/298, false positive 0 |
| student/family/tier/slot coverage | `PASS` | 64 students, 9 families, T1-T10, slots 1-3 |
| portable 회귀 fixture | `PASS` | atlas + source-hash manifest + 298 replay test |
| combined S3B evidence | `PASS` | 316/316 pairs, 632/632 cells |
| actual digit 0-9 per position | `NOT_VERIFIED` | position 2의 2/6/8 없음 |
| actual single-digit blank | `NOT_VERIFIED` | archive 최소 장비 레벨 10 |
| non-Lv70 exact 1280x720 | `NOT_VERIFIED` | archive eligible ROI는 2560x1440 |
| production promotion | `NOT_VERIFIED` | remaining evidence gate 우선 |
| focused tests | `PASS` | S3B 10; combined 36 tests |
| compile/diff/Almanac | `PASS` | compile, JSON, diff check, validate, health |
| S4/S5 미변경 | `PASS` | 해당 범위 수정 없음 |

## 검증 내용

- `tests.test_student_equipment_s3b`: 10 tests passed.
- S2/S3/S3B/recognition-asset/stdio combined: 36 tests passed in 32.782s.
- Full backend: 196 tests executed; 기존 generated metadata baseline 실패만 동일하게 남았다
  (1 failure, 7 errors: Aru/Eimi/Kotama stat lookup ID와 Hoshino gift ID). 이 검증은 해당
  generated/stat/gift 파일을 수정하지 않았다.
- Python compile, JSON parse, `git diff --check`, `codealmanac validate`, `codealmanac health` 통과.
- Contact ZIP 7 entries, source ZIP 8 entries가 모두 non-empty이며 위 artifact hash와 일치한다.

## 미완료 사항 및 위험

- `MASTER_REQUIRED`: position-2 digits 2/6/8, 실제 single-digit blank, non-Lv70 exact
  1280x720을 독립 실캡처로 확보한다.
- 최소 margin 0.043264가 현재 shadow margin 0.04에 가깝다. 남은 혼동 표본 없이 production
  threshold를 고정하거나 낮추지 않는다.
- Gate가 끝날 때까지 shadow status와 generated/menu fallback을 유지한다.
- S4/S5는 작업하지 않았다.
