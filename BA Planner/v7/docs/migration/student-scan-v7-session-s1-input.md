# S1 input — 학생 스탯 정적 DTO와 순수 계산 코어

## 목표

SchaleDB 학생/장비 원천값을 v7 전용 versioned DTO로 정규화하고, scanner와 Flutter 없이
HP/ATK/DEF/HEAL을 계산하는 순수 Python 수직 슬라이스를 구현한다.

## 먼저 읽을 문서

- `AGENTS.md`
- `README.md`
- `docs/migration/v6-knowledge-baseline.md`
- `almanac/workflows/p0-p6-workflow-status.md`
- `almanac/workflows/student-scan-validation-workflow.md`
- `docs/migration/student-scan-v7-next-session-handoff-2026-08-20.md`
- `almanac/workflows/slave-artifact-handoff.md`

## 범위

- level/star base interpolation과 Schale 반올림 순서
- equipment tier/current-level interpolation
- unique weapon, relationship, alternate outfit, favorite gear, potential contribution
- 필수 dependency가 빠진 경우를 0과 구별하는 결과 타입
- compact static DTO 생성/동기화 경계와 parity fixtures
- Python focused tests와 전체 backend regression

## 제외

- scanner 캡처/입력/matcher
- protocol candidate/evidence 변경
- Flutter UI
- 전투 damage/buff/debuff 계산
- `../v6` runtime import

## 완료 조건

- Aru 등 고정 예제에서 bond 1/10/20/50/100 누적값이 검증된다.
- 장비 Lv1/중간/최대와 성급 1~5 edge를 검증한다.
- 다른 의상 랭크 미확인은 `dependency_missing`으로 표현한다.
- generated metadata를 광범위하게 수동 편집하지 않는다.
- 변경 이유·테스트·다음 세션 계약을 workflow status에 갱신한다.

## 인계 계약

슬레이브 환경이면 같은 디렉터리의 `output.md`를 마지막에 작성하고 실제 patch/fixture/
verification 결과를 `artifacts/`에 저장한다. 각 artifact 크기와 SHA-256을 기록한다.
Flutter/CodeAlmanac 검증은 필요한 경우 `MASTER_REQUIRED`로 남긴다.

