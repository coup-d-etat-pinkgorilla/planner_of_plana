# P8 전술대항전 로비 스캐너 결과

## 결과

사용자가 지정한 `스크린샷 2026-07-07 201820.png`를 2560×1440 기준 fixture로 고정해
현재 순위 8과 상대 5·6·7위 세 행을 한 번의 review candidate로 읽는 수직 슬라이스를
구현했다.

| 행 | 순위 | 이름 | striker 1 | special 1 | special 2 |
|---:|---:|---|---|---|---|
| 0 | 5 | 마리나9데스티니 | `tsubaki` | `hibiki` | `michiru_dress` |
| 1 | 6 | 우그웃 | `eimi` | `michiru_dress` | `yakumo` |
| 2 | 7 | 메라조마 | `tsubaki` | `michiru_dress` | `hibiki` |

## 산출물

- `artifacts/tactical_lobby_2560x1440.png`: 승인된 실제 기준 프레임
- `artifacts/roi-characterization.md`: 픽셀 ROI와 ratio 투영 근거
- `backend/assets/recognition/v1/regions/tactical_lobby_regions.json`: runtime ROI profile
- `backend/assets/recognition/v1/templates/tactical_lobby/`: rank/name/portrait template
- `backend/core/tactical_lobby_scanner.py`: matcher와 strict review DTO
- `frontend/lib/services/tactical_lobby_scanner_service.dart`: typed Dart 경계
- `contracts/scanner-protocol-v1.schema.json`: `tactical_lobby` session/candidate 계약

## 동작 경계

- 2560×1440, 1920×1080, 1280×720 ratio projection 지원
- 같은 의미의 화면은 해상도와 무관하게 같은 deterministic `refresh_generation` 생성
- 실제 안정 영역 픽셀은 별도 `screen_hash`로 기록
- 낮은 score/margin, 부분 가림, 미등록·유사 이름은 제안값만 남기고 검토 요구
- 공개되지 않은 striker 2~4번은 `unknown`; 실제 빈 슬롯으로 추정하지 않음
- P5 start/cancel/event/snapshot/review 재사용
- P9 전 tactical repository commit은 `persistence_deferred`로 차단

## 검증

- `cd backend; py -3.11 -m unittest discover -s tests -v`: 90 tests 통과
- `cd frontend; flutter analyze`: 통과
- `cd frontend; flutter test test/tactical_lobby_scanner_service_test.dart`: 2 tests 통과
- `cd frontend; flutter test`: 215 tests 통과
- `cd frontend; flutter build windows --release`: 통과
- `codealmanac validate`, `codealmanac health`, `git diff --check`: 통과
