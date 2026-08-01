---
title: "학생 상세 상태 인디케이터 반복 개선 기록"
summary: "학생 탭 목업 데이터와 우측 상세 상태 패널을 구현하면서 받은 사용자 피드백, 실패한 기하 접근, 현재 렌더링 계약과 후속 작업 원칙을 기록합니다."
topics: [design, flutter, diagonal-layout, testing, workflow]
sources:
  - id: student-section-layout
    type: file
    path: frontend/lib/ui/widgets/student_section_layout.dart
  - id: student-layout-tests
    type: file
    path: frontend/test/student_studio_layout_test.dart
  - id: mock-student-fixture
    type: file
    path: frontend/lib/services/mock_student_fixture.dart
  - id: student-studio-layout
    type: file
    path: frontend/lib/ui/studio/student_studio_layout.dart
  - id: p0-p6-status
    type: file
    path: almanac/workflows/p0-p6-workflow-status.md
---

# 학생 상세 상태 인디케이터 반복 개선 기록

## 목적과 범위

이 문서는 2026-07-31부터 2026-08-01까지 학생 탭의 목업 보유 학생 데이터와 우측
상태 인디케이터를 반복 개선한 과정을 보존한다. 단순 완료 목록보다 다음 내용을 우선한다.

- 사용자가 실제 화면에서 재지적한 부분
- 자동 테스트가 통과했는데도 시각 결과가 틀렸던 이유
- 폐기하거나 되돌린 구조
- 현재 코드가 사용하는 좌표계, 경로, 여백과 반경 계약
- 다음 작업자가 같은 시행착오를 반복하지 않기 위한 확인 순서

실제 동작의 기준은 항상 코드이며, 이 문서와 코드가 다르면 코드를 우선한 뒤 문서를
갱신한다. 세션의 완료 상태와 검증 이력 요약은 활성 P0–P6 기록을 따른다.
[@student-section-layout] [@student-layout-tests] [@p0-p6-status]

## 초기 데이터와 표시 범위

학생 탭 표시 기능의 밑작업으로 canonical 학생 42명을 선택 프로필의 confirmed current에
주입했다. 레벨 1~90, 1~5성, 전용무기, 인연, 스킬, 장비, 능력개방, 전투 능력치와
애장품 상태를 서로 다른 순열로 분산했다. 전투 능력치는 6자리까지 포함한다.
[@mock-student-fixture]

우측 상세 영역은 조회 전용이며 미보유·복수 상태 표현은 별도 후속 범위다. 최종적으로
다음 정보를 Studio의 학생 상세 컨테이너에 배치했다. [@student-studio-layout]

- LEVEL과 학교 로고
- Position, Class, Weapon level
- EX, Normal, Passive, Sub-skill
- 장비 1~3과 애장품
- HP, ATK, DEF, HEAL 전투 능력치
- Ability Release의 HP, ATK, HEAL
- 잠금 상태의 심상개화
- 숫자만 표시하는 인연 랭크와 삼각형 게이지

## 섹션 의미와 텍스트 결정

초기 배치 해석에서 `해금`·`전용무기` 텍스트가 있던 영역을 스킬로, `스킬` 텍스트가
있던 영역을 장비로 사용하도록 바로잡았다. 최하단은 심상개화 잠금 영역이다.

상단 메타데이터는 다음 규칙으로 정리됐다.

- position은 `Back`처럼 title case로 표시한다.
- 역할명 대신 전투 편성 구분인 `Striker` 또는 `Special`을 표시한다.
- Weapon 행은 총기 아이콘과 `Weapon` 접두어를 제거하고 `Lv. N`만 표시한다.
- 학교 로고는 흰색으로 처리하고 레벨 값과 시각 중심을 맞춘다.
- `Position`, `Class`, `Weapon` 라벨은 숫자 접두어 없이 핑크색으로 표시한다.

명시적 섹션 제목은 `LEVEL`, `SKILL SUMMARY`, `EQUIPMENT`, `STATS`,
`Ability Release`를 사용한다. `Ability Release`는 한글 병기를 제거하고 다른 섹션 제목과
같은 스타일로 좌측 정렬한다.

## 스킬과 장비 패널 반복 개선

스킬은 네 개의 독립 열로 분리했다. 초기 구조 개선안에 있던 스킬 아이콘과 숫자 아래
진행 바는 사용자의 후속 지시에 따라 제거했다. 열 사이 구분선은 화면상 80도 빗면과
평행해야 하므로 고정 슬롯 폭으로 잘라 그리지 않고 실제 끝점을 80도 직선에서 계산한다.
장비 네 열에도 같은 규칙을 적용한다.

사용자 피드백으로 `SKILL SUMMARY`와 `EQUIPMENT` 제목이 상단 빗면에 너무 붙은 문제가
반복 확인됐다. 제목 아래 가로 구분선을 추가하고 제목을 안전 영역으로 내렸다. 이후
EX·Normal·Passive·Sub-skill 라벨은 헤더선과의 간격이 기존의 절반이 되도록
`Alignment(0, -0.5)`로 올렸다. 스킬 값은 `21px`에서 `31.5px`로 1.5배 확대했다.

장비 티어와 레벨은 각각 평행사변형 윗변과 아랫변의 중앙에 사선 흐름을 따라 배치하고
기존 대비 1.5배 확대했다. 애장품 값은 스킬 값과 같은 크기를 사용한다.

## STATS와 Ability Release에서 발생한 피드백

STATS 값은 HP·ATK·DEF·HEAL 라벨을 최종적으로 제거하고 아이콘과 최대 6자리 숫자만
남겼다. ATK 아이콘은 번개 대신 칼 모양 custom painter를 사용하며 모든 아이콘은 숫자와
같은 19px 크기와 수직 중심을 사용한다.

처음에는 각 능력치 행만 높이에 따라 80도 레일을 따라 이동하고 행 사이 가로선은 같은
X 좌표에 고정돼 있었다. 사용자는 구분선 끝점들이 수직으로 쌓여 평행사변형 밖으로
나간다고 지적했다. 해결은 각 행 경계의 정규화된 Y에 대해
`-height / tan(80°) * normalizedBoundary`를 계산해 가로선 전체를 이동하는 것이었다.

STATS 제목 옆 구분선은 한때 80도 사선으로 구현했지만, 사용자는 이 선은
`SKILL SUMMARY` 헤더처럼 가로선이어야 한다고 명시했다. 현재 STATS 헤더는 스킬·장비와
동일한 가로 구분선이며, 행 사이 가로선만 패널 레일을 따라 점진적으로 이동한다. 제목
구분선과 행 구분선의 요구를 혼동하지 않아야 한다.

Ability Release 제목은 좌측 안전 레일에 붙고, HP·ATK·HEAL 값 묶음은 제목을 제외한
나머지 영역의 중앙에 배치한다.

## 인연 랭크 구조의 변경 이력

인연 랭크는 다음 구조를 순차적으로 거쳤다.

1. 우하단 삼각형 안의 숫자
2. 별도 세로 핑크 게이지
3. 좁은 독립 평행사변형 게이지
4. 독립 게이지 제거 후 남은 우측 삼각형 재사용
5. 삼각형 내부의 어두운 트랙, 아래에서 위로 차는 핑크 fill, 별도 하단 숫자 영역

현재는 5번 구조다. 하트와 `인연` 텍스트는 표시하지 않으며 숫자만 사용한다. 숫자는
43.2px이고 하단 잔여 공간의 시각 중심에 맞추기 위해 폭에 따라 3~8px 왼쪽으로 이동한다.

## 인연 게이지에서 실패한 접근과 원인

### 1. 이상적인 삼각형 좌표만 평행 이동

첫 접근은 80도 직선 삼각형의 세 변을 수학적으로 같은 법선 거리만큼 평행 이동하는
방식이었다. focused test는 세로변과 빗면의 선간 거리가 같다고 판정했다. 하지만 실제
화면에서는 빗면 간격이 줄지 않았다.

원인은 테스트와 렌더링이 다른 경로를 사용했기 때문이다.

- 테스트는 둥글기 전의 재구성된 삼각형 두 개를 비교했다.
- 실제 외부 패널은 `radius: 10`으로 둥글게 만든다.
- 그 경로를 부모 섹션과 `PathOperation.intersect`한 뒤 다시 `ClipPath`로 자른다.
- 내부 게이지는 외부 path bounds의 크기만 받아 별도의 이상적 삼각형을 재구성했다.

내부 빗면이 실제 외부 clip 밖으로 나가면 화면에 보이는 빗면은 이동한 내부선이 아니라
고정된 외부 `ClipPath`가 된다. inset 픽셀을 줄여도 세로변만 움직이고 빗면은 움직이지
않았던 직접 원인이다.

### 2. 픽셀만 조금 줄여 크기를 키운 접근

초기 inset은 2~4px에서 1.5~3px로 줄였고 랭크 영역과의 간격도 조금 줄였다. 수학적으로는
크기가 증가했지만 일반 패널 높이에서 위·아래 합계 수 픽셀에 불과했다. 외부 삼각형
자체의 Studio rect와 spec도 그대로였으므로 사용자는 화면이 똑같다고 판단했다.

따라서 “테스트 값이 변했다”와 “육안으로 의미 있는 면적 변화가 생겼다”를 구분해야 한다.
작은 경사 패널은 절대 픽셀과 전체 높이 대비 변화율을 함께 기록해야 한다.

### 3. 하단 반경을 3~6px로 직접 지정

실제 외부 경로를 사용한 뒤 하단 mask에 3~6px 반경을 적용했지만 모서리가 충분히
둥글어 보이지 않았다. 이후 균등 inset이 3.5~6.5px를 다시 제거하므로 최종 내부 경계에
남는 반경이 거의 0이 됐기 때문이다.

현재 host mask 반경은 `10px + inset + 0.5px`, 즉 13.5~16.5px다. inset 처리 후 최종
보이는 하단 모서리에 외부 패널과 비슷한 약 10px 반경이 남도록 역보정한다.

## 현재 인연 게이지 렌더링 계약

현재 구현은 다음 순서를 사용한다. [@student-section-layout]

1. `studentContainerPath`가 만든 실제 container-10 경로를 local path로 변환한다.
2. 이 path에는 외부 10px rounding과 부모 섹션 교차 결과가 이미 포함돼 있다.
3. 랭크 영역 직전에서 actual path의 수평 내부 span을 샘플링한다.
4. 그 span으로 하단 양쪽이 둥근 mask를 만들고 actual path와 교차한다.
5. `BlendMode.clear` stroke로 동일 폭을 안쪽에서 제거해 track inset을 만든다.
6. outline, dark track, pink progress가 같은 host와 inset 계약을 사용한다.
7. progress는 rank/100 비율로 아래에서 위로 채운다.

현재 주요 값은 다음과 같다.

| 항목 | 현재 값 |
|---|---|
| 외부 패널 반경 | 10px |
| 게이지 균등 inset | 폭에 따라 3~6px |
| fill 경계 보정 | inset + 0.5px |
| 하단 host 반경 | 10px + inset + 0.5px |
| 게이지와 랭크 영역 간격 | 높이에 따라 3~4px |
| 랭크 숫자 왼쪽 이동 | 폭에 따라 3~8px |
| 랭크 글자 크기 | 43.2px |

## 삼각형 텍스처

학생 상세 영역에서 삼각형 무늬가 적용되는 surface는 레벨 패널 계열의 파란 palette를
공유한다. 사용자 요청으로 기본 tessellation 명암 대비를 `0.024`에서 `0.030`으로
올렸다. hue, seed와 palette 역할은 변경하지 않았다. 대비를 다시 조정할 때는 색을
바꾸기보다 명도 차이, face size와 fog의 관계를 먼저 조정한다.

## 검증과 검증의 한계

세션 중 집중 학생 레이아웃 suite는 최종적으로 38 tests를 통과했고 `flutter analyze`,
`codealmanac validate`, `git diff --check`도 통과했다. 이전 중간 단계에서는 전체 Flutter
263 tests와 Windows release build도 통과했다.

그러나 자동 테스트 통과가 시각 정답을 보장하지 않았다. 특히 초기 equal-inset test는
서로 같은 잘못된 재구성 좌표를 비교했기 때문에 실제 clip 불일치를 놓쳤다. 향후
게이지 geometry test는 다음을 확인해야 한다.

- ideal polygon이 아니라 실제 rounded·parent-intersected local path를 입력으로 사용
- path bounds뿐 아니라 실제 raster 또는 representative sample point 확인
- inset 변경 전후의 세로변과 빗면 모두에서 보이는 픽셀 거리 비교
- clear stroke 이후 최종 반경을 확인하고 host 반경만 검사하지 않기
- 1280×720, 1920×1080, 2560×1392와 비정수 DPI에서 확인

사용자가 한 단계에서는 최종 화면 검증을 직접 맡겠다고 명시했다. 그 경우 자동
검증 결과와 “실화면 사용자 확인 대기” 상태를 구분해 보고해야 한다.

## 시행착오에서 얻은 원칙

1. child geometry를 `path.getBounds().size`로 재구성하지 않는다. 부모 교차까지 끝난 실제
   local path를 child painter에 전달한다.
2. equal gap은 X 차이가 아니라 각 변의 법선 거리 또는 동일 stroke inset으로 정의한다.
3. rounded outer path와 sharp inner polygon을 비교하는 테스트는 화면 계약을 검증하지 못한다.
4. 후처리로 inset을 제거한다면 목표 최종 반경에 제거 폭을 더해 host 반경을 정한다.
5. header line, row divider와 column divider는 서로 다른 요구다. 사용자가 가리킨 선의
   계층을 먼저 확인한다.
6. 고정된 사선 패널 안의 row와 divider는 같은 Y 기반 rail 함수를 공유한다.
7. 작은 수치 변경은 전체 패널 대비 변화율을 계산하고, 육안으로 의미 있는지 판단한다.
8. 사용자 이미지와 피드백이 자동 geometry test보다 우선하는 경우, 테스트가 무엇을
   빠뜨렸는지 먼저 설명한 뒤 경로 계약을 고친다.

## 후속 작업 체크리스트

- 사용자 실화면에서 하단 내부 모서리의 약 10px 최종 반경을 확인한다.
- 빗면·세로면의 실제 보이는 간격이 3~6px로 함께 변하는지 확인한다.
- 랭크 숫자의 3~8px optical shift가 compact와 wide에서 과하지 않은지 확인한다.
- 필요하면 actual-path painter의 raster pixel test를 추가한다.
- 외부 container-10 크기 자체를 바꾸는 요청과 내부 gauge inset 요청을 구분한다.
- 미보유 및 여러 상태 표시는 현재 read-only indicator 작업과 분리해 구현한다.
