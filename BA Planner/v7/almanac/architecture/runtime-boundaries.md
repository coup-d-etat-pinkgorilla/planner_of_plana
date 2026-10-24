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
  - id: frontend-process-service
    type: file
    path: frontend/lib/services/process_app_service.dart
  - id: backend-process
    type: file
    path: backend/core/backend_process.py
  - id: user-data-migration
    type: file
    path: backend/core/user_state_migration.py
---

# Target Runtime Boundaries

Flutter는 화면, view state, 입력과 접근성을 소유합니다. Python 객체나 프로필
파일을 직접 읽지 않고 versioned local protocol을 통해 use case를 요청합니다.
[@frontend-entry] [@protocol-readme]

Python backend는 계산, 저장, scanner orchestration을 소유합니다. Flutter widget,
Qt signal이나 QML model을 backend DTO에 넣지 않습니다. 현재 첫 slice는 계획 목표와
총 필요량 계산이며, 목표와 현재 상태의 의미를 합치지 않습니다. [@planning-model]

학생 정적 메타데이터의 source of truth는
`backend/data/metadata/v1/student_catalog.json`입니다. core 학생 레코드, 폼,
서버 가용성, 애용품 상태, provider reference와 선물 affinity를 versioned catalog의
서로 다른 영역에 둡니다. `core.student_meta`는 기존 계산·scanner 호출자를 위한
호환 lookup façade이며 generated Python 선언은 더 이상 runtime source가 아닙니다.
승인된 client-store 원천 재생성은 오프라인 도구가, 계산용 명시 CharacterId 바인딩은
별도 sidecar가 소유합니다. 자세한 계약은 [Canonical Metadata Boundary](canonical-metadata)를 따릅니다.

Inventory의 `resource_key`만 version 간 stable identity입니다. `order_index`는 현재
catalog revision에 속하는 scan/display ordinal이고 실제 화면에서 관측한 위치는
`observed_slot`입니다. 상세 계약은
[Inventory Catalog Order Stability](inventory-catalog-order)를 따릅니다.

planning과 repository slice의 실행 경계는 JSON Lines stdin/stdout Python process와 Dart
process client입니다. Python은 profile catalog, confirmed current, inventory와 goal의 atomic
persistence를 소유하고 Flutter는 immutable typed repository state만 소비합니다. 기본 UI
실행은 mock을 유지하고 compile-time define으로만 실제 `ProcessAppService`를 선택합니다.
process 진단은 stderr로 분리하며 Flutter는 Python 모듈이나 repository 파일을 직접 읽지
않습니다. [@frontend-process-service] [@backend-process]

기본 사용자 데이터는 `%LOCALAPPDATA%/BA Planner/v7/`에 둡니다. 시작 시 기존 기본
경로를 양쪽 잠금과 지문 검증 아래 원본 보존 복사로 이관합니다. 명시한 사용자/storage
경로는 자동 이관하지 않습니다. 복구 중 journal이나 알 수 없는 목적지가 있으면
자동 덮어쓰기를 거부합니다. [@backend-paths] [@backend-process]

Windows 이관 I/O는 drive/UNC의 절대 extended-length 경로를 사용하며, 상대 manifest
키는 유지합니다. 실패하면 원본으로 쓰기를 전환하거나 빈 저장소를 노출하지 않고
`user_data_migration_failed` 전역 응답만 제공하는 제한된 JSONL 상태로 시작합니다.
이 상태는 일반 메타데이터·저장소·스캐너를 로드하지 않습니다. 원인을 해결한 뒤
앱을 재시작해야 하며 경로/파일명/예외 원문은 응답에 담지 않습니다. 지속 guard
파일은 OS 잠금의 고정 이름으로 남겨 둡니다. [@user-data-migration] [@backend-process]

표시용 asset은 Flutter package에 포함하고 scanner template/region은 Python backend의
인식 contract로 별도 배포합니다. 표시용 v6 원본은 `frontend/assets/` 아래 역할별 경로를
유지하고, 인식 자산은 Python 소스와 분리된 `backend/assets/recognition/v1/`의 versioned
manifest로 관리합니다. 배포 환경은 완전한 같은 버전 catalog에 한해
`BA_PLANNER_RECOGNITION_ASSET_DIR`로 packaged root를 교체할 수 있습니다. 계획 기준표는
backend package 기본값을 사용하되,
명시적인 runtime asset override가 있을 때만 외부 버전을 채택합니다. [@backend-paths]

v6는 회귀 기준이지 v7 runtime dependency가 아닙니다. 수직 이전마다 v6 결과 fixture와
v7 contract test를 먼저 만들고, parity가 확인된 뒤에만 v7 구현을 확장합니다.
[@project-readme]
