---
title: "학생 카드 그리드·목록·초상 반복 개선 기록"
summary: "학생 탭 Section 2와 Section 3의 공용 학생 카드, 그리드·목록 전환, 상태 배지, PNG 합성 경계 및 첫 진입 성능을 개선하면서 확인한 실패 원인과 현재 렌더링 계약을 기록합니다."
topics: [design, flutter, diagonal-layout, testing, workflow]
sources:
  - id: title-page
    type: file
    path: frontend/lib/ui/pages/title_page.dart
  - id: student-section-layout
    type: file
    path: frontend/lib/ui/widgets/student_section_layout.dart
  - id: asset-image-grid
    type: file
    path: frontend/lib/ui/widgets/asset_image_grid.dart
  - id: diagonal-media-list-item
    type: file
    path: frontend/lib/ui/widgets/diagonal_media_list_item.dart
  - id: reusable-plan-student-tile
    type: file
    path: frontend/lib/ui/widgets/plan_student_step_tile.dart
  - id: student-grid-warmup
    type: file
    path: frontend/lib/ui/widgets/student_grid_warmup.dart
  - id: student-layout-tests
    type: file
    path: frontend/test/student_studio_layout_test.dart
  - id: plan-tile-tests
    type: file
    path: frontend/test/plan_student_step_tile_test.dart
  - id: p0-p6-status
    type: file
    path: almanac/workflows/p0-p6-workflow-status.md
---

# 학생 카드 그리드·목록·초상 반복 개선 기록

## 목적과 범위

이 문서는 2026-08-01부터 2026-08-02까지 수행한 다음 작업의 결정 과정과 시행착오를
보존한다.

- 타이틀 시작 버튼의 삼각형 텍스처 확대
- 계획 탭 학생 아이템의 재사용 가능한 생성자 경계 추출
- 학생 탭 Section 2의 그리드·목록 보기와 전환 애니메이션
- 그리드 카드의 희미한 직사각형 경계 역추적
- `UNOWNED`·`PLAN`·`JP` 상태 배지 배치
- 첫 학생 탭 진입 지연 완화
- Section 3 선택 학생 초상을 Section 2 그리드와 같은 렌더링 계약으로 통일

단순한 최종값보다, 자동 테스트가 통과한 뒤에도 실화면에서 문제가 남았던 이유와
폐기한 가설을 우선 기록한다. 실제 동작의 기준은 코드이며, 이 문서와 코드가 다르면
코드를 먼저 확인한 뒤 문서를 갱신한다. [@student-section-layout] [@p0-p6-status]

## 선행 작업: 타이틀 시작 버튼 텍스처

타이틀의 일반 액션 버튼과 시작 버튼은 서로 다른 삼각형 텍스처 설정을 사용한다.
시작 버튼의 삼각형 무늬를 2.5배로 키우기 위해 일반 액션의 `triangleSize: 42`를 그대로
바꾸지 않고 시작 버튼 전용 설정을 `triangleSize: 105`로 분리했다. 이 방식은 시작 버튼만
변경하며 다른 타이틀 버튼의 밀도를 보존한다. [@title-page]

## 공용 학생 아이템 생성자 경계

계획 메인 화면의 학생 정보 행은 원래 큰 계획 레이아웃 파일 내부에 묶여 있어 다른 탭이
동일한 형태로 호출하기 어려웠다. `PlanStudentStepPreview`, `PlanBottleneckFocusField`,
`PlanStudentStepTile`을 `plan_student_step_tile.dart`로 분리하고, 기존 계획 화면은 이를
import·re-export하도록 유지했다. 따라서 기존 호출부를 깨지 않으면서 학생 탭도 독립
라이브러리만 import해 같은 생성자를 사용할 수 있다. [@reusable-plan-student-tile]

학생 탭 목록 사용을 위해 생성자에 source-compatible optional 입력을 추가했다.

- `owned`: 기본값은 기존 계획 화면과 호환되는 보유 상태
- `onTap`: 기본값은 비상호작용이며 학생 탭에서만 선택 동작 연결
- 목록 전용 표시 옵션: 계획 화면의 기본 표현을 바꾸지 않고 순번·목표·인연 부가 문구 등을
  선택적으로 숨김

초기에는 동일 UI를 복제하는 방안도 가능했지만 폐기했다. 복제하면 배지, 초상, 텍스트 크기,
장비 아이콘과 후속 버그 수정이 두 구현에서 갈라지기 때문이다. 재사용 경계는 레이아웃 전체가
아니라 한 학생 행에 필요한 DTO와 callback까지만 소유한다. [@plan-tile-tests]

## Section 2 그리드·목록 보기

Section 2는 기본 8열 그리드를 유지하고, 같은 검색·필터·숨김·정렬 결과를 목록 생성자에
전달한다. 선택 callback도 공유하므로 보기 방식은 데이터 의미를 바꾸지 않는다.

Section 1에는 목록·그리드 버튼을 한 행으로 추가했다. 버튼을 단순히 기존 좁은 위치에
삽입하자 글자와 사선이 압축될 우려가 있어, 넓은 상단에 보기 버튼 행을 두고 그 아래에
정렬 드롭다운과 작업 버튼을 재배치했다. 모든 행과 네 개의 간격을 함께 다시 계산해
Section 1 내부 높이를 초과하지 않게 했다.

목록 버튼은 사다리꼴이며, 목록 버튼 우측 사선·그리드 버튼 양쪽 사선·Section 1 우측
레일은 같은 80도 깊이를 사용한다. 처음에는 이상적인 80도 polygon만으로 간격을 맞췄지만,
둥근 Section 1 실경로와 화면상 간격이 달라졌다. 인연 랭크 인디케이터에서 얻은 교훈을
적용해 실제 rounded path의 위·아래 교점을 샘플링하고 그 렌더링 경계에서 inset을 계산했다.

보기 전환은 자식만 즉시 교체하지 않는다. Section 2 전체가 현재 방향으로 완전히 퇴장한 뒤
내용을 바꾸고 같은 controller를 정방향으로 실행해 재진입한다. 전환 중 중복 보기·필터 요청은
무시한다. 이 구조는 그리드와 목록의 서로 다른 높이와 paint tree가 한 프레임에서 겹쳐 보이는
문제를 피한다.

## 목록 표현의 조정 과정

학생 목록 행은 기존 65px에서 97.5px로 1.5배 확대했고 행간 4px는 유지했다. 학생 탭에서는
다음 정보를 정리했다. 계획 탭의 기본 표현에는 영향을 주지 않는다.

- 좌측 순번과 이름 뒤 목표 상태 문구 제거
- 이름만 표시하고 이름 크기 1.5배 확대
- 레벨·스킬·장비·애장품·능력개방·무기 레벨 텍스트 1.5배 확대
- 인연 랭크 아래 부가 문구와 우측 요약 숫자 제거
- 장비 아이콘 15% 확대
- 비워진 좌측 rail에 `UNOWNED`·`PLAN`·`JP` 세 슬롯 확보

미보유 암전이 초상 밖으로 번진 원인은 어두운 레이어와 초상이 같은 clip 계약을 공유하지
않았기 때문이다. 목록에서는 alpha를 보존하는 `ColorFiltered` 처리와 초상 host clip을
공유하도록 고쳤다. [@diagonal-media-list-item]

배지 글자가 사라진 것처럼 보였던 현상은 실제로는 글자가 없는 것이 아니라, 사선과 초상
사이의 너무 좁은 폭에 맞추는 과정에서 글자가 극단적으로 축소된 결과였다. 좌측 rail은
경로에서 구하되 공통 최소 badge 폭을 확보했다. 최종 순서는 위 `UNOWNED`, 중앙 `PLAN`,
아래 `JP`다. 각 슬롯은 사선, 위·아래 모서리, 초상, 서로 사이에 독립 간격을 가진다.

## 희미한 직사각형 경계의 역추적

사용자가 지적한 선은 둥근 평행사변형 외곽선이 아니라 `square.png` 원본 캔버스 크기의
축 정렬 직사각형이었다. 이 구분이 핵심이었다. 다음 가설과 수정은 순서대로 시도됐으나
단독으로는 문제를 해결하지 못했다.

### 1. 바깥 컨테이너 outline 가설

Section 2 최외곽 컨테이너의 outline을 제거하면 된다고 처음 해석했지만, 실제 문제는 각
그리드 셀마다 반복됐다. 외곽 컨테이너를 바꾸는 것은 카드별 직사각형과 무관했다.

### 2. PNG의 눈에 보이는 알파 테두리 가설

`square.png`, 인연 배경, 학생 초상의 가장자리를 crop했다. 인연 배경의 baked bright rim은
실제로 존재해 edge crop을 3.5%에서 11%로 늘리는 효과가 있었지만, 문제의 마지막 직사각형은
남았다. 이미지 편집기에서도 별도의 눈에 보이는 알파 테두리가 없음을 확인했다.

### 3. 극저알파 픽셀 가설

소스 캔버스 전체가 non-zero alpha bounds를 반환하고, 배경에는 alpha 1~31의 픽셀이 약
1,200개 존재했다. 배경·이름·속성·미보유 overlay에는 12.5%, 초상에는 4% cutoff를 적용했다.
이는 희미한 알파 노이즈를 줄였지만 모든 직사각형을 제거하지는 못했다.

### 4. `saveLayer` allocation 경계 가설

필터 합성 layer가 정확한 fitted rect와 맞닿아서 생기는 seam으로 보고 offscreen layer bounds를
2px 확장했다. 후속 실화면에서도 하단선이 유지됐으므로 이 가설은 폐기했다. layer padding은
합성 안전성에는 도움이 될 수 있지만 이번 현상의 최종 원인은 아니었다.

### 5. 실제 원인: 서로 다른 형상 소유자

최종 캡처에서 남은 선은 `square.png` 마지막 행의 유효 폭과 맞았고, 배경보다 이름 overlay
mask가 좌우로 더 긴 형상이었다. 즉 배경, 초상, 이름·속성 overlay, 선택 stroke가 각기 다른
bitmap alpha 또는 직사각 bounds를 형상으로 사용하고 있었다. 알파 파일을 개별 수정해도
합성 단계마다 형상 소유자가 다르면 축 정렬 경계가 다시 나타난다.

해결은 bitmap alpha를 카드 외곽 형상으로 쓰지 않는 것이었다. `square*.png`는 edge-cropped
색상 소스로만 사용하고, `studentGridCardPath`가 다음 모든 단계의 유일한 형상 소유자가 된다.

- 배경 clip
- 이름·속성 및 미보유 암전 clip
- 기본 흰 외곽선
- 선택 분홍 강조선
- 배지 위치 계산의 기준 card rect

## 현재 그리드 카드 렌더링 계약

그리드의 원본 논리 크기는 `252×204`다. 각 셀에서 이 비율을 `BoxFit.contain`으로 맞춘
`fitted rect`를 계산하고, 그 rect에 `studentGridCardPath`를 생성한다.

배경과 초상을 그린 뒤 foreground에 흰 기본선을 그려 clip 가장자리의 계단 현상을 덮는다.
기본선은 카드 짧은 변의 `0.01`, 선택선은 이전 강조선 두께인 `0.02`다. 선택선은 가장
마지막에 같은 path 위에 그린다. 테두리를 이미지 alpha에서 얻지 않기 때문에 사각 캔버스
경계가 다시 외곽선으로 나타나지 않는다. [@asset-image-grid]

그리드 배지는 card clip 밖의 foreground에서 그려 잘리지 않는다.

- `UNOWNED`: 상단 좌측 rounded corner 시작점에 접하며 불필요한 radius 추가 inset 없음
- `JP`: `UNOWNED` 오른쪽이 아니라 카드 상단 우측 rounded corner에 접함
- `PLAN`: `UNOWNED` 아래에 짧은 변의 `0.01` 간격을 두고, 평행사변형의 80도 진행량만큼
  왼쪽으로 이동
- `PLAN`: repository goal student ID 집합에서 결정
- `JP`: catalog의 `jpOnly`에서 결정

목업에 PLAN 학생이 없어 화면에서 당장 보이지 않더라도 세 슬롯의 기하와 데이터 연결은
고정한다.

## 첫 학생 탭 진입 성능

첫 진입에서만 남는 지연은 첫 화면에 필요한 약 40~64개 초상과 세 인연 배경을 동시에
asset lookup, PNG decode, image stream 완료, clip·alpha layer·outline·badge·text 합성하는
cold cost였다. 한 번 준비된 뒤에는 Flutter image cache와 shader/painter 경로가 재사용되므로
이후 진입이 빨라졌다.

두 단계로 완화했다.

### 런타임 그리드 비용 제한

전체 스크롤 extent는 유지하되 viewport와 위·아래 한 buffer row만 image item, overlay,
hit target으로 만든다. active row가 바뀌면 벗어난 image stream listener를 해제한다.
`AssetImageGrid`는 이미지 하나가 올 때마다 전체 map을 복사해 `setState`하지 않고, 같은
프레임의 성공·실패 결과를 pending collection에 모아 post-frame callback 한 번으로 갱신한다.

### 앱 시작 중 warmup

타이틀이 이미 받은 catalog에서 이름순 첫 64명과 인연 배경 3종을 선정한다. 첫 frame 뒤부터
8개씩 `precacheImage`하고 batch 사이 한 frame을 양보해 시작 화면 자체를 막지 않는다.
사용자가 타이틀을 빨리 통과하면 offstage StudentPage가 shared warmup controller를 이어받는다.
또한 `1/255` opacity의 실제 1-card grid painter를 잠시 실행해 단순 decode뿐 아니라 clip,
alpha layer, outline, badge, text 합성 경로도 미리 준비한다. [@student-grid-warmup]

모든 64장을 한 프레임에 precache하거나 완전 투명(`opacity: 0`) 위젯만 두는 방식은 피한다.
전자는 타이틀 첫 프레임으로 렉을 이동시키고, 후자는 Flutter가 paint를 생략해 합성 경로가
warmup되지 않을 수 있다.

## Section 3 선택 초상 통일 과정

학생 탭 Section 3의 첫 구현은 Studio `container-1` 전체 rounded parallelogram을 clip·테두리·배지
host로 사용했다. 내부 이미지는 `BoxFit.contain`으로 별도 배치되어 실제 이미지 rect와
외부 카드 path가 달랐다. 이 때문에 이미지 비율을 유지하면 여백과 외곽선이 분리되고,
컨테이너를 채우면 초상이 잘리는 선택 문제가 생겼다.

`BoxFit.cover`는 비율을 유지한 채 공간을 모두 채우므로 남는 축이 잘린다. 사용자는 초상
내용과 비율을 더 중요하게 보고 좌우 또는 상하 여백을 허용하기로 결정했다. 따라서
Section 3도 그리드와 완전히 같은 방식으로 변경했다.

- `container-1`은 배치 slot일 뿐 카드 외곽 형상을 소유하지 않음
- `252×204`를 `BoxFit.contain`한 fitted rect가 실제 visible card
- 배경: `edgeCropFraction 0.11`, `studentGridCardPath` clip
- 초상: `scale 0.98`, `clipRadiusFraction 0.12`, `alphaThreshold 0.04`
- Section 3 전용 overlay painter 제거
- `StudentGridCardOverlayPainter`를 1×1, name/attribute off, selection null로 재사용

따라서 Section 3의 암전, `0.01` 흰 선, 세 배지까지 Section 2와 동일한 fitted rect와 path를
사용한다. slot 비율이 다르면 여백이 생기는 것은 오류가 아니라 명시적으로 선택한 계약이다.

계획 요소 Section 3은 한 단계 더 나아가 Studio `container-1` 자체를 삭제했다. 초상 전용
`StudioPlacementRect`는 Section 3 좌표계 안의 배치 정보만 제공하고, visible surface는
`AssetImageGrid`와 1×1 `StudentGridCardOverlayPainter`가 전부 소유한다. 이로써 초상 바깥에
별도의 평행사변형 fill·clip·outline이 남지 않는다. 초상을 오른쪽으로 옮기고 폭을 fitted card에
맞춰 줄인 여유로 좌측 인연 삼각형도 오른쪽으로 옮겨 Section 외곽 rail에 잘리는 면적을 줄였다.
계획 화면의 배지 입력은 `seed.owned`, 기존 계획 요소 존재 여부, `jp_only` 메타데이터다.

후속 상단 재배치에서는 계획 초상의 높이를 고정 placement 비율로 두지 않고 Container 2의
실제 clipped path 높이에서 계산한다. 카드 비율을 유지하는 데 필요한 폭은 Container 2의
우측 끝을 고정한 채 폭을 조절한다. 후속 확장에서는 남은 간격의 절반만 사용해 두 80도
사선의 기준 간격을 24px에서 12px로 줄였다. 인연
삼각형 placement 높이는 1.3배로 늘렸고 acute-corner rounding 뒤 실제 visible 높이도 30%
이상 증가하는지 별도로 확인한다. 레벨/학교 구분선 역시 `height / tan(80°)`의 동일한
rail 계산을 사용해야 하며 `width * 0.06` 같은 고정 비율은 viewport마다 각도가 달라진다.
구분선과 무관한 70:30 `Row`는 로고 영역이 사선을 침범할 수 있으므로, 레벨은 하단 교점
왼쪽, 학원 로고는 상단 교점 오른쪽의 안전 영역에 배치한다. 로고의 기존 하향 translate는
하단 clip을 만들 수 있어 같은 시각적 top inset을 padding으로 흡수한다.

계획 화면에서 학교 문양 자체를 사용하지 않는 경우에는 공용 위젯을 복제하지 않고
`StudentLevelStatus(showSchool: false)` 변형을 사용한다. 이 변형은 Feature 2의 외곽 크기와
clip을 유지하면서 내부 학교 배경·80도 구분선·로고를 모두 생략하고 레벨 surface를 전체
영역에 채운다. 기본값은 `true`이므로 학생 탭의 레벨/학교 인디케이터는 바뀌지 않는다.

계획 인연 삼각형은 크기를 유지하면서 Container 5 스킬 패널의 좌측 시작 x와 같은 값으로 이동한다.
게이지 합성도 학생 탭 Container 10과 동일하게 foundation painter가 texture와 outline을
소유하고, clipped child에는 `StudentBondStatus`만 둔다. child 바깥의 별도 `ColoredBox`와
border painter는 foundation 위를 다시 덮어 학생 탭과 다른 결과를 만들므로 제거한다.
좌향 계획 삼각형은 학생 탭 우향 삼각형을 이미 180도 돌린 외곽 path이므로 child의
`CustomPaint`를 다시 회전하지 않는다. `inverted` 상태에서는 실제 좌향 path의 상단 span에
숫자를 놓고 그 아래 영역을 gauge host로 잘라 위에서 아래로 진행량을 채운다.

## 검증 이력과 한계

최종 상태에서 다음 검증이 통과했다.

- 학생 레이아웃 집중 테스트 45개
- 타이틀·학생 관련 누적 집중 테스트 71개
- Flutter 전체 테스트 284개 (`--concurrency=1`)
- `flutter analyze`
- Windows release build
- `codealmanac validate`
- `git diff --check`

하지만 직사각형 경계 문제는 여러 단계에서 자동 테스트가 통과했는데도 실화면에 남았다.
기존 테스트는 각 painter가 받은 설정이나 path만 확인했으며, 여러 합성 단계가 최종 픽셀에서
같은 형상을 공유하는지는 충분히 검증하지 못했다. 사용자 확대 캡처에서 선의 방향, 길이,
반복 주기를 비교한 것이 최종 원인 규명에 결정적이었다. [@student-layout-tests]

## 재발 방지 원칙

1. 카드 형상은 PNG alpha, widget rect, overlay rect가 나눠 소유하지 않는다. 하나의 geometry
   path를 clip·overlay·stroke·badge가 공유한다.
2. 축 정렬 직사각형과 둥근 평행사변형 outline을 먼저 구분한다. 선의 모양이 다르면 외곽
   컨테이너부터 수정하지 않는다.
3. 이미지 편집기에서 알파가 깨끗해도 Flutter의 fitted rect, filter layer, overlay mask가 만든
   경계는 별개로 조사한다.
4. crop, alpha cutoff, layer padding은 서로 다른 문제를 해결한다. 하나를 만능 원인으로
   간주하지 않는다.
5. 배지는 최종 clip 내부 child가 아니라 clip 이후 foreground에 그리고, 실제 rounded path의
   코너와 80도 rail에서 위치를 계산한다.
6. 사선 공간에 텍스트를 맞출 때 무제한 축소하지 않는다. 최소 폭을 확보하고 필요하면 주변
   제어의 순서를 바꾼다.
7. 보기 전환은 데이터 변경과 section motion의 시점을 분리한다. outro 완료 뒤 child를 바꾸고
   intro를 실행한다.
8. 첫 진입 최적화는 보이는 행 제한, image completion batching, decode warmup, 실제 paint-path
   warmup을 각각 구분해 적용한다.
9. `BoxFit.contain`은 전체 이미지 보존과 여백, `BoxFit.cover`는 빈 공간 제거와 crop의
   트레이드오프다. 카드 형상을 통일하기 전에 어느 쪽이 우선인지 확정한다.
10. 설정 단위 테스트가 통과해도 사용자 확대 캡처에서 반복되는 1px seam은 최종 raster
    합성 계약 문제로 취급한다.

## 후속 작업 체크리스트

- 실제 Windows 화면에서 Section 2와 Section 3의 흰 선, 배지 corner 접점과 PLAN 간격 확인
- PLAN 목업 데이터가 생기면 `UNOWNED` 아래·왼쪽 이동과 JP 동시 표시 확인
- 비정수 DPI에서 흰 선과 선택선의 계단 및 1px seam 확인
- 첫 앱 실행 중 타이틀 frame time과 학생 탭 첫 진입 frame time을 profile mode로 비교
- 학생 수가 늘어날 때 64개 warmup 상한과 visible row buffer가 여전히 적절한지 측정
- 필요하면 여러 합성 단계를 함께 그리는 golden/raster regression test 추가
