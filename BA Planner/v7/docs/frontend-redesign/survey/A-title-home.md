> 오케스트레이터 조사 보고서(2026-10-05, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`는 저장소 루트, `.../scratchpad/canvas/project/`는 `docs/frontend-redesign/prototype/2026-10-05/`에 해당한다. [확인]은 grep·파싱으로 확인한 사실, (추정)·[추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.

# 그룹 A — 타이틀 + 홈: 시안 ↔ Flutter 매핑 조사

- 조사 대상 artboard 7개: `Title`, `Title-Accounts`, `Title-Accounts-New`, `Title-Accounts-Portrait`, `Home-Connect-Pick`, `Home-Connect-Effect`(interactive), `Home-Connected-Scan`
- 비교한 코드(읽기만 함): `ui/pages/title_page.dart`, `ui/widgets/account_section_cluster.dart`, `ui/studio/title_studio_layout.dart`, `ui/studio/account_studio_layout.dart`, `ui/pages/home_page.dart`, `ui/widgets/diagonal_menu.dart`, `ui/pages/scan_page.dart`, `ui/widgets/scan_companion_dock.dart`, `services/window_dock_service.dart`, `services/scanner_service.dart`, `services/repository_service.dart`, `ui/app_shell.dart`, `ui/app_section.dart`, `ui/pages/settings_page.dart`(참고)
- 문서: `almanac/design/section-template-studio.md` §「Title 계정 생성·관리 클러스터 적용」~「계정 클러스터 적용 시행착오」, `frontend-section-direction-and-user-flows.md` §1.1·1.4·4(홈)·9(스캔)·10(설정)·12
- 표기: **[확인]** = 파일에서 grep/추출로 확인. **[추정]** = 시안 의도나 동작을 해석한 것.
- 좌표 환산: Studio grid는 `sectionTemplateGridSize = 12*8 = 96`이다 [확인]. 2560×1392에서 1칸 = 26.67px × 14.5px. 표에 적은 "코드 px"는 이 환산값이다.

---

## 0. 핵심 결론 (먼저 읽을 것)

1. **상단 탭 구성은 바뀌지 않았다.** 탭바가 있는 모든 artboard(홈·학생·계획·시나리오·인벤토리·전술대항전·통계, 33개)의 `.nav .nt` 라벨이 `홈·학생·계획·인벤토리·전술대항전·통계·스캔·설정` 8개로 같다. 이는 `AppSection.primary`와 순서·라벨이 정확히 일치한다 [확인]. 예외는 `Tactic-*`/`Tactical-Timeline` 3개로, `전술대항전` 뒤에 `택틱` 탭을 더한 9개다(다른 그룹 담당). **스캔·설정 탭은 시안에 그대로 있다.** 다만 어느 artboard에서도 `스캔`이나 `설정` 탭은 선택되어 있지 않다. 그 두 탭 화면의 시안은 없다.
2. **홈의 "싯딤의 상자와 연결"은 동작이 바뀐다.** 지금은 누르면 `onOpen(AppSection.scan)`으로 스캔 탭으로 이동한다(`home_page.dart:36-40`) [확인]. 시안은 v6 흐름을 되살린다: ① 홈 안에 오른쪽 창 선택 패널을 연다 → ② 메뉴 섹션이 빠졌다 첫 버튼이 `스캔`으로 바뀌어 다시 들어온다 → ③ `스캔` 버튼을 누르면 스캔 종류 팝업(학생·아이템·기타)이 뜬다. 그 결과 지금 `ScanPage` 한 화면에 섞여 있는 기능이 둘로 나뉜다. "대상 창 선택"(`scan-target` dropdown)은 ① 패널로, "종류 선택"(`scan-kind` segmented + `scan-inventory-profile` dropdown)은 ③ 팝업으로 옮겨진다.
3. **타이틀은 "v7 구성 유지"가 맞다.** 섹션 3개와 버튼(계정 카드 / 로고 띠 / 설정·나가기 / 시작+Space)의 구성과 위치는 현재 Studio 투영과 거의 같다. 차이는 다음과 같다:
   - 시작 버튼 폭 320→380
   - 설정·나가기 버튼이 커지고 위치가 조정됨
   - 계정 카드의 구분선이 **보유율 진행 막대**로 바뀜
   - `보유 : a/b`가 `보유 217 / 265`(숫자 강조)로 바뀜
   - 계정 카드 전체가 버튼이 됨
   - 로고 띠에 분홍 radial glow가 추가됨
   - Space 키캡 위치가 바뀜
4. **계정 관리 클러스터는 "수정" 수준을 넘어 확정 문서와 충돌하는 변경이 여럿이다.** 주요 변경:
   - 행 배경: 삼각 무늬 → 그라데이션
   - 행 구분선 → 진행 막대, `지금` 칩 추가
   - 초상 grid: 4열 → 6열
   - 초상 선택(Section 4)이 편집기(Section 1)와 한 패널로 합쳐짐
   - "추가"가 Section 1 편집기 대신 모달 다이얼로그가 됨
   - 목록 하단 fog 추가
   - "마지막 스캔" 시각 표시
   - `section-template-studio.md`의 계정 클러스터 계약(4열, 삼각 무늬 row, Feature 6 구분선, Section 4 독립 진입 등)과 어긋나므로 사용자 확인이 필요하다.
5. **데이터 공백이 있다** [확인]:
   - `ScannerTarget`(`target_id/title/status/foreground`)에 창 해상도(`2560×1440`)와 BA 판별 정보가 없다.
   - `RepositoryProfile`/`RepositoryState`에 "마지막 스캔 시각"이 없다.
   - 홈 헤더의 "게임 창 연결됨 · Blue Archive" 상태를 담을 앱 전역 상태가 없다. 지금 `_targetId`는 `ScanPage`의 지역 state다.

---

## 1. 탭 라벨 전수표 (모든 artboard의 `<nav class="nav">` `.nt`)

추출 방법: 각 `.dc.html` 본문에서 `<nav …>` 안의 `button.nt` 텍스트를 뽑았다. `*` = `.nt.on`(선택). 위치는 모두 `left:22px;top:18px`이다 [확인].

| artboard | canvas page | 탭 라벨(순서대로) | 개수 |
|---|---|---|---|
| Home-Connect-Pick / Home-Connect-Effect / Home-Connected-Scan | home | **\*홈**, 학생, 계획, 인벤토리, 전술대항전, 통계, 스캔, 설정 | 8 |
| Student, Student-Filter | student | 홈, **\*학생**, 계획, 인벤토리, 전술대항전, 통계, 스캔, 설정 | 8 |
| Flow-1-Students(-Many/-One/-Filter), Flow-2-Goals, Flow-3-Order(-Many), Flow-4-Save | plan | 홈, 학생, **\*계획**, 인벤토리, 전술대항전, 통계, 스캔, 설정 | 8 |
| Scenario-List, Scenario-Detail-Bottleneck/-Phase/-All, Scenario-Compare | scenario | 홈, 학생, **\*계획**, …, 스캔, 설정 (시나리오는 계획 탭 소속) | 8 |
| Inventory, Inventory-All, Inventory-Analysis(-Opa), Inventory-Tiers | inventory | 홈, 학생, 계획, **\*인벤토리**, 전술대항전, 통계, 스캔, 설정 | 8 |
| Tactical, Tactical-Analysis(-All), Tactical-Slots, Tactical-Import-Excel | pvp | 홈, 학생, 계획, 인벤토리, **\*전술대항전**, 통계, 스캔, 설정 | 8 |
| Stats-Growth(-Filter), Stats-Filter-Open, Stats-Inventory, Stats-Plan | stats | 홈, 학생, 계획, 인벤토리, 전술대항전, **\*통계**, 스캔, 설정 | 8 |
| Tactic-Full, Tactic-Bosses, Tactical-Timeline | tactic | 홈, 학생, 계획, 인벤토리, 전술대항전, **\*택틱**, 통계, 스캔, 설정 | **9** |
| Title, Title-Accounts(-New/-Portrait) | title | (탭바 없음) | 0 |
| UI-Elements, W-* 12개, Statistics-Proposal | parts | (탭바 없음) | 0 |

- 현재 코드: `AppSection.primary = [home, students, plan, inventory, pvp, statistics, scan, settings]`, 라벨은 `'홈','학생','계획','인벤토리','전술대항전','통계','스캔','설정'`이다(`app_section.dart`) [확인]. 8탭 artboard와 정확히 일치한다.
- `택틱` 탭은 `AppSection`에 없다 [확인]. 홈 그룹과는 무관하지만 탭 구성이 바뀌는 유일한 지점이라 적어 둔다.
- `canvas.json`에는 있지만 로컬 파일이 없는 board: `Boss-*.dc.html` 17개, `Tactic-Zoom30`, `Tactic-Interval`, `Tactic-Cancel` [확인]. 이 board들의 탭은 확인하지 못했다.
- 탭바 치수도 현재 `_TopTab`/`_CompoundPageHeader`와 일치한다 [확인]:

  | 항목 | 시안 | 코드 |
  |---|---|---|
  | 탭 높이 | `.nt` height 44 | `_TopTab` height 44 |
  | 탭 최소 폭 | min-width 76 | `_topTabMinWidth` 76 |
  | 탭 간격 | gap 2 | `_topTabGap` 2 |
  | 탭 좌우 padding | 12 | 12 |
  | 선택 탭 | 배경 `rgba(37,88,123,.34)` + 하단 2px `#71c7f4` | `primaryMuted .34` + `primary` 2px |
  | shelf 우측 끝 | 778 | 18+760 |
  | 구분선 | `22,62 752×1` | 동일 |
  | 헤더 | `23,67 2511×109` | `left 5`, `top 53`, `right 8`, `bottom 8`, padding 18 → 동일 |

  남은 차이는 아이콘(시안은 자체 SVG, 코드는 Material `section.icon`)뿐이다.
- **스캔 진입점이 홈 밖에도 있다**(다른 그룹과 겹치는 부분) [확인]:
  - `Tactical`의 `지금 스캔` 버튼
  - `Stats-*`의 `다시 스캔` 버튼
  - `Inventory`의 `인벤토리 스캔`(텍스트)

  이들이 스캔 탭으로 가는지, 홈의 스캔 팝업을 띄우는지는 시안에 없다.

---

## 2. Title.dc.html — 「타이틀 — v7 구성 유지 (계정 카드 · 로고 띠 · 설정/나가기 · 시작)」

### 2.1 목적과 섹션 구성 [확인]

| 요소 | 시안 rect (x,y,w,h) | 형상 / 부착면 | 현재 Studio 투영(코드 px) |
|---|---|---|---|
| 계정 카드 (`button aria-label="계정 관리 열기"`) | 0,22, 660×226 | 왼쪽 변 수직, 오른쪽 변 80° 사선 → 사다리꼴 / 왼쪽 부착 | `element-3` trapezoid·left (0,0,25,16) → 0,0, 666.7×232 |
| └ 초상 카드 `.stucard` | 52,58, 190×154 (평행사변형 clip + 흰 1.66px stroke, frame 이미지 + 초상) | 평행사변형 | `container-6`→`feature-3` square.png+portrait ≈ 37,35, 238×162 |
| └ 텍스트 열 | 280,64 w320: 이름(22px dsp) / 진행 막대 300×5 skewX(-10°) 81.9% / `보유 217 / 265` | — | `feature-4` 이름, `feature-6` 구분선(3px), `feature-5` `보유 : a/b` |
| 로고 띠 | 520,470, 1520×250 + lifted shadow 4겹, fill `rgba(29,42,58,.93)`, 분홍 radial glow | 평행사변형 / (중앙) | `element-1` parallelogram (20,32,56,16) → 533,464, 1493×232, glass `surface .78`+blur |
| └ 로고 이미지 | 980,497, 600×180 (`alt="Plan A of Plana"`) | — | `feature-1` → ≈975,464 w641 (contain, aspect 3.452 → 높이 ≈186) |
| 설정 버튼 (`aria-label="계정 관리"`, 톱니 SVG) | 544,646, 92×54 | 평행사변형, 이미지 텍스처 | `container-4` → ≈563,638, 70×42 |
| 나가기 버튼 | 1875,646, 110×54 | 평행사변형 | `container-5` → ≈1922,639, 75×42 |
| 시작 버튼 (`aria-keyshortcuts="Space"`) | 1090,820, 380×116, 분홍 stroke `rgba(242,179,239,.9)`, 라벨 `시작` 34px | 평행사변형 | `element-2`/`container-2` → ≈1097,813, **316**×115, 라벨 28px |
| Space 키캡 | 1246,950, 높이 26, bg `#0d151f`, inset 1px 테두리 | — | `_KeyCap` top = `primaryRect.bottom - 5`(≈923, 버튼과 겹침), bg `0xff263a52`, 테두리 white70 |

- 탭바·헤더가 없다. 배경은 이미지 blob(`5bb2…`)이며, 코드의 `BATriangleBackground` 렌더 결과로 보인다 [추정].
- `script`는 빈 `renderVals()`다. 상태 로직은 없다.

### 2.2 사용 요소
- **TitleImageButton**: 평행사변형 + 텍스처 이미지 + 외곽선. 회색-분홍(`2bcb…`)은 설정·나가기·뒤로, 진한 분홍(`49ed…`)은 시작·저장에 쓰인다. 코드의 `_actionTexture`/`titlePrimaryActionTexture`(BATriangle 절차 텍스처)가 이것에 대응한다 [추정: blob은 텍스처 캡처 이미지].
- **AccountCard**: 초상 stucard + 이름 + **SkewProgressBar**(보유율) + 보유 수치. Title, Title-Accounts 행, 편집기에서 반복된다.
- **LogoBand**: lifted shadow 평행사변형 + radial glow.
- **KeyCap**.

### 2.3 상태·상호작용
- 상태 변형 artboard는 없다. 계정이 없을 때(`계정 생성` 라벨), busy 스피너, 오류 배너는 시안에 없다.
- 계정 카드 전체가 `계정 관리 열기` 버튼이다 [확인]. 현재 코드에서 계정 영역은 `_positionedContent`(IgnorePointer)라 탭할 수 없다 [확인].

### 2.4 현재 코드 대응 — **수정(diff만)**
`TitlePage` / `_StudioTitleCanvas` / `titleStudioDocument`를 그대로 쓰고 다음만 바꾼다:

| # | 차이 | 코드 위치 |
|---|---|---|
| T1 | 시작 버튼 폭 320→380(grid w 12 → 약 14.25칸), 위치 1093,812 → 1090,820 | `title_studio_layout.dart` element-2 `SectionGridRect(41,56,12,8)` |
| T2 | 설정 70×42 → 92×54, 나가기 75×42 → 110×54. 위치 563/1922,638 → 544/1875,646 | container-4/-5 `StudioPlacementRect` |
| T3 | 계정 카드 y 0→22, h 232→226 (상단 22px 여백). 코너 반경 16 | element-3 |
| T4 | 구분선(feature-6, 3px 흰 선) → **보유율 진행 막대**(300×5, skew -10°, track `rgba(255,255,255,.14)`, fill `#f4f8fb`, 폭 = owned/total) | `_accountFeatures()` `title-account-divider` |
| T5 | `보유 : $ownedCount/$totalCount` → `보유` (13px muted) + `217` (GyeonggiTitle 20 w800) + `/ 265` (muted). 라벨 순서는 이름 → 막대 → 보유 | `title-owned-count` |
| T6 | 계정 카드 전체 탭 → `_openAccountManager` | 신규 hit path (element-3 path) |
| T7 | 설정 버튼 아이콘 `Icons.settings` → 톱니 SVG, 의미 라벨 `설정` → `계정 관리` | `title-settings` |
| T8 | 시작 라벨 28px w500 → 34px(dsp, 700 지정), 분홍 외곽선 | `title-primary-action` |
| T9 | 키캡: 버튼 아래 14px 띄움, 색 `#0d151f` + `rgba(56,81,107,.9)` inset | `_KeyCap` |
| T10 | 로고 띠 fill 불투명도 `.78` → `.93` + 분홍 radial glow(`radial-gradient(60% 90% at 50% 45%, rgba(242,179,239,.09)…)`) | `_StudioPathSurface(title-brand-glass)` |
| T11 | 초상: square.png 컨테이너(사다리꼴 텍스처 container-6 위) → 평행사변형 stucard(흰 외곽선). container-6의 삼각 무늬 텍스처는 시안에 없다 | `container-6` + `feature-3` |

- 퇴장 애니메이션(brand·primary 270°, account 90°)은 시안에 표시가 없으므로 유지한다 [추정].
- 테스트 영향: `title_page_test`는 `title-owned-count`, `title-account-divider` 등의 key와 Studio projection 동일성을 검증한다고 문서에 적혀 있다(section-template-studio.md "typed 문서의 encode 결과를 저장 JSON 전체와 비교") [확인: 문서 서술. 테스트 파일은 로컬에 없음]. **T1~T3은 Studio JSON 재저장 + projection 테스트 갱신이 필요하다.**

### 2.5 데이터 요구
- 이름 `RepositoryProfile.displayName`, 보유 `RepositoryState.students.length`, 전체 `listStudents().length`, 초상 `avatarStudentId` — 모두 이미 있다 [확인]. 진행 막대 비율도 이 값으로 계산된다. **백엔드 추가는 없다.**

### 2.6 모호점
- A-T-1: 계정이 없을 때 시작 라벨(`계정 생성`)과 첫 실행 v6 가져오기 다이얼로그(`title-initial-account-dialog`)를 그대로 둘지. 시안에는 해당 상태가 없다.
- A-T-2: 버튼 텍스처를 시안의 이미지 blob으로 바꿀지, 현재 절차 텍스처(`BATriangleTextureConfig`)를 유지할지. 타이틀 노트 "이미지 버튼 스타일 계승"은 유지 쪽으로 읽힌다 [추정].

---

## 3. Title-Accounts.dc.html — 「타이틀 설정 · 계정 관리 (목록 + 수정)」

### 3.1 섹션 구성 [확인]

| 요소 | 시안 rect | 형상 | 현재 코드 |
|---|---|---|---|
| 액션 레일 5개(`이 계정으로 전환`/`추가`/`수정`/`삭제`/`뒤로`) | x=14, y=44/135/226/317/408, h 74, 간격 17. 폭은 225→208→192→176→160으로 줄어든다(목록 사선을 따라감) | 왼쪽 수직·오른쪽 80° 사다리꼴 | `container-12/13/14/18/19`(h = .08×1363 ≈ **109**), 폭은 `_managerActionPath`로 목록 경계에서 역산 |
| 계정 목록 패널 `.sw` | 29,36, 871×1320, fill `rgba(29,42,58,.9)` + lifted shadow 4겹 | **평행사변형**(위 왼쪽 offset 232.8 = 1320·tan10°) | `element-5` trapezoid-left 0,0, 933×1363이 레일과 목록을 함께 감싸고, `container-11`(28,27, 607×1309)은 outline+clip만 |
| └ 계정 행 ×9 | 597×142, 세로 피치 158(간격 16), x는 행마다 −28 (80° 계단) | 평행사변형, 배경 `linear-gradient(120deg, rgba(47,74,102,.75), rgba(29,42,58,.85))` | `container-15` (≈560×143), `_accountRowTexture` 삼각 무늬, gap 7 |
| └ 행 내용 | stucard 141×114 + 이름 17px dsp + 진행 막대 322×4 + `보유 217 / 265` + 선택 계정에 `.chip.pk` `지금` | — | 초상 + 이름 20px + 구분선 3px + `보유 : a/b` |
| └ 사선 스크롤바 | 오른쪽 경계를 따라 track `rgba(56,81,107,.48)` 3px, thumb `#e5a0ea` 8px | 80° 직선 | `_DiagonalScrollbar(keyPrefix:'account-profile')` ✓ |
| └ 하단 스크롤 fog | 29,1320, 911×36, `linear-gradient(rgba(38,61,82,0), #263d52)` | — | **없음** |
| 편집 패널 | 1010,470, 1000×262, fill `.95` + shadow | 평행사변형 | `element-1` parallelogram (32,32,32,16) → 853,464, 853×232 |
| └ 초상 stucard | 1069,502, 176×142 | | `container-4` |
| └ `초상 변경` 버튼 | 1058,660, 159×44 | 평행사변형 | `container-3` 라벨 `변경` |
| └ 라벨 `.ihdr` `계정명` (작은 GyeonggiTitle + 파란 점) | 1331,506 | | `feature-4` `계정명 :` 22px |
| └ 입력 표면 | 1311,530, 570×56, fill `rgba(10,16,24,.55)` + **분홍 2.4px stroke**(포커스 상태) | 평행사변형 | `feature-8`. 문서 계약상 fill·border 없음 |
| └ 메타 줄 | `보유 217 / 265 · 마지막 스캔 어제 21:40` (1311,598, 12px muted) | | **없음** |
| └ `저장`(분홍) / `뒤로` | 1819,662 / 1691,662, 118×50 | 평행사변형 | `container-7` / `container-6` |

### 3.2 상태·상호작용 [확인]
- 레일 `수정`이 `aria-pressed="true"`이며 분홍 3.2px stroke로 강조된다. 즉 **레일 버튼에 "현재 열린 모드" 표시가 새로 생긴다.**
- 레일 `이 계정으로 전환`은 `disabled`이고 opacity .42에 보조 문구 `지금 쓰는 계정`이 붙는다(선택 행이 이미 현재 계정일 때).
- 선택 행(`aria-pressed=true`)은 분홍 `#f2b3ef` 3.2px stroke다. 코드의 선택 stroke는 `#ff72b6` 2px다 [확인].
- script는 비어 있다.

### 3.3 현재 코드 대응 — `AccountSectionCluster._buildManager` / `_buildEditor`: **수정(중~대)**
- 그대로 쓰는 것:
  - 80° 행 궤적 계산(`slantedLeft`)
  - `_DiagonalScrollbar`
  - Section 5(0°/180°)·Section 1(80°/260°) 독립 controller와 전이 규칙
  - repository CRUD 호출
- 바꿀 것:
  - (a) 레일 높이 109 → 74
  - (b) 목록 패널을 평행사변형 fill 섹션으로 바꾸고, 바깥 사다리꼴 base surface를 제거할지 결정(모호점 A-A-1)
  - (c) 행 배경을 삼각 무늬 → 그라데이션으로
  - (d) 구분선 → 진행 막대
  - (e) `지금` 칩
  - (f) 하단 fog: 공용 `ScrollViewportFog`가 `ui/widgets/scroll_viewport_fog.dart`에 있다 [확인]
  - (g) 레일 pressed 상태
  - (h) 전환 버튼 disabled + 보조 문구
  - (i) 편집기: 라벨 `계정명`(ihdr 스타일), 입력에 fill과 분홍 포커스 stroke, `초상 변경` 라벨, 메타 줄
  - (j) 편집 패널 rect 853×232 → 1000×262, x 853 → 1010

### 3.4 데이터 요구
- 목록·보유 수: 지금처럼 `listProfiles()`에 프로필마다 `loadRepositoryState()` 호출 [확인].
- `지금` 칩: `RepositoryProfile.selected` [확인].
- **`마지막 스캔 어제 21:40`: 제공되지 않는다.** `RepositoryProfile`(id, displayName, avatarStudentId, revision, selected)와 `RepositoryState`(profileId, revision, students, inventory, goals)에 시각 필드가 없다 [확인]. `ScannerRecentSummary`는 메모리 전용이고 timestamp도 없다 [확인]. → 백엔드에 "프로필별 마지막 스캔 시각"(예: `repository.profile.list` 응답에 `last_scan_at`)을 더해야 한다. 통계·인벤토리 artboard의 `인벤토리 스캔 3일 전`, `스캔 6회`, `마지막 스캔`과 같은 출처로 묶는 것이 좋다 [추정].

### 3.5 모호점
- **A-A-1 (문서 충돌)**: `section-template-studio.md`는 다음을 계약으로 정해 두었다. 시안은 이와 다르다.

  | 문서 계약 | 시안 |
  |---|---|
  | "Container 11 자체에는 삼각 무늬를 그리지 않고 outline과 clip만" | 목록이 불투명 fill + 그림자 평행사변형 |
  | "Container 15 … 삼각 무늬가 있는 polygon row" | 그라데이션 row |
  | "Feature 6 구분선" | 진행 막대 |

  시안을 새 계약으로 보고 문서를 갱신할지 확인해야 한다.
- A-A-2: 바깥 Section 5(사다리꼴) 표면을 없애고 레일 버튼을 배경 위에 띄울지. 시안에는 사다리꼴 path가 없다 [확인: clip path 목록에 레일 버튼·목록·행·편집 패널만 있음].
- A-A-3: 편집 입력의 fill과 분홍 stroke는 문서 "Feature 8 … 진한 box, border, fill은 그리지 않는다"와 충돌한다.

---

## 4. Title-Accounts-New.dc.html — 「타이틀 설정 · 계정 추가 (새 계정)」

### 4.1 구성 [확인]
- 배경은 Title-Accounts와 같다(레일 `추가`가 pressed). 그 위에 **모달 scrim** `rgba(6,10,16,.72)` + `blur(2px)`, z 50.
- 다이얼로그는 900,520, 1000×330, 평행사변형. 내용:
  - 제목 `계정 추가`(dsp) + **(i) 팝오버**(`.info.open`, 열린 상태). 내용: "학생·인벤토리 없이 빈 계정으로 시작하고, 스캔으로 채웁니다. 초상은 만든 뒤 '수정'에서 바꿀 수 있습니다."
  - 닫기 X 버튼 1794,548, 58×40
  - `.ihdr` `계정 이름` + 입력 966,648, 822×56(값 `메인 계정`)
  - `취소` 1535,766 / `만들기` 1677,766, 각 130×56(분홍)
- **초상 선택이 없다.**

### 4.2 현재 코드 대응 — **신규(다이얼로그) + 흐름 변경**
- 코드의 `_startCreate()`는 Section 1 편집기를 새 계정 모드로 연다(초상 `hasumi` 기본 + `변경` 버튼 포함) [확인]. 시안은 초상 없는 **이름만 받는 모달**이다.
- `createProfile(displayName, key, {avatarStudentId='hasumi'})`는 그대로 쓸 수 있다 [확인]. 백엔드 변경은 없다.
- 이 다이얼로그는 공용 **DiagonalModalDialog**(scrim + 평행사변형 패널 + 제목 + (i) + X + 하단 버튼)의 첫 사례다. 홈 스캔 팝업과 구조가 같으므로 공용화하는 것이 좋다.

### 4.3 모호점
- A-N-1: `TitlePage._createAccount()`의 Material `AlertDialog`(`title-account-dialog`)와 `AccountClusterEntry.createFirst` 경로(Title 퇴장 → Section 1만 진입)도 이 다이얼로그로 통일할지. 시안은 관리 화면 안에서의 추가만 보여준다.
- A-N-2: 문서는 "추가 → Section 5를 유지한 채 Section 1을 새 계정 mode로 연다"로 정해 두었고, 시안의 모달과 충돌한다.
- A-N-3: v6 가져오기(`previewV6Accounts`/`importV6Account`)는 시안의 계정 추가에 없다. 지금은 타이틀 첫 실행 다이얼로그와 설정 탭(`settings-profile-v6-import`)에 있다 [확인]. 목록의 `(v6 가져오기 N)`은 계정 이름일 뿐이다.

---

## 5. Title-Accounts-Portrait.dc.html — 「타이틀 설정 · 초상 고르기」

### 5.1 구성 [확인]
- 레일 `수정`이 pressed이고, 목록은 같다.
- **편집 패널이 아래로 확장된다**: 1010,270, 1000×850, 평행사변형(위 왼쪽 offset 165.9).
  - 위쪽은 편집기와 같다: stucard 1172,302 / `고르는 중`(pink stroke = pressed 상태의 `초상 변경`) 1162,460 / `계정명` 입력 1414,330, 535×56 / 메타 줄.
  - 가운데는 `.ihdr` `초상 고르기` + (i) "학생 초상 중 하나를 고릅니다. 저장해야 계정 카드에 반영됩니다."
  - 그 아래 초상 grid viewport: 패널 내부 평행사변형 (139,300)~(907,750), 즉 약 1059..1917 × 570..1020, fill `rgba(10,16,24,.45)`.
    - stucard 112×91 **6열 × 4행 = 24개 가시**
    - 행마다 x가 −19씩 이동(80° 계단)
    - 15번째가 선택(`#ff72b6` 1.88px)
  - 사선 스크롤바(80°, thumb `#e5a0ea`)
  - 하단 `닫기` 1588,1050 / `저장` 1716,1050
- 편집기의 `뒤로`는 이 상태에서 보이지 않는다(`닫기`/`저장`만 있음).

### 5.2 현재 코드 대응 — `_buildPicker`: **수정(구조 변경)**
- 코드는 picker가 **별도 Section 4**다(`element-4` parallelogram (27,50,32,46) → 720,725, 853×667, 하단 부착, 80°/260° 독립 진입) [확인]. 시안은 Section 1과 Section 4를 **하나의 확장 패널**로 합친다.
- 열 수: `const columns = 4` → 6 [확인].
- 그대로 쓰는 것:
  - `portraitGridTrajectoryOffset` / `portraitScrollbarTrackPoint`
  - `AssetImageGrid`(행별 x offset, alpha silhouette 선택선)
  - `_pickerDraft` commit 규칙(닫기 = 버림, 저장 = 편집기 draft에 반영)
- 시안의 선택선은 stucard 평행사변형 stroke다. 문서 계약("square.png의 alpha silhouette를 팽창")과 표현 방식이 다르지만, 시각상 같은 의도로 보인다 [추정].

### 5.3 데이터 요구
- 초상 목록: `AssetManifest`의 `assets/student_portraits/*.png` [확인]. 백엔드 변경은 없다.

### 5.4 모호점
- **A-P-1 (문서 충돌)**: 문서는 "사진 변경은 Section 4를 중첩 호출", "Section 4 닫기·저장은 Section 4만 퇴장", "4열 scroll grid"로 정해 두었다. 시안은 한 패널 확장 + 6열이다. 패널 확장 애니메이션(높이 262→850, 위로 200 이동)은 시안에 없다.
- A-P-2: 확장 패널은 화면 어느 변에도 붙지 않은 "중앙 부유 섹션"이다. `frontend-section-direction…` §1.1("어느 경계에도 연결되지 않은 채 중앙에 독립적으로 떠 있는 섹션은 만들지 않는다")과 충돌한다. 단, 현재 편집기 element-1도 이미 부유 상태다 [확인].

---

## 6. Home-Connect-Pick.dc.html — 「홈 · 싯딤의 상자와 연결 ① 오른쪽 창 선택 패널 (v6 복원)」

### 6.1 구성 [확인]

| 요소 | 시안 rect | 형상 / 부착 | 현재 코드 |
|---|---|---|---|
| 탭바 + L자 헤더 | 위 §1 참조. 헤더 `23,67 2511×109`, 인사말/`현재 프로필 · 아로나 선생님`/초상 62×52(둥근 사각+흰 2px)/`학생 217`/`인벤토리 1,284`/**`.conn` `연결 안 됨`(회색)**/`.devbtn` | — | `_CompoundPageHeader`/`_AppHeader` (위치 일치). 지표는 `'${n}명'`/`'${n}개'`, 초상은 square.png 62 정사각, `_ConnectionBadge`(백엔드 상태, disconnected = 빨강) |
| 홈 메뉴 섹션 | 18,202, 742×1018, fill `.78` + shadow | 오른쪽 사선 사다리꼴 / 왼쪽 부착 | `HomePage.menuSectionMaxSize = Size(742,1018)`, padding 18 → **정확히 일치** |
| └ 메뉴 버튼 `.hmenu` | 행1 36,220, 691×238 `싯딤의 상자와 연결` / 행2 `학생부 확인`·`계획 설정`·`인벤토리` / 행3 `전술대항전`·`통계` / 행4 `설정`(이미지 없음, 텍스처) | 80° 사다리꼴, seam | `_HomeMenuLayout` rowHeight (1018−36−30)/4 = 238 ✓ |
| └ 행1 강조 | 691×238 오버레이, 분홍 `#f2b3ef` 3.2px stroke (패널이 열린 상태 표시) | | **없음**: `DiagonalMenuButton`은 hover만 있음 [확인] |
| **창 선택 패널** | 1822,202, 720×1018, fill `.78` + shadow | 왼쪽 80° 사선·오른쪽 수직 → 사다리꼴 / **오른쪽 부착** | **없음** (가장 가까운 것은 `ScanPage`의 `scan-target` DropdownButtonFormField) |
| └ 제목 | 2030,228: 분홍 skew 막대 + `싯딤의 상자와 연결`(24px dsp) | | |
| └ 안내 | `Blue Archive 창을 선택해 주십시오.` | | |
| └ 상태 줄 | `선택 예정` **Blue Archive** · `현재 선택: 없음` | | |
| └ 창 목록 viewport | clip 사다리꼴 (1857~2522 × 356~1110). 행 16개, 행 높이 38·피치 44, 왼쪽 x가 행마다 −7.7(80°)이고 오른쪽 끝은 2484로 고정 | 행 = 왼쪽 사선 사다리꼴 | |
| └ 창 행 | `[태그 30px] 제목 … 해상도`(예: `BA` / `Blue Archive` / `2560×1440`). 선택 행은 fill `rgba(242,179,239,.16)` + 분홍 2.8px stroke, 태그·제목은 녹색 계열(`#3dbf7a`/`#b9f1d0`) | | |
| └ 수직 스크롤바 | 2498,356, 20×754, track 3px, thumb `#e5a0ea` 8px | **수직**(오른쪽 변이 수직이라서) | |
| └ 하단 fog | 1842,1066, 710×44 | | |
| └ 버튼 | `새로고침` 1852,1134, 200×56(왼쪽 사선) / `취소` `.tonal` 2150, 130×56 / `선택한 창 사용` `.tonal.pri` 2292, 220×56 (링크 아이콘) | | `scan-refresh` OutlinedButton `Refresh` |

### 6.2 사용 요소
- 재사용:
  - **HomeMenuButton**(기존 `DiagonalMenuButton` + 새 selected/flash 상태)
  - **AttachedTrapezoidPanel(right)**
  - **DiagonalSelectableRow**(왼쪽 사선 행, 선택 상태)
  - **PanelTitle**(skew 막대 + dsp 제목)
  - **ScrollFog**
  - **VerticalScrollbar**(분홍 thumb)
  - **TonalButton**(.tonal / .tonal.pri, 둥근 사각)
  - **SlantedButton**
  - **ConnChip**(회색 / 녹색 변형)

### 6.3 상태·상호작용
- 정적 artboard다. 행 클릭 → `선택 예정` 갱신, `선택한 창 사용` → 연결 확정 후 ② 이펙트, `취소` → 패널 퇴장(0°) [추정].
- 패널 intro/outro: 오른쪽 부착이므로 문서 표 기준 intro 180° / outro 0°. ② 이펙트의 `hmPanel`이 `translateX(+820)`(오른쪽으로 퇴장)이라 일치한다 [확인].

### 6.4 현재 코드 대응
- `HomePage`: **수정**. `_featured` 탭 시 `onOpen(AppSection.scan)` 대신 패널을 열어야 한다. `HomePage`는 지금 `StatefulWidget`이지만 state가 없다 [확인].
- 창 목록: `ScannerService.listScannerTargets()` → `List<ScannerTarget>` [확인]. **재사용.** 지금 이 호출은 `ScanPage._refreshPreparation()`과 설정 탭(`감지된 대상 N개`)에서만 쓰인다 [확인].
- 선택 상태: `ScanPage._targetId`(지역 state) [확인]. 홈에서 고른 창을 스캔 팝업·스캔 진행·헤더 칩이 함께 써야 하므로 **AppShell 수준 또는 서비스 수준의 "connected target" 상태가 새로 필요하다**(예: `ValueNotifier<ScannerTarget?>`를 `AppShell`이 소유하고 `HomePage`/`ScanPage`/`_AppHeader`에 전달).
- 헤더 칩: `_ConnectionBadge(connection: state.connection)`는 **백엔드** 연결을 표시한다(`Semantics label: '백엔드 $label'`) [확인]. 시안 칩은 **게임 창 연결**이다(②에서 `연결 안 됨` → `연결됨 · Blue Archive`). → 수정 또는 칩 추가.
- 신규 위젯: `ConnectTargetPanel`(가칭). 공용 `DiagonalSelectableRow` 후보.

### 6.5 데이터 요구
- 제목·상태(`ready/minimized/closed/unsupported`)·foreground: 있다 [확인].
- **창 해상도(`2560×1440`): 없다** [확인: `ScannerTarget.fromWire`와 `planning_protocol_client.dart` `scanner.target.list` 검증 모두 `target_id/title/status`만]. → `scanner.target.list` 응답에 `width/height`(client 영역)를 추가해야 하고, 프로토콜 검증도 함께 갱신한다.
- **`BA` 태그 / `선택 예정 Blue Archive`(자동 추천)**: BA 창 판별 기준이 없다. `status == ready`를 BA 판별로 쓸 수 있는지, 아니면 `unsupported`가 BA가 아닌 창을 뜻하는지 백엔드 코드 없이는 확인할 수 없다 [추정]. 필요하면 `is_game: bool` 같은 필드를 추가한다.
- 목록에 Discord, 카카오톡 같은 비게임 창이 나온다. 현재 백엔드가 모든 top-level 창을 내보내는지는 확인하지 못했다(백엔드 소스가 로컬에 없음).

### 6.6 모호점
- **A-H-1**: "연결"이 무엇인지. ⓐ 대상 창 id를 기억하기만 하는지, ⓑ v6처럼 `WindowDockService.dockBeside(targetId)`로 플래너 창을 게임 옆에 붙이는지(현재 이 호출은 전체 학생 스캔 시작 때만 실행된다 [확인]), ⓒ 백엔드에 "attach" 세션을 여는지.
- A-H-2: 연결이 끊기는 조건(게임 창이 닫힘/최소화)과 그때 메뉴가 `스캔` → `싯딤의 상자와 연결`로 되돌아가는지. ②의 루프 후반(70%~)에서 B → A로 되돌아가는 연출이 있다 [확인: `hmSwap` 72.5~92%, `hmA/hmB` 79.6%]. 연결 해제 이펙트로 읽을 수 있다 [추정].
- A-H-3: 헤더 칩을 게임 창 연결로 바꾸면 백엔드 연결 상태를 어디에 표시할지(개발 패널, `RecoveryBanner`만 쓸지).
- A-H-4: 헤더 지표 표기 `217` vs 코드 `217명`, `1,284` vs `1284개`, 초상 모양(둥근 사각 62×52 vs square.png).

---

## 7. Home-Connect-Effect.dc.html — 「② 연결 이펙트 — 메뉴 섹션 빠짐 → 스캔으로 교체 → 들어옴 (반복 재생)」 (interactive)

### 7.1 구조 [확인]
- `.hm-slide`(translateX 애니메이션) 안에 메뉴 두 벌이 있다. `.hm-a`는 Pick과 같은 메뉴(행1 `싯딤의 상자와 연결`, 이미지 `2c1d…`)이고, `.hm-b`는 행1만 **`스캔`(새 이미지 `9e57…`)**으로 바뀐 메뉴다. 나머지 6개 버튼은 같은 이미지다.
- `.hm-flash`: `.hm-b` 행1 위 691×238, fill `rgba(118,215,255,.16)` + `#76D7FF` 3.2px stroke.
- `.hm-panel`: Pick의 창 선택 패널 전체.
- 헤더 칩: `.hm-a` `연결 안 됨`(회색) ↔ `.hm-b` `연결됨 · Blue Archive`(녹색 `.conn` 기본).
- `script`는 빈 `renderVals()`다. 애니메이션은 helmet의 CSS `@keyframes`로만 구현되어 있다(10s infinite).

### 7.2 타임라인 (10초 루프, CSS에서 직접 추출) [확인]

| 시각 | 메뉴(`hmSwap`) | 패널(`hmPanel`) | 내용(`hmA/hmB`, 칩) | flash |
|---|---|---|---|---|
| 0–1.8s | 정지 | 표시 | A | — |
| 1.8–2.05s | +14px(되튐 예비동작) | 2.0s부터 퇴장 시작 | A | — |
| 2.05–2.7s | → −820px(왼쪽 퇴장 = 180°) | → +820px(오른쪽 퇴장 = 0°), 2.71s 이후 숨김 | A | — |
| 2.75s | (화면 밖) | 숨김 | **A→B 교체**, 칩 `연결됨 · Blue Archive` | — |
| 2.8–3.6s | −820 → −10px(왼쪽에서 진입 = 0°) | 숨김 | B | — |
| 3.6–4.0s | −10 → 0 (안착) | 숨김 | B | 3.8s 페이드인 → 4.0s 최대 |
| 4.0–4.6s | 정지 | 숨김 | B | 4.6s까지 페이드아웃 |
| 4.6–7.0s | 정지 | 숨김 | B | — |
| 7.0–7.9s | +14 → −820 (퇴장) | 숨김 | B | — |
| 7.95s | 밖 | 숨김 | **B→A 교체**, 칩 원복 | — |
| 7.9–9.2s | −820 → −10 → 0 (진입) | 숨김 | A | — |
| 10s | 루프(패널이 즉시 0으로 복귀) | | | |

- 방향은 문서 §1.4와 일치한다. 메뉴는 왼쪽 부착(intro 0°/outro 180°), 패널은 오른쪽 부착(outro 0°) [확인].
- 예비동작(+14px)과 overshoot 안착(−10 → 0)은 현재 `DirectionalSectionEntrance`/`sectionMotionOffset`(easeInOutCubic 직선)에 없는 곡선이다 [추정: `animated_section_stack.dart` 시그니처만 확인].

### 7.3 현재 코드 대응
- `DirectionalSectionEntrance`(home-menu-entrance, 0°)와 `AnimatedSectionStack`이 있다 [확인]. 메뉴 섹션만 따로 퇴장 → 내용 교체 → 진입시키는 **섹션 내부 교체 전이**는 없다. → **신규**: `HomeMenuSwapTransition`(가칭). `AnimationController` 하나에 Interval 3구간(out 0.65s / swap / in 1.2s) + flash, 패널 outro는 병렬.
- `_HomeCardData`의 `_featured`를 연결 상태에 따라 고른다: 미연결이면 `싯딤의 상자와 연결`/`shittim.png`, 연결이면 `스캔`/새 이미지.
  - 현재 `scan.png`는 `_settings` 카드의 `fileName`인데 `triangleOnly: true`라 그려지지 않는다 [확인].
  - `imageWidth` 맵에 `'shittim.png' || 'scan.png' => 692`가 이미 있다 [확인].
  - 시안의 `스캔` 이미지(blob `9e57…`)가 기존 `assets/home_menu/scan.png`와 같은지는 blob 원본이 없어 확인하지 못했다.
- flash 색 `#76D7FF`는 AppColors에 없다(primary `#71c7f4`와 다름) [확인].

### 7.4 데이터 요구
- 연결 상태(앱 전역)뿐이다. §6.5와 같다.

### 7.5 모호점
- A-E-1: 루프 후반의 B → A 복귀가 "연결 해제" 연출인지, 데모 루프를 위한 되감기인지.
- A-E-2: 예비동작·overshoot를 이 전이에만 쓸지, 공용 섹션 모션 곡선으로 올릴지.

---

## 8. Home-Connected-Scan.dc.html — 「홈 · 연결 후 ③ 스캔 버튼 → 스캔 팝업 (학생 · 아이템 · 기타)」

### 8.1 구성 [확인]
- 배경은 B 상태 메뉴(행1 `스캔`)이고, 헤더 칩은 `연결됨 · Blue Archive`다.
- 모달 scrim `rgba(6,10,16,.72)` + blur(2px).
- 팝업: 520,300, 1520×780, **평행사변형**(위 왼쪽 offset 155.5), fill `.97` + shadow.

| 영역 | rect | 내용 |
|---|---|---|
| 헤더 | 687,330 | 분홍 skew 막대 + `스캔`(26px dsp) + (i) "게임에서 해당 화면을 열어 둔 뒤 누르십시오. 스캔하는 동안에는 게임 창을 가리지 마십시오." + `.conn` `연결됨 · Blue Archive · 2560×1440` |
| 헤더 버튼 | 1739,328, 186×40 / 1937,328, 58×40 | `창 다시 선택`(새로고침 아이콘) / 닫기 X |
| 행 라벨 `학생` | 654,440, 170×210 | 파란 skew 막대 + `학생` + `학생 화면` |
| 타일 `전체 학생` | 830,440, 667×210 | stucard 3장 겹침(랜덤) + `학생 목록을 차례로 넘기며` |
| 타일 `지금 화면 1명` | 1472,440, 504×210 | stucard 1장(랜덤) + `열려 있는 학생 정보 한 명` |
| 행 라벨 `아이템` | 615,666, 170×200 | `인벤토리 · 종류별` |
| 아이템 타일 5개 | x 792/1016/1240/1464/1688, 247×200 | `오파츠`, `기술 노트`, `전술 교육 BD`, `활동 보고서`, `엘레프`. 각각 아이템 아이콘 1개(랜덤) |
| 행 라벨 `기타` | 582,882, 170×150 | |
| 타일 `장비` | 762,882, 575×150 | `장비 인벤토리` |
| 타일 `전술대항전` | 1323,882, 575×150, **`disabled`**, opacity .45 | `준비 중` |

- 모든 타일은 평행사변형이고 텍스처 이미지(`66a4…`)를 쓴다. 행 라벨이 행마다 왼쪽으로 이동하므로 80° 계단 배치다.
- **script**: `renderVals()`가 그룹별로 대표 이미지를 무작위로 하나 고른다. `G = {s:[12,3], t:[12,1], o:[6,1], n:[7,1], b:[6,1], r:[4,1], e:[3,1], q:[6,1]}` → 각 타일 이미지 slot이 `{{r.<g><slot>_<i>}}`의 `display:contents/none`으로 하나씩 보인다 [확인]. 대응은 `s`=전체 학생(12장 중 3장), `t`=지금 화면 1명, `o`=오파츠, `n`=기술 노트, `b`=BD, `r`=활동 보고서, `e`=엘레프, `q`=장비 [추정: 장 수와 타일 내 slot 수 대조].

### 8.2 현재 코드 대응 — 팝업 **신규**, 스캔 시작 로직 **재사용**

| 시안 타일 | 현재 코드 매핑 [확인] |
|---|---|
| 학생 · 전체 학생 | `ScannerKind.student` + `StudentScanMode.full` (segment `student_full` `전체`). 시작 시 `windowDockService.dockBeside(target.id)` → `ScanCompanionDock` |
| 학생 · 지금 화면 1명 | `ScannerKind.student` + `StudentScanMode.single` (segment `student_single` `1명`) |
| 아이템 · 오파츠 | `ScannerKind.inventory` + `InventoryScanProfile.ooparts` |
| 아이템 · 기술 노트 | `inventory` + `techNotes` |
| 아이템 · 전술 교육 BD | `inventory` + `tacticalBd` |
| 아이템 · 활동 보고서 | `inventory` + `activityReports` |
| 아이템 · 엘레프 | `inventory` + `studentElephs` |
| 기타 · 장비 | `inventory` + `equipment` |
| 기타 · 전술대항전 (준비 중) | `ScannerKind.tacticalLobby` (`TacticalLobbyScannerService.startScannerSession(ScannerKind.tacticalLobby, …)`가 있음) |
| (시안에 없음) | `InventoryScanProfile.presents`(선물) |
| `창 다시 선택` | ① 패널 재호출 (`listScannerTargets`) |
| 헤더 칩 해상도 | 데이터 없음 (§6.5) |

- 타일 하나를 누르면 `startScannerSession(kind, targetId, profileId:, studentScanMode:, inventoryScanProfile:)`가 실행된다 [확인: 시그니처]. 지금 이 호출과 그 전제조건(`_canStart`: backend 연결, scanner/repository 존재, `_profile != null`, `_recognitionReady`, target `ready`, stage idle/terminal)은 모두 `_ScanPageState` 안에 있다 [확인]. 팝업에서 시작하려면 **세션 상태 머신(`_SessionStage`, 이벤트 구독, stale event 무시, candidate 보관, companion publish)을 `ScanPage` 밖으로 꺼내야 한다**(예: `ScanSessionController`, `ChangeNotifier`). 이것이 이번 그룹에서 가장 큰 구조 변경이다.
- 시작 후 화면 흐름은 시안에 없다. 진행·취소·후보 검토가 어디서 보이는지(팝업이 진행 상태로 바뀌는지, 스캔 탭으로 이동하는지, 전체 학생만 companion dock을 쓰는지)를 정해야 한다. `ScanCompanionDock`(전체 학생 dock 모드: 진행 + 현재 학생 피드백 + 취소)은 시안과 충돌하지 않으므로 **그대로 재사용**한다 [추정].
- `scan_companion_dock.dart` / `window_dock_service.dart`: **재사용**. dock 시점을 "전체 학생 시작 시"에서 "연결 시"로 옮길지는 모호점 A-H-1에 달려 있다.
- `scan_page.dart`: 스캔 탭이 시안에 남아 있으므로 폐기 대상이 아니다. 다만 준비·종류 선택 UI(영어 라벨 `Scan preparation`/`Start scan`/`Refresh` 등)가 홈 팝업과 중복된다. 스캔 탭에 무엇을 남길지는 시안이 없다(모호점 A-S-1).

### 8.3 데이터 요구
- 스캔 종류·프로필: 기존 enum으로 충분하다 [확인]. 백엔드 추가는 없다.
- 해상도 칩: §6.5와 같다(`scanner.target.list` 확장).
- 타일 대표 이미지: 학생 초상(`assets/student_portraits`)과 아이템 아이콘 asset으로 프론트에서 만든다. 무작위 선택은 프론트 로직이다 [추정].
- `준비 중` 판정: 정적 플래그인지, 백엔드 capability(예: `scanner.recognition.status`의 profile별 활성)인지 미정이다. `post-consolidation-status.md` O0-6에 "1080 tech_notes/presents 활성, equipment 비활성"이라는 창 크기별 활성 정보가 있다 [확인]. **해상도에 따라 타일을 disable해야 할 수도 있다** [추정].

### 8.4 모호점
- **A-S-1**: 스캔·설정 탭은 탭바에 그대로 있지만 화면 시안이 없다. 스캔 탭이 계속 "준비 + 종류 + 세션 + 후보 검토 + 최근 결과"를 다 가질지, "세션 진행·검토·최근 결과"만 남길지 정해야 한다.
- **A-S-2**: `전술대항전` 타일이 `준비 중`(disabled)인데, `Tactical.dc.html`에는 `지금 스캔` 버튼이 있고 코드에도 `tacticalLobby` 스캔 경로가 있다 [확인]. 시안끼리 충돌한다.
- A-S-3: `presents`(선물) 프로필이 팝업에 없다. 의도적으로 제외한 것인지 확인해야 한다.
- A-S-4: 팝업에서 타일을 누른 직후의 화면(진행 표시 위치, 후보 검토 인계)이 정해져 있지 않다. 현재는 `onCandidateHandoff`로 학생·인벤토리·전술대항전 탭에 인계한다 [확인].
- A-S-5: 팝업이 중앙에 떠 있는 평행사변형이다. 모달 오버레이를 §1.1 "부유 섹션 금지"의 예외로 인정할지 확인해야 한다.

---

## 9. 그룹 전체 요약

### 9.1 분류 요약

| Dart 파일/클래스 | 분류 | 근거 |
|---|---|---|
| `title_page.dart` `_StudioTitleCanvas`, `title_studio_layout.dart` | 수정(소) | T1~T11 diff |
| `account_section_cluster.dart` `_buildManager` | 수정(중) | 행 표현, 진행 막대, 칩, fog, 레일 pressed/disabled, 치수 |
| `account_section_cluster.dart` `_buildEditor` + `_buildPicker` | 수정(대, 구조) | 두 Section을 확장 패널 하나로 합침, 6열 |
| `account_section_cluster.dart` `_startCreate` 경로 | 신규 모달로 교체 | Title-Accounts-New |
| `account_studio_layout.dart` | 수정 | Section 1/4/5 rect 재저장 필요 |
| `home_page.dart` | 수정(중) | 패널 열기, 메뉴 교체 전이, featured 카드 상태 |
| `diagonal_menu.dart` `DiagonalMenuButton` | 수정(소) | selected(분홍 3.2) / flash(`#76D7FF`) 상태 추가 |
| `app_shell.dart` `_AppHeader`/`_ConnectionBadge`, AppShell state | 수정 | 게임 창 연결 칩, connected target 소유 |
| `scan_page.dart` `_ScanPageState` 세션 로직 | 수정(대, 추출) | 세션 컨트롤러를 밖으로 빼 홈 팝업과 공유 |
| `scan_companion_dock.dart`, `window_dock_service.dart` | 그대로 재사용 | 시안과 충돌 없음 |
| `scanner_service.dart` `ScannerTarget` | 수정 + 프로토콜 | `width/height`(+ 게임 판별) 필드 |
| `repository_service.dart` `RepositoryProfile` | 수정 + 프로토콜 | `last_scan_at` |
| (신규) `ConnectTargetPanel`, `ScanKindPopup`, `DiagonalModalDialog`, `HomeMenuSwapTransition`, `SkewProgressBar`, `ConnChip` | 신규 | — |

### 9.2 구현 단위(vertical slice) 제안과 순서

| 순서 | slice | 내용 | 난이도 | 선행 의존 |
|---|---|---|---|---|
| 0 | 공용 위젯 | `SkewProgressBar`, `ConnChip`(회색/녹색), `PanelTitle`(skew 막대 + dsp), `InfoPopover`(i)는 W-Info-Popover 그룹과 공유, `DiagonalModalDialog`(scrim + 평행사변형 + 헤더 + X + 하단 버튼), `TonalButton` | M | 다른 그룹(W-*)과 이름·API 합의 |
| 1 | 타이틀 diff | T1~T11 + Studio JSON 재저장 + projection 테스트 갱신 | S | 0(진행 막대) |
| 2 | 계정 관리 목록 | 행 그라데이션, 진행 막대, `지금` 칩, fog, 레일 74px·pressed·disabled+보조 문구, 목록 패널 평행사변형 fill | M | 0, 문서 충돌 A-A-1 결정 |
| 3 | 계정 추가 모달 | `DiagonalModalDialog`로 이름만 받는 생성, createFirst 경로 통일 여부 결정 | S | 0, A-N-1/2 |
| 4 | 편집기 + 초상 선택 통합 | 확장 패널(262↔850), 6열 grid, `고르는 중`·`닫기`/`저장`, 메타 줄(마지막 스캔은 백엔드 전까지 숨김) | L | 2, A-P-1, (백엔드) `last_scan_at` |
| 5 | 연결 상태 기반 | AppShell `connectedTarget` 상태 + 헤더 칩 전환 + `scanner.target.list` 해상도·게임 판별 확장(백엔드 + 프로토콜 검증 + mock) | M | 백엔드, A-H-1/3 |
| 6 | 홈 ① 창 선택 패널 | `ConnectTargetPanel`(오른쪽 부착 사다리꼴, 사선 행 목록, 수직 스크롤바, fog, 새로고침·취소·사용) + 메뉴 행1 selected 표시 | M | 5 |
| 7 | 홈 ② 교체 이펙트 | `HomeMenuSwapTransition`(out 180° / swap / in 0° + overshoot + flash, 패널 outro 0°), `스캔` 카드 이미지 asset | M | 6 |
| 8 | 스캔 세션 컨트롤러 추출 | `_ScanPageState`의 세션·이벤트·candidate·companion 로직을 공유 컨트롤러로 이동. 기존 `scan_page_test` 회귀 유지 | L | 5 |
| 9 | 홈 ③ 스캔 팝업 | `ScanKindPopup`(학생 2 / 아이템 5 / 기타 2 타일, 무작위 대표 이미지, `창 다시 선택`, disabled 규칙) → 컨트롤러로 시작, 시작 후 흐름(A-S-4) | M | 0, 8 |
| 10 | 스캔 탭 재정의 | 홈과 중복되는 준비·종류 UI 정리(A-S-1 결정 후) | M~L | 9, 사용자 시안 |

- 타이틀·계정 slice(1~4)와 홈·스캔 slice(5~10)는 서로 독립적이므로 병렬로 진행할 수 있다.
- 백엔드/프로토콜 추가는 두 건이다: ① `scanner.target.list`에 창 크기와 게임 판별 필드, ② 프로필별 마지막 스캔 시각. ②는 Inventory/Stats 그룹의 "마지막 스캔·스캔 횟수" 요구와 합쳐서 설계하는 것이 좋다.

### 9.3 사용자 확인 질문 묶음
1. (A-A-1, A-A-3, A-P-1, A-N-2) 계정 클러스터 시안이 `section-template-studio.md` 계약(삼각 무늬 row, 구분선, 4열, Section 4 독립, 추가 = Section 1, 입력 무 fill)을 대체하는가?
2. (A-H-1) "싯딤의 상자와 연결"은 대상 창을 기억하는 것인가, v6처럼 창 dock까지 하는 것인가?
3. (A-H-3) 헤더 칩을 게임 창 연결로 바꾸면 백엔드 연결 상태는 어디에 표시하는가?
4. (A-S-1) 스캔 탭·설정 탭은 탭바에 남는데 화면은 어떻게 되는가? 현재 화면 유지인가, 축소인가?
5. (A-S-2, A-S-3) 전술대항전 스캔 `준비 중` vs Tactical의 `지금 스캔`, 그리고 선물(presents) 프로필이 빠진 것은 의도인가?
6. (A-E-1) 이펙트 루프 후반의 B → A 복귀는 "연결 해제" 연출인가?
7. (A-T-1, A-N-1, A-N-3) 계정이 없을 때의 첫 실행 흐름과 v6 가져오기 진입점은 어떻게 하는가?
