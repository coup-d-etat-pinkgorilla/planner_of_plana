---
title: "Target Runtime Boundaries"
summary: "v7 Flutter, Python backend, protocol과 asset 경계를 설명합니다."
topics: [architecture, migration, data]
sources:
  - id: project-readme
    type: file
    path: README.md
  - id: frontend-entry
    type: file
    path: frontend/lib/main.dart
  - id: backend-paths
    type: file
    path: backend/core/runtime_paths.py
  - id: planning-model
    type: file
    path: backend/core/planning.py
  - id: protocol-readme
    type: file
    path: contracts/README.md
---

# Target Runtime Boundaries

Flutter는 화면, view state, 입력과 접근성을 소유합니다. Python 객체나 프로필
파일을 직접 읽지 않고 versioned local protocol을 통해 use case를 요청합니다.
[@frontend-entry] [@protocol-readme]

Python backend는 계산, 저장, scanner orchestration을 소유합니다. Flutter widget,
Qt signal이나 QML model을 backend DTO에 넣지 않습니다. 현재 첫 slice는 계획 목표와
총 필요량 계산이며, 목표와 현재 상태의 의미를 합치지 않습니다. [@planning-model]

표시용 asset은 Flutter package에 포함하고 scanner template/region은 Python backend의
인식 contract로 별도 배포합니다. 계획 기준표는 backend package 기본값을 사용하되,
명시적인 runtime asset override가 있을 때만 외부 버전을 채택합니다. [@backend-paths]

v6는 회귀 기준이지 v7 runtime dependency가 아닙니다. 수직 이전마다 v6 결과 fixture와
v7 contract test를 먼저 만들고, parity가 확인된 뒤에만 v7 구현을 확장합니다.
[@project-readme]

