# P10 결정론적 전술 통계 MVP 결과

## 결과

P7의 비식별 전적과 P9의 로비 노출·상대 identity·match link를 원본 변경 없이 집계하는
`tactical.v2.stats.query`를 구현했다. Python backend와 Dart process service가 같은 filter와
응답 DTO를 사용하며, 동일 state와 filter에는 동일한 정렬 결과를 반환한다.

## 제공 통계

- 공개 signature: 노출, 선택, 서로 다른 상대, 연결 전적, 공격덱 결과, 완전 방어덱 분포
- 상대: 최근 공개/완전 snapshot, 공격/방어 관측 결과 분리
- 공격덱 패턴: exact, striker, special, one-slot variant, 3·4인 core
- 표본 품질: 날짜 보유율, 방향·출처 구성, 상대 수, 중복 의심
- 필터: season, source, opponent identity, public signature, 기간, 목록 제한

비율은 실제 승률이 아닌 `observed_win_rate`로 명시하며 95% Wilson 구간을 함께 반환한다.
prediction은 관측 결과에서 제외하고 날짜 없는 기록은 기간 필터와 최근 snapshot에서 제외한다.

## 계약과 fixture

- `contracts/tactical-protocol-v2.schema.json`: stats request/response 계약
- `contracts/fixtures/tactical_protocol_v2.json`: valid/invalid wire 사례
- `contracts/fixtures/tactical_statistics_v2.json`: P7 import→P9 link 집계 기준값
- `backend/tests/test_tactical_stats_v2.py`: 필터·집계·순수 조회·schema·dispatch 검증
- `frontend/test/tactical_v2_process_e2e_test.dart`: 실제 Dart→Python 통계 조회

## 검증

- `cd backend; py -3.11 -m unittest discover -s tests -v`: 101 tests 통과
- `cd frontend; flutter analyze`: 통과
- `cd frontend; flutter test`: 216 tests 통과
- `cd frontend; flutter build windows --release`: 통과
- `codealmanac validate`, `codealmanac health`, `git diff --check`: 통과
