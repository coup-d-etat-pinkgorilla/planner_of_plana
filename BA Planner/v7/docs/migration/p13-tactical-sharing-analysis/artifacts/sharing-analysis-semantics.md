# P13 익명 공유·분석 의미 규칙

## 저장 경계

- 공유는 명시적 opt-in 이후 로컬에서 prepare하며 외부 전송은 이 단계의 범위가 아니다.
- 공유 레코드는 `tactical-share/{profile_id}.v1.json`에 저장한다. 관측 match/snapshot과 저장 prediction이 있는 `tactical/{profile_id}.v2.json`과 물리적으로 분리한다.
- 공유 payload의 필드 집합은 고정되어 있다. 상대 표시 이름, 로컬 상대·match·snapshot ID, name ROI, screen hash, screenshot, note, prediction은 허용하지 않는다.
- 원본 매체 포함 동의는 지원하지 않는다. `include_original_media`는 반드시 `false`이다.

## 익명 ID와 중복 제거

- `contributor_id`는 설치와 공유 범위에 한정하여 클라이언트가 발급하고 명시적 동의의 ID·범위와 정확히 일치해야 한다.
- `anonymous_opponent_id`는 공유 범위·시즌·로컬 상대 ID를 입력으로 만든 범위 제한 hash다. 시즌 또는 공유 범위가 달라지면 재사용되지 않는다.
- `defense_snapshot_id`와 `source_identity`도 범위 제한 hash로 변환한다.
- `(scope_id, contributor_id, source_identity)`가 같은 자료는 별도 `share_id`로 재전송되어도 한 번만 수용한다.
- 철회 시 활성 레코드를 제거하고 최소 tombstone을 남긴다. 동일 share/source의 재유입을 막고 aggregate cache를 같은 atomic write에서 재구축한다.

## 집계와 표본 보호

- match 수, 독립 contributor 수, 익명 opponent 수, attempt session 수를 서로 다른 모집단 값으로 반환한다.
- 그룹이 요청한 최소 독립 contributor 수와 최소 독립 opponent 수 중 하나라도 충족하지 못하면 상세 결과를 숨기고 억제 건수만 반환한다.
- 결과에는 contributor ID와 opponent ID를 반환하지 않는다. `raw_identifiers_returned=false`를 계약으로 노출한다.
- 승률은 공유에 동의한 실제 관측 경기의 `observed_win_rate`이며 전체 사용자 또는 미래 승률 추정치가 아니다.

## 시도·재현성 지표

- attempt는 `(contributor_id, attempt_session_id)`별로 묶고 `attempt_index`로 정렬한다.
- 첫 시도 승률, 첫 성공까지 평균·중앙 시도 수, 1·2·3회 이내 누적 성공률을 계산한다.
- 최초 관측 contributor와 이후 독립 contributor의 관측 결과를 ID 없이 분리한다.
- contributor 최대 점유율, 최초·최근 실제 경기 시각, 관측 수명, 출처별 건수를 반환한다.
- 동일 조건·동일 방어덱에서 공격덱 한 자리만 다른 두 그룹이 모두 최소 표본을 통과한 경우에만 one-slot substitution 비교를 반환한다.
- 같은 익명 상대의 방어 snapshot/signature 변경과 이후 실제 결과 관측을 재검증 건수로 집계한다.

## 비범위

- 서버 업로드, 계정 연동, 원본 screenshot 공유와 중앙 삭제 API는 구현하지 않는다.
- 머신러닝은 P13 완료 조건이 아니며 `implemented=false`로 명시한다.
