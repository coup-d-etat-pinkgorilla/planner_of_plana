# S2 input — v6 학생 기본 인식의 v7 headless 이전

## 선행 조건

S1 결과가 master 검증을 통과한 accepted snapshot이어야 한다. 불명확하면 구현하지 말고 동일
snapshot을 요청한다.

## 목표

v6 학생 스캔에서 ID, 폼, 레벨, 성급, 스킬, 무기와 HP/ATK/DEF/HEAL을 읽는 동작을 v7
scanner session/candidate 경계 안의 headless Python 수직 슬라이스로 이전한다.

## 필수 문서

`AGENTS.md`, migration baseline, active workflow/status, next-session handoff,
`../v6/almanac/flows/student-scan.md`, `../v6/almanac/gotchas/large-module-change-safety.md`,
slave artifact handoff를 완전히 읽는다.

## 범위와 제약

- v6 behavior와 ROI를 참조하되 Qt callback/facade를 복사하지 않는다.
- 한 안정 기본 캡처와 named ROI crop set을 공유한다.
- 관측값마다 source/confidence/status evidence를 만든다.
- cancel, progress, generation, terminal contract를 보존한다.
- 장비의 고비용 생성형 level matcher와 인연 OCR은 이 세션에서 구현하지 않는다.
- 낮은 confidence 후보는 자동 commit하지 않는다.

## 완료 조건

- 실제 또는 고정 image fixture에서 ID 이외의 candidate values가 생성된다.
- DTO가 허용하는 field만 payload에 들어간다.
- field failure가 다른 확정 field를 지우지 않는다.
- focused matcher/session/contract tests와 전체 backend tests 결과를 기록한다.
- S3가 장비 matcher를 별도 교체할 수 있는 작은 port가 존재한다.

## 인계 계약

`output.md`는 artifacts가 모두 존재한 뒤 마지막에 작성한다. patch, 새 fixture, verification과
master-only 명령을 artifacts에 포함하고 크기·SHA-256을 기록한다.

