---
title: "P0-P6 Implementation Workflow"
summary: "planning 계약부터 실제 프로세스, 저장소, scanner와 전 탭 통합 베타까지 진행하는 단계별 구현 계약입니다."
topics: [workflow, architecture, migration, data]
sources:
  - id: runtime-boundaries
    type: file
    path: almanac/architecture/runtime-boundaries.md
  - id: migration-baseline
    type: file
    path: docs/migration/v6-knowledge-baseline.md
  - id: protocol-contract
    type: file
    path: contracts/README.md
  - id: app-sections
    type: file
    path: frontend/lib/ui/app_section.dart
---

# P0-P6 Implementation Workflow

이 워크플로는 v7을 Flutter UI 목업에서 실제 데이터를 다루는 통합 베타로 발전시키는
순서를 고정한다. 각 단계는 다음 단계의 경계를 먼저 확정하며, v6 폴더나 facade를
통째로 복사하지 않는다. Flutter는 화면과 view state를, 별도 Python 프로세스는 계산,
저장과 scanner orchestration을 소유한다. [@runtime-boundaries] [@migration-baseline]

## 전체 결과

| 단계 | 구현 결과 | 사용자에게 보이는 수준 |
|---|---|---|
| P0 | planning protocol v1 계약과 양쪽 contract test | UI는 mock, wire 계약은 확정 |
| P1 | Python JSONL process와 Dart process client | 실제 backend 연결과 planning 호출 가능 |
| P2 | 실제 계획 화면 수직 슬라이스 | 학생 목표 설정과 총 필요량 계산 가능 |
| P3 | repository DTO와 병합 parity 특성화 | 저장 이전의 데이터 경계 확정 |
| P4 | 프로필·현재 상태·목표 영구 저장 | 재실행 후 데이터 복원, 수동 입력형 알파 |
| P5 | scanner/matcher protocol과 backend 이전 | 학생·인벤토리 스캔과 검토·확정 가능 |
| P6 | 모든 기본 탭을 실제 데이터에 연결 | 핵심 흐름이 연결된 통합 베타 |

P0부터 P6까지는 순차 의존한다. 단, 선행 계약을 바꾸지 않는 UI 골격·fixture·조사
작업은 병렬로 준비할 수 있다.

## 공통 불변식

모든 단계는 다음을 지킨다. [@migration-baseline]

1. 스캔된 현재 상태, 정적 메타데이터, 사용자 목표, 보유량 차감 전 총 계산 결과,
   인벤토리 기반 부족량을 서로 다른 필드와 계산 단계로 유지한다.
2. `calculate_goal_cost()`와 `calculate_plan_totals()`은 총 필요량만 반환한다.
3. 비어 있는 목표는 현재 값을 유지한다. 숫자 `0`과 같은 의미가 아니다.
4. 낮은 confidence의 scanner 결과는 검토 없이 확정 저장하지 않는다.
5. repository만 프로필 JSON과 SQLite 병합을 소유한다.
6. Flutter는 프로필 파일이나 SQLite를 직접 읽지 않는다.
7. scanner status는 로그 문자열이 아니라 versioned event 계약이다.
8. runtime UI asset과 scanner recognition template을 분리한다.
9. `../v6`는 fixture와 동작 조사에만 사용하며 런타임 import하지 않는다.
10. Qt, QML, QWidget, Tkinter와 PySide6 presentation 코드를 복사하지 않는다.

## P0 — Planning IPC 계약

### 목표

공통 envelope 위에 planning 수직 슬라이스의 request, response, 오류와 호환성 정책을
고정한다. Python과 Dart가 동일 fixture를 소비해야 한다. [@protocol-contract]

### 범위

- 학생 정적 메타데이터 한 건 조회
- 계획 역직렬화·검증과 canonical 직렬화
- 현재 학생 상태와 목표를 사용한 총 필요량 계산
- 구조화된 오류, request/response ID 상관관계
- unknown-field와 protocol version 정책
- method별 JSON Schema와 공용 fixture
- Python JSON Schema test와 Dart wire contract test

### 완료 조건

- method별 schema와 공용 fixture가 `contracts/`에 있다.
- 정상, 잘못된 payload, 알 수 없는 method와 version mismatch 사례가 있다.
- 양쪽 contract test와 기존 planning parity test가 통과한다.
- process transport, UI, repository와 scanner 코드는 포함하지 않는다.

## P1 — 실제 Process Transport

### 목표

P0 계약을 실제 별도 Python 프로세스와 Flutter service 경계로 연결한다.

### 범위

- Python JSONL stdio entrypoint와 planning dispatcher
- Dart process lifecycle, JSONL framing과 request ID 매칭
- timeout, stderr 진단, 비정상 종료와 pending request 실패
- reconnect, restart와 dispose
- 실제 backend 선택 경로와 테스트 기본 `MockAppService` 유지
- 배포 전 개발 환경에서 backend 경로와 Python launcher 설정

### 완료 조건

- Flutter에서 세 planning method를 실제 Python process로 호출할 수 있다.
- 정상 응답, protocol 오류, timeout, malformed output와 process 종료를 테스트한다.
- 앱 종료 시 child process와 stream이 정리된다.
- scanner 호출은 지원되지 않음을 명시적으로 반환한다.
- repository와 scanner를 transport 구현에 끌어오지 않는다.

## P2 — 계획 화면 수직 슬라이스

### 목표

계획 placeholder를 실제 학생 목표 입력과 계산 결과 화면으로 바꾼다.

### 범위

- 학생 검색·선택과 계획 대상 추가·삭제
- 현재 성장 상태와 목표 상태를 별도 모델로 표시
- 레벨, 성급, 무기, 스킬, 장비와 능력치 목표 편집
- 학생별 비용과 전체 총 필요량 계산
- loading, empty, validation, backend disconnected와 calculation error 상태
- P4 전까지 명시적인 임시 저장 또는 in-memory 정책

### 완료 조건

- 실제 `AppService` planning method만 통해 계산한다.
- 목표 변경과 합산 결과를 Widget test로 검증한다.
- 총 필요량을 부족량으로 표시하지 않는다.
- P0 schema를 UI 편의 때문에 임의로 우회하지 않는다.

## P3 — Repository 특성화와 DTO 분리

### 목표

v6 repository를 복사하기 전에 scanner DTO, 프로필 저장과 JSON/SQLite 병합 동작을
분리하고 fixture로 고정한다.

### 범위

- 학생 현재 상태, 인벤토리, 목표와 scanner candidate의 독립 DTO
- v6 repository import와 callback 의존성 목록
- 프로필 JSON/SQLite 우선순위와 병합 parity fixture
- unknown-field, 오래된 version, 누락·손상 데이터 정책
- 인벤토리 정렬, 프로필 순서와 zero-fill 계약
- repository application service와 protocol method 초안

### 완료 조건

- scanner/matcher 모듈 없이 repository fixture를 재생할 수 있다.
- 다섯 데이터 버킷 사이의 필드 매핑이 문서와 test에 고정된다.
- v6 runtime import 없이 parity test가 통과한다.
- 이 단계에서는 실제 사용자 저장소를 쓰지 않는다.

## P4 — Repository와 프로필 영구 저장

### 목표

Python backend가 프로필과 다섯 데이터 버킷의 저장·복원을 소유하게 한다.

### 범위

- 프로필 생성, 조회, 선택과 이름 변경
- 학생 현재 상태, 인벤토리와 사용자 목표 저장·복원
- JSON/SQLite 병합과 데이터 version 처리
- atomic write 또는 실패 시 기존 데이터 보존
- 손상 데이터, 부분 데이터와 저장 실패 오류
- Flutter repository client와 프로필 UI의 최소 경로
- 기존 v6 프로필의 명시적인 import 또는 migration 경계

### 완료 조건

- 앱 재실행 후 프로필, 현재 상태와 목표가 복원된다.
- 총 계산 결과와 부족량은 원본 상태처럼 잘못 저장·병합되지 않는다.
- Flutter가 파일과 DB를 직접 읽지 않는다.
- 병합·손상·실패 fixture와 양쪽 contract test가 통과한다.

## P5 — Scanner/Matcher 계약과 Backend

### 목표

캡처·인식 로직을 UI callback에서 분리해 versioned session protocol로 제공하고,
검토된 결과만 repository에 반영한다.

### 범위

- 학생/인벤토리 scan start, cancel과 session generation
- 구조화된 phase, progress, candidate와 terminal event
- capture target, ROI, matcher와 recognition template 경계
- confidence와 review-required 상태
- 이전 session의 지연 event 무시
- 결과 검토, 수정, 확정과 repository commit 분리
- scanner asset packaging과 진단 오류

### 완료 조건

- Flutter를 실행하지 않고 scanner application service를 테스트할 수 있다.
- 취소, 실패, stale event와 낮은 confidence 사례가 fixture에 있다.
- 낮은 confidence 후보가 자동으로 현재 상태를 덮어쓰지 않는다.
- UI asset과 recognition template이 별도 경로로 배포된다.

## P6 — 실제 탭 통합

### 목표

기본 탭의 placeholder를 제거하고 P1~P5의 실제 service와 데이터를 사용해 핵심 사용자
흐름을 완성한다. 현재 기본 탭 목록은 `AppSection.primary`를 기준으로 한다.
[@app-sections]

### 탭별 기능

| 탭 | P6 완료 시 가능한 기능 |
|---|---|
| 홈 | 현재 프로필·backend 상태, 학생/인벤토리 수, 활성 계획, 부족 재화와 최근 스캔 요약, 각 탭 바로가기 |
| 학생 | 실제 학생 목록, 검색·필터·정렬, 현재 육성 상태 조회·수정, scan confidence 검토, 계획에 학생 추가 |
| 계획 | 다중 학생 목표 편집, 현재 상태 비교, 학생별·전체 총 필요량, 인벤토리 기반 부족량, 계획 저장·복원 |
| 인벤토리 | 카테고리·검색·정렬·zero-fill, 수량 수정, 스캔 결과 비교·확정, 계획 필요량과 부족량 연결 |
| 전술대항전 | 실제 학생을 사용한 공격·방어 편성, 기록·메모 저장, 검색·필터; 고급 추천·승률 분석은 별도 범위 |
| 통계 | 학생 성장 분포, 인벤토리 현황, 계획 총계와 부족 재화 집계; 지표와 차트 목록은 구현 전 고정 |
| 스캔 | 대상 창과 scan 종류 선택, 진행·취소·재시도, 후보 비교·수정·확정, 최근 결과 표시 |
| 설정 | 프로필 관리, backend 재연결·재시작, protocol/version·경로·로그·scanner 진단, Adaptive-Sync 진입 |

`Adaptive-Sync 진단`은 기본 탭이 아니며 설정에서 진입하는 그래픽 진단 화면으로
유지한다. 실제 PNG hover, 탭 전환과 창 크기 변경 시 Windows 표시 문제를 재현한다.

### 권장 하위 순서

1. P6-1 학생
2. P6-2 인벤토리
3. P6-3 스캔
4. P6-4 홈
5. P6-5 통계
6. P6-6 전술대항전
7. P6-7 설정과 통합 오류 처리

계획 탭은 P2에서 먼저 실제화하고 P6에서 repository와 scanner 결과까지 연결한다.
전술대항전과 통계의 세부 기능은 v6 동작 조사와 별도 fixture 없이 추측해 구현하지
않는다.

### 완료 조건

- `AppSection.primary`의 모든 화면이 실제 service 또는 명시된 파생 데이터에 연결된다.
- 모든 탭에 loading, empty, error와 disconnected 상태가 있다.
- scan → 현재 상태 검토 → 목표 설정 → 총 필요량 → 부족량 → 저장·복원 흐름이 통과한다.
- 대용량, 긴 이름, 누락 metadata와 좁은 창 상태를 Widget test로 검증한다.
- Python, Flutter analyze/test와 Windows release build가 통과한다.

## 단계별 작업과 인계

각 단계는 독립된 작업 디렉터리의 `input.md`로 지시하고, 슬레이브는 같은 위치의
`output.md`와 `artifacts/`를 함께 반환한다. 마스터가 파일 존재, SHA-256, diff와
검증 결과를 직접 확인하기 전에는 완료로 판정하지 않는다.

단계 상태, 실제 산출물과 다음 행동은
[P0-P6 Workflow Status](p0-p6-workflow-status)에 기록한다. 이 문서는 장기 단계 정의를,
상태 문서는 현재 진행 사실을 소유한다.

## P6 이후

P6은 통합 베타 완료 기준이다. v6 전체 기능 parity 감사, scanner 해상도·게임 업데이트
안정화, 성능, 백업·복구, 접근성, installer, 서명, 자동 업데이트와 release 운영은
별도 안정화 단계로 관리한다.
