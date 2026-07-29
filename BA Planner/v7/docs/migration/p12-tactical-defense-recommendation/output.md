# P12 예상 방어덱과 설명 가능한 추천 결과

## 결과

관측된 완전 방어 snapshot만으로 가능한 방어 시나리오와 공격덱 근거를 반환하는
`tactical.v2.recommend.query`를 구현했다. 계산 결과는 순수 조회이며, 사용자가 저장하는 경우에만
`recommend.save/get`을 통해 관측 history와 분리된 prediction record가 생성된다.

## 제공 기능

- 6단계 상대·공개 signature·시즌·rank condition 계층 탐색
- 표본 부족 시 실제 넓은 단계 관측을 사용한 명시적 shrinkage
- 완전 방어 TOP-K와 대상 상대 점유율, 마지막 확인과 근거 snapshot
- 숨은 슬롯별 보조 후보와 공개 signature 변형 가능성
- Wilson 결과·최근성·표본·상대 범위·출처를 분해한 공격덱 추천 점수
- 요청된 보유 학생에 대한 적용 가능 여부와 부족 학생
- 시간순 TOP-1/TOP-K/숨은 슬롯/Brier/log loss backtest
- prediction의 별도 저장, idempotent retry와 재시작 복원

근거가 없으면 생성형 fallback 없이 `no_observed_full_defense_evidence`를 반환한다. 현재 독립
fixture의 calibration gate는 실패 상태이므로 정밀 확률을 노출하지 않고 근거 점유율과
low/medium/high 등급만 기본 제공한다.

## 계약과 fixture

- `contracts/tactical-protocol-v2.schema.json`: query/save/get과 prediction state 계약
- `contracts/fixtures/tactical_protocol_v2.json`: Python/Dart 공용 wire 사례
- `contracts/fixtures/tactical_recommendation_v2.json`: 계층 fallback·소유 적용·gate 기준값
- `backend/tests/test_tactical_recommend_v2.py`: 시나리오·추천·backtest·저장 분리 검증
- `frontend/test/tactical_v2_process_e2e_test.dart`: 실제 Dart→Python P12 E2E

## 검증

- `cd backend; py -3.11 -m unittest discover -s tests -v`: 112 tests 통과
- `cd frontend; flutter analyze`: 통과
- `cd frontend; flutter test`: 216 tests 통과
- `cd frontend; flutter build windows --release`: 통과
- `codealmanac validate`, `codealmanac health`, `git diff --check`: 통과
