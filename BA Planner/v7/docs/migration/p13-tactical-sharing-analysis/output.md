# P13 익명 공유와 고급 분석 구현 결과

## 구현 결과

- `tactical.v2.share.state.get/prepare/import/withdraw/analytics.query`를 추가했다.
- 공유 저장소를 관측·예측 저장소와 분리하고 revision, idempotency, atomic write, tombstone, aggregate cache 검증을 적용했다.
- 실제 관측 공격 match와 확정된 lobby link·전투 후 방어 snapshot이 모두 있을 때만 redacted payload를 생성한다.
- 실제 경기 시각, 공유 시각, attempt session/index, 범위 제한 익명 ID, season/patch/map/rank condition, source identity를 보존한다.
- 독립 contributor/opponent 최소 표본, 출처 집중도, 첫 시도와 첫 성공 시도 수, discoverer 대 이후 사용자, 관측 수명, 변경 후 재검증, one-slot substitution을 결정론적으로 집계한다.
- Python과 Dart의 별도 v1 schema/fixture, typed service와 실제 Dart→Python process E2E를 추가했다.

## 개인정보 경계

- 상대 표시 이름, 로컬 identity/match/snapshot ID, name ROI, screen hash, screenshot, note와 prediction은 공유 payload에 포함되지 않는다.
- contributor와 상대 익명 ID는 명시된 공유 범위에 한정한다. 상대 ID는 시즌도 hash 입력에 포함하여 장기 재사용을 차단한다.
- 상세 분석 결과는 독립 contributor와 opponent 최소 표본을 모두 통과해야 하며 원시 익명 ID도 반환하지 않는다.
- 철회된 share/source는 tombstone으로 재수집을 막고 캐시를 즉시 재구축한다.

## 검증

- P13 Python 단위 테스트: redaction·동의·중복·idempotent retry·철회·재유입 차단·캐시 corruption·시도 통계·소표본 억제·one-slot 비교·pure query·schema/application dispatch.
- Flutter fixture 검증과 실제 process E2E: prepare → import → analytics → withdraw → restore.
- 전체 회귀 명령과 결과는 workflow status에 기록한다.
