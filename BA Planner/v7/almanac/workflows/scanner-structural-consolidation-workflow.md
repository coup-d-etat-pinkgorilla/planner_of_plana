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
| X20 | 행 overlap이 identity 없이 24차원 RGB 히스토그램만 사용 | `inventory_navigation.py:36-46, 142-150` |
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

- 이미지 유틸을 `recognition_image_ops.py`로 모은다. `_normalized_correlation` 두 변형은 `ncc_signed_lanczos`,
  `ncc_unit_bilinear`처럼 의미가 드러나는 이름으로 분리하고 private import를 제거한다.
- `InventoryDetailRecovery`를 `StudentPanelRecovery`와 같은 `open → verify → read → close → verify_return` 계약(공통 base 또는 Protocol)에 올린다.
  재고 고유 원시(선택 테두리 검출)는 전략으로 주입한다.
- 재고 수량 판독을 `StudioNumericBank` 경로에 합류시켜 사용자 정답 샘플·세션 보정을 받게 한다. 기존 그리드 잉크마스크 경로는
  parity 비교 후 fallback으로 강등하거나 제거한다. **사용자 승인 슬롯만 영구 저장** 규칙은 그대로다.
- 행 overlap에 슬롯 identity(직전 페이지 매칭 결과)를 히스토그램과 병합한다. 티어 연속 프로필(노트/BD/오파츠)에서
  ambiguous 중단 빈도가 줄어드는지 native fixture로 전후 비교한다.
- (C2에서 이관, 2026-09-26) 목록 끝에서 마지막 이동이 1행 미만일 때의 tail 판정(C2-2)을 overlap 재설계에 포함하고,
  X07 no-motion 재확인이 실게임에서 실제로 실행되는 것을 확인한다.
- 완료: 항목별 parity fixture 통과, 실게임 1280 재고 세 프로필(**tail 도달 포함**)과 학생 단일 스캔 회귀 통과, golden 재고정.

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

- 현재 **C0 미착수**. 리뷰 근거는 위 X01~X25 표와 2026-09-23 분석 대화에 있다.
- 다음 행동: C0 골든 고정. 프레임 결손 조합이 있으면 status에 적고 C1로 진행한다.
