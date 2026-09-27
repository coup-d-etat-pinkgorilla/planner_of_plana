---
title: "Scanner Structural Consolidation Workflow"
summary: "F0~F12 완료 후 학생·재고 스캐너의 계약 드리프트, 끝 판정 약점, 구조 결합, 임계값 산재를 동작 보존 원칙으로 정리하는 C0~C7 실행 계약입니다."
topics: [workflow, architecture, migration, data]
sources:
  - id: restoration
    type: file
    path: almanac/workflows/scanner-fallback-restoration-workflow.md
  - id: student-workflow
    type: file
    path: almanac/workflows/student-scan-validation-workflow.md
  - id: boundaries
    type: file
    path: almanac/architecture/runtime-boundaries.md
  - id: catalog-order
    type: file
    path: almanac/architecture/inventory-catalog-order.md
  - id: matchers
    type: file
    path: backend/core/scanner_matchers.py
  - id: session
    type: file
    path: backend/core/scanner_session.py
  - id: navigation
    type: file
    path: backend/core/inventory_navigation.py
  - id: detail
    type: file
    path: backend/core/inventory_detail_recovery.py
  - id: schema
    type: file
    path: contracts/scanner-protocol-v1.schema.json
  - id: status
    type: file
    path: almanac/workflows/scanner-structural-consolidation-status.md
---

# Scanner Structural Consolidation Workflow

## 목적과 배경

2026-09-23 학생 스캔·재고 그리드 스캔 코드 방향성 리뷰 결과, **정책과 안전 설계는 옳으나
구현이 F-gate 단위로 누적되며 protocol·module·threshold 경계가 느슨해지고 있다**고 판정했다.
이 워크플로는 F0~F12의 기능을 유지한 채 그 경계를 다시 조이는 후속 작업이다. 새 인식 기능을
추가하지 않으며, P0~P6·F0~F12·D1~D3을 다시 열지 않는다. [@restoration] [@student-workflow]

작업자는 Claude Opus 세션이다. 한 세션은 한 phase(또는 한 phase의 명시된 sub-slice)만 수행한다.
실제 완료 사실·검증 수치·다음 행동은 [상태 문서](scanner-structural-consolidation-status)에만
기록하고, 이 문서는 순서와 gate만 소유한다. [@status]

## 리뷰에서 확정된 발견 (근거)

| ID | 발견 | 근거 |
|---|---|---|
| X01 | evidence `status:"shadow"`가 스키마 enum에 없음 | `scanner_session.py:17`, `scanner_matchers.py:946-966`, `schema:49` |
| X02 | `scanner.session.start`가 `additionalProperties:false`인데 `inventory_scan_profile` 미정의 | `scanner_protocol_v1.py:51-63`, `schema:118` |
| X03 | 인벤토리 프로필 집합이 세 곳에 복제 | `scanner_session.py:186-191`, `inventory_catalog.py CATALOG`, `inventory_navigation.py:11 ITEM_FILTERS` |
| X04 | evidence 필드 `entries[N]`이 슬롯 evidence는 observed_slot, zero-fill은 리스트 인덱스 | `scanner_matchers.py:1365-1366` vs `:1429` |
| X05 | 엔트리 `profile_id` 값이 계정이 아니라 스캔 프로필 | `scanner_matchers.py:1360` |
| X06 | 스캐너 출력에 `catalog_revision` 없음 | `scanner_matchers.py:1360`, [@catalog-order] |
| X07 | `verified_tail_residual` 뒤 무이동 재확인 없이 `coverage_complete=True` | `inventory_navigation.py:194-195`, `scanner_matchers.py:1389-1393` |
| X08 | `verified_no_motion` 드래그 시작점 `(.78,.75)`가 그리드 내부 → 탭 오인 시 zero-fill 위험 | `inventory_navigation.py:177-186` |
| X09 | 아이템 정렬 `sort_rule_check`를 확인 전 무조건 클릭 | `inventory_navigation.py:119` |
| X10 | 안전 중단 후 "첫 페이지 복귀"가 문서에만 있고 코드에 없음 | F10 결과 문서 vs `inventory_navigation.py` |
| X11 | `InventoryMatcherAdapter.__call__` 244줄·상태 플래그 9개, `_scan_current` 218줄, `_scan_full` 128줄 | `scanner_matchers.py:1216`, `:760`, `:1069` |
| X12 | `target` dict가 `_scanner_cancel/_scanner_cleanup/_scanner_scroll_point/_inventory_profile_verified/_window_identity` 컨텍스트 백 | 전역 |
| X13 | 예외 `details['inventory_restored']` 사후 주입 후 호출자 분기 | `inventory_detail_recovery.py:218`, `scanner_matchers.py:1320` |
| X14 | `getattr(menu, f"capture_{kind}_menu")` 문자열 디스패치, `inspect.signature` validator 판별, `progress.supports_feedback` 함수 속성 | `student_panel_recovery.py:44-62`, `scanner_session.py:141-146, 530` |
| X15 | 재고 모듈이 `student_weapon_recognizer._normalized_correlation`(private) import; 같은 이름이 equipment에 다른 의미로 별도 존재 | `inventory_navigation.py:8`, `inventory_detail_recovery.py:8`, `student_equipment_recognizer.py:48-61` |
| X16 | `windows_scanner_adapter`(하위)가 `scanner_matchers`(상위) import | `windows_scanner_adapter.py:13` |
| X17 | 임계값 전부 코드 리터럴, 이름·중앙 테이블 없음 | 학생 0.55/0.58/0.65/0.38/0.49/0.57…, 재고 .85/.68/.88/.94/.975/.995/.985/.97… |
| X18 | 재고 상세 복구가 `StudentPanelRecovery` 계약의 별도 복사본 | `inventory_detail_recovery.py` vs `student_panel_recovery.py` |
| X19 | 숫자 판독 파이프라인 3개 독립(그리드/상세/학생) → 재고 수량은 사용자 정답·세션 보정 미적용 | `scanner_matchers.py:434-478`, `inventory_detail_recovery.py:88-118`, `studio_numeric_bank.py` |
| X20 | 행 overlap이 identity 없이 24차원 RGB 히스토그램만 사용 → C5b에서 `measure_shift`(픽셀 이동 측정)로 대체됨. 남은 문제는 누적 offset 드리프트를 anchor 클릭+21회 탐색으로 보정하는 비용(C5e-1) | `inventory_navigation.py:36-46, 142-150` (구), `:272-305` (신) |
| X21 | source 이름 오해: `detail_template_fallback`은 same-crop 재매칭, 무이동 종료도 `verified_row_overlap` | `scanner_matchers.py:1298-1303, 1399-1400` |
| X22 | 인연 whole-bank 0.38/0.005 → 사실상 무조건 확정 | `student_scan_recognizer.py:820` |
| X23 | D2처럼 봉인되지 않은 특수 사례 축적: `4→0` 보정, 무기 0.57, 무기 whole-bank 0.49, 로비 3px, `EQUIPMENT_SLOT_*` 2560 절대좌표 | `student_potential_recognizer.py:256-260`, `student_scan_recognizer.py:897-933`, `student_equipment_recognizer.py:25-27` |
| X24 | F9/F10 모듈 세미콜론 압축 한 줄 스타일 | `inventory_navigation.py`, `inventory_detail_recovery.py` |
| X25 | 검증 표본이 한 계정(feedback1) 중심 | F0/F12 결과 문서 |

## 불변식 (이 워크플로 동안 추가되는 것)

기존 restoration 워크플로의 불변식 전부를 유지하고 아래를 추가한다. [@restoration]

- **동작 보존 phase(C3, C4, C6)는 golden diff 0건이 완료 조건이다.** C0에서 고정한 replay 입력에 대해
  후보 JSON(evidence 순서 포함)이 바이트 단위로 동일해야 한다. 차이가 나면 의도된 변경인지 status에
  사유를 적고 golden을 갱신하되, 같은 phase에서 동작 변경과 구조 변경을 섞지 않는다.
- **동작 변경 phase(C1 일부, C2, C5, C7)는 parity fixture → 구현 → 실게임 1280 확인 순서를 지킨다.**
  합성 프레임 통과를 실게임 검증으로 표기하지 않는다.
- 임계값 숫자는 C4 전까지 바꾸지 않는다. C4는 값을 옮기기만 하고, 값 변경은 C7에서만 D-결정으로 한다.
- 스키마 변경은 additive(enum 추가, optional 필드 추가)만 v1에서 허용한다. 기존 필드 의미 변경·이름 변경은
  v2 또는 병행 필드로 하고 구 진단 JSON 호환 테스트를 유지한다.
- Flutter 쪽은 protocol/decoder/mock/localization 동기화 외에는 손대지 않는다. UI 작업은 별도 워크플로다.
  **예외(2026-09-27 사용자 승인)**: C5e-6e 리뷰 화면의 미식별 슬롯 identity 지정 UI는 이 워크플로 안에서 한다.
- `../v6` import 금지, Qt/Tk 반입 금지, 자동 커밋 금지, 미확정 0 채움 금지는 그대로다.

## 실행 순서와 gate

순서는 `C0 → C1 → C2 → C3 → C4 → C5 → C6 → C7`이다. C1·C2가 앞선 이유는 비용이 낮고 사용자 데이터
오답(zero-fill)에 직접 닿기 때문이다. C3 이후는 구조 작업이며 C2까지의 동작을 golden으로 고정한 뒤 시작한다.

### C0 — 기준선·golden 고정

- 전체 테스트를 새로 실행해 수치를 기록한다(과거 533/400을 재사용하지 않는다).
- `debug/scanner_f12_replay`와 `debug/scanner_f*_live`의 기존 프레임으로 학생 단일·전체·다중 폼, 재고
  item/equipment/gift/student_elephs 각 1개 이상의 **replay 입력 → 후보 JSON** golden을
  `backend/tests/fixtures/scanner_consolidation/golden/`에 고정한다. 프레임이 없는 조합은 status에 결손으로 적는다.
- golden 비교 테스트 `test_scanner_consolidation_golden.py`를 추가한다. evidence 배열 순서까지 비교한다.
- 상태 문서 `almanac/workflows/scanner-structural-consolidation-status.md`를 생성한다.
- 완료: golden 세트·비교 테스트·상태 문서가 있고, 현재 코드로 golden 테스트가 통과한다.

### C1 — 계약 드리프트·이름 정리 (X01~X06, X21)

- X01: `fieldEvidence.status` enum에 `shadow` 추가. 스키마 검증 테스트가 shadow evidence를 포함한 실제 후보를 통과시키는지 확인.
- X02: `scanner.session.start`에 `inventory_scan_profile` optional 정의. enum은 X03의 단일 소스에서 생성.
- X03: 프로필 집합을 `inventory_catalog.CATALOG` 파생 하나로 통일. `session.start`·`ITEM_FILTERS`는 그것을 import.
- X04: zero-fill evidence 필드를 `entries[<observed_slot 없음>]`이 아닌 명시 형태로 바꾼다. 권장:
  `zero_fill[<resource_key>].quantity`. Flutter decoder/mock 동기화.
- X05: 엔트리에 `inventory_scan_profile` 필드를 **추가**하고 `profile_id`는 한 버전 동안 병행 유지 후 status에 제거 시점을 적는다.
- X06: 후보 payload에 `catalog_revision`을 실어 보내고 repository commit 경로가 이를 검증하도록 한다(불일치 시 commit 거부, 사유 evidence).
- X21: source 이름을 사실대로 바꾼다(`detail_template_fallback` → `grid_same_crop_rematch`, 무이동 종료 → `verified_no_motion`).
  구 진단 JSON 호환 매핑 테이블과 테스트를 유지한다.
- 완료: 스키마 테스트가 실제 후보 샘플 전체를 통과, Flutter decoder 테스트 통과, golden은 의도된 필드 추가/이름 변경만 diff.

### C2 — 재고 끝 판정·입력 보강 (X07~X10)

- X07: `verified_tail_residual` 뒤 **무이동 재확인 1회**를 추가한다. 재확인 실패면 `partial`, zero-fill 금지.
- X08: 드래그 시작·종료점을 그리드 밖(스크롤 트랙 또는 빈 여백)으로 옮긴다. 좌표는 region 자산에 `scroll_track` 컨트롤로 두고
  코드 리터럴을 제거한다. 실게임 1280에서 item/equipment/gift 세 프로필 tail까지 확인한다.
  **결정 필요(D4)**: 게임 UI에 안전한 드래그 영역이 없으면 무이동 종료를 `terminal`이 아닌 `review_required`로 강등한다.
- X09: `sort_rule_check`를 상태 확인 후 꺼져 있을 때만 클릭한다(F6 체크박스 정책과 동일).
- X10: `inventory_scroll_unverified` 안전 중단 후 첫 페이지 복귀를 구현하거나, 구현하지 않기로 하면 F10 결과 문서의 문구를 수정한다.
- 클릭 허용 컨트롤 이름 allowlist를 코드에 둔다(region 자산만으로 새 버튼을 누를 수 없게).
- 완료: tail 부분 소비·탭 오인·정렬 이미 켜짐·중단 후 복귀 tests와 실게임 1280 세 프로필 정상/취소 통과. C2 완료 후 golden 재고정.

### C3 — 오케스트레이터 분해 (X11~X14, 동작 보존)

- `InventoryMatcherAdapter.__call__`을 `read_page(frame) → PageResult`, `apply_profile_gate(PageResult) → GateResult`,
  `finalize(entries, coverage) → CandidatePayload` 순수 함수로 나눈다. 상태 플래그는 typed dataclass로 모은다.
- `target` 컨텍스트 백을 `ScanContext` frozen dataclass로 대체한다. `_scanner_*` 키는 전부 필드가 된다. 어댑터 경계에서만 dict로 변환.
- 예외 사후 주입(X13)을 `DetailRecoveryResult(restored: bool, ...)` 반환으로 바꾼다.
- `getattr` 문자열 디스패치를 `PanelMenu` Protocol(`capture/recapture/close`)로, validator 인자 판별을 단일 시그니처로,
  `progress.supports_feedback`를 `ProgressSink` Protocol 속성으로 바꾼다.
- `_scan_current`를 `identify → basic_reads → detail_fallbacks → assemble`로, `_scan_full`을 순회 제어와 학생 1명 처리로 나눈다.
- 완료: golden diff 0건, 전체 테스트 통과, 최대 함수 길이 80줄 이하(status에 상위 5개 함수 길이 기록).

### C4 — 임계값 레지스트리 (X17, 동작 보존)

- `backend/core/recognition_thresholds.py`에 `field × source × native_resolution → (score, margin)` 테이블을 만든다.
  각 항목에 이름, 도입 phase(F/S/D 번호), 근거 문서 링크를 붙인다.
- recognizer·navigation·detail의 리터럴을 전부 레지스트리 참조로 바꾼다. **값은 바꾸지 않는다.**
- "같은 프레임" 임계 세 가지(.995/.985/.97)는 각각 이름을 붙여 왜 다른지 status에 적는다. 통일은 C7 결정.
- 완료: 인식 코드에서 0.xx 리터럴 grep 0건(허용 목록 명시), golden diff 0건.

### C5 — 인식 공통화 (X15, X18~X20, 동작 변경 가능)

C5a·C5b는 2026-09-26 완료(status 참조). C5b가 남긴 방식 — 프로필 스캔에서 **모든 슬롯을 상세 패널로 읽고**, 슬롯마다
원선택으로 복귀(1→N→1)하며, 스크롤 후 anchor 클릭+21회 탐색으로 위상을 맞추는 것 — 은 정확하지만 첫 스캔이 장비 105칸에
약 10분으로, 이 프로젝트의 그리드 스캔 방법론(한 페이지를 한 번에 읽는 batch, 상세는 예외 경로)에서 벗어난다.
2026-09-27 사용자 지시로 기록 프레임 실험(E1/E2, `docs/migration/scanner-consolidation/c5e-experiments-2026-09-27.md`)을
근거로 C5c 이후를 아래와 같이 재정의한다. **C5b의 정확도(45/45, 56+19, 95종)와 안전 규칙은 유지한 채 속도 경로를 복원**하는 것이 목표다.

| Slice | 항목 | 성격 |
|---|---|---|
| C5c | X15 이미지 유틸 공통화 — `recognition_image_ops.py`, `_normalized_correlation` 두 변형을 `ncc_signed_lanczos`/`ncc_unit_bilinear`로 분리, private import 제거. **E2의 채널별 NCC(아이콘 영역)도 여기 둔다** | 동작 보존 |
| C5d | X18 `InventoryDetailRecovery`를 `StudentPanelRecovery` 계약에 정렬 + **배치 선택**: 슬롯별 원선택 복귀를 제거하고 1→2→…→N 순차 선택, baseline은 마지막 선택 프레임으로 갱신(`same_grid`의 ignore에 이전/현재 선택 포함), 페이지 끝 또는 실패 시점에 **한 번** 검증 복귀. F9 (a) 클릭 전 보이는 선택, (b) 클릭 전후 같은 격자는 그대로. 슬롯당 재시도 ≤ 2, 선택 미확인이면 그 슬롯 partial·입력 중단 | 동작 변경 |
| C5e-1 | **결정론적 스크롤 + gutter 위상 검증**(E1·E6). 스크롤은 `press → priming 8px → k·itemSize·s 이동(2~3 스텝) → 0.2s 정지 → release`, **k = 완전히 보이는 행 수 − 1(한 행 겹침; 720p 아이템·장비 모두 4행)** — 겹친 행은 앞 페이지 판독과 identity 대조로 이동량을 교차 확인(관성 0, 이동량 = 요청량, 위상 보존 ≤2px). 릴리스 후 즉시 캡처(고정 0.5s 대기 제거). gutter 위상(viewport 행별 gutter-회색 198~215 비율 ≥ .8 band, 길이 ≥ 3px, 경계 band 제외, band 끝+3 = 타일 상단)은 **검증**으로: 예상 위상과 3px 초과 차이면 재측정 후 실제 값 사용. `measure_shift`는 실제 이동량·끝 판정용 유지(요청 < 관측이면 끝). `_align_to_anchor`·anchor 클릭 제거. 첫 페이지 복귀는 휠 up N tick(≤10) 후 위상 확인. viewport 사각형은 spec clip 범위(684/872 units)·softness 12 units에서 파생, 페이드 구간에 걸친 행은 다음 페이지로. 레지스트리 신규: `inventory.scroll.priming_px`(8), `inventory.scroll.hold_s`(.2), `inventory.scroll.phase_tolerance_px`(3). 위상 검출 실패(band < 2개)면 `inventory_scroll_unverified`. **포그라운드 유지(사용자 결정 2026-09-27)**: 그리드 스캔은 스캔 동안 게임 창을 계속 앞에 둔다(입력 버스트로 띄웠다 숨기지 않음). 백그라운드·최소화 입력은 불가(확정). 사용자 입력 충돌은 D21 | 동작 변경 |
| C5e-2 | **타일 은행 fast path 복원**: `detail_required`를 "은행 출처가 타일 crop이고 M4 score ≥ `inventory.tile_bank.score`(.90) & margin ≥ `.margin`(.015)이면 상세 생략"으로 완화(`scanner_matchers.py:1419, 1460`). 상세 확정 (identity, 타일 crop, 해상도)를 **session bank**에 넣되 영구 저장은 사용자 승인 슬롯만(D1). 원화 아이콘 템플릿은 후순위로 강등(제거는 C7 결정). 페이지 진입 시 visible 슬롯 전부를 먼저 매칭하고 모호 슬롯만 C5d 배치 선택으로 넘긴다 | 동작 변경 |
| C5e-3 | X19 수량을 `StudioNumericBank` 경로로(사용자 정답·세션 보정), `K` 축약 표기(C5-2) 처리. 기존 잉크마스크 경로는 parity 후 fallback. **synth seed 계층 추가**(D20/E5): 런타임 생성기가 KR 폰트로 만든 `x0-9K` 자릿수 템플릿을 최하위 우선순위로 공급, 프로필 gate(자릿수 top-1 ≥ .95) 통과 전에는 evidence만 기록 | 동작 변경 |
| C5e-4 | equipment identity: **상세 패널의 카테고리 라벨(11장) × `T#` 배지(10장)를 1차 키**로, 상세 아이콘은 보조. 그리드에서는 icon M4 + 타일 좌하단 `T#` 배지. 라벨·배지 템플릿은 아이템과 무관해 현재 보유분으로 전부 캡처되며 미보유 (카테고리,티어)도 확정된다. 조각·범용 설계도·강화석은 카탈로그 항목 추가 + 상세 이름 템플릿(보유분 캡처) — C5-1 결정 | 동작 변경 |
| C5e-5 | (선택, D12) 사용자 1280 프레임에서 추출한 타일 은행을 배포 asset으로 export하는 도구. 다른 PC 유효성은 X25 표본 확보 후 판단 | 도구 |
| C5f | **학생 스캔 백그라운드 탐색 (게이트 통과 2026-09-27)**: `probe_background_key.py` 2회 — 다른 창 포그라운드 유지(`0x1b0bb2` 불변), 프레임 41~47 % 변화 = 키 소비. 즉 Unity는 `WM_KEYDOWN/UP`을 백그라운드에서 처리하며 스스로 활성화하지 않는다(08-26 기록의 포그라운드 전환은 어댑터의 `_foreground()` 선행 호출이 원인). 구현: `press_key` 순서를 **PostMessage 키 → PrintWindow 프레임 변화(identity 또는 diff ≥ 2 %)로 소비 확인 → 미변화 시에만 포그라운드 SendInput**으로. 학생 전체 스캔의 좌우 이동·캡처·판독은 전부 백그라운드. **클릭이 필요한 폴백**(패널 열기/닫기, 상세 복구)만 `이전 포그라운드 HWND 기록 → 게임 포그라운드 → 클릭·판정 → 이전 창 복원(SetForegroundWindow, 실패 시 evidence)` 순서로 잠깐 띄웠다 되돌린다(사용자 결정). 재고 그리드 스캔에는 적용하지 않음(포그라운드 유지) | 동작 변경 |
| C5e-6 | **템플릿 합성 계층(synth tier)** — 런타임 생성기·로더·수량 seed·라벨링 폴백·E4 gate. 입력(명세·asset 팩·등급표)은 오케스트레이터가 확보 완료. 상세는 아래 "C5e-6 상세" 절의 6a~6f | 동작 변경·UI |

- 실측 근거(E1): gutter 위상은 세 프로필·28 페이지 프레임에서 pitch 101px, anchor 클릭 대비 ≤ 1.5px, 13~23 ms, 누적 없음.
  세로 gutter는 타일 사선 모서리 때문에 쓰지 않는다(x는 region 자산 고정).
- 실측 근거(E6, 실게임): 정지 후 릴리스 드래그는 관성 0·이동량 = 요청량 − 임계 초과 첫 move(→ priming으로 흡수), 4행 요청 시 위상 오차 ≤ 2px.
  스크롤바는 숨김·비활성(thumb 없음, 트랙 클릭 무반응)이라 쓰지 않는다. 휠 1 tick은 536~709px로 가변(관성)이라 페이지 이동에 쓰지 않고 맨 위 복귀에만 쓴다.
- 실측 근거(E2): 타일 crop 템플릿이면 현재 지표(M1)도 top-1 97~100%이나 margin .002~.006으로 `.03` gate를 못 넘긴다.
  채널별 NCC(아이콘 영역 x 12~88 %, y 6~76 %)는 tech notes 100 % / margin min .016, presents 100 % / .282, equipment 99.4 % / .003.
  M1 오답은 다른 학교(배경 지배), 그레이 NCC 오답은 같은 학교 다른 티어(색 손실) — 채널별 NCC만 둘 다 가른다.
- (C2에서 이관) 1행 미만 tail(C2-2)은 C5b `measure_shift`로 해결됐고 X07 무이동 재확인은 `tech-notes-full-c`에서 실게임 실행을 확인했다.
- 임계 신규 항목은 C4 레지스트리에 phase `C5e`, doc 링크로 등록한다. 기존 값은 바꾸지 않는다.
- 완료: 슬라이스별 parity fixture, 실게임 1280 재고 세 프로필 tail 도달, **첫 스캔 소요 시간**(장비 전체·기술 노트 전체)과
  **두 번째 스캔 소요 시간**(session/승인 은행 채워진 상태)을 status에 기록, 학생 단일 스캔 회귀, golden 재고정.
  C5e-2 완료 조건에 "상세 패널 클릭 0회인 슬롯 비율"을 포함한다.

#### C5e-6 상세 — 템플릿 합성 계층 (2026-09-27 확정)

**확보된 입력(수정 금지, 읽기 전용)**

| 입력 | 경로 | 내용 |
|---|---|---|
| 기하 명세 | `backend/assets/recognition/spec/ba-ui-template-spec-v1.json` | NGUI 2960×1440, `s = H / round(2960·H/W)`, 타일·상세·학생 위젯 기하, 아이콘 정합(`ICON_SCALE 1.06`, 오프셋 (+3.5, +1.2) units), `fonts` 블록(렌더 파라미터), `generator_outputs`, `validation` |
| 등급표 | `backend/assets/recognition/spec/item-rarity-v1.json` | `items[icon] → {id, rarity, category, name_kr…}`, `equipment[icon] → {id, rarity, category, tier, …}` (Steam ExcelDB) |
| asset 팩 | `backend/assets/recognition/asset_pack/` | `icons-01..03.zip`(멤버 `icons/{items,equipment}/<icon>.png`, 1268장), `sprites/*.png`(카드 배경 N/R/SR/SSR, `Card_Bg`, 설계도 배경 `Card_Item_Bg_C`, 선택선 등), `fonts/GyeonggiTitle-{Bold,Medium}.ttf`, `manifest.json`(sha256) |
| 사람용 명세 | `docs/migration/scanner-consolidation/template-generation-spec-2026-09-27.md` §3~§4(합성 알고리즘), §8(폰트), §9(팩) |
| 참조 구현 | `backend/tools/asset_spec/ba_tile_synth.py`(E4에서 검증된 타일 합성), `debug/scanner_c5e_experiments/e5_final.py`(글리프 렌더) | 런타임 코드가 아니다. 로직을 옮기되 import 하지 않는다 |

**원칙**: 합성 템플릿은 **은행의 최하위 계층**이다(`synth < session < user_confirmed`). 합성이 실물 캡처를 덮어쓰지 않고, 합성만으로 확정된 슬롯은 evidence에 `source=synth_bank`로 남긴다. 합성 실패(팩 손상·spec 불일치·폰트 없음)는 스캔 실패가 아니라 **합성 계층 비활성 + evidence 기록**이다.

| Sub-slice | 산출 | 계약 | 완료 조건 |
|---|---|---|---|
| **6a 생성기** `backend/core/recognition_synth.py` | `SynthTemplateSet` (grid tiles, detail icons, digit glyphs) | `synthesize(spec, pack, rarity, *, client="kr", window=(W,H), profile) -> SynthTemplateSet`; 순수 함수(입력 sha·창 크기·spec_version·profile이 같으면 바이트 동일). 그리드 타일: 카드 배경(등급) + 아이콘(1.06/오프셋) → 데이터셋 crop 규칙(`crop_like_dataset`)과 같은 창; 장비는 `Card_Item_Bg_C` + 아이콘; 상세 아이콘: 하늘색 배경 위 원화(551×435 / 649×512 units). 글리프: `x0-9K`를 Gyeonggi Bold, em `round(44·s)+1` ±1 후보 3벌, shear .10, 팽창 `.5·s/.4324`px. 렌더 시간은 status에 기록(목표: 1280 전 아이템 < 10 s, 캐시 적중 < 200 ms) | 단위 테스트: (1) 결정성(두 번 생성 sha 동일), (2) 1280×720에서 `debug/scanner_c5e_experiments` 실물 타일 100장 대비 M4 top-1 ≥ 99 %, 정답 점수 med ≥ .95(E4 재현), (3) 글리프 자릿수 top-1 ≥ .90(E5 재현, 실험용 분할 기준), (4) 팩 sha 불일치·아이콘 누락 시 `SynthUnavailable(reason)` |
| **6b 캐시·드리프트** | `%APPDATA%/…/recognition-synth-cache/<client>/<WxH>/<spec_version>/<pack_sha[:12]>/` + `index.json` | 캐시 키에 profile 포함. 스캔마다 **합성 vs 실물 점수 요약**(상세로 확정된 슬롯의 합성 M4 점수 분포 p10/med)을 `evidence.synth_drift`로 기록. p10이 레지스트리 `inventory.synth.drift_floor`(초기 .85) 아래로 2회 연속이면 그 프로필의 synth 계층을 세션 동안 끄고 `synth_drift_detected` 진단 발행(UI 패치 감지, D19) | 캐시 적중/미스 테스트, 손상 캐시 재생성 테스트, 드리프트 강등 테스트(합성 점수를 인위적으로 낮춘 fixture) |
| **6c 로더 계층** | `TemplateMatcher`/상세 recognizer/`StudioNumericBank`에 `synth` 계층 | `TemplateMatcher.match` 후보 순서: `user_confirmed` → `session` → `synth` → (기존 원화 `bundled`, 후순위). 같은 identity가 상위 계층에 있으면 synth 후보는 제외. `detail_required` 완화(C5e-2)의 "은행 출처가 타일 crop"에 `synth`를 포함하되 **D16 gate를 통과한 프로필만**(`inventory.synth.enabled_profiles`, 초기값: `tech_notes`·`presents`; `equipment`·학생 화면은 6f 통과 후). `StudioNumericBank`에 `add_synth_template` + 우선순위 최하위, 프로필 gate(`numeric.synth.enabled_profiles`, 초기 빈 집합) 통과 전에는 판정에 쓰지 않고 `evidence.numeric_synth_agree`만 기록 | golden: 기존 replay는 synth 계층이 꺼진 상태로 diff 0; 새 replay 시나리오 "은행 비어 있음 + synth 켜짐"에서 tech notes 45종 top-1과 상세 클릭 0회 슬롯 비율 기록 |
| **6d 상세 패널 폴백 순서 확정** | `inventory_detail_recovery` 판정 순서 문서화+구현 | 장비: 카테고리 라벨 × `T#` 배지(C5e-4) → 합성 상세 아이콘 → 이름 템플릿. 아이템: 캡처 상세 템플릿(user/session) → **합성 상세 아이콘(E3)** → 이름 템플릿 → 미식별(`partial`, 6e). 미보유 이벤트 선물·`_Piece`·강화석은 이 순서로 합성 단계에서 확정된다 | replay: 미보유 선물 프레임(있으면) 또는 합성 프레임 parity, 실게임 1280 presents tail |
| **6e 사용자 라벨링 폴백(UI 예외 허용, D15)** | protocol additive: `scanner.review.unresolved_slots`(슬롯 crop PNG base64, 후보 top-3 identity+score, 프로필) / `scanner.review.assign_identity`(slot, identity, `persist: bool`) | 리뷰 화면에 미식별 슬롯 카드: 후보 3개 + 카탈로그 검색. `persist=true`면 D1 규칙대로 사용자 승인 샘플로 저장(`scanner-samples/{account}/{WxH}`), 아니면 세션 은행. 자동 추정 금지, 지정 전까지 `partial` 유지 | Dart↔Python E2E, decoder/mock/localization 동기화, 스키마 additive 테스트, 구 진단 JSON 호환 |
| **6f E4 gate 확장(D16)** | `debug/scanner_c5e_gate/<profile>/` 프레임 + status 표 | 프로필별로 상세 확정 슬롯의 (실물 타일 vs 합성) M4 분포를 (실물 vs 실물) 분포와 비교. 합성 정답 점수 p10 ≥ 실물-실물 p10 − .03 이고 top-1 ≥ 99 %면 `inventory.synth.enabled_profiles`에 추가. equipment(`T#` 배지 결합), student 화면(장비 3칸·무기) 순. 미달 프로필은 상세 아이콘 합성만 | 실게임 1280 세 프로필 + 학생 단일 스캔, 수치 status 기록 |

**D18 후속(6c와 같은 세션 또는 C5e-4에서)**: `tech-notes-full-c` 슬롯 44의 정답을 `Item_Icon_SkillBook_Ultimate`로 고치고, 아이템 카탈로그의 `_Piece`/본체 identity를 `item-rarity-v1.json`의 id·icon 기준으로 재검한다(상세 템플릿 `inventory_detail_f9_manifest`의 `identity_value`가 어느 icon을 가리키는지 합성 상세 아이콘으로 교차 확인, 불일치는 표로 status에). golden 기대값은 사유와 함께 갱신한다.

**순서 권장**: 6a → 6b → 6c(+D18) → 6f(아이템 두 프로필) → 6d → 6e → 6f(장비·학생). 6a~6c는 한 세션에 가능하면 묶고, 6e는 Flutter 포함이라 별도 세션.

### C6 — 계층·위생 (X16, X24, 파일 분할, 동작 보존)

- `windows_scanner_adapter → scanner_matchers` 의존을 제거한다(필요한 타입은 `scanner_ports.py`로 내린다).
- 모듈 import 시점 전역(`CATALOG/BY_KEY/CATALOG_REVISION`)의 `student_meta` 의존을 lazy 또는 명시 초기화로 바꾼다.
- `scanner_matchers.py`를 `scanner_ports.py`, `student_matcher_adapter.py`, `inventory_matcher_adapter.py`,
  `slot_count_matcher.py`로 분할한다. 기존 import 경로는 한 버전 동안 re-export로 유지.
- 세미콜론 압축 스타일을 프로젝트 formatter로 정규화한다(포맷 전용 커밋, 로직 변경 0).
- 완료: import 그래프에 순환·역전 없음(간단한 스크립트로 검사), golden diff 0건, 전체 테스트 통과.

### C7 — 특수 사례·과적합 감사 (X22, X23, X25, 결정 gate)

- D2를 기준으로 X23의 각 특수 사례를 표로 만든다: 조건, 적용 범위(해상도/필드), 근거 표본, 별도 source/status 여부.
  각각 **D2 수준으로 봉인**(격리 조건·전용 source·비활성 스위치)하거나 **제거**를 사용자에게 결정 요청한다(D5~D9).
- X22: 인연 whole-bank 0.38/0.005를 다른 계정 표본으로 재측정한다. 표본이 없으면 `uncertain`으로 강등하는 안을 제시한다.
- X25: 최소 1개 다른 계정·다른 해상도(가능하면 2560 native) 표본을 확보해 학생 단일·재고 item 회귀를 돌린다.
  확보 불가 시 인지된 위험으로 status에 기록하고 워크플로를 닫는다.
- 완료: 특수 사례 표와 사용자 결정 기록, 재측정 결과, 전체 테스트·실게임 통과.

## 결정 gate

| ID | 결정 사항 | 기본안 | 시점 |
|---|---|---|---|
| D4 | 안전한 드래그 영역이 없을 때 무이동 종료 처리 | `review_required` 강등, zero-fill 금지 | C2 |
| D5~D9 | X23 특수 사례 각각 봉인/제거 | C7 표 제출 후 개별 결정 | C7 |
| D10 | 인연 whole-bank 임계 | 다른 계정 표본 전까지 `uncertain` 강등 | C7 |
| D11 | `profile_id` 엔트리 필드 제거 시점 | C1에서 병행, C6에서 제거 | C1/C6 |
| D12 | 타일 은행을 배포 asset으로 export할지 | X25 다른 PC 표본으로 전이 확인 전까지 session/승인 은행만 | C5e-5/C7 |
| D13 | 기존 원화 아이콘 템플릿(497종, `bundled`) 처리 | synth 계층 도입 후 `bundled`는 최후순위로 강등하고 C7에서 제거 결정(합성 상세 아이콘이 E3 통과로 대체) | C5e-6/C7 |
| D14 | 원화 템플릿 공급원 | **확정(2026-09-27)**: KR/Steam 클라이언트에서 추출한 `backend/assets/recognition/asset_pack/`(D17). JP·SchaleDB는 쓰지 않음 | C5e-6 |
| D19 | 템플릿 생성 시점 | **런타임 생성**: 아이콘 PNG 팩(`asset_pack/`, ~50 MB)+스프라이트+spec+등급표를 배포하고, 스캔 시 창 크기별로 합성해 디스크 캐시(키: client, WxH, spec_version, asset_pack_sha). 사전 생성 세트는 배포하지 않음. 합성 vs 실물 점수를 상시 기록해 UI 패치 감지 → 상세 경로 강등 + 갱신 알림 | C5e-6(b) |
| D20 | 텍스트 템플릿 생성 | **E5 완료(2026-09-27)**: KR 폰트(GyeonggiTitle Bold, Steam Preload 번들) 렌더링은 실물 글리프를 재현하지만 720p 문자열 margin이 얇아(min .001) **단독 키 금지**. 폰트 글리프는 `StudioNumericBank`의 **synth seed 계층**(synth < session < user)과 `x`/`K` 글리프 seed로만 쓴다. 프로필별 gate: 상세 확정 수량 대비 자릿수 top-1 ≥ .95. 상세 이름 라벨은 미실험 → 렌더링 안 함. 명세 `spec/template-generation-spec §8`, `ba-ui-template-spec-v1.json.fonts` | C5e-3/C5e-6a·6c |
| D18 | 카탈로그 identity 명명(`_Piece`) | 인벤토리 설계도 = `*_Piece`(EquipmentExcel). 카탈로그·상세 템플릿·evidence를 `_Piece` 기준으로 재명명, 구 이름은 호환 매핑. **실제 오답 확인(2026-09-27)**: `tech-notes-full-c` 슬롯 44는 상세 경로가 `SkillBook_Ultimate_Piece`(비의서 조각)로 확정했으나 실물 타일은 `SkillBook_Ultimate`(비의서, 합성 M4 .909 vs .484). 아이템 쪽도 `_Piece`/본체 템플릿 매핑을 ExcelDB id 기준으로 재검하고 golden 기대값을 수정 | C5e-4/C6 |
| D17 | 스캔 대상 클라이언트(KR/Steam)와 asset 출처(JP)의 아트 차이 처리 | 생성기에 클라이언트 인자, 기본은 스캔 대상과 같은 클라이언트의 asset; 불일치 항목은 E4 gate에서 partial. **폰트는 예외 없이 지역별**(E5: JP LINE Seed ≠ KR GyeonggiTitle) — asset 팩의 폰트는 스캔 대상 클라이언트에서 추출 | C5e-6 |
| D16 | 합성 그리드 타일을 은행에 넣는 조건 | E4에서 프로필별로 합성-실물 M4 점수가 실물-실물 분포 안에 들 때만. 미달 프로필은 상세 패널 템플릿만 합성 | C5e-6 |
| D15 | 미보유·미식별 아이템의 최종 폴백 | 사용자 라벨링(C5e-6e). 자동 추정 금지, partial 유지 | C5e-6 |
| D22 | 4:3 화면 비율 지원 | 게임 옵션은 4:3/16:9 둘뿐. 같은 창 폭이면 `s`·타일 크기·열 x·행 pitch가 16:9와 **동일**(실측 1280폭: pitch 101.5px, 6행+α 표시), 세로 앵커 요소만 이동. region 자산의 높이 비율 상수를 버리고 프리팹 앵커 트리에서 ROI를 계산하는 **레이아웃 리졸버**(`recognition_layout.py`, 입력: `spec/debug/*prefab*.json` 앵커)로 파생 — 16:9·4:3 모두 같은 데이터. 실게임 4:3 검증(E7)은 리졸버 구현 후 | **보류(사용자 결정 2026-09-27): 이 워크플로 완료 후 재검토** |
| D21 | 스캔 중 사용자 입력 충돌 처리 | 기본: 현재의 사후 검출(`input_focus_changed`·`_modifiers_clear`) 유지 + 저수준 훅으로 비주입 입력 감지 시 해당 스텝 `input_busy` 후 재시도(≤2회, 초과 시 `partial`). 입력 삼킴·입력 버스트·DLL 주입은 채택하지 않음 | C5e-1 |

기본안은 사용자가 달리 말하지 않으면 채택한다. D1~D3은 재질문하지 않는다.

## 세션 운영 규칙 (Opus 작업자)

1. 세션 시작 시 읽는 순서: `AGENTS.md` → `README.md` → 이 문서 → 상태 문서 → 해당 phase가 참조하는 코드.
2. 한 세션은 한 phase. phase가 크면 status에 sub-slice를 먼저 쪼개 적고 그중 하나만 한다.
3. 착수 전 status에 "진행 중: Cn/sub-slice, 시작 커밋 SHA"를 적는다. 종료 시 실행한 명령·수치·미검증 항목·다음 행동을 적는다.
4. 요구가 모호하면 AGENTS.md 규칙대로 파일을 수정하기 전에 질문한다. 단 이 문서의 기본안이 있는 항목은 질문 없이 기본안으로 진행한다.
5. 동작 보존 phase에서 golden diff가 생기면 멈추고 사유를 status에 적은 뒤 사용자에게 보고한다. 임의로 golden을 덮지 않는다.
6. 실게임 확인이 필요한 단계는 프레임을 `debug/scanner_c<n>_live/`에 저장하고 SHA를 status에 적는다.
7. 검증 명령은 restoration 워크플로와 같다: `cd backend; py -3.11 -m unittest discover -s tests -v`,
   `cd frontend; flutter analyze; flutter test`, `codealmanac validate`, `git diff --check`. protocol 변경 시 Dart↔Python E2E 포함.

## 세션 시작 프롬프트 템플릿

```
BA Planner v7 스캐너 구조 정리 작업이다. 다음 순서로 읽어라:
AGENTS.md → README.md → almanac/workflows/scanner-structural-consolidation-workflow.md
→ almanac/workflows/scanner-structural-consolidation-status.md.

이번 세션의 범위는 <Cn — 제목> (sub-slice: <있으면>)이다.
워크플로 문서의 해당 phase 항목과 불변식만 수행한다. 다른 phase의 항목은 발견해도 status의
"발견 사항"에 적기만 하고 손대지 않는다.

시작 전에 status에 진행 중 표시와 시작 SHA를 적고, 종료 시 실행 명령·수치·golden diff 결과·
미검증 항목·다음 행동을 적어라. 동작 보존 phase에서 golden diff가 0이 아니면 멈추고 보고하라.
모호한 요구는 파일 수정 전에 질문하되, 워크플로 문서에 기본안이 있는 항목은 기본안으로 진행하라.
```

## 재개 지점

- 2026-09-27: C0~C4 완료, C5a·C5b 완료. C5c~C5e는 위 표대로 재정의됐다(E1/E2 실험 근거). E5(폰트)·asset 팩·KR/JP parity·등급표까지
  오케스트레이터 쪽 입력 확보는 **전부 끝났다**. 이후 오케스트레이터 개입 없이 Opus가 C5c → C7을 진행한다.
- 다음 행동 순서: **C5c**(이미지 유틸 + 채널별 NCC) → C5d(배치 선택) → C5e-1(gutter 위상) → C5e-2(타일 은행 fast path) →
  **C5e-6a~6c**(생성기·캐시·로더, +D18 교정) → C5e-3(수량 은행 + synth seed) → C5e-4(장비 라벨×배지) → C5e-6d → C5e-6f(아이템 gate) →
  C5e-6e(라벨링 UI) → C5e-6f(장비·학생 gate) → C5e-5(선택) → C6 → C7.
  C5d와 C5e-1은 함께 실게임 1280 세 프로필 tail 검증을 한 번에 받아도 된다.
- 재고 golden 두 시나리오는 첫 상세 읽기에서 멈추므로 C5c 이전에 `scanner_c5_live` 프레임(선택 프레임 포함)으로
  **상세 경로가 끝까지 도는 재고 replay 시나리오 1개**를 추가한다(C6 리팩토링 보호). 이때 슬롯 44 기대값은 D18대로 `SkillBook_Ultimate`.
- 실험 산출물: `docs/migration/scanner-consolidation/c5e-experiments-2026-09-27.md`(E1/E2/E5/E6), `debug/scanner_c5e_experiments/`.
- 합성 입력: `docs/migration/scanner-consolidation/template-generation-spec-2026-09-27.md`, `backend/assets/recognition/spec/`,
  `backend/assets/recognition/asset_pack/`, 도구 `backend/tools/asset_spec/`. 팩 재추출이 필요하면(게임 패치) `ba_extract_pack.py` — 오케스트레이터 몫.
- 사용자 확인 대기: 경기천년제목 폰트 재배포 조건(팩 `README.md`). C5f 게이트는 통과(2026-09-27).
