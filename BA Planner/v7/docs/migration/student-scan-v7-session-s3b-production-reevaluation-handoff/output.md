# 작업 결과

## 작업 정보

- 작업 ID: `student-scan-v7-session-s3b-production-reevaluation`
- 상태: `COMPLETED`
- 입력 파일: `input.md`
- 범위: Kurumi/Niko template 및 추가 1280급 자료를 이용한 S3B production 재평가
- 제외: production enablement, fallback 억제, S4/S5

## 수행 내용

- Kurumi/Niko template의 manifest 등록·무결성과 별도 T2 repeat의 student identity를 확인했다.
- 기존 6장/18 ROI를 학생→metadata family→tier→generated glyph 순서로 재생했다.
- BA archive의 저해상도 PNG를 해상도별로 다시 분류하고 1275x720 8장과 1276x752 2장을
  육안 답지와 함께 세 generated variant로 재생했다.
- 기존 frozen 334와 결합 회귀를 다시 실행하고 cold/warm 비용을 재측정했다.
- Production 승격을 거부했다. 1275x720 Aris T9 Lv65 세 슬롯이 모든 variant에서 Lv6으로
  확정 오판독되고, Kurumi Necklace T2 tier가 한 슬롯에서 거부되기 때문이다.
- Production flag와 fallback은 변경하지 않았고 S4/S5는 건드리지 않았다.

## 결과물

| 경로 | 설명 | 크기 | SHA-256 |
|---|---|---:|---|
| `artifacts/client_1275x720_raw.json` | 1275x720/1276x752 실제 analyzer 원자료 | 40,634 bytes | `39a1b253702c4eb8b069d14b3e87be0bc2b0d133a3b4e2953de5ac1252f7d4ab` |
| `artifacts/client_1275x720_roi_review.png` | 저해상도 tier-eligible ROI와 menu/fill 결과 시트 | 53,773 bytes | `dc4d2b1ba80967581de1839bec2b2f6f8a3b8ab85cc937230ccaeb49b94a9058` |
| `artifacts/frozen_334_benchmark.json` | 재실행한 frozen 334 confusion·성능 | 7,193 bytes | `9983c9a142ae58ca05d8e1502de135f4a4c946a8532c38705e9d9b140820054f` |
| `artifacts/MASTER_PROMPT.md` | master 재검증 명령과 production 금지 조건 | 1,110 bytes | `892313afa992581f2a6ce686e77d460ac344fba0764ae6b64dc9b1fe3bfb90e7` |
| `artifacts/promotion_2560_end_to_end_raw.json` | Kurumi/Niko 포함 6장 end-to-end 원자료 | 34,860 bytes | `a5a058ea7474afccd19f686627a87d8ecb049c2f32ff78b42909cf7e8c1346e5` |
| `artifacts/promotion_2560_roi_review.png` | 2560 promotion ROI 판독 시트 | 65,377 bytes | `b8cb8524ad30cc23d3d45d9b33d4a77d53d2bce48851b5904ce7d653e99d113d` |
| `artifacts/reevaluation_summary.json` | 판정·핵심 수치·남은 gate 요약 | 2,426 bytes | `8a95cf62b61bc18a8196e71811430564626cd5bf87604a91366d0792e1034250` |
| `artifacts/verification.txt` | 검증 명령·결과·위험과 master 후속 | 2,614 bytes | `4d69e8995f1459075e8e63ddcbce1aff7d216157c90aafbb6efce94279532c97` |

## 요구사항 확인

| 요구사항 | 결과 | 근거 |
|---|---|---|
| Kurumi/Niko template 등록·무결성 | `PASS` | asset/stdio 6/6; manifest hash 확인 |
| Kurumi/Niko 별도 repeat student gate | `PASS` | Niko 0.989095/0.165600, Kurumi 0.985231/0.169860 |
| 6장 promotion student identity | `PASS` | 6/6 정확 |
| 6장 promotion tier→level end-to-end | `FAIL` | 17/18; Kurumi slot 3 T2 tier margin 0.009946 |
| 추가 exact 1280x720 | `FAIL` | exact 1280x720은 0장; client-area 1275x720 8장 |
| independent non-Lv70 low-resolution 판독 | `FAIL` | 11개 중 정답 6, 오답 3, fallback 2 |
| accepted false positive 0 | `FAIL` | Aris Lv65→Lv6 accepted wrong 3건 |
| blank/non-level false positive 0 | `PASS` | tier-eligible 세 crop 모두 fallback |
| frozen 334 회귀 | `PASS` | generated fill 334/334, wrong 0, fallback 0 |
| 결합 회귀 | `PASS` | 38/38 |
| production 승격 | `FAIL` | 저해상도 오판독·tier miss·cold gate 존재 |
| production/S4/S5 미변경 | `PASS` | flag/fallback/후속 단계 변경 없음 |

## 검증 내용

- `tests.test_student_equipment_s3b`: 12/12 PASS.
- `tests.test_recognition_assets tests.test_scanner_stdio_transport`: 6/6 PASS.
- S2/S3/S3B/recognition-asset/stdio combined: 38/38 PASS in 48.352s.
- Frozen generated fill: 334/334, accepted wrong 0, fallback 0.
- Python AST와 모든 handoff JSON parse 통과.
- `codealmanac validate`, `codealmanac health` 통과.
- 변경한 진단 도구와 본 handoff 대상 scoped `git diff --check` 통과.
- 결과물 8개가 모두 존재하고 크기가 0보다 크며 위 SHA-256과 일치한다.

## 미완료 사항 및 위험

- `MASTER_REQUIRED`: 1275x720에서 두 digit을 모두 보존하고 Lv65/Lv6 portable 회귀를 추가한다.
- `MASTER_REQUIRED`: Kurumi Necklace T2 tier rejection을 해결한다.
- `MASTER_REQUIRED`: calibration과 frozen validation을 분리한다.
- `MASTER_REQUIRED`: generated fill cold prepare를 낮추고 다시 측정한다.
- `MASTER_REQUIRED`: 새 production 후보가 생긴 뒤 fallback/menu-call 감소량을 측정한다.
- `MASTER_REQUIRED`: 위 gate 통과 뒤에만 production을 명시 승인한다.
- 그 전까지 `generated_binary_production_enabled=false`를 유지하고 S4/S5를 시작하지 않는다.
