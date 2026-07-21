---
title: "BA Planner v7 Almanac"
summary: "Flutter 프론트엔드와 headless Python 백엔드의 장기 경계를 기록합니다."
topics: [architecture]
sources:
  - id: project-readme
    type: file
    path: README.md
---

# BA Planner v7 Almanac

v7은 Flutter와 Python의 프로세스 경계, 데이터 의미와 v6 parity를 장기 지식으로
관리합니다. 시작점은 [Target Runtime Boundaries](architecture/runtime-boundaries)입니다.
일회성 복사 목록은 Almanac이 아니라 `docs/migration/`에 둡니다. [@project-readme]

슬레이브 명령용 프롬프트를 작성하거나 결과물을 인계할 때는
[Slave Artifact Handoff](workflows/slave-artifact-handoff)의 `input.md`, `output.md`,
`artifacts/` 계약을 사용합니다.

P0~P6 작업을 새 대화에서 계속할 때는
[P0-P6 Workflow Status](workflows/p0-p6-workflow-status)를 먼저 읽고, 작업 결과와
다음 행동이 바뀔 때마다 전체 워크플로가 완료될 때까지 갱신합니다.

각 단계의 고정된 목적, 완료 조건, 의존 관계와 P6 탭별 목표는
[P0-P6 Implementation Workflow](workflows/p0-p6-workflow)를 기준으로 합니다. 단계
정의는 이 문서에, 현재 상태와 실제 산출물은 Workflow Status에 기록합니다.
