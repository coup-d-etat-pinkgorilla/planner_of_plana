> 오케스트레이터 조사 보고서(2026-10-06, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`·`/mnt/user-data/outputs/v7/`는 저장소 루트, `.../scratchpad/canvas2/project/`는 `docs/frontend-redesign/prototype/2026-10-05/`에 해당한다. [확인]은 grep·파싱으로 확인한 사실, [추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.

> 오케스트레이터 조사 보고서(2026-10-06, 읽기 전용 조사). 본문의 `/mnt/user-data/uploads/v7/`는 저장소 루트, `.../scratchpad/canvas2/project/`는 2026-10-06에 추가된 시안 폴더(기존 `prototype/2026-10-05/`와 같은 캔버스 + Scan 6장·Calc-Student 1장)에 해당한다. [확인]은 grep·파싱으로 확인한 사실, [추정]은 해석이다. 결정은 `docs/frontend-redesign/decision-register.md`가 우선한다.

# 그룹 I — 스캔 탭: 시안 ↔ Flutter 매핑 조사

- 조사 대상 artboard 6개(canvas page `scan`, 2026-10-06 추가): `Scan`, `Scan-Student-Run`, `Scan-Student-Review`, `Scan-Items`, `Scan-Item-Run`, `Scan-Item-Review`.
- canvas 노트 [확인]:
  - `scanStudent`: "스캔 탭 · 학생 — 게임 창을 뒤에 둔 채 백그라운드로 진행: 고르기 → 진행(플래너 계속 사용) → 결과 검토 (전술대항전 스캔은 전술대항전 탭에서만)"
  - `scanItem`: "스캔 탭 · 아이템 — 게임 창이 앞으로 나와 포그라운드로 진행: 고르기 → 진행(게임 창 옆 진행 창) → 결과 검토"
- `Home-Connected-Scan.dc.html`은 canvas(10-05)와 canvas2(10-06)가 바이트 단위로 같다 [확인: `cmp`]. 홈 팝업 시안은 이번에 바뀌지 않았다.
- 비교한 코드(읽기만 함, `frontend/lib/` 기준): `ui/pages/scan_page.dart`, `ui/widgets/scan_student_review_workspace.dart`, `ui/widgets/scan_inventory_identity_review.dart`, `ui/widgets/scan_companion_dock.dart`, `services/scanner_service.dart`, `services/window_dock_service.dart`, `services/student_scan_diagnostic.dart`, `services/planning_protocol_client.dart`(scanner 응답 검증), `services/mock_app_service.dart`, `services/process_app_service.dart`, `services/tactical_lobby_scanner_service.dart`, `ui/app_shell.dart`, `ui/pages/inventory_page.dart`(`_CandidatePanel`), `ui/pages/student_page.dart`, `ui/widgets/animated_section_stack.dart`, `ui/widgets/student_section_layout.dart`.
- 문서: README.md「학생 스캔 진단 파일」절, `almanac/workflows/scanner-structural-consolidation-workflow.md`(C5e-1, C5f, D21, D29), `post-consolidation-status.md`(O0-6), 기존 조사 `survey/A-title-home.md` §6~§9, 결정 대장 §8(FD-113~125)·FD-041, 워크플로 FE8·FB-2.
- 백엔드 소스는 로컬에 없다. 백엔드 동작 판단은 Dart 프로토콜 클라이언트의 메서드·검증 키와 almanac 문서에만 근거한다.

---

## 0. 핵심 결론 (먼저 읽을 것)

1. **스캔 탭 시안이 생겼고, FD-120의 권장안 (a)와 다르게 답한다.** 스캔 탭은 "세션 진행·검토·최근"만 남는 화면이 아니다. **고르기(종류 선택, 아이템 다중 선택, 종류별 마지막 스캔) → 진행 → 결과 검토**를 모두 가진 3섹션 화면이다. 홈에서 가져오는 것은 **게임 창 선택**뿐이다(스캔 탭 왼쪽 아래 `게임 창 다시 선택`). 인벤토리 후보 비교(`_CandidatePanel`)는 스캔 탭 "아이템 결과 검토"로 옮겨진다. 이 부분은 FD-120 (a)의 후반과 같다.
2. **홈 스캔 팝업과 종류 선택이 두 곳에 생긴다.** 둘의 관계(팝업 타일이 바로 시작하는지, 스캔 탭으로 넘기는지)를 보여 주는 시안은 없다. 팝업 (i) 문구는 "해당 화면을 열어 둔 뒤 **누르십시오**"다. 그래서 타일을 누르면 바로 시작한다고 읽힌다 [추정]. 구성도 서로 다르다:
   - 팝업에는 `전술대항전(준비 중)` 타일이 있고, `장비`는 "기타" 줄에 있다.
   - 스캔 탭에는 전술대항전이 없고, `장비`는 아이템 줄에 있으며, 아이템을 여러 개 고를 수 있다.

   → 새 FD-140(열림).
3. **진행 방식이 현재 코드와 반대다.** 지금은 **전체 학생 스캔**이 `windowDockService.dockBeside(target.id)`로 플래너 창을 게임 옆 진행 창(`ScanCompanionDock`)으로 바꾼다(`scan_page.dart` 245–253행). 시안에서는 반대다:
   - 학생은 **백그라운드**다. 진행 창을 띄우지 않고, 진행은 머리글 칩과 스캔 탭에 나온다.
   - 아이템은 **포그라운드**다. 게임 창 옆에 1:2 진행 창이 붙는다.

   백엔드 쪽 근거는 이미 있다. scanner 워크플로 C5f에서 학생 전체 스캔을 PostMessage 키 + PrintWindow 백그라운드로 처리하기로 했고(2026-09-27), C5e-1에서 그리드 스캔은 포그라운드를 유지하기로 했다(사용자 결정 2026-09-27). 시안은 이 두 결정을 UI로 옮긴 것이다 [확인: 문서].
4. **일시정지는 지금 프로토콜에 없다.** `ScannerService`의 메서드는 `listScannerTargets / scannerReadiness / startScannerSession / cancelScannerSession / scannerSnapshot / getScannerCandidate / reviewScannerCandidate / revalidateScannerCandidate / scannerUnresolvedSlots / assignScannerIdentity / commitScannerCandidate`가 전부다 [확인].
   - 시안은 일시정지·이어서 버튼, "최소화하면 일시정지", "마우스·키보드 입력이 감지되면 일시정지 → 이어서"를 요구한다.
   - 확정된 D21은 "입력 감지 시 해당 스텝 `input_busy` 재시도 ≤2, 초과 시 `partial`"이다. 시안과 다르다 [확인].
   - → 백엔드(스캐너 워크플로) 추가 + D21 개정이 필요하다. 새 FD-142(열림).
5. **학생 검토는 현재 `ScanStudentReviewWorkspace`와 구조가 다르다.**
   - 현재: 학교 그룹 목록 + 상세 비교표 + 후보별 수정·재검증·보류·적용.
   - 시안:
     - 분류 seg(전체/확인 필요/바뀐 학생/새 학생/그대로)
     - "계산 일치" 학생 묶음 **일괄 적용**(`6명 한 번에 적용`)
     - 학생 상세 인디케이터(W-Student-Detail) 위에 이전값을 주석으로 표시
     - **폴백 캡처 crop**과 **계산 역산값**

   일괄 적용은 지금 API로도 순차 commit하면 된다. 폴백 crop·계산 역산·신뢰도 문구는 백엔드 데이터가 없다.
6. **아이템 검토는 새로 만든다.** 칸별 승인, 읽지 못한 칸 빗금, "확인 필요 2칸은 빼고 적용", 남은 칸은 인벤토리에 "확인 필요"로 남기기 — 모두 해당한다.
   - 지금은 후보 전체를 인벤토리 탭 `_CandidatePanel`에서 `Review & approve` 한 번으로 승인·commit한다.
   - `ScanInventoryIdentityReview`(미식별 아이템 crop + 후보 + 검색 + 이번 세션만/영구 승인)는 수량이 아니라 **identity** 검토다. 이 단계는 시안에 없다.
7. **"종류별 마지막 스캔"은 FB-2(FD-041)와 겹치지만 FB-2보다 더 잘게 필요하다.** FD-041은 "프로필별 마지막 스캔 시각"을 이력에서 유도한다. 시안은 **종류별**(학생, 오파츠, 기술 노트, BD, 활동 보고서, 엘레프, 장비)과 **아이템별**(검토 오른쪽 `이전 확정값 96 · 3일 전 스캔`) 시각을 요구한다. FB-2 이력 레코드에 `scan_kind`와 `inventory_scan_profile`을 넣어야 한다. 새 FD-147.
8. **전술대항전을 스캔 탭에서 빼는 것은 현재 코드와 맞는다.**
   - `ScanPage`의 `scan-kind` segment는 `student_single / student_full / inventory`뿐이다. `tacticalLobby`를 시작하는 UI는 어디에도 없다 [확인].
   - 이 방향은 FD-125(전술 = 탭 안 로비 스캔)와 FD-122(FE9-c)에도 맞는다.
   - 충돌하는 곳은 홈 팝업의 `전술대항전(준비 중)` 타일 하나다.

---

## 1. 공통 골격 (6장 중 앱 화면 5장)

### 1.1 섹션 배치 [확인]

`Scan-Item-Run`을 뺀 5장은 통계 탭과 같은 3섹션 배치다. 탭바·L자 헤더 위치도 다른 탭과 같다.

| 섹션 | rect (x,y,w,h) | 형상 / 부착면 | 비고 |
|---|---|---|---|
| S1 왼쪽 "스캔" 레일 | 0,209, 587×1183 | 왼쪽 수직·오른쪽 80° 사선 사다리꼴 / 왼쪽·아래 부착 | path `M14 0 L572.7 0 … L364.1 1182.8 … Z` |
| S2 가운데 작업 영역 | 400,209, 1702×1183 (Review만 1515×1183) | 평행사변형(좌상 offset 222.6) / 아래 부착 | 단계별 내용이 바뀐다 |
| S3 오른쪽 상세 | 1920,209, 640×1183 (Student-Review만 1733,209, 827×1183) | 왼쪽 80° 사선·오른쪽 수직 사다리꼴 / 오른쪽·아래 부착 | 선택 대상의 설명·검사기 |

- 모두 `.sw` + lifted shadow 4겹 + fill `rgba(29,42,58,.76)`(FD-006 값)이다.
- 탭바 8개, `스캔` 선택(`.nt.on`). 헤더 제목은 `스캔`이고, 부제가 단계마다 바뀐다:
  - `학생 · 아이템 스캔 · 고르기 → 진행 → 결과 검토`
  - `학생 스캔 진행 중 · 다른 탭을 계속 쓸 수 있습니다`
  - `학생 스캔 결과 검토 · 후보 확인 → 적용`
  - `아이템 스캔 결과 검토 · 칸별 승인 → 적용`
- 헤더 `.conn`은 평소 `연결됨`(종류명 없음)이다. 학생 진행 중에는 분홍 `학생 스캔 34 / 128`로 바뀐다.

### 1.2 S1 레일 (5장 공통) [확인]

| 요소 | rect | 내용 |
|---|---|---|
| 제목 | 20,231 | `스캔` + (i) "학생과 아이템만 여기서 스캔합니다. 전술대항전은 전술대항전 탭의 로비 스캔에서 다룹니다. 학생은 게임 창을 뒤에 둔 채로 읽고, 아이템은 게임 창을 앞으로 가져와 읽습니다." |
| `.cap` `준비 상태` + ghost 버튼 3개(80° 계단, 폭 533→522→511, h56, 피치 62) | 14,309 / 371 / 433 | `게임 창 · Blue Archive · 2560×1440`, `인식 준비 · 이 계정 정답 샘플 12개`, `계정 · 아로나 선생님` |
| `.cap` `최근 스캔` + 행 4개(h60, 피치 66, 폭 492→457) | 14,541~739 | 예: `학생 전체 · 128명 / 어제 21:40 / chip.pk 검토 12`, `아이템 · 기술 노트 · BD / 3일 전 / chip.ok 확정`, `학생 1명 · 쿠루미 / 9/18 / 확정`, `아이템 · 오파츠 / 9/15 / chip.dg 실패 · 창 없음`. 지금 보고 있는 실행은 `.btn.sel-pink` |
| 각주 행 | 14,805, 446×34 | `이 실행 중 기록 4건 · 앱을 끄면 지워집니다` |
| 아래 버튼 | 14,1322, 354×52 | `게임 창 다시 선택` |

### 1.3 반복 컴포넌트 이름 (FE2 공용 이름에 맞춤)
- **ScanRailStatusRow**: `RailButton`/`DiagonalRow(.btn.ghost)` + 라벨·값 2줄.
- **ScanRecentRow**: `DiagonalRow` + 제목·시각 + `BaChip`(pk 검토 n / ok 확정 / wn 확인 n / dg 실패 · 사유 / 기본 백그라운드).
- **ScanKindTile**: `.tile` 평행사변형. 대표 이미지(학생 stucard 겹침 3장 / 1장, 아이템은 `ItemIconTile` 1개, 무작위) + 제목·설명 + 회색 칩(보유·소요). 선택 시 bg `rgba(242,179,239,.12)`.
- **PanelTitle**(분홍 skew 막대 + dsp) + **InfoPopover**(i), **SubHeader**(`.dsp` + 파란 그라데이션 1px + 분홍 40×3 표식).
- **SkewSegmented형 큰 필터 버튼**: 검토 화면 위쪽 `전체 128 / 확인 필요 2 / …`. `.btn.sel-pink`/`.btn.ghost`, h56. 숫자를 2줄로 넣은 큰 버튼이다.
- **ScanDiffRow**: `DiagonalRow(.row)` + 이름 + `값 a → b` 칩 묶음 + 건수 + `BaChip` + `TonalButton`(고치기/보류).
- **KpiTile**, **SkewBar**(진행·마지막 스캔 막대), `.chip.gy/ok/wn/pk/dg`.

### 1.4 script [확인]
- `Scan`·`Scan-Items`: `renderVals()`가 그룹별 대표 이미지를 무작위로 하나 고른다. 홈 팝업과 같은 코드이고, 그룹 표만 다르다: `G={s:[18,3], u:[18,1], o:[6,1], n:[7,1], b:[6,1], r:[4,1], e:[3,1], q:[6,1]}`(학생 후보 12 → 18장).
- 나머지 4장은 빈 `renderVals()`다. 애니메이션 keyframes는 없다.
  - `Scan-Item-Run`의 `stuform2~4`는 helmet 공통 CSS다.

---

## 2. Scan.dc.html — 「스캔 · 고르기 — 학생 전체 선택 (백그라운드) · 종류별 마지막 스캔」

### 2.1 목적·섹션 [확인]
고르기 단계다. 상태는 `전체 학생` 타일이 선택된 상태다.

| 섹션 | 요소 | rect | 내용 |
|---|---|---|---|
| S2 | 제목 줄 | 636,229, 1425×36 | `무엇을 스캔합니까` + (i) "학생과 아이템은 따로 스캔합니다. 학생 칸을 고르면 아이템 선택이 풀리고, 아이템을 고르면 학생 선택이 풀립니다. 전술대항전은 전술대항전 탭에서 스캔합니다." + `.conn 연결됨 · Blue Archive` |
| | 줄 라벨 `학생` | 633,283 | 분홍 skew 막대 + `학생` + `chip 백그라운드 · 플래너를 계속 쓸 수 있습니다` |
| | ScanKindTile `전체 학생`(선택) | 583,329, 848×196 | stucard 3장 + `학생 목록을 차례로 넘기며 읽습니다` + `보유 128명`·`약 8분` |
| | ScanKindTile `지금 화면 1명` | 1414,329, 637×196 | stucard 1장 + `열린 학생 정보 한 명` + `약 10초` |
| | 줄 라벨 `아이템` | 584,559 | `chip.wn 포그라운드 · 게임 창이 앞으로 나옵니다` + `여러 종류를 함께 고를 수 있습니다` |
| | ScanKindTile ×6 | x 538/780/1021/1262/1503/1745, y 605, 258×172 (80° 사선을 따라 x가 왼쪽으로 밀림) | `오파츠 · 마지막 9/12`, `기술 노트 · 마지막 3일 전`, `전술 교육 BD · 마지막 3일 전`, `활동 보고서 · 마지막 9/20`, `엘레프 · 마지막 없음`, `장비 · 마지막 9/10` |
| | 주 버튼 `.btn.pri` | 521,811, 641×66 | `학생 전체 스캔 시작` / `백그라운드 · 약 8분` |
| | `.plain` 설명 | 1168,811, 798×66 | "시작해도 플래너를 그대로 쓸 수 있습니다. 다른 탭으로 옮겨도 스캔은 계속되고, 진행은 맨 위 머리글에도 표시됩니다." |
| | 카드 **LastScanBars** | 434,911, 1514×457 | `종류별 마지막 스캔` + `막대 = 지난 날짜 · 14일 이상은 끝까지`. 7행(h30): 이름 96px / `SkewBar`(10px, 폭 = 경과일/14, 예 어제 7%, 3일 21%, 16일+ 100%) / 시각 / 칩(`최근`·`오래됨`·`스캔 없음`) |
| S3 | 선택 요약 | 2161,231 | `전체 학생` + `chip 백그라운드`, `보유 128명 · 약 8분`, `게임 창은 뒤에 두고 읽습니다` |
| | `시작 전에` 번호 목록 3개 | 2119,427 | ① 첫 학생 정보 열기 ② 게임 창을 뒤에 둔 채로 읽음, 다른 탭 사용 가능 ③ 최소화 금지, "최소화하면 일시정지하고 머리글에 알립니다." |
| | `읽는 항목` 칩 7개 | 2088,657 | 레벨·성급·스킬 4종·장비 3칸·전용무기·인연·능력 개방 |
| | `끝나면` | 2066,781 | "결과 검토가 열립니다. 바뀐 값만 확인해 적용합니다. 적용하기 전까지 확정값은 바뀌지 않습니다." |
| | 아래 ghost 버튼 | 1947,1316, 591×58 | `지금 화면 1명으로 바꾸기` / `열린 학생 정보 한 명만 · 약 10초` |

### 2.2 상태·상호작용
- 상호 배타 규칙이 (i)에 명시되어 있다 [확인]: 학생 칸을 고르면 아이템 선택이 풀리고, 아이템을 고르면 학생 선택이 풀린다. 학생 두 칸은 둘 중 하나만 고른다 [추정].
- 주 버튼 라벨과 오른쪽 S3 내용은 선택에 따라 바뀐다(§5 Scan-Items와 비교) [확인].

### 2.3 현재 코드 대응
- `ScanPage` 준비·종류 UI(`scan-refresh`, `scan-readiness-summary`, `scan-target` dropdown, `scan-kind` SegmentedButton, `scan-inventory-profile` dropdown, `scan-start`): **폐기 후 신규**로 바꾼다. 영어 Material UI라 재사용할 것이 없다.
- `RepositoryProfilePanel`(ScanPage 맨 위): **폐기**. 시안의 `계정` 행은 앱 전역 선택 프로필(`AppShell._selectedProfile`)을 표시만 한다 [추정].
- `_canStart`의 전제조건(backend 연결, scanner·repository 존재, profile, `_recognitionReady`, target `ready`, stage idle/terminal)은 **재사용**한다. 세션 컨트롤러로 옮긴다(§8).
- 신규 위젯: `ScanKindTile`, `LastScanBars`, `ScanRailStatusRow`, `ScanRecentRow`, `ScanPrereqList`(번호 목록).

### 2.4 데이터 요구

| 표시 | 출처 | 판정 |
|---|---|---|
| `Blue Archive · 2560×1440` | `ScannerTarget`에 해상도 없음 | FB-4/FD-118과 같다 |
| `이 계정 정답 샘플 12개` | `scanner.recognition.status` 검증 키는 `ready/manifest_version/missing`(+corrupt)뿐이다 [확인] | **신규**: 프로필·해상도별 정답 샘플 수(README "recognition_samples/ 로컬 상태") |
| `보유 128명` | `RepositoryState.students.length` | 있음 |
| `약 8분`·`약 10초`·`약 2분 · 약 58칸` | 출처 없음 | 칸 수는 `InventoryCatalogEntry.profileId == wireName` 개수로 셀 수 있다. 시간은 프론트 추정(FD-154) |
| 종류별 마지막 스캔·`최근/오래됨` | `RepositoryProfile`/`RepositoryState`에 시각 없음 [확인], `ScannerRecentSummary`는 메모리 전용이고 시각도 없다 [확인] | **FB-2 확장**(FD-147) |
| 최근 스캔 4행 | `ScannerRecentSummary`(최대 8, `_recordRecent`). 시각, 인벤토리 프로필, 확정 여부 필드가 없다 [확인] | 필드 추가는 프론트만으로 된다(FD-149) |

### 2.5 모호점
- I-S-1: `최근 스캔` 각주는 "이 실행 중 기록 · 앱을 끄면 지워집니다"다(현행 `ScannerRecentSummary`와 같다). 그런데 행 날짜는 `9/15`, `9/18`, `어제`다. 앱 실행 하나로 보기 어렵다. 예시 값인지, 영속 세션 기록을 원하는 것인지 확인이 필요하다(FD-149).
- I-S-2: `게임 창 다시 선택`이 홈의 창 선택 패널(Home-Connect-Pick)을 여는지, 스캔 탭 안에 같은 패널을 띄우는지 정해지지 않았다. 미연결 상태의 스캔 탭 시안도 없다(FD-155).
- I-S-3: `준비 상태` 행 3개가 버튼(`.btn.ghost`)이다. 눌렀을 때 동작(창 선택 / 인식 상태 상세 / 계정 전환)은 시안에 없다.
- I-S-4: 선물(presents)이 없다. 홈 팝업에도 없다(FD-123 → FD-151).

---

## 3. Scan-Student-Run.dc.html — 「스캔 · 학생 전체 진행 중 — 백그라운드 · 머리글 진행 표시 · 다른 탭 사용 가능」

### 3.1 구성 [확인]

| 섹션 | 요소 | rect | 내용 |
|---|---|---|---|
| S2 | 제목 줄 | 636,229 | `학생 전체 스캔` + (i) "게임 창을 뒤에 둔 채로 읽습니다. 다른 탭으로 옮기거나 플래너에서 다른 작업을 해도 스캔은 계속됩니다." + `chip 백그라운드 · …` + `TonalButton 일시정지` + `TonalButton.dng 중지` |
| | 큰 진행 수치 | 629,287, 1413×70 | `34` `/ 128명` · `27%` · `남은 시간 약 6분` |
| | 진행 막대 | 620,365, 1413×16 | SkewBar(분홍) [추정: 색] |
| | 타일 `지금 읽는 학생` | 564,405, 670×230 | stucard + `노아` + kv 5개: `레벨 Lv.90`, `성급 ★5 · 전무 ★2`, `스킬 4 / M / M / 7`, `장비 T9 · T9 · T8`, `전용무기 Lv.30 ?` |
| | 타일 `지금까지 · 34명` | 1211,405, 827×230 | KpiTile 4개: `바뀐 값 9`, `새 학생 1`, `확인 필요 2`, `그대로 22` + "확정값은 아직 바뀌지 않았습니다. 끝나면 결과 검토에서 적용합니다." |
| | SubHeader `방금 읽은 학생 · 최근 순 · 34명 중 6명` | 565,665 | |
| | ScanDiffRow ×6 | x 538→477(−12.3/행), y 715 피치 70, 1444×62 | `노아 · 전용무기 레벨 · 신뢰도 낮음 / 확인 필요`, `슌(수영복) · 새 학생 · 적용 전에 재검증 / 새 학생`, `오토기 · 레벨 20 → 90 / 바뀐 값`, `유우카 · EX 스킬 4 → 5`, `히나 · 변경 없음 / 그대로`, `미카 · 변경 없음` |
| | 각주 | 482,1141 | "다른 탭으로 옮겨도 계속됩니다. 진행은 맨 위 머리글에도 표시되고, 끝나면 알림으로 결과 검토를 엽니다." |
| S3 | `확인 필요 · 2명` + 설명 | 2161,231 | "스캔이 끝난 뒤 결과 검토에서 고칩니다. 지금은 미리 볼 수만 있습니다." |
| | 행 2개 | 2119,335 / 2107,405 | `노아 · 전용무기 레벨 / 자동 판독 Lv.30 · 신뢰도 0.61`, `슌(수영복) · 새 학생 / 확정값 없음 · 적용 전에 재검증` |
| | `백그라운드 스캔` kv 3줄(`.plain`) | 2087,539~ | `게임 창 · chip.ok 뒤에 있음 · 읽는 중`, `플래너 · 자유롭게 사용`, `최소화 · chip.wn 하면 일시정지` |
| | `다른 탭에서 보이는 모습` | 2079,701 | 칩 예시 `학생 스캔 34 / 128` + "머리글 오른쪽의 연결 표시 자리에 나옵니다. 누르면 이 화면으로 옵니다." |
| | 버튼 | 1959,1248 / 1947,1316 | ghost `학생 탭으로 이동 · 스캔은 그대로 계속됩니다`, pri `지금까지 읽은 34명 미리 검토 · 적용은 스캔이 끝난 뒤` |
| 셸 | 탭 `스캔`에 분홍 점 | `i[aria-label=스캔 진행 중]` 7×7 `#f2b3ef` | |
| | 헤더 `.conn` | color `#f7c9f4`, bg `rgba(242,179,239,.14)` | `학생 스캔 34 / 128` |
| S1 | 최근 스캔 첫 행 | `.btn.sel-pink` | `학생 전체 · 진행 중 / 34 / 128명 / chip 백그라운드` |

### 3.2 상태·상호작용
- 진행 중 상태 하나만 그려져 있다. 일시정지 상태(학생)는 그림이 없다. 최소화 → 일시정지 → 머리글 알림은 문구로만 나온다.
- `미리 검토`는 스캔 중에도 검토 화면을 읽기 전용으로 연다는 뜻이다 [추정].

### 3.3 현재 코드 대응
- 진행 표시: `_buildSession`(Material Chip/LinearProgressIndicator, `scan-session`·`scan-progress`·`scan-cancel` key)은 **폐기 후 신규**(`ScanRunView`)로 바꾼다. 취소는 `cancelScannerSession` **재사용**.
- **백그라운드 지속은 구조상 이미 된다**:
  - `AnimatedSectionStack`이 비활성 탭을 `Offstage`+`TickerMode`로 마운트한 채 둔다 [확인: `animated_section_stack.dart` 195–197행].
  - `ScanPage`의 이벤트 구독(`scannerEvents.listen`)도 탭을 옮겨도 살아 있다.
  - 다만 머리글 칩과 탭 점은 `AppShell`이 세션 상태를 알아야 한다. → 세션 컨트롤러를 `AppShell`이 소유한다(§8).
  - 프로필을 바꾸면 `ValueKey('scan-$_profileGeneration')`로 ScanPage가 새로 만들어진다. 이때 진행 중인 세션을 어떻게 할지는 미정이다 [추정: 막거나 취소 확인].
- **companion dock 제거(학생)**: 현재 `_start()`는 `_kind == student && full`일 때 `dockBeside`를 부른다 → 시안대로라면 이 분기를 지운다. 동작 변경이다.
- 머리글: `_AppHeader` → `_ConnectionBadge(connection: state.connection)`는 백엔드 상태를 표시한다 [확인]. 스캔 진행 표시 자리를 더해야 한다. FD-117과 우선순위를 정해야 한다(FD-148).
- `_TopTab`에 진행 점 표시 추가.
- "알림으로 결과 검토를 엽니다": 공용 토스트 위젯이 없다. 지금은 페이지마다 Material `SnackBar`를 쓴다(settings·tactical·plan 위젯 등) [확인]. → 다른 탭 위에도 뜨는 셸 수준 토스트를 새로 만든다.

### 3.4 데이터 요구

| 표시 | 현재 | 판정 |
|---|---|---|
| `34 / 128명` | `progress` 이벤트 `current/total` [확인]. mock은 학생 total이 `null`이다 [확인] | 실제 백엔드가 전체 학생 스캔에 total을 주는지 확인 불가. 없으면 보유 수(`students.length`)를 "약"으로 쓴다(FD-154) |
| `남은 시간 약 6분` | 없음 | 프론트 추정(진행 속도) |
| `지금 읽는 학생` 값 5개 | `feedback` 이벤트는 `field == 'student_id'`일 때 학생 id만 쓴다(`_applyEvent`) [확인] | 필드별 값이 이벤트에 오는지 확인 불가. 학생마다 `candidate` 이벤트가 바로 오면 그 payload로 그릴 수 있다 [추정] |
| 바뀐 값/새 학생/확인 필요/그대로 수, 방금 읽은 학생 diff | candidate payload `values` vs `RepositoryState.students[].values` | 후보가 스캔 중에 하나씩 오면 프론트 계산으로 된다. mock은 후보 1개만 끝에 보낸다 [확인] → mock fixture 확장 |
| 일시정지 / 최소화 일시정지 | 없음 | **백엔드 신규**(FD-142) |

### 3.5 모호점
- I-R-1: 머리글 칩을 누르면 "이 화면으로 옵니다" — 진행 중에는 스캔 탭 진행 화면으로, 완료 후에는 검토로 간다 [추정].
- I-R-2: "알림"이 앱 안 토스트인지, Windows 알림인지. 다른 탭에 있을 때 검토 화면을 자동으로 열지, 알림만 띄울지. 문구 "알림으로 결과 검토를 엽니다"는 알림을 눌러 연다로 읽힌다 [추정].
- I-R-3: 학생 진행 중 일시정지 상태 그림이 없다(버튼 라벨이 `이어서`로 바뀌는지 등).

---

## 4. Scan-Student-Review.dc.html — 「스캔 · 학생 결과 검토 — 확인 필요 · 계산 일치 일괄 적용 · 새 학생 재검증」

### 4.1 구성 [확인]
S2는 폭 1515로 좁아지고, S3는 1733부터 827 폭으로 넓어진다(학생 상세 카드를 넣기 위함).

| 섹션 | 요소 | rect | 내용 |
|---|---|---|---|
| S2 | 제목 | 636,229 | `학생 스캔 결과 검토` + (i) "자동 판독값은 후보입니다. 적용한 값만 확정값이 됩니다. 한 학생에서 여러 값이 바뀌면 한 줄로 묶어 보여 주고, 계산한 능력치를 그 값들 전체로 게임 화면과 맞춰 봅니다. 그래서 적용도 학생 단위로 합니다." + `chip.gy 학생 전체 · 방금 · 128명` |
| | 필터 버튼 5개 | y283, 250×56, x 616/867/1119/1371/1623 | `전체 128`(sel-pink) / `확인 필요 2` / `바뀐 학생 6` / `새 학생 1` / `그대로 119` |
| | SubHeader `확인 필요 · 2명` | 619,359 | "한 값이라도 신뢰도가 낮으면 그 학생 전체를 여기에 둡니다" |
| | ScanDiffRow(확인) ×2 | 590,407 / 575,493, 1260×78 | `노아 · 전용무기 레벨 — → Lv.30 · chip.wn 신뢰도 낮음 · 같이 바뀜 · 레벨 85→90 · EX 스킬 3→4 · 3건 · [고치기][보류]`. 첫 행은 선택 상태(bg 분홍 .12) |
| | SubHeader `바뀐 학생 · 6명 · 값 16건` | 577,597 | `계산한 HP · 공격력이 화면과 일치` |
| | **일괄 행** | 552,645, 1257×58 | `6명 모두 계산값이 화면과 일치합니다 / 값 16건 · 레벨 4 · 스킬 7 · 장비 4 · 인연 1` + `TonalButton.pri 6명 한 번에 적용` |
| | ScanDiffRow(일치) ×3 + 펼친 행 1(h112) | 539~495, y715~913 | `리오(무장) 레벨 78→82 · EX 4→5 · 장비 2 T8→T9 · 3건 · chip.ok 일치` …, `노도카 8건 · 펼침 · 접기`(8개 값) |
| | `.plain` 버튼 | 487,1033 | `나머지 2명 · 2건 · 바뀐 학생 탭에서 보기` |
| | SubHeader `새 학생 · 1명` | 491,1085 | `확정값이 없어 먼저 재검증합니다` |
| | ScanDiffRow(새) | 462,1133 | `슌(수영복) · 레벨 · 성급 · 스킬 · 장비 전체 · chip.wn 재검증 필요 · 레벨 없음→85 …· 12건 · [고치기][보류]` |
| S3 | 제목 | 1974,231 | `노아 · 학생 정보` + `chip.wn 확인 필요 · 전용무기` |
| | seg | 1970,283 | `스캔 결과`(on) / `현재 확정값` + `바뀐 값 2`·`확인 필요 1` |
| | **학생 상세 카드**(`.stusec` 746×780, 축소 배치) | ≈1904,345 | W-Student-Detail과 같은 구성(LEVEL Lv.90 / Position / Class / Weapon `Lv. 30 ?` / PLAN / SKILL SUMMARY EX 4/5·M·M·7/10 / EQUIPMENT T9·T9·T8 / 애장품 / Ability Release / 심상개화 / STATS 52,480·5,812·436·1,240 / 인연 →30·20). 위에 주석: `이전 85`, `이전 3`, `확인 필요` |
| | **폴백 캡처 카드** | 1828,1013, 693×144 | `chip.gy 폴백 캡처` + crop 이미지 `전용무기 숫자 부분` + `전용무기 레벨 · 확정할 값 [Lv.30]` + `TonalButton 재검증` + `계산 공격력 5,812 = 화면 5,812` / `자동 판독 Lv.30 · 신뢰도 0.61` / `이전 확정값 없음 · 계산 역산 Lv.30` |
| | 각주 | 1810,1165 | "판독이 폴백으로 넘어갈 때만 그 부분을 잘라 저장합니다. 적용하거나 폐기하면 지웁니다." |
| | 버튼 줄 | 1773,1256 | `보류`(ghost) / `폐기`(dng) / `다음` |
| | 주 버튼 | 1761,1316, 778×58 | `노아 3건 적용` / `전용무기 Lv.30 · 레벨 90 · EX 4 → 확정값 · 나머지 값은 그대로` |

### 4.2 현재 코드 대응 — `ScanStudentReviewWorkspace`와 비교 [확인: 코드]

| 항목 | 현재(`scan_student_review_workspace.dart`) | 시안 | 분류 |
|---|---|---|---|
| 배치 | 왼쪽 `_ResultList`(full이면 `orderScanResultCandidatesByGroup`으로 학교 그룹 순) + 오른쪽 `_buildDetail`(DiagonalSection) | S2 = 분류별 섹션 목록, S3 = 선택 학생 상세 | 구조 변경 |
| 분류 | `_hasProblem`(reviewRequired / 오류 / evidence status ∉ `_safeStatuses`) + `_status` 문자열(`suspicious`·`partial`… 영어) | 확인 필요 / 바뀐 학생 / 새 학생 / 그대로 + seg 필터 | 신규 분류. `_hasProblem` 재사용, "새 학생" = `currentStudents`에 id 없음, "그대로" = values 동일 |
| 행 | 학생 1명 = 1행(96px), 인연 행 | 학생 1명 = 1행 + 바뀐 값 칩 묶음 + 건수 + 펼침/접기 | 신규 |
| 일괄 적용 | 없음(후보별 `onApply`) | `6명 한 번에 적용`(계산 일치 학생만) | 신규. `_applyStudentCandidate`(review approve → commit → reload)를 순차 반복(FD-144) |
| 상세 | 초상 82 + 이름 + `Candidate id · revision` + 상태 Chip + `_ComparisonTable`(현재/스캔/계산/차이) + `상세 증거` ExpansionTile + `_RelationshipContributionPanel` | 학생 상세 인디케이터 카드 + 이전값 주석 + seg(스캔 결과/현재 확정값) + 폴백 캡처 카드 | 신규. 인디케이터는 `student_section_layout.dart`의 `_StudentStatusIndicators`(private)를 공개해 재사용 [확인: 1962행] |
| 수정·재검증 | `수정` → 표 안 입력 → `재검증`(`onRevalidate(candidate, payload, relationshipRanks, confirmedFields)`), `화면 확인` 체크(`_confirm`) | `고치기` → S3 폴백 카드 입력 → `재검증` | 재검증 콜백 재사용. **`화면 확인` 체크는 시안에 없다** |
| 보류·폐기 | `보류`(프론트 메시지만), 폐기는 `PopupMenu` → AlertDialog(`scan-student-discard-confirm`) | S3 `보류`/`폐기`/`다음` | 버튼 위치 변경, 확인 다이얼로그는 `BaModal`로 |
| 적용 단위 | 후보 단위(문제 없을 때만 `적용`) | 학생 단위 `노아 3건 적용`(확인 필요 학생도 고친 뒤 적용) | 같은 의미. 라벨에 건수·값 요약 |
| 인연 랭크 입력(다른 의상) | 단일 스캔에서 `relationship` 행 + 랭크 입력 | 없음 | 모호점 |
| 진단 JSON 추출 | `_buildSession`의 `scan-export-student-diagnostic` | 없음 | 모호점(FD-152) |

- 결론: `ScanStudentReviewWorkspace`는 **신규 위젯으로 대체**한다(가칭 `ScanStudentReviewBoard`). 재사용하는 것:
  - 상태 로직(`_hasProblem`, `_expected`, `_delta`, `_relationshipContributions`, `_revalidate`의 payload·confirmedFields 구성, `_edit`의 정수 검증)
  - 상위 콜백 4개(`ScanCandidateEditAction`, `ScanCandidateAction`)
- 이 파일은 **스캐너 세션 소유**다(워크플로 "파일 소유권") → 기존 파일을 고치지 말고 새 파일로 만든다. 로직은 순수 함수 파일로 추출해 두 위젯이 함께 쓰게 한다(§9 slice).

### 4.3 데이터 요구

| 표시 | 현재 | 판정 |
|---|---|---|
| 같이 바뀜 값, 건수, 새 학생 | candidate `values` vs `ConfirmedStudentState.values` | 있음(프론트 계산) |
| `계산한 HP · 공격력이 화면과 일치` | `student_stat_validation` evidence의 `details.expected/delta` [확인] | 있음. "일치" = delta가 전부 0 [추정] |
| `신뢰도 0.61` | `ScannerFieldEvidence.confidence` | 있음 |
| `폴백 캡처`(필드 crop 이미지) | 학생 후보에 이미지가 없다. 진단 파일도 `images_included: false` [확인]. crop은 인벤토리 미식별 슬롯(`crop_png_base64`)에만 있다 | **백엔드 신규**(FD-145) |
| `계산 역산 Lv.30` | 없음(expected/delta만 있음) | **백엔드 신규**(FD-145) |
| `인연 →30` 목표 | FD-003 활성 계획 문서 | FE3-b와 같다 |

### 4.4 모호점
- I-V-1: README 규칙은 "수정했거나 `화면 확인`한 필드만 정답 샘플로 학습"이다. 시안에는 `화면 확인`이 없다. 고치지 않고 적용하는 값을 학습할지(아이템 검토는 "고치지 않고 승인해도 됩니다 → 정답 샘플") 학생에도 같은 규칙을 쓸지 정해야 한다(FD-152).
- I-V-2: `확인 필요` 학생도 `노아 3건 적용`으로 적용한다(고친 뒤). 현재는 문제 있는 후보에 `적용`이 없고 재검증만 있다. 재검증 결과 계산 일치가 된 뒤에만 적용 버튼을 켜는지 확인이 필요하다 [추정: 그렇다. README "계산값이 화면과 일치한 후보만 적용"].
- I-V-3: 여러 의상의 인연 랭크 입력(`relationshipRanks`)이 시안에 없다.

---

## 5. Scan-Items.dc.html — 「스캔 · 고르기 — 아이템 2종 선택 (포그라운드)」

### 5.1 Scan.dc와 다른 점 [확인]
- 학생 타일 선택이 풀려 있다. `기술 노트`·`전술 교육 BD` 타일 2개가 선택(bg 분홍 .12)되어 있다.
- 아이템 줄 라벨에 `2종 선택` + `TonalButton 모두 선택`(h28)이 있다.
- 주 버튼: `아이템 2종 스캔 시작` / `게임 창이 앞으로 나옵니다 · 약 2분`. 설명: "시작하면 플래너는 뒤로 갑니다. 진행은 게임 창 옆 작은 창에 나오고, 끝나면 플래너가 다시 앞으로 와 결과 검토를 엽니다."
- S3:
  - `아이템 2종 · chip.wn 포그라운드`, `기술 노트 · 전술 교육 BD`, `약 2분 · 약 58칸`
  - `시작 전에`: ① 인벤토리 화면을 연다 ② 게임 창이 앞으로 나오고 고른 종류를 차례로 넘긴다, 플래너는 뒤로 간다 ③ "끝날 때까지 마우스와 키보드를 쓰지 마십시오. 입력이 감지되면 일시정지합니다. Esc를 누르면 중지합니다."
  - `진행 표시`: "게임 창 옆에 작은 진행 창이 붙습니다. 인식 영역을 가리지 않는 쪽에 붙고, 캡처에는 들어가지 않습니다."
  - `끝나면`: "플래너가 다시 앞으로 와 결과 검토를 엽니다. 승인한 칸만 인벤토리에 적용됩니다."
  - 아래: `고른 종류 해제 · 아이템 선택을 모두 풉니다`

### 5.2 코드 대응
- 다중 선택 → `startScannerSession(..., inventoryScanProfile:)`은 **프로필 하나만** 받는다 [확인]. `scanner.session.start` 요청 키도 `inventory_scan_profile` 하나다 [확인].
  - 프론트에서 종류별 세션을 차례로 이어 돌리거나(큐), 백엔드에 목록 키를 추가(additive)해야 한다(FD-143).
- 나머지는 §2.3과 같다.

### 5.3 모호점
- I-I-1: `모두 선택`이 6종 전부인지(장비 포함). 1080 창에서는 equipment가 비활성이다(O0-6 `SYNTH_GRID_ENABLED_WINDOWS`) [확인: 문서] → 해상도별 비활성 타일 규칙(FD-124)과 합쳐서 정해야 한다.

---

## 6. Scan-Item-Run.dc.html — 「스캔 · 아이템 진행 중 — 게임 창이 앞으로 · 옆에 붙는 진행 창 (진행 / 일시정지 / 완료)」

### 6.1 구성 [확인]
**앱 화면이 아니라 설명도다.** 탭바·`.sw` 섹션이 없다. 제목 "아이템 스캔 진행 · 게임 창이 앞으로 나온 상태 (포그라운드)" + 설명 "… 진행은 게임 창 옆에 붙는 작은 창(가로 1 : 세로 2)에 표시합니다. 학생 스캔은 이 방식을 쓰지 않습니다."

| 요소 | rect | 내용 |
|---|---|---|
| 바탕화면 예시 | 40,104, 1880×1000 | `바탕화면 예시 · 게임 창 1280×720` |
| 플래너 창(뒤) | 460,164, 1300×640 | `BA Planner · 뒤로 감`, 섹션 4개 윤곽만 |
| 게임 창(앞) | 100,254, 1280×750 | `Blue Archive · 앞으로 나옴`. 종류 탭 6개, 수량 칸 24개, 점선 `인식 영역 · 칸마다 아이콘과 수량을 읽습니다 (설명용 표시)` |
| **진행 창(진행 중)** | 1382,254, 375×750 (게임 창 오른쪽, `게임 창 오른쪽에 붙음 · 높이 = 게임 창`) | `Plan A · 아이템 스캔` / `기술 노트 · 전술 교육 BD` + `chip.pk 진행 중` / `69%` `40 / 58칸 · 남은 시간 약 40초` / 진행 막대 / 종류별 줄 `기술 노트 · chip.ok 완료 · 28 / 28칸`, `전술 교육 BD · chip.pk 12 / 30칸` / **NOW READING** 카드 `전술 교육 BD · 밀레니엄 · 최상급 · 40 → 40 일치` / KpiTile 3개 `바뀐 수량 4`·`확인 필요 1`·`그대로 35` / `최근 기록` 5줄(`BD 밀레니엄 · 40 그대로`, `BD 백귀야행 · 12 → 18`, `BD 붉은겨울 · 수량을 읽지 못함`, …, `기술 노트 28칸 완료`) / 경고 `마우스 · 키보드를 쓰면 일시정지합니다 · Esc 중지`(#ffd08a) / `일시정지`·`중지`(dng) |
| 번호 설명 4개 | 100,1030 | ① 게임 창이 앞으로(플래너는 뒤로, 종류 탭을 차례로 누름) ② "작은 창은 캡처 밖 … 오른쪽에 자리가 없으면 왼쪽에 붙습니다." ③ "입력하면 일시정지 … Esc는 언제든 중지합니다. 읽은 칸은 남습니다." ④ "마지막 칸을 읽으면 플래너가 다시 앞으로 오고 아이템 결과 검토를 엽니다." |
| 상태 변형 `입력 감지 · 일시정지` | 1960,168, 270×540 | chip.wn `일시정지 · 입력 감지` + 카드 "마우스 입력이 감지되어 멈췄습니다 / 게임 화면을 처음 위치로 되돌린 뒤 '이어서'를 누르십시오. 읽은 40칸은 그대로 남습니다." + `이어서`(pri) / `중지` |
| 상태 변형 `완료` | 2250,168, 270×540 | chip.ok `완료`, `100%` `58 / 58칸`, "곧 플래너가 앞으로 오고 결과 검토가 열립니다. 이 창은 함께 닫힙니다." + `결과 검토 열기` |
| 각주 | 1960,734 | "게임 창이 작아지면(예: 높이 540) 같은 비율로 줄어듭니다." / "일시정지 중에는 게임 창을 앞으로 두고, 플래너를 앞으로 가져오지 않습니다." / "중지해도 그때까지 읽은 칸은 결과 검토에서 볼 수 있습니다." / "학생 스캔은 게임 창을 뒤에 둔 채 진행되어 이 창을 띄우지 않습니다. 진행은 플래너 머리글과 스캔 탭에 나옵니다." |

### 6.2 현재 코드 대응
- `WindowDockService.dockBeside(targetId)` → `ScanDockPlacement(side, width, height, gameResized)`, `restore()` [확인].
  - 응답에 `side`가 있으므로 "오른쪽에 자리가 없으면 왼쪽"과 맞는다 [추정].
  - 지금은 **플래너 창 자체**를 게임 옆으로 줄인다. 그 상태에서 `AppShell` 최상단 `Positioned.fill(ScanCompanionDock)`이 전체를 덮는다 [확인: app_shell.dart 457–461행].
  - 시안 그림은 플래너 창(뒤)과 진행 창(앞)이 **동시에 따로** 있다. 현행 방식(플래너 = 진행 창)으로 하면 "플래너는 뒤로 감"이 "플래너가 진행 창으로 바뀜"이 된다. 진짜 두 번째 창을 만들려면 Windows 러너에 네이티브 창을 추가해야 한다(러너 소스는 로컬에 없다) → FD-141(열림).
- `ScanCompanionDock`: **수정(대) — 내용 재작성.**

  | 현재 | 시안 |
  |---|---|
  | `STUDENT SCAN` 머리 | `Plan A · 아이템 스캔` |
  | 대상 창 제목, 인식 수 칩 | 종류별 진행 |
  | `_CurrentStudentFeedback`(초상·이름·id) | NOW READING(아이템) |
  | 취소 IconButton(`scan-dock-cancel`) | KPI 3개, 최근 기록, 경고, 일시정지/이어서/중지, 완료 시 `결과 검토 열기` |

  `ScanCompanionState` 필드도 바뀐다(종류 목록·종류별 current/total, 현재 아이템, 카운트, paused 사유, 최근 기록, onPause/onResume). 이 파일은 워크플로 소유권 목록에 없다. 다만 scanner 오케스트레이터 로그(C5e-6e)에 "다른 세션의 미커밋 편집(scan_page·scan_companion_dock·scan_student_review_workspace)과 충돌 금지"가 있다 [확인]. 그래서 사실상 공동 소유로 다룬다.
- 1:2 비율과 "높이 = 게임 창"은 네이티브 `dock`이 정한다. 지금 반환값(`width/height`)이 1:2인지는 확인할 수 없다(러너 없음).
- 완료 → "플래너가 앞으로 + 검토 열기"는 `restore()` + 스캔 탭 검토로 이동하면 된다. 지금은 terminal에서 `_closeCompanion()`만 하고 이동은 없다 [확인].

### 6.3 데이터 요구

| 표시 | 현재 | 판정 |
|---|---|---|
| 종류별 `28 / 28칸`, 전체 `40 / 58칸` | 세션당 `progress current/total`(프로필 하나) | 다중 종류는 FD-143 방식에 달렸다. 큐 방식이면 종류별 total을 칸 수로 미리 알아야 한다(카탈로그 개수 = 추정치) |
| NOW READING(아이템·티어·수량·일치) | `feedback`은 학생 id만 처리 [확인] | 인벤토리 feedback payload(아이템 id·수량·이전값 비교)는 **확인 불가 → 백엔드 요청**. 없으면 카드 숨김 |
| 바뀐 수량/확인 필요/그대로, 최근 기록 | 후보가 끝에 한 번 오면 진행 중에는 계산할 수 없다 | 진행 중 부분 결과 이벤트가 필요하다(FD-156) |
| 일시정지(입력 감지)/이어서 | 없음. D21 = `input_busy` 재시도 ≤2 → `partial` [확인] | **백엔드 신규 + D21 개정**(FD-142) |
| Esc 중지 | 키 입력은 백엔드 저수준 훅 쪽이다 [추정: D21 "저수준 훅"] | 백엔드가 Esc를 cancel로 처리해야 한다(포그라운드는 게임 창이라 Flutter가 키를 받지 못함) |
| "캡처에는 들어가지 않습니다" | 그리드 스캔 캡처 방식(PrintWindow vs 화면 캡처)은 로컬 소스로 확인 불가 | 진행 창이 게임 창과 겹치지 않으면 어느 방식이든 안전 [추정] |

### 6.4 모호점
- I-C-1(FD-141): 진행 창 = 플래너 창을 줄인 것(현행)인가, 별도 창인가.
- I-C-2: "게임 화면을 처음 위치로 되돌린 뒤 '이어서'" — 이어서 할 때 백엔드가 그리드 위치를 다시 맞추는지(C5e-1 결정론적 스크롤·위상 검증), 사용자가 맞춰야 하는지.
- I-C-3: 학생 1명(`지금 화면 1명`) 스캔도 백그라운드인지. 시안은 학생 = 백그라운드로 묶는다. 현재는 single에서 dock하지 않는다 [확인]. 일치한다.

---

## 7. Scan-Item-Review.dc.html — 「스캔 · 아이템 결과 검토 — 칸별 승인 · 읽지 못한 칸은 빗금」

### 7.1 구성 [확인]

| 섹션 | 요소 | rect | 내용 |
|---|---|---|---|
| S2 | 제목 | 636,229 | `아이템 스캔 결과 검토` + (i) "읽은 수량은 후보입니다. 승인한 칸만 인벤토리에 적용되고, 같은 계정 · 해상도의 정답 샘플로 쌓입니다. 읽지 못한 칸은 0이 아니라 빗금으로 둡니다." + `chip.gy 기술 노트 · 전술 교육 BD · 방금` |
| | 필터 버튼 4개 | y283, 359×56 | `전체 58`(sel-pink) / `확인 필요 2` / `바뀐 수량 5` / `그대로 51` |
| | SubHeader `기술 노트 · 최상급 7칸` | 619,361 | `하급 · 중급 · 상급 21칸은 바뀐 칸 없음 · 펼치기` |
| | **ItemCellTile** ×7 | 행 580,411, 각 124×150(margin 13), 배경 skewX(−10°) | 아이콘 89×72 + 학교명 + 값. 바뀐 칸은 `96 → 112 +16`, 그대로는 흐린 `140`. 선택 칸(밀레니엄) = inset 2px `#f2b3ef` |
| | SubHeader `전술 교육 BD · 최상급 6칸` | 580,583 | `하급 · 중급 · 상급 18칸 · 1칸 바뀜 · 펼치기` |
| | ItemCellTile ×6 | 행 541,633 | `아비도스 18→22 +4`, `백귀야행 12→18 +6`, **`붉은겨울` 빗금(`repeating-linear-gradient(135deg, rgba(158,176,194,.22) 0 3px …)`) + `읽지 못함`**, 확인 필요 칸 = inset 1.5px `rgba(255,198,109,.8)`(호박색) |
| | 범례 `표시` | 533,851 | `확인 필요` / `+n 지난 확정값 대비` / 빗금 `읽지 못함 · 0으로 보지 않음` / `흐림 = 그대로` |
| | 주 버튼 | 506,897, 641×66 | `승인한 56칸 인벤토리에 적용` / `확인 필요 2칸은 빼고 적용합니다` |
| | `.plain` 설명 | 1153,897 | "확인 필요 칸을 남겨 두고 적용해도 됩니다. 남은 칸은 인벤토리에 이전 값으로 남고 '확인 필요'로 표시됩니다." |
| S3 | 제목 | 2161,231 | `기술 노트 · 밀레니엄 (최상급)` + `chip.wn 확인 필요` |
| | 아이콘 119×96 + 위치 | 2150,287 | `인벤토리 · 기술 노트 탭 · 4행 2열` / "그리드 스캔은 캡처를 남기지 않습니다." / "수량이 의심되면 게임의 이 칸에서 확인합니다." |
| | kv `.plain` | 2111,399 / 2102,449 | `이전 확정값 96 · 3일 전 스캔`, `자동 판독 112 · 신뢰도 0.58 · 1과 7 구분 낮음` |
| | `승인할 수량` + 값 `112` + −/+ `TonalButton` 2개 | 2108,555 | NudgeButtons/Stepper |
| | 설명 | 2099,611 | "승인한 칸만 이 계정 · 이 해상도의 정답 샘플로 쌓입니다. 고치지 않고 승인해도 됩니다." |
| | `이 아이템을 쓰는 곳` | 2086,663 | `활성 계획 필요량 254`, `승인하면 부족 158 → 142` |
| | 버튼 | 1960,1256 / 1947,1316 | `이 칸 건너뛰기` / `다음 확인 필요`, pri `112로 승인 · 기술 노트 · 밀레니엄 최상급` |

### 7.2 현재 코드 대응

| 시안 | 현재 | 분류 |
|---|---|---|
| 아이템 검토 화면 전체 | 스캔 탭: `_CandidateSummary`(후보 id·evidence 나열 + `Review in Inventory` 인계 버튼) [확인] → `AppShell._handoffCandidate` → `InventoryPage._CandidatePanel`(`added/changed/missing/unknown` 요약 + `Hold` / `Review & approve`) [확인] | **신규**(`ScanItemReviewBoard`). `_CandidatePanel`과 인계 경로는 **폐기**(FD-120 확정과 같이 FE6-a에서) |
| 칸별 승인 → 일부만 적용 | `_approveCandidate()` = 후보 전체를 `reviewScannerCandidate(approve: true)` → `commitScannerCandidate` [확인] | **백엔드 의미 확인 필요**(FD-146). 일부 적용 = payload에서 미승인 entry를 빼고 review → commit으로 될 수 있지만, 백엔드가 "빠진 entry = 이전 값 유지"로 처리하는지는 확인할 수 없다 |
| 읽지 못한 칸 빗금 | `_CandidatePanel`이 `quantity == null`을 `unknown`으로 센다. 문구 "Missing rows stay unknown; they are never auto-filled with zero." [확인] | 의미는 같다. 표현만 신규(빗금은 FE2-d 차트 primitive 빗금 재사용) |
| 확인 필요 칸 | 후보 단위 `reviewRequired`만 있다. entry 단위 신뢰도·note는 evidence 구조가 entry별인지 확인 불가 | **백엔드 확인/신규**: entry별 confidence·note(`1과 7 구분 낮음`) |
| `4행 2열` 위치 | `ScannerUnresolvedSlot.slot`(미식별 슬롯만)이 있다 [확인]. 일반 entry의 slot 위치는 확인 불가 | 백엔드 확인/신규 |
| 승인할 수량 수정 | 없음(인벤토리 탭은 수동 수정만) | `reviewScannerCandidate`의 payload 수정으로 가능 [추정] |
| 승인 칸 = 정답 샘플 | README "인벤토리 후보도 사용자가 명시적으로 승인한 슬롯만 같은 범위의 정답 샘플로 누적" [확인] | 칸 단위 승인을 백엔드에 전달하는 키는 Dart에 없다(`confirmedFields`는 학생 재검증·review에만 씀). 같은 키를 인벤토리에 쓰는지 확인 필요 |
| 미식별 아이템(identity) | `ScanInventoryIdentityReview`: crop + 후보 top-3 + 검색 + `이번 세션만`/`영구 승인`/`건너뛰기` [확인] | **시안에 없다.** "확인 필요" 칸의 변형으로 S3에 기존 위젯을 그대로 넣는 것을 권장(FD-153). 파일은 스캐너 세션 소유라 수정하지 않고 마운트만 한다 |
| `이 아이템을 쓰는 곳` | `InventoryShortageRow`(required/owned/shortage) [확인: 대장 FD-030 근거] | 있음(프론트 계산 + 활성 계획 문서) |
| `이전 확정값 96 · 3일 전 스캔` | 값은 `RepositoryState.inventory`. 시각은 없다 | FB-2 이력(resource_key 단위)(FD-147) |

### 7.3 모호점
- I-T-1: "남은 칸은 인벤토리에 이전 값으로 남고 '확인 필요'로 표시됩니다" — 인벤토리 탭에 아이템별 `확인 필요` 표시가 **영속**해야 하는가(앱 재시작 후에도)? 그렇다면 repository에 entry별 `needs_review` 같은 필드가 필요하다(FD-146).
- I-T-2: 하위 티어(`하급·중급·상급 21칸은 바뀐 칸 없음 · 펼치기`) 접기 기준. 바뀐 칸이 없는 티어 줄을 접는지, 최상급만 기본으로 펼치는지 [추정: 바뀐 칸·확인 필요 칸이 있는 티어만 펼침].
- I-T-3: S3 "그리드 스캔은 캡처를 남기지 않습니다"와 미식별 슬롯 crop(`crop_png_base64`)이 충돌한다. 미식별 슬롯은 상세 패널 판독이라 예외로 보인다 [추정].

---

## 8. 핵심 질문별 답

### Q1. 새 스캔 탭과 홈 스캔 팝업(Home-Connected-Scan)의 관계
- 시안 근거 [확인]:
  - 팝업은 바뀌지 않았다.
  - 스캔 탭에 창 선택 UI는 없고 `게임 창 다시 선택` 버튼만 있다.
  - 스캔 탭 고르기 화면은 팝업과 같은 종류(학생 2 + 아이템)를 다시 보여 준다. 여기에 다중 선택, 마지막 스캔, 시작 전 안내, 시작 버튼을 더했다.
  - 팝업 (i) "열어 둔 뒤 누르십시오"는 타일 = 시작으로 읽힌다.
- 두 곳의 차이:

  | | 팝업 | 스캔 탭 |
  |---|---|---|
  | 전술대항전 | `준비 중`(disabled) | 없음 |
  | 장비 | "기타" 줄 | 아이템 줄 |
  | 아이템 선택 | 타일 하나 = 한 종류 | 다중 선택 |
  | 학생 대표 이미지 | 12장 | 18장 |

- 판단: **종류 선택을 두 곳에 둔다.** 팝업은 "한 종류 바로 시작" 지름길이고, 스캔 탭은 "전체 고르기 + 진행 + 검토"의 본거지라고 읽는 것이 시안끼리 가장 덜 충돌한다 [추정]. 그래도 직접 그린 연결 흐름이 없으므로 **FD-140(열림)**으로 묻는다. 어느 쪽이든 시작은 같은 세션 컨트롤러를 쓴다.
  - 팝업에서 시작하면 학생은 그 자리(홈)에 머물고 머리글 칩으로 진행을 보여 준다.
  - 아이템은 진행 창을 쓴다.
  - 끝나면 스캔 탭 검토로 간다.
- 팝업 `전술대항전` 타일은 스캔 탭 노트("전술대항전 탭에서만")에 맞춰 다룬다: 전술대항전 탭으로 이동하는 링크로 바꾸거나 제거한다(FD-150).

### Q2. FD-120에 대한 답
- 시안이 생겼으므로 FD-001에 따라 시안이 답이다:
  - 스캔 탭 = S1 준비 상태·최근 스캔(앱 실행 기록)·게임 창 다시 선택 / S2 고르기 → 진행 → 결과 검토 / S3 선택·진행·검토 상세.
  - 창 선택은 홈 패널에 남는다.
  - 인벤토리 후보 비교(`_CandidatePanel`)와 학생 탭 후보 인계(`StudentPage.candidateContext`, `_handoffCandidate`의 student/inventory 분기)는 스캔 탭 검토로 옮겨진다.
- FD-120의 선택지 (a)와 다른 점: "준비·종류 선택을 홈으로 일원화"가 아니다. **종류 선택은 스캔 탭에도 있다.** 팝업과의 관계만 FD-140으로 남긴다.
- FD-120을 `확정(FD-001 적용, 2026-10-06 시안)`으로 갱신하고 FE6-a의 막힘을 푼다. FE6-a는 `_CandidatePanel` 제거만 하면 된다.

### Q3. 백그라운드/포그라운드, 머리글 진행, 진행 창, 일시정지 — 현재 지원 여부

| 요구 | 지원 | 근거 |
|---|---|---|
| 학생 백그라운드(게임 창 뒤) | **백엔드 지원**(문서) | scanner 워크플로 C5f: PostMessage 키 + PrintWindow, 클릭 폴백만 잠깐 포그라운드(D29) |
| 아이템 포그라운드 | **백엔드 지원**(문서) | C5e-1 "포그라운드 유지(사용자 결정 2026-09-27)" |
| 플래너 다른 탭 사용 중 진행 | 프론트 구조상 가능 | `AnimatedSectionStack` Offstage 유지, ScanPage 구독 유지 |
| 머리글 진행 칩·탭 점 | **없음** | 세션 상태가 `_ScanPageState` 지역 상태. `AppState.scanPhase`(idle/scanning/succeeded/failed)는 `ProcessAppService.startScan()` 경로 전용 [확인] |
| 학생 진행에 dock 안 함 | 코드 변경 필요 | `_start()` 245–253행이 student full에서 `dockBeside` |
| 아이템 진행 창 | 부분 지원 | `dockBeside`/`restore`(MethodChannel `ba_planner/window_dock`의 `dock`/`restore`) + `ScanCompanionDock`. 내용 재작성 + 아이템 시작 시 dock으로 트리거 이동. 별도 창이면 네이티브 신규 |
| 일시정지/이어서 | **없음** | 프로토콜에 `scanner.session.pause/resume` 같은 메서드 없음 [확인: `_validScannerSuccessPayload`의 메서드 목록] |
| 최소화 → 일시정지 | **없음** | `ScannerTargetStatus.minimized`는 시작 전 판정용. 진행 중 처리 확인 불가 |
| 입력 감지 → 일시정지 | **다름** | D21 = 재시도 ≤2 후 `partial` |
| Esc 중지 | 확인 불가 | 백엔드 저수준 훅 필요 [추정] |
| 완료 후 플래너 앞으로 + 검토 | 부분 | `restore()`는 있다. 검토 화면 이동은 없다 |

### Q4. 검토 화면 차이와 "종류별 마지막 스캔" 데이터
- 학생: §4.2 표. 핵심 신규는 분류 seg, 계산 일치 일괄 적용(FD-144, 순차 commit으로 가능), 학생 상세 인디케이터 재사용, 폴백 crop·역산(백엔드, FD-145).
- 아이템: §7.2 표. 칸별 승인과 부분 적용, 영속 `확인 필요`(FD-146), entry별 신뢰도·위치(백엔드 확인), identity 검토 위젯은 마운트만(FD-153).
- 마지막 스캔: FB-2(FD-041 (a))의 "프로필별 마지막 스캔 시각"과 **겹친다**. 시안은 다음까지 요구한다:
  - ① 종류별(학생 + 인벤토리 프로필 6)
  - ② 아이템별(`3일 전 스캔`)
  - ③ 계정 메타 줄(`마지막 스캔 어제 21:40` = 학생 행과 같은 값)

  → FB-2 이력 레코드에 `scan_kind`·`inventory_scan_profile`(source=scan일 때)을 넣고, 조회 메서드에 "종류별 최신 scan 커밋 시각"을 더하는 것으로 한 번에 해결된다(FD-147). 변경 없는 스캔(전부 "그대로")도 시각을 남기려면, 적용 시 diff 0이어도 이력 1건(또는 종류별 시각 갱신)을 남겨야 한다.

### Q5. 전술대항전 스캔 제외
- 코드와 맞다:
  - `ScanPage`에 tacticalLobby 선택 UI가 없다.
  - `_payloadMatchesKind`·`_CandidateSummary`에 tacticalLobby 분기는 있지만 시작 경로가 없다.
  - `TacticalLobbyScannerService`를 쓰는 UI도 없다 [확인: `ui/` grep].
  - `_handoffCandidate`의 else(→ pvp) 분기만 남아 있다.
- 결정과도 맞는다: FD-125(전술 = 탭 안 로비 스캔)와 FD-122(FE9-c 후 로비 스캔 세션).
- 충돌: 홈 팝업 `전술대항전(준비 중)` 타일(FD-150). 스캔 탭 `_handoffCandidate` 전술 분기는 FE9-c에서 전술 탭 자체 흐름으로 옮긴 뒤 지운다.

### Q6. 파일 충돌을 피하는 분할
§9.2 표.
- 원칙 ① 새 화면은 **새 파일**로 만든다(`ui/pages/scan/…`). 스캐너 세션 소유 파일(`scan_student_review_workspace.dart`, `scan_inventory_identity_review.dart`)은 수정하지 않는다.
- 원칙 ② 공유 로직은 소유 파일에서 **복사하지 말고** 순수 함수 파일로 추출한다. 이 추출 한 번만 스캐너 세션과 시점을 맞춘다.
- 원칙 ③ `scan_page.dart`·`scan_companion_dock.dart`는 동결 창(스캐너 세션 미커밋 편집 없음 확인) 안에서만 고친다.
- 원칙 ④ 백엔드·프로토콜 추가는 스캐너 워크플로에 요청(additive)하고, 프론트는 "필드가 오면 표시, 없으면 숨김"으로 먼저 간다.

---

## 9. 그룹 전체 요약

### 9.1 분류 요약

| Dart 파일/클래스 | 분류 | 근거 |
|---|---|---|
| `scan_page.dart` `_ScanPageState` 세션 로직(`_start/_cancel/_recoverSnapshot/_handleEvent/_applyEvent/_keepCandidate/_recordRecent/_openRecent/_revalidateStudentCandidate/_applyStudentCandidate/_discardStudentCandidate/_assignInventoryIdentity/...`) | 수정(대, 추출) | `ScanSessionController`로 옮기고 AppShell이 소유(A §8.2 제안과 같음) |
| `scan_page.dart` build(준비·종류·세션·후보 요약·최근) | 폐기 → 신규 `ScanTabPage` | 영어 Material UI, 시안 3섹션과 무관 |
| `RepositoryProfilePanel` 사용(스캔 탭) | 폐기 | 앱 전역 프로필 |
| `scan_student_review_workspace.dart` | 유지(동결) → 신규 `ScanStudentReviewBoard`로 대체, FE10에서 제거 | 소유권 |
| `scan_inventory_identity_review.dart` | 그대로 재사용(마운트만) | 시안에 없음, 기능 유지 필요 |
| `scan_companion_dock.dart` | 수정(대, 아이템 진행 창) | §6.2 |
| `window_dock_service.dart` | 재사용(호출 시점 변경: 학생 full → 아이템) | FD-141 (a)일 때 |
| `scanner_service.dart` | 수정(additive): pause/resume, 상태 필드, 다중 프로필(선택) | FB-10 |
| `planning_protocol_client.dart` `_validScannerSuccessPayload` | 수정(additive 검증) | 같다 |
| `mock_app_service.dart` 스캐너 | 수정(대): 학생 128명·아이템 58칸 fixture, 진행 중 후보 스트리밍, 일시정지 | 검수 fixture 규칙 |
| `student_scan_diagnostic.dart` | 그대로 재사용(진입점만 이동) | FD-152 |
| `app_shell.dart` `_AppHeader`/`_ConnectionBadge`/`_TopTab`, `_handoffCandidate` | 수정(최소 diff) | 진행 칩·탭 점·토스트, 인계 분기 축소 |
| `inventory_page.dart` `_CandidatePanel`·`candidateContext` | 폐기(FE6-a) | 검토 이관 |
| `student_page.dart` `candidateContext`·`_approveCandidate` | 폐기(FE3/FE8 조율) | 검토 이관 [추정: 스캔 탭에서 이미 학생 후보는 인계하지 않음 — `_CandidateSummary`는 학생 이외만 표시] |
| `student_section_layout.dart` `_StudentStatusIndicators` | 수정(공개) | 검토 S3 재사용. Lane A(FE3) 파일이므로 요청 |
| (신규) `ScanSessionController`, `ScanTabPage`, `ScanKindTile`, `LastScanBars`, `ScanRailStatusRow`, `ScanRecentRow`, `ScanRunView`(학생), `ScanStudentReviewBoard`, `ScanItemReviewBoard`, `ItemCellTile`, `ScanHeaderProgressChip`, `ScanToast` | 신규 | — |

### 9.2 slice 제안 (FE8-f/g를 쪼갬, 순서대로)

| 순서 | slice | 범위 | 건드리는 파일 | 난이도 | 선행 의존 |
|---|---|---|---|---|---|
| 1 | **FE8-f1 세션 컨트롤러 추출**(동작 보존) | `ui/scan/scan_session_controller.dart`(신규, `ChangeNotifier`): 세션 단계·이벤트 커서·후보·최근·companion publish·dock 호출. 학생 검토 순수 로직을 `ui/scan/scan_student_review_logic.dart`(신규)로 추출(`_hasProblem`, `_expected`, `_delta`, 분류). `ScanPage`는 컨트롤러를 그리기만 한다. AppShell이 컨트롤러 소유. `scan_page_test` 회귀 0 | `scan_page.dart`, `app_shell.dart`(소유 1줄), 신규 2 | L | FE2, **스캐너 세션 동결 창**(scan_page 미커밋 편집 없음 확인). 추출 로직 파일은 스캐너 세션에 통보 |
| 2 | **FE8-f2 머리글 진행·토스트** | `ScanHeaderProgressChip`(백엔드 끊김 > 스캔 진행/일시정지 > 게임 창 연결), 탭 `스캔` 점, 완료 토스트(누르면 검토) | `app_shell.dart` | S | f1, FD-148, (FE8-d 칩) |
| 3 | **FE8-g1 스캔 탭 골격 + 고르기** | `ScanTabPage` 3섹션, S1 레일(준비 상태·최근 스캔·게임 창 다시 선택), S2 고르기(학생/아이템 상호 배타, 다중 선택, 모두 선택, 주 버튼), S3 시작 전 안내. 마지막 스캔 막대·정답 샘플 수는 데이터가 오기 전까지 "—" | 신규 `ui/pages/scan/*`, `app_shell.dart`(ScanPage → ScanTabPage 교체 1줄) | M | f1, FE2-a/b/d, FD-140, FD-155 |
| 4 | **FE8-g2 학생 진행(백그라운드)** | `ScanRunView`: 큰 진행 수치, 지금 읽는 학생, KPI 4, 방금 읽은 학생 행, S3 확인 필요 미리보기·백그라운드 상태, `학생 탭으로 이동`, `미리 검토`. 학생 full의 dock 호출 제거. 일시정지 버튼은 FB-10 전까지 숨김 | 신규, `scan_session_controller.dart` | M | f1, f2, FD-156, (FB-10 일시정지) |
| 5 | **FE8-g3 아이템 진행 창** | 아이템 시작 시 dock, `ScanCompanionDock` 재작성(진행/일시정지/완료), 다중 종류 큐, 완료 → restore + 검토 이동 | `scan_companion_dock.dart`(동결 창), 컨트롤러 | M~L | f1, FD-141, FD-143, (FB-10) |
| 6 | **FE8-g4 학생 검토 v2** | `ScanStudentReviewBoard`(신규 파일): 분류 seg, 섹션 목록, 일괄 적용(순차 commit), 펼침, S3 학생 상세 인디케이터 + 이전값 주석 + 폴백 카드(crop은 필드가 오면 표시) + 보류/폐기/다음/적용. 기존 workspace는 마운트 해제만 하고 파일 유지 | 신규, `student_section_layout.dart`(인디케이터 공개 — Lane A 요청) | L | f1, FE3(학생 상세), FD-144, FD-145, FD-152 |
| 7 | **FE8-g5 아이템 검토** | `ScanItemReviewBoard` + `ItemCellTile`(빗금·확인 필요·흐림), 티어 접기, S3 검사기(Stepper, 쓰는 곳), 부분 적용, 미식별 슬롯은 `ScanInventoryIdentityReview` 마운트 | 신규 | L | f1, FE2-d, FD-146, FD-153, (FB-10 entry 단위 승인) |
| 8 | **FE6-a 연동** | `InventoryPage._CandidatePanel`·`candidateContext` 제거, 인벤토리 `확인 필요` 표시(FD-146 결과), `_handoffCandidate` 인벤토리·학생 분기 제거 | `inventory_page.dart`, `student_page.dart`, `app_shell.dart` | S | g5, FD-120 |
| 9 | **FE8-f3 홈 팝업 연결** | 기존 FE8-f의 팝업 부분: 타일 → 컨트롤러 시작(또는 스캔 탭 이동), 전술대항전 타일 처리 | `home_page.dart` 등(A 보고서) | M | f1, g1, FD-140, FD-150 |
| B1 | **FB-10 스캐너 프로토콜 추가**(스캐너 워크플로 소유, additive) | `scanner.session.pause/resume` + `phase: paused`(reason `user/input_detected/target_minimized`), Esc → cancel, 학생 폴백 필드 crop + 역산값(evidence details), 인벤토리 entry별 confidence·note·slot 위치, entry 단위 승인·부분 commit 의미, 진행 중 후보·feedback 스트리밍, `recognition.status`에 정답 샘플 수, (선택) 다중 프로필 세션 | 백엔드·Dart 검증·mock·contracts | L | FD-142, FD-145, FD-146, FD-156, D21 개정 |
| B2 | **FB-2 확장** | 이력 레코드에 `scan_kind`·`inventory_scan_profile`, 종류별·아이템별 마지막 스캔 조회, diff 0 적용도 시각 기록 | 백엔드·repository | M | FD-041, FD-147 |

- 순서 메모:
  - f1 → (f2, g1) → g2 → g4가 학생 흐름의 최소 경로다. 데이터 공백은 "—"·숨김으로 처리하므로 FB-10/B2 없이 시작할 수 있다.
  - g3·g5는 FD-141/146 답과 FB-10 일부가 있어야 의미가 있다.
  - 동결 창이 필요한 파일은 f1(`scan_page.dart`)과 g3(`scan_companion_dock.dart`) 둘뿐이다. 나머지는 신규 파일과 `app_shell.dart` 최소 diff다.

### 9.3 결정 대장 추가·갱신 초안

| 새/갱신 FD | 질문 | 선택지 | 권장안 | 상태(열림/워커 재량/확정 근거) | 막는 slice |
|---|---|---|---|---|---|
| FD-120 갱신 | 홈 스캔 팝업이 생긴 뒤 스캔 탭에는 무엇을 남기는가? | — | 시안(Scan 6장)대로: 스캔 탭 = 준비 상태·최근(앱 실행 기록)·고르기(다중 선택·종류별 마지막 스캔)·진행·결과 검토. 창 선택은 홈 패널. 인벤토리 `_CandidatePanel`·학생 탭 후보 인계는 스캔 탭 검토로 이관 | 확정(FD-001 적용, 2026-10-06 시안). 팝업과의 관계만 FD-140 | 풀림: FE6-a, FE8-g |
| FD-121 갱신 | 스캔 시작 뒤 진행·후보 검토는 어디서 보이는가? | — | 학생 = 백그라운드(진행 창 없음, 머리글 칩 + 스캔 탭 진행 화면), 아이템 = 게임 옆 진행 창. 끝나면 스캔 탭 결과 검토(`onCandidateHandoff` 인계 폐기, 전술은 FE9-c) | 확정(FD-001 적용, Scan-Student-Run·Scan-Item-Run) | FE8-g2, FE8-g3 |
| FD-122 갱신 → FD-150 | (FD-150 참조) | | | | |
| FD-123 갱신 → FD-151 | (FD-151 참조) | | | | |
| FD-140 | 홈 스캔 팝업과 스캔 탭 고르기는 어떤 관계인가? | (a) 팝업 타일 = 그 종류 하나 바로 시작(학생은 머문 자리에서 백그라운드, 아이템은 진행 창), 검토는 스캔 탭. 스캔 탭 = 다중 선택·마지막 스캔·안내가 있는 본 화면. 둘 다 같은 컨트롤러 (b) 팝업 타일 = 스캔 탭 고르기로 이동 + 그 종류 미리 선택(시작은 스캔 탭) (c) 팝업 폐기, 홈 `스캔` 버튼 = 스캔 탭 이동 | (a). 팝업 (i) "열어 둔 뒤 누르십시오"와 맞고 홈에서 한 번에 시작된다. 전제조건·추정치는 컨트롤러 한 곳에 있다 | 열림 | FE8-g1, FE8-f3 |
| FD-141 | 아이템 진행 창은 플래너 창을 줄여 붙이는가(현행 `dockBeside`), 별도 작은 창인가? | (a) 현행 `dockBeside`/`restore` 재사용: 플래너 창이 1:2 진행 창이 되고 끝나면 복원 (b) Windows 러너에 별도 top-level 창 추가(플래너는 뒤에 그대로) (c) 진행 창 없이 게임 창만 앞으로, 진행은 플래너(뒤) | (a). 이미 동작하는 네이티브 경로이고 포그라운드 스캔 동안 플래너를 쓸 수 없는 점은 시안과 같다. 시안 그림의 "플래너 뒤로 감"은 "진행 창으로 바뀜"으로 해석 | 열림(시안 그림은 창 2개) | FE8-g3 |
| FD-142 | 일시정지·이어서(버튼, 최소화, 입력 감지)를 지원하는가? | (a) 스캐너 워크플로에 `scanner.session.pause/resume` + `paused` 이벤트(reason) 추가, D21을 "입력 감지 → 일시정지 → 사용자 이어서"로 개정, Esc = 중지 (b) 일시정지 없음: 버튼 숨기고 입력 감지는 D21(재시도 → partial), 최소화는 실패로 끝남 (c) 프론트 일시정지 = 중지 후 같은 종류 새 세션(읽은 칸 유지 안 됨) | (a). 시안 3장이 일관되게 요구하고 "읽은 칸은 남습니다"는 같은 세션 안에서만 지킬 수 있다. FB-10 전에는 (b)로 동작 | 열림(D21 확정 결정 개정) | FB-10, FE8-g2·g3 일시정지 부분 |
| FD-143 | 아이템 여러 종류를 한 번에 스캔할 때 세션을 어떻게 돌리는가? | (a) 프론트 큐: 종류마다 세션을 차례로, 진행 창은 유지, 검토는 합쳐 표시 (b) `scanner.session.start`에 `inventory_scan_profiles` 목록 additive | (a). 프로토콜 변경 없이 되고 종류별 진행·후보 commit이 이미 세션 단위다. 종류 사이 전환 지연이 크면 (b) | 워커 재량 | FE8-g3 |
| FD-144 | 학생 검토 분류와 "계산 일치 일괄 적용"은 어떻게 하는가? | (a) 프론트 순차: 학생마다 review(approve) → commit, 응답 revision을 다음 expected로, 실패하면 멈추고 남은 후보 유지 (b) 백엔드 일괄 commit 원자 처리 | (a). 분류 = 확인 필요(`_hasProblem`) / 새 학생(확정값 없음, 재검증 먼저) / 바뀐 학생(diff 있음 + 문제 없음 + 계산 delta 0) / 그대로(diff 없음, 적용 불필요) | 워커 재량 | FE8-g4 |
| FD-145 | 학생 폴백 캡처 crop과 "계산 역산" 값은 어디서 오는가? | (a) 스캐너 워크플로가 폴백으로 넘어간 필드만 evidence details에 crop(png base64)·역산값을 additive로 추가하고 적용·폐기 시 삭제(시안 각주), 프론트는 있으면 표시 (b) 이번 범위 제외(카드에 판독값·신뢰도만) | (a). 시안이 보관 정책까지 적어 두었다. 진단 JSON의 `images_included:false`는 유지 | 워커 재량(백엔드 요청) | FB-10, (FE8-g4는 막지 않음) |
| FD-146 | 아이템 칸별 승인·부분 적용과 남은 칸의 "확인 필요" 표시는 어떻게 저장하는가? | (a) 백엔드: commit에 승인 entry 목록(또는 review payload에서 제외 = 이전 값 유지 의미 명시) + 승인 entry만 정답 샘플 + repository entry별 `needs_review` 영속 표시 (b) 부분 적용은 하되 `확인 필요`는 앱 실행 동안만(보류 후보에서 유도) (c) 현행처럼 후보 전체 승인만 | (a). 시안 문구 "인벤토리에 이전 값으로 남고 '확인 필요'로 표시"는 영속 표시로 읽힌다. 인벤토리 탭(FE6-a)도 같은 필드를 그린다 | 열림 | FB-10, FE8-g5, FE6-a |
| FD-147 | "종류별 마지막 스캔"·"아이템별 n일 전 스캔"은 어디서 오는가? | (a) FD-041 이력 레코드에 `scan_kind`·`inventory_scan_profile`을 더하고 종류별·resource_key별 최신 scan 커밋 시각을 조회. 전부 "그대로"인 적용도 시각 기록 (b) 세션 완료 시각(적용 여부 무관)을 프로필 메타에 종류별로 저장 | (a). FB-2 하나로 계정 메타 줄·통계·인벤토리와 출처가 같아진다. 표시 규칙: 막대 = 경과일/14(상한), `최근` ≤ 7일, `오래됨` > 7일, `스캔 없음` | 워커 재량(FD-041 확정 후) | FB-2, FE8-g1(막대는 FB-2 전 "—") |
| FD-148 | 머리글 연결 칩 자리에 스캔 진행을 어떻게 겹쳐 보이는가? | — | 우선순위 백엔드 끊김(빨강) > 스캔 진행/일시정지(분홍 `학생 스캔 34 / 128`, 일시정지는 wn) > 게임 창 연결(녹/회). 누르면 스캔 탭 진행·검토. 탭 `스캔`에 분홍 점. 완료 시 앱 안 토스트(누르면 검토) | 워커 재량(FD-117 확장) | FE8-f2 |
| FD-149 | 스캔 탭 "최근 스캔"은 앱 실행 기록인가, 영속 기록인가? | (a) 앱 실행 기록(현행 `ScannerRecentSummary`, 8건) + 시작 시각·종류 라벨·확정 여부 필드 추가 (b) 영속 세션 기록 | (a). 시안 각주가 명시한다. 날짜 예시는 표본 값 | 워커 재량 | FE8-g1 |
| FD-150 | 홈 팝업의 `전술대항전(준비 중)` 타일은? (FD-122 개정) | (a) 제거 (b) 전술대항전 탭으로 이동하는 링크 타일(로비 스캔은 탭 안, FE9-c) (c) FD-122대로 FE9-c 후 팝업에서 로비 스캔 시작 | (b). 스캔 탭 노트 "전술대항전 탭에서만"을 지키면서 찾기 쉬움은 남는다 | 워커 재량 | FE8-f3 |
| FD-151 | 선물(presents) 스캔은 어디서 하는가? (FD-123 개정) | (a) 스캔 탭 아이템 줄 7번째 타일(타일 폭 축소)과 팝업 "기타" 줄 추가 (b) 이번 범위 제외(enum·백엔드는 유지, UI 없음) | (a). 1080에서 활성 프로필이라(O0-6) 기능을 잃지 않는다. 두 시안 모두 생략했으므로 확인 필요 | 열림 | FE8-g1, FE8-f3 |
| FD-152 | 시안에 없는 학생 검토 기능(`화면 확인` 표시, 다른 의상 인연 랭크 입력, 진단 JSON 추출)은 어디에 두는가? | — | `화면 확인` = S3 폴백 카드와 값 주석 옆 토글(README 학습 규칙 유지, 고치지 않은 값은 학습 안 함). 인연 랭크 = 해당 학생 S3에 입력 줄. 진단 JSON = 개발 상태 패널 | 워커 재량 | FE8-g4 |
| FD-153 | 아이템 검토에서 미식별(identity) 칸은 어떻게 보이는가? | — | `확인 필요` 칸 변형(아이콘 `?` + 호박색 테두리). 선택하면 S3에 기존 `ScanInventoryIdentityReview`(1 슬롯)를 그대로 마운트(파일 수정 없음). "그리드 스캔은 캡처를 남기지 않습니다" 문구는 미식별 칸에서는 숨김 | 워커 재량 | FE8-g5 |
| FD-154 | 진행 추정치(`약 8분`, `약 58칸`, `남은 시간`, 학생 total)는 무엇으로 계산하는가? | — | 칸 수 = 카탈로그 `profileId` 개수, 학생 total = `progress.total`이 있으면 그것, 없으면 보유 수에 "약"을 붙임, 시간 = 종류별 기본 상수 → 진행 중에는 실측 속도로 갱신, 모르면 숨김 | 워커 재량 | FE8-g1, FE8-g2 |
| FD-155 | 스캔 탭의 미연결 상태와 `게임 창 다시 선택`은? | — | 미연결이면 시작 버튼 비활성 + S3 자리에 홈과 같은 `ConnectTargetPanel`(오른쪽 부착) 표시. `게임 창 다시 선택`도 같은 패널. 연결 상태는 FE8-d 전역 `connectedTarget` | 워커 재량(FD-116 확정 후) | FE8-g1 |
| FD-156 | 진행 중 실시간 정보(지금 읽는 학생 값, 방금 읽은 학생 diff, 아이템 NOW READING·최근 기록)는 어디서 오는가? | (a) 학생·종류 단위 후보를 진행 중에 바로 `candidate` 이벤트로 내보내고 인벤토리 `feedback`에 아이템 id·수량을 넣도록 스캐너 워크플로에 요청, 프론트는 받은 만큼 계산 (b) 끝나기 전에는 진행 수치만 | (a). 이벤트가 오기 전에는 (b)처럼 숨김. mock은 진행 중 후보 스트리밍으로 확장 | 워커 재량(백엔드 요청) | FB-10, FE8-g2·g3 일부 |

### 9.4 사용자 확인 질문 묶음
1. (FD-140) 홈 스캔 팝업의 타일은 바로 스캔을 시작하는가, 스캔 탭으로 넘겨 고르게 하는가?
2. (FD-141) 아이템 진행 창은 지금처럼 플래너 창이 작아져서 게임 옆에 붙는 것으로 충분한가, 플래너와 별개인 작은 창이어야 하는가?
3. (FD-142) 일시정지를 백엔드에 추가하고, 확정된 D21(입력 감지 → 재시도 후 partial)을 "입력 감지 → 일시정지 → 이어서"로 바꾸는가?
4. (FD-146) "확인 필요"로 남긴 아이템 칸 표시는 앱을 다시 켜도 인벤토리에 남아야 하는가?
5. (FD-151) 선물 스캔이 두 시안 모두에 없다. 스캔 탭에 넣는가, 이번 범위에서 빼는가?
