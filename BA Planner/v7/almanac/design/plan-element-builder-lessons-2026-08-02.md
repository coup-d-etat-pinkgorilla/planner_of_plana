---
title: "계획 요소 제작 화면 구현·시행착오 기록"
summary: "계획 요소 제작 화면의 네 섹션 계약, 학생 상태 카드의 최종 렌더링 구조, 프리셋 적용과 단계 편집 규칙, 반복된 geometry·합성 실패와 재발 방지를 기록합니다."
topics: [design, flutter, planning, preset, diagonal-layout, testing]
sources:
  - id: plan-element-builder
    type: file
    path: frontend/lib/ui/widgets/plan_element_builder.dart
  - id: planning-models
    type: file
    path: frontend/lib/ui/models/planning_models.dart
  - id: plan-starter-layout
    type: file
    path: frontend/lib/ui/studio/plan_starter_studio_layout.dart
  - id: preset-element-layout
    type: file
    path: frontend/lib/ui/studio/preset_element_studio_layout.dart
  - id: student-indicators
    type: file
    path: frontend/lib/ui/widgets/student_section_layout.dart
  - id: plan-element-tests
    type: file
    path: frontend/test/plan_element_builder_test.dart
  - id: product-contract
    type: file
    path: docs/migration/p2-planning-screen/plan-element-builder-contract-2026-07-31.md
  - id: workflow-status
    type: file
    path: almanac/workflows/p0-p6-workflow-status.md
---

# 계획 요소 제작 화면 구현·시행착오 기록

## 범위와 현재 화면 구조

계획 요소 제작 화면은 `PlanningStudentSeed` 한 명을 받아 네 개 Section을 동시에 표시한다.

- Section 3: 학생의 현재 상태를 읽기 전용으로 표시한다.
- Section 5: 인메모리 프리셋 목록을 불러와 제작 draft 전체를 덮어쓴다.
- Section 6: 순서가 있는 누적 목표 단계 카드를 편집한다.
- Section 7: 확정됐지만 아직 페이즈에 배정되지 않은 요소만 표시한다.

Section 5는 프리셋 **관리** 화면이 아니다. 현재 구현은 외부에서 받은 목록 또는
`defaultPlanElementPresets` fixture를 선택하는 loader뿐이다. 저장·이름 변경·삭제·복제·기본
지정·영속화는 다음 프리셋 관리 탭의 범위다. [@plan-element-builder] [@planning-models]

## 단계와 프리셋의 확정 계약

한 학생은 여러 계획 단계를 가질 수 있다. 단계는 누적 절대 목표 snapshot이며 순서를 직접
바꾸지 않는다. 새 단계는 선택 단계 바로 뒤에 그 snapshot을 복제해 만들고, 단계 삭제 뒤에는
이전 단계에 포커스를 둔다.

이전 단계의 값을 이후 단계보다 높이면 이후 단계의 같은 필드를 자동으로 올린다. 이전 단계
값을 낮춰도 이후 값은 자동으로 낮추지 않는다. 확정할 때 현재 상태보다 증가가 없는 단계는
결과에서 제외한다. 목표를 바꾸거나 단계를 추가·삭제한 학생은 페이즈 배정을 다시 해야 하며,
표시 이름만 바꾼 경우에는 배정을 유지한다. [@product-contract]

프리셋은 sparse 절대 목표 단계 목록이다. 첫 단계의 미지정 값은 학생 현재값, 다음 단계의
미지정 값은 직전 단계 값을 승계한다. 프리셋 선택은 현재 제작 draft 전체를 덮어쓴다. 이미
달성한 단계는 제외하고, 각 목표는 현재값보다 낮아지지 않으며 단계 순서상 단조 증가를
유지한다. 현재 `PlanElementPreset`은 `id`, `name`, `isDefault`, `stages`만 가진 인메모리 타입이며
version, scope, serialization, repository field는 없다. [@plan-element-builder] [@planning-models]

## Section 6 카드 구조

단계 카드는 `section-preset-element.ba-section-studio.json`과 typed projection을 source of
truth로 사용한다. `element-5`는 배경 카드일 뿐 전체 clip이 아니다. 우측으로 돌출되는
`element-2`, `element-3`, `element-4`를 포함한 아홉 surface의 합집합이 카드의 선택·hover·ink
영역이다. 각 surface는 같은 실제 path를 fill, outline, clip, geometry test에 공유한다.

- Element 1: 학생 레벨
- Element 2: 전용무기 레벨
- Element 3: 인연 랭크
- Element 4: 학생·전용무기 성작 목표
- Element 5: 전체 배경과 단계 번호
- Element 6: 네 스킬
- Element 7: 장비·애장품
- Element 8: HP·공격력·치유력 추가 능력치
- Element 9: 잠긴 심상개화

성작은 학생 탭과 공용 세그먼트 painter를 사용하지만 Section 6에서는 아홉 개 독립 hit target과
토글을 유지한다. 시작 상태는 채움, 계획 목표는 학생 금색·전용무기 청색 outline으로 구분한다.
[@preset-element-layout] [@plan-element-builder]

## Section 3 최종 렌더링 계약

### 초상과 배지

초상은 별도 Container surface를 사용하지 않는다. Section 3 내부 독립 slot에서 학생 탭과 같은
`AssetImageGrid`, `studentGridCardPath`, `StudentGridCardOverlayPainter`를 직접 사용한다. 배경,
초상, 흰 outline, `UNOWNED / PLAN / JP` 배지가 같은 fitted card path를 공유한다.

초상 높이는 Container 2의 실제 clipped path 높이와 같고 `252:204` 비율을 유지한다. Container
2의 우측 끝은 고정하며 현재 좌측 placement는 `0.5602870942110612`, 폭은
`0.3479522131790751`이다. canonical `2560×1392`에서 초상과 Container 2의 평행 사선 간격은
12px이다. [@plan-starter-layout] [@plan-element-builder]

### 레벨과 전용무기

계획 화면의 Feature 2는 레벨 전용이다. 공용 `StudentLevelStatus(showSchool: false)`를 사용해
학교 배경·80도 구분선·학교 로고를 모두 생략하고 같은 Feature 2 전체 영역을 레벨 surface로
사용한다. 학생 탭은 기본값 `showSchool: true`이므로 기존 레벨/학교 인디케이터가 유지된다.

공용 위젯의 좁은 viewport에서는 `LEVEL` label도 한 줄 `FittedBox(scaleDown)`으로 축소한다.
학교 영역을 실제 split path에 맞추는 과정에서 안전 폭이 작아져 label이 여러 줄로 감기고
세로 overflow가 발생했던 회귀를 막기 위한 계약이다. [@student-indicators]

### 성작

Container 3은 외곽 카드 surface가 아니다. Section foundation의 fill·outline 대상에서 제외하고
학생 5칸·전용무기 4칸의 공용 세그먼트만 그린다. “외곽 테두리가 보인다”는 문제를 Container
배경색 조절로 해결하려 하면 다시 중복 surface가 생긴다. foundation ownership부터 확인한다.

### 인연 삼각형

Container 8은 `face: left` 삼각형이며 크기는 유지한다. 왼쪽 수직 변은 Container 5 스킬
패널의 왼쪽 시작점과 일치한다. placement 높이는 초기 값의 1.3배다. triangle의 실제 가시 폭은
placement width보다 높이와 80도 cut depth에 크게 좌우되므로 rect width만 보고 판단하지 않는다.

Section foundation이 Container 8의 triangle texture와 outline을 한 번만 그린다. clipped child에는
공용 `StudentBondStatus(inverted: true)`만 둔다. 별도 `ColoredBox`나 foreground border painter를
추가하면 학생 탭과 다른 이중 fill·outline이 생긴다.

계획 삼각형의 Studio path 자체가 이미 학생 탭 우향 삼각형을 180도 돌린 좌향 형상이다.
`CustomPaint` 전체를 다시 회전하면 painter가 받은 outer path와 canvas 좌표계가 달라져 gauge가
사라졌다. 최종 구현은 실제 좌향 rounded path의 상단 span에 숫자를 놓고, 그 아래 남은 path를
gauge host로 계산하며 progress를 위에서 아래로 채운다. [@student-indicators]

### 장비·애장품과 미구현 상태

애장품 메타데이터가 없거나 `no`이면 잠금 아이콘이 아니라 `-`를 표시한다. 메타데이터가
`yes`이고 현재 티어가 0일 때만 잠금을 표시한다. catalog DTO 연결은 아직 완료되지 않았다.
인연 비용 아이템 메타데이터도 미연결이며, 심상개화는 잠금 표시만 한다. 이 값들을 0 비용이나
달성 상태로 추론하지 않는다. [@product-contract]

## 주요 시행착오와 재발 방지

### Studio 좌표의 동일 숫자를 잘못 교체함

Container 3과 Container 8이 같은 left 값을 사용하던 시점에 숫자만 검색·치환해 Container 3을
먼저 바꿨다. 집중 geometry test가 즉시 rail 오차를 잡았다. Studio 좌표를 수정할 때는 반드시
`id` 문맥을 포함한 patch를 사용하고 typed projection과 `release/*.ba-section-studio.json`을 함께
갱신한다. parity test를 첫 검증으로 실행한다.

### canonical 폭을 잘못 가정함

Container 2를 12px 확장할 때 Section grid의 단순 27% 폭을 사용해 정규화했지만 실제 Studio
container projection은 720px 기준으로 환산됐다. 첫 결과는 목표 12px가 아니라 11.5px였다.
화면 비율만으로 정규화 값을 추정하지 말고 runtime raw polygon endpoint 간격을 test에서 직접
측정해 보정한다.

### 이상 polygon과 실제 rounded path를 혼용함

인연 gauge, 사선 gap, 내부 content 안전 영역은 ideal 80도 polygon으로만 계산하면 rounded
corner와 parent intersection 이후의 실제 표면과 달라진다. visible surface를 소유하는 실제
rounded local path를 child painter에 전달하고, 같은 path에서 span·inset·host를 계산한다.

### 외곽과 child가 같은 surface를 두 번 그림

Container foundation 위에 child `ColoredBox`와 border painter를 다시 올려 색과 테두리가 학생
탭과 달라졌다. fill·texture·outline은 foundation, 내부 gauge·text는 clipped child처럼 ownership을
한 곳에 둔다. 눈에 보이는 테두리 문제는 painter를 추가하기 전에 중복 owner를 먼저 찾는다.

### 공용 위젯 변경이 작은 viewport를 깨뜨림

학교 logo clipping을 막으려고 70:30 Row를 실제 split 안전 영역으로 바꾼 뒤 학생 탭의 작은
indicator에서 `LEVEL`이 여러 줄로 감겨 9px 세로 overflow가 발생했다. 계획 화면 검증만으로
공용 위젯 변경을 끝내지 말고 학생 page의 1280×720 등 좁은 viewport 회귀도 함께 실행한다.

### 임시 raster probe가 timeout 뒤 늦게 산출됨

widget raster 캡처 호출이 timeout됐지만 PNG와 `flutter_tester`가 뒤늦게 남았다. visual probe가
timeout되면 생성 파일과 process를 다시 확인하고, 실제 workspace 안의 정확한 임시 경로만
검증 후 제거한다. timeout은 제품 test 실패와 구분해 기록한다.

## 2026-08-03 단계 카드 숫자·MAX·장비 편집 보정

- 학생 레벨, 전용무기 레벨, 인연 랭크, 네 스킬의 숫자 style은 학생 상태
  인디케이터 스킬 숫자 31.5px의 80%인 25.2px을 사용한다. `Lv`, `R`, `EX/기본/강화/서브`
  prefix는 제거했고, 감소·증가는 16.5px `−`/`+` 텍스트로 통일했다.
- 각 숫자 편집기 아래에 `MAX` 배지를 두었다. 일반 필드는 해당 계약 상한으로,
  장비 슬롯은 티어와 레벨을 함께 상한으로 올린다. 이후 단계의 단조 증가 전파는 기존
  `_setTarget` 계약을 그대로 재사용한다.
- 장비 영역은 티어 컨트롤, 학생 메타데이터로 계산한 티어 아이콘, 레벨 컨트롤,
  `MAX`를 가진 4열 인디케이터형 편집기로 교체했다. 아이콘 host는 원래 인디케이터의
  0.96 비율에서 30% 줄인 0.672를 사용하고, 레벨 텍스트는 13.5px의 1.2배인
  16.2px을 사용한다.
- 추가 능력치는 `HP`, `ATK`, `HEAL`로 통일하고 라벨·숫자를 기존 9px의 1.5배인
  13.5px로 키웠다.
- 큰 컨트롤을 기존 43-row 카드에 단순 추가하면 인연·추가 능력치의 `MAX`가
  clip되고 스킬이 두 행으로 wrap된다. 첫 보정은 49-row로 늘려 clip을 막았지만,
  실화면에서 학생 레벨·스킬·심상개화 패널의 빈 세로 공간이 과도했다. 최종값은
  외곽 34-row, 레벨·전용무기·인연·스킬 4-row, 장비 7-row, 추가 능력치·심상개화
  3-row다. 제목 padding, 제목-컨트롤 gap, ± hit box, MAX 배지의 수직 padding도 같이
  축소했다. 스킬 4개와 추가 능력치 3개는 `Wrap`이 아닌 균등 단일 행으로 배치하며,
  widget test가 각 배지의 전역 bounds가 대상 element bounds 안에 있는지 고정한다.
- 최외곽 카드는 개별 패널 bounds의 convex hull을 사용하면 패널은 모두 감싸지만
  변이 불규칙해져 평행사변형 계약을 잃는다. 최종 구현은 모든 패널의 80도 rail 범위를
  구한 뒤 하나의 둥근 80도 평행사변형 envelope를 만들고, 하단 패널을 같은 rail을 따라
  왼쪽으로 재배치한다. containment test와 네 꼭짓점·좌우 변 각도 test를 함께 둔다.
- Section 6의 카드 폭은 과거의 고정 카드 높이 `520px`로 좌측 inset을 추정하지 않는다.
  Studio의 Section `width`는 평행사변형 bounding box 폭이 아니라 수평 rail 길이다.
  여기에 Section 전체 높이의 사선 이동량을 다시 빼면 우측에 큰 빈 영역이 생긴다.
  Section rail 전체에서 좌우 8px만 뺀 뒤 카드의 실제 종횡비와 80도 tangent로 bounding
  box 폭을 역산하고, Section의 실제 우측 사선 위치에 정렬한다. 카드 비율이 다시
  바뀌어도 Section 가용 폭을 과도하게 버리지 않도록 geometry test로 고정한다.
- 단계 목록은 직사각형 `ListView` 대신 전용 사선 스크롤 구조를 사용한다. 각 카드의
  viewport Y와 scroll offset을 80도 tangent로 X 이동량으로 환산해 스크롤 중에도
  Section rail을 따라가게 한다. 기본 scrollbar는 숨기고 우측 80도 rail 위에 track과
  handle을 그리며, scroll range에 따라 상·하단 fog를 표시한다.
- Section 6과 단계 목록 사이에는 계획-메인 `planPhaseContainerPath` 계약을 따른 별도
  외곽 컨테이너를 둔다. 단순 X축 inset은 왼쪽 사선에서 여백이 사라지므로 양쪽
  `x + y / tan(80°)` rail을 법선 거리 12px만큼 안쪽으로 이동한 80도 path를 Section
  path와 intersect하고, 계획-메인과 같은 삼각 텍스처·0.9px outline을 그린다. 하단은
  62px 버튼 영역과 버튼 위·컨테이너 사이 12px를 남긴다. 목록·fog·
  scrollbar만 이 컨테이너 path로 clip하며 하단 버튼은 부모 Section의 별도 자식이다.
  카드 폭과 X offset도 같은 법선 12px 내부 간격·14px scrollbar reserve·카드 하단
  viewport Y 기반 공식을 사용한다.
- 2026-08-03 후속 배치는 프리셋 카드 높이를 유지하고 너비만 이전 계산값의 95%로
  줄인다. 내부는 `학생 레벨 / 전용무기 레벨 / 인연 랭크` 1행 3열, 성작 strip,
  스킬, 장비, 추가 능력치, 심상개화 순서다. 상·하단과 여섯 행 사이 세로 간격은
  모두 24px이며, 각 행과 카드 양쪽 80도 rail 사이도 법선 24px을 유지한다. 상단
  세 열 사이 역시 법선 24px이다. 높이는 현재 카드의 남은 공간을 기존 4:1:4:7:3:3
  비율로 나누며, 후속 높이 보정과 content wrapping 전의 중간 계약이다.
- 인연 랭크의 unsupported `*` 표시는 제거했다. 성작 strip의 element surface fill과
  outline은 투명하게 하고 `StudentStarStatus`가 그리는 내부 평행사변형 segment만
  보이게 한다. exact pixel 배치는 Studio 정수 grid만으로 표현할 수 없으므로 Studio
  문서는 1행 3열 구조의 설계 projection을 보존하고 런타임 geometry 함수가 24px
  계약의 최종 source of truth다.

## 검증 기준선

2026-08-02 최종 기준선은 다음과 같다.

- 계획 요소·학생 Studio·학생 page 관련 75 tests 통과
- Flutter 전체 290 tests, `--concurrency=1` 통과
- `flutter analyze` 통과
- Windows release build 통과
- `codealmanac validate` 통과
- `git diff --check` 통과

다음 프리셋 관리 탭 작업도 최소한 계획 요소 집중 test, 학생 탭 공용 위젯 회귀, 전체 suite,
Windows release build를 다시 통과해야 한다. [@plan-element-tests] [@workflow-status]

## 2026-08-03 preset panel height pass

- Keep the preset card envelope height unchanged until the final content-wrapping
  pass. Scale only the current inner rows: the three top panels to 50%, skill and
  equipment to 60%, and additional stats to 80%.
- Preserve the exact 24px normal gaps while stacking the shortened rows. The
  resulting unused vertical space intentionally remains below the mind-growth row.
- Center the level, weapon-level, and bond-rank steppers in the available area
  beneath each title so the three-column row uses one alignment contract.
- The 95%-width card must receive half of the removed width as a horizontal rail
  offset. This keeps its left and right margins equal inside the content rail while
  preserving the diagonal scrollbar reservation.
## 2026-08-03 diagonal-list shrink correction

- A diagonal list must not derive card X placement directly from a stale
  `ScrollController.offset` while its child extent is shrinking. The controller's
  previous `maxScrollExtent` can survive through the first rebuild after deletion.
- Compute the effective offset from the new content height and viewport height for
  immediate geometry, then synchronize the controller to its post-layout extent in
  a post-frame callback. This prevents a deleted tail card from shifting the first
  remaining card to the right.
## 2026-08-03 preset card wrapping pass

- Preserve inner-row sizing from the former 36-grid unwrapped canvas even after the
  outer card is shortened. Otherwise deriving row heights from the wrapped height
  recursively shrinks every control panel.
- Increase the equipment row from a 0.60 to a 0.63 source-height scale, which is
  exactly 105% of its prior rendered height.
- Wrap the outer preset envelope to the sum of all scaled rows plus seven exact
  24px gaps. The seventh gap is the mind-growth-to-card-bottom clearance.
- Recalculate the diagonal rail width from the wrapped height's affine width
  relationship so the shorter parallelogram keeps equal side margins and the
  scrollbar reserve.
## 2026-08-03 equipment MAX lower-edge inset

- Increasing the equipment panel height alone does not guarantee lower clearance:
  its `Expanded` icon region consumes the added height and the trailing MAX badge
  remains the final child at the edge.
- Reserve an explicit 6px spacer after each regular equipment MAX badge. Treat this
  as a control safe inset and verify the rendered badge-to-panel-bottom distance,
  rather than relying on incidental parent padding.
## 2026-08-03 preset flow, right-list, and section motion pass

- Reuse the plan-main phase-flow visual contract between preset cards: a centered
  16x10 downward triangle in the existing 14px inter-card gap, using the same
  `0xfff2b3ef` color and 0.88 opacity. Its host follows the diagonal scroll rail.
- While the phase-editor launch action is temporarily hidden, remove its reserved
  right column as well. The unassigned list should consume the right section width
  between the existing 14px side insets.
- Animate the four builder sections with one synchronized 360ms controller and
  independent direction pairs: student/status and preset selection 0/180, preset
  card editor 80/260, and right list 180/0. Propagate the parent active state so tab
  deactivation plays the requested outro.
## 2026-08-03 bottom-center flow and right diagonal viewport pass

- A flow triangle centered in a parallelogram's bounding box is visually too far
  right. Its target X is the bottom-edge midpoint:
  `(width - height / tan(80deg)) / 2`. Use the preceding card/phase height and the
  same card host left coordinate for both plan-main and preset flows.
- Halving preset panel spacing means only the five vertical row-to-row gaps change
  from 24px to 12px. Preserve 24px card-edge clearances and the two 24px gaps among
  the three top columns, and retain the former source gap solely for row sizing.
- A rectangular `ListView` inside the right trapezoid is clipped by the changing
  trapezoid boundary. Expand `container-15` to 90% of its parent and use its saved
  parallelogram path as a clipped viewport. Position 66px rows on an 80-degree rail
  from viewport height, row Y, and scroll offset; include matching fog and a
  diagonal scrollbar.

## 2026-08-03 phase-editor-shaped right panel pass

- The preset builder's right-attached trapezoid now derives its inner list and
  bottom-right action from the same responsive geometry contract as the phase
  editor's right panel. The inner list is a clipped 80-degree parallelogram with
  equal 12px normal clearances; the action occupies only the lowest right control
  slot outside that list.
- Do not add a header to this surface. The list viewport starts at the inner
  parallelogram's top edge, and the former visible title/count row is absent.
- Restore only the phase-editor launch action. It remains disabled until plan
  elements exist, then invokes the existing phase-editor callback.
- Unassigned rows use the plan-phase media pattern: square item backing, student
  portrait, student display name, separator, and an editable stage-name field.
  Keep the existing rename commit behavior on submit and focus loss.

## 2026-08-03 blocked-reason, slanted controls, and row-shape correction

- Reserve a dedicated 30px blocked-reason strip between the shortened preset list
  viewport and the 62px control row. When no stage raises a target above the current
  state, disable confirmation and show the former snackbar explanation in that strip.
- Build each of the four control buttons from its actual laid-out size with one
  rounded 80-degree parallelogram path. Paint, clip, hover, splash, semantics, and
  hit testing share that path; do not rely on rectangular `FilledButton` surfaces.
- The right-side phase-editor action uses the requested muted purple palette and a
  deterministic BA triangle texture sized to 80% of the button height. Keep the
  disabled treatment readable instead of covering the surface with a heavy dark fill.
- Never scale a fixed 260x60 row path to an arbitrary row width. Non-uniform scaling
  changes the diagonal angle. Rebuild the path from the row's actual `Size`, matching
  the phase-editor source-row fill (`0xb7213c52`) and outline treatment.
- The right list container now shares the phase-editor blue texture palette and seed
  so its visible tessellation and color family match the reference panel.

## 2026-08-03 exact phase-list color and completion routing

- Matching a reference container requires the complete texture contract, including
  the deterministic seed. The preset right-list container now uses the plan-main
  phase container's exact blue palette and seed `404`, not merely similar colors.
- Completing phase assignment from the element-builder flow must close both nested
  surfaces. Clear `_showPhaseEditor`, `_showElementBuilder`, and `_builderSeed`
  together; otherwise hiding the phase editor reveals the stale student element
  builder beneath it instead of the plan main screen.
- Preserve the main-screen entrance state: phase element 2 is already completed by
  the phase-editor transition, while any other controller below 1 resumes forward.

## 2026-08-03 builder-owned exit motion and right-stage actions

- A parent must not remove the element builder immediately when a nested navigation
  button is pressed. The builder owns its four-section motion controller, so it now
  reverses that controller to completion before invoking either the phase-editor or
  plan-main navigation callback.
- The right trapezoid retains the phase action in its bottom control slot and derives
  two more 80-degree action paths above it at the normal component gap: return to plan
  in the middle and delete selected unassigned stage at the top. Each path is clipped
  to the section and shares its paint, ink, and hit geometry.
- Unassigned rows have one explicit local selection. Selection repaints the row with
  a pink outline and enables deletion; deleting removes only that stage and advances
  selection to a neighboring remaining row.
- Returning to plan closes only the student element builder. Confirmed plan elements
  remain available when the phase editor is subsequently opened from plan main.

## 2026-08-04 right-list texture parity and width reduction

- The element builder's right list now imports the phase editor path-surface texture
  contract directly. Matching the visible reference includes its deterministic
  triangle seed `8404`, not only the four blue colors and contrast values.
- Keep the right edge fixed while reducing Section 7 from grid rect `68/28` to
  `76/20`. With the fixed 12px normal insets included, the resulting inner list is
  70% of its former canonical width.
- The right action widths are height- and rail-derived rather than section-width
  derived. Therefore the narrower section preserves all three button widths,
  heights, gaps, and right alignment while only shortening the list and its rows.
- Paint, texture clipping, outline, scrolling, and hit testing continue to consume
  the same responsive path; do not independently scale the painted parallelogram.

## 2026-08-04 right-list local texture-canvas correction

- Copying a triangle configuration is insufficient when the destination painter
  still receives the full section canvas. Its light center and vignette are then
  evaluated far outside the narrow right-list bounds, leaving the visible list dark
  and making the triangle faces effectively disappear.
- Position the foundation painter at the list path's exact bounds and shift the path
  into that local coordinate system. The list surface, texture light center, and
  tessellation now all use the same local size as the phase-editor reference.
- Match the reference layer order as well: paint the translucent blue base path,
  clip and paint the triangle texture, then draw the outline. The extra base layer
  is part of the reference brightness contract rather than redundant paint.

## 2026-08-04 session retrospective: failed approaches and durable rules

This section consolidates the visual and behavioral failures encountered while
iterating the plan-element preset builder. It is intentionally organized by symptom,
failed approach, root cause, and the rule that should prevent another recurrence.

### 1. The outer container did not enclose its child panels

- **Symptom:** lower panels and the mind-growth area extended beyond the visible
  preset-card container even after the container height was increased.
- **Failed approach:** increase one fixed height or build an arbitrary convex hull
  around child bounding rectangles.
- **Root cause:** a convex hull can contain the children without preserving one
  parallel pair of 80-degree rails. Fixed heights also ignored later row scaling,
  explicit gaps, and the bottom safe inset.
- **Durable rule:** derive one enclosing 80-degree parallelogram from the complete
  row-height sum, every explicit gap, and the common rail extrema. Verify both child
  containment and the parallel-rail invariant; either assertion alone is insufficient.

### 2. The container enclosed the content but had an irregular silhouette

- **Symptom:** all panels were technically inside the container, but its left and
  right edges bent or no longer looked like a parallelogram.
- **Failed approach:** connect each child extremum directly into a many-vertex path.
- **Root cause:** containment geometry was mistaken for the visible design geometry.
- **Durable rule:** visible card envelopes must have exactly four rounded rail
  endpoints. Project child extrema onto the chosen 80-degree rails instead of adding
  more outline vertices.

### 3. Width and margin adjustments moved the wrong surface

- **Symptom:** increasing width removed one margin, created unequal margins, or left
  most of the section unused.
- **Failed approach:** change a bounding-box width or a child percentage without
  accounting for the diagonal rail displacement and scrollbar reserve.
- **Root cause:** a slanted component's bounding width is not its usable horizontal
  rail length. Its safe left and right distances change with Y.
- **Durable rule:** measure normal distance to the rendered rails. Treat
  section-to-container and container-to-card clearances as two independent contracts,
  and test both at the canonical canvas size.

### 4. Compacting rows by changing the outer height recursively shrank content

- **Symptom:** reducing the card height also made controls and text unexpectedly tiny,
  while increasing it left excessive empty space.
- **Failed approach:** derive inner row sizes from the already wrapped outer height.
- **Root cause:** the outer envelope and inner source-grid sizing formed a recursive
  dependency.
- **Durable rule:** keep one stable source canvas for row proportions. Calculate the
  wrapped outer height afterward from scaled row heights and explicit gaps.

### 5. Increasing the equipment panel height did not create MAX-button clearance

- **Symptom:** the equipment MAX badges remained attached to the lower edge after the
  panel was made 5 percent taller.
- **Failed approach:** assume extra parent height becomes trailing space.
- **Root cause:** the flexible icon region consumed the additional height, leaving the
  MAX badge as the final edge child.
- **Durable rule:** add an explicit trailing spacer or bottom padding after the badge.
  Assert the rendered badge-to-panel-bottom distance, not merely panel height.

### 6. Scroll deletion shifted the first remaining card to the right

- **Symptom:** after scrolling a multi-card list and deleting cards, the first card
  appeared far to the right.
- **Failed approach:** use `ScrollController.offset` directly during the rebuild.
- **Root cause:** the controller retained an offset valid for the old content extent
  until post-layout correction, and X position depends on that offset along the
  80-degree scroll rail.
- **Durable rule:** clamp an effective offset against the new content extent before
  computing X, then synchronize the controller in a post-frame callback. Test deletion
  at a non-zero scroll offset.

### 7. Flow triangles were mathematically centered but visually displaced

- **Symptom:** triangles between phase or preset items sat too far to the right.
- **Failed approach:** align to the parallelogram bounding-box center.
- **Root cause:** the requested anchor was the bottom-edge midpoint, whose X differs
  from the bounding center by the diagonal cut depth.
- **Durable rule:** for the current 80-degree rail use
  `(width - height / tan(80deg)) / 2` relative to the preceding item host. Reuse this
  rule for both plan-main phases and preset cards.

### 8. Right-panel rows were clipped, distorted, or almost invisible

- **Symptom:** rows disappeared at the slanted boundary, and an early row silhouette
  looked warped.
- **Failed approach:** place a rectangular list in the trapezoid or non-uniformly
  scale a fixed 260x60 path to a new row width.
- **Root cause:** the viewport did not follow the parent rail, while non-uniform path
  scaling changed the intended 80-degree angle.
- **Durable rule:** place a responsive inner parallelogram in the trapezoid; position
  each row along the same scroll rail; rebuild every row path from its actual `Size`.
  Never stretch a canonical diagonal path horizontally.

### 9. Section shrinking risked shrinking the action buttons

- **Symptom:** reducing the right list and section could also alter the stacked action
  controls, contrary to the visual requirement.
- **Rejected shortcut:** multiply the complete section, including controls, by 0.70.
- **Root cause:** list width and action-slot width are different geometry contracts.
- **Durable rule:** keep the section's right edge fixed, change the Studio grid from
  `x=68,width=28` to `x=76,width=20`, and leave button widths height/rail-derived.
  Compare current buttons with legacy button geometry in a regression test.

### 10. Copying colors did not reproduce the reference texture

- **Symptom:** the target list looked different even though its four colors matched.
- **Failed approach:** compare only palette values; the first copy retained seed
  `404` while the reference used `8404`.
- **Root cause:** deterministic triangle placement is part of the visual contract.
- **Durable rule:** export and reuse one `BATriangleTextureConfig` object rather than
  copying its fields. Tests must compare the shared object and deterministic seed.

### 11. Even the exact texture configuration still rendered dark and patternless

- **Symptom:** after sharing the reference configuration, the target remained darker
  and no triangle faces were apparent.
- **Failed approach:** paint the correct texture while leaving its canvas equal to the
  entire right section.
- **Root cause:** light center, fog, vignette, and triangle origin were evaluated in
  the full-section coordinate system; the narrow list occupied a dark outer region.
  The reference's translucent blue base layer was also missing.
- **Durable rule:** position the foundation painter at the list path bounds, shift the
  path to local coordinates, and preserve the reference layer order:
  `blue base -> clipped triangle texture -> outline`. Assert foundation and viewport
  rectangles are identical. Configuration equality alone is not visual parity.

### 12. Phase-editor navigation skipped the builder outro

- **Symptom:** pressing the phase-configuration button removed the element-builder
  cluster immediately instead of playing its requested exit motion.
- **Failed approach:** let the parent switch `_showPhaseEditor` as soon as it received
  the button callback.
- **Root cause:** the parent unmounted the child that owned the motion controller, so
  the child had no frame in which to reverse its animation.
- **Durable rule:** the animation owner reverses all four sections first and invokes
  the navigation callback only after completion. Test that callbacks remain false at
  half duration and fire after settle.

### 13. Completing phases returned to the stale student builder

- **Symptom:** phase completion reopened the student element configuration instead of
  returning to plan main.
- **Failed approach:** close only `_showPhaseEditor`.
- **Root cause:** `_showElementBuilder` and `_builderSeed` still described the previous
  nested route.
- **Durable rule:** successful phase completion clears the phase editor, element
  builder, and stale seed together, while resuming the appropriate plan-main entrance
  controllers. Cover the entire confirm/assign/complete route in one widget test.

### 14. Delete behavior and test fixtures initially targeted the wrong identity

- **Symptom:** deletion semantics were unclear, and an integration test could not find
  `stage-1` after loading a preset.
- **Failed approach:** infer deletion without a selection model and assume visible
  stage numbers equal internal IDs.
- **Root cause:** the requirement was to delete one selected unassigned item, while
  preset replacement allocates IDs after the initial draft (`hoshino-stage-2`, etc.).
- **Durable rule:** maintain one explicit selected unassigned ID, disable deletion
  without selection, remove that ID from elements/drafts/phases, and use actual IDs in
  fixtures. Preserve remaining confirmed elements when returning to plan main.

### 15. The editable preset list item was trapped behind a private widget boundary

- **Requirement:** the center diagonal stage-list item must be constructible from
  other screens while retaining selection, level, skill, equipment, favorite-item,
  star, and stat editing.
- **Root cause:** `_PlanPresetElementCard` already received caller-owned stage state
  and callbacks, but its private class name made the otherwise reusable contract
  inaccessible outside `plan_element_builder.dart`.
- **Durable rule:** expose the item as `PlanPresetElementCard`. Keep state ownership
  outside the widget: callers provide `PlanElementStageDraft`, previous targets,
  propagated fields, equipment metadata, selection state, `onSelected`, and
  `onChanged`. Do not couple the public card to the builder route or diagonal-list
  controller. [@plan-element-builder]
- **Regression coverage:** construct the public card directly under a standalone
  host, invoke its selection callback, and operate a level stepper to prove that the
  edit callback remains available without mounting `PlanElementBuilder`.
  [@plan-element-tests]

### 16. Reusable card header actions must follow the clipped envelope

- **Requirement:** external `PlanPresetElementCard` hosts may add a leading condition checkbox and a trailing reset action without losing the card's full editing behavior.
- **Failed approach:** position both header actions at a fixed 14px horizontal inset.
- **Root cause:** the card is clipped to a diagonal envelope; its safe left and right edges change with Y, so a fixed rectangular inset can place an otherwise rendered control outside hit testing.
- **Durable rule:** expose optional `headerLeading`, `headerTrailing`, and `showStageNumber`, but derive their horizontal positions from the envelope path at both the header's top and bottom. Use the intersection of those intervals plus a small inset. The card remains caller-owned and editable; header controls do not inherit builder route state.
- **Regression coverage:** host the card in the student range-condition section, click both a header checkbox and an internal level stepper, and assert neither clipping nor layout overflow occurs.

### 17. Header space must come from explicit row geometry

- **Symptom:** condition labels and reset actions visually competed with the first three value panels even after their own hit targets were moved inside the diagonal envelope.
- **Rejected shortcut:** shrink the entire reusable card or overlay the header without changing the row projection.
- **Root cause:** clipping and hit safety do not reserve layout space. The first row still began at the standard 24px edge gap.
- **Durable rule:** use a condition-specific projection that reserves 40px before the first row and recovers exactly that amount by reducing the skill and additional-stat rows by 20px each. Preserve total card height, all five inter-row gaps, and the same 80-degree rail equation for every recomputed row. Standard builder cards continue using the unchanged projection.
- **Regression coverage:** compare standard and condition rects, check exact reserve/reductions and unchanged total height, then verify rendered header controls lie inside the envelope and above the first content row.

### Verification strategy learned from the session

- Geometry tests must cover path containment, exact 80-degree rails, normal gaps,
  legacy/current width ratios, and unchanged button geometry.
- Widget tests must cover rendered edge clearance, local painter/viewport bounds,
  scrolled deletion, selection-gated deletion, delayed navigation callbacks, and the
  complete phase-editor route.
- Palette/config tests are useful but cannot prove rendered parity. Local canvas size,
  layer order, and deterministic seed are equally part of a procedural texture.
- A full Flutter suite can exceed a 120-second shell timeout. This is a tooling timeout,
  not a product failure; rerun with a bounded 300-second timeout and compact reporter.
- Preserve unrelated dirty-worktree changes. Validate with `flutter analyze`, focused
  tests, the full suite, Windows release build, `codealmanac validate`, and
  `git diff --check` after the final visual correction rather than after an earlier
  intermediate state.
