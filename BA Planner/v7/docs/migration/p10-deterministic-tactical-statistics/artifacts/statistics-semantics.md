# P10 전술 통계 의미와 집계 규칙

## 모집단

- `refresh_count`: 필터를 통과한 로비 새로고침 수. 상대 또는 공개 signature 필터가 있으면
  해당 후보를 실제로 포함한 새로고침만 센다.
- `exposure_count`: 로비 후보 행 수. 같은 profile의 같은 refresh generation 재저장은 P9에서
  막으므로 중복 노출로 증가하지 않는다.
- `selected_count`: 선택 시각이 저장된 후보 수.
- `linked_match_count`: 필터를 통과한 후보와 관측 match가 연결된 수.
- `match_count`: 관측 match 수. `prediction` 출처는 항상 제외한다.

필터는 분자와 분모에 함께 적용한다. 기간 필터가 있으면 날짜 없는 match는 포함하지 않는다.

## 결과 표현

- 비율 이름은 `observed_win_rate`로 고정한다.
- 분자는 관측된 `win`, 분모는 같은 행의 관측 match 수다.
- `unknown` 결과는 match 수에는 포함하지만 승·패 어느 쪽에도 더하지 않는다.
- 95% Wilson 구간을 함께 제공하며 표본이 0이면 비율과 구간은 `null`이다.
- 공격 match와 방어 match의 결과는 별도 필드로 반환한다. 공격덱 패턴에는 공격 match만 쓴다.

## 패턴과 이력

- 공개 signature: 노출·선택·연결 수, 서로 다른 상대 수, 연결된 공격덱 결과와 완전 방어덱 분포.
- 상대: 최근 공개 snapshot과 날짜가 있는 최근 완전 snapshot, 공격·방어 결과 분리.
- 공격덱: 완전 동일, striker 동일, special 동일, 한 슬롯 wildcard 변형, 3·4인 core.
- 모든 목록은 횟수 내림차순과 안정된 signature 오름차순으로 정렬해 같은 입력에 같은 결과를 낸다.

## 품질 지표

날짜 보유·미보유 match 수, 날짜 보유율, 상대 수, 공격·방어 수, 출처 구성과 동일 방향·상대·
시각·결과·덱·출처 fingerprint의 중복 의심 수를 제공한다. 통계 조회는 저장 파일을 쓰지 않는다.
