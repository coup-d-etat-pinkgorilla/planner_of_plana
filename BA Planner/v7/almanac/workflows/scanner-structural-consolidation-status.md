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
| C3 오케스트레이터 분해 | **완료** (2026-09-26, C3a~C3d) | `3b20374` | — |
| C4 임계값 레지스트리 | **완료** (2026-09-26, C4a~C4c) | `d4f030e` | — |
| C5 인식 공통화 | **진행 중: C5a~C5d·C5e-1·C5e-2·C5e-6a-0·C5e-6a 완료**(D21 실입력·C5e-2 실게임 두 번째 스캔 사용자 대기, 6a 학생 화면 spec 대기) (2026-09-27) | `43c17b5` | C5e-6b 캐시·드리프트 |
| C6~C7 | 미착수 | — | 순서대로 |

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
| C3d | X12 `ScanContext` frozen dataclass(target 컨텍스트 백 제거) | **완료** |

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

### C3d 결과

- `core/scan_context.py`의 `ScanContext`(frozen dataclass): 공개 target 키는 `target`, 스캐너 상태는 타입 필드
  `cancel`/`cleanup`/`scroll_point`/`session_id`/`generation`/`inventory_profile_verified`/`first_student`/`seen_students`.
  `ScanContext.of()`가 dict·context를 모두 받고, 변형은 `replace()`로만 만든다.
- core의 `{**target, '_scanner_*': ...}` 생성과 `target.get('_scanner_*')`·`'_first_student'`·`'_seen_students'`·
  `'_inventory_profile_verified'` 조회를 전부 타입 필드로 바꿨다(인벤토리 상세·navigation·메뉴 adapter·학생 식별/폼/패널 복구·
  학생/인벤토리 adapter). 세션은 `session.target` dict에 private 키를 주입하지 않고 matcher 호출 시 context를 만든다.
- **어댑터 경계**: `ScanContext`는 읽기 전용 `Mapping`이기도 해서 capture/input port(`windows_scanner_adapter`)와 테스트 fake는
  기존처럼 `target.get("_scanner_cancel")` 등 legacy 키로 읽는다. 이 이름이 남는 곳은 `scan_context.LEGACY_KEYS`와 port 구현뿐이다.
  capture worker 전송은 기존대로 새 dict(`target_id`, `_window_identity`)를 만든다.
- 검증: Python 555 OK(golden 8/8 same), Flutter 406 all passed. **미검증**: 실제 Windows adapter와의 실게임 smoke — 게임 창이 닫혀
  있어(`target_not_ready`, 입력 없음) 실행하지 못했다. port의 Mapping 사용은 F1 fake-user32 테스트가 덮는다.

### C3 완료 판정

- golden diff **0**(C3a~C3d 매 slice), 전체 테스트 통과, 범위 내 최대 함수 65줄(`windows_scanner_adapter._render`) — 완료.
- 관찰 가능한 차이는 C3a의 `inventory_restored` error details 키 제거 1건(소비자 없음).
- C6로 넘기는 정리: 메뉴 adapter의 종류별 별칭(`capture_weapon_menu` 등), `profile_id` 병행 필드(D11).

### 다음 행동

- C4 착수: `recognition_thresholds.py` 레지스트리로 리터럴을 옮긴다(값 불변, golden diff 0).

## C4 — 임계값 레지스트리 (동작 보존)

시작 `d4f030e`.

### 정의와 범위 (기본안)

- **임계값 리터럴** = float 상수가 비교식(`>=`, `<` 등)에 쓰이거나, 이름에 threshold/margin/floor/minimum/score/tolerance가 들어간
  인자·기본값·대입에 쓰인 것. 검사기 `tests/test_recognition_thresholds_c4.py`가 AST로 찾는다.
- **허용 목록(명시)**: 같은 테스트의 `ALLOWLIST`에 (파일, 값, 탐지 유형) → 사유로 적는다. 중립 기본값(0 = gate 없음)과 가중치
  (`.4*visual+.6*name`)만 둔다. 크롭 비율·좌표·가중치 곱·대기 시간처럼 비교에 쓰이지 않는 float는 정의상 대상이 아니다.
- **범위**: 인식·오케스트레이션 모듈(`scanner_matchers`, `inventory_*`, `student_*recognizer`, `student_*recovery`,
  `studio_numeric_bank`). tactical lobby·windows adapter 타이밍은 워크플로 범위 밖. 착수 시 AST 기준 164건.
- 레지스트리 `backend/core/recognition_thresholds.py`: `Threshold(name, value, kind, phase, doc, field, source, resolution, note)`,
  `value(name)`, `lookup(field, source, kind, resolution)`. 도입 phase는 `git log -S`로 확인한 커밋 기준(P5 `8f4ffd4`, F12 `b19da65` 등).

| Slice | 파일 | 상태 |
|---|---|---|
| C4a | `scanner_matchers`, `inventory_navigation`, `inventory_detail_recovery` (29 항목) | **완료** |
| C4b | `student_panel_recovery`, `student_identity_recovery`, `student_equipment_recovery`, weapon/level/star/skill/potential recognizer, `studio_numeric_bank` (46 항목) | **완료** |
| C4c | `student_scan_recognizer`, `student_equipment_recognizer` (59 항목) | **완료** |

### "같은 프레임" 임계 세 가지 (값 유지, 통일은 C7 결정)

| 이름 | 값 | 비교 대상 | 왜 다른가 |
|---|---|---|---|
| `inventory.wheel.same_frame` | .995 | 한 번 wheel 후 **전체 프레임** 픽셀 유사도(`image_similarity`) | navigation 없는 P5 fallback. 전체 프레임에는 애니메이션 배경·선택 테두리가 섞여 있어 거의 완전 일치만 "무이동"으로 본다 |
| `inventory.scroll.settled_same` | .985 | 연속 캡처 간 **slot 내부 24차원 히스토그램** 평균 유사도 | 스크롤 관성이 멈췄는지 판단. 테두리·수량 기준선을 잘라낸 서명이라 전체 프레임보다 잡음이 적지만, 멈춘 뒤에도 반짝임 효과가 남아 1.0이 아니다 |
| `inventory.scroll.no_motion_same` | .97 | drag **전후** 페이지 서명 유사도 | 1행 이동도 서명 평균을 크게 바꾸므로 낮은 값이어도 "안 움직임"을 가르기에 충분하다. 동시에 settle 판정보다 느슨해야 settle 직후 잔여 효과로 무이동을 놓치지 않는다. C2 tail 재확인(`confirm_terminal`)도 같은 값을 쓴다 |

### C4a 결과

- 29개 항목 등록(inventory grid/profile gate/slot count/wheel, navigation 메뉴·정렬·스크롤, 상세 패널, 학생 식별 기본값).
  `inventory.profile_gate.outside_score`(.55, F12)와 `inventory.grid_icon.floor_without_detail`(.55, P5)은 값은 같지만 다른 결정이라
  이름을 나눴다. C2의 tail 재확인은 `inventory.scroll.no_motion_same`을 공유한다.
- 검증: 검사기 4 tests OK(허용 목록 stale 없음), inventory 50·scanner 73 tests OK, golden **8/8 same**.

### C4b 결과

- 46개 항목 추가(누적 75): 패널 전환 F2, 엔트리 복구 F8, 장비 메뉴 컨트롤 F7, 무기 basic S2(2026-09-05 보고서), level F4, star F5,
  skill F6, potential F3, studio glyph 높이 비 S3b. 8비트 밝기 gate(`student.weapon.signal.min_mean` 35, `min_stddev` 8)는
  `kind="intensity"`(0~255)로 등록했다. 정수 밝기 gate(`>= 210`, `>= 80` 등)는 float 규칙 밖이라 그대로 두었다 — C7 감사 대상.
- X23 특수 사례 중 potential `4→0` 보정의 두 값(`zero_correction.below` .72, `.tolerance` .03)은 규칙에 잡히지 않는 산술식
  (`score-.03`)이지만 명시적으로 등록해 C7 표의 근거로 쓴다. 무기 0.57·whole-bank 0.49·인연 0.38/0.005는 C4c 파일에 있다.
- 허용 목록 추가: 식별 복구 가중치 .7/.3·.35/.65, potential basic glyph 가중치 .55/.45, 무기 `min(default=0.0)`.
- 검증: 검사기 OK, Python 전체 559 OK(golden 8/8 same). 레지스트리 조회는 1백만 회 0.11s — 전체 테스트 시간 변동(255→431s)은
  동일 커밋에서도 나타나는 시스템 부하 차이로 판단했다(potential 테스트 24개에서 조회 213회).
- 작업 사고 기록: 시간 비교 중 `git stash`로 작업 트리 전체(사용자 미커밋 frontend 변경 포함)를 잠시 stash했다가 즉시 pop했다.
  stash 목록 0, frontend·almanac 미커밋 diff 11 files +1383/−620이 그대로임을 확인했다.

### C4c 결과

- 59개 항목 추가(누적 **134**): basic skill/level bank(S3b)/relationship(S4)/star/combat(S2), 무기 basic(S2 무기 보고서),
  무기 성급 cyan 색상 gate(`kind="hue"` 160~230°), 장비 basic(S3/S3b), 장비 메뉴·favorite·empty dot(F7), D2 T10 추론(D2).
- **X22·X23 값이 이름으로 드러났다**: `student.relationship.whole_bank.score/.margin`(.38/.005),
  `student.weapon.basic.digit.score`(.57), `student.weapon.basic.whole_bank.score`(.49), potential `zero_correction.*`,
  D2 `student.equipment.d2.*`. D2의 "normal tier" 상한은 메뉴 tier 기준 `student.equipment.menu.tier.score`(.60)와 같은 항목을 공유해
  두 결정이 묶여 있음을 보이게 했다. 로비 3px·`EQUIPMENT_SLOT_*` 2560 절대좌표는 float 임계가 아니라 C7 표에서 다룬다.
- 허용 목록 추가: 2개 미만 순위 margin fallback `0.0`, 신뢰도 clamp·보수 `1.0`, star 잔차→신뢰도 스케일 `.35`,
  normalized correlation 0-분모 guard, synthesized tier 가중치 `.85/.15`.

### C4 완료 판정

- 범위 14개 파일에서 **등록 안 된 임계 리터럴 0건**(검사기 `test_recognition_thresholds_c4`, 허용 목록 20항목 명시·stale 검사 포함).
- golden diff **0**(C4a~C4c 매 slice), Python 559 OK.
- Flutter: analyze 기존 info 2건. test 403 pass / 4 fail → 4파일 단독 재실행 22 pass / 2 fail, 모두 real-process E2E의 첫 요청
  10초 timeout. **발견 C4-1**: backend 첫 응답까지 5.5초이며 `build_scanner_service`(6.4s)가 템플릿 773장 decode·asset hash 검증에
  쓰인다(cProfile). C3/C4 코드(레지스트리 조회·ScanContext)는 프로파일에 나타나지 않아 회귀가 아니라 **기존 기동 지연이 병렬 E2E 부하에서
  드러난 것**으로 판단했다. 템플릿 lazy load는 C6(모듈 import 시점 전역·초기화 정리) 후보.
- 변경 금지 확인: 모든 항목은 기존 리터럴과 같은 float(검사기가 대상 파일에 리터럴이 남지 않았음을, golden·기존 benchmark 테스트가
  동작 동일성을 확인).

### 다음 행동

- C5는 동작 변경 phase이고 실게임 1280(재고 세 프로필 tail 포함)이 필요하다. 착수 전 **C2-1 결정**(prepare가 카테고리 필터를
  걸지)과 C0-1(기술 노트·선물 전량 skip)의 처리 방향을 사용자와 정한다.

## C5 — 인식 공통화 (동작 변경)

시작 `43c17b5`. 게임 1280(사용자가 띄움). 사용자 결정(2026-09-26): **C2-1 스캐너가 프로필 카테고리를 체크**, C0-1은 권장안 —
C5에서 gate **로직**을 고치고 값 변경은 C7. F9 "선택이 안 보이면 입력 금지" 규칙은 **유지**(사용자: v6처럼 1행 겹침으로 선택을
다음 페이지에 보이게 하는 방식을 권장).

| Slice | 항목 | 상태 |
|---|---|---|
| C5a | C2-1 카테고리 필터, C0-1 gate, 탭 전환 검증, 실패 시 메뉴 취소, 스크롤 전 선택 anchor | **완료** |
| C5b | 오프셋 인식 grid(실제 픽셀 이동 측정): X20 행 overlap, C2-2 1행 미만 tail, 스크롤 후 선택·클릭 정렬, X07 실게임 | **완료** (실게임 1280 세 프로필 tail·취소·학생 회귀) |
| C5c | X15 이미지 유틸 공통화(`_normalized_correlation` 두 변형 이름 분리, private import 제거) | 미착수 |
| C5d | X18 상세 복구를 `StudentPanelRecovery` 계약에 정렬 | 미착수 |
| C5e | X19 재고 수량을 `StudioNumericBank` 경로로(사용자 정답·세션 보정) | 미착수 |

### C5a 결과

- **C2-1**: item prepare = 메뉴 열기 → `filter_tab` **활성 확인** → `filter_reset_button` → 모든 상자 회색 'all' **확인** →
  프로필 카테고리 클릭 → 그 상자만 'selected'·나머지 10개 'empty' **확인** → `sort_tab` 활성 확인 → 정렬 관측 → 확인.
  상자 상태는 청록 체크 비율/회색 체크 비율로 판정(실측 selected .375, 전체 회색 .19, empty 0). 판정에 쓰는 코인·소모품·수집품·
  제조 재료·그 외 상자 5개와 `filter_cancel_button`을 region 자산에 추가(매니페스트 갱신). allowlist에 reset·카테고리 6개·cancel 추가.
  **실패하면 항상 `filter_cancel_button`(취소)을 cleanup 입력으로 눌러 표시 설정을 바꾸지 않는다.**
- **안전 사고 1건(실게임)**: 메뉴는 마지막 탭(정렬)으로 다시 열리는데 첫 구현은 `filter_tab` 클릭이 먹혔는지 보지 않았고, 그 사이
  reset 좌표 클릭이 정렬 탭의 "사용 기간" 라디오에 떨어졌다. 곧이어 실패 경로의 취소로 변경은 적용되지 않았고 정렬은 `기본` 그대로임을
  재확인했다(`debug/scanner_c5_live/safety/`). 이후 탭 활성(흰색 비율 ≥ .5, 실측 .90/.93 vs 0)을 확인하기 전에는 탭별 클릭을 하지 않는다.
  또 reset 직후 카테고리를 누르면 reset 애니메이션이 덮어써서, reset 상태 확인 후 클릭한다.
- **C0-1 gate**: 전역 매칭이 프로필 밖 identity를 가리켜도 margin이 `inventory.grid_icon.margin` 이상일 때만 skip한다(값 불변, 로직 변경).
  근본 원인도 확인했다: 번들 템플릿은 **아이콘 원화(어두운 배경)**이고 실제 타일은 등급 색 카드 배경·수량 글자라 전체 이미지 유사도가
  배경에 지배된다 — 프로필로 제한해도 기술 노트 45종 전부 `SkillBook_Ultimate_Piece` ~.65/margin≈0. 따라서 카테고리 필터 후 대부분의
  슬롯은 **상세 패널로 식별**된다(느리지만 정확). 빠른 grid 식별기는 C5e 은행 작업과 함께 다룬다.
- **실게임 결과** `debug/scanner_c5_live/tech-notes-full`: 카테고리·탭·정렬 모두 확인, **1페이지 20종 전부 정확한 identity와 수량**
  (예: Hyakkiyako_0 ×2365, Abydos_0 ×3994; 상세 패널 margin 대 .4~.5). 2페이지 첫 상세 읽기에서 `inventory_restore_failed`로 중단 — C5b 대상.
- **스크롤 전 선택 anchor**: 사용자 권장 방식대로 스크롤 전 현재 페이지 마지막 채워진 슬롯을 선택해 다음 페이지에 보이는 선택을
  남긴다(F9 규칙 유지). 단 drag 후 행이 슬롯 격자와 **1행 미만 어긋나** 선택 판정이 틀린 슬롯/None을 준다(2페이지 실패 원인).
- **정밀 스크롤 실측(C5b 근거)**: drag 끝에서 0.35s 고정 후 놓아도 이동이 선형이 아니다(첫 페이지 기준 150px→165, 200→235,
  250→306, 304→178). 입력으로 행 정렬을 보장할 수 없으므로 C5b는 **스크롤 후 실제 픽셀 이동을 측정**(세로 상호상관, 정답 위치 평균차 4~5)해
  슬롯 region을 행 위상만큼 옮기고, overlap·tail·무이동을 그 측정으로 판정하는 설계로 간다(X20·C2-2·다중 페이지 선택을 함께 해결).
  실험용 drag hold 코드는 되돌렸다.
- replay: tech_notes 시나리오에 C5 실측 메뉴 프레임(정렬 탭으로 열림·필터 탭·reset·기술 노트 선택)을 합성해 prepare 경로를 고정했다.
  replay에는 슬롯 선택 프레임이 없어 두 재고 golden은 첫 상세 읽기에서 멈춘다(`inventory_detail_unconfirmed`/`inventory_selection_unknown`) —
  **의도된 golden 재고정**, 실제 검증 근거는 실게임 trace.
- 검증: Python 564 OK(+5: 탭 확인·카테고리 실프레임·유일 선택·reset 대기/취소·near-tie gate).

### C5b 결과 (구현, 실게임 대기)

- `InventoryNavigation.measure_shift`: 목록 viewport(새 region `list_viewport`: item y .2083–.8472, equipment .2083–.9583, 실측 150–610/150–690px)
  안의 회색조 세로 상호상관으로 **실제 위쪽 이동(px)과 잔차**를 잰다(1/2 축소 탐색 후 ±4px 정밀, 약 0.05s). 기존 기록 전부에서 정확:
  F10 fixture 112/31/110/112px, F10이 `reject_ambiguous_overlap`으로 거부한 쌍 **110px(잔차 2.37)**, C2 기술 노트 tail **29px**,
  C2 선물·장비 모호 지점 110/112px, 동일 프레임 0px. 잔차는 좋은 이동에서 0.7~9.1.
- `advance`는 drag 후 측정한 이동을 `PageMove(frame, shift)`로 돌려준다. 잔차 > `inventory.shift.max_residual`(20)이면
  `inventory_scroll_unverified`, 이동 ≤ `inventory.shift.no_motion`(≈3px)이면 한 번 더 drag하고 두 번째도 무이동이면 `verified_no_motion` 종료.
  **histogram 행 overlap(X20)·tail residual 판정·`confirm_terminal`은 제거**했다. 1행 미만 tail(C2-2)은 평범한 이동으로 읽히고, 그 뒤의
  무이동 확인이 X07 재확인 역할을 항상 한다. 레지스트리에서 `inventory.scroll.no_motion_same`·`overlap_score`·`tail_residual_floor`·
  `overlap_margin.*`를 제거하고 `inventory.shift.*` 두 항목을 추가했다(C4의 "같은 프레임" 셋 중 .97은 이 결정으로 대체).
- `page_slots(source, offset)`: 누적 offset에서 **정수 행 + 위상**으로 슬롯 region을 옮겨, viewport 안에 완전히 보이는 타일만
  `content index → region`으로 준다. offset 0은 기존 격자와 정확히 같다. adapter는 content index로 evidence·`observed_slot`을 매기고
  `read_until` 이후만 읽으며, **새로 보이는 첫 index가 연속이 아니면 `inventory_scroll_unverified`**(건너뛴 행을 조용히 잃지 않음).
- 상세 복구 `selected/same_grid/observe_selection/select/anchor/resolve`가 옮겨진 슬롯(`slots`)을 받는다 — 스크롤 뒤에도 선택
  판정·클릭·복귀 확인이 실제 타일 위치에서 이뤄진다. F9 "보이는 선택 없으면 입력 금지" 규칙은 그대로다.
- 정밀 drag 실험(drag hold)은 입력만으로 행 정렬이 안 돼 되돌렸다(C5a 기록). 측정 방식이라 drag 거리는 기존 `scroll_track` 그대로다
  (drag당 약 1.08행, 목록 9행이면 약 5회).
- replay: 두 재고 golden은 첫 페이지 상세 읽기에서 멈춰(선택 프레임 없음) **변화 없음** — C5b 경로는 단위 테스트(측정 이동·무이동 종료·
  잔차 초과·tail 후 무이동·행 건너뜀)와 실프레임 이동 측정 테스트가 고정한다.
- 검증: Python 전체 565 OK. **실게임 미검증**: 확인 시점에 게임 창이 최소화되어(`status: minimized`) 입력을 보내지 않았다.

### C5b 실게임 1280 결과 (2026-09-26, 사용자가 창 복원)

| 실행 (`debug/scanner_c5_live/`) | 결과 |
|---|---|
| `tech-notes-full-c` | **완료**. 기술 노트 **45/45** identity·수량(예: Hyakkiyako_0 ×2365 … Ultimate_Piece ×71). 이동 108×4 → **31px tail** → 무이동 2회 = `verified_no_motion`(**X07 재확인 실게임 실행**). 정렬 확인, `scan_coverage ok`, zero-fill 0(카탈로그 45종 모두 보유) |
| `presents-full` | **완료**. 선물 **56종 관측 + 19종 zero-fill**(말단·순서 검증). 이동 ~110×7 → 2px×2(무이동) |
| `equipment-full` | 말단 도달. **95종** 관측(이전 실행에서 조각 아이콘으로 잘못 skip된 Necklace T4·Gloves T1 등 포함). 이동 110~114×15 → **45px tail** → 무이동. `partial`: 수량 판독 불가 4건(강화석 `25K/27K/29K` 표기 등, 추정 없음) + 범용 설계도 9칸·104번(상세 패널 identity 없음) → zero-fill 없음 |
| `equipment-cancel` | `cancelled`, 보존 후보 partial, zero-fill 없음, 메뉴 열린 채 남지 않음 |
| `student-single` | 학생 목록에서 진입 클릭 1회 → mika 단일 스캔 전 필드 확정, review 없음, 3.1s(**학생 회귀 통과**) |

실게임에서 드러나 고친 것(모두 이 slice 안):
- **anchor 기반 정렬**: 측정 이동을 누적하면 5회 후 약 3px 어긋나 선택 테두리 판정 허용폭(수 px)을 벗어났다. 이동 후 스크롤 전에 선택해 둔
  anchor 타일이 감지되는 보정 창(±10px)의 중앙으로 offset을 다시 맞춘다(evidence `scroll_alignment`, 실측 창 예: −2..2, −1..3).
- **판독 가능 여백**: viewport 가장자리 8px(`list_viewport.edge_margin`) 안쪽 타일만 판독 대상으로 한다(아래 행 선택 테두리가 패널에 잘림).
  목록 말단에서 한 번도 판독 가능해지지 않은 채워진 타일이 있으면 `inventory_scroll_unverified`로 실패한다(조용한 누락 금지).
- **anchor 행**: 맨 아래 판독 행 대신 그 위 행을 anchor로 쓴다(맨 아래는 오차에 따라 테두리가 잘림, 1행 drag 후에도 위 행은 보임).
- **same-grid 예외**: 선택 상태가 바뀌는 타일은 내부 색도 변한다(선물 .972 < .975) — 기대/현재/기준 선택 타일은 페이지 동일성 비교에서 제외,
  나머지 타일이 페이지를 검증한다.
- **선택 테두리 위치 허용**: 위/아래 band를 ±3px 범위에서 가장 강한 위치로 읽는다(장비 첫 페이지 .14 → 검출). 값(.15)은 그대로.
- **식별 규칙(C0-1 후속)**: 번들 아이콘은 현재 타일과 맞지 않아(기술 노트 전부 한 아이콘, 장비는 자기 조각 아이콘에 .80) **상세 패널이 있는
  프로필 스캔은 grid만으로 skip·명명하지 않는다** — 전역 outside gate와 grid fast path를 끄고 상세 identity가 프로필 카탈로그에 있어야 기록한다.
  item 페이지는 검증된 카테고리 필터가 소속 근거. 상세 패널이 identity를 못 주면 기록하지 않고 `partial` evidence + review(zero-fill 금지).
  상세 패널이 없으면 F12 gate가 그대로 적용된다(`test_inventory_profile_never_relabels_a_confident_foreign_item` 통과).
- 검증: Python 566 OK. Flutter 402 pass / 4 fail → 4파일 단독 24/24(부하 timeout, C4-1). golden: 재고 2개 재고정(첫 슬롯부터 상세 패널 경로).

발견(다른 slice/phase): **C5-1** 장비 페이지 범용 설계도(조각)는 상세 패널 identity가 없어 장비 스캔이 항상 partial — 조각 식별 또는
카탈로그 결정 필요. **C5-2** 강화석 `25K` 같은 축약 수량은 상세 패널 판독 불가 → C5e(수량 은행) 대상. **C5-3** 상세 패널 판독이라
느리다(장비 105칸 약 10분) — 빠른 grid 식별기는 C5e에서 현재 UI 기준 은행으로.

### 사용자 방향 결정 및 사전 실험 (2026-09-27, 오케스트레이터 세션)

- 사용자 판정: C5b의 "모든 슬롯 상세 패널 + 1→N→1 복귀"는 정확하지만 방법론적으로 퇴보(batch가 기본이어야 함). C5c~C5e를 워크플로
  문서의 새 표대로 재정의했다. C5b의 정확도·안전 규칙은 유지한다.
- 기록 프레임만으로 실험(게임 입력 없음): `docs/migration/scanner-consolidation/c5e-experiments-2026-09-27.md`,
  스크립트 `debug/scanner_c5e_experiments/`.
  - E1 gutter 위상: `tech-notes-full-c`/`presents-full`/`equipment-full` 28 페이지 프레임에서 pitch 101px, anchor 클릭 대비 ≤1.5px, 13~23ms.
  - E2 지표: 타일 crop 템플릿 + 채널별 NCC(아이콘 영역) → tech notes 100%/margin min .016, presents 100%/.282, equipment 99.4%/.003.
    C0-1의 근본 원인은 원화 템플릿 도메인이며, 그리드 식별 자체는 가능하다.
- 코드 확인: `_read_slot`의 `detail_required`(`scanner_matchers.py:1419`)가 참이면 `user_templates`로 fast_confident가 나와도 무시된다 —
  학습된 은행이 identity 결정에 기여하지 못하는 구조. C5e-2에서 완화한다.
- 1→N→1 복귀는 `inventory_detail_recovery.resolve:231-247`의 구현 선택이며 F9 불변식이 요구하지 않는다(C5d에서 배치화).
- 다음 세션 시작점: 워크플로 재개 지점 참조. C5c 착수 전에 상세 경로가 끝까지 도는 재고 replay 시나리오 1개를 추가한다.
- 추가 결정(2026-09-27): C5-1(조각·범용 설계도)과 미보유 이벤트 선물의 상세 템플릿 부재는 **C5e-6**으로 다룬다 — E3(asset 원화→상세 템플릿) 실험,
  카탈로그·템플릿의 asset/DB 파생, 사용자 라벨링 폴백. 장비 identity는 상세 패널 카테고리 라벨×T 배지를 1차 키로(C5e-4). D13~D15 추가.
- 추가 결정(2026-09-27): C5e-6은 **asset 원화 + 레이아웃 지식 기반 템플릿 생성기**(해상도별 그리드 타일·상세 아이콘·학생 화면)로 확정.
  글자는 합성하지 않음. 합성 타일의 그리드 은행 편입은 E4(보유 아이템 합성-실물 M4 비교) 통과 프로필로 제한(D16).
  C5e-6c 리뷰 UI 변경은 이 워크플로 안에서 허용(사용자 승인).
- 2026-09-27 (오케스트레이터): JP 클라이언트에서 템플릿 생성 명세 추출 완료 — NGUI 2960×1440, 스케일 법칙 `s=H/round(2960·H/W)`(1280×720 → .43243),
  아이템/장비 타일·상세 패널·학생 화면 위젯 기하, 아틀라스 스프라이트(Card_Item_Bg_N/R/SR/SSR 등), 아이콘 텍스처(304×240 BC7).
  E3(상세 9/9)·E4(그리드 top-1 99 %, 정답 점수 med .975) 통과. 산출물은 워크플로 C5e-6 항목 참조.
  **Opus 전제 변경**: C5e-6 생성기 구현은 Opus 범위에서 제외. Opus는 생성된 템플릿이 인식 자산에 있다는 전제로 (c)(d)(e)(f)만 한다.
  남은 외부 입력: ItemExcelTable.Rarity(등급 표). 실패 사례 `SkillBook_Ultimate_Piece`(KR/JP 아트 차이 의심)는 D17로 등록.
- 2026-09-27 (오케스트레이터, 후속): Steam ExcelDB.db를 공개 키로 복호화·FlatBuffers 디코드해 `backend/assets/recognition/spec/item-rarity-v1.json`
  (items 1068, equipment 200, Rarity/Category/NameKr·Jp) 확보. E4 등급 적용 재실행 top-1 100 %. 생성기 외부 입력 없음.
  D18: 인벤토리 설계도 아이템은 `*_Piece` identity — 카탈로그 명명 정리 필요.
- 사용자 결정(2026-09-27): 템플릿은 **런타임 생성**(asset 팩 배포 + 스캔 시 합성·캐시, D19). 텍스트는 현재 캡처 은행만 사용 중이며 생성은 seed/3차 키로 제한(D20, E5 대기).
- 2026-09-27 (오케스트레이터, E5): 폰트 렌더링 실험 완료. **KR 클라이언트 UI 폰트는 GyeonggiTitle(MainFont/MainFont_Bold)** — Steam 카탈로그 `ui/font/bundlefontkr`,
  Preload 번들 `prologdepengroup-assets-_mx-uis-_mxcommon-_mxprolog-2024-11-18_*`. JP의 LINE Seed KR은 글리프가 달라 사용 불가(D17 폰트 예외).
  Gyeonggi Bold, em 20px @720p, shear .10, 팽창 .5px로 문자열 top-1 100/100이나 margin min .001 → 단독 키 금지, `StudioNumericBank` synth seed 계층으로만(D20 확정).
  명세 §8·JSON `fonts` 블록 추가. Opus 영향: C5e-3에 synth 계층 로더(우선순위 최하위 + 프로필 gate) 1항목 추가, 나머지 전제 불변.
- 2026-09-27 (오케스트레이터, asset 팩): KR/Steam 클라이언트에서 배포 asset 팩 추출 완료 — `backend/assets/recognition/asset_pack/`
  (아이콘 1068+200 `icons-01..03.zip`, KR 아틀라스 스프라이트 12 + 설계도 배경 `Card_Item_Bg_C`, GyeonggiTitle 폰트 2, `manifest.json` sha/출처).
  KR/JP 프리팹 기하 동일 확인(아틀라스 rect·폰트만 다름). E4 재실행 KR 팩 top-1 100 %.
  **C5b 오라벨 발견**: `tech-notes-full-c` 슬롯 44 `SkillBook_Ultimate_Piece` → 실물은 `SkillBook_Ultimate`(D18 갱신). Opus는 C5e-4에서 아이템 `_Piece` 매핑과
  golden 기대값을 ExcelDB id 기준으로 재검한다. 추출 도구 `backend/tools/asset_spec/ba_extract_pack.py`.
- 2026-09-27 (오케스트레이터, 워크플로 확정): C5e-6을 6a(생성기)·6b(캐시·드리프트)·6c(로더 계층+D18 교정)·6d(상세 폴백 순서)·6e(라벨링 UI)·6f(E4 gate 확장)로
  분해해 워크플로에 계약·완료 조건을 적었다. 오케스트레이터 입력(명세·팩·등급표·폰트·E1~E5)은 모두 확보됐고, 이후는 Opus가 C5c부터 재개 지점 순서대로 진행한다.
  다음 세션: **C5c** (착수 전 상세 경로 replay 시나리오 1개 추가, 슬롯 44 기대값 `SkillBook_Ultimate`).
- 2026-09-27 (오케스트레이터, E6 실게임): 스크롤 입력 실험. 결정론적 드래그(priming 8px + 목표 거리 + 정지 .2s) 확정 — 이동량 = 요청량, 위상 보존 ≤2px,
  릴리스 즉시 정착. 스크롤바는 숨김·비활성(폐기), 휠 tick은 가변(맨 위 복귀에만). C5e-1 항목을 이에 맞게 갱신(레지스트리 신규 3항목). 실험 기록 E6 절.
- 2026-09-27 (오케스트레이터, E6 추가): 백그라운드/최소화 입력은 불가로 확정(08-26 실측 + 타입 덤프: UICamera→Unity raw-input 마우스). 대안으로 입력 버스트 + 입력 가드(D21)를 C5e-1에 추가.
  타입 덤프 확인: `UICamera.mouseDragThreshold`(4px), `UILabel.UseKiloFormat`(K는 ≥10,000 정수), `Card_Amount` overflow = ResizeFreely(글자 크기 불변). 스크롤바 폐기 유지.
- 2026-09-27 (오케스트레이터): 사용자 결정 — 그리드 스캔은 포그라운드 유지, 입력 버스트 폐기(D21 축소). 학생 스캔 백그라운드 키 탐색은 `press_key` 순서 변경으로 C5f 신설(게이트: `backend/tools/probe_background_key.py` 사용자 실행 결과).
  4:3 예비 관찰: 같은 폭이면 s·타일·pitch 동일, 세로 앵커만 이동 → D22 레이아웃 리졸버(프리팹 앵커 기반 ROI). 게임 옵션은 4:3/16:9만.
- 2026-09-27 (오케스트레이터): C5f 게이트 통과 — PostMessage 방향키가 백그라운드에서 소비되고 포그라운드 불변(probe 2회). C5f 구현 항목 확정(키 우선·프레임 확인·클릭 폴백만 잠깐 포그라운드 후 복원). D22(4:3)는 보류.
- 2026-09-27 (오케스트레이터, 정렬): 정렬 규칙 반영 현황 점검 — X09(기본 정렬 강제)·카탈로그 `order_index`·`verify_profile_order`(사후 단조 검사, zero-fill gate)는 있음. 식별 단계의 사전(prior)으로는 미사용 → C5e-2에 "order prior" 추가.
  게임 기본 정렬 로직은 `ItemSortingService.GetDefaultSortingOrder`(타입 덤프에 이름만)라 ExcelDB 컬럼만으로 재현 안 됨(기술 노트 T1 6001x가 학교 그룹 안에 정렬됨). 현재의 실측 기반 `order_index` 유지.
  D18 원인: `inventory_catalog.py`가 `SkillBook_Ultimate_Piece`를 "비의서"로 등록(실제 9998=비의서 조각, 9999=비의서).
- 2026-09-27 (오케스트레이터): 사용자 우려(신규 아이템 시 정렬 사전 고장) → D23 추가: 사전은 좁히기만, 실패 시 전체 은행→합성 상세(팩 전체)→라벨링으로 강등, LIS 기반 단조 검사, 카탈로그 identity는 ExcelDB 파생·순서만 관측 계층.
- 2026-09-27 (오케스트레이터): 정렬 규칙을 세 스캔(tech notes 45, presents 56, equipment 95)에서 귀납 — 기술 노트: 학교 enum × 티어↑(신형 T1도 학교 자리), 선물: 등급↑ × id↑, 장비: 강화석 등급↓ → 카테고리 × 티어↓(T2+) → 전 카테고리 T1 → 무기 성장. D23에 기록.
  신규 아이템 후보 우주는 프로필 필터 범주(ExcelDB ItemCategory/Tags)로 제한(사용자 제안) 후 팩 전체로 확대.
- 2026-09-27 (오케스트레이터, 배포): 사용자 결정 — 게임 자산 비배포, 최초 실행 시 Steam 설치 폴더에서 로컬 추출(D24, 6a-0 추출기 신설). asset_pack 바이너리는 개발용 git-ignore 경로 유지, manifest는 정답지. 1차 Steam/KR만, JP·다국어는 D22와 함께 후순위.
- 2026-09-27 (오케스트레이터, D24 확정): 클라이언트 로컬 추출은 키 불필요 파일(카탈로그·아이콘·스프라이트·폰트)만, ExcelDB 파생 등급표는 배포자 갱신 스냅샷. 스냅샷 미포함 아이콘은 4등급 합성 + 스캔 시 등급 판정. 배포자 유지보수 항목: 게임 업데이트마다 `fb_excel.py`로 `item-rarity-vN.json` 재생성(D23(4) 절차와 함께).
- 2026-09-27 (오케스트레이터): 6a-0/6b를 증분 갱신으로 명시 — 추출은 번들 sha 단위, 합성 캐시는 identity별 입력 sha 튜플 단위로 변경분만 재생성(사용자 결정).
- 2026-09-27 (오케스트레이터, E8): 합성 템플릿은 해상도별 저장 없이 정규화 한 벌(D25, 720p 검증 top-1 100 %/p10 .949). 학생 화면 합성 범위 D26(장비·무기·별·숫자·스킬 아이콘; identity는 캡처 유지 + 이름 렌더 E9 예정). 오케스트레이터 남은 입력: 무기·스킬 아이콘·이름 localize 카탈로그 키 규칙.


### C5c 착수 전 작업 (2026-09-27, Opus)

사용자 결정: 상세 경로 replay는 **현재 코드로 새로 녹화한 기술 노트 실행**, 프레임은 **로컬 전용**(sha 고정, 없으면 테스트 skip),
슬롯 44는 **D18 매핑을 지금 교정**.

- **D18 교정**: 비의서는 ExcelDB 9999 `Item_Icon_SkillBook_Ultimate`, v6가 비의서 조각(9998) 아이콘 이름 `*_Ultimate_Piece`로 잘못 부르고 있었다.
  상세 아이콘 템플릿(비의서 노트 그림)과 이름 템플릿("비의서")이 실물과 같음을 asset 팩 아이콘과 대조해 확인했다. 카탈로그 항목,
  상세 아이콘·이름 템플릿 파일명과 `identity_value`, `item_regions.json`·`inventory_detail_f9_regions.json`의 tech_notes 배경 규칙을
  `Item_Icon_SkillBook_Ultimate`로 바꾸고 매니페스트 sha를 갱신했다. 저장 인벤토리·v6 가져오기의 구 키는
  `inventory_catalog.LEGACY_RESOURCE_KEYS` → repository rebase·스캔 commit upsert·계획 alias에서 새 키로 옮긴다(중복 생성 없음, 테스트 추가).
  `CATALOG_REVISION` 변경 → `contracts/fixtures/inventory_catalog_v6_parity.json` revision 갱신, 재고 golden 2개는 `catalog_revision` 줄만 diff로 재고정.
  실제 비의서 조각은 기술 노트 목록 소속이 검증되지 않아 카탈로그에 넣지 않았다.
- **D18 재검(ExcelDB 기준)**: 엘레프를 제외한 카탈로그 키 전부가 `item-rarity-v1.json`에 있고 한국어 이름이 일치한다. 엘레프 258종은 학생 slug
  기반 키라 ExcelDB 아이콘 이름과 체계가 다르다 — 오라벨이 아니라 C5e-6 합성 시 매핑이 필요한 명명 차이로 기록한다.
- **잠긴(locked) replay**: `scanner_consolidation_replay.LockedReplayCapture` — 실게임 녹화(`verify_inventory_c2_live.py` trace)의 캡처를 순서대로
  주고, 코드가 보내는 입력이 녹화와 하나라도 다르거나 남거나 모자라면 `ReplayDivergence`로 실패. 시나리오 `replay: "locked"`,
  `frames_local_only: true`면 프레임이 없는 PC에서 skip, 있으면 pixel sha로 검증. `debug/scanner_c5_replay/**/frame-*.png`는 `.gitignore`.
- 남은 일: 게임을 1280 아이템 화면으로 띄워 기술 노트를 녹화 → 시나리오·golden 추가 → C5c.

### 상세 경로 locked replay (2026-09-27)

- 게임 1280 아이템 화면에서 `3533b11` 코드로 기술 노트를 새로 녹화(`debug/scanner_c5_replay/tech-notes-detail/`, 캡처 220·이벤트 327).
  결과 45/45, **슬롯 44 = `Item_Icon_SkillBook_Ultimate` ×71**(D18 교정 확인), 말단 검증·순서 확인 `scan_coverage ok`.
- 시나리오 `inventory_item_tech_notes_detail_locked_1280`(`replay: locked`, `frames_local_only`, trace sha 고정): 재생이 녹화 이벤트
  327개를 입력 하나 틀리지 않고 전부 소비함을 확인하고 golden을 고정했다(`72feb3f`). trace.json만 추적, 프레임 PNG는 `.gitignore`.
- replay cancel 토큰(`ReplayCancel`)은 대기를 즉시 반환해 시간만 줄인다(기존 8개 golden same). 남은 재생 시간 ~110s는 순수 파이썬 NCC 비용 —
  바이트 보존이 필요한 동안 numpy 전환은 하지 않는다(런타임 의존성은 Pillow뿐, `pyproject.toml`).

## C5c — 이미지 유틸 공통화 (X15, 동작 보존) — 완료 (2026-09-27)

- `core/recognition_image_ops.py`: 모듈 간 private import 대상이던 이미지 연산을 **AST로 원문 그대로 추출해** 옮겼다 — `pixels`,
  `ncc_signed_lanczos`(구 weapon `_normalized_correlation`: 회색, 템플릿 크기로 LANCZOS, 부호 있음 [-1,1]), `color_similarity`,
  `ncc_unit_bilinear`(구 equipment `_normalized_correlation`: crop 크기로 BILINEAR, [0,1]), `mean_difference`, `mask_from_predicate`,
  `normalize_mask`, `binary_iou`, `otsu_binary`, `ncc_difference_score`. 산술·평가 순서 동일.
- E2 **M4** `ncc_per_channel_icon`(타일 아이콘 영역 x 12–88 %·y 6–76 %, 48×48 BILINEAR, 채널별 NCC 평균)을 추가. 아직 인식에 쓰지 않는다(C5e-2).
  런타임이 Pillow 전용이라 순수 파이썬 구현이다(쌍당 수 ms). C5e-2 fast path 속도가 부족하면 numpy 의존성 추가를 그때 사용자 결정으로 올린다.
- 인식기 전용 도우미는 `student_scan_recognizer`의 공개 이름으로(`rank_glyph`, `skill_ui_feature`, `skill_text_feature`).
- core 모듈의 **다른 모듈 private import 0건**(AST 확인). 옛 private 이름은 원 모듈에 alias로 남겨 tools/tests 호환(C6에서 제거) —
  `test_recognition_image_ops_c5c`가 alias가 이동한 함수와 동일 객체임을 고정.
- C4 검사기: `recognition_image_ops.py`를 대상에 추가, 0-분모 guard 허용 항목을 equipment에서 옮김.
- 검증: Python 567+3 OK(golden 9/9 same — **locked 상세 경로 replay 포함, 입력 327개 동일**). Flutter 377 pass / 5 fail → 5파일 단독 25/25(C4-1 부하 timeout).
- 다음: **C5d** 배치 선택(동작 변경).

## C5d — 배치 선택 + X18 계약 정렬 (동작 변경) — 완료 (2026-09-27, 시작 `8e35f72`)

- 계약(`StudentPanelRecovery`의 open/restore 대응): `begin_page(target, cancel, frame, slots)` → `read(...)` × N → `end_page(target)`.
  `begin_page`는 페이지의 보이는 선택을 기록(안 보이면 관측, 없으면 입력 없이 실패), 열린 세션이 있으면 `inventory_page_active`.
  `read`는 필요할 때만 클릭(이미 선택된 슬롯은 마지막 검증 프레임으로 읽음), 성공 프레임이 새 baseline.
  `end_page`는 새 cleanup 토큰으로 **선택을 먼저 관측(F9 a·b)**하고 원선택과 다를 때만 복귀 클릭 — 페이지당 한 번.
- 재시도: 클릭 후 3캡처 관측이 원선택(직전 선택)을 그대로 보이면(클릭 유실) 최대 2회 재클릭. 다른 슬롯이 선택되면 재시도하지 않는다.
  선택 미확인 → 그 자리에서 검증 복귀 → 결과 `stop=True` → 어댑터가 슬롯을 partial로 남기고 입력 중단(`failed`, 기존 entry 보존, zero-fill 없음).
  선택이 확인된 뒤 패널 읽기만 실패하면 슬롯 partial, 배치 계속(C5c까지와 같은 슬롯 결과).
- 어댑터: `_read_page`가 첫 상세 읽기에서 세션을 열고 `finally`에서 닫는다(취소·예외도 같은 경로). scroll anchor는 세션 밖에서 그대로(C5e-1에서 제거).
- `resolve()`(슬롯마다 선택→읽기→복귀)는 제거. 호출자는 어댑터와 F9 테스트뿐이었다.
- **빈 타일 판정(실게임에서 발견, 같은 slice에서 수정)**: 선물 첫 실행이 마지막 행(56번 1칸 + 빈칸 4)에서 빈 타일을 채워진 칸으로 보고
  클릭 → 선택 불변 3회 → `inventory_detail_unconfirmed`로 중단했다. `image_has_visible_content`는 캡처 여백(검정)만 거르고 빈 타일(단색 회색)은
  통과시켰다 — C5b까지는 모든 tail이 꽉 찬 행으로 끝나 드러나지 않았고, 걸렸다면 partial·review·zero-fill 없음이 됐을 잠재 결함.
  타일 안쪽(18~82 %) 회색 표준편차 ≤ `inventory.empty_tile.stddev`(**신규 8.0**, intensity, C5; 실측 빈칸 0.0·평균 204, 채움 최소 34.8)이면 빈칸.
  같은 함수를 쓰는 anchor 선택·`_require_tail_read`도 함께 바로잡힌다. 기존 임계값 변경 없음.

### C5d 실게임 1280 결과 (2026-09-27)

| 실행 | 결과 | 클릭(cleanup) | 캡처 | 소요 | C5b 대비 |
|---|---|---|---|---|---|
| 기술 노트 (`debug/scanner_c5_replay/tech-notes-detail-c5d`) | **45/45**, 슬롯 44 = `SkillBook_Ultimate`, `scan_coverage ok`, zero-fill 0 | 62 (6) | 99 | 130 s | 녹화 `3533b11`과 entry 45개 identity·수량 동일. 클릭 100→62, 캡처 220→99 |
| 선물 (`debug/scanner_c5d_live/presents-full`) | **56 관측 + 19 zero-fill**, `scan_coverage ok` | 77 (8) | 123 | 162 s | C5b와 entry 75개 동일. 클릭 128→77, 캡처 301→123 |
| 장비 (`debug/scanner_c5d_live/equipment-full`) | 95 관측, 말단 도달, `partial`(C5-1 범용 설계도 9칸·K 표기 수량 — C5b와 같은 사유) | 137 (16) | 272 | **205 s** | C5b 약 10분. 클릭 225→137, 캡처 916→272 |
| 장비 취소 (`equipment-cancel`, 30캡처 후) | `cancelled`, 보존 후보 partial, zero-fill 없음 | cleanup 1회로 원선택 검증 복귀 | 33 | 26 s | — |

- 장비 수량 차이 5건 중 4건(Exp_3 34, C_2 227, C_3 5, Z_1 1251)은 상세 패널·타일 표기와 일치 — C5b 이후 실제 보유량 변화.
  1건(`WeaponExpGrowthC_1` 상세 ×11223)은 `weak_digit_match`로 미확정(C5b는 ×11193 판독) → **발견 C5d-1**.
- 선물 첫 실행(빈 타일 결함)은 `debug/scanner_c5d_live/presents-full-failed`에 보존.
- 페이지 끝 복귀가 anchor 클릭 직전에 원선택으로 돌아가므로 페이지당 cleanup 1회 + anchor 1회가 남는다 — anchor는 C5e-1에서 제거.

### C5d golden

- 의도된 diff 3건(재고 golden 전부), 학생 golden 6/6 same.
  - `inventory_item_tech_notes_1280`, `inventory_equipment_1280`(화면 상태 replay): 정지 프레임이라 선택이 바뀌지 않는다. C5c까지는 슬롯마다
    클릭→미확인→복귀를 반복해 모든 칸을 partial로 남겼고, C5d는 원선택 슬롯 0을 클릭 없이 읽은 뒤 슬롯 1을 3회(1+재시도 2) 클릭하고
    `inventory_detail_unconfirmed`로 **입력 중단**(`failed`, entry 1개 보존, zero-fill 없음). 계약대로의 변화.
  - `inventory_item_tech_notes_detail_locked_1280`: 녹화를 C5d 코드의 실게임 기록(`tech-notes-detail-c5d`, trace sha `62f68e0f…`)으로 교체하고
    재생이 녹화 입력을 전부 그대로 소비함을 확인한 뒤 고정(45/45, 슬롯 44 Ultimate, coverage ok). 옛 녹화 trace는 비교 기록으로 남긴다.
- 검증: Python **576 OK**(C5d 테스트 +7: 순차 선택·한 번 복귀, 재시도 2회 뒤 중단, 다른 슬롯 선택 시 재시도 없음, 두 번째 세션 거부,
  읽기 실패 시 배치 유지, 어댑터 세션 1회 열고 닫기, 미확인 시 partial·입력 중단 + 빈 타일). Flutter는 변경 없음(프로토콜·코드 매핑 영향 없음) — 미실행.
- 미검증: 학생 단일 스캔 회귀(학생 코드 미변경) — C5e-1 실게임 검증 때 함께.

### C5d 발견 사항 (다른 slice)

- **C5d-1** (C5e-3): 장비 상세 5자리 수량 `x11223`이 `weak_digit_match` — 수량 은행 경로에서 다룬다.

### 다음 행동

- **C5e-1** gutter 위상 검출(`_align_to_anchor`·스크롤 전 anchor 클릭 대체). 실게임 1280 세 프로필 tail + 학생 단일 스캔 회귀.

## C5e-1 — gutter 위상 검출 (동작 변경) — 완료 (2026-09-27, 시작 `a775b05`)

- `InventoryNavigation.gutter_tops`: viewport의 그리드 x 범위에서 회색(198~210) 비율 ≥ .8 행의 band, viewport 경계에 닿는 band·길이 < 3px band 제외,
  band 끝 + 3px = 타일 상단(E1 그대로, Pillow만). `phase_residuals(frame, source, offset, calibration)`은 예측 행 위상과의 차이(px, ±반 행).
- 어댑터: 첫 페이지(offset 0)의 위상 차이 중앙값을 **보정값**으로 저장(gutter 끝과 slot region 상단 사이의 고정 거리). 이동 후에는
  보정값을 뺀 차이 중 중앙값 ±3px 안에 드는 gutter가 2개 이상이면 그 중앙값만큼 offset을 고친다. 2개 미만·보정값 없음·25px 초과는
  `inventory_scroll_unverified`. `measure_shift`는 행 수·끝 판정용으로 유지.
- 제거: 스크롤 전 anchor 클릭(`_anchor_selection`, `InventoryDetailRecovery.anchor`)과 21회 탐색(`_align_to_anchor`).
- **결정(C5e-1, C5d 계약 조정)**: anchor가 없으면 C5d의 "페이지 끝 원선택 복귀"가 선택을 첫 행으로 되돌려 다음 페이지에서 보이지 않게 만든다
  (F9 a 위반 → `inventory_selection_unknown`). 그래서 **정상 완료 페이지는 마지막 검증 선택을 유지**(`end_page(keep_selection=True)`, 입력 없음) —
  그 칸은 마지막 읽기 행에 있어 ~1행 drag 뒤에도 보인다. 원선택 검증 복귀는 실패·취소·예외 경로에 그대로 남는다.
- 신규 임계(C5): `inventory.gutter.grey_low` 198, `.grey_high` 210, `.row_ratio` .80, `.agreement` .0042(≈3px), `.max_correction` .035(≈25px).
- 녹화 대조(C5d 실게임 프레임, 입력 없음): 세 프로필 모든 페이지에서 band 간격 101px, 한 프레임 안 gutter 간 차이 ≤ 1.1px,
  첫 페이지 보정값 item −1.0 / equipment +1.5px.

### C5e-1 실게임에서 드러난 한 행 alias (같은 slice에서 수정)

- 첫 장비 실행이 **90/95**로 끝났다(Bag T8~T4 5종, evidence 없음). 원인: 여섯 번째 drag가 실제 111px 움직였는데 `measure_shift`가 **10px**를 돌려줬다
  (잔차 11.5 ≤ 20 통과). 격자가 행마다 반복돼 반 크기 탐색이 한 pitch(101px) 떨어진 골을 고르고, 전체 크기 정밀화는 그 주변 ±4px만 봤다
  (전체 크기 비용 111px 6.3 vs 10px 11.8). gutter 위상은 행 단위 오차를 볼 수 없고(±반 행), 다음 페이지는 행 55~59를 index 50~54로 읽은 뒤
  다시 읽은 55~59를 `_record_entry`가 **조용히 중복 제거**했다. 이 alias는 C5b부터의 잠재 결함이다(C5b anchor 검사는 `uncertain`만 남기고 계속했다).
- 수정 1 `measure_shift`: 반 크기 비용의 **국소 최소 3개**를 전체 크기에서 정밀화해 가장 낮은 것을 고른다. 같은 프레임 쌍 → 111px(잔차 6.6).
  native 테스트에 이 쌍(`debug/scanner_c5e1_live/equipment-full-alias/frame-96·108`, 커밋)을 추가.
- 수정 2(방어): 탐색 스캔에서 **같은 identity가 다른 content index에 다시 나오면** `inventory_scroll_unverified`(행 매핑 오류의 직접 증거) —
  중복 제거로 조용히 넘기지 않는다. zero-fill 스캔(선물 등)에서 누락이 0으로 기록될 수 있었던 경로를 막는다.
- alias 실행은 `debug/scanner_c5e1_live/equipment-full-alias`에 보존.

### C5e-1 실게임 1280 결과 (2026-09-27)

| 실행 | 결과 | 클릭(cleanup) | 캡처 | 소요 | C5d 대비 |
|---|---|---|---|---|---|
| 기술 노트 (`debug/scanner_c5_replay/tech-notes-detail-c5e1`) | **45/45**, 슬롯 44 Ultimate, `scan_coverage ok` | 50 (0) | 74 | 120 s | entry 동일. 클릭 62→50, 캡처 99→74 |
| 선물 (`debug/scanner_c5e1_live/presents-full`) | **56 관측 + 19 zero-fill**, `ok` | 61 (0) | 94 | 150 s | entry 동일. 클릭 77→61, 캡처 123→94 |
| 장비 (`debug/scanner_c5e1_live/equipment-full`) | 95 관측, 말단 도달, `partial`(C5-1·K 표기·C5d-1 — 같은 사유) | 105 (0) | 253 | 199 s | entry 동일. 클릭 137→105 |
| 학생 단일(미카, `debug/scanner_c5e1_live/student-single`) | 전 필드 확정, review 없음, 입력 1회 | — | — | 3.1 s | C5b와 값 동일(**학생 회귀 통과**) |

- gutter 보정 |correction| ≤ 1.0px(장비 15회·기술 노트 5회·선물 8회), 실패 0. 페이지 선택 유지로 cleanup 클릭 0, anchor 클릭 0.
- 누적 개선(C5b → C5e-1): 기술 노트 클릭 100→50·캡처 220→74, 선물 128→61·301→94, 장비 225→105·916→253(약 10분 → 199 s).

### C5e-1 golden

- 화면 상태 재고 golden 2건 **same**(슬롯 1 미확인에서 멈추므로 스크롤 경로에 닿지 않음). 학생 6건 same.
- locked 상세 경로: 녹화를 `tech-notes-detail-c5e1`(trace sha `964dbeb1…`)로 교체, 재생이 입력을 전부 그대로 소비함을 확인하고 고정.
- 검증: Python **582 OK**(+ gutter native 2, 어댑터 gutter 보정·위상 미확인·중복 identity, 선택 유지). Flutter 변경 없음 — 미실행.

### 다음 행동

- **C5e-2** 타일 은행 fast path(M4 ≥ .90·margin ≥ .015면 상세 생략, session bank). numpy 의존성 여부는 속도 측정 후 사용자 결정.

## C5e-1b — 결정론적 스크롤·겹침 검증·휠 복귀 (재정의된 C5e-1, 동작 변경) — 완료 (2026-09-27, 시작 `5efabba`)

오케스트레이터가 E6 결과로 C5e-1을 재정의했다(결정론적 드래그 + gutter 위상 **검증**, D21). `5efabba`까지의 gutter 위상·anchor 제거는 그대로 두고
나머지를 C5e-1b(스크롤 경로)·C5e-1d(D21 입력 가드)로 나눴다. (같은 시각 오케스트레이터 사본이 status의 C5c~C5e-1 절을 지운 채 저장돼,
HEAD 내용에 오케스트레이터의 새 기록 4줄을 합쳐 복원했다.)

- **드래그** `WindowsCaptureInputAdapter.drag_path`: 누름 → priming 8px → 목표 거리 3스텝 → 정지 → 뗌. 커서 이동은 **SendInput 절대 좌표 이동**
  (`MOVE|ABSOLUTE|VIRTUALDESK`) — `SetCursorPos`만으로는 클라이언트가 드래그로 보지 않았고(0px), 시작점이 목록 하단 경계(.836)면 무반응이라
  기존 `scroll_track.start_y`(.75)에서 시작한다.
- **정지 시간 실측(1280, 3행 305px 요청)**: .2s → +38~43px(관성), .35s → +10, .5s → +2.4, **.8s → 정확(±1px, 위상 드리프트 ≤1px)**.
  E6의 .2s와 다르다 — 레지스트리 `inventory.scroll.hold_s` = **.8**로 등록(사유 note). priming 8px, `phase_tolerance_px` 3도 등록(kind `pixels`/`seconds`
  신설, C4 검사기에 범위 추가).
- **k = 완전히 읽히는 행 수 − 1**(워크플로 공식): 아이템 4행 → **k=3**, 장비 5행 → k=4. (워크플로 괄호의 "아이템·장비 모두 4행"은 아이템에서 겹침 0이 되어
  공식을 따랐다.)
- **위상 중앙 정렬**: 첫 페이지는 윗행이 판독 경계에서 1px뿐이라, 첫 k행 이동이 겹침 행을 경계에 올려 선택 테두리가 잘렸다(실게임 `inventory_selection_unknown`).
  첫 이동을 (아래 여유 − 위 여유)/2만큼 짧게(아이템 21.3px, 장비 10.8px) 해 행을 판독 영역 중앙에 두고, 이후 이동은 그 위상으로 k행씩(`page_distance`).
- **끝 판정**: 요청보다 짧은 이동은 끝 근처 페이지로 읽고, 무이동 드래그 2회가 끝(X07 유지). 짧은 이동 자체를 끝으로 보지 않는다 — 측정 alias가 짧은 이동으로
  보이면 거짓 끝이 되므로.
- **겹침 행 identity 검증**(`overlap_identity`): 다시 보인 타일을 첫 판독 crop과 채널별 NCC(M4)로 비교, 유지 선택 칸 제외·2개 이상, 중앙값 ≥ `inventory.scroll.overlap_icon`(.86).
  녹화 대조: 같은 행 페이지 중앙값 ≥ .905, 한 행 어긋남 ≤ .814. 미달이면 `inventory_scroll_unverified`. `measure_shift`는 요청 거리 주변을 후보에 항상 넣는다.
- **gutter 위상**: 허용 3px 안이면 검증 통과(재캡처 없음), 밖이면 재캡처 후 재측정. 두 경우 모두 관측 위상으로 offset을 다듬는다 — 끝 페이지의 마지막 행이 판독 경계에서
  0.9px 안쪽이라, 다듬지 않으면 "tile 55 filled but never readable"로 실패했다(실게임, 안전 쪽 실패).
- **첫 페이지 복귀**: 휠 up N tick(N = ceil(행/5)+1 ≤ 10) → 스프링이 가라앉을 때까지(≤3s) 폴링해 첫 페이지 프레임과 `measure_shift` 0·잔차 ≤ 20이면 완료, 다른 곳에
  정착하면 10 tick 한 번 더, 그래도 아니면 `inventory_prepare_unconfirmed`. (첫 시도는 스프링 중 빈 목록 프레임을 안정 프레임으로 읽어 실패 → 폴링 추가.)
- **viewport**: spec(`ba-ui-template-spec-v1.json`)은 prefab clip이 런타임에 재앵커된다며 실측 viewport(.2083~.8472/.9583)를 싣고 있고 region 자산과 같다.
  soft clip 12 units(5.2px) < edge margin 8px. spec이 있을 때만 도는 일치 테스트 추가(spec은 미추적 파일).

### C5e-1b 실게임 1280

| 실행 | 결과 | 이동(요청→관측 px) | 캡처 | 소요 | C5e-1 대비 |
|---|---|---|---|---|---|
| 기술 노트 (`debug/scanner_c5_replay/tech-notes-detail-c5e1b`) | 45/45, `ok` | 3행 이동 2회 + 끝 확인 | 58 | 116 s | entry 동일, 캡처 74→58 |
| 선물 (`debug/scanner_c5e1b_live/presents-full-2`) | 56 + zero-fill 19, `ok` | 283.3→283, 304.1→304, 304.1→180(끝), 무이동 | 69 | 144 s | entry 동일, 캡처 94→69 |
| 장비 (`debug/scanner_c5e1b_live/equipment-full`) | 95, `partial`(같은 사유) | 393.3→393, 405.3→405, 405.3→406, 404.8→395, 무이동 | 129 | **142 s** | entry 동일, 캡처 253→129, 199→142 s |
| 복귀 probe (`restore-probe-2`) | 3행×2 이동 후 휠 복귀, 첫 페이지 유사도 .9999998 | — | 14 | — | — |

- 겹침 검증 중앙값: 기술 노트 .95/.99, 선물 .996/.999/.988, 장비 .944~.969. gutter 보정 |≤1.5px|.
- 실패 기록 보존: `presents-full-tail`(보정 생략 시 끝 행 판독 불가), `presents-full`(겹침 행 경계 → 선택 미확인), `restore-probe`(스프링 중 캡처).
- golden: 화면 상태 2건 same, 학생 same, locked 상세 경로는 `tech-notes-detail-c5e1b`(sha `ba2a7184…`)로 교체·재고정. Python **588 OK**. Flutter 변경 없음.
- 미검증: 학생 단일 스캔(학생 경로 무변경, C5e-1 때 통과) — C5e-1d 실게임 때 함께.

### 다음 행동

- **C5e-1d** D21 입력 가드: 저수준 훅(`WH_MOUSE_LL`/`WH_KEYBOARD_LL`)으로 주입되지 않은 사용자 입력을 감지해 해당 스텝 `input_busy` → 재시도 ≤ 2, 초과 시 partial.
  입력 삼킴 없음. 그다음 C5e-2.

## C5e-1d — D21 사용자 입력 가드 (동작 변경) — 구현 완료, 실게임 확인 대기 (2026-09-27, 시작 `c0b0e68`)

- `core/user_input_guard.py` `UserInputGuard`: 전용 스레드가 `WH_MOUSE_LL`/`WH_KEYBOARD_LL` 훅을 걸고 **주입 표시가 없는** 이벤트만 센다
  (`LLMHF_INJECTED`/`LLKHF_INJECTED`). 입력은 항상 다음 훅으로 넘긴다(삼킴 없음). 스캐너 입력이 30 s 없으면 훅을 풀고 스레드를 끝내며 다음 입력에서 다시 건다
  (스캔하지 않을 때 시스템 전역 훅을 남기지 않음).
- `WindowsCaptureInputAdapter`의 click·press_key·scroll·drag_scroll·drag_path는 한 입력이 한 **guarded step**: 사용자 입력이 `input.guard.idle_s`(.25 s)보다
  최근이면 기다리고, `input.guard.wait_s`(2 s) 뒤에도 바쁘면 보내지 않고 `input_busy`(`performed: false`); 보내는 동안 사용자 입력이 들어오면 보낸 뒤
  `input_busy`(`performed: true`).
- 재시도(≤ 2): 상세 선택 클릭은 방해된 클릭을 재시도 1회로 세고 선택 관측으로 결과를 판정(C5d 계약 그대로), 드래그는 보내지 않았으면 재시도·보냈으면
  측정 이동량을 그대로 쓰고(겹침 검증이 확인) **방해된 무이동 드래그는 끝 증거로 쓰지 않는다**, 휠 복귀 tick은 기록만(첫 페이지 대조가 판정).
  초과는 `input_busy`로 스캔 중단 → partial(기존 항목 보존, zero-fill 없음). 메뉴 준비 클릭은 기존대로 실패 시 메뉴 취소(안전 실패).
- 실측(훅 동작): 주입한 1px 이동 10건은 전부 `injected`, 같은 0.6 s 동안 사용자 마우스 이동 225건은 `user`로 분리. 세션 중 사용자가 PC를 쓰고 있어
  (1 s에 150~450 이벤트) 실게임 스캔은 돌리지 않았다 — 스캔이 커서를 움직여 사용자 조작을 방해하고, 가드가 매 스텝을 대기시킨다.
- 검증: Python **597 OK**(+9 가드·재시도 테스트, Windows에서 훅 설치·해제 포함). Flutter 변경 없음.
- **미검증(사용자 참여 필요)**: ① PC를 건드리지 않는 상태에서 세 프로필 스캔이 오탐 없이 C5e-1b와 같은 결과인지, ② 스캔 중 마우스를 움직이면 해당 스텝이
  `input_busy` → 재시도/partial로 끝나는지. 둘 다 끝나면 C5e-1 완료 판정 후 C5e-2.

### C5e-1d 실게임 확인 (2026-09-27, 사용자 PC 유휴)

- ① **오탐 없음**: 가드를 켠 채 세 프로필·학생 단일 스캔. 기술 노트 45/45 `ok`(114 s), 선물 56 + zero-fill 19 `ok`(143 s), 장비 95 `partial`(같은 사유, 139 s),
  미카 단일 전 필드 동일(3.0 s) — 모두 C5e-1b와 entry 동일, 가드 카운터 `user_events 0 / idle_waits 0 / busy_steps 0`(`debug/scanner_c5e1d_live/`).
  첫 두 시도는 첫 클릭에서 `input_focus_changed`·`input_busy(performed)`로 멈췄다 — **사용자 확인: 그 순간 모니터를 끄며 마우스를 움직였다**(정탐). 스캐너 자신의
  `SetCursorPos`는 훅에 잡히지 않음도 확인: 원시 호출 4회 → 0건.
- ② **실입력 감지는 사용자 참여 필요**: 다른 프로세스의 `SetCursorPos`로 "사용자 이동"을 흉내 냈지만 저수준 훅에 **보이지 않았다**(34회 → 0건).
  사용자 모드에서 비주입 입력을 만들 방법은 없다(SendInput은 항상 injected). 이 흉내는 가드가 모르는 커서 이동이 스캔을 방해하는 경우와 같고,
  결과는 클릭이 빗나가 `inventory_restore_failed` → **안전 중단**(기존 20건 보존, zero-fill 없음, 게임 화면 이상 없음)이었다.
  실제 마우스·키보드 조작 시험은 사용자가 있을 때 한 번 받는다.
- 가드 카운터(`waits`/`busy`)와 실게임 도구 리포트의 `input_guard`를 추가(진단용).
- (기록) `6b9e022` 커밋 때 status가 다시 오케스트레이터의 오래된 사본으로 덮여 있어 그대로 커밋됐다. `0484243` 내용에 오케스트레이터의 새 3줄(정렬·D18 원인)을 합쳐 복원했다.

## C5e-1 완료 판정 (2026-09-27)

- 재정의된 C5e-1 항목: 결정론적 드래그(정지 .8 s, 사유 기록)·k행 이동(아이템 3/장비 4)·릴리스 후 즉시 캡처·gutter 위상 검증·겹침 identity 검증·
  무이동 2회 끝 판정·휠 첫 페이지 복귀·viewport spec 일치·anchor 제거·D21 가드 — 구현·실게임 확인. 남은 것은 ②(사용자 실입력) 하나.
- 첫 스캔 소요(C5b → C5e-1): 기술 노트 ≈ 2분(상세 클릭 50회가 지배), 선물 ≈ 143 s, **장비 약 10분 → 139 s**. 두 번째 스캔 속도는 은행이 생기는 C5e-2부터.
- 다음: **C5e-2** 타일 은행 fast path(+ 워크플로의 order prior).

## C5e-2 — 타일 은행 + 정렬 사전(D23) (동작 변경) — 완료, 실게임 두 번째 스캔 대기 (2026-09-27, 시작 `62fbbbd`)

오케스트레이터가 착수 중에 C5e-2 정렬 사전을 D23으로 갱신했다(17:06, 사용자 지시 "order prior 갱신 확인"). 갱신본 기준으로 구현했다(`b3f46b0`).

- **`core/inventory_tile_bank.py` `TileBank`**: 상세 확정 타일 crop의 채널별 아이콘 벡터(M4를 미리 정규화해 내적 3번으로; `ncc_per_channel_icon`과 1e-9 일치)를
  identity당 ≤ 3개 보관. 계층 `session`(상세 확정, 비영속) < `user_confirmed`(승인 샘플, `RecognitionAnswerSampleStore`에서 로드, D1). 은행은 어댑터 수명 동안
  클라이언트 크기별로 유지 → 같은 백엔드 세션의 다음 스캔이 은행을 이어 받는다. 레지스트리 `inventory.tile_bank.score` .90, `.margin` .015.
- **1차(페이지 진입)**: 새 타일 전부 은행 매칭. 후보 = 프로필 카탈로그 − **이번 스캔에서 이미 기록된 identity**(목록에 항목은 한 번씩만 나오므로). 확신이고
  카탈로그 순서를 잇는 타일만 anchor.
- **2차(순서대로)**: anchor가 아니면 정렬 사전 — 직전 확정 항목과 다음 anchor의 `order_index` 사이로 좁혀 재매칭, 전체 1위도 구간 안이어야 확정.
  **D23 "좁히기일 뿐"**: 실패하면 전체 은행(모든 프로필, 기록된 identity 제외)으로 다시 보고, 구간 밖 항목과 확신 일치면 `order_conflict`로 세기만 하고 상세가 판정.
  상세가 읽었는데 이름을 못 댄 타일은 `unknown_new`(슬롯 evidence note, 라벨링 6e 대상 — 장비 범용 설계도 9칸이 여기에 해당). 읽기 실패는 `unknown_new`가 아니다.
  (합성 상세 아이콘의 후보 우주 = 프로필 필터 범주 → 팩 전체는 6d에서.)
- **상세 생략 조건**: 은행 identity 확신 **그리고 그리드 수량 확신**. 상세로 확정된 타일은 은행이 배우고, 은행 추정과 상세의 일치/불일치를 `tile_bank` evidence로 남긴다
  (불일치가 있으면 `uncertain`, 상세 우선).
- **D23 단조성 = LIS**: 페이지마다 review로 떨어뜨리던 `profile_order` partial을 없애고, 스캔 끝에서 관측 항목의 catalog order 최장 증가 부분열 밖 항목만
  `entries[i].order` `uncertain`으로 표시. zero-fill은 표시 항목의 LIS 이웃 사이 **구간 안 항목만 보류**(그 타일의 실제 정체일 수 있으므로), 나머지는 그대로.
  관측된 카탈로그 항목이 하나도 없으면 zero-fill하지 않는다(기존 "빈 목록 = 비단조" 규칙 유지 — 전부 외부 항목으로 skip되는 F12 테스트가 회귀를 잡았다:
  LIS 첫 판은 관측 0건에서 45종을 전부 0으로 채웠다).
  페이지 단조 검사는 grid-count fallback 허가 플래그(`inventory_profile_verified`)에만 남았다.
- **D23 정렬 규칙** `core/inventory_order_rules.py`(ExcelDB `item-rarity-v1.json`): 기술 노트 학교 enum × 티어·비의서 마지막, 선물 등급↑ × id↑, 장비 강화석 등급↓ →
  카테고리 × 티어↓(T2+) → 전 카테고리 T1 → 무기 성장 Z,C,B,A × 등급↓. 현재 카탈로그 `order_index`와 비교: **기술 노트 45·장비 110 완전 일치**,
  선물은 23개 위치가 다르다 — 모두 실게임에서 본 적 없는 항목이 끼어 있다(`Favor_Random`·`Random_Lv2`·`Selection`, `Lv2_3`·`Lv2_12`·`Lv2_Special`·`SSR_2`·`SSR_GL_10`·`SSR_GL_20`과 이웃).
  관측된 56종은 규칙에서도 단조다. 관측으로 가를 수 없어 **런타임 order는 카탈로그 값을 유지**하고 규칙은 모듈·테스트로 두었다(spec 없는 PC는 skip).
  해당 선물을 보유한 스캔이 생기면 판정 → 규칙으로 카탈로그 order 파생 전환(D23 (1)).
- **수량 재사용 시도(기각)**: 은행 타일과 수량 띠가 같으면 은행 수량을 재사용하는 안 — 두 스캔 196쌍에서 같은 수량의 잉크 차이 최대 93px(±3px 정렬 후),
  다른 숫자 최소 25px로 **분리 불가**(수량 라벨이 아이콘 아트와 겹침). 기각.
- **검증(오프라인, 실게임 녹화 replay; 모니터가 꺼져 실게임 불가)**: 한 어댑터로 녹화 A(C5e-1b)→B(C5e-1d)를 locked replay(입력 완전 일치).
  두 번째 스캔 은행 anchor **196/196**(기술 노트 45·선물 56·장비 95), 상세와 **불일치 0**, `order_conflict` 0, `unknown_new` 9(장비 범용 설계도).
  기록된 identity를 후보에서 빼기 전에는 첫 스캔의 은행 미등록 타일 14개(기술 노트 11·장비 3)가 **다른 항목에 확신 오답**이었고 모두 정렬 규칙이 막았다 —
  제외 규칙 뒤 0.
- **상세 클릭 0회 슬롯 비율 = 0 %**(완료 조건 항목): 현재 그리드 수량 판독기(v6 글리프)는 현재 UI에서 196/196 `None`이라 생략 조건이 성립하지 않는다.
  C5e-3(수량 은행)이 들어오면 두 번째 스캔은 은행 확신 196/196 기준으로 상세 없이 끝날 수 있다. 두 번째 스캔 소요도 그때 측정(지금은 첫 스캔과 같음).
- golden: 화면 상태 2건 same, locked 상세 경로는 `tile_bank` evidence 1줄 추가만(재고정). Python **614 OK**.
- 미검증: 실게임 두 번째 스캔(모니터 꺼짐) — replay로 대신.
- (기록) status가 18:04에 다시 오래된 사본으로 덮여 `b3f46b0`에 들어갔다. `df2255d` 내용 + 오케스트레이터 새 항목 + 이 절로 복원.
- 다음: 워크플로 순서 **C5e-6a-0(D24 로컬 추출기) → 6a → 6b → 6c** → C5e-3.

## C5e-6a-0 — 로컬 asset 추출기 (D24) — 완료, UI 폴더 선택은 이월 (2026-09-27, 시작 `21fc9a9`)

- `core/recognition_asset_extract.py`: `find_game_dir()`(레지스트리 SteamPath → `libraryfolders.vdf` → `appmanifest_3557620.acf` installdir, 카탈로그 존재 확인),
  `extract(game_dir, out_root, rarity_path) -> AssetCache`. 카탈로그 파서는 **자체 구현**한 최소 CCDB v1 리더(`AddressablesCatalog`, 주소 → 첫 의존 번들) —
  `tools/asset_spec/ccdb_catalog_reference.py`는 "BA Viewer 0.1에서 가져옴"이라 라이선스가 기록돼 있지 않아 코어로 복사하지 않았다(**사용자 확인 필요: 그 파일의 출처·라이선스**).
  읽는 것은 키가 필요 없는 파일뿐(카탈로그, 아이콘 Texture2D, `NGUIAtlas Common` 스프라이트 rect, `Card_Item_Bg_C` 텍스처, Font `m_FontData`). 등급표는 배포 스냅샷을 캐시에 복사.
- 대상: 스냅샷 아이콘 1268 + **카탈로그에만 있는 아이콘 61**(`03_NonEquipment`/`02_Equipment` 폴더 × `Item_Icon_`/`Equipment_Icon_` 접두 — 스냅샷이 뒤처진 신규 항목, D24;
  `@` 없이 텍스처 이름으로 저장, manifest `snapshot:false`) + 아틀라스 스프라이트 12 + `Card_Item_Bg_C` + 폰트 2. 아틀라스·폰트 번들은 날짜 접미가 바뀌어도 되게 glob + 이름으로 찾는다
  (현재 atlas 번들 2개 중 `Common`이 든 쪽).
- 캐시: `runtime_paths.resolve_extracted_asset_root()` = `%LOCALAPPDATA%/BA Planner/recognition-assets/<catalog sha[:16]>/`(`BA_PLANNER_USER_DIR`·`BA_PLANNER_EXTRACTED_ASSET_DIR` 재정의).
  staging에 만든 뒤 교체(실패 시 이전 캐시 유지), 성공하면 이전 카탈로그 캐시 삭제.
- **증분(번들 단위)**: 이전 manifest의 번들 (이름, 크기, mtime)이 같으면 열지 않고 그 번들 항목을 이전 캐시에서 **하드링크**(실패 시 복사). 복사로 했을 때 1345 파일에 9 s
  (거의 전부 파일 open — 백신 검사로 추정) → 하드링크로 1.3~2.0 s.
- **정답지(실측, 이 PC의 Steam 클라이언트 2026-09-15 카탈로그)**: 첫 추출 **9.0 s**, 아이콘 1329(스냅샷 1268 전부)·스프라이트 13·폰트 2, missing 0.
  **아이콘 1268/1268·스프라이트 13/13 픽셀 동일, 폰트 2/2 바이트 동일**. PNG 파일 sha는 인코더(Pillow 12 vs 오케스트레이터 환경)마다 달라 정답지 비교는
  디코드 픽셀 sha(`pixel_sha`)로 한다 — manifest에 `pixel_sha256`과 파일 `sha256`을 함께 기록. 캐시 적중 0.08 s, 카탈로그만 바뀐 증분 1.3~2.0 s(32/33 번들 재사용).
- 실패: 폴더·카탈로그·스냅샷 없음, 손상·잘린 카탈로그(엔트리 블록이 파일 끝을 넘는 경우 포함), UnityPy 없음, 추출 중 예외 → 모두 `asset_extract_failed`, 캐시는 건드리지 않음.
- 의존성: `pyproject.toml`에 `UnityPy>=1.24,<2` 추가(워크플로 명시; texture2ddecoder 등은 UnityPy 의존으로 설치됨, 이 PC 1.24.2 휠 확인).
  `.gitignore`: `asset_pack`의 zip·icons·fonts·sprites(개발용, D24). `manifest.json`·`README.md`는 정답지로 추적.
- 테스트 +5: 합성 CCDB 카탈로그 해석, 손상 카탈로그, vdf/acf 폴더 탐지, 폴더 없음 → 실패·캐시 무변경, **실 클라이언트 정답지 + 증분**(클라이언트·팩이 있는 PC에서만, ~11 s).
  Python **619 OK**.
- 이월: ① 탐지 실패 시 **UI 폴더 선택**(워크플로의 UI 예외, protocol + Flutter) — 6e 라벨링 UI 세션에 합친다. ② 추출 실행 시점(백엔드 시작 시 백그라운드/첫 스캔 전)과 진행 표시는
  6c 로더가 소비할 때 연결. ③ `spec/`(등급 스냅샷·기하 명세)는 아직 미추적 — 배포 스냅샷이므로 추적 여부는 오케스트레이터 결정.
- 다음: **C5e-6a 생성기**(`recognition_synth.py`).

## C5e-6a — 합성 템플릿 생성기 (D19/D25) — 완료, 학생 화면(D26)은 spec 대기 (2026-09-27, 시작 `ff9d0d6`)

- `core/recognition_synth.py`: `synthesize(cache, rarity, *, profile, identities=None, window, glyph_sizes) -> SynthTemplateSet`
  (tiles 96², details 128², glyphs {em: {char: ink map}}, `fingerprint` = 입력 sha·등급·생성기/spec 버전). 입력은 6a-0 `AssetCache`. Pillow만 사용
  (참조 구현의 numpy/scipy는 옮기지 않음). 누락 입력은 `SynthUnavailable(reason)`.
- **D25 정규화 한 벌**: 그리드 타일·상세 아이콘을 1080p 등가 스케일(`s = 1080/1665`)로 합성해 96²/128²로 저장, 실물 crop도 같은 크기로 맞춰 M4.
- 아이템 타일: `Card_Item_Bg_<등급>` 265×217 + 아이콘 253×200 × 1.06 @ (+3.5, +1.2) units(E4), 슬롯 창 = 카드 좌+2·상+2·98×91 @720p 비례.
- **장비 타일 E4(신규 실측, 1280 실게임 79장)**: 설계도 타일은 `*_Piece` 아이콘(D18) + `Card_Item_Bg_C`(2 units 아래), 격자 탐색으로 scale **1.06**, offset **(+2, 0)** units,
  alpha **1.0**(프리팹 .8~.867보다 실물과 잘 맞음) → **79/79 top-1**, 정답 M4 med .935 / min .829, margin min .032. 강화석·무기 성장은 아이템 카드(등급 배경) 기하로 **16/16**.
- **상세 아이콘 E3(신규, 101장)**: 프리팹 551×435 @(−717, 261) 그대로, 패널 색 (181, 227, 244) 단색 위, 플래너 ROI(137×146 @720p) crop → **101/101 top-1**(tech notes + presents),
  정답 M4 med .995 / min .973. 스케일 ±2 %는 더 나쁨. 장비 상세 아이콘은 C5e-4(라벨×배지 1차 키) 때 ROI와 함께.
- **그리드 E4 재현(D25 정규화)**: tech-notes-full-c 95타일(D18 교정 라벨) **95/95**, 정답 med .975 / min .895, margin min .018 — 오케스트레이터 E4(100 %, .977, .018)와 같다.
- **글리프(E5)**: `x0-9K` Gyeonggi Bold, em 후보 round(44·s)+1 ±1(720p 19/20/21), shear .10, 팽창 .5·s/.4324 px. 실물과 같은 잉크맵으로 비교하려고 **글자색을 밝은 배경에 합성한 뒤
  같은 `ink_map`으로 읽는다**(원 마스크 비교는 ~15 %). 실물 라벨 326자리(95타일)에서, 라벨 = 하단 잉크 band의 오른쪽 연속 열·자릿수 높이, 알려진 문자열 폭 비율로 위치를 잡고
  ±3px 창에서 NCC → **em 19: 91.4 %**(20: 85.9 %, 21: 70.9 %). E5 보고의 최적 em 20과 1px 다르지만 ±1 후보 규칙이 흡수한다(세션 첫 상세 확정 수량으로 선택, C5e-3).
- 프로필 후보 우주(D23 (2)): `profile_universe` = 스냅샷의 필터 범주(선물 `Favor`, 기술 노트 `SkillBook`, 장비 전체, `_Piece`는 장비 identity로 접힘) ∪ 프로필 카탈로그 —
  tech notes 54(카탈로그 45 포함), presents 76(75), equipment 110(110).
- 소요(1280, 이 PC): 프로필별 0.4~0.6 s(타일·상세·글리프 3벌), 아이템 1058종 타일만 7.1 s(목표 < 10 s 충족), 상세 포함 13.9 s — 전체 합성은 6b 캐시가 막는다(D25).
- 테스트 +6: 스케일 공식(16:9·4:3), 결정성(같은 입력 → 같은 바이트·fingerprint), 입력 누락 → `SynthUnavailable`, **E4 그리드 ≥ 99 %·med ≥ .95, E3 상세 top-1, E5 글리프 ≥ .90**
  (클라이언트·로컬 프레임이 있는 PC에서만). Python **625 OK**.
- 대기: **학생 화면(D26)** — 무기·스킬 아이콘·이름 localize의 카탈로그 키를 오케스트레이터가 spec에 추가하기로 했으나 아직 없다(`prefabs.student_detail`에는 위젯 기하만).
- 다음: **C5e-6b** 캐시·드리프트(항목 단위 증분 index).
