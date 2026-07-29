# P11 방어 변경·신선도·노출 분석 결과

## 결과

반복 로비 관측을 P10 원시 통계와 분리해 분석하는 `tactical.v2.trends.query`를 구현했다.
조회 기준 시각을 요청에 고정하므로 같은 state와 filter에서 변경 구간, funnel과 신선도 결과가
재현된다.

## 제공 분석

- 공개 signature 변경 관측 구간, 유지 run과 과거 signature 재사용
- 공개 signature 유지 중 확인된 완전 방어덱 변경
- 새로고침당 상대 등장과 같은 season·map의 연속 refresh 잔류
- 상대·공개 signature·rank difference별 노출률, 선택률과 관측 승률
- 노출→선택→전투→결과 funnel
- 마지막 전투·성공·실패, 최신 공개/변경 이후 검증, 반감기형 신선도 가중치와 구식 경고

결과 문구는 `observed_exposure_rate`, `observed_selection_rate`, `observed_win_rate`로 분리한다.
노출은 이 사용자에게 표시된 선택지이며 서버 전체 메타 점유율이 아님을 응답에 포함한다.

## 계약과 fixture

- `contracts/tactical-protocol-v2.schema.json`: trends request/response 계약
- `contracts/fixtures/tactical_protocol_v2.json`: Python/Dart 공용 valid/invalid wire 사례
- `contracts/fixtures/tactical_trends_v2.json`: A→A→B→A 반복 관측 독립 기대값
- `backend/tests/test_tactical_trends_v2.py`: 변경·재사용·잔류·funnel·filter·순수 조회 검증
- `frontend/test/tactical_v2_process_e2e_test.dart`: 실제 Dart→Python trend 조회

## 검증

- `cd backend; py -3.11 -m unittest discover -s tests -v`: 106 tests 통과
- `cd frontend; flutter analyze`: 통과
- `cd frontend; flutter test`: 216 tests 통과
- `cd frontend; flutter build windows --release`: 통과
- `codealmanac validate`, `codealmanac health`, `git diff --check`: 통과
