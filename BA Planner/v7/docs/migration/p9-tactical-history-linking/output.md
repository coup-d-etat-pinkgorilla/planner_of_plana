# P9 상대 Identity·방어 Snapshot·전적 연결 결과

## 결과

P8 로비 review candidate를 전술 v2 저장소의 상대 이력으로 연결했다. 로비를 보았지만
전투하지 않은 행도 노출 관측으로 남으며, 전투가 확인된 행은 공개 snapshot과 기존 완전
방어 snapshot을 상대 identity와 candidate→match link로 함께 조회할 수 있다.

## 저장 모델

- `lobby_scans`: 관측 시각, season, map, 현재 순위, refresh generation, screen hash, ROI
- `lobby_candidates`: 표시 행, 상대 identity, 상대 순위, 공개 signature, 선택 시각, match link
- `opponents`: 현재 이름, alias, name template ID, 최초·최종 관측
- `snapshots`: `lobby_scan` 공개 덱과 `v6_import`/`battle_result` 완전 덱의 분리 provenance

## 연결 정책

- 동일 refresh generation은 profile 안에서 하나의 노출 표본
- 상대 이름 exact alias 또는 사용자 identity binding
- 자동 연결은 선택된 candidate 가운데 상대·공개 signature·season·6시간 범위를 만족하는
  후보가 정확히 하나일 때만 수행
- 복수 후보는 `ambiguous`/`review_required`; 사용자가 수동 연결 또는 재연결 가능
- unlink는 match 원본과 snapshot을 삭제하지 않음
- lobby 삭제는 해당 scan에서 생성된 candidate와 공개 snapshot만 cascade 삭제
- prediction은 이 저장 경계에 입력할 수 없음

## 프로토콜

- `tactical.v2.lobby.commit`
- `tactical.v2.candidate.select`
- `tactical.v2.match.link`
- `tactical.v2.lobby.delete`
- `tactical.v2.opponent.alias`

## 검증

- `cd backend; py -3.11 -m unittest discover -s tests -v`: 95 tests 통과
- `cd frontend; flutter analyze`: 통과
- `cd frontend; flutter test`: 216 tests 통과
- 실제 Dart→Python P7 import→P9 lobby 저장·선택·자동 연결·복원 E2E 통과
- `cd frontend; flutter build windows --release`: 통과
- `codealmanac validate`, `codealmanac health`, `git diff --check`: 통과
