# 작업 결과

## 작업 정보

- 작업 ID: `p7-tactical-contract`
- 상태: `COMPLETED`
- 입력 파일: `input.md`

## 수행 내용

- P6 `tactical.*` v1을 호환 유지하고 `tactical.v2.*` evidence/import 계약을 추가했다.
- canonical student ID, slot observation state, provenance, 네 시각, opponent identity와
  defense snapshot DTO를 Python/Dart에 구현했다.
- v6 SQLite read-only preview, SHA-256 변경 감지, issue 승인, atomic commit,
  revision/idempotency와 import batch 중복 방지를 구현했다.
- 실제 v6 DB를 변경하지 않고 전체 preview해 12개 검토 대상을 구조화했다.

## 결과물

| 경로 | 설명 | 크기 | SHA-256 |
|---|---|---:|---|
| `backend/core/tactical_v2.py` | Python DTO 변환·import·저장·protocol | 28,774 | `c49c3bc86a87c8b4902e5c9456d52f879b1fcae5ac5b62b24f13b38664668f5b` |
| `contracts/tactical-protocol-v2.schema.json` | 공용 JSON Schema | 11,026 | `d1e91c681fdc600bf259a860900de2dd7fbf8b4d65709591cb4c110b57f36131` |
| `contracts/fixtures/tactical_protocol_v2.json` | 공용 valid/invalid protocol fixture | 2,894 | `02851148b68e1dfb4b81c2c90aeac9e8524ba9c1cb820543a0caf1bb76414454` |
| `contracts/fixtures/tactical_v6_import_v2.json` | 비식별 v6 parity fixture | 1,170 | `e7ce40d7b0a221727b383a98994e58e9eb1670efb817433a3fd08bda074d97f6` |
| `frontend/lib/services/tactical_v2_service.dart` | Dart immutable DTO·validator·service | 25,518 | `ca94bd5b9f6fd4821ee69ef3b6c493cd804a7c3a9a5b7c965e232cecfb4a3f9f` |
| `backend/tests/test_tactical_v2.py` | Python schema·import·atomicity tests | 8,064 | `76fadd5d40555e322eda693382b60053a2608309ff4a8db3c3c9981104683455` |
| `frontend/test/tactical_v2_service_test.dart` | Dart DTO·fixture tests | 3,174 | `46b653770056310e08b497f83c90c403419736ec02ec67959edd1d33e4d90fa0` |
| `frontend/test/tactical_v2_process_e2e_test.dart` | 실제 process preview/commit E2E | 4,485 | `781203b9192713c1edc08b8a035bbf22452830fb9d3ebc88e2def7ddec3410bb` |
| `artifacts/v6-characterization.md` | 실제 v6 DB 비식별 특성화 | 1,611 | `2d793d129774d453b623e90ffaae609fca64f4d986cc605922087efda8b303c0` |

연결 변경은 `backend/core/application_protocol_v1.py`,
`frontend/lib/services/planning_protocol_client.dart`,
`frontend/lib/services/process_app_service.dart`, `contracts/README.md`에 반영했다.

## 요구사항 확인

| 요구사항 | 결과 | 근거 |
|---|---|---|
| 실제 v6 사례 의미 보존 | PASS | 실제 DB preview와 비식별 parity fixture |
| batch/source 중복 방지 | PASS | 재commit idempotency test |
| canonical student ID | PASS | 실제 표시 이름 219종 exact mapping, wire ID 검증 |
| unknown/empty 분리 | PASS | Python schema와 Dart round-trip/semantic test |
| Python/Dart 공용 fixture | PASS | 양쪽 `tactical_protocol_v2.json` 판정 일치 |
| v6 runtime import 없음 | PASS | SQLite read-only adapter만 사용 |
| 비검토 쓰기 없음 | PASS | issue ID 전체 승인과 source fingerprint 필수 |

## 검증 내용

- `backend: py -3.11 -m unittest discover -s tests -v` — 84 PASS
- `frontend: flutter analyze` — PASS, no issues
- `frontend: flutter test` — 213 PASS
- 실제 Dart→Python preview/commit/state E2E — PASS
- 실제 v6 DB read-only preview — 10,475 matches, 2 jokbo, 12 review issues
- `frontend: flutter build windows --release` — PASS
- `codealmanac validate`, `codealmanac health`, `git diff --check` — PASS

## 미완료 사항 및 위험

- P8 로비 캡처·ROI·template matching은 의도적으로 시작하지 않았다.
- 실제 v6 DB의 검토 대상 12건은 사용자의 명시적 issue 승인 없이는 import되지 않는다.
