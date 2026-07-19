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
  - id: ui-design-spec
    type: file
    path: gui/ui_design_spec.py
  - id: ui-component-studio
    type: file
    path: tools/ui_component_studio.py
  - id: ui-scale-context
    type: file
    path: gui/ui_scale.py
  - id: qt-quick-viewer
    type: file
    path: gui/quick_app.py
  - id: qt-quick-layer
    type: file
    path: gui/quick/
  - id: ui-diagonal-shape
    type: file
    path: gui/diagonal_shape.py
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

Qt 홈 내부 설정 패널의 문제 신고 다이얼로그는 입력과 비동기 작업 상태만 소유합니다. 진단정보
구성과 민감정보 제거, HTTP 오류 계약은 `core/bug_report.py`를 통과하며, Worker URL은
환경 변수로 production과 staging을 선택합니다. 실제 GitHub 토큰과 rate-limit 상태는
데스크톱 프로세스로 가져오지 않습니다. 신고 진단정보는 최신 로그의 완전한 오류·fallback
레코드와 실제 스캔 해상도만 포함하며, 오류를 요청 한도에 맞춰 자동 절단하지 않습니다.
클라이언트는 결정적 집계 요약과 무손실 원문을 분리하고, Worker는 요약을 Issue 본문,
원문을 Issue 댓글에 기록합니다. 댓글 등록 실패는 Issue와 앱 응답 양쪽에 명시합니다.
[@bug-report-dialog] [@bug-report-client]

Qt 홈은 연결·스캔 진입과 다른 뷰어 탭으로의 이동만 조정합니다. 실제 스캔은 기존처럼
별도 Tk 스캐너 프로세스에 위임하며, 홈에서 직접 입력한 크레딧과 청휘석도 임의 JSON
수정 대신 `ScanRepository`를 통해 현재 프로필의 스캔 표현으로 저장합니다.
[@viewer-components] [@repository-layer]

Qt 컴포넌트의 QSS, 기본 팔레트, selector 기반 대각선 형태는
`gui/ui_design_spec.json`을 공통 명세로 사용합니다. UI Component Studio는 실제 Viewer를
복제하지 않고 독립 샘플 위젯을 갤러리로 표시합니다. Studio는 geometry, layout,
visibility, 새 위젯, 애니메이션을 편집하거나 런타임에 주입하지 않습니다. v1 구조 값은
마이그레이션 이력으로만 보존합니다. Planner는 전체 QObject 트리를 색인하지 않고 명세에
기록된 selector 경로만 직접 해석합니다.
[@ui-design-spec] [@ui-diagonal-shape] [@ui-component-studio]

각 Qt 최상위 창은 1920×1080 기준의 독립 `UIScaleContext`를 소유합니다. geometry와
11pt 기준 폰트는 같은 연속 scale을 사용합니다. Viewer는 시작 모니터의 화면 비율을 유지하며,
리사이즈가 멈추면 저장소를 다시 읽지 않고 메모리 데이터로 UI 표현 트리만 재생성합니다.
`QApplication` 전역 scale로 여러 창을 함께 바꾸지 않습니다. [@ui-scale-context]
[@viewer-components]

점진적으로 전환되는 Qt Quick Viewer는 같은 1920×1080 기준을 사용하지만 표현 트리를
재생성하지 않습니다. 하나의 논리 canvas transform이 창 크기를 흡수하고, Python
`QAbstractListModel`이 학생·플랜·인벤토리 데이터를 소유하며 QML `GridView`/`ListView`는
보이는 delegate만 생성합니다. QML은 프로필 파일이나 SQLite를 직접 읽지 않고 기존 Python
저장·계산 경계를 통과합니다. [@qt-quick-viewer] [@qt-quick-layer]

Qt Quick 디자인 override는 QWidget selector와 분리된 `qml/...` selector만 사용합니다.
허용 대상과 코드 기본값은 `gui/quick/design_registry.py`가 소유하고, Quick UCS는 저장 전
범위·히트 영역·형상 조합을 검증합니다. 실행 중 Viewer는 같은 명세 파일을 감시하지만 등록되지
않거나 검증에 실패한 QML override는 채택하지 않고 코드 기본값을 유지합니다. 팔레트와 유효한
형상·선호 크기·추가 패딩 변경과 전역 타이포그래피 토큰은 QML 객체나 Python 모델을
재생성하지 않고 바인딩만 갱신합니다. 선호 크기 `0`은 자동 레이아웃을 뜻하며, 기존 코드의
패널별 기본 크기, 표면 variant, 반지름, 테두리와 주요 spacing은 QML 파일이 아니라 같은
registry가 소유합니다. variant는 전역 팔레트 의미 토큰을 선택하며 패널별 임의 색상을
영속화하지 않습니다.
공통 버튼·입력·콤보·체크박스·스크롤바·진행 표시줄 스타일도 `qml/controls/...` registry 대상이
소유합니다. UCS는 자동 축을 뜻하는 `0`을 포함한 너비·높이,
반지름, 테두리와 normal·hover·active·pressed 상태의 의미 표면 토큰만 저장하며, 개별 QML
인스턴스 주소나 임의 색상 selector를 만들지 않습니다. 유효한 변경은 실행 중인 기존 컨트롤
객체의 바인딩만 갱신하고 페이지 트리나 Python 모델을 재생성하지 않습니다.
대화상자와 콤보 드롭다운은 `qml/overlays/dialog`, `qml/overlays/dropdown` 대상으로 분리하고
공통 `PlannerPopup` 경계를 통과합니다. 오버레이 override는 콘텐츠 모델이나 열림 상태가 아니라
표면, 테두리, 패딩, 반지름, 모달 스크림만 소유합니다. 따라서 실행 중 스타일 저장은 열린
팝업을 닫거나 내부 입력 상태를 다시 만들지 않습니다.
학생 카드·인벤토리 행·플랜 행은 `qml/delegates/...` 역할 대상으로 분리하고 공통
`PlannerDelegateSurface`가 외곽 표면만 그립니다. delegate의 데이터 역할, 생성 수와 재사용은
기존 `GridView`·`ListView`가 계속 소유합니다. 디자인 명세는 높이·패딩·상태 표면만 바꾸며
모델 행이나 선택 ID를 복제하지 않습니다.
같은 경계는 창 후보·플랜 재화·전술 족보·전술 전적·통계 compact row에도 적용됩니다.
승패, 자동 감지 여부와 통계 수치 같은 데이터 의미는 각 페이지 바인딩이 계속 소유합니다.
초상·아이콘 프레임, 학생 상태 배지와 통계 막대는 `qml/elements/...` 대상으로 분리하고 공통
`PlannerElementSurface`가 그립니다. 요소 override는 이미지 주소, 로딩 상태, 레벨·성급이나
통계 비율을 소유하지 않으며 크기·표면·반지름·불투명도만 바꿉니다.
학생 상세 패널, 플랜 재화 요약과 통계 요약 카드도 같은 요소 경계를 사용합니다. 표시 여부와
요약 데이터는 페이지가 계속 소유하므로 디자인 저장이 학생 선택이나 통계 계산을 바꾸지 않습니다.
페이지 구분선은 `PlannerDivider`를 사용합니다. 페이지 QML은 직접 `Rectangle`, 기본 Qt
Control이나 임의 hex 색상을 만들지 않는 것을 회귀 테스트로 강제하며, 기하 도형은 등록된 공통
컴포넌트 내부에서만 소유합니다.
[@ui-design-spec] [@qt-quick-layer]

## 리팩토링 기준

- UI 이벤트 조정은 Tk 또는 Qt 경계 안에서 처리합니다.
- 화면 캡처·입력·인식의 공개 계약은 `core/scanner.py`, 구현은 해당 scanner component와
  인식 모듈에 둡니다.
- 현재 상태의 병합·저장은 repository 계층을 통과시킵니다.
- 공유가 필요하면 거대 UI 클래스 사이에서 메서드를 옮기기보다 작은 순수 모델이나
  서비스 계약을 먼저 만듭니다.

## 스캔 종료와 저장 워커

스캔 결과 리뷰는 Tk UI 스레드에서 처리하지만, 리뷰 승인 뒤의 최종 JSON 작성,
repository 병합, SQLite 반영은 별도 저장 워커에서 수행합니다. 스캔 작업 스레드가
끝났더라도 저장 완료 콜백이 도착하기 전에는 WATCHING 전환이나 자동 스캐너 프로세스
종료를 실행하지 않습니다. 저장 워커가 이미 종료됐더라도 UI 완료 콜백이 큐에 남아
있을 수 있으므로 worker 객체의 존재 자체가 이 구간의 수명주기 가드입니다.
[@main-entry] [@repository-layer]

데이터 의미를 바꾸는 작업은 [Data Bucket Separation](../decisions/data-bucket-separation)을
먼저 읽고, 대형 클래스 분리는
[Large Module Change Safety](../gotchas/large-module-change-safety)를 따릅니다.
