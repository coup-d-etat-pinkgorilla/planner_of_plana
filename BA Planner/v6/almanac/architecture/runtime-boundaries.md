---
title: "Runtime Boundaries"
summary: "Tk 제어 앱, Qt 뷰어, 스캔 엔진, 저장 계층, Cloudflare Worker 사이의 런타임 경계를 설명합니다."
topics: [architecture, refactoring]
sources:
  - id: main-entry
    type: file
    path: main.py
  - id: viewer-entry
    type: file
    path: gui/viewer_app_qt.py
  - id: viewer-components
    type: file
    path: gui/viewer_components/
  - id: scanner-engine
    type: file
    path: core/scanner.py
  - id: scanner-components
    type: file
    path: core/scanner_components/
  - id: repository-layer
    type: file
    path: core/repository.py
  - id: worker-entry
    type: file
    path: bug-report-worker/src/index.ts
  - id: bug-report-client
    type: file
    path: core/bug_report.py
  - id: bug-report-dialog
    type: file
    path: gui/bug_report_dialog.py
---

# Runtime Boundaries

BA Planner는 단일 UI 프로세스처럼 보이지만 책임이 다른 여러 런타임 표면으로
구성됩니다.

`main.py`의 Tk 애플리케이션은 대상 창 선택, 스캔 요청, 스캔 상태 전이와 검토·저장
흐름을 소유합니다. 실제 화면 이동과 인식은 `Scanner`에 위임합니다. 따라서 Tk 코드를
정리할 때 인식 기준이나 ROI 계산을 끌어오지 않아야 합니다. [@main-entry]
[@scanner-engine]

Qt 뷰어는 학생·플랜·인벤토리·전술 데이터를 표시하고 편집하는 별도 진입점입니다.
`gui/viewer_app_qt.py`는 `StudentViewerWindow`와 기존 helper import를 유지하는 façade이고,
스캔, 학생, 자원, 인벤토리, 레이드, 전술, 통계, 플래너 구현은
`gui/viewer_components/`의 독립 컴포넌트가 소유합니다. 공유 Qt widget과 순수 helper는
`gui/viewer_shared.py`에 둡니다. [@viewer-entry] [@viewer-components]

`core/scanner.py`도 기존 `Scanner`, 결과 타입, 테스트 patch point를 내보내는 façade입니다.
중단·대기·상태 전이 같은 런타임, 인벤토리 순회, 학생 인식 구현은 각각
`core/scanner_components/`의 runtime, inventory, student 컴포넌트로 구성합니다.
공용 모델과 저수준 helper는 `core/scanner_shared.py`에 둡니다. [@scanner-engine]
[@scanner-components]

영속화는 `core/repository.py`가 스캔 결과를 프로필별 JSON과 SQLite 표현으로
변환·병합하는 경계입니다. UI가 저장 파일을 직접 고치거나 스캐너가 뷰어 모델에
의존하면 이 경계가 무너집니다. [@repository-layer]

`bug-report-worker/`는 Cloudflare Workers 기반의 독립 TypeScript 서비스입니다.
데스크톱 Python 의존성이나 프로필 저장 규칙을 공유한다고 가정하지 않습니다.
Worker 작업에는 하위 `AGENTS.md`가 추가로 적용됩니다. 신고 빈도 제한은 IP 원문 대신
SHA-256 파생 키마다 분리된 SQLite-backed Durable Object가 최근 요청 시각만 소유합니다.
앱 프로필이나 신고 본문을 이 상태 저장소에 섞지 않습니다. [@worker-entry]

Qt 설정 탭의 문제 신고 다이얼로그는 입력과 비동기 작업 상태만 소유합니다. 진단정보
구성과 민감정보 제거, HTTP 오류 계약은 `core/bug_report.py`를 통과하며, Worker URL은
환경 변수로 production과 staging을 선택합니다. 실제 GitHub 토큰과 rate-limit 상태는
데스크톱 프로세스로 가져오지 않습니다. [@bug-report-dialog] [@bug-report-client]

## 리팩토링 기준

- UI 이벤트 조정은 Tk 또는 Qt 경계 안에서 처리합니다.
- 화면 캡처·입력·인식의 공개 계약은 `core/scanner.py`, 구현은 해당 scanner component와
  인식 모듈에 둡니다.
- 현재 상태의 병합·저장은 repository 계층을 통과시킵니다.
- 공유가 필요하면 거대 UI 클래스 사이에서 메서드를 옮기기보다 작은 순수 모델이나
  서비스 계약을 먼저 만듭니다.

데이터 의미를 바꾸는 작업은 [Data Bucket Separation](../decisions/data-bucket-separation)을
먼저 읽고, 대형 클래스 분리는
[Large Module Change Safety](../gotchas/large-module-change-safety)를 따릅니다.
