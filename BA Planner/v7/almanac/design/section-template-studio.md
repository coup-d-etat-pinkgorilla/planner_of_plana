---
title: "Section Template Studio"
summary: "개발용 Studio가 Section→Container→Feature 계층과 48/96 그리드, 우측 위 80도 형상을 모델링하고 검증하는 경계를 기록합니다."
topics: [design, architecture, flutter, testing]
sources:
  - id: studio-model
    type: file
    path: frontend/lib/ui/studio/section_template.dart
  - id: studio-page
    type: file
    path: frontend/lib/ui/pages/section_template_studio_page.dart
  - id: studio-document
    type: file
    path: frontend/lib/ui/studio/section_studio_document.dart
  - id: studio-file-service
    type: file
    path: frontend/lib/ui/studio/section_studio_file_service.dart
  - id: studio-surface
    type: file
    path: frontend/lib/ui/widgets/section_template_surface.dart
  - id: studio-tests
    type: file
    path: frontend/test/section_template_studio_test.dart
  - id: studio-document-tests
    type: file
    path: frontend/test/section_studio_document_test.dart
  - id: responsive-policy
    type: file
    path: almanac/design/responsive-diagonal-layout-policy.md
---

# Section Template Studio

## 목적과 진입점

Section Template Studio는 실제 기능 탭을 디자인하기 전에 섹션의 점유 공간과 형상,
여러 요소의 배치를 개발 화면에서 검증하는 도구다. 앱 헤더의 개발 상태 패널에서 진입하며
기본 탭 목록에는 노출하지 않는다. Studio 상태는 실제 기능 데이터나 repository를 변경하지
않고 현재 widget 생명주기 안에서만 유지된다. [@studio-page]

## 사용자 정의 요소 모델

단일과 조합은 별도 모드가 아니다. 캔버스에는 항상 `SectionCanvasElement` 목록이 있고,
요소가 하나면 단일 구성, 둘 이상이면 조합 구성이 된다. 조합 preset은 제공하지 않는다.
사용자는 요소를 직접 추가·삭제·선택하고 각 요소의 X, Y, 폭, 높이를 48×48 논리 좌표로
설정한다. 새 요소는 현재 비어 있는 정사각형 영역을 우선 찾아 배치한다. 캔버스에서 도형
본체를 드래그하면 이동하고, 선택된 점유 rect의 네 모서리 핸들을 드래그하면 반대 모서리를
고정한 채 크기를 바꾼다. 포인터 이동량은 각 축의 실제 셀 크기로 나눈 뒤 가장 가까운 정수
셀로 스냅한다. [@studio-model]

각 요소는 점유 rect와 `AttachedSectionSpec`을 함께 가진다. 형상 입력은 삼각형·사다리꼴·
평행사변형, 붙는 왼쪽·오른쪽·위·아래 면, 면 내부 시작·길이로 구성한다. 삼각형의 나머지
꼭짓점은 붙는 면과 80도로 자동 계산하고 사다리꼴·평행사변형만 높이를 추가로 받는다.
모든 사선은 화면 좌표에서 우측 위로 향하는 `/` 80도로 고정한다.

48단위는 기존 24단위보다 두 배 촘촘한 배치를 제공한다. 8칸마다 굵은 선을 그어 기존
1/6 major division 여섯 개를 유지하고, 한 칸은 요소 사이 기본 간격을 검토하는 단위다.
Standard·Wide·Compact는 같은 논리 좌표를 서로 다른 실제 캔버스 비율에 투영한다.
[@responsive-policy]

## 단일 공용 렌더링 공간

모든 요소는 헤더 아래의 동일한 콘텐츠 `Size`와 원점을 공유한다. 요소별 점유 rect는 경로를
만드는 기준 좌표일 뿐 별도 `Positioned` 렌더링 캔버스나 `ClipRect`가 아니다. 렌더러는 각
요소의 로컬 polygon 점을 공용 캔버스 절대 좌표로 변환하고, 모든 fill·border·hit test를 같은
공용 경로에서 수행한다. 요소의 사선이나 원형 fillet이 점유 rect 밖으로 나가도 전체 콘텐츠
캔버스 안에 있는 부분은 잘리지 않는다. 마지막에만 콘텐츠 캔버스의 rounded bounds와
교차한다. [@studio-surface]

polygon 꼭짓점은 원형 fillet로 둥글린다. 예각은 인접 선분의 36%까지 접점을 허용해 직선
구간을 유지하면서 끝을 깊게 절삭한다. 원호는 polygon winding과 같은 방향을 사용해 볼록한
외곽선을 만들며 반대 원 중심에서 생기는 오목한 패임을 허용하지 않는다.

## Section → Container → Feature 레이어

Studio 편집 대상은 세 레이어다. Section은 기존 공용 콘텐츠 캔버스의 48×48 좌표를 사용한다.
Container는 반드시 하나의 부모 Section ID를 가지며 그 부모 footprint 내부의 로컬 96×96
좌표를 사용한다. Feature도 반드시 하나의 부모 Container ID를 가지며 부모 footprint 내부의
로컬 96×96 좌표를 사용한다. 부모를 이동하거나 리사이즈해도 자식의 로컬 rect는 바뀌지 않아
계층 전체가 함께 이동·비례 조정된다. [@studio-model]

Container와 shape Feature는 Section과 같은 삼각형·사다리꼴·평행사변형, 붙는 면, 면 범위,
높이 계약을 96단위로 사용한다. 각 레이어에서 본체 drag와 네 모서리 resize는 현재 부모의
실제 pixel 크기를 96칸으로 환산해 snap한다. Container path는 부모 Section path와 교차하고
Feature path는 부모 Container path와 교차하므로 자식 렌더링은 부모 외부에 노출되지 않는다.
선택한 부모 영역에만 96×96 보조 grid를 표시한다. [@studio-surface]

Feature에는 shape 외에 image 종류가 있다. 초기 image source는 v6 runtime 참조가 아니라 v7
asset으로 복사한 `assets/studio_features/square.png`이며 252:172 원본 비율을 저장한다. 숫자 입력과
corner resize 모두 한 축에서 다른 축을 재계산하고 96×96 부모 경계에서 clamp하므로 가로세로
비율을 임의로 변경할 수 없다. 이미지는 `BoxFit.contain`으로 고품질 렌더링하고 부모 path로
clip한다. [@studio-page] [@studio-surface]

## 검증 계약

- 요소 rect는 48×48 범위 안에 있어야 한다.
- 본체 드래그는 요소 크기를 유지한 채 X·Y를 정수 셀로 이동하고 캔버스 경계에서 멈춘다.
- 네 모서리 리사이즈는 반대 모서리를 고정하고 최소 폭·높이 1칸을 보장하며 48×48 경계를
  넘지 않는다.
- 핸들 판정은 pan threshold 이후가 아니라 최초 pointer-down 좌표에서 확정한다.
- 요소 rect의 중첩은 validator 경고로 표시한다.
- 모든 요소는 하나의 콘텐츠 캔버스와 하나의 48×48 그리드를 공유한다.
- 개별 요소 rect는 렌더링 clip 영역으로 사용하지 않는다.
- 붙는 면은 요소 geometry의 실제 외곽면이어야 한다.
- `faceStart + faceSpan`과 높이는 48 범위를 넘지 않도록 자동 보정한다.
- 삼각형에는 높이 입력을 표시하지 않는다.
- 모든 사선은 우측 위 `/` 80도 방향을 유지한다.
- 선택 요소의 부착면 눈금, 콘텐츠 안전영역, 전체 그리드는 독립적으로 표시한다.
- 상단 헤더는 기본 8/48이고 1/48~24/48 범위에서 조절한다. geometry는 남은 콘텐츠
  영역만 새로운 전체 캔버스로 사용한다.

`채팅용 요약 복사`는 공용 그리드·헤더·요소 수를 먼저 기록하고 모든 요소의 rect, 도형,
붙는 면, 면 범위, 높이를 순서대로 직렬화한다. 사용자는 전체 구성을 채팅에 그대로 붙여 넣어
승인이나 수정을 요청할 수 있다. [@studio-page]

## 구성 저장과 불러오기

Studio 구성은 사람이 읽고 diff할 수 있는 UTF-8 JSON으로 저장하며 기본 파일명은
`section-template.ba-section-studio.json`이다. 문서는 `ba-planner-section-studio` format과
정수 version을 맨 앞에 두고 48×48/96×96 grid, 우측 위 80° diagonal 계약, workspace의 헤더·viewport·
표시 옵션·활성 레이어와 선택 ID, 모든 section/container/feature의 ID·부모 ID·rect·shape·image
metadata를 기록한다. version 2가 계층을 저장하며 version 1 section-only 파일도 읽는다. JSON에는 앱 실행 상태나
실제 기능 데이터는 포함하지 않는다. [@studio-document]

불러오기는 JSON root와 format/version, 48×48 및 80° 고정 계약, workspace 타입과 범위,
1~256개 요소, 고유하고 비어 있지 않은 ID, rect 경계, enum과 면 범위를 모두 검사한다.
전체 decode가 성공하기 전에는 현재 widget 상태를 바꾸지 않으므로 손상되거나 호환되지 않는
파일을 선택해도 작업 중인 캔버스가 보존된다. 현재 version보다 새 버전은 추측해 읽지 않고
명시적으로 거부한다. [@studio-document]

`저장 파일에서 섹션 추가`는 일반 불러오기와 달리 현재 workspace를 교체하지 않는다. 문서를
완전히 검증한 뒤 가져온 모든 section을 append하고 container와 feature ID도 새로 발급하며,
parent ID를 새 ID map으로 함께 변환한다. 따라서 현재 문서와 원본 문서의 ID가 같아도 충돌이나
잘못된 부모 참조가 생기지 않는다. 가져온 배치는 원본 rect를 보존하며 기존 섹션과 겹치면 일반
overlap 경고를 통해 사용자가 재배치한다. [@studio-page]

Windows에서는 Flutter 공식 `file_selector`의 네이티브 열기·저장 대화상자를 사용한다.
페이지는 파일 대화상자와 분리된 service를 주입받을 수 있어 Widget test가 실제 파일 시스템을
열지 않고 저장 payload, 취소, 정상 교체와 실패 시 불변성을 검증한다. [@studio-file-service]

Widget test는 48×48 validator, 공용 캔버스 밖이 아닌 점유 rect 밖 경로의 보존, 공용 path
hit test, 요소 추가·선택·편집, 그리드 스냅 이동·네 모서리 리사이즈·경계 clamp, 헤더 비율,
요약 복사, viewport 전환, 예각의 볼록 fillet과 개발 패널 진입을 검증한다. 저장 문서 test는
전체 값 round-trip, v1 호환, 계층 부모 관계, schema·버전·범위·중복 ID 거부, service 기반
저장·불러오기·ID 재매핑 import와 실패 시 원자적 상태 보존을 검증한다. 레이어 test는 부모 clip,
96-grid, shape/image 추가와 이미지 비율 고정 resize를 검증한다. [@studio-tests] [@studio-document-tests]

## 현재 경계와 다음 확장

`SectionCanvasPainter`는 Studio 실험용 렌더러이며 기존 실제 페이지의 `DiagonalSection`을
자동 교체하지 않는다. 다음 확장 후보는 요소 이름 편집, 사선 seam 적합성 검사와 Dart spec
export다. 승인된 형상을 실제 UI에 적용할 때 공용
`SectionGeometry` 승격 범위를 별도로 결정한다. [@studio-surface]
