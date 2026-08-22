# 작업 결과

## 작업 정보

- 작업 ID: `student-scan-v7-session-s3b-generated-glyph`
- 상태: `COMPLETED`
- 입력 파일: `input.md`
- 범위: S3B 생성형 text-layer glyph 구현·shadow 통합·frozen benchmark
- 제외: production enablement, fallback 억제, S4/S5

## 수행 내용

- v6의 장비 카드 생성 방식을 v7 소유 코드에서 사용하되 background와 equipment icon을
  binary template에서 제거하고 transparent text layer만 남겼다.
- 흰 fill, 1px 남색 outline, -0.25 shear와 기존 level ROI transform을 보존했다. 실제 화면은
  near-white fill을 locality seed로 사용하고 digit 높이에 못 미치는 card/icon component를
  제거한다.
- 실제 한 자리 숫자를 고정 두 cell로 나누지 않고 전체 level string을 40x28 integer bitset으로
  정규화한다. Outline-only, fill+outline, fill-only와 기존 장비-menu binary를 비교했다.
- 새 6개 source screenshot의 SHA-256을 확인하고 18개 48x36 ROI를 432x72 portable test-only
  atlas로 만들었다. T1 1/8/9, T2 12/16/18, 세 학생과 세 슬롯을 포함한다.
- Frozen 334 pair에서 generated fill이 top-1 334/334, 현 gate accepted 334/334, accepted wrong 0,
  fallback 0이었다. 최소 score 0.616097, 최소 margin 0.065519다.
- Fill은 benchmark lead일 뿐 production-selected variant가 아니다. Threshold를 바꾸지 않았고
  frozen 334를 calibration에 사용하지 않는다.
- Runtime adapter에 `equipment_generated_binary_shadow` evidence를 추가했다. Shadow 결과는
  confirmed payload에 들어가지 않고 기존 small-ROI generated 및 unresolved-only one-menu
  fallback을 줄이지 않는다.

## 결과물

| 경로 | 설명 | 크기 | SHA-256 |
|---|---|---:|---|
| `artifacts/benchmark_raw.json` | frozen 334 pair의 4-way confusion·score·성능 원자료 | 7,073 bytes | `b704d34481345f766c413bbe56afa7792491d5f06f277429b480c680eef980ba` |
| `artifacts/generated_glyph_source_and_fixtures.zip` | source, tests, portable atlas/manifest, benchmark, workflow/status | 168,018 bytes | `1b697b483de916fc1b0d2771c796ccb2af626071bdbe43003ef5ac11cb15b7d5` |
| `artifacts/MASTER_PROMPT.md` | master 재검증 명령과 production 금지 조건 | 949 bytes | `d74504f7e1d90556821eaa97b3bffb12cfbab049f4617088d9cfec87a69868ee` |
| `artifacts/verification.txt` | 구현·정확도·성능·전체 suite 결과와 remaining gates | 2,112 bytes | `3954a3a588f8b7643879a0660cc6722b4fcb60696500a49728e6b8e4902a873d` |

## 요구사항 확인

| 요구사항 | 결과 | 근거 |
|---|---|---|
| v6 생성형 숫자 layer 사용 | `PASS` | background/icon 제외, font/fill/outline/shear/quad 보존 |
| outline 제거 여부 검증 | `PASS` | outline, fill+outline, fill 독립 비교 |
| 실제 한 자리 처리 | `PASS` | T1 1/8/9 9 ROI, generated fill 9/9 |
| 실제 두 자리 2/6/8 포함 | `PASS` | T2 12/16/18 9 ROI, generated fill 9/9 |
| 기존 frozen 회귀 | `PASS` | 총 334/334, accepted wrong 0 |
| portable fixture | `PASS` | source hash manifest + 432x72 atlas + replay test |
| bounded memory/full canvas 금지 | `PASS` | fill 70/9,800 bytes, full-size canvas 0 |
| runtime shadow-only | `PASS` | 별도 evidence; payload/fallback 미변경 |
| production variant/threshold | `NOT_VERIFIED` | 독립 calibration 없음 |
| non-Lv70 exact 1280x720 | `NOT_VERIFIED` | 추가 probe는 2560x1440 |
| Niko/Kurumi end-to-end | `NOT_VERIFIED` | student recognition asset 선행 필요 |
| S4/S5 미변경 | `PASS` | 범위 외 파일/동작 미변경 |

## 검증 내용

- `tests.test_student_equipment_s3b`: 12 tests passed in 10.647s.
- S2/S3/S3B/recognition-asset/stdio combined: 38 tests passed in 64.971s.
- Full backend: 198 tests in 111.347s; 기존 baseline과 동일한 1 failure + 7 errors만 존재한다.
- Known baseline: Aru/Eimi/Kotama stat data ID 누락 7건, Hoshino gift assertion 1건.
- Python compile와 JSON parse 통과.
- `codealmanac validate`, `codealmanac health` 통과.
- ZIP 11 entries가 모두 non-empty이며 fixture atlas는 manifest SHA-256과 일치한다.

## 미완료 사항 및 위험

- `MASTER_REQUIRED`: frozen 334와 분리된 독립 calibration set으로 variant/threshold를 결정한다.
- `MASTER_REQUIRED`: non-Lv70 exact 1280x720을 반복 확보한다.
- `MASTER_REQUIRED`: Niko/Kurumi student recognition asset 뒤 새 18 ROI를 end-to-end 재생한다.
- `MASTER_REQUIRED`: fill bank cold prepare 173.055ms를 build-time compact asset 또는 동등한
  방법으로 낮추고 cold/warm을 다시 측정한다.
- `MASTER_REQUIRED`: production 후보 승인 뒤 fallback/menu-call 실제 감소량을 측정한다.
- 위 gate와 master 명시 승인이 끝날 때까지 `generated_binary_production_enabled=false`를 유지한다.
