# Qt Quick 고정 논리 캔버스 전환

BA Planner의 새 Viewer 표현 계층은 1920×1080 논리 캔버스를 한 번 생성하고, 창의 client
크기에 따라 캔버스의 단일 transform만 변경한다. 리사이즈는 데이터 로드, QWidget/QML
페이지 재생성, 입력 상태 캡처·복원을 유발하지 않는다.

## 런타임 경계

- 스캔, 프로필, 저장, 플래너 계산은 기존 Python 코어가 소유한다.
- `gui/quick/models.py`의 QObject와 QAbstractListModel이 QML 표시 계약을 제공한다.
- QML은 프로필 파일이나 SQLite를 직접 읽지 않는다.
- 페이지는 필요할 때 Loader로 생성할 수 있지만 Python 모델의 수명과 분리한다.

## 크기 계약

기준 크기는 1920×1080이다.

```text
scale = min(client_width / 1920, client_height / 1080)
canvas_x = (client_width - 1920 * scale) / 2
canvas_y = (client_height - 1080 * scale) / 2
```

Windows 일반 창은 `WM_SIZING`에서 client 영역 비율을 유지한다. 최대화처럼 운영체제가
창 크기를 소유하는 상태에서는 외부 창을 강제로 줄이지 않고 내부 캔버스를 중앙 정렬한다.

## 이행 순서

1. Qt Quick 셸과 비율 제약
2. 인벤토리 가상 목록
3. 홈과 스캔 프로세스 제어
4. 학생 GridView와 필터
5. 플랜 및 필요 재화
6. 전술대항전과 통계
7. UCS QML 컴포넌트 갤러리 전환
8. 기존 QWidget Viewer 제거

## 현재 이행 상태

- 홈, 창 연결, 스캔 실행
- 학생 가상 그리드, 공용 메타데이터 필터, 학생 상세
- 성장 플랜과 기존 `planning_calc` 기반 총 필요 재화
- 인벤토리 가상 목록
- 전술대항전 SQLite 전적 입력·검색
- 현재 학생 필터 결과 기반 통계
- 프로필 생성·전환과 창 연결 설정

## 기존 디자인 이행 계약

기존 QWidget 디자인은 위젯 트리나 QSS를 그대로 QML에 복사하지 않는다. 먼저
`gui/ui_design_spec.json`의 다섯 기본 색을 의미 기반 토큰으로 변환하고, QML 컴포넌트가
그 토큰만 사용하도록 옮긴다.

```text
UCS 저장
  -> gui/ui_design_spec.json
  -> QuickThemeController (파일 변경 감시 + 의미 토큰 파생)
  -> DesignTokens.qml
  -> PlannerPanel / PlannerButton / PlannerHeader
  -> 각 페이지
```

첫 이행 단위는 상단 헤더와 내비게이션이다. UCS에서 팔레트를 저장하면 실행 중인 Quick
Viewer가 QML 트리를 재생성하지 않고 색을 갱신한다. 다음 디자인 이행은 아래 순서를 따른다.

1. 기존 화면과 동일한 1920×1080 크기의 기준 캡처를 남긴다.
2. 반복되는 표면을 `PlannerPanel`, 입력을 `PlannerButton` 같은 공통 컴포넌트로 치환한다.
3. 페이지별 직접 색상값을 `DesignTokens`의 의미 토큰으로 치환한다.
4. 여백·타이포그래피·카드 크기를 맞춘 뒤 대각선, 그림자, 배경 질감을 옮긴다.
5. 1920×1080과 축소 창에서 기준 캡처와 비교하고, 입력 상태와 모델이 리사이즈 중 보존되는지
   함께 검사한다.

QWidget `style_sheet`와 selector 기반 override는 QML 객체에 자동 적용하지 않는다. 마이그레이션
중에는 기존 override를 시각 참고값으로 유지하고, 반복 가능한 값은 토큰이나 공통 QML
컴포넌트 속성으로 승격한다. 일회성 좌표 복사는 마지막 수단으로 제한한다.

현재 공통 QML 계층에는 패널·헤더·버튼뿐 아니라 텍스트 입력, 텍스트 영역, 콤보박스,
체크박스, 스핀박스, 진행 막대, 스크롤바가 포함된다. 메인 7개 페이지는 Qt Quick Controls의
플랫폼 기본 표면과 직접 색상값 대신 이 계층을 사용한다.

홈은 일반 사각 버튼을 배치한 뒤 외곽 패널로 잘라내지 않는다. `HomeMenuRow`가 80° 사선의
깊이와 10px seam gap으로 각 버튼의 겹치는 widget bounds를 계산하고,
`HomeMenuSurfaceItem`이 왼쪽 확장과 오른쪽 절단을 한 경로에서 그린다. 같은 경로를 이미지
클립과 containment mask에 사용하므로 투명한 모서리가 이웃 버튼의 클릭을 가로채지 않는다.
설정 버튼은 비트맵 대신 palette 기반 삼각형 렌더러를 고정 seed 8417로 호출한다.

홈 헤더는 `main/header` 외곽 탭 바, 선택된 홈 탭 폭의 `home/header-connector`,
`home/header-active`, 내부 `home/header-content` 순서로 중첩한다. 연결부 위치는 실제 홈 탭
geometry에서 계산하며, 홈 화면에서는 선택 탭과 인사말·프로필·계정 초상 헤더가 하나의
연속된 활성 영역으로 보인다. 학생부·계획·인벤토리·전술대항전은 같은 탭 바에서 각 페이지의
기존 헤더로 이동하고, 통계와 설정은 홈 메뉴를 통해 접근한다.

전체 창 삼각형 배경은 QML에서 알고리즘을 복제하지 않는다. `TriangleTextureItem`이 기존
`gui/triangle_texture.py`의 `paint_triangle_texture`를 호출한다. 팔레트와 안정적인 random seed를
공유하며, 패널과 입력의 명시적 불투명 표면은 유지해 배경 질감 때문에 가독성이 떨어지지
않도록 한다.

## 패널 형상과 그림자

`PlannerPanel`의 표면은 `PlannerSurfaceItem`이 그린다. 기본은 둥근 사각형이며
`diagonalEdge`, `diagonalAngle`, `diagonalDirection`으로 한쪽 절삭을 선택할 수 있다. 절삭
경로와 깊이 계산은 기존 `gui/diagonal_shape.py`를 재사용한다. 높이 또는 반지름이 바뀌면
고정 좌표를 확대하지 않고 현재 논리 크기에서 경로를 다시 계산한다.

절삭이 활성화된 쪽은 계산된 깊이와 `contentSafeMargin`을 합쳐 콘텐츠 영역에서 제외한다.
따라서 우측 정렬 버튼이나 긴 텍스트가 투명한 절삭 영역으로 진입하지 않는다. 현재 학생,
플랜, 인벤토리, 통계의 페이지 헤더는 기존 스캔 헤더와 같은 80° 우측 절삭을 사용한다.

그림자는 `QGraphicsDropShadowEffect`나 QML 레이어 전체 효과를 사용하지 않는다. 표면 경로를
하단 우측으로 0.8~3.2 논리 픽셀 이동한 네 레이어로 먼저 그리고, 각 레이어의 알파를
점진적으로 낮춘다. 입력 자식이나 텍스트를 합성 이미지로 흐리지 않으며 레이아웃·히트 영역도
변경하지 않는다.

## UCS QML 컴포넌트 편집

Quick UCS는 실제 QML 객체 주소나 QWidget selector를 섞지 않고 `qml/...` selector를 사용한다.
현재 메인 헤더와 프로필, 각 페이지의 주요 패널 20개, 공통 컨트롤 6개, 오버레이 2개,
반복 delegate 표면 8개와 내부·보조 시각 요소 10개가
안정적인 대상으로 등록되어 있다.
등록 목록은 `gui/quick/design_registry.py`가 단일 소유하며 Viewer와 UCS가 함께 읽는다.

UCS에서 QML 대상을 선택하면 다음 값을 편집할 수 있다.

- 절삭 변: `none`, `left`, `right`, `top`, `bottom`
- 절삭 방향: `forward`, `reverse`
- 각도: 5~89.5° 범위
- 그림자 높이: 0~4 논리 픽셀
- 절삭 깊이에 추가되는 콘텐츠 안전 여백: 0~200 논리 픽셀
- 선호 너비·높이: 0은 레이아웃 자동 계산, 양수는 1920×1080 논리 캔버스 기준 크기
- 가로·세로 추가 패딩: 각 방향 0~120 논리 픽셀
- 표면 variant: `panel`, `alt`, `raised`, `selected`
- 모서리 반지름: 0~64 논리 픽셀
- 테두리 두께: 0~6 논리 픽셀
- 패널 직속 주요 레이아웃 간격: 0~64 논리 픽셀

공통 컨트롤은 패널과 분리된 안정 대상 `qml/controls/button`, `qml/controls/input`,
`qml/controls/combo`, `qml/controls/checkbox`, `qml/controls/scrollbar`,
`qml/controls/progress`로 등록한다. UCS에서는 각 대상의 너비·높이, 모서리 반지름, 테두리 두께와
`NORMAL`, `HOVER`, `ACTIVE`, `PRESSED` 상태 표면을 편집한다. 상태 표면은 임의 색상이나
QML 객체 주소가 아니라 `backgroundDeep`, `panel`, `panelAlt`, `panelRaised`,
`surfaceSelected`, `accent`, `accentStrong`, `border`, `danger` 의미 토큰 중 하나만 선택한다.
버튼은 `PlannerButton`, 입력 대상은 `PlannerTextField`·`PlannerTextArea`·`PlannerSpinBox`,
콤보 대상은 `PlannerComboBox`가 공유한다. 체크박스·스크롤바·진행 표시줄은 각각
`PlannerCheckBox`·`PlannerScrollBar`·`PlannerProgressBar`가 대응한다. 너비나 높이 `0`은 해당
축을 부모 레이아웃에 맡긴다는 뜻이다. 따라서 기존 화면의 반복되는 컨트롤 외형을 한 번
이전하면 모든 페이지에 적용되며, 페이지별 예외 selector를 계속 늘리지 않는다.

오버레이는 `qml/overlays/dialog`와 `qml/overlays/dropdown`으로 분리한다. 공통
`PlannerPopup`이 표면·테두리 표면·반지름·테두리 두께·패딩을 적용하고, 대화상자는 모달
스크림 표면과 불투명도도 함께 적용한다. 대화상자의 선호 너비·높이 `0`은 학생 필터와 플랜
목표 편집기가 가진 서로 다른 콘텐츠 크기를 그대로 유지한다. 드롭다운의 선호 높이는 고정
높이가 아니라 목록의 최대 높이로 사용하므로 항목이 적을 때 빈 공간을 만들지 않는다.
Qt Basic이 사용하던 기본 패딩 12와 모달 스크림 50%, 기존 드롭다운의 최대 높이 360과 패딩
4를 registry 기본값으로 옮겨 override가 없는 화면의 외형과 닫기 동작을 보존한다.

반복 목록 표면은 `qml/delegates/student-card`, `qml/delegates/inventory-row`,
`qml/delegates/plan-row`로 분리한다. 공통 `PlannerDelegateSurface`는 높이, 네 방향 패딩,
반지름, 테두리와 `NORMAL`·`ALTERNATE`·`SELECTED` 의미 표면을 적용한다. 학생 Grid의 셀 높이는
학생 카드 대상과 함께 갱신하고, 인벤토리의 홀짝 교차 표면과 학생 선택 강조는 기존 모델 상태에
계속 바인딩한다. delegate 인스턴스 수, `reuseItems`, `cacheBuffer`, 탭 동작과 행 내부 입력은
스타일 명세가 소유하지 않으므로 디자인 저장 중 재생성되지 않는다.

작은 목록은 같은 계약 아래 `home-window-row`, `plan-resource-row`, `tactical-jokbo-row`,
`tactical-match-row`, `statistics-row` 역할을 추가한다. 현재 행 높이 62·58·78·106·58과
패딩 9·10·12를 각 대상의 기본값으로 유지한다. 창 후보의 `likelyBA` 선택 상태와 전술 전적의
승패 테두리처럼 데이터에 따른 의미 표현은 페이지 바인딩에 남기며 UCS는 그 데이터를
저장하지 않는다.

delegate 내부 시각 요소는 `student-portrait`, `student-status-badge`, `inventory-icon`,
`plan-portrait`, `statistics-meter` 역할로 등록한다. 공통 `PlannerElementSurface`는 선호
너비·높이, 반지름, 테두리, 표면과 불투명도만 소유한다. 이미지 URL·로드 상태, 학생 레벨과
성급 텍스트, 인벤토리 대체 아이콘, 통계 막대 폭 계산은 기존 delegate 바인딩에 남는다.
따라서 프레임 디자인을 저장해도 이미지 요청이나 수치 계산이 다시 실행되지 않는다.

목록 밖의 `student-detail-panel`, `plan-resource-summary`, `statistics-summary-card`도 같은
요소 계약을 사용한다. 학생 선택 여부, 플랜 재화 모델과 통계 값은 페이지가 계속 소유하고,
UCS는 패널 폭·요약 카드 크기와 표면만 편집한다. 연결·승패처럼 현재 텍스트 색상만으로
표현되는 상태는 기존 디자인에 없는 칩을 새로 만들지 않고 데이터 바인딩으로 유지한다.

페이지의 1px 구분선은 `qml/elements/divider`와 `PlannerDivider`로 통일한다. 마이그레이션 완료
게이트는 `qml/pages/*.qml`에서 직접 `Rectangle`, 기본 Qt Button/Input/Popup, 임의 hex 색상을
허용하지 않는다. 배경·컨트롤 indicator처럼 공통 컴포넌트 내부에서만 의미가 분명한 기하 도형은
해당 컴포넌트가 계속 소유한다.

패널의 기존 선호 크기는 QML 파일과 UCS에 중복 기록하지 않고 component registry의 기본값이
소유한다. 표면 variant, 반지름, 테두리와 주요 spacing도 같은 registry 기본값으로 이전한다.
따라서 override가 없는 기존 화면은 동일한 크기와 시각 위계를 유지한다. 패딩 override는 기존
페이지 내부 여백을 제거하지 않고 패널 콘텐츠 경계에 추가되며, 대각선 안전 영역과 그림자
예약 공간도 함께 합산된다.

variant는 임의 색상값을 패널별로 저장하지 않고 전역 팔레트의 `panel`, `panelAlt`,
`panelRaised`, `surfaceSelected` 의미 토큰을 선택한다. 팔레트를 바꿔도 패널의 계층 관계가
유지되며 UCS에 별도 색상 복제본이 생기지 않는다.

Quick UCS의 QML 섹션 미리보기는 Canvas나 빈 `PlannerSurfaceItem`으로 대각선을 근사하지 않는다.
데이터 로드를 끈 실제 `Main.qml`에서 선택한 `componentKey`를 찾아 그 좌표와 하위 객체 트리를
그대로 렌더링한다. 인라인 미리보기는 선택 영역을 종횡비 유지로 확대하고, 별도 미리보기 창은
1920×1080 논리 캔버스의 실제 Main 좌표에 같은 크기로 배치한다. UCS에서 보이는 절삭 끝점,
내부 버튼·텍스트·이미지와 그림자는 저장 후 Viewer에 나타나는 객체와 동일하다. 공통 컨트롤,
오버레이, delegate와 element는 역할별 독립 샘플을 유지하며 기존 QWidget 명세 항목은 호환
Canvas 미리보기를 계속 사용한다.

타이포그래피는 `font_caption`, `font_body`, `font_section`, `font_title` 네 전역 토큰으로
관리한다. UCS에서 8~72 논리 픽셀 범위로 편집할 수 있고 저장 후 모든 페이지의 해당 텍스트
바인딩이 같은 객체 트리 안에서 갱신된다.

편집 중인 값은 UCS 메모리에만 존재한다. `디자인 저장`을 실행해야
`gui/ui_design_spec.json`의 `components["qml/..."]`에 기록되며, 실행 중 Viewer는 파일 감시를
통해 같은 QML 객체에 값을 갱신한다. `기본값 복원`은 해당 override를 삭제하므로 코드에 등록된
기본값으로 돌아간다.

저장 전에는 알려진 selector, cut 모드, edge와 direction, 각도, 그림자, 안전 여백, hit mask,
seam gap/overlap 조합, 선호 크기와 패딩 범위를 검사한다. 검증 실패 명세는 저장하지 않으며, 외부에서 잘못된 JSON이
들어와도 `QuickThemeController`는 해당 override를 채택하지 않고 등록 기본값을 사용한다.
컨트롤 상태 표면도 허용된 의미 토큰인지 함께 검증하며, 하나라도 잘못되면 해당 컨트롤
override 전체를 버리고 registry 기본 스타일을 사용한다.
오버레이의 표면·테두리·스크림 토큰과 0~100% 스크림 불투명도도 같은 방식으로 검증한다.
반복 표면의 기본·교차·선택·테두리 토큰과 높이·네 방향 패딩 범위도 저장 전에 검증한다.
내부 요소의 크기·표면·테두리와 0~100% 불투명도 역시 같은 registry 범위로 검증한다.

전술대항전 스크린샷 판독·족보 저장/검색과 UCS 컴포넌트 갤러리도 Qt Quick 경로를
사용한다. Excel 전술 기록 가져오기와 기존 QWidget 실제 스냅샷 감사 기능은 설정 화면의
레거시 Viewer 및 호환 UCS 명령으로 유지한다.

기존 `gui/viewer_app_qt.py`는 회귀 비교와 Excel 전술 기록 가져오기 같은 고급 호환 기능용으로
유지한다. 기본 `main.py`, `student_viewer.py`, Tk Viewer launcher는 Qt Quick Viewer를 연다.
`--legacy-ui` 또는 `BA_PLANNER_LEGACY_UI=1`로 기존 Viewer를 명시적으로 선택할 수 있다.
