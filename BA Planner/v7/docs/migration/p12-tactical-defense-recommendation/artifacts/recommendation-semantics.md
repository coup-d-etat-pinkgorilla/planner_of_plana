# P12 방어 시나리오·공격 추천 의미 규칙

## 방어 시나리오

- 같은 상대+공개 signature+시즌부터 전체 상대의 같은 공개 signature까지 6단계로 탐색한다.
- 첫 근거 단계의 표본이 `min_target_samples`보다 작을 때만 뒤 단계의 새로운 실제 snapshot을
  추가하며 단계 거리마다 0.5의 가중 할인을 적용한다.
- 날짜가 있고 `as_of` 이전이며 confirmed인 완전 방어 snapshot만 사용한다.
- 시간 가중치는 `0.5 ^ (age_hours / half_life_hours)`다.
- 반환 덱은 실제 snapshot에 있었던 완전 덱뿐이다. 숨은 슬롯 후보를 독립 조합해 새 덱을
  만들지 않는다.
- `evidence_weight_share`는 근거 가중 점유율이며 calibration 전 예측 확률이 아니다.
- 근거가 없으면 `unavailable/no_observed_full_defense_evidence`와 빈 결과를 반환한다.

## 추천 점수

추천은 관측 공격 match만 사용하며 prediction과 날짜 없는 자료를 제외한다. 각 공격덱은
다음 구성 요소와 원시 근거를 함께 반환한다.

- 관측 결과: 95% Wilson 하한
- 최근성: match별 시간 감쇠 평균
- 표본: 5건에서 포화되는 관측 수
- 상대 범위: 같은 상대 또는 예상 완전 방어 일치 비중
- 출처 품질: battle result, manual, v6 import, community report의 명시적 등급

최종 점수 가중치는 결과 0.45, 최근성 0.20, 표본 0.15, 상대 범위 0.10, 출처 0.10이다.
보유 학생은 요청 context이며 저장된 관측을 바꾸지 않는다. 필요한 canonical 학생과 부족 학생을
함께 반환한다.

## 저장 경계

- `recommend.query`는 순수 조회다.
- `recommend.save`만 파생 결과를 독립 `predictions` 컬렉션에 저장한다.
- prediction record는 생성 근거 state revision, `as_of`, filter와 전체 결과를 가진다.
- prediction 저장·조회는 관측 `snapshots`, match 또는 lobby history를 바꾸지 않는다.
