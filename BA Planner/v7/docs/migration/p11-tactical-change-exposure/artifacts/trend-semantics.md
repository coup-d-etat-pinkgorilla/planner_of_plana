# P11 변경·신선도·노출 의미 규칙

## 변경 시계열

- 공개 signature 변경은 `interval_start`의 마지막 이전 관측과 `interval_end`의 최초 새 관측
  사이에 발생한 것으로만 표현한다. 그 사이의 단일 확정 시각을 만들지 않는다.
- 같은 signature의 연속 관측은 하나의 run이다. 다른 signature 뒤 다시 나타나면 재사용으로
  기록한다.
- 완전 방어덱 변경은 두 전투 확인 사이 공개 signature 변경 관측이 없을 때만
  `full_defense_while_public_stable`로 분류한다.
- 날짜 없는 전적과 snapshot은 변경 구간, 유지 기간과 신선도 계산에서 제외한다.

## 노출과 funnel

- 표본 단위는 확정된 refresh generation이다. 중복 generation을 방어적으로 한 번만 센다.
- rank difference는 `상대 순위 - 현재 사용자 순위`다.
- 노출, 선택, 연결된 공격 전투, 승패 결과는 서로 다른 count와 rate로 반환한다.
- 전투하지 않은 후보는 노출·선택에는 남지만 관측 승률 분모에는 들어가지 않는다.
- 연속 잔류는 같은 season·map에서 인접한 두 refresh 사이 같은 상대가 다시 나타난 경우다.
- 결과는 이 사용자에게 실제 제시된 선택지이며 서버 전체 메타 점유율이 아니다.

## 신선도

- 요청의 `as_of` 이후 관측은 제외한다.
- 공격 근거별 마지막 전투·성공·실패와 최신 공개 관측/변경 이후 검증 여부를 반환한다.
- `freshness_weight = 0.5 ^ (age_hours / stale_after_hours)`로 계산한다.
- 임계시간 초과, 최신 공개 이후 미검증 또는 최신 변경 이후 미검증이면 `stale`이다.
- prediction과 방어 match는 공격 근거 신선도에 사용하지 않는다.
