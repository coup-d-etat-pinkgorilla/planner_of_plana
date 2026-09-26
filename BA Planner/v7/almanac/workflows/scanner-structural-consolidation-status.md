---
title: "Scanner Structural Consolidation Status"
summary: "C0~C7 스캐너 구조 정리 워크플로의 실제 진행 상태, 기준선 수치, golden 결과, 발견 사항과 다음 행동을 기록합니다."
topics: [workflow, architecture, migration, data]
sources:
  - id: workflow
    type: file
    path: almanac/workflows/scanner-structural-consolidation-workflow.md
---

# Scanner Structural Consolidation Status

단계 정의·불변식·gate는 [Scanner Structural Consolidation Workflow](scanner-structural-consolidation-workflow)가
소유한다. 이 문서는 실제 완료 사실, 검증 수치, 발견 사항과 다음 행동만 기록한다. [@workflow]

## 현재 현황

| Phase | 상태 | 시작 기준 | 다음 행동 |
|---|---|---|---|
| C0 기준선·golden 고정 | **완료** (2026-09-26) | `3a96abe` (branch `scanner-consolidation`) | — |
| C1 계약 드리프트·이름 정리 | **완료** (2026-09-26, C1a~C1c) | `552ab99` | — |
| C2 재고 끝 판정·입력 보강 | **완료** (2026-09-26, tail 실측 미충족을 C5로 이관) | `35768a2` | — |
| C3 오케스트레이터 분해 | **진행 중: C3a~C3c 완료** (2026-09-26) | `3b20374` | C3d(X12 `ScanContext`) |
| C4~C7 | 미착수 | — | 순서대로 |

## C0 — 기준선·golden 고정

### 시작 기준

- 시작 커밋: `b19da65df9507c44913b99d351fac5a96744bd47`
- 작업 트리: 미커밋 변경 포함(사용자 결정 2026-09-26: 현재 dirty tree 기준으로 고정).
  스캐너 관련 변경 지문:
  `git diff b19da65 -- backend/core backend/assets/recognition backend/data | sha256sum`
  (저장소 루트 `planner_of_plana` 기준 경로 출력) =
  `82d4b7284c23839c22536898a896e64cb227d58d4429492d3c5743d34e258b9a`
  — 9 files, +633/−218, 미추적 `backend/data/student_stats/v1/formula.json` 별도 존재.
- **Golden 기준 커밋(2026-09-26 사용자 승인 커밋)**: 위 스캐너·스탯 미커밋 변경을 branch `scanner-consolidation`의
  `3a96abe`로 커밋했다. golden은 이 커밋 + C0 산출물 커밋에서 재현된다. frontend UI 변경, `data/`, `debug/` 신규 파일,
  `section-template-studio.md`, `p0-p6-workflow-status.md`는 이 워크플로 범위 밖이라 미커밋으로 남겼다.

### 사용자 결정 (C0 착수 전)

- Replay 방식: **화면 상태 기계**. 기록 프레임에 화면 라벨을 붙이고, 클릭은 control 이름으로,
  드래그는 페이지 전진으로 해석한다. 순차 replay는 채택하지 않는다(현재 prepare 입력이 기록 당시와 달라
  — `filter_reset_button`·`note_filter` 없음, `sort_rule_check` 선클릭 — 기록 순서의 프레임이 다른 입력에 대응된다).
  정정: 착수 전 질문에서 순차 replay의 전량 `outside profile` skip을 오정렬 탓으로 설명했으나, 상태 기계 replay에서도
  같은 skip이 재현되어 원인은 인식 gate(아래 C0-1)다.
- 기준선: 현재 dirty tree.
- 결손 조합: 학생 전체 스캔은 F1 1280 이동 프레임을 상태 기계로 연결해 구성, gift(`presents`)·
  `student_elephs`는 결손으로 기록.

### 기준선 수치 (2026-09-26 신규 실행, 과거 533/400 재사용 안 함)

| 검증 | 명령 | 결과 |
|---|---|---|
| Python 전체(착수 시) | `cd backend; py -3.11 -m unittest discover -s tests -v` | 541 tests OK (234.9s) |
| Python 전체(C0 산출물 포함) | 동일 | **543 tests OK** (258.4s, golden 2건 추가) |
| Flutter analyze | `cd frontend; flutter analyze` | 2 issues(info `unnecessary_const`, `lib/ui/app_shell.dart:690,700` — 미커밋 UI 변경), exit 1 |
| Flutter test(전체) | `cd frontend; flutter test` | 403 pass / 2 fail — Python 전체 테스트와 **동시 실행** 중 real-process E2E 10초 timeout(`planning_protocol_client_test`, `repository_process_e2e_test`) |
| Flutter test(실패 2파일 단독 재실행) | `flutter test test/planning_protocol_client_test.dart test/repository_process_e2e_test.dart` | 22/22 pass → 부하 경합 timeout으로 판정 |
| golden 비교 | `cd backend; py -3.11 -m unittest tests.test_scanner_consolidation_golden -v` / `py -3.11 -m tools.scanner_consolidation_replay` | 2 tests OK, 8/8 `same` |
| 결정성 | 같은 프로세스 2회 + 새 프로세스 비교 | 8/8 바이트 동일 |
| `git diff --check` (C0 신규 파일) | — | 0 |
| `codealmanac validate` | — | 6 issues, 전부 기존 workflow 문서의 `unused_sources`(boundaries/detail/matchers/navigation/schema/session). status 문서 신규 issue 없음 |

### 산출물

- Replay harness: `backend/tools/scanner_consolidation_replay.py` (테스트·도구 전용, 런타임 import 없음).
  `core.scanner_runtime.build_scanner_service`와 같은 matcher/recovery 배선에 `ReplayCapture`만 교체한다.
  답안 샘플 저장소는 빈 임시 디렉터리의 실제 `RecognitionAnswerSampleStore`, 진행 콜백은 production과 같이
  `supports_feedback=True`.
- 입력 manifest: `backend/tests/fixtures/scanner_consolidation/scenarios.json` — 화면별 프레임 경로(추적 중인
  `debug/scanner_f*`)와 SHA-256, 화면 전이표. 프레임은 복사하지 않고 digest로 고정한다(불일치 시 테스트 실패).
- Golden: `backend/tests/fixtures/scanner_consolidation/golden/<scenario>.json` 8개(합계 164K).
- 비교 테스트: `backend/tests/test_scanner_consolidation_golden.py`.
- 재고정: `cd backend; py -3.11 -m tools.scanner_consolidation_replay --write [scenario...]` — 동작 변경 phase에서
  status에 의도된 diff를 적은 뒤에만 사용한다.

Golden 형식: `{scenario, result, inputs, screens_captured, progress}`. `result`는 adapter 반환값
(list 또는 `ScanBatchResult` → `candidates/outcome/error/screen_state/coverage_complete`, 예외는 `raised`).
이미지(`_answer_specimen` crop 등)는 `{mode,size,sha256}`로 바꾼다. dict 키는 정렬하고 **리스트 순서(evidence 포함)는
보존**한다. 입력 로그는 클릭을 region 이름으로 해석한 결과와 화면 전이를 담으므로 C2의 입력 변경(X08/X09)은
의도된 golden diff가 된다. 줄바꿈은 autocrlf 대비 LF로 정규화해 비교한다.

### Golden 세트

| Scenario | 해상도 | 입력 프레임 | 결과 요약 |
|---|---|---|---|
| `student_single_mika_1280` | 1280 | `scanner_f7_followup/mika-final/basic.png` | mika 1건, review 없음, 입력 0 |
| `student_single_mika_2560` | 2560 | `scanner_f3_live/00-initial.png` | mika 1건, review 없음 |
| `student_single_miyu_1280` | 1280 | `scanner_f7_live/miyu-basic/basic.png` | miyu 1건, skipped evidence 포함 |
| `student_single_shizuko_skill_panel_unopened_1280` | 1280 | `scanner_f7_followup/shizuko-panel/basic.png` | skill1/2 uncertain → `skill_menu_button` 클릭 → 패널 프레임 없음 → `skill_panel partial (panel_open_failed;same-student basic restored)`; `status:"shadow"` evidence 3건 포함(X01 실제 샘플) |
| `student_forms_hoshino_1280` | 1280 | `scanner_f8_live/hoshino-forms/frame-00,02` | `hoshino_battle`, `hoshino_battle#2` 2건, form2→form1 복원 |
| `student_full_ring_1280` | 1280 | `scanner_f1_live/01,02,03,07` | 학생 목록 진입 → mika→hina_dress→miyu→mika, `completed`, `coverage_complete=true` (**합성 ring**: hina_dress→miyu 전이는 기록 없음) |
| `inventory_item_tech_notes_1280` | 1280 | `scanner_f10_live/item-tech-notes-terminal-final` frame 00~03,07,10,13,16,19 | prepare → 5회 drag → `verified_tail_residual` 종료, entries 0, 60칸 `skipped`, `scan_coverage partial (ordered=False)` |
| `inventory_equipment_1280` | 1280 | `scanner_f10_live/equipment-three-pages-final` frame 00~03,07,10,13 | 3번째 이동에서 `inventory_scroll_unverified`(score .984, margin .002) → `failed`, 후보 0 |

### 결손 (C0에서 golden 없음)

- 재고 `presents`(gift)·`student_elephs`: `debug/scanner_f*`에 프레임 없음.
- 학생 패널 **열림 성공** 경로(level/star/skill/equipment/weapon/stat): 기록 basic 프레임이 fallback을 자연 유발하지 않거나
  (mika/miyu 등) 유발해도 같은 학생의 패널 프레임이 없다(shizuko). 기존 F2~F7 단위 테스트만 보호한다.
- 실프레임 재고 **accepted entry·zero-fill** 경로: 두 재고 scenario 모두 entries 0. entry 조립·X04/X05 필드는 기존
  `test_scanner_production_adapters` 합성 프레임 테스트만 보호한다.
- 학생 2560은 단일 스캔 1건만, 전체 스캔은 합성 ring 1건만. 다른 계정 표본 없음(X25).

### 미검증

- 실게임 확인 없음(C0 범위 아님). Replay는 기록 프레임의 화면 상태 기계이며 실게임 검증으로 표기하지 않는다.
- 재고 두 scenario의 전량 skip이 현재 클라이언트에서도 재현되는지(아래 발견 사항 C0-1/C0-2) 미확인.

### 발견 사항 (다른 phase 소관, C0에서 손대지 않음)

| ID | 발견 | 소관 후보 |
|---|---|---|
| C0-1 | 1280 tech_notes 실프레임의 기술 노트 아이콘이 전역 매칭에서 장비 조각(`*_Piece`)·`Vajra` 등에 score≈.67~.69, margin≈0으로 붙는다. 전역 gate는 `score>=0.55`만 보고 margin을 보지 않아 **실제 기술 노트 60칸 전부를 `outside the explicit scan profile`로 skip**한다. zero-fill은 `ordered=False`로 막히지만 item 프로필 스캔이 사실상 무결과다. | C5(인식 공통화)/C7(임계 결정), X17 |
| C0-2 | equipment 실프레임도 가시 슬롯 top 매칭이 `equipment` 프로필 밖의 `*_Piece` identity라 entries 0. 이어진 스크롤 실패 시 entries가 비어 있으면 `ScanBatchResult`가 **evidence 전체를 버린다**(skip·overlap evidence가 진단에 남지 않음). | C1/C2(X10 인접), C3 |
| C0-3 | X09 재현: 현재 prepare는 `filter_tab` 화면에서 `sort_rule_check`를 무조건 클릭한다(replay 입력 로그상 `menu_filter`에서 unmapped 클릭). | C2 |
| C0-4 | X08 재현: 모든 drag가 `(.78,.75)→(.78,.65)`로 그리드 내부에서 시작한다. | C2 |
| C0-5 | `scanner_runtime.build_scanner_service`가 `WindowsCaptureInputAdapter`를 직접 생성해 replay harness가 배선을 복제한다. 배선이 바뀌면 harness가 조용히 어긋날 수 있다. capture port 주입형 factory가 필요하다. | C3/C6 |
| C0-6 | `codealmanac validate`의 workflow 문서 `unused_sources` 6건(기존). | 문서 정리 시 |
| C0-7 | Flutter analyze info 2건(`app_shell.dart` 미커밋 UI 변경). | 별도 UI 워크플로 |

### 다음 행동

1. (완료) 사용자 승인으로 기준 변경(`3a96abe`)과 C0 산출물을 별도 커밋했다.
2. C1 착수: `student_single_shizuko_skill_panel_unopened_1280` golden의 shadow evidence를 X01 스키마 검증의 실제 후보
   샘플로 사용한다. C1의 필드 추가·이름 변경은 golden diff로 드러나며 status에 사유를 적고 `--write`로 재고정한다.
3. C0-1/C0-2는 C2 실게임 1280 확인 때 현재 클라이언트 프레임으로 재현 여부를 먼저 확인한다.

## C1 — 계약 드리프트·이름 정리

### Sub-slice 분할 (2026-09-26)

C1은 repository DTO와 Flutter decoder까지 걸치므로 세 조각으로 나눈다.

| Slice | 항목 | golden 기대 | 상태 |
|---|---|---|---|
| C1a | X01 `shadow` enum, X02 `session.start.inventory_scan_profile`, X03 프로필 집합 단일 소스 | diff 0 | **완료** (2026-09-26) |
| C1b | X04 zero-fill 필드, X05 `inventory_scan_profile` 엔트리 필드, X21 source 이름 | 의도된 필드 추가·이름 변경 diff | **완료** (2026-09-26) |
| C1c | X06 후보 `catalog_revision`과 commit 검증 + 재고 commit 전체 교체 버그(C1-1) 수정 | 재고 golden에 `catalog_revision` 추가 | **완료** (2026-09-26) |

### C1a 결과 (2026-09-26)

- X03: `inventory_catalog.SCAN_PROFILES`(CATALOG profile id 등장 순서)·`ITEM_SCAN_PROFILES`(equipment 제외)를 단일 소스로 두었다.
  `scanner_session.start`의 하드코딩 집합과 `inventory_navigation.ITEM_FILTERS`(값인 filter control 이름은 F12 이후
  클릭하지 않는 죽은 매핑이었고 membership만 쓰였다)를 제거하고 이 둘을 import한다.
- X02: `scanner.session.start` 요청에 optional `inventory_scan_profile` enum(7개, CATALOG 순서)을 정의했다. 정적 JSON이라
  생성 대신 동기화 테스트로 묶었다: Python `test_inventory_scan_profile_enum_is_the_catalog_single_source`(schema == `SCAN_PROFILES`),
  Dart `inventory scan profiles match the shared scanner schema enum`(`InventoryScanProfile.wireName` 집합 == schema).
  공용 fixture에 유효/무효 start 2건을 추가했다(15→17건, 유효 9→10).
- X01: `fieldEvidence.status` enum에 `shadow`를 추가했다. `test_real_replay_candidates_including_shadow_evidence_match_schema`가
  C0 golden 8개의 실제 후보 전부를 `$defs/candidate`로 검증한다. 구 스키마에서는 hoshino/mika/shizuko 등 학생 후보가
  `'shadow' is not one of [...]`로 실패함을 확인했다(학생 후보 대부분이 shadow를 포함 — 기존 스키마는 실제 후보를 거부하고 있었다).
- 응답 `scanner.session.start`에는 `inventory_scan_profile`을 싣지 않으므로 응답 스키마는 바꾸지 않았다.

| 검증 | 결과 |
|---|---|
| `cd backend; py -3.11 -m unittest discover -s tests -v` | 545 tests OK (+2 contract) |
| golden diff | **0** (`test_scanner_consolidation_golden` OK) |
| `cd frontend; flutter analyze` | 기존 info 2건(`app_shell.dart`)만 |
| `cd frontend; flutter test` | 406 all passed (+1, Dart↔Python process E2E 포함) |


### C1b·C1c 사용자 결정 (2026-09-26)

- **C1-1 (신규 발견, 데이터 손실)**: scanner 재고 commit이 `update_inventory`로 계정 인벤토리 **전체를** 후보 엔트리로 교체한다.
  재현: 임시 저장소에 ooparts `Mandragora_0 ×5` 저장 → `tech_notes` 후보 1건 commit → 저장 인벤토리에 tech note 1건만 남음.
  Flutter `inventory_page._approveCandidate`는 후보 payload를 그대로 review/commit한다. 결정: **C1c에서 수정**(스캔 프로필의
  catalog 엔트리만 교체하고 나머지 보존, 재현 회귀 테스트 선행).
- X05: `inventory_scan_profile`은 **scanner 후보 전용**. repository DTO·스키마·Flutter repository 파서는 바꾸지 않는다.
- X06: `catalog_revision` **누락도 거부**(`catalog_revision_missing`), 불일치는 `catalog_revision_mismatch`, details에 기대/수신 revision.

### C1b 결과 (2026-09-26)

- X04: zero-fill evidence field를 `entries[<리스트 인덱스>].quantity` → `zero_fill[<resource_key>].quantity`로 바꿨다
  (zero-fill 대상 row는 전부 `resource_key == item_id` 확인).
- X05: 스캔 엔트리(관측·zero-fill)에 `inventory_scan_profile`을 추가했다(`prepared.profile_id`, navigation 없는 경로는 `null`).
  `profile_id`는 D11 기본안대로 병행 유지 — **제거 시점: C6**. `ScannerSessionService._repository_inventory`가 review/commit/후보
  생성 검증 전에 이 필드를 떼어내며(`SCANNER_ONLY_ENTRY_FIELDS`), 값이 `SCAN_PROFILES` 밖이면 `invalid_candidate`로 거부한다.
- X21: 같은 crop 재매칭 source `detail_template_fallback` → `grid_same_crop_rematch`. `scroll_overlap` evidence source를 항상
  `verified_row_overlap`으로 쓰던 것을 실제 결정(`verified_row_overlap`/`verified_tail_residual`/`verified_no_motion`)으로 바꿨다.
- 구 진단 호환: `scanner_matchers.LEGACY_INVENTORY_EVIDENCE_SOURCES`와 `canonical_inventory_evidence(evidence, entries)`가 세 가지 구 형식을
  현재 계약으로 변환한다(비파괴·멱등). 테스트 `test_inventory_evidence_contract_c1.py`.
- Flutter: 재고 evidence field/source 이름과 후보 엔트리 키를 엄격 파싱하는 곳이 없어(`inventory_page.dart:813`은 느슨한 List 읽기)
  decoder/mock 변경이 필요 없었다. v6 parity fixture의 역사적 `detail_template_fallback` 표기는 그대로 둔다.

| 검증 | 결과 |
|---|---|
| Python 전체 | 547 tests OK (+2) |
| golden diff | **1건, 의도됨**: `inventory_item_tech_notes_1280`의 마지막 `scroll_overlap` source `verified_row_overlap` → `verified_tail_residual`(X21). `--write inventory_item_tech_notes_1280`으로 재고정. 나머지 7개 same. 재고 golden에 accepted entry가 없어 X04/X05는 golden에 나타나지 않고 단위 테스트로만 고정된다. |
| Flutter analyze / test | 기존 info 2건 / 406 all passed |

### C1c 결과 (2026-09-26)

- 병합 규칙 사용자 결정: **identity upsert**. 착수 전 선택지는 "스캔 프로필 엔트리 교체"였으나, 부분 스캔(zero-fill 불가)에서
  관측 못 한 같은 프로필 항목을 지우는 손실이 남아 재질문했고 upsert로 확정했다. 관측 못 한 항목은 이전 수량을 유지한다.
- C1-1 수정: `ScannerSessionService._merged_inventory`가 commit 시점의 저장 인벤토리에 스캔 엔트리(명시 zero-fill `"0"` 포함)를
  `item_id or key` 기준으로 덮어쓰고 나머지는 순서를 유지해 보존한다. revision 충돌 검사는 기존 `update_inventory` 그대로다.
  회귀 테스트 `test_scanner_inventory_commit_c1c.py`는 수정 전 실제 `JsonRepository`에서 ooparts·미관측 노트가 사라지는 것을 재현했다.
- X06: `InventoryMatcherAdapter` 후보 payload(정상·중단 보존 후보 모두)에 `catalog_revision`(= `inventory_catalog.CATALOG_REVISION`)을
  싣는다. commit은 누락 `catalog_revision_missing`, 불일치 `catalog_revision_mismatch`로 거부하고 저장소를 쓰지 않는다. error
  details와 후보 `audit`에 `{expected, received}`를 남긴다. Flutter는 후보 payload를 그대로 review/commit하므로 값이 보존된다.
- 스키마: 후보 payload는 v1에서 generic object라 변경 없음. repository `inventorySnapshot.catalog_revision`은 기존 optional 필드.

| 검증 | 결과 |
|---|---|
| Python 전체 | 549 tests OK (+2) |
| golden diff | **1건, 의도됨**: `inventory_item_tech_notes_1280` payload에 `catalog_revision` 추가(X06). `--write`로 재고정. 나머지 7개 same |
| Flutter analyze / test | 기존 info 2건 / 406 all passed (Dart↔Python process E2E 포함) |
| `codealmanac validate` | 기존 workflow `unused_sources` 6건만 |

### C1 완료 판정

- 스키마 테스트가 C0 golden 실제 후보 전체를 통과(C1a), Dart enum 동기화 테스트 통과, golden diff는 X21·X06의 의도된 2줄뿐.
- **미검증**: 실제 앱 UI에서 재고 스캔 승인→commit 병합을 실게임으로 확인하지 않았다(commit 경로는 게임 입력과 무관해 저장소
  통합 테스트로 확인). 실게임 1280 확인은 C2에서 재고 스캔 실측과 함께 한다.
- 남은 발견: C0-1(기술 노트 전량 skip), C0-2(entries 0일 때 중단 결과가 evidence를 버림) — C2 실게임 확인 시 먼저 재현한다.

### 다음 행동

- C2 착수. X07·X09·X10·allowlist는 fixture 선행이 가능하나 X08과 완료 조건은 **실게임 1280에서 item/equipment/gift tail**
  확인이 필요하다. 게임 실행 가능 시점을 사용자와 맞춘다. D4 기본안(안전 드래그 영역 없으면 `review_required` 강등)은 그대로.

## C2 — 재고 끝 판정·입력 보강

시작 `35768a2`. 게임 창 1280×720(사용자가 띄움), 계정 화면 입력은 표시 설정·목록 조작만 했고 사용/판매 버튼은 누르지 않았다.

### 구현

| 항목 | 변경 |
|---|---|
| X07 | `InventoryNavigation.confirm_terminal`: `verified_tail_residual` 페이지를 읽은 뒤 drag 1회 + settle 후 `page_similarity >= .97`(기존 값)일 때만 terminal. 움직이면 `scroll_terminal partial / tail_recheck_moved`, `coverage_complete=False`, review_required, zero-fill 없음 |
| X08 | region 자산 `inventory_navigation_f10_regions.json`에 `scroll_track {x: 0.975, start_y: .75, end_y: [.65, .58]}` 추가(매니페스트 sha/bytes 갱신, CRLF 유지). `scroll_once`가 drag·wheel 모두 이 값을 쓰고 코드의 `.78` 리터럴을 제거했다. x=.975는 목록 오른쪽 여백으로 item·equipment 모든 grid slot 밖(테스트로 고정) |
| X09 | prepare에서 filter 탭의 무조건 `sort_rule_check` 클릭 제거. 정렬 라디오는 정렬 탭에서 `ensure_sort`가 관측 후 꺼져 있을 때만 클릭 |
| X10 | `inventory_scroll_unverified` 안전 중단(취소 아님) 시 `restore_first_page`(= 검증된 표시 설정 재적용)를 호출하고 `error.details.first_page_restored`, evidence `inventory_restore`(`inventory_first_page_restore`)를 남긴다. 문서 수정이 아니라 **구현**을 택했다 |
| allowlist | `inventory_navigation.ALLOWED_CONTROLS`(filter/sort 메뉴·탭·정렬 체크·확인 9개) 밖의 이름은 `control_not_allowed`로 클릭 전 거부. 카테고리 필터 체크박스·`filter_reset_button`은 목록에 없다 |

D4: 안전 드래그 영역이 있으므로(아래 실측) 강등 기본안은 적용하지 않았다.

### 실게임 1280 확인 (`debug/scanner_c2_live/`)

각 디렉터리의 `trace.json`에 입력·캡처 순서, 중복 제거된 프레임 파일명→SHA-256, 결과 후보가 있다. 실행 도구
`backend/tools/verify_inventory_c2_live.py`(production adapter, 저장소 쓰기 없음).

| 실행 | 결과 |
|---|---|
| `menu/` 표시 설정 관찰 | filter 탭에 **카테고리 체크박스가 존재**(엘레프·기술 노트·선물 등, F10 `*_filter` 좌표와 일치). 정렬 탭 라디오 `기본` = `sort_rule_check` 위치, 선택 시 score .92 |
| `track/`, `eq-track/` | x=.975 탭: 선택 항목 이름·수량 불변(item/equipment). drag: item에서 3행 overlap .985로 스크롤 |
| `presents-full-2` | prepare 정상(정렬 관측 .92, 클릭 없음), drag 5회 검증 후 6번째 `ambiguous row overlap .983 margin .019` → failed, **first_page_restored=true**, entries 3(모두 상세 fallback) |
| `tech-notes-full` | drag 4회 검증 후 **실제 목록 끝**에서 1행 미만 이동 → `.922 margin .019` → failed, first_page_restored=true, entries 0 |
| `equipment-full` | drag 2회 후 `.982 margin .006` → failed, first_page_restored=true (F10 기록과 같은 지점) |
| `*-cancel` 3개 | 세 프로필 모두 `cancelled`, 보존 후보는 `scan_interrupted partial`, zero-fill 없음, 게임은 같은 페이지 |
| `tech-notes-restore-probe` | 2페이지 이동(유사도 .864) 후 restore → page0 유사도 **.99999** (X10 실측) |
| `presents-full`(첫 시도) | filtermenu 클릭 2회가 게임에 반영되지 않아 `inventory_filter_unconfirmed`. 직후 같은 클릭은 정상 — 창 포커스 전환 직후 입력 누락으로 추정, 재현 안 됨 |

사용자 표시 설정은 시작 상태(선물 필터)로 되돌렸다. 주의: 인벤토리 화면에서 Escape는 메뉴가 아니라 화면 자체를 닫고
로비 메뉴 모음으로 나간다(진단 중 1회 발생, 로비 메뉴 `아이템`으로 복귀).

### 완료 판정 — 보류

완료 조건 중 "실게임 1280 세 프로필 **tail까지**"를 충족하지 못했다. 세 프로필 모두 안전하게(복귀·zero-fill 없음) 중단됐지만:

- **C2-2 (신규, 끝 판정)**: 목록 끝에서 마지막 drag가 1행 미만만 움직이면 정수 행 overlap(1~4행) 후보만 비교하므로
  tail-residual band(.88~.94)에는 들어가도 margin(.03)을 못 넘겨 `inventory_scroll_unverified`가 된다(`tech-notes-full`).
  X07 재확인은 이 경로에 도달하지 못해 **실게임에서 미실행**(단위 테스트로만 확인). 임계 변경은 C4 전 금지이므로 C2에서 고치지 않았다.
- **X20 실측**: 선물·장비 청사진처럼 배경이 비슷한 타일에서 24차원 히스토그램 overlap이 목록 중간에 모호해진다 → C5 소관.
- **C0-1 실측 재현**: 선물 45칸 중 42칸이 `confident visible identity is outside the explicit scan profile`로 skip, 3칸만 상세 fallback으로 인식.
- **C2-1 (신규)**: 현재 클라이언트에 카테고리 필터 체크박스가 있다. `f12-inventory-current-display-contract.json`의
  `category_checkboxes_available: false`와 모순. prepare가 프로필 필터를 걸지 않아 사용자가 걸어 둔 필터에 따라 목록이 달라진다.

### 검증

| 검증 | 결과 |
|---|---|
| Python 전체 | 555 tests OK (+6: allowlist, 정렬 관측 후 클릭, scroll_track 좌표·slot 밖, tail 재확인 2, restore 성공/실패) |
| golden diff | **2건, 의도됨** → 재고정. `inventory_item_tech_notes_1280`: 무조건 정렬 클릭 입력 삭제, drag x .78→.975, tail 재확인 drag 1회 추가·evidence note. `inventory_equipment_1280`: drag x, 스크롤 실패 뒤 설정 재적용 입력 2개와 `first_page_restored: true`. 학생 6개 same |
| Flutter analyze | 기존 info 2건 |
| Flutter test | 403 pass / 3 fail — real-process E2E 첫 요청 10초 timeout(게임 실행 중 병렬 부하). 3개 파일 단독 재실행 23/23 pass |

### C2 종료 결정 (2026-09-26, 사용자)

- C2를 **완료**로 닫는다. 완료 조건 중 "실게임 1280 세 프로필 tail"은 **미충족으로 기록**하고 C5로 이관한다:
  C5의 행 overlap 재설계(X20, slot identity 병합)에 **C2-2 1행 미만 tail 이동 판정**과 **X07 no-motion 재확인의 실게임 실행**을 추가한다.
  C5 완료 조건의 "실게임 1280 재고 세 프로필"은 tail 도달까지 포함한다.
- 프레임: 판단 근거가 되는 **핵심 프레임 18개(7.7 MB)만 커밋**했다 — `menu/`·`track/`·`eq-track/` 관찰과 각 중단 지점의
  전후 쌍(`presents-full-2/frame-31,34`, `tech-notes-full/frame-16,19`, `equipment-full/frame-16,19`). 나머지 153개는 로컬 미추적이며
  각 `trace.json`의 `frames`(파일명→SHA-256)로 식별한다.
- C2-1(카테고리 체크박스 존재)은 프로필 필터를 prepare가 걸도록 할지의 **기능 결정**이라 이 워크플로 범위 밖이다. C5 착수 전
  사용자 결정 항목으로 남긴다(C0-1 전량 skip과 함께 재고 item 프로필 스캔이 실사용 불가인 원인 후보).

### 다음 행동

- C3 착수: 오케스트레이터 분해(동작 보존). 완료 조건은 golden diff 0, 전체 테스트 통과, 최대 함수 80줄 이하.

## C3 — 오케스트레이터 분해 (동작 보존)

시작 `3b20374`. **80줄 기준 범위(기본안)**: X11~X14가 지목한 오케스트레이션 모듈 — `scanner_matchers`, `scanner_session`,
`inventory_navigation`, `inventory_detail_recovery`, `student_panel_recovery`, `student_identity_recovery`, `student_form_recovery`,
`student_equipment_recovery`, `windows_scanner_adapter`. 인식 알고리즘(`student_*_recognizer`)과 tactical/planning 모듈의 80줄 초과
함수(core 전체 21개)는 이 워크플로 범위 밖이다. 착수 시 범위 내 초과: 인벤토리 `__call__` 262, `_scan_current` 218, `_scan_full` 128,
`scanner_session.review` 93.

| Slice | 항목 | 상태 |
|---|---|---|
| C3a | X11 인벤토리 `__call__` 분해 + 상태 dataclass, X13 `DetailRecoveryResult` | **완료** |
| C3b | X11 학생 `_scan_current`·`_scan_full` 분해 | **완료** |
| C3c | X14 `PanelMenu` Protocol·validator 단일 시그니처·`ProgressSink`, `scanner_session.review` 분해 | **완료** |
| C3d | X12 `ScanContext` frozen dataclass(target 컨텍스트 백 제거) | 미착수 |

### C3a 결과

- `InventoryMatcherAdapter.__call__`(262줄)을 `_prepare_scan`·`_load_answer_samples`·`_read_page`·`_read_slot`(식별+상세+프로필 gate)·
  `_apply_detail`·`_record_entry`·`_advance_page`·`_wheel_page`·`_finalize`·`_zero_fill`·`_interrupted`로 나눴다. 흩어진 상태 플래그
  9개(entries/evidence/slot_crops/review_required/completed/coverage_complete/terminal_after_page/observed ids/prepared)는
  `_InventoryScan` dataclass, 슬롯 관측은 `_SlotReading`으로 모았다. 워크플로 예시의 "순수 함수"는 매칭·상세 클릭이 부수효과라
  adapter 메서드로 두었다. 최장 `_read_slot` 50줄.
- X13: `InventoryDetailRecovery.resolve`가 복귀 확인 뒤의 읽기 실패를 `details['inventory_restored']` 주입 후 raise하던 것을
  `DetailRecoveryResult(detail, restored, failure)` 반환으로 바꿨다. 복귀 실패·취소·비-ScannerError는 이전처럼 raise한다. adapter의
  partial 전환 코드 집합은 `DETAIL_RECOVERABLE_CODES`로 이름 붙였다(값 동일).
  **관찰 가능한 차이 1건**: partial로 전환되지 않고 재발생한 상세 오류의 `error.details`에 `inventory_restored` 키가 더는 없다.
  Flutter·protocol·진단 스키마에서 이 키를 읽는 곳은 없다(grep 확인).
- 검증: inventory 50·scanner 73 tests OK, golden **8/8 same**.

### C3b 결과

- `_scan_current`(218줄) → `_basic_crops`(basic 탭 확인·crop) · `_read_growth_fields`(basic + level/star/skill/potential, 기존 호출 순서)
  · `_resolve_weapon`(무기 상태 gate와 무기 패널 fallback evidence) · `_resolve_equipment`(장비 basic + 장비 패널, 확정 digit 세션 학습)
  · `_assemble_student`(values/provenance/evidence, shadow 3종은 `_evidence_rows`로 통일). 무기 패널 복구 체인은 `_panel_recovery()`로
  `_capture_identified`와 공유. 항상 `True`였던 `confident` 변수는 제거(evidence `ok`·review 조건 동일).
- `_scan_full`(128줄) → 순회 제어 `_scan_full` + 학생 1명 `_scan_full_student` + 재방문 판정 `_revisit`(retry/reverse/complete/move)
  + 키·버튼 이동 `_StudentWalker`(버튼 좌표 상수화, 값 동일). break/continue·progress 순서 유지.
- 검증: student 265·scanner 73 tests OK, golden **8/8 same**(학생 단일·다중 폼·전체 ring 포함). 범위 내 최장 함수는 이제 `scanner_session.review` 93.

### C3c 결과

- `PanelMenu` Protocol(`capture`/`recapture`/`close`, `student_panel_recovery`)로 `read_panel_fields`의
  `getattr(menu, f"capture_{kind}_menu")` 문자열 디스패치를 없앴다. 메뉴 adapter 6개는 일반 메서드를 구현하고, 종류별 Protocol 6개는
  삭제했다. 메서드 이름 충돌을 피하려 adapter의 capture port 속성은 `self.port`로 바꿨다. **종류별 이름(`capture_weapon_menu` 등)은
  클래스 별칭으로 C6까지 유지**한다(도구·F12 audit matrix가 참조). 테스트 fake 8개 파일은 일반 이름으로 바꿨다.
- student validator는 항상 `(payload, profile_id, relationship_ranks)`로 호출한다(`inspect.signature` 판별 제거). 2인자 테스트
  validator 4개와 `tests/scanner_e2e_backend.py`에 3번째 인자를 추가했다. production `StudentCandidateValidator`는 이미 3인자다.
- `ProgressSink` Protocol(`supports_feedback` 속성 + 호출)을 두고, 세션의 함수 속성 주입을 `_SessionProgress` 클래스로, 전체 스캔의
  `current_progress.supports_feedback = ...`를 `_CollectedProgress`로 바꿨다. plain callable은 feedback 없는 sink로 계속 허용한다.
- `scanner_session.review`(93줄) → `_train_answer_sample`·`_mark_user_verified`·`_revalidate_student`.
- 검증: Python 555 OK(golden 8/8 same 포함), Flutter 406 all passed.
- 범위 내 상위 5개 함수 길이: `windows_scanner_adapter._render` 65, `scanner_session.commit` 62, `_read_slot` 50,
  `_scan_with_forms` 49, `_resolve_weapon` 48 — **80줄 조건 충족**.
