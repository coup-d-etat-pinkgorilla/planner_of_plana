# BA Planner v7

BA Planner v7은 Flutter for Windows 프론트엔드와 headless Python 백엔드를
분리해 새로 구축하는 세대입니다. v6의 Qt/QML/QWidget/Tk UI를 복사하지 않고,
검증된 도메인 로직과 데이터 계약만 수직 슬라이스 단위로 이전합니다.
클라이언트 자료 버전 고정 파일, C:\Users\brigh\ba-client-data 참조, 읽기 경로 전환은 미실시

## 현재 상태

- Flutter Windows 렌더러와 실제 홈 PNG hover 검증 화면
- v6 시각 규칙을 Flutter로 재작성한 고정 시드 BA 삼각형 배경
- 고정 ㄴ자 글라스 그림자와 상태 보존형 페이지 섹션 전환
- v6의 80° 사다리꼴 홈 섹션과 가시 간격을 보존하는 평행사변형 메뉴 행
- 계획 목표 모델과 성장 비용 계산
- BA Planner 소유의 versioned canonical 학생 메타데이터와 호환 lookup API
- v6 계산 결과를 고정한 Python parity fixture
- protocol v1 계약과 Python JSONL process/Dart process client
- mock 기본값을 보존한 `ProcessAppService` 실제 backend 선택 경로
- profile catalog, confirmed current, inventory와 goal의 atomic repository persistence
- immutable Flutter repository state와 실제 Dart↔Python process restart 복원 E2E
- Studio 좌표를 직접 투영한 Title 계정 생성·사진 선택·다중 계정 관리 섹션 클러스터
- 2026-10-05 UI/UX 개선 시안(택틱 제외 57장)을 옮긴 프론트 개편(FE1~FE10,
  [Frontend Redesign Implementation Workflow](almanac/workflows/frontend-redesign-workflow.md),
  결정은 `docs/frontend-redesign/decision-register.md`의 `FD-###`)

화면은 타이틀(계정 생성·관리) 뒤 기본 탭 8개 — 홈(스캔 팝업), 학생(성장 계산기), 계획(계획 만들기
4단계·시나리오·활성 계획 보기), 인벤토리, 전술대항전, 통계, 스캔, 설정 — 와 보조 화면 Adaptive-Sync
진단, 개발용 Section Template Studio입니다(`frontend/lib/ui/app_section.dart`). 탭별 흐름과 결정은
[Frontend Section Direction and User Flows](almanac/design/frontend-section-direction-and-user-flows.md)에
있습니다.

저장소는 scanner DTO와 분리해 이전했습니다. 스캐너는 v6의 캡처·입력·matcher·상태 callback 결합을
떼어 낸 session 경계(`backend/core/scanner_session.py`)와 `contracts/scanner-protocol-v1.schema.json`으로
옮겨 홈 스캔 팝업과 스캔 탭에서 씁니다. 스캐너 구조 정리는 scanner 워크플로가 이어서 맡습니다.

## 구조

| 경로 | 책임 |
| --- | --- |
| `frontend/` | Flutter Windows UI와 UI 전용 asset |
| `backend/` | UI 프레임워크에 의존하지 않는 Python 로직 |
| `backend/data/metadata/v1/` | BA Planner canonical 학생 메타데이터와 schema |
| `contracts/` | Flutter/Python 공용 IPC envelope와 fixture |
| `docs/migration/` | v6 지식, 복사 근거와 이전 상태 |
| `almanac/` | v7의 장기 경계와 불변식 |

## 검증

```powershell
cd backend
py -3.11 -m unittest discover -s tests -v

cd ..
powershell -ExecutionPolicy Bypass -File frontend/tool/fe_gate.ps1

cd frontend
flutter build windows --release
```

`fe_gate.ps1`은 `flutter analyze` → 단위·위젯 시험 → 실제 Python backend를 띄우는 process 시험(한 파일씩)
→ golden 비교 → `codealmanac validate` → `git diff --check`를 차례로 돌리고 요약을
`debug/frontend_gate/<시각>/summary.txt`에 남깁니다. 맨 `flutter test`는 golden과 process 시험을 함께
돌려 시간 초과가 날 수 있어 쓰지 않습니다. golden은 화면을 일부러 바꾼 slice에서만
`fe_gate.ps1 -UpdateGoldens`로 다시 만듭니다.

2026-10-19 기준 Flutter 시험은 `frontend/test/` 아래 `*_test.dart` 208개(그중 process 시험 32개,
`fe_gate.ps1`의 분류 기준)와 golden 시험 `frontend/test/goldens/*_golden_test.dart` 15개입니다. golden
장면은 `frontend/test/goldens/baseline/`의 68장입니다.

| 화면 | golden 장면 |
| --- | ---: |
| 타이틀·계정(`title`, `account-*`) | 5 |
| 홈·머리글(`home`, `home-scan-popup`, `header-scan-progress`) | 3 |
| 학생·성장 계산기(`students-*`) | 7 |
| 계획 메인(활성 계획 보기)·프리셋 관리(`plan-bottleneck`, `plan-by-phase`, `plan-overall`, `plan-preset-manager`) | 4 |
| 계획 만들기(`plan-flow-*`) | 13 |
| 시나리오(`plan-scenario-*`) | 8 |
| 인벤토리(`inventory*`) | 5 |
| 전술대항전(`tactical*`) | 8 |
| 통계(`statistics-*`) | 5 |
| 스캔(`scan-*`) | 9 |
| 설정(`settings`) | 1 |

## 실제 Python backend로 실행

일반 실행과 Windows Release는 `ProcessAppService`와 실제 Python backend를 기본으로
사용합니다. 개발 중 mock 화면만 필요하면
`--dart-define=BA_PLANNER_USE_REAL_BACKEND=false`를 지정합니다.
backend를 자동 탐지할 수 없는 개발 환경에서는 경로를 명시합니다.

```powershell
cd frontend
flutter run -d windows `
  --dart-define="BA_PLANNER_BACKEND_DIR=C:\path\to\BA Planner\v7\backend"
```

기본 Python launcher는 Windows의 `py -3.11`입니다. 별도 실행 파일을 쓰려면
`--dart-define="BA_PLANNER_PYTHON=C:\path\to\python.exe"`를 추가합니다.
backend 경로는 실제 연결을 시작할 때 확인하므로 경로가 잘못되어도 앱 shell은
연결 끊김 상태로 실행됩니다. 스캔은 홈의 `싯딤의 상자와 연결`로 게임 창을 고른 뒤 같은 자리의
`스캔` 버튼(홈 스캔 팝업)이나 스캔 탭에서 시작합니다.
Windows Release에는 backend source/data와 검증된 Python 3.11 가상환경이
`release/backend/`로 함께 복사됩니다. 앱은 명시적인 Python 경로가 없으면 이
가상환경을 우선 사용하고, 가상환경이 없는 개발 트리에서만 시스템 `py -3.11`로
대체합니다.

mock 모드에서 화면을 시안과 같은 숫자로 검수하려면 `flutter run -d windows --dart-define=BA_PLANNER_USE_REAL_BACKEND=false --dart-define=BA_PLANNER_MOCK_SCENARIO=design-review`로 실행합니다(계정 `거모이는존재한다 (v7 UI 테스트)`, 쓰기는 메모리 안에서만 바뀌고 다시 실행하면 처음 값으로 돌아갑니다).

## v6 계정 가져오기

첫 실행에 v7 계정이 없고 sibling `v6/config.json`이 발견되면 새 계정을 만들거나
v6 계정을 가져올 수 있습니다. 가져오기는 계정명·대표 학생, 확정 학생 상태,
인벤토리와 성장 목표를 새 v7 계정에 복사하고 그 계정을 선택한 뒤 계획 탭을 엽니다.
설정의 `v6 가져오기`에서도 같은 작업을 다시 실행할 수 있습니다. v6 원본은 항상
읽기 전용이며 스캔 후보·로그·전술 기록은 계획 계정 가져오기 범위에 포함되지 않습니다.

다른 위치의 v6을 사용하려면 backend 실행 환경에
`BA_PLANNER_V6_DIR=C:\path\to\v6`를 지정합니다.

반복적인 실제 UI 검증에는 아래 개발용 시드 도구를 사용할 수 있습니다. v6 원본은 읽기만
하고, 독립적인 `거모이는존재한다 (v7 UI 테스트)` v7 계정을 만들거나 재사용한 뒤 목록과
계산 상태가 다른 8개 시나리오를 멱등하게 추가하고 그 계정을 선택합니다.

```powershell
cd backend
py -3.11 tools\seed_ui_test_profile.py
```

## Windows 실행 파일

UI 검사와 성능 측정을 위한 DevTools 런처는 최상위의
`BA Planner v7 DevTools Debug.exe`와 `BA Planner v7 DevTools Profile.exe`입니다.
각 런처는 Windows Flutter 앱과 연결된 DevTools를 자동으로 열며, 다음 명령으로
다시 생성할 수 있습니다.

```powershell
cd frontend
.\tool\build_windows_devtools_launchers.ps1
```

개발 작업공간의 최상위 `BA Planner v7.exe`는 고정된 Release 복사본이 아니라
소스 최신성을 확인하는 런처입니다. 실행할 때 `frontend/lib`, UI asset,
Windows runner와 `pubspec`의 SHA-256 지문을 비교하며, 변경이 있으면 Flutter
Release 번들을 자동으로 다시 만든 뒤 `release/ba_planner_v7.exe`를 실행합니다.

최상위 런처까지 처음 만들거나 런처 코드를 갱신할 때는 다음 명령을 사용합니다.

```powershell
cd frontend
.\tool\build_windows_release.ps1
```

Release 최신성만 검사하려면 다음 명령을 사용합니다. 오래된 경우 실패 코드로
종료하므로 로컬 검증이나 CI에도 사용할 수 있습니다.

```powershell
cd frontend
.\tool\sync_windows_release.ps1 -CheckOnly
```

Flutter의 Dart 코드와 asset은 `release/data/`에 포함되므로 UI만 변경된 빌드는
네이티브 runner EXE의 바이트가 이전 빌드와 같을 수 있습니다. 동기화 스크립트는
혼동을 줄이기 위해 EXE 표시 시각을 빌드 시각으로 맞추지만, 실제 최신성 판단은
`release/.ba_planner_build.json`의 소스 지문을 기준으로 합니다.

Section Template Studio에서 `release/` 루트에 저장한
`*.ba-section-studio.json`은 릴리스 번들 교체 전에 새 staging 번들로 승계합니다.
실행 파일과 `data/`는 생성물이지만 Studio 배치 문서는 릴리스 갱신 시 보존됩니다.

## 독립 개발 도구

v6의 학생 메타데이터 편집기, 학생 템플릿 추출기, 인벤토리 그리드 매치 검사기는
Qt/Tk 코드를 반입하지 않고 v7 Flutter/Python 경계로 마이그레이션했습니다. 다음 실행기는
각 도구를 별도 Windows 프로세스로 엽니다.

```powershell
.\run_student_metadata_editor.cmd
.\run_student_template_extractor.cmd
.\run_inventory_grid_match_inspector.cmd
```

배포용 공용 도구 번들은 `frontend/tool/build_windows_developer_tools.ps1`로 갱신합니다.
학생 메타데이터 편집기의 SchaleDB 화면은 전체/단일 최소 인연 필드 가져오기와 다중 slug
병합 규칙 관리를 제공하며, 병합 카드에서 첫 경로는 기준, 이후 경로는 같은 로컬 학생을
찾는 보조 경로로 표시합니다. 학생 및 인연 스탯 필드는 이 가져오기 범위에 포함하지 않습니다.
아이템 통계 화면은 선택된 v7 계정의 인벤토리를 기본으로 읽고, 외부 JSON과 선택적인
계획 증감 JSON도 분석합니다. 미확인 수량과 명시적 0을 구분하고 아이템 이미지를 사용해
계획 반영 부족을 표시하며 서로 다른 재화의 수량을 하나의 총합으로 합치지 않습니다.

## 학생 스캔 진단 파일

완료된 학생 단일/전체 스캔의 세션 영역에서 `진단 JSON 추출`을 누르면
`ba-planner-student-scan-*.json` 파일을 저장할 수 있습니다. 이 파일을 대화에 첨부하면
후보별 인식값, confidence와 source, 계산 expected/observed/delta, 누락 dependency,
재검증 revision과 세션 이벤트를 함께 검토할 수 있습니다.

진단 파일은 계정명, 게임 창 제목과 스크린샷을 포함하지 않습니다. 현재 확정 상태도
스캔 후보와 같은 학생만 비교 문맥으로 포함합니다. 파일 검토에서 계산만으로 결론을 낼 수
없는 값은 게임의 학생 기본 정보 화면에서 육안 확인한 뒤, 그 피드백을 기준으로 계산식,
메타데이터 또는 인식 matcher 중 어느 경계의 문제인지 추적합니다. 문서 계약은
`contracts/student-scan-diagnostic-v1.schema.json`에 고정되어 있습니다.

기존 확정 상태에 없던 신규 학생은 스캔 검토 화면에서 바로 적용하지 말고 먼저 재검증합니다.
레벨 90·5성 학생인데 능력 개방 HP/공격력/치유 값이 저장되어 있지 않으면 세 값을 직접
입력해야 합니다. 스캐너는 이를 임의의 0으로 간주하지 않습니다. `empty` 또는 `locked`로
확인된 일반 장비 칸은 미인식과 구분되어 장비 기여도 0으로 계산됩니다. 전용무기 숫자나
성급이 불확실하면 게임 화면에서 확인해 수정한 뒤 재검증하고, 계산값이 화면의 HP/공격력/
방어력/치유력과 일치한 후보만 적용합니다.

학생 검토 화면에서 값을 수정하고 `재검증`하면 해당 캡처의 학생 레벨, 인연 랭크,
전용무기 레벨과 장비 1~3 레벨 숫자 glyph가 현재 계정과 실제 캡처 해상도 전용 정답 샘플로
저장됩니다. 같은 앱 실행 중에는 즉시 matcher에 반영되고, 재시작 뒤에도 같은 계정·해상도에서
우선 사용됩니다. 자동 판독값, 단순 보류와 폐기 결과는 학습하지 않습니다. 인벤토리 후보도
사용자가 명시적으로 승인한 슬롯만 같은 범위의 정답 샘플로 누적됩니다. 이 샘플은
`recognition_samples/`의 로컬 상태이며 배포용 인식 asset과 진단 JSON에는 포함되지 않습니다.

## v6 관계

v6는 안정판과 회귀 기준으로 남습니다. v7은 `../v6`를 런타임에서 import하지
않으며, 새 기능의 기준 구현은 v7입니다. 필요한 v6 버그 수정은 명시적으로
선별해 역이식합니다.

### Inventory FB3 contracts

Catalog rows expose exactly ten fields, adding required nullable school/family/tier to the previous seven. Reviewed mappings preserve old resource identities, relative ordering, aliases and quantity semantics. School/family accept valid Unicode strings or null without trimming/enums/maxima; tier is an exact positive integer or null. Catalog revision includes these fields.

Scanner support stays at seven reviewed profiles (six on the item page). Catalog-only currencies are appended credits then Item_Icon_SecretStone, with item_id null and Item_Icon_SecretStone respectively, zero_fill_allowed=false and three null metadata fields. Manual/unattributed inventory writes preserve canonical currency quantities including presence/null/zero; violations return invalid_payload with reason currency_read_only after existing replay-cache checks. Initialized-profile rejection does not record history/sample clock/write. Common legacy plan migration/recovery still precedes that guard and can have its existing effects.

planning.inventory.acquisition.get accepts only resource_key and returns resource_key/methods/acquisition_revision. Packaged v1 resources={} is intentionally authoritative: known resources have methods=[], unknown resources return resource_not_found; malformed queries return invalid_payload and unavailable/corrupt metadata returns resource_acquisition_failed. A method has exactly method_id/kind/label/weekly_quantity/selector_resource_keys/source, with reviewed KR source and a real calendar date. Weekly quantity is a canonical integer string or null; null selectors differ from []. TEST_ONLY fixtures supply no KR facts. Acquisition revision hashes its validated full table independently of inventory catalog/current/plan revisions. The query does not write repository/history/clock. Catalog does not embed acquisition data. FD101 continues consuming existing backend stage_results[].resources and stage IDs; this slice introduces no synthetic demand or acquisition facts.
