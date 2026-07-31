# 계획 탭 다음 세션 Handoff

## 목적

이 문서는 2026-07-30 세션에서 완성한 계획 탭 Section 2~6 preview UI를 보존하면서,
다음 세션에서 남은 계획 기능과 실데이터 연결을 이어가기 위한 source-of-truth다.
대화 요약보다 코드와 Almanac을 우선한다.

## 시작 전 읽을 파일

1. `AGENTS.md`
2. `README.md`
3. `docs/migration/v6-knowledge-baseline.md`
4. `almanac/workflows/p0-p6-workflow-status.md`
5. `almanac/design/section-template-studio.md`
   - `Plan Section 3 tab views and first bottleneck detail`
   - `계획 탭 Section 4 재화 제어와 Section 6 유형 필터`
   - `2026-07-30 계획 탭 Section 3~6 작업 시행착오와 재발 방지`
6. `contracts/planning-types-v1.schema.json`
7. `contracts/planning-plan-shortages-v1.schema.json`
8. `frontend/lib/services/app_service.dart`
9. `frontend/lib/services/repository_service.dart`
10. `frontend/lib/ui/pages/planning_page.dart`
11. `frontend/lib/ui/widgets/plan_section_layout.dart`
12. `frontend/test/planning_page_test.dart`

## 현재 소스 상태

### 페이지와 데이터 경계

- `PlanningPage`는 `AppService service`와 `PlanningStudentSeed? initialSeed`를 받지만
  `PlanSectionLayout(active: active)`만 생성한다. service와 seed는 아직 소비하지 않는다.
- `AppShell`은 학생 탭의 `PlanningStudentSeed`를 계획 페이지에 전달하지만, 현재 계획
  페이지에서 무시한다.
- `ProcessAppService`와 `MockAppService`는 이미 다음 경계를 제공한다.
  - `getStudent`, `listStudents`
  - `validatePlan`, `calculatePlan`
  - `listInventoryItems`, `calculateShortages`
- 두 service는 `RepositoryService`도 구현한다.
  - 선택 프로필 목록과 `loadRepositoryState`
  - `saveRepositoryGoals`
  - 저장된 confirmed students와 inventory
- 따라서 새 wire method를 만들기 전에 현재 service/repository 계약으로 가능한
  vertical slice를 먼저 구현한다.

### Section별 현황

| Section | 현재 상태 | 남은 핵심 |
|---|---|---|
| 1 | foundation만 렌더링 | 계획 생성·편집·저장 action과 상태 UI. 정확한 버튼 구성은 구현 전 사용자 확인 |
| 2 | `dummyPlanPhases` 기반 페이즈·학생 단계, 사선 scroll, 강조 표시 | 저장 goal/current에서 실제 ordered phase/step model 생성, empty/loading/error |
| 3-1 | 병목 preview 카드, 단계 재사용, 크레딧 독립 행, 지연 단계/재화 클릭 강조 | 실제 최초 부족 및 이후 누적 부족 계산 결과 연결 |
| 3-2 | 페이즈별 소비 preview, 진입/필요/종료, 부족/충족 | 실제 페이즈별 소비와 entry balance 연결 |
| 3-3 | 전체 소비 preview, 확보율 bar, 부족/충족 | 실제 전체 합계 및 inventory 연결 |
| 4 | 유형 필터, 충족 숨김, 정렬 control | 실데이터 category와 안정적인 sort key 연결 |
| 5 | 병목/페이즈별/전체 summary header | 실데이터 대표 재화와 전체 요약 연결 |
| 6 | Section 5 교체형 4열·3행 재화 유형 필터, 초기화 | backend category mapping, 필요 시 empty result 안내 |

### Preview 상수

다음 값은 실제 저장 계획에서 파생되지 않는다.

- `dummyPlanPhases`
- `dummyPlanBottleneckDetails`
- `dummyPlanPhaseConsumptions`
- `dummyPlanOverallConsumption`
- Section 5의 대표 재화, 전체 확보율, 영향 학생 집합

이 상수는 UI fixture로 유지할 수 있지만 production build 경로의 데이터 원본으로
남겨서는 안 된다.

## 현재 고정된 시각·동작 계약

- canonical 최대화 viewport는 작업 표시줄을 제외한 `2560×1392`다.
- Windows runner는 최대화 상태로 시작한다.
- Section 3-1·3-2·3-3은 모두 `intro 80° / outro 260°`이며 foundation도 body와
  함께 움직인다.
- Section 5↔6은 동일한 외곽 path, glass, shadow를 사용하고 순차 퇴장·진입한다.
- Section 6은 scroll이 없는 `filter container + 초기화 버튼` 구조다.
- Section 6의 11개 항목은 4열·3행이다.
  - title 18px
  - checkbox label 15.75px
- Section 4의 두 버튼은 icon-only이며 tooltip/semantics에 라벨을 둔다.
- Section 4 정렬은 학생 custom dropdown과 같은 투명 surface, 1px 핑크 outline,
  compact label, painted arrow 구조다.
- 정렬 compact label의 최대화 left inset은 26px다.
- 3-n 2열 재화 카드는 107px 높이와 기존 너비를 유지한다.
  - 왼쪽 열은 10.70px 오른쪽 이동
  - 오른쪽 열은 10.70px 왼쪽 이동
  - 외곽 visible rail은 약 22.70px inset
- 재화, 지연 단계, Section 5 summary 강조는 상호 배타적이며 Section 2의 exact
  `phase/student/step`에만 핑크 테두리를 적용한다.
- 장비만 `(T10)` 같은 tier suffix를 표시하고 기본 `square.png`를 사용한다.
  오파츠는 v6 정식 품질별 이름/배경을 사용하며 크레딧은 배경 없는 독립 행이다.

## 실데이터 연결 전에 해결할 모델 간극

현재 계약만으로는 aggregate total과 학생 단위 shortage는 구할 수 있지만, 화면이 요구하는
모든 정보를 직접 표현하지 못한다.

1. `InventoryShortageResult`는 `affected_student_ids`를 제공하지만 exact
   `phase/student/step` consumer key를 제공하지 않는다.
2. `calculatePlan`은 전체 gross totals를 반환하지만 phase별 entry/need/ending balance를
   반환하지 않는다.
3. repository goal에는 현재 UI의 phase 순서와 같은 ordered execution plan이 없다.
4. 현재 backend 응답에는 다음이 없다.
   - 최초 부족 지점
   - 이후 단계에서 누적되는 추가 부족
   - 병목 하나로 지연되는 exact stage 목록
5. `planResourceCategory`는 preview ID/asset 문자열을 추정한다. 실데이터에서는 backend
   catalog의 category를 source-of-truth로 사용해야 한다.

이 간극을 무시하고 `affected_student_ids`를 모든 단계에 확장하면 강조와 병목 의미가
틀어진다. 다음 세션 첫 vertical slice에서 frontend view model로 충분한지, versioned
protocol/DTO 확장이 필요한지 먼저 결정한다.

## 권장 다음 작업 순서

### 1. 다음 UI 목표를 사용자와 고정

Section 1의 남은 action 구성과 “페이즈를 사용자가 직접 편집하는가, goal 순서에서
자동 생성하는가”는 아직 확정되지 않았다. 이 선택이 저장 형식과 Section 2 데이터
모델을 바꾸므로 추측해 구현하지 않는다.

### 2. PlanningPage를 stateful controller 경계로 전환

- `service`와 optional `RepositoryService`를 실제로 사용한다.
- 선택 profile과 `RepositoryState`를 load한다.
- `initialSeed`를 한 번만 consume하고 중복 추가를 막는다.
- loading, disconnected, empty, validation error, calculation error 상태를 분리한다.
- stale async response가 최신 state를 덮지 않도록 generation/token을 사용한다.

### 3. typed plan view model 도입

UI widget 안에서 raw map을 직접 해석하지 않는다. 최소한 다음 타입을 분리한다.

- plan phase
- ordered student stage
- resource identity/category
- phase consumption
- overall consumption
- bottleneck event
- exact consumer stage keys

DTO 추가가 필요하면 Flutter와 Python 사이 versioned local protocol을 유지하고 parity
fixture를 먼저 만든다.

### 4. 작은 vertical slice부터 preview를 교체

권장 순서:

1. repository goal/current → Section 2 실제 학생 단계
2. `validatePlan`/`calculatePlan` → Section 3-3 전체 gross total
3. inventory + `calculateShortages` → Section 3-3 owned/shortage
4. phase execution model → Section 3-2
5. first-shortage/cumulative bottleneck model → Section 3-1과 Section 5
6. 저장 action과 재접속/재시작 복원

한 번에 모든 preview를 제거하지 말고 각 slice마다 fixture와 Widget test를 추가한다.

### 5. 기존 제어를 실데이터에 연결

- category filter는 catalog category를 사용한다.
- `충족 재화 숨기기`는 `owned >= required`가 확정된 항목만 숨긴다.
- 정렬은 display string이 아닌 안정적인 identity/tie-breaker를 사용한다.
- filter/sort 변경 시 현재 선택이 사라지면 Section 2 highlight도 함께 해제한다.
- 모든 category를 끈 경우 명시적인 empty result를 보여 줄지 사용자에게 확인한다.

## 테스트와 검증

### 현 세션 최신 결과

- `flutter analyze`: 통과
- `flutter test test/planning_page_test.dart`: 21 tests 통과
- `codealmanac validate`: 통과
- `git diff --check`: 통과

### 주의

- Flutter 전체 225 tests는 Section 4·5·6 초기 구현 시점에는 통과했다.
- 이후 Section 6 4열·3행, 3-n rail 보정, dropdown label 이동까지 반영한 상태에서는
  전체 Flutter suite와 Windows release build를 다시 실행하지 않았다.
- 다음 세션 마감 전 반드시 아래를 실행한다.

```powershell
cd frontend
flutter analyze
flutter test
flutter build windows --release

cd ..\backend
py -3.11 -m unittest discover -s tests -v

cd ..
codealmanac validate
git diff --check
```

실데이터 protocol을 바꾼 경우 관련 contract fixture, Dart validator, Python handler,
real process E2E를 함께 검증한다.

## 작업 트리 주의

- 현재 worktree에는 계획 탭 외에도 사용자의 광범위한 backend, asset, tactical,
  Windows runner 변경이 함께 존재한다.
- 관련 없는 변경을 restore, delete, reset, reformat하지 않는다.
- `frontend/lib/ui/widgets/plan_section_layout.dart`와
  `frontend/test/planning_page_test.dart`에도 이번 세션 이전부터 이어진 대규모 변경이
  누적되어 있으므로 전체 파일 교체보다 작은 patch를 사용한다.
- v6는 행동·데이터 참고용이며 runtime import 대상이 아니다.
- runtime UI asset과 scanner recognition asset을 섞지 않는다.

## 다음 세션의 첫 체크리스트

1. `git status --short`로 기존 사용자 변경을 확인한다.
2. 이 handoff와 위 Almanac 절을 읽는다.
3. `flutter analyze`와 계획 집중 test를 baseline으로 실행한다.
4. 사용자에게 Section 1의 다음 한 기능 또는 phase 생성 규칙을 확인한다.
5. 선택한 기능에 필요한 DTO/fixture를 먼저 정의한다.
6. 한 vertical slice만 구현하고 최대화 화면에서 사용자 검수를 받는다.

## 후속 구현: 인메모리 페이즈 편집 화면

2026-07-30 후속 작업에서 사용자가 phase를 직접 편집하는 UI 규칙을 확정하고
`frontend/lib/ui/widgets/plan_phase_editor.dart`에 구현했다.

- 계획-메인 Section 1의 `페이즈 만들기` action으로 연다.
- 더미 계획 요소 16개를 사용하며 repository나 protocol은 변경하지 않는다.
- 편집 Section 1은 compact 원본 목록과 뒤로 가기, Section 2는 미배정 상세 목록,
  Section 3은 페이즈 생성·제거·이름 수정·완료, Section 4는 phase별 drop container다.
- 현재 단계에서는 compact 목록 위치를 먼저 확정하기 위해 뒤로/생성/제거/완료
  버튼 네 개를 모두 렌더 트리에서 임시 제거했다. 이름 수정과 drag/drop은 계속
  동작하며, 버튼 동작 메서드는 다음 배치 작업에서 복구할 수 있도록 남겨 두었다.
- Section 2에서 Section 4로 drag하면 원본이 미배정 목록에서 제거된다. 페이즈 제거
  또는 배정 항목의 유효하지 않은 drop은 미배정 목록으로 되돌린다.
- 미배정 항목이 남아 있으면 완료가 비활성화된다.
- 완료 시 Section 1~3이 퇴장하고 Section 4가 메인 Section 2 위치로 이동한 뒤,
  메인 Section 2가 편집 결과를 인메모리로 이어받는다.
- Section 2와 Section 4는 메인 Section 2와 같은 `29×94` grid 크기이며 Section
  1·2·3·4 내부 반복 항목은 80° 사선 scroll rail을 따른다.
- Section 1↔2와 Section 4↔3의 facing 80° edge는 최소 12px seam을 유지한다.
  양쪽 compact 목록(코드 `element-1`, `element-3`)은 Section 사다리꼴의 짧은
  수평 변에서 양쪽 12px 법선 간격을 차감한 길이를 목록 평행사변형의 수평 변으로
  사용한다. 목록 bounds를 Section 중심에 배치해 좌우 수평 마진을 동일하게 두고
  위·아래는 10px inset한다. 두 Section 사이와 목록-사다리꼴 사이의 사선 간격은
  수평 차이가 아닌 80° 선에 수직인 법선 거리로 측정한다.
- Section 1 compact 행, Section 3 이름 행, Section 4 phase drop card는 모두
  양면 80° 평행사변형이며 네 scrollbar는 계획-메인과 같은 방향으로 기운다.
- Section 2·4 최외곽 container도 10px inset 평행사변형이고 모든 사선 목록은
  platform 수직 scrollbar를 숨긴다. Section 1 portrait는 `square.png` 배경과
  `학생 · N단계` label을 사용한다.
- 편집기의 모든 평행사변형 container/item은 기존 bounds를 유지한 채 좌상단과
  우하단을 `height / tan(80°)`만큼 대칭 절단한다. `AttachedSectionSpec` 원본을
  다시 사각 bounds로 교차하면 사다리꼴로 퇴화하므로 사용하지 않는다.
- 편집 Section 1의 초기 폭은 18칸이다. Section 4는 편집 중부터 완료 전환까지
  Section 2 및 계획-메인 Section 2와 같은 29칸 폭을 유지한다.
- 상세 container는 계획-메인 Section 2와 동일하게 section path bounds를 10px
  inset하고, 상세 행 65px·extent 69px·phase header 38px·phase gap 20px을 공유한다.
  양쪽 compact 목록은 `section-plan-phase.ba-section-studio.json`의 형태를
  참고하되 현재 크기는 고정 점유율이 아니라 짧은 변·대칭 마진 규칙으로 계산한다.
  Section 4 배정 스크롤은 축소 wrapper 없이 29칸 Section 내부 컨테이너 전체를
  사용한다.
- Section 4는 phase 항목 앞·사이·뒤에 insertion drop target과 hover 선을 제공해
  phase 간 이동뿐 아니라 같은 phase 내부 순서 변경도 지원한다.
- Section 2의 미배정 상세 행은 65px item 오른쪽에 6px seam을 둔 `65×65`
  양면 80° 평행사변형 빠른 이동 버튼을 둔다. 버튼을 누르면 Section 3에서 선택한
  phase의 맨 아래로 즉시 이동한다.
- Section 4 결과 item은 계획-메인 Section 2와 동일하게 phase card의 사선 가용
  폭 전체를 사용하며 오른쪽에 버튼용 빈 공간을 남기지 않는다.
- Section 3의 선택 phase ID는 Section 4의 해당 phase card 강조에도 그대로
  연결된다. 버튼과 Section 3·4 강조에는 계획-메인의 공용 핑크 강조색
  `diagonalMediaHighlightColor`를 사용한다. 버튼 hover·pressed 효과는 Material을
  평행사변형 ClipPath 안에 두어 같은 사선 형태로 제한한다.
- drag feedback은 고정 폭이 아니라 각 원본 item과 같은 폭·높이·사선 비율을
  사용하며 0.72 opacity로 표시한다.
- Section 1 compact portrait 배경은 원본 `square.png`의 252×204 비율을 보존하는
  44×36 contain 프레임을 사용하고 portrait만 중앙 32×32 안전 영역에 둔다.
- 후속 범위는 실제 계획 요소 화면 연결, repository 저장, 재시작 복원이다.

### 2026-07-30 페이즈 편집기 Section 1·3 측면 영역 버튼 복원

- 기존 `element-1`, `element-3` 평행사변형 스크롤 목록의 위치와 크기는 변경하지 않았다.
- 공통 간격은 12px이며, 버튼 사이의 수직 간격, 섹션 직선면과의 거리, 목록 빗면과의 거리를 같은 값으로 계산한다. 빗면 간격은 80° 선에 대한 법선 거리다.
- 버튼 높이는 섹션 높이의 6.5%를 44~72px 범위로 제한하고 모든 버튼에 동일하게 적용한다.
- Section 1은 위에서부터 `계획 요소로 돌아가기`, `전체 선택 페이즈에 넣기`, `전부 되돌리기`를 배치했으며 세 버튼 모두 left-face 사다리꼴이다.
- Section 3은 아래쪽을 기준으로 위에서부터 `위로 조정`, `아래로 조정`, 같은 행의 `+ 생성`·`- 제거`, `완료`를 배치했다. `+ 생성`만 평행사변형이고 나머지는 right-face 사다리꼴이다.
- 전체 배치는 현재 선택 페이즈의 마지막으로 미배정 요소를 모두 옮긴다. 전체 되돌리기와 페이즈 제거는 원래 계획 요소 순서로 Section 2에 복원한다. 위·아래 조정은 선택 페이즈 순서를 바꾼다.
- 완료와 사용할 수 없는 일괄 배치·되돌리기 버튼은 도형 경계 안에서 어두운 반투명 잠금 상태를 사용한다. 완료 hover tooltip은 `계획 요소를 전부 배치하세요`다.
- Section 1~4 공통 사선 목록에 scroll range 기반 위·아래 안개를 추가했다.
- Section 2·4의 260° 퇴장은 Flutter 화면 좌표에서 좌하단으로 이동하도록 Y축을 반전한다. 완료 시 Section 4는 퇴장시키지 않고 기존처럼 계획-메인 Section 2 위치로 왼쪽 이동한다.
- Section 4 phase 번호는 계획-메인 Section 2와 같은 `AppTextStyles.planPhaseNumber`를 사용한다.
- 학생 필터·학생 grid와 타이틀 portrait·profile 사선 목록의 공통 wrapper에서 데스크톱 기본 수직 scrollbar painting을 비활성화하고 전용 사선 scrollbar만 유지한다.
- 검증: `flutter analyze`, Flutter 전체 243 tests(`--concurrency=1`), Windows release build, `codealmanac validate`, `git diff --check` 통과.

### 2026-07-30 계획 메인 우측 컨트롤 간격 및 페이즈 이름 편집 보정

- 계획 메인 최우측 삼각형 Section 4의 필터·충족 재화 숨기기·정렬 컨트롤은 기존 화면 높이 비례 간격 대신 페이즈 편집기 Section 3과 같은 12px 시각 간격을 사용한다. 버튼 높이와 삼각형 경계 대응 형상은 유지한다.
- 페이즈 편집기 Section 3의 이름 입력란은 Enter뿐 아니라 입력란 바깥을 클릭해 포커스를 잃을 때도 공백 제거와 이름 저장을 수행하고 일반 텍스트 상태로 돌아간다.
- 외부 상태 변경으로 페이즈 이름이 갱신될 때 편집 중이 아니라면 입력 컨트롤러도 동기화한다.
- 회귀 테스트는 컨트롤 사이의 실제 경계 간격이 12px인지, 이름을 수정한 뒤 잠긴 완료 버튼을 클릭했을 때 편집장이 닫히고 수정 이름이 남는지를 확인한다.
- 검증: `flutter analyze`, 계획 화면 집중 35 tests, Flutter 전체 243 tests(`--concurrency=1`), Windows release build 통과.
