---
title: "Section Template Studio"
summary: "개발용 Studio가 Section 그리드와 Container/Feature의 부모 상대 간격 배치, 우측 위 80도 형상을 모델링하고 검증하는 경계를 기록합니다."
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
  - id: title-runtime
    type: file
    path: frontend/lib/ui/pages/title_page.dart
  - id: title-layout
    type: file
    path: frontend/lib/ui/studio/title_studio_layout.dart
  - id: asset-image-grid
    type: file
    path: frontend/lib/ui/widgets/asset_image_grid.dart
  - id: title-tests
    type: file
    path: frontend/test/title_page_test.dart
  - id: account-layout
    type: file
    path: frontend/lib/ui/studio/account_studio_layout.dart
  - id: account-runtime
    type: file
    path: frontend/lib/ui/widgets/account_section_cluster.dart
  - id: account-studio-document
    type: file
    path: release/section-account-create-manager.ba-section-studio.json
  - id: lifted-path-shadow
    type: file
    path: frontend/lib/ui/widgets/lifted_path_shadow.dart
  - id: student-layout
    type: file
    path: frontend/lib/ui/studio/student_studio_layout.dart
  - id: student-runtime
    type: file
    path: frontend/lib/ui/widgets/student_section_layout.dart
  - id: student-tests
    type: file
    path: frontend/test/student_studio_layout_test.dart
  - id: student-studio-document
    type: file
    path: release/section-student.ba-section-studio.json
  - id: student-catalog-dto
    type: file
    path: frontend/lib/services/app_service.dart
  - id: student-catalog-protocol
    type: file
    path: backend/core/protocol_v1.py
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
사용자는 Section을 직접 추가·삭제·선택하고 각 Section의 X, Y, 폭, 높이를 전역 96×96 논리 좌표로
설정한다. 새 요소는 현재 비어 있는 정사각형 영역을 우선 찾아 배치한다. 캔버스에서 도형
본체를 드래그하면 이동하고, 선택된 점유 rect의 네 모서리 핸들을 드래그하면 반대 모서리를
고정한 채 크기를 바꾼다. 포인터 이동량은 각 축의 실제 셀 크기로 나눈 뒤 가장 가까운 정수
셀로 스냅한다. [@studio-model]

각 요소는 점유 rect와 `AttachedSectionSpec`을 함께 가진다. 형상 입력은 삼각형·사다리꼴·
평행사변형, 붙는 왼쪽·오른쪽·위·아래 면, 면 내부 시작·길이로 구성한다. 삼각형의 나머지
꼭짓점은 붙는 면과 80도로 자동 계산하고 사다리꼴·평행사변형만 높이를 추가로 받는다.
모든 사선은 화면 좌표에서 우측 위로 향하는 `/` 80도로 고정한다.

96단위는 기존 48단위보다 두 배 촘촘한 배치를 제공한다. 8칸마다 굵은 선을 그어
12개 major division을 표시하고, 한 칸은 요소 사이 기본 간격을 검토하는 단위다.
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

Studio 편집 대상은 세 레이어다. Section만 공용 콘텐츠 캔버스의 전역 96×96 좌표를 사용한다.
Container는 반드시 하나의 부모 Section ID를 가지고 부모 Section 경계 상자 안의 0~1 비율 rect를
사용한다. Feature도 반드시 하나의 부모 Container ID를 가지고 부모 Container 경계 상자 안의
0~1 비율 rect를 사용한다. 따라서 부모를 이동하거나 크기를 바꾸면 자식도 함께 이동·비례 조정된다.
[@studio-model]

Container와 shape Feature는 Section과 같은 삼각형·사다리꼴·평행사변형, 붙는 면, 면 범위,
높이 계약을 96단위로 사용하지만 배치 rect에는 그리드를 사용하지 않는다. 본체 drag는 부모의
실제 pixel 크기를 0~1 비율 이동량으로 환산한다. 사용자가 고른 공통 간격은 부모의 짧은 변에
대한 비율을 실제 pixel 거리로 환산한다. 부모와 자식, 형제 아이템의 둥근 polygon path 사이
최단거리가 이 값에 가까워지면 사선의 법선 방향까지 포함해 snap한다. 따라서 평행사변형의
경계 상자 모서리가 아니라 화면에 그려지는 사선 외곽선이 간격 기준이다. 네 모서리 resize도 부모 상대
비율을 사용한다. Container path는 부모 Section path와, Feature path는 부모 Container path와
교차하므로 자식 렌더링은 부모 외부에 노출되지 않는다. 하위 레이어는 격자 대신 선택 아이템과
부모의 실제 path와 아이템의 실제 path 사이 최단거리 guide를 표시한다. [@studio-surface]

Feature는 shape, image, text, line 네 종류를 지원한다. image preset은 기존 252:172 이미지,
사용자가 제공한 863:250 `assets/studio_features/plan_a_title.png`, bitmap을 복제하지 않고
Material-style stroke로 그리는 둥근 뒤로 화살표다. preset을 바꾸면 저장된 비율과 부모의 실제
aspect ratio를 사용해 rect 높이를 다시 계산한다. 숫자 입력과 corner resize도 한 축에서 다른
축을 재계산하고 부모 경계에서 clamp하므로 이미지 비율을 임의로 변경할 수 없다. bitmap은
`BoxFit.contain`으로 렌더링한다. text는 최대 120자의 사용자 문자열을 중앙 정렬하고 line은
둥근 cap의 수평선으로 렌더링한다. 모든 종류는 부모 path로 clip한다. [@studio-page] [@studio-surface]

Container는 `BA 삼각 무늬` boolean을 가진다. 활성화하면 기존 Flutter
`BATriangleTexturePainter`를 고정 seed와 낮은 대비로 재사용하고 Container의 실제 path에 clip한다.
repaint마다 임의 패턴을 만들거나 별도 bitmap 배경을 추가하지 않는다. [@studio-surface]

삼각 무늬를 밝은 행동 버튼 표면에 사용할 때는 하늘색 계열 대신 Title 로고 이미지에서 추출한
핑크 `#E08EE6`을 옅게 만든 공용 보라빛 연핑크색 계열을 기본으로 사용한다. Title의
시작·설정·종료와 계정 클러스터의 변경·뒤로·저장·닫기·전환·추가·수정·삭제 버튼은
`BATrianglePalette.softTitlePink*` 색상군을 공유한다. 어두운 Section 배경, 목록 row, outline,
scrollbar와 선택 상태 색은 밝은 행동 버튼 팔레트로 간주하지 않으며 각 역할의 기존 대비를 유지한다.
로고 원색을 그대로 넓은 면에 칠하지 않고 흰색 방향으로 옅게 섞은 뒤 base alpha를 약 53%로 낮춘다.
따라서 로고와 hue는 연결되지만 버튼 면이 진한 자주색 덩어리나 밝은 분홍 표면으로 튀지 않는다.
색상 변경 시에도 triangle 크기·고정 seed·저대비 tessellation·macro face·light·fog 설정은
보존한다. [@title-runtime] [@account-runtime] [@title-tests]

## Studio 구성을 실제 화면에 적용할 때의 규칙

타이틀 화면 적용 과정에서 Studio 문서를 육안으로 비슷하게 다시 만드는 방식은 크기, 둥근 모서리,
사선 끝점과 자식 배치에서 반복적인 오차를 만들었다. 실제 화면은 JSON의 Section rect와
Container/Feature 상대 rect를 typed projection으로 읽고 Studio와 같은 path 생성 함수를 사용해야
한다. 두 Studio 문서의 일부를 조합해야 한다면 어느 문서가 각 Section·Container·Feature의
위치를 소유하는지 코드와 test에 명시한다. 새 Container 위치만 채택하면서 기존 text·line 위치를
유지해야 하는 경우처럼 서로 다른 부모 rect를 섞는 작업은 암묵적인 좌표 재계산에 맡기지 않는다.
[@title-layout] [@title-tests]

Section의 기본 표면은 테두리가 없고 반투명이다. 그러나 같은 영역에 부모 Section 표면과
삼각 무늬 Container를 차례로 그리면 두 반투명 색이 합성되어 원하지 않는 원본 색이 남는다.
Container 텍스처가 최종 표면인 구성에서는 부모 Section fill을 먼저 그리지 않고 실제 Container
path에 텍스처를 한 번만 그린다. 반투명은 화면 배경과의 관계에서 유지하며, 서로 겹친 두 표면으로
만들지 않는다. 회귀 test는 해당 모션 그룹 아래 배경/blur 표면의 개수를 검사해야 한다.
[@title-runtime] [@title-tests]

Title 패널에 속한 모든 최상위 Section은 최종 polygon path를 따르는 얇은 lifted shadow를 가진다.
기본 Title의 brand·primary action·account summary Section과 Title에서 호출되는 계정 editor·asset
picker·manager Section에 각각 한 번만 적용한다. shadow는 `defaultLiftedSectionShadow`의 2px
오프셋·4단 저대비 사양과 `paintLiftedPathShadow`를 재사용한다. Section fill에서 버튼 path를 차감해도
shadow는 차감 전 원래 Section path를 사용하며, 버튼·목록 행·입력 표면마다 Section shadow를 반복하지
않는다. shadow는 해당 Section의 motion subtree 안에 있어 호출·퇴장 중 표면과 같은 translation을
유지하고 hit test를 가로채지 않는다. [@title-runtime] [@account-runtime] [@title-tests]
[@lifted-path-shadow]

평행사변형 버튼의 정렬과 입력 영역은 점유 rect가 아니라 최종 polygon path를 기준으로 한다.
텍스트·아이콘 중심은 `path.getBounds().center`에 맞추고 hit target은 전체 path bounds에 둔 뒤
로컬로 이동한 같은 path로 clip한다. 따라서 사선 쪽의 label rect 밖을 눌러도 버튼이 동작해야
한다. 모서리 버튼의 간격도 Studio에서 확인한 밑변 간 거리를 기준값으로 삼고 각 빗변과 밑변에
같은 거리가 되도록 path geometry로 계산한다. [@title-runtime] [@title-tests]

Feature의 text는 작은 창에서도 박스를 넘지 않도록 제한된 rect 안에서 `FittedBox.scaleDown`을
사용한다. 좌측 정렬된 복수 text와 구분선은 각자의 원본 rect 왼쪽이 아니라 구분선의 실제 왼쪽
끝을 공통 기준으로 사용한다. Widget test는 작은 viewport에서 실제 text rect가 action rect를
넘지 않는지, 관련 text의 왼쪽 좌표가 line 좌표와 일치하는지를 검사한다. [@title-runtime]

이미지는 장식용 사각 widget을 이미지마다 중첩하지 않는다. `Image`를 `SizedBox.expand`,
`FractionallySizedBox`, 개별 `Stack`으로 감싸면 투명 asset의 실제 픽셀과 부모의 사각 layout box를
구분하기 어렵고, `BoxFit.contain`으로 축소된 이미지에는 부모 clip의 둥근 모서리가 닿지 않아
원본의 사각 배경이 그대로 보일 수 있다. 실제 화면에서는 `AssetImageGrid`가 asset을 `ui.Image`로
해석한 뒤 행·열, span, gap, scale로 계산한 셀에 `CustomPainter`로 직접 그린다. 둥근 clip이
필요하면 셀 rect가 아니라 `applyBoxFit` 결과인 실제 destination rect에 적용한다. [@asset-image-grid]

카드 이미지의 레이어 순서도 데이터로 명시한다. 타이틀 계정 카드에서는 `square.png`를 먼저
그리고 학생 portrait를 같은 셀의 98% 크기로 그 위에 놓는다. 원본 portrait가 사각 배경 픽셀을
포함할 수 있으므로 portrait의 실제 fitted rect를 둥글게 clip한다. 학생이 없거나 asset loading이
실패하면 페인터는 그 레이어를 생략하며 별도 색상 사각형 placeholder를 자동으로 만들지 않는다.
이 그리드 경로는 이후 학생 카드 목록처럼 다수 이미지를 렌더링할 때도 재사용하고, 이미지마다
새로운 배치 위젯 계층을 만들지 않는다. [@asset-image-grid] [@title-runtime]

화면 전환 방향은 Flutter의 양의 Y축이 아래쪽이라는 점을 포함해 수학적 화면 방향으로 계산한다.
각도 `d`의 이동 벡터는 `(cos(d), -sin(d))`이다. 타이틀의 Section 1·2는 270°로 아래쪽 퇴장하고
Section 3은 90°로 위쪽 퇴장한다. 중간 animation frame에서 translation의 Y 부호를 검사해 방향
반전을 방지한다. [@title-runtime] [@title-tests]

실제 화면 적용 완료 조건은 다음과 같다.

- Studio 원본 크기와 실제 path bounds가 기준 viewport에서 일치한다.
- 둥근 처리, 사선, 투명도와 무테 기본값이 Studio 속성을 보존한다.
- 텍스처 표면은 동일 영역에 기본 fill과 이중 합성되지 않는다.
- 모든 Title 최상위 Section은 같은 polygon과 motion을 공유하는 lifted shadow를 정확히 하나 가진다.
- 버튼 label 중심과 hit test가 동일한 최종 polygon path를 사용한다.
- 작은 viewport에서 text가 지정 rect를 벗어나지 않는다.
- 이미지 영역 아래에 `FractionallySizedBox`나 per-image `SizedBox.expand`가 생기지 않고 공용
  이미지 그리드가 직접 paint한다.
- 이미지 그리드는 빈 데이터와 실제 portrait가 있는 데이터를 모두 처리한다.
- 전환 animation의 중간 frame에서 각 Section의 이동 방향을 검증한다.
- `flutter analyze`, 관련 Widget test, 전체 Flutter test와 Windows release build를 통과한다.
[@title-tests]

### Title 계정 생성·관리 클러스터 적용

`section-account-create-manager.ba-section-studio.json`의 Section 1·4·5, Container 3~16·18·19와
Feature 4~8은 `accountStudioDocument`에 수치 그대로 투영한다. 특히 Container 15 목록 행 안의
Container 16 프로필 이미지와 Feature 5 계정명·Feature 6 구분선·Feature 7 보유 학생 수는 각각의
저장 좌표를 사용하고, Feature 8 polygon을 계정명 입력 표면과 clip 영역으로 사용한다. typed 문서의
encode 결과를 저장 JSON 전체와 비교해 누락된 저장이나 임시 runtime 좌표의 재도입을 막는다.
삼각 무늬 여부는 저장 JSON의 geometry가 아니라 사용자가 지정한 계정 관리 버튼·목록 행의 runtime
표현 규칙을 따른다. [@account-layout] [@title-tests]

Section의 남는 영역에만 기본 반투명 표면을 그리고, 삼각 무늬 버튼·목록 Container와 입력 표면은
Section path에서 차감한 뒤 각 polygon에 한 번만 그린다. 따라서 부모 Section fill과 자식 표면이
중복 합성되지 않는다. 목록 행의 hit target, 버튼 정렬과 입력 clip도 같은 최종 polygon path를
사용한다. [@account-runtime] [@title-tests]

첫 계정 생성은 Title Section 1·2가 퇴장한 뒤 Section 1만 진입한다. Title 설정은 Section 5만
진입하고, 추가·수정은 Section 1, 사진 변경은 Section 4를 중첩 호출한다. Section 5는 0°로
호출되고 180°로 퇴장하며, Section 1·4는 80°로 호출되고 260°로 퇴장한다. 비직교 각도는
`(cos(d), -sin(d))`의 두 축 성분을 모두 보존하며 호출 시작점은 호출 벡터의 반대편에 둔다.
Title로 돌아갈 때는 기존 Title 퇴장 controller를 reverse해 각 요소가 퇴장 방향의 반대로 등장한다.
[@account-runtime] [@title-tests]

Section 5·1·4는 각각 독립 animation controller를 가진다. Section 5에서 추가·수정으로 Section 1을
열 때 두 Section은 겹치지 않으므로 Section 5를 퇴장시키지 않는다. Section 4 닫기·저장은 Section
4만 퇴장시키고 Section 1을 유지한다. Section 1 뒤로는 첫 계정 경로에서는 Title로 돌아가고,
Section 5에서 시작한 경로에서 Section 4가 닫혀 있으면 Section 1만 퇴장시켜 Section 5로 돌아간다.
반면 Section 5·1·4가 모두 열린 상태에서 Section 1 뒤로를 누르면 Section 4, Section 1, Section 5를
차례로 퇴장시키고 Title로 돌아간다. [@account-runtime] [@title-tests]

Section 5의 Container 12·13·14·18·19는 같은 높이와 같은 세로 간격을 사용한다. 각 버튼의
우측 80° 사선은 Container 11의 실제 좌측 polygon 경계를 현재 viewport에서 샘플링한 뒤 일정한
pixel 간격만 남도록 폭을 다시 계산한다. 따라서 Studio의 top·height·left는 유지하되 폭은 창 크기와
Container 11 경계에 맞춰 유동적으로 강제한다. Container 11 자체에는 삼각 무늬를 그리지 않고 outline과 clip만 사용한다.
Container 15 목록 행은 좌우 내부 여백을 두고 Container 11 안에 놓으며, 스크롤 offset과 현재
viewport Y로 X를 다시 계산해 모든 가시 행이 사선 경계를 따라 이동한다. Container 11도 실제
vertical ScrollController를 값 원본으로 삼는 80° custom track·handle을 표시하며 wheel·drag·키보드
scroll 동작을 유지한다. [@account-layout]
[@account-runtime] [@title-tests]

Section 1의 계정명 입력은 별도 반투명 input surface를 합성하지 않는다. Section 기본 유리 표면
위에 TextField의 text·hint·cursor만 표시하고 모든 InputBorder와 fill을 끈다. 기존 계정명을 편집할
때 controller selection을 문자열 끝에 두고 LTR text direction을 명시한다. Windows IME의
composing text·selection·range는 controller listener로 변경하지 않는다. composing range가 활성인
동안에만 `showCursor`를 false로 두고, 조합이 확정되어 range가 비면 기본 cursor를 다시 표시한다.
Container 3 변경 버튼은 Container 4에 놓인 252×204
`square.png`의 전체 캔버스 폭이 아니라 중앙 정사각 이미지의 204px 한 변에 `BoxFit.contain`
배율을 적용한 길이로 보정하고, 두 path 중심을 잇는 선을 80°로 맞춘다. [@account-runtime]
[@title-tests]

프로필 사진은 계정 데이터의 `avatar_student_id`로 저장하며 기존 필드가 없는 profile summary는
`hasumi`를 기본값으로 읽는다. 사진 선택 목록은 asset manifest의 모든
`assets/student_portraits/*.png`를 4열 scroll grid로 구성한다. 각 셀은 `square.png` 뒤에 98%
portrait를 놓고, 간격·내부 여백·2% pink 선택 테두리와 hit cell을 하나의 `AssetImageGrid`
CustomPainter 경로에서 처리한다. 목록 행도 같은 painter를 사용하며 별도의 이미지 placeholder를
만들지 않는다. [@account-runtime]

Section 4의 portrait grid는 scroll offset에 따라 각 행의 viewport Y와 X를 함께 다시 계산한다.
모든 행은 위치와 무관하게 80°의 한 직선 궤적을 따라 위로 진행하고, 반대 방향은 260°가 된다.
수평 offset은 `x = (viewportHeight - y) / tan(80°)`로 계산한다. 수직 Scrollable·Scrollbar의
접근성 동작은 유지하고 painter 배치와 cell hit test에 같은 행별 X offset을 적용한다. 선택 강조는
cell의 둥근 사각형을 그리지 않고 실제 `square.png`의 alpha silhouette를 확대해 pink 외곽을 만든
뒤 원래 silhouette를 `dstOut`으로 제거한다. 따라서 투명 모서리와 기울어진 외곽까지 원본 이미지
모양을 따른다. [@asset-image-grid] [@account-runtime] [@title-tests]

Section 4의 scroll viewport 안에서는 grid painter에 viewport와 같은 tight width를 전달해야 한다.
`Stack`이나 `SingleChildScrollView`의 loose cross-axis constraint 때문에 paint 폭이 0으로 축소되지
않도록 하며, 실제 grid RenderBox 폭을 Container 8 폭과 대조한다. [@account-runtime] [@title-tests]

Section 4의 scrollbar는 기본 직선 Scrollbar paint를 사용하지 않는다. 실제 ScrollController의
viewport·max extent·offset을 값 원본으로 유지하면서 grid와 같은 고정 80° 직선 track과
handle을 그린다. handle drag의 수직 이동량은 실제 scroll 범위에 선형 매핑하고, handle 중심은
이동할 때 Y와 직선 기울기에 따른 X가 함께 바뀌며 반대 이동 방향은 260°다. wheel·키보드·기본 Scrollable 동작은 기존 controller를
계속 사용한다. [@account-runtime] [@title-tests]

Section 5의 각 계정 행은 Container 11의 수평 중앙을 지나는 80° 기준선에 중심을 맞춘다. 행의
viewport Y가 바뀌면 `1 / tan(80°)` 기울기로 X도 함께 바뀌므로 중앙 배치와 사선 스크롤을 동시에
유지하며, 행과 자식 portrait·text·line은 같은 translation을 공유한다. Title의 Space 시작 단축키는
Title Section이 화면에 남아 있고 account cluster가 닫힌 상태에서만 처리한다. [@account-runtime]
[@title-tests]

### 계정 클러스터 요소별 작업 스타일

계정 클러스터는 Section 단위로 세 UI archetype을 정의한다. Section 1은 이미지와 이름을 한 번에
편집하는 `editor`, Section 4는 다수의 asset 중 하나를 고르는 `asset picker`, Section 5는 여러
계정과 행 단위 행동을 제공하는 `manager`다. 이후 같은 archetype의 Section은 별도 디자인 지시가
없는 한 아래 스타일을 출발점으로 삼는다. Studio 번호는 설계 추적용이며, placeholder Container는
runtime에 빈 표면을 추가하라는 의미가 아니다. [@account-studio-document] [@account-layout]
[@account-runtime]

#### Section 1: 단일 항목 편집기

| 요소 | 역할 | 작업 스타일 |
|---|---|---|
| Container 3 | `변경` 버튼 | 최종 polygon path 중앙에 text를 배치하고 같은 path로 clip·hit test한다. 폭은 Container 4의 PNG 캔버스가 아니라 실제 square 이미지 한 변을 따르고 두 요소의 중심선은 80°로 맞춘다. |
| Container 4 | 프로필 이미지 기준 영역 | Studio에서는 크기·위치 placeholder다. runtime에서는 별도 placeholder 표면 대신 `square.png`를 먼저 그리고 98% portrait를 겹친다. 기본 portrait는 `hasumi`다. |
| Container 5 | 계정명 field group | label과 입력 영역을 묶는 구조적 부모다. 부모와 입력 표면의 반투명 fill을 중복 합성하지 않는다. |
| Feature 4 | `계정명 :` label | 저장된 text rect를 사용하고 입력값보다 먼저 읽히는 고정 label로 유지한다. 작은 viewport에서는 scale-down하되 입력 영역을 침범하지 않는다. |
| Feature 8 | 계정명 입력 영역 | polygon은 배치·clip·hit 영역으로 사용하되 진한 box, border, fill은 그리지 않는다. text·hint·cursor만 표시하며 IME composing 값은 변경하지 않는다. |
| Container 6 | `뒤로` 버튼 | 호출 출처를 기준으로 닫을 Section 집합을 결정한다. 최종 polygon 전체가 클릭 가능해야 하며 text는 path 중앙에 둔다. |
| Container 7 | `저장` 버튼 | 첫 계정과 관리 화면 편집의 저장 후 목적지를 분리한다. 저장 완료 전 화면을 먼저 닫지 않으며 polygon path를 시각·클릭 기준으로 공유한다. |

#### Section 4: asset 선택 그리드

| 요소 | 역할 | 작업 스타일 |
|---|---|---|
| Container 8 | 4열 portrait grid viewport | 좌우 내부 여백과 작은 cell gap을 두고 `AssetImageGrid`가 직접 paint한다. 일반 grid/list 규칙에 따라 80° 사선으로 스크롤하며 painter·hit test·scrollbar가 같은 변환을 쓴다. cross-axis에는 tight width를 전달한다. |
| grid cell | portrait 선택 항목 | `square.png` 위에 98% portrait를 쌓는다. 선택선은 사각 cell이 아니라 square asset의 alpha silhouette를 따라 약 2% pink 외곽선으로 그린다. 셀의 이미지 path와 hit target이 일치해야 한다. |
| Container 9 | `닫기` 버튼 | 선택 draft를 commit하지 않고 Section 4만 퇴장시킨다. |
| Container 10 | `저장` 버튼 | 현재 선택을 Section 1의 draft에 commit한 뒤 Section 4만 퇴장시킨다. |
| diagonal scrollbar | grid 위치 표시·drag | 기본 수직 Scrollbar를 시각 표면으로 사용하지 않는다. 실제 ScrollController를 유지하면서 80° track과 handle을 그리고, handle의 Y 이동을 scroll extent에 선형 매핑해 X도 함께 이동한다. |

#### Section 5: 선택 가능한 관리 목록

| 요소 | 역할 | 작업 스타일 |
|---|---|---|
| Container 11 | 계정 목록 viewport | 목록을 담는 구조적 outline·clip이며 삼각 무늬 fill을 그리지 않는다. 목록을 polygon의 시각적 중앙에 두고 80° 사선 scrollbar를 제공한다. |
| Container 15 | 반복 계정 행 template | 실제 목록에서는 데이터 개수만큼 반복한다. 삼각 무늬가 있는 polygon row로 그리고, row 전체 path를 선택 hit target으로 사용한다. 행과 모든 자식은 하나의 사선 scroll translation을 공유한다. |
| Container 16 | 행 portrait 기준 영역 | Studio에서는 이미지 크기·위치 placeholder다. runtime에서는 Section 1과 같은 square→98% portrait 레이어를 사용한다. |
| Feature 5 | 계정명 | Feature 6의 실제 왼쪽 끝을 공통 text 기준으로 삼고 긴 이름은 지정 rect 안에서 scale-down한다. |
| Feature 6 | 구분선 | 계정명과 학생 수의 정렬 기준이다. row path 안에서 둥근 cap의 얇은 선으로 그린다. |
| Feature 7 | 등록 학생 수 / 전체 학생 수 | Feature 5와 같은 왼쪽 기준을 사용하며 실제 profile 데이터에서 값을 만든다. |
| Container 12 | `이 계정으로 전환` | 선택된 행에 적용되는 주 행동이다. |
| Container 13 | `추가` | Section 5를 유지한 채 Section 1을 새 계정 mode로 연다. |
| Container 14 | `수정` | 선택 행이 있을 때 Section 1을 편집 mode로 연다. |
| Container 18 | `삭제` | 선택 행을 대상으로 확인 절차를 거친 뒤 삭제한다. |
| Container 19 | `뒤로` | Section 5를 퇴장시키고 Title을 퇴장 방향의 반대로 다시 호출한다. |

Container 12·13·14·18·19는 같은 높이와 같은 세로 간격을 갖는 하나의 action rail이다. 모두
삼각 무늬가 있는 사다리꼴 버튼으로 표현하고, 현재 viewport에서 Container 11의 실제 사선과 같은
간격을 남기도록 폭만 유동적으로 계산한다. label의 정렬과 hover·press·click 판정은 최종 polygon
path 하나를 공유한다. [@account-runtime] [@title-tests]

#### 유사 위젯에 적용할 기본 경향

- 여러 항목을 세로로 탐색하는 grid와 list는 별도 지시가 없으면 80° 사선 스크롤을 기본으로 한다.
  논리 scroll 값과 wheel·키보드·접근성 동작은 표준 수직 `Scrollable`과 `ScrollController`에 맡기고,
  보이는 행만 Y와 함께 X를 선형 이동시킨다. 역방향은 260°다.
- 사선 목록의 row painter, 자식 콘텐츠, 선택 highlight, hit test와 custom scrollbar는 각각 좌표를
  다시 추정하지 않고 하나의 trajectory 함수와 scroll offset을 공유한다.
- grid는 열 수·내부 여백·gap을 먼저 정하고 남은 폭에서 cell 크기를 구한다. asset의 투명 여백이
  있으면 layout rect가 아니라 실제 fitted image rect 또는 alpha silhouette를 시각 기준으로 삼는다.
- 반복 row의 Studio Container는 template이지 고정된 단일 widget이 아니다. 실제 데이터 수만큼
  생성하되 template의 path, 내부 상대 rect와 간격 계약을 보존한다.
- 이미지 placeholder Container는 runtime 장식이 아니라 asset 배치 기준이다. 별도 색상 box를
  자동 생성하지 않고 공용 image painter에서 base·foreground·selection 레이어를 처리한다.
- 행동 버튼은 사각 `Rect`가 아닌 최종 polygon을 정렬·clip·hover·hit test의 단일 기준으로 삼는다.
  인접 사선 Section이나 viewport 경계와의 간격은 고정 폭보다 실제 path 사이 거리로 보정한다.
- 밝은 삼각 무늬 행동 버튼은 Title 로고의 `#E08EE6`을 옅게 한 공용 보라빛 연핑크색 계열을 사용한다.
  진한 자주색, 고명도 분홍이나 하늘색 계열은 밝은 버튼의 대체
  팔레트로 사용하지 않으며, 정보·outline·scrollbar처럼 버튼이 아닌 역할에는 별도 색상 규칙을 둔다.
- 투명 Section 안의 입력·목록·버튼 표면은 부모 fill 위에 같은 색을 다시 칠하지 않는다. 최종적으로
  보여야 할 자식 path를 부모 표면에서 차감하거나 한 painter에서 한 번만 합성한다.
- 겹쳐 열릴 수 있는 Section은 각각 animation controller와 가시 상태를 소유한다. 닫기·저장·뒤로는
  action 이름만으로 일괄 처리하지 않고 호출 출처와 현재 열린 Section 집합으로 퇴장 대상을 정한다.
- text input은 플랫폼 IME의 composing 상태를 소유하지 않는다. 시각적 cursor 문제는 composing
  text·selection·range를 쓰지 않는 표시 계층에서만 해결한다.

이 경향은 새 화면을 기계적으로 동일하게 만드는 절대 규칙은 아니다. Studio 문서나 기능 명세가
다른 방향·형상·읽기 순서를 명시하면 그것이 우선한다. 다만 예외가 없다면 위 패턴을 사용하고,
예외를 둘 때는 painter·hit test·scrollbar·animation 검증도 함께 변경한다.
[@asset-image-grid] [@account-runtime] [@title-tests]

### 계정 클러스터 적용 시행착오와 재발 방지

이번 적용에서 가장 먼저 확인된 문제는 작업 지시를 받은 시점의 Studio 문서와 이후 사용자가 다시
저장한 문서의 좌표가 달랐다는 점이다. 임시 runtime 좌표나 앞선 export를 기준으로 보정하면 화면은
대략 비슷해도 Container 11~19와 Feature 5~8의 부모 상대 위치가 계속 어긋났다. 최종 저장 JSON을
다시 읽어 typed projection 전체를 교체하고, encode한 결과를 원본 JSON과 비교하는 test를 둔 뒤에야
배치 기준이 안정됐다. Studio 적용 작업은 구현 전에 파일 수정 시각과 실제 저장 내용을 재확인하고,
일부 좌표를 눈대중으로 덮어쓰지 않는다. [@account-studio-document] [@account-layout] [@title-tests]

배치와 스크롤에서 겪은 실패와 최종 판단은 다음과 같다.

| 시행착오 | 원인 | 최종 규칙 |
|---|---|---|
| 관리 버튼과 Container 11 사이 간격이 viewport마다 달라짐 | Studio의 고정 rect 폭만 사용하고 상대 polygon 경계를 보지 않음 | 버튼 높이·세로 간격은 같게 유지하되, 폭은 현재 viewport에서 Container 11의 실제 사선까지 같은 pixel 간격이 남도록 계산한다. |
| Container 11 목록이 오른쪽 테두리에 붙음 | 행의 사각 bounds를 정렬 기준으로 사용함 | 행 중심을 Container 11의 수평 중앙을 지나는 80° 기준선에 맞춘다. |
| 스크롤이 수직 또는 곡선으로 보임 | 처음에는 Y만 이동했고, 이후에는 위치별 곡선 보간을 사용함 | 모든 행은 고정 80° 직선 하나를 사용하며 역방향은 260°다. scroll offset에서 구한 Y와 `1 / tan(80°)`의 X를 함께 갱신한다. |
| 보이는 셀과 클릭 위치 또는 scrollbar가 어긋남 | painter, hit test, handle이 서로 다른 offset 계산을 사용함 | 행 paint·hit test·scrollbar track·handle drag가 같은 선형 변환과 같은 ScrollController를 공유한다. |
| Section 4에 Container만 보이고 portrait grid가 사라짐 | scroll 자식의 loose cross-axis constraint에서 CustomPaint 폭이 0으로 축소됨 | viewport 폭을 `StackFit.expand` 등으로 tight하게 전달하고 RenderBox 폭을 Container 8 폭과 test에서 비교한다. |
| 선택 강조가 square 이미지와 다른 둥근 사각형으로 보임 | 셀 RRect를 그대로 stroke함 | `square.png`의 alpha silhouette를 팽창한 뒤 원본 silhouette를 빼서 약 2% pink 외곽선을 만든다. |
| 변경 버튼 폭이 지나치게 김 | 252×204 PNG 캔버스 전체 폭을 이미지 한 변으로 해석함 | 중앙 정사각 이미지의 실제 204px 한 변에 `BoxFit.contain` 배율을 적용한 길이를 사용한다. |

Section 상태 전이는 한 개의 현재 화면 enum이나 공용 animation controller로 처리하기 어려웠다.
Section 5를 유지한 채 Section 1을 열고 다시 Section 4를 중첩할 수 있으므로 세 Section의 가시성과
animation 진행률을 독립적으로 소유해야 한다. 닫기와 뒤로의 의미도 호출 경로에 따라 다르다. 사진
선택의 닫기·저장은 Section 4만 닫고, 관리 화면에서 연 Section 1의 뒤로는 보통 Section 1만 닫는다.
다만 5·1·4가 모두 열린 상태에서 Section 1 뒤로를 누르는 경로는 세 Section을 퇴장시켜 Title로
돌아가도록 명시했다. 전역 Space shortcut도 Title widget의 존재만으로 판단하면 퇴장 후에 시작이
재호출되므로, Title이 실제 활성이고 account cluster가 닫힌 상태를 함께 검사한다. 각 경로는 최종
화면뿐 아니라 animation 중간 frame의 X·Y 부호와 남아 있는 Section 집합을 test한다.
[@account-runtime] [@title-tests]

계정명 입력에서는 시각 문제와 IME 상태 문제를 분리하지 않은 보정이 가장 큰 회귀를 만들었다.
처음의 기본 Flutter 입력은 한글 조합 자체는 정상이나 조합 중 cursor가 글자 왼쪽에 보였다. 입력
표면의 진한 박스는 `TextField`의 border와 fill을 제거하는 것으로 해결할 수 있었지만, cursor 위치를
고치려고 controller listener에서 매 composing update의 selection을 `composing.end`로 다시 쓰자
Windows IME와 Flutter가 서로 편집 상태를 되돌려 보내며 `거`가 `ㄱ거거`로 중복됐다. Alt+Tab으로
focus가 바뀔 때 미확정 조합이 다시 commit되면서 순서까지 달라지는 현상도 같은 상태 왕복의 결과였다.

따라서 플랫폼 IME가 소유한 `TextEditingValue.text`, `selection`, `composing`은 조합 중 절대
수정하지 않는다. `ValueListenableBuilder`는 값을 관찰만 하고 composing range가 활성인 동안
`showCursor: false`를 적용한다. commit으로 range가 비면 기본 cursor를 다시 표시한다. test는 한글
문자열뿐 아니라 IME가 보낸 selection과 composing range가 그대로 보존되는지, commit 전후 cursor
가시성만 달라지는지를 함께 검증한다. cursor 위치가 이상하다는 이유만으로 composing selection을
정규화하거나 focus 전환 시 text를 재설정하지 않는다. [@account-runtime] [@title-tests]

이 작업에서 얻은 검증 순서는 `저장 JSON → typed projection 동일성 → 기준 viewport path bounds
→ 작은 viewport의 동적 간격 → painter와 hit test 좌표 일치 → animation 중간 frame → 실제
Windows IME 조합·focus 전환`이다. 정적 golden이나 최종 frame만으로는 폭 0 grid, 반대 방향 전환,
보이지 않는 전역 shortcut, IME composing 회귀를 잡을 수 없으므로 관련 Widget test와 Windows 수동
입력 검증을 함께 수행한다.

## 검증 계약

- Section rect는 96×96 범위 안에 있어야 한다.
- Container/Feature rect는 부모의 0~1 비율 범위 안에 있어야 한다.
- 본체 드래그는 요소 크기를 유지한 채 X·Y를 정수 셀로 이동하고 캔버스 경계에서 멈춘다.
- 네 모서리 리사이즈는 반대 모서리를 고정하고 최소 폭·높이 1칸을 보장하며 96×96 경계를
  넘지 않는다.
- 핸들 판정은 pan threshold 이후가 아니라 최초 pointer-down 좌표에서 확정한다.
- 요소 rect의 중첩은 validator 경고로 표시한다.
- Section은 하나의 96×96 그리드를 공유하고 하위 요소는 부모 상대 자유 배치를 사용한다.
- 하위 요소는 실제 polygon path가 부모 path를 벗어나거나, 설정된 부모 테두리 최단거리와
  형제 아이템 path 사이 최단거리보다 가까우면 경고한다.
- 개별 요소 rect는 렌더링 clip 영역으로 사용하지 않는다.
- 붙는 면은 요소 geometry의 실제 외곽면이어야 한다.
- `faceStart + faceSpan`과 높이는 96 범위를 넘지 않도록 자동 보정한다.
- 삼각형에는 높이 입력을 표시하지 않는다.
- 모든 사선은 우측 위 `/` 80도 방향을 유지한다.
- 선택 요소의 부착면 눈금, 콘텐츠 안전영역, 전체 그리드는 독립적으로 표시한다.
- 상단 헤더는 기본 8/96이고 0/96~48/96 범위에서 조절한다. 0은 헤더 widget을 그리지 않는다.
  geometry는 남은 콘텐츠
  영역만 새로운 전체 캔버스로 사용한다.

`채팅용 요약 복사`는 공용 그리드·헤더·요소 수를 먼저 기록하고 모든 요소의 rect, 도형,
붙는 면, 면 범위, 높이를 순서대로 직렬화한다. 사용자는 전체 구성을 채팅에 그대로 붙여 넣어
승인이나 수정을 요청할 수 있다. [@studio-page]

## 구성 저장과 불러오기

Studio 구성은 사람이 읽고 diff할 수 있는 UTF-8 JSON으로 저장하며 기본 파일명은
`section-template.ba-section-studio.json`이다. 문서는 `ba-planner-section-studio` format과
정수 version을 맨 앞에 두고 Section 96×96 grid, 하위 요소 부모 상대 배치와 공통 간격, 우측 위 80° diagonal 계약, workspace의 헤더·viewport·
표시 옵션·활성 레이어와 선택 ID, 모든 section/container/feature의 ID·부모 ID·rect·shape·image
metadata를 기록한다. version 5가 0% 헤더, Container 삼각 무늬와 image preset·text·line metadata를
저장한다. version 4는 새 필드의 안전한 기본값으로 읽고 version 1~3 파일의 하위 96 좌표는
불러올 때 0~1 비율로 변환한다. JSON에는 앱 실행 상태나
실제 기능 데이터는 포함하지 않는다. [@studio-document]

불러오기는 JSON root와 format/version, Section 96×96·하위 배치 모드·간격 및 80° 고정 계약, workspace 타입과 범위,
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

Widget test는 Section 96×96 validator, 하위 부모 경계·형제 간격 snap, 공용 캔버스 밖이 아닌 점유 rect 밖 경로의 보존, 공용 path
hit test, 요소 추가·선택·편집, 이동·네 모서리 리사이즈·경계 clamp, 헤더 비율,
요약 복사, viewport 전환, 예각의 볼록 fillet과 개발 패널 진입을 검증한다. 저장 문서 test는
전체 값 round-trip, v1 호환, 계층 부모 관계, schema·버전·범위·중복 ID 거부, service 기반
저장·불러오기·ID 재매핑 import와 실패 시 원자적 상태 보존을 검증한다. 레이어 test는 부모 clip,
부모 상대 배치, 네 Feature 종류, image preset과 이미지 비율 고정 resize, 0% 헤더와 Container
삼각 무늬를 검증한다. [@studio-tests] [@studio-document-tests]

## 현재 경계와 다음 확장

`SectionCanvasPainter`는 Studio 실험용 렌더러이며 기존 실제 페이지의 `DiagonalSection`을
자동 교체하지 않는다. 다음 확장 후보는 요소 이름 편집, 사선 seam 적합성 검사와 Dart spec
export다. 승인된 형상을 실제 UI에 적용할 때 공용
`SectionGeometry` 승격 범위를 별도로 결정한다. [@studio-surface]

## 학생 탭 Section 1~4 토대 적용

`release/section-student.ba-section-studio.json`의 Section 1~4와 Container 1~7·9~14·16,
Feature 2~5는 `studentStudioDocument`의 typed runtime projection으로 관리한다. Section 1의
Container 16·13·11은 저장 문서의 역할과 세로 순서를 유지하되 실제 화면에서는 같은 높이와 같은
간격으로 정규화한다. 버튼의 크기는 독립 픽셀이 아니라 Section 1의 inset·버튼 간 gap에서 역산하고,
세 버튼에는 공용 보라빛 연핑크 BA 삼각형 texture를 적용하되 다른 학생 상태 Container의 어두운
texture에는 이 팔레트를 전파하지 않는다. 각 버튼의 오른쪽 끝은 Section 1의 80° 경계와 평행하며
같은 inset을 유지하도록 행별 폭을 역산한다. 버튼 아이콘은 점유 bounds 중앙이 아니라 높이의 절반인
Y에서 사다리꼴의 실제 수평 길이를 계산하고 그 선분의 절반 X에 배치한다. Section 1과 Section 2의 마주 보는 80°
빗면은 모든 viewport에서 12 px 간격을 유지한다. Section 4의 Container 14는 Studio 제안 높이의
절반인 normalized 0.14를 사용한다. Section 4는 오른쪽 끝을 유지한 채 왼쪽 길이를 runtime에서
조정해 Section 3의 왼쪽 빗면과 같은 80° 무한 직선을 공유한다. 학생 canvas 위의 repository profile
selector와 canvas 아래의 기존 repository editor Section은 제거하며 현재 선택 profile은 화면 진입 시
service에서 직접 복원한다.

Section 2는 Container 12 하나만 소유하는 공용 사선 grid viewport다. 표준 수직 ScrollController가
scroll extent를 소유하고, 모든 가시 행은 viewport Y에 따라 `1 / tan(80°)`만큼 X를 함께 이동한다.
계정 portrait picker와 같은 `gridInset=8`을 유지하고 8열의 가로 gap은 4.8, 행 gap은 그 80%인
3.84 px를 적용한다.
80° custom scrollbar의 trajectory와 14 px 전용 폭을 먼저 제외한 나머지 폭으로 셀 크기를 역산한다.
`square.png`는 셀 전체 크기, portrait는 98% 크기로 확대한다. `square.png`와
portrait는 전체 grid의 단일 `AssetImageGrid` painter에서 순서대로 그린다. 별도의 overlay painter는
`square.png`의 alpha를 최종 mask로 사용해 카드 하단 16%에만 정보를 합성한다. 이 영역의 상단 3%는
v6 학생 카드와 같은 좌우 공격/방어 속성 색상 띠이고, 남은 13%는 회색 반투명 이름 영역과 흰색 이름이다.
Section 4의 `학생 공격/방어 속성 표시`, `학생 이름 표시` checkbox가 두 overlay를 독립적으로
토글한다. `미보유 학생 숨김`은 repository 보유 ID 집합을, `일본 서버 전용 숨김`은 protocol v1의
`jp_only` 정적 metadata를 기준으로 grid 항목을 제외한다. 셀 hit target과 overlay painter는 같은 행 offset을 공유한다. Mock runtime도 backend
metadata에서 생성한 `assets/student_catalog.json`의 265명을 전부 사용한다.
검색은 `StudentCatalogEntry.searchTags`와 `krSearchTags`를 그대로 사용하므로 v6에서 이관한
`하나코(수영복) → 수나코` 같은 대체 이름이 별도 UI alias 표 없이 동작한다.

Section 3은 이 단계에서 Container 토대만 소유한다. Container 1과 3은 placeholder이므로 runtime
surface·outline을 그리지 않는다. Container 1 영역에는 `square.png` 뒤에 선택 portrait만 겹치고,
Container 2의 Feature 2~5는 삼각 무늬 없이 단색으로 그린다. Container 3 영역에는 앞 5칸 학생
성작과 뒤 4칸 무기 성작을 같은 평행사변형 strip으로 표시하며 repository 값이 없는 칸은 muted
outline 색으로 남긴다. portrait·성작 strip·Container 5·6·7·9의 왼쪽 끝은 같은 80° rail에,
Container 5·6·7·9의 오른쪽 끝은 별도의 같은 80° rail에 맞춘다. Container 4~7·9·10의 텍스트와
세부 indicator는 후속 작업 범위다. Container 5·6·7·9의 세로 gap은 한 값으로 정규화하며 그 값을
Container 4의 왼쪽 80° rail과 상태 Container 오른쪽 rail 사이의 법선 거리에도 재사용한다. 성작
9칸의 양쪽 변과 학생 grid scrollbar track도 화면 좌표 기준 80°를 사용한다.

Container 12와 Container 2·4는 Container 5·6·7·9와 같은 어두운 상태용 삼각 texture·outline을
사용한다. Container 10만 Section 1 행동 버튼과 같은 연핑크 행동 texture를 사용한다. Filter 행동은
Section 2를 260°로 완전히 퇴장시킨 뒤 Section 5로 교체하고 Section 5를 80°로
진입시킨다. 다시 누르면 같은 순서로 Section 5에서 Section 2로 복귀한다. Section별 motion은
  Section 1 `intro 0° / outro 180°`, Section 2·5 `80° / 260°`, Section 3·4 `180° / 0°`다.
  runtime은 forward 중 각 Section의 intro 벡터를 사용하고 reverse 중에는 해당 Section의 outro
  벡터를 직접 사용한다. outro를 intro의 반대 방향이라고 암묵적으로 추론하거나 검증용 값으로만
  남겨 두지 않는다.
학생 탭은 AppShell의 페이지 단위 translation에서 제외한다. 탭 진입 시 이전 탭의 퇴장이 끝난
경계에서 `StudentPage.active`를 켜고 Section 1~4의 controller가 각자의 intro를 시작한다. 탭 퇴장
시에는 `active`를 먼저 끄고 같은 controller를 reverse하여 각자의 outro를 사용한다. 따라서
페이지 전체의 90°/270° 이동을 Section motion과 합성하지 않으며, 학생 페이지와 선택·filter 상태는
기존처럼 mount된 채 motion lifecycle만 탭 활성 상태에 연결한다.
Section 5는 Section 2의 높이와 왼쪽 80° rail을 유지하되 윗변과 밑변 길이를 모두 Section 2의
50%로 줄여 평행사변형을 유지한다. 내부 Container 12도 축소된 Section 5 bounds에서 normalized
placement를 다시 계산하고 최종 Section path와 교차해 바깥으로 넘치지 않게 한다. Filter 버튼은
Section 5가 열린 동안 `tune_rounded` 대신 현재 학생 탭과 같은 `groups_2_outlined` 아이콘을 표시한다.
각 foundation painter는 hit test를 받지 않아 위 레이어의 빈 영역이 아래 학생 grid 입력을 막지 않는다.

Section 1~4는 공통 alpha 0.76의 반투명 기본 표면을 사용하고 각각 최종 polygon path에
`defaultLiftedSectionShadow`를 정확히 한 번 적용한다.
Section 자체 outline은 그리지 않는다. 최종 child surface가 있는 부분은 parent fill에서 차감해
반투명 색이 중복 합성되지 않게 한다.
겹치는 Section 1은 Section 2 뒤에 paint하여 좌측 행동 rail의 shadow와 hit target이 목록에 가려지지
않는다. [@responsive-policy] [@asset-image-grid] [@lifted-path-shadow]

이 절과 아래 후속 계약이 학생 탭의 현행 기준이다. “최초 토대와 피드백 반영 결과” 표의 최초
열과 workflow의 날짜별 기록은 변경 이유를 보존하는 이력이며 현재 기본값이 아니다. 충돌할 때는
현재 runtime과 회귀 test, 이 절의 현행 계약, 회고 이력 순으로 판정한다.

## 계획 탭 Section 1~5 토대

`release/section-plan-main.ba-section-studio.json`의 다섯 Section을
`planStudioDocument`의 typed runtime projection으로 관리한다. 최초 배치는 저장 문서의 96×96
좌표를 그대로 사용하며 Section 1 `(0,2,37,92)`, Section 2 `(12,2,29,94)`, Section 3
`(45,2,42,92)`, Section 4 `(89,14,7,80)`, Section 5 `(53,1,42,14)`다.
Section 3은 bottom 부착 깊이 80, Section 5는 top 부착 깊이 96을 사용한다. 최초에는
Section 1·3·4를 비우고 Section 2만 공통 페이즈 표시의 UI 토대를 두었다.

Section별 motion은 Section 1 `intro 0° / outro 180°`, Section 2·3
`intro 80° / outro 260°`, Section 4 `intro 180° / outro 0°`, Section 5
`intro 260° / outro 80°`를 직접 사용한다. 계획 탭도 학생 탭과 같이 AppShell의 페이지 단위
translation에서 제외하며, 탭 진입·퇴장 lifecycle을 다섯 Section의 독립 controller에 연결한다.
각 Section은 공통 alpha 0.76 surface와 최종 polygon path에 `defaultLiftedSectionShadow`를
정확히 한 번 적용하고 별도 outline은 그리지 않는다. 겹치는 Section 1은 Section 2보다 뒤에,
Section 5는 재화 본문 Section 3보다 뒤에 paint한다. [@lifted-path-shadow]

최초 실화면에서는 계획 페이지가 AppShell의 공용 BA 삼각 배경 위에 `AppColors.canvas` 72%를
전면 합성한 뒤 다시 Section surface를 합성해 학생 탭보다 배경과 Section이 함께 어두워졌다.
계획 페이지 전용 canvas fill을 제거하고 투명 layout host만 유지하여 공용 배경 위에 Section
surface가 한 번만 합성되도록 보정한다. Section 색·alpha·shadow와 motion은 변경하지 않는다.

Section 2는 최종 Section path에서 10px 안쪽에 같은 80° 방향의 내부 평행사변형 Container를
두고 BA 삼각 texture와 얇은 outline을 적용한다. 내부에는 읽기 전용 페이즈 카드를
`페이즈 순서 → 페이즈 내부 학생 단계 순서`로 배치한다. 각 카드는 높이에 따른 자체 사선
깊이를 폭 산식에 포함하고 scroll offset에 따라 X도 함께 이동해 하나의 80° rail을 따른다.
전용 scrollbar track과 handle도 같은 rail을 사용한다.

초기 더미 데이터는 4개 공통 페이즈와 시로코 1·2·3단계를 포함한다. portrait는 새 복사본을
만들지 않고 v6 `templates/students_portraits`에서 이관되어 SHA-256이 같은 기존
`frontend/assets/student_portraits`를 사용한다. 이 더미는 레이아웃 검수 전용이며 실제 계획,
프리셋 또는 시나리오 저장 상태로 취급하지 않는다. 계획은 공통 페이즈, 시나리오는 개별
페이즈를 가지며 시나리오 재화는 계획 계산에 합치지 않는다는 데이터 경계는 후속 구현에서도
유지한다.

### 계획 탭 Section 3 본문과 Section 5 재화 헤더

최초 구현에서는 Section 3이 재화 헤더와 이후 본문 자리를 함께 소유했다. 탭별 전환 시
헤더와 결과 surface의 motion을 분리하기 위해 Studio JSON에 Section 5를 추가하고, 재화 헤더
전체를 Section 5로 옮겼다. Section 3은 bottom 부착 깊이를 96에서 80으로 줄여 Section 5 아래의
재화 결과 본문 자리를 만든다. Section 5는 x를 53으로 두어 Section 3과 같은 80° 무한 rail에
맞추고 y를 1로 내려 공용 페이지 헤더에서 한 grid 떨어뜨린다. Section 5 하단과 Section 3
상단의 간격은 약 2.33 grid로, Section 3 하단과 canvas 바닥의 2 grid 여백에 가깝게 맞춘다.

Section 5는 자체 평행사변형을 AppShell 공용 compound header의 바깥 L-glass에 대응하는
외곽 surface로 사용한다. Section 5 자체에 다른 계획 Section과 같은 alpha 0.76 glass fill과
lifted shadow를 적용한다. 내부에는 `페이즈별 / 전체 / 병목` 탭 선반, outline divider와 중첩된
재화 헤더 surface를 둔다. 탭의 선택 배경, primary 하단선, icon·label 색과 전환 시간은 AppShell
상단 탭의 시각 문법을 따른다.

탭 선반의 좌우 끝은 선반 중심 Y에서 Section 5의 두 80° 경계를 계산한 뒤 10px 안쪽으로
들어간다. 중첩 헤더는 자체 bounds의 네 꼭짓점을 위·아래 Y에서 다시 계산해 부모와 같은
두 80° rail을 따르는 평행사변형으로 만든다. 내부 title·subtitle 안전 영역은 위쪽 왼쪽
경계와 아래쪽 오른쪽 경계 중 더 좁은 구간을 사용하므로 텍스트가 사선에 닿지 않는다.
중첩 surface는 AppShell 페이지 헤더와 같은 palette·seed의 BA 삼각 texture, 얇은 outline과
lifted shadow를 사용한다.

Section 5의 낮은 높이는 viewport에 따라 탭과 중첩 헤더 높이를 함께 축소한다. title·subtitle
두 줄을 안전하게 담을 수 없는 높이에서는 title만 유지한다. 이 단계는 Section 5 헤더와 탭
선택에 따른 copy 전환까지만 구현한다. Section 3 부족 재화 본문, repository/API 연결,
페이즈별·전체·병목 계산 결과는 후속 범위다.

## 학생 탭 최초 토대와 피드백 반영 결과

이 절은 학생 탭을 처음 구성했을 때의 토대와 반복 피드백 뒤 확정된 결과를 구분한다. Studio JSON의
값은 시작점이지 runtime의 최종 크기·간격 계약이 아니었다. 특히 사선 사이의 거리는 단순 bounds가
아니라 같은 화면 좌표에서의 평행선 법선 거리로 검토해야 했고, placeholder와 실제 surface도 구분해야
했다. 아래의 “최초”는 최초 요구와 첫 구현에서 채택한 일반형 해석이며, “확정”은 이후 사용자 피드백과
검증 test가 고정한 현재 계약이다. [@student-studio-document] [@student-layout] [@student-runtime]

| 항목 | 최초 토대·초기 해석 | 피드백 이후 확정된 계약 | 재사용 시 교훈 |
|---|---|---|---|
| 화면 범위 | Section 1~4를 배치하고 기존 하단 편집 영역을 함께 유지했다. | 헤더 사이와 canvas 하단의 legacy 영역을 제거하고 Section 1~4, 전환 중의 Section 5만 남긴다. | 새 토대를 추가하기 전에 유지·제거할 기존 영역을 명시한다. |
| Section 외곽 | 일반 outline과 shadow를 함께 쓰는 보통 glass section으로 해석했다. | Section outline은 없고 alpha 0.76 surface와 lifted shadow만 사용한다. child surface는 parent fill에서 차감한다. | border, shadow, transparency는 서로 독립된 질문이다. |
| Section 1 버튼 | Studio의 개별 rect와 일반 bounds 중앙 정렬을 우선했다. | 세 버튼 크기는 Section inset과 동일 gap에서 유동 계산한다. 오른쪽 사선 inset까지 포함하고 아이콘은 중간 Y의 실제 수평 선분 중앙에 둔다. | 사다리꼴 자식은 bounding-box 중앙을 사용하지 않는다. |
| Section 1 texture | 버튼별 색만 유지하고 무늬는 후속으로 보았다. | 세 버튼 모두 연핑크 BA 삼각 texture를 사용한다. Container 10도 같은 action 역할이며 Container 4는 status 역할이다. | “같은 효과”가 fill, texture, outline, shadow 중 무엇인지 묻는다. |
| Section 1·2 관계 | 두 section을 독립 rect로 배치했다. | 마주 보는 80° 사선 사이에 모든 viewport에서 12px의 명시적 평행 gap을 둔다. | 인접 사선은 각 section 좌표가 아니라 공유 seam 계약으로 설계한다. |
| Section 2 구조 | 반복 카드나 복수 container 가능성을 남기고 소수 sample 학생을 먼저 표시했다. | Container 12 하나 안에서 전체 265명 catalog를 8열 단일 grid painter로 렌더링한다. | sample 데이터가 최종 데이터 범위로 오인되지 않게 전체/부분 여부를 먼저 묻는다. |
| Section 2 간격·scroll | 일반 grid gap과 수직 scrollbar를 사용했다. | 외곽 inset 8, 열 gap 4.8, 행 gap 3.84이며 scrollbar의 14px 예약 폭을 cell 산식에서 먼저 뺀다. 행과 scrollbar는 80° trajectory를 공유한다. | 사선 scroll은 painter, hit test, content와 handle이 한 변환을 공유해야 한다. |
| 학생 카드 | portrait만 표시하고 이름과 속성은 후속으로 두었다. | `square.png` alpha 안의 하단 16%를 사용한다. 상단 3%는 v6 공격/방어 색상 띠, 나머지 13%는 반투명 회색 이름 영역과 흰색 이름이다. | overlay 비율, 층 순서, mask 기준을 숫자로 확인한다. |
| Section 3 placeholder | Container 1·3도 일반 surface처럼 그렸다. | Container 1·3 surface를 제거하고 내부 portrait와 9개 성작 평행사변형만 남긴다. | “컨테이너”가 시각 surface인지 배치 placeholder인지 확인한다. |
| Section 3 정렬 | 각 container의 저장 rect를 개별 적용했다. | portrait·성작·5·6·7·9의 왼쪽은 한 80° rail, 5·6·7·9의 오른쪽은 다른 한 rail에 맞춘다. 4와 stack의 간격도 stack 내부 gap과 같다. | 여러 요소가 같은 사선에 맞는지는 공통 rail로 모델링한다. |
| Section 4 | 높은 검색 입력 하나만 우선 배치했다. | 검색 bar 높이와 상단 inset을 줄이고 text를 수직 중앙에 둔다. 속성·이름 표시, 미보유·JP 전용 숨김의 네 toggle을 둔다. | 검색, 표시 옵션, 데이터 제외 filter를 별도 상태로 구분한다. |
| 데이터·정렬 | sample 학생과 화면용 이름을 직접 둘 수 있었다. | backend catalog 전체, 한국어 display name 정렬, v6 alias, repository 보유 ID, protocol의 `jp_only`를 사용한다. | UI filter에 필요한 정적 metadata가 protocol에 있는지 먼저 확인한다. |
| Section 5 | Section 2와 같은 geometry의 빈 교체 영역으로 시작했다. | 높이와 왼쪽 rail은 유지하고 윗변·밑변과 내부 Container를 50%로 줄인 평행사변형이다. | 외곽만 바꾸지 말고 내부 normalized container도 새 path에서 다시 계산한다. |
| 전환·역할 표시 | 정적인 네 section을 우선했다. | Section 1=0/180, Section 2·5=80/260, Section 3·4=180/0이다. Filter 버튼은 Section 5에서 학생 탭 아이콘으로 바뀐다. | 상태가 버튼의 역할을 바꾸면 tooltip과 icon도 함께 바꾼다. |
| 탭 호출 lifecycle | AppShell의 공용 페이지 이동과 내부 Section 이동을 함께 적용했다. | 학생 페이지 자체 translation은 끄고, 이전 탭 퇴장 완료 뒤 Section별 intro를 시작한다. 학생 탭 퇴장 시에는 Section별 controller가 각자의 outro로 reverse한다. | 페이지 전환과 내부 Section 전환을 합성할지 먼저 정하고, 독립 motion이면 탭 활성 lifecycle을 자식에게 명시적으로 전달한다. |

현재 runtime과 회귀 test는 위 확정 계약을 기준으로 한다. 이후 Studio 값이나 유사 화면을 가져올 때
표의 “최초 토대”를 기본값으로 되돌리지 않는다. [@student-runtime] [@student-tests]

## 유사 Section 작업 전 사용자 확인 질문

유사 Section은 모양이 닮았다는 이유만으로 학생 탭의 모든 수치를 복사하지 않는다. 먼저 almanac과
기존 runtime을 읽고 이미 답이 있는 항목은 다시 묻지 않는다. 답이 없고 결과를 크게 바꾸는 항목은
아래 순서로 사용자에게 확인한다. 한 번에 전부 묻기보다 현재 단계에 필요한 3~7개만 묶고, 질문에는
현재 참고한 Section과 제안 기본값을 함께 적는다. [@student-runtime] [@responsive-policy]

### 첫 확인: 범위와 기준

1. “이 화면에서 유지할 기존 Section과 제거할 legacy 영역은 각각 무엇인가요?”
2. “Studio JSON의 좌표를 그대로 고정할까요, 아니면 현재 Section의 inset·gap·사선 rail을 우선하는 비율형 토대로 사용할까요?”
3. “참고할 기존 화면은 학생 탭의 어느 Section인가요? 모양만 같은가요, texture·motion·데이터 동작까지 같은가요?”
4. “이번 단계는 container 토대까지만인가요, 아니면 text·indicator·실제 데이터 연결까지 포함하나요?”

### 형상과 시각 효과

5. “각 Section의 사선 각도와 intro/outro 방향은 무엇이며, 두 방향은 정확히 반대 trajectory인가요?”
6. “인접 Section의 빗면 간격은 수평 bounds 차이인가요, 평행 사선의 법선 거리인가요? 목표 pixel 값은 얼마인가요?”
7. “Section 외곽에 border가 필요한가요? shadow와 반투명 alpha는 각각 어떤 기존 Section을 따라야 하나요?”
8. “내부 요소 중 실제 surface와 위치만 잡는 placeholder는 각각 무엇인가요?”
9. “여러 container의 좌우 끝이 같은 사선 rail에 맞아야 하나요? 맞는다면 어느 요소가 기준 anchor인가요?”
10. “효과를 같게 한다는 뜻이 fill, 삼각 texture, outline, shadow, hover/press 중 어디까지인가요?”

### 내부 배치와 반응형 계산

11. “자식 크기는 고정값인가요, 아니면 Section 외곽 inset과 자식 간 gap을 먼저 정한 뒤 남은 공간에서 계산하나요?”
12. “사다리꼴 안의 icon/text 중앙은 bounds 중앙인가요, 해당 Y에서의 실제 수평 선분 중앙인가요?”
13. “grid/list의 열 수, 외곽 inset, 가로·세로 gap, scrollbar 예약 폭은 각각 얼마인가요?”
14. “scroll 시 행·내용·선택선·hit target·scrollbar가 같은 사선 trajectory를 따라야 하나요?”
15. “최소 검수 viewport는 무엇인가요? 예: 960×590, 1280×720, 1440×900.”

### 데이터와 상호작용

16. “초기 sample만 표시할까요, 사용 가능한 전체 catalog를 표시할까요? 정렬 기준과 동률 처리 기준은 무엇인가요?”
17. “검색은 display name 외에 v6 alias, 한국어 별명, 영문 tag 중 어디까지 포함하나요?”
18. “표시 toggle과 데이터 제외 filter는 무엇이며 기본 checked 상태와 화면 재진입 시 유지 여부는 어떻게 하나요?”
19. “미보유·서버 전용 같은 filter에 필요한 metadata가 현재 protocol에 있나요, 아니면 backend 계약 확장이 필요한가요?”
20. “카드 overlay가 있다면 전체 높이 중 각 영역 비율, 색상 출처, text 색, alpha mask asset은 무엇인가요?”
21. “상태 전환으로 버튼 역할이 바뀔 때 icon, tooltip, enabled 조건도 함께 바뀌어야 하나요?”
22. “전환은 기존 Section 퇴장 완료 후 새 Section 진입인가요, 아니면 두 Section이 겹쳐 교차 전환하나요?”

질문 답변은 구현 전 geometry·effect·data·motion 계약으로 짧게 다시 요약한다. 사용자가 “기존 학생
Section과 동일”이라고 답하면 동일 범위를 다시 명시해 확인하고, 저장 JSON의 숫자보다 이 합의된
계약과 현재 almanac을 우선한다. [@student-layout] [@student-catalog-dto] [@student-catalog-protocol]

### 다수 요구의 작업 분리 승인

Section 추가 요청에 서로 독립적인 요구가 많으면 한 번에 모두 구현하지 않는다. 다음 중 하나라도
해당하면 먼저 작업 분리안을 제시하고, 그 단위로 진행해도 되는지 사용자에게 묻는다.

- 둘 이상의 Section geometry를 동시에 새로 만들거나 바꾼다.
- geometry, texture/effect, runtime data, interaction/motion 중 셋 이상을 함께 바꾼다.
- UI 변경과 backend/protocol 계약 변경이 함께 필요하다.
- 전체 catalog, 검색 alias, filter처럼 데이터 정확성 검증이 필요한 작업이 포함된다.
- 기존 Section을 재사용하지만 어느 속성까지 같게 할지 확정되지 않았다.
- 한 번의 구현으로는 각 단계의 시각 검수 결과가 다음 단계 배치를 크게 바꿀 수 있다.

이때 다음처럼 구체적인 분리안과 순서를 제안한다.

> 요청을 ① Section 외곽과 rail, ② 내부 container와 간격, ③ texture·overlay, ④ 실제 데이터·filter,
> ⑤ motion·상태 전환으로 나누어 각 단계 확인 후 다음 단계로 진행해도 될까요? 먼저 ①~②의 토대를
> 고정하면 이후 effect와 데이터 작업의 재배치를 줄일 수 있습니다.

사용자가 분리 진행을 승인하면 각 단위마다 구현, 집중 검증, 변경 요약을 마친 뒤 다음 단위로 넘어간다.
각 단계가 끝날 때 남은 요구를 다시 열거해 누락을 방지한다. 사용자가 일괄 진행을 원하면 전체 범위를
유지하되 같은 단위를 내부 milestone로 사용하고, 서로 독립적으로 검증 가능한 결과를 중간 update로
알린다. 단순히 요청 항목 수가 많다는 이유만으로 범위를 임의 축소하거나 일부를 다음 작업으로
미루지는 않는다. 분리는 사용자 승인과 검수 순서를 위한 것이며 요청 범위를 바꾸는 절차가 아니다.
[@student-tests] [@responsive-policy]

### 유사 Section 참조 확인 우선

새 Section을 만들기 전에 현재 runtime과 almanac에서 형태·역할이 가까운 Section을 먼저 찾는다.
후보를 찾으면 “비슷한 Section을 참고할까요?”처럼 추상적으로 묻지 않고, 재사용하려는 속성과 새로
정할 속성을 분리해 질문한다. 이름이나 번호가 같은 Container라도 다른 탭에서는 역할이 다를 수 있으므로
번호만으로 동일성을 추론하지 않는다. [@student-runtime] [@student-layout]

질문은 다음 구조를 사용한다.

> 기존 `<화면/Section>`의 `<구체 속성>`을 참고해 `<새 Section>`을 만들면 될까요?<br>
> 동일 적용 제안: `<각도, rail, inset, gap, texture, shadow, motion, grid/data 중 명시 항목>`<br>
> 별도 결정 필요: `<크기, child 수, data source, interaction 등 차이 항목>`

사용자가 기존 Section의 “호출”을 요구하면 새로 닮은 도형을 만드는 것인지, 실제 기존 widget과
controller를 재사용해 같은 Section instance/flow를 여는 것인지도 반드시 구분한다. 다음 질문 예시를
우선 사용한다.

1. “새 목록은 학생 Section 2의 80° 양측 rail, 8px inset, 사선 scrollbar 계산을 그대로 참고하되 열 수와 card 내용만 새 데이터에 맞추면 될까요?”
2. “새 행동 rail은 학생 Section 1의 Section 상대 크기 계산과 중간-Y icon 정렬을 재사용하고, 색상과 버튼 수만 별도로 정하면 될까요?”
3. “새 상세 영역은 학생 Section 3의 좌우 공통 rail과 동일 gap만 참고하고, placeholder 제거 여부와 내부 indicator는 새 역할에 맞게 정하면 될까요?”
4. “검색·toggle 영역은 학생 Section 4의 배치 밀도와 hit 영역을 참고하되 실제 filter 항목과 기본 checked 값은 별도로 정의하면 될까요?”
5. “요청하신 기존 Section 호출은 기존 widget과 상태를 그대로 여는 것인가요, 아니면 geometry와 효과만 복제한 새 Section을 만드는 것인가요?”
6. “참고 Section과 동일하게 적용하지 않을 부분이 있나요? 현재는 `<차이 후보>`를 다르게 처리하는 것으로 이해했습니다.”

참조 승인을 받을 때는 최소한 `같게 적용할 것`, `다르게 적용할 것`, `아직 미정인 것`의 세 묶음으로
답을 다시 요약한다. 기존 Section의 구현 세부가 현재 사용자 의도와 충돌하면 기존 동작을 자동 복사하지
않고 충돌 지점을 먼저 알린다. 사용자 답변 뒤에는 “A의 geometry·B의 texture·C의 motion을 참고하고,
data와 child 구성은 새로 만든다”처럼 조합된 최종 계약을 한 문단으로 확인한 후 구현한다.
[@student-runtime] [@student-tests]

## 학생 Section 5 필터와 Section 2 고정 viewport 후속 계약

2026-07-27 후속 보정에서 Section 5의 `container-12`는 Section path 안쪽의 남은 높이에
고정된 filter viewport가 되었다. 아래쪽에는 container와 겹치지 않는 44px 초기화 action을
두며, 항목 수가 늘어도 Section이나 container 높이를 늘리지 않는다. Section 2의 학생 grid도
같은 고정 viewport 정책을 사용한다.

두 viewport는 표준 수직 `ScrollController`를 유지하면서 행 중심의 viewport Y를 80도
trajectory의 X로 변환한다. Section 5는 v6의 그룹명과 표시값을 사용하는 학교, 초기 성급,
공격 타입, 방어 타입, 편성, 역할, 포지션 그룹을 제공한다. 같은 그룹에서 선택한 값은 OR,
서로 다른 그룹은 AND이며, Section 2로 돌아가도 선택을 보존하고 초기화 action만 모든 선택을
지운다. 현재 planning catalog protocol이 직접 제공하지 않는 v6 성장·스킬 metadata 그룹은
빈 동작으로 노출하지 않는다.

viewport 위·아래에는 container 기본색과 같은 36px gradient fog를 둔다. 이는 기본 lifted
shadow의 약 3배 두께이며, scroll content가 고정 경계에서 잘려 보이지 않고 자연스럽게
사라지게 한다. fog는 pointer를 받지 않고 grid/list의 wheel, drag, checkbox hit target과
사선 scrollbar 동작을 그대로 보존한다.

실화면 재검수에서는 container polygon을 사각 bounds로 만든 뒤 부모 path와 교차시키는 방식이
둥근 꼭짓점을 잘라내는 것을 확인했다. Section 5 container의 위·아래 좌우 점은 부모 80도 경계를
각 Y에서 직접 평가하고 10px 안쪽에 배치한다. 필터 group row도 중심 Y 이동과 자체 사선 깊이를
중복 적용하지 않고 row 밑변의 viewport Y를 기준으로 한 번만 이동한다. 제목·checkbox의 좌우
안전영역은 row 전체 높이에서 생기는 최대 사선 깊이와 8px 여백을 합한 값으로 고정해 상단 제목이
사선에 잘리지 않게 한다.

필터 group row의 폭은 모든 row에 같은 상수를 사용하지 않는다. 각 row의 높이에 따른 자체 우측
사선 깊이를 폭에 포함해, viewport 상단·하단에서 평가한 row의 우측 두 끝점이 하나의 80도 rail
위에 놓이도록 계산한다. 따라서 checkbox 개수로 row 높이가 달라져도 우측 사선이 서로 평행하게
어긋나는 대신 같은 경계선에 정렬되며, scroll offset이 바뀌어도 이 관계를 유지한다.

### 학생 페이지 viewport와 Section canvas 높이

학생 페이지의 Section canvas 높이는 `StudentPage` viewport에서 페이지 상하 padding을 뺀 값이어야
한다. `SingleChildScrollView`의 바깥 constraint를 padding 차감 없이 그대로 canvas 높이로 사용하면
Section 2·5의 하단과 Section 5 초기화 버튼이 화면 아래로 padding 합계만큼 밀린다. 최소 canvas
높이 590은 유지하되, 충분한 높이에서는 `maxHeight - padding.vertical`을 사용한다.

필터 모드의 `_StudentSectionFoundationPainter`는 새 Section 5 container와 reset surface를 직접
그린 뒤, 일반 Section 2용 runtime container/feature paint loop에서 `element-2` 자식을 제외해야
한다. 그렇지 않으면 기존 `container-12`가 새 필터 container 뒤에 원래 크기로 다시 그려져
이전 viewport와 비슷한 중복 면·윤곽이 남는다.

Section 2·5의 viewport fog는 고정 장식이 아니라 실제 `ScrollPosition`에서 파생되는 상태다.
스크롤 범위가 없으면 위·아래 fog를 모두 그리지 않는다. `pixels`가 최소 extent에 있으면 위 fog를,
최대 extent에 있으면 아래 fog를 그리지 않으며, 두 끝점 사이에서만 양쪽 fog를 표시한다. 두
섹션은 `_StudentDiagonalScrollbar`의 동일한 계산과 overlay를 공유한다.

## 학생 Section 1 정렬 드롭다운 계약

- Section 1의 정렬 드롭다운은 기존 action 버튼의 채움·삼각 texture를 복제하지 않는다. 닫힌
  surface는 투명하며, 같은 연핑크색의 1px 사다리꼴 테두리·텍스트·우측 하향 삼각형만 사용한다.
- 사다리꼴 path는 기존 Section 1 action과 같은 responsive path builder 계열을 사용한다. 그 path를
  border, clip, hit 영역이 공유하며 고정 pixel polygon을 별도로 만들지 않는다.
- 드롭다운 높이는 Section 4 검색 입력 `container-14`의 실제 렌더 높이에서 유도한다. 좌우 inset과
  오른쪽 80° 경계 여백은 action 버튼 규칙을 따르고, 세 action 버튼과 드롭다운 사이의 모든 세로
  gap은 같은 값이다. 드롭다운을 Section 1의 최상단에 두고 그 아래에 계획·스캔·필터 action을
  기존 순서로 배치한다. 이 네 항목을 수용하도록 action 버튼 높이는 Section 1 높이에서 역산한다.
- 좁은 닫힌 control에는 `이름 ↑`, `LV ↓` 같은 축약 label을 표시하고, 펼친 menu에는 기준과
  오름·내림차순을 모두 적는다. 닫힌 label은 15px, 펼친 menu label은 18px로 초기 구현의
  10px·12px보다 각각 1.5배 크게 표시한다.
- 정렬 기준은 이름, LV(`level`), 성작 상태(`student_star`), 인연 랭크(`bond_rank`) 각각의
  오름·내림차순이다. 숫자 값이 없는 학생은 방향과 무관하게 목록 끝에 두고, 동률과 미구현 값은
  이름 오름차순으로 안정화한다. 인연 랭크는 repository protocol에 필드가 추가되기 전까지 전원이
  미구현 값이므로 이름순 fallback만 동작한다.

## 학생 카드 이름 크기 계약

- 하단 16% overlay 중 속성 띠를 제외한 13% 이름 영역은 유지한다.
- 이름 글꼴은 이전 4~8px 범위에서 1.5배인 6~12px 범위로 키우고, 가용 이름 영역 높이의 80%를
  목표값으로 사용한다. 긴 이름은 기존처럼 한 줄 ellipsis와 `square.png` alpha mask 안에서만
  렌더링한다.

## 학생 Section 4 표시 토글 텍스트 계약

- 공격/방어 속성, 학생 이름, 미보유 학생 숨김, 일본 서버 전용 숨김 checkbox label은
  초기 11px에서 1.5배인 16.5px로 표시한다.
- 기존 한 줄 ellipsis와 27px row cadence는 유지하며, text 크기 변경으로 Section 4나 검색 입력의
  geometry를 바꾸지 않는다.
## Diagonal media list item contract

- `release/component-diagonal-media-list-item1.ba-section-studio.json` is the
  placement source for the reusable Flutter `DiagonalMediaListItem`.
- The component is presentation-neutral: planning and scan-result surfaces pass
  typed media, title, level, skill, equipment, favorite-item, bond, star, and
  stat values into it without embedding repository or scanner behavior.
- Feature 4 is a placement anchor only. Runtime paints the same five student
  star plus four weapon-star segmented indicator used by the student tab.
- Feature 17 is a placement anchor only. Runtime paints a fixed pink heart with
  a white bond-rank number from 1 through 100 and reserves adjacent delta space.
- Numeric changes use `5(▲2)` and `5(▼2)`: increases are green and decreases
  are red. Heart selection and warning states do not recolor the heart.
- The exact shared center lines are feature 2/3, feature 5/4/7/17, and feature
  6/8/9/10/11/12/13/14/16/18. Widget tests gate these normalized coordinates.
- The JSON shape and runtime item share one responsive 80-degree path. Clipping,
  fill, border, and hit behavior derive from that path while child placement
  remains independent normalized geometry.
- The runtime plan row is 54 px high inside a 58 px row extent. Star segments
  retain the Studio `0.22` height fraction as the row grows. Equipment images
  grow while preserving the lower content center line.
- Plan rows are not placed in one fixed safe rectangle. Each row's left and
  right bounds are sampled from the parent phase parallelogram at the row's top
  and bottom, so the child's own 80-degree path shares both parent edges.
- Student portraits use a bond-rank background and a 98% foreground portrait:
  default through 20, blue from 21, yellow from 51, and purple at 100.
  The same policy is shared by Students, Plan, and Statistics surfaces.
- Phase cards reserve a 20 px inter-phase gap containing a downward triangle to
  communicate execution flow.

## DiagonalMediaListItem runtime sizing follow-up (2026-07-28)

- Studio source `component-diagonal-media-list-item1.ba-section-studio.json`
  uses a 24-grid-row section height; the plan runtime maps it to a 65px item
  with a 69px extent.
- Equipment media slots layer `assets/studio_features/square.png` under a 98%
  foreground icon.
- The relationship-rank heart uses a fixed 1.28:1 aspect ratio inside its
  Studio-aligned anchor so a wide parent row cannot flatten the badge.
- The student/weapon star bar keeps its normalized height of `0.22`; increasing
  item height therefore preserves the authored bar proportion.

## DiagonalMediaListItem information-column follow-up (2026-07-28)

- The relationship heart occupies the far-right column and its delta is rendered
  in a separate row immediately below the badge.
- The favorite-item slot is widened to `0.075` so a tier and delta remain legible.
- Equipment image/value pairs reserve at least `0.008` normalized horizontal
  spacing after each square-backed icon.
- Skills remain between the student level and equipment group and use a 14.25px
  base font size.
- The star indicator's normalized height is `0.154`, which is 70% of its former
  `0.22` height, while its vertical center stays unchanged.

## DiagonalMediaListItem multi-value deltas (2026-07-28)

- Equipment values consist of an independent tier and level, rendered together
  above a two-part delta line.
- Skills, equipment, and additional stats use component-aligned delta rows such
  as `- / - / - / ▲1`; unchanged components render as `-`.
- The relationship badge returns to the central information area and keeps its
  delta below it. Its number font is 15.75px, 1.5 times the former 10.5px.
- Studio feature rectangles reserve two-line height for skills, equipment values,
  and additional stats.

## DiagonalMediaListItem conditional delta rows (2026-07-28)

- The relationship badge is centered in the dedicated far-right column at
  normalized center X `0.95`; its delta remains below the badge.
- A component delta row is omitted when every component is unchanged. If any
  component changes, unchanged siblings remain visible as `-` placeholders.
- Skill display maps maxima `[5, 10, 10, 10]` to `M`, so `5/6/6/6` renders as
  `M/6/6/6` and fully capped skills render as `M/M/M/M`.

## DiagonalMediaListItem bond vertical alignment (2026-07-28)

- The heart surface and equipment `square.png` slots share normalized center Y
  `0.67614347305232`.
- The phase header no longer exposes its internal item count at the upper right.

## Plan resource bottleneck header (2026-07-29)

- Section 5 orders its tabs as `병목 / 페이즈별 / 전체`, and `병목` is the
  initial selection because it is the primary plan-resource view.
- The bottleneck content removes the former title and subtitle copy. Its left
  media slot uses the v6 `Item_Icon_Material_Nebra_2.png` with the tier-index-2
  `square_yellow.png` background: v6 maps ooparts index 0/1/2/3 to
  default/blue/yellow/purple, so index 2 is the visible T3 grade.
- The runtime copies those files into dedicated `item_icons/ooparts` and
  `item_backgrounds` UI asset folders; it does not load or import v6 scanner
  templates at runtime.
- The media slot occupies 85% of the content height and preserves the source
  256:204 aspect ratio, matching the vertical prominence of Section 2 media.
- The text column is three rows: `가장 심한 병목 요소`,
  `보유량 : 42 / 필요량 : 60`, and
  `확보 시 학생 3명의 목표 단계가 가능해집니다`.
- The sample values remain typed constants until the inventory-derived shortage
  contract is connected.
- Clicking the bottleneck media toggles a `1.8px` `#f2b3ef` outline on every
  Section 2 row for Azusa, Nonomi, and Haruka. Multiple plan steps for the same
  student are all highlighted; switching tabs clears the prior selection.
- The two gaps between the three bottleneck copy rows are 1.5 times their
  original values: `4.5px / 6px` normally and `1.5px / 1.5px` when compact.
- Compact heights use explicit one-line text metrics so the three-line bottleneck
  summary remains inside the Section 5 diagonal safe region without overflow.

## Plan phase resource header (2026-07-29)

- The `페이즈별` tab reuses the exact Section 5 item-summary structure from the
  bottleneck tab: the same 85%-height media slot, typography, three rows,
  spacing, compact behavior, and diagonal safe interval.
- Its representative resource is Antikythera T4. The runtime uses
  `Item_Icon_Material_Antikythera_3.png` with the tier-index-3
  `square_purple.png` background copied from the v6 reference.
- Its sample copy is `가장 부족한 재화`, `보유량 : 42 / 필요량 : 60`, and
  `2단계에서 4명 중 1명만 완료 가능`.
- Clicking the phase resource toggles the common Section 2 highlight contract
  for Yuuka, the Antikythera consumer in the current phase-2 sample.

## Plan overall resource header (2026-07-29)

- The `전체` tab has no resource icon and displays exactly two visible lines:
  `전체 요구량의 72% 확보` and `14종 부족 · 6명의 성장 계획에 영향`.
- It has a dedicated two-line responsive type scale instead of inheriting the
  smaller three-row item-summary typography, so both lines use the available
  diagonal header height.
- The whole summary is clickable. It toggles the same Section 2 row-highlight
  contract for the six sample affected students: Shiroko, Hoshino, Serika,
  Haruka, Nonomi, and Azusa.
- Bottleneck, phase, and overall views therefore own separate affected-student
  sets. Switching tabs clears the previous set; clicking the current summary
  toggles its set without changing the common `1.8px` pink row treatment.

## Plan Section 3 tab views and first bottleneck detail (2026-07-29)

- Section 5 owns the selected resource view and drives three keyed Section 3
  bodies: `3-1 병목`, `3-2 페이즈`, and `3-3 전체`. The phase and overall
  bodies are reserved placeholders until their detail designs are implemented.
- Section 3-1 projects the container geometry from
  `release/section-plan-main-1.ba-section-studio.json`, then applies the runtime
  fit correction requested after visual review: width and height are 95% of
  Section 3, it is horizontally centered, its top margin is 2.5%, and the path
  is clipped to the parent Section 3 polygon.
- The container reuses the Section 2 diagonal list behavior. Each bottleneck
  detail is its own parallelogram card; vertical scroll offset is converted to
  horizontal offset along the 80° rail.
- The first sample card displays `병목 1` and
  Hoshino phase 2. `병목 1` occupies the original upper-left position. The
  space below it reuses the exact 65px `PlanStudentStepTile` used by Section 2
  instead of maintaining a separate portrait-and-label composition.
- The reused step tile accepts presentation-only bottleneck color overrides.
  The first tactical-BD sample paints its skill value pink; equipment samples
  paint the affected equipment value, and the credit sample paints the stage
  title. All other geometry and data presentation remain the Section 2 item.
- Credit is not rendered as a resource tile. When credit is a bottleneck, a
  dedicated long row between the reused stage item and the resource grid shows
  the v6 `Currency_Icon_Gold.png`, `remaining / required`, and shortage in that
  order. The icon box is `58.5×73.8px`, 60% of the former natural resource icon
  box, and has no `square.png` background.
- The resource grid has two equal slots per row. Its first entry uses the v6
  Abydos tier-index-0 tactical BD icon with the default `square.png` background
  and shows `단계 진입 잔량 4 / 단계 필요량 12`, followed by `8개 부족`.
- Resource icon and text metrics use 1.5 times the prior natural size
  (`97.5×123` media, `16.5 / 12 / 18px` copy). Narrow layouts proportionally
  scale that natural presentation down to prevent overflow.
- The active primary monitor is `2560×1440` at Windows DPI 96 (100%), so the
  supplied screenshot's physical pixels equal Flutter logical pixels. In that
  capture the old card fill is 132px high, the bright icon/text group spans
  78px, and the top and bottom gaps are 27px each. Resource tiles are therefore
  107px tall with 2px vertical padding, targeting approximately 13.5px visible
  gaps on that monitor.
- Equipment resource names append their explicit tier, for example
  `헤어핀 (T10)`.
- `이 병목으로 지연되는 단계` is an action button. It toggles the common
  1.8px pink Section 2 highlight only on the exact phase/student/step keys
  listed by that bottleneck, rather than every row belonging to those students.
- The action uses the same 80° parallelogram silhouette while preserving its
  previous width and 38px height. Delayed-stage child rows are not duplicated
  in Section 3-1 because Section 2 is the result display.
- Resource-summary actions and delayed-stage actions are mutually exclusive:
  selecting a resource clears the exact-stage focus before applying the
  resource's affected-student highlight set.
- Four sample bottlenecks (BD, credit, T10 equipment, and ooparts) make the
  Section 3-1 diagonal scroll trajectory directly testable. The credit sample
  additionally carries Antikythera T4 and Nebra T3 as two ordinary resource
  tiles in one row, covering the multiple-resource case.
- v6 images are copied into dedicated v7 runtime UI asset directories; v7 does
  not import v6 paths at runtime.
