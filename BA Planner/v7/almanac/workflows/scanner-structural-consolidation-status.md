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
| C1 계약 드리프트·이름 정리 | 미착수 | C0 golden | C1 착수 |
| C2~C7 | 미착수 | — | 순서대로 |

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
