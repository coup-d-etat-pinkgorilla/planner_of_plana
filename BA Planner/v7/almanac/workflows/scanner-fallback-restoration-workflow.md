---
title: "Scanner Fallback Restoration Workflow"
summary: "v6 학생·재고 스캔의 누락 폴백을 입력 복구부터 상세 판독·통합 검증까지 순차 재도입하는 실행 계약입니다."
topics: [workflow, migration, data]
sources:
  - id: baseline
    type: file
    path: docs/migration/v6-knowledge-baseline.md
  - id: status
    type: file
    path: almanac/workflows/p0-p6-workflow-status.md
  - id: student-workflow
    type: file
    path: almanac/workflows/student-scan-validation-workflow.md
  - id: matchers
    type: file
    path: backend/core/scanner_matchers.py
  - id: windows-input
    type: file
    path: backend/core/windows_scanner_adapter.py
  - id: session
    type: file
    path: backend/core/scanner_session.py
  - id: equipment
    type: file
    path: backend/core/student_equipment_recognizer.py
  - id: weapon
    type: file
    path: backend/core/student_weapon_recognizer.py
  - id: validator
    type: file
    path: backend/core/student_candidate_validation.py
  - id: f0-result
    type: file
    path: docs/migration/scanner-fallback-restoration/README.md
  - id: f0-decisions
    type: file
    path: docs/migration/scanner-fallback-restoration/dependencies-and-decisions.md
  - id: f1-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f1-results.md
  - id: f2-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f2-results.md
  - id: f3-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f3-results.md
  - id: f4-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f4-results.md
  - id: f5-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f5-results.md
  - id: f6-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f6-results.md
  - id: f7-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f7-results.md
  - id: f8-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f8-results.md
  - id: f9-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f9-results.md
  - id: f10-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f10-results.md
  - id: f11-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f11-results.md
  - id: f12-result
    type: file
    path: docs/migration/scanner-fallback-restoration/f12-results.md
---

# Scanner Fallback Restoration Workflow

## 목적과 현재 상태

2026-08-30 사용자의 “전부 다시 도입하는 워크플로우” 요청에 따라 직전 v6/v7 비교의
학생·재고·공통 복구 항목을 모두 추적한다. 현재 **F0 기준선·증거·계약 고정 완료**이며,
F1은 실제1280 게임 캡처·좌우 키/버튼·끝 순환 검증까지 완료했다. F2 구현·실게임 장비/무기 복귀와
최종 Python341개·Flutter399개 회귀도 통과하여 완료했다. F3도 능력 개방 기본·상세 판독, 실제2560
확인과 최종 Python365개·Flutter399개 회귀를 통과하여 완료했다. 후속 실제1280 F3 검증도 통과했고,
F4도 구현·실게임 확인과 Python383개·Flutter 순차399개 회귀를 통과하여 완료했다.
F5도 독립 성급 추론·성급 탭과 실제1280 확인, Python405개·Flutter 순차399개 회귀를 통과하여 완료했다.
F6도 실제1280 스킬·체크·취소 복귀, Python427개·Flutter399개/analyze를 통과하여 완료했다.
F7 R12~R15 구현·실제1280 확인, D2 독립24슬롯 및 음성 검증 후 native1280 제한 규칙 적용.
Python463/Flutter399/analyze 최종 회귀를 통과하여 F7 완료다. [@f6-result] [@f7-result]
F8 R16~R18 구현·전용23 tests 및 실제1280 진입/재식별/폼 복귀 검증을 통과했다.
F9 R19~R21도 실제1280 아이템/장비 정상·취소 선택 복귀 및 안전한 미확정 사례를 확인했다.
F10 R22~R23은 검증형 필터·정렬과 행 overlap/tail/실패 안전 스크롤을 구현했고, 실제1280
아이템 전체 tail과 장비 세 화면·불규칙 이동 안전 중단을 확인했다. F11 R24도 session-local
보정 격리, 사용자 정답 우선권과 종료 폐기를 구현하고 실제1280 레벨 상세→기본 재판독을 확인했다.
Python529/Flutter399/analyze 전체 회귀를 통과해 F11까지 완료했다. F12 구현·실게임1280/2560·
Python533/Flutter400/analyze/Windows release도 통과했다. 후속 16:9 창 크기 3회 실게임 검사도 모두
직접 T10/Lv70 판독으로 통과했다. 자연 저점수 T10/70 표본 부재와 native2560 특수 추론 비활성은
사용자 지시에 따라 인지된 위험으로 남기고 F0~F12 전체를 완료 처리했다.
[@f8-result] [@f9-result] [@f10-result] [@f11-result] [@f12-result]
[@f2-result] [@f3-result] [@f4-result] [@f5-result]
기존 전용무기 S2W 구현은 유지하고 보완한다. [@f1-result]
F0는 실게임 입력, 자동 스캔 실행, 사용자 데이터 변경 또는 전체 구현 완료를 뜻하지 않는다. [@f0-result]

P0~P6 및 학생 S1~S5를 다시 시작하지 않는 후속 scanner 안정화 작업이다. 이 문서는 실행
순서와 gate를 소유하고, 실제 완료 사실·검증 결과·다음 행동은
[P0-P6 상태](p0-p6-workflow-status)에 기록한다. [@status] [@student-workflow]

## 범위와 불변식

- v6의 **실제 호출되는 동작**을 참조한다. 함수·로그·asset 존재만으로 도입 여부를 판정하지 않는다.
  각 slice에서 DTO·callback·입력 의존성을 분리하고 parity fixture를 먼저 만든다.
- Qt/QML/QWidget/Tk/PySide6 및 v6 facade를 복사하지 않고 `../v6` 런타임 import를 금지한다.
- 스캔 후보, 정적 메타데이터, 목표, 총 계산 결과, 재고 부족량의 분리를 유지한다. 미확정을 0으로 채우지 않는다.
- 실제 클릭은 선택된 게임 창의 정보 조회·탭·체크박스·닫기·이동에 한정한다.
  강화 실행, 장착 변경, 재화 사용, 구매, 계정 전환 버튼은 대상이 아니다.
- 기본 화면에서 충분히 확정되면 상세창을 생략한다. 같은 학생·폼의 독립 증거를 합치되
  실패한 상세 판독으로 기존 확정값을 지우지 않는다. 서로 다른 확정값은 충돌 evidence로 검토한다.
- 모든 재시도는 횟수·시간 상한과 취소 경계를 갖는다. 중첩 retry의 총 시도 상한도 고정한다.
- `finally`에서 닫기를 시도하고, 기본 화면 복귀가 확인되지 않으면 다음 학생·다른 패널 판독을 중단한다.
  취소 이후에는 정리용 닫기 외 새 탐색을 하지 않는다.
- 계산 불일치는 관측 숫자의 자동 수정 근거가 아니다. 계산값에 맞추는 숫자 강제 보정은 제외한다.
- 인연 랭크는 v6에 없는 v7 기능이다. 기존 판독·사용자 샘플·검증을 회귀 보호한다.
- 영구 정답 샘플은 사용자 명시 확인 경계를 유지한다. F0에서 승인한 자동 session-local calibration을 F11에서 구현한다.
- 런타임 인식 asset과 UI asset을 분리하고 상세 ROI는 기본 ROI와 독립된 fixture로 검증한다.
  [@baseline] [@session] [@validator]

## 전수 추적표

v6 경로는 sibling `../v6/` 기준이다. 코드가 이동하면 F0에서 함수 이름과 SHA를 다시 고정한다.
‘부분 구현’도 runtime 연결과 실패 복구 gate를 통과해야 완료다.

| ID | 복원·보완 항목 | v6 근거 | v7 시작 상태 | 단계 |
|---|---|---|---|---|
| R01 | PrintWindow 플래그 대체·제한 캡처 재시도 | `core/capture.py:_print_window`, `core/scanner_components/runtime.py:_capture` | BitBlt 대체만 있음 | F1 |
| R02 | 전경 실제 클릭·메시지 대체, 좌우 이동 | `core/input.py:click_point`, `core/scanner_components/student.py:_send_student_arrow` | 클릭 메시지 전용, 왼쪽 키 지원 불일치 | F1 |
| R03 | 제목·탭 표시 기반 열림 확인·최종 재확인 | `core/scanner_components/student.py:_click_student_region_and_wait` | 픽셀 안정성 확인만 있음 | F2 |
| R04 | 대체 닫기·ESC·기본 화면 복귀 확인 | `core/scanner_components/student.py:_close_student_panel`, `_restore_basic_tab` | 닫기 좌표 클릭만 있음 | F2 |
| R05 | 전용무기 상세 폴백 안전 통합 | `core/scanner_components/student.py:read_weapon` | S2W 도입, R03/R04 및 값 보존 보완 필요 | F2 |
| R06 | 능력 개방 기본 배지·값 → 상세 패널 | `core/scanner_components/student.py:read_basic_combat_stats`, `read_stats` | 판독 미구현, 저장값/입력 보완만 있음 | F3 |
| R07 | 기본 레벨 → 레벨 탭 ROI·추가2회 캡처 | `core/scanner_components/student.py:read_level` | 기본 숫자 대체 매칭만 있음 | F4 |
| R08 | 독립 무기 해금 증거 → 학생5성 추론 | `core/scanner_components/student.py:read_student_star` | 미구현 | F5 |
| R09 | 기본 별 → 성급 탭 | `core/scanner_components/student.py:read_student_star` | 미구현 | F5 |
| R10 | 기본 스킬 → 상세창·전체 보기·상세 ROI | `core/scanner_components/student.py:read_skills` | 구현·검증 완료 | F6 |
| R11 | 성급에 따른 잠긴 스킬 제외 | `core/scanner_components/student.py:_read_skills_from_basic`, `read_skills` | 구현·검증 완료 | F6 |
| R12 | 장비 전체 보기 확인·활성화·재캡처 | `core/scanner_components/student.py:read_equipment` | 구현·실제1280 확인 | F7 |
| R13 | 대상 일반 장비 모두 미확인 시 추가1회 캡처 | `core/scanner_components/student.py:read_equipment` | 구현·실제1280 실패 주입 확인 | F7 |
| R14 | 레벨70 + T10 최상위 후보의 제한적 추론 | `core/scanner_components/student.py:_scan_equip_slot` | D2 native1280 제한 적용, 자연 저점수/2560은 F12 coverage | F7 |
| R15 | 성장 버튼 비활성·빈칸 표시 부재 → 애용품 잠금 | `core/scanner_components/student.py:read_equipment` | 실제 미유 잠금 및 빈칸/T1/T2 fixture 확인 | F7 |
| R16 | 학생 식별 재캡처·첫 학생 진입 복구 | `core/scanner_components/student.py:identify_student`, `_recover_first_student_entry` | 2회 식별/1회 진입·단계별 확인 구현, 실제1280 통과 | F8 |
| R17 | 후보군 확대·속성 후보 보완 | `core/matcher.py:_match_student_texture_optimized` | 전체 검색 유지·속성 cohort/본체 확인 후 폼 보완, 경쟁 학생 배제 금지 | F8 |
| R18 | 폼 템플릿 실패 → 속성 판별·폼 순회·복귀 | `core/scanner_components/student.py:_current_student_form_index`, `read_multi_form_combat_stats` | unknown 동률·폼별 전투 DTO·능동 순회/정상·취소 복귀 구현 | F8 |
| R19 | 재고 그리드 실패 → 실제 상세창 ID·이름·수량 | `core/scanner_components/inventory.py:_verify_inventory_slot` | 상시 상세 패널 판독·원슬롯 복귀 구현, 실제1280 정상/취소 통과 | F9 |
| R20 | 장비 상세 수량 → 아이템 수량 template 대체 | `core/scanner_components/inventory.py:_verify_inventory_slot` | 누락 사유에만 장비 ROI+아이템 bank 대체, 실제116 진단 통과 | F9 |
| R21 | 상세 weak_x_match → 유효한 그리드 결과 복귀 | `core/scanner_components/inventory.py:_verify_inventory_slot` | 확정 grid ID/수량+F10 독립 scan profile gate 연결 | F9 |
| R22 | 필터창·정렬 실패 후 재클릭·재확인 | `core/scanner_components/inventory.py:_open_item_inventory_filter_panel`, `_open_equipment_inventory_filter_panel`, `_ensure_region_matches_reference` | 최대2회 열기·profile 선택·최대2회 정렬 보정 구현, 실제 item/equipment 통과 | F10 |
| R23 | 스크롤 재시도·행 겹침·잔여 오차 재확인 | `core/scanner_components/inventory.py`의 drag/motion 경로 | RGB histogram 행 overlap·tail·무이동 끝·애매 이동 중단 구현, 실제1280 통과 | F10 |
| R24 | 상세 레벨 성공값 기반 실행 중 보정 샘플 | `core/scanner_components/student.py:_learn_basic_level_for_run`, `_learn_basic_equipment_slot` | 공통 session bank·사용자 정답 우선·scope/종료 폐기 구현, 실제1280 레벨 재판독 통과 | F11 완료 |

## 실행 순서와 단계별 gate

순서는 `F0 → F1 → F2 → F3 → F4 → F5 → F6 → F7 → F8 → F9 → F10 → F11 → F12`다.
한 번에 한 backend 수직 slice를 구현·검증한다. 문서 작성 요청만으로 구현이나 별도 작업 생성을 시작하지 않는다.

### F0 — 기준선·증거·계약 고정

- R01~R24의 v6 실제 호출 경로, v7 대체 경로, DTO·callback·상태 이벤트 의존성을 특성화한다.
- 산출물: `docs/migration/scanner-fallback-restoration/`의 source manifest·결정 기록·F0 측정 결과와
  `backend/tests/fixtures/scanner_fallback_restoration/`의 증거·계약·R별 양성/음성 fixture 계획.
- 제공 JSON `debug/scan test/ba-planner-student-scan-2026-08-29T00-49-15.526282Z-full.json`과
  `C:/Users/brigh/Pictures/Screenshots/BA/feedback1`의 SHA, 학생 ID/폼, 실제 해상도, 육안 정답을 고정한다.
  과거 JSON 재검증과 새 프레임 인식 결과를 분리한다.
- feedback1은 기본 화면 증거다. 상세창·체크박스 off·복귀 실패·재고 이동은 별도 실제 화면/입력 trace가 필요하다.
  2560 원본 축소본과 실제 1280 캡처도 별도 coverage로 기록한다.
- 기존 전체 test·archive를 다시 측정한다. 과거 290-test 기록을 신규 실행 결과로 재사용하지 않는다.
- 완료: 각 R에 positive/negative fixture 계획, 실제 증거 유무, 담당 단계가 있고 D1~D3 결정이 기록됨.
- 2026-08-30 완료: 소스26개/함수65개와 feedback1 원본19개를 고정하고 Python290개 및 archive를 재실행했다.
  D1/D3은 사용자 승인 완료, D2는 legacy 특성화 완료·F7 승격 검증 대기다. 실제 호출되지 않는 helper와
  합성/원본/축소/실제1280 증거를 분리한 결과·한계는 F0 산출물을 따른다. [@f0-result] [@f0-decisions]

### F1 — 캡처·입력 복구 기반

- R01/R02를 Windows adapter 경계로 도입한다. 플래그 대체·BitBlt·재캡처의 순서와 총 상한을 고정한다.
- 선택된 HWND 검증, client/screen 좌표 변환, foreground 입력과 메시지 대체를 구현한다.
  입력 API 성공과 화면 전환 성공을 구별하고 왼쪽 키 예외가 버튼 폴백을 막는 문제를 수정한다.
- 완료: capture 실패 후 성공/소진, 메시지 무시, 초점 변경, 창 소멸, 좌우 끝, 취소 tests 통과.
  대상 외 창에는 입력하지 않으며 최소화·비활성 창 처리와 실제 게임 입력 trace를 검증한다.
- 2026-08-30: 제한 캡처/격리 worker, 선택 HWND 입력·양쪽 키/버튼 대체, 실패·취소 후보 보존 구현.
  Python319개·Flutter399개와 analyze 통과. 게임 창 탐색0개로 실제 입력 trace는 대기이며 F1 완료는 아니다.
  무이동은 끝으로 확정하지 않고 검토 후보를 남긴다. 원자적 foreground 잠금 부재 등 한계는 결과에 기록했다. [@f1-result]
- 후속 실게임 검증 완료: 실제1280에서 8개 안전 입력과 학생 왕복·양끝 순환, 비활성 capture를 확인했다.
  F1 완료이며 실제2560/OS 오류 주입 coverage는 F12에서 별도로 추적한다. [@f1-result]

### F2 — 공통 패널 복구·전용무기 안전 통합

- R03~R05: `기본 화면 → 열기 → 목표 패널 확인 → 판독/재캡처 → 닫기 → 기본 화면 확인`을 공통 경계로 만든다.
- 제목/활성 탭 predicate, v6의 추가 대기·최종 재확인, 대체 닫기·ESC를 복원한다.
  잘못 열린 패널이나 닫히지 않은 화면을 새 학생 데이터로 오인하지 않는다.
- weapon state 미확정이면 상세창을 열지 않는 정책과 장착 확인 후 최초+추가2회 캡처를 유지한다.
- 미확정 상세값으로 기본 확정값을 덮지 않는다. retry 집계도 확정값을 보존하고 상충값은 검토한다.
- 완료: 클릭 무반응, 잘못된/늦게 열린 패널, 한 필드만 복구, 확정값 충돌, 닫기 실패, 각 상태 취소 tests 통과.
  실게임에서 전용무기·장비 열기/닫기·기본 복귀를 확인한다.
- 2026-08-30 구현: 제목4개와 활성 탭3개, 제한 열기/재확인/대체 X/ESC, 같은 학생 기본 복귀,
  확정값 보존·충돌 검토·상세 실패 partial을 공통화했다. 실제1280 장비/무기 왕복 및 취소 정리,
  미카 단일 matcher를 확인했고 프레임8개를 개발/회귀용으로 고정했다. 최종 Python341개·Flutter399개와
  analyze/문서/asset 검증을 통과하여 F2 완료다. 재실행 이력과 실제2560 등 남은 한계는 결과에 기록했다. [@f2-result]

### F3 — 능력 개방 기본·상세 판독

- R06: 레벨90·5성 조건을 확인하고 기본 배지 존재/부재와 숫자를 각각 판독한다.
  배지 부재 확정만 0으로 인정하고 세 값 중 미확정이 있으면 상세 패널 전용 ROI를 읽는다.
- 새 관측과 기존 프로필 보완값의 provenance를 구분한다. 저장값이 있다고 화면 판독을 무조건 생략하지 않는다.
- 완료: 미해금, 해금 후 전부0, 일부25, 중간값, 배지 불명, 기본·상세 충돌, 상세 실패 tests 통과.
  미확정은 `dependency_missing`이며 표시 HP/ATK/DEF/HEAL과 능력 개방값을 혼동하지 않는다.
- 2026-08-31: 기본/상세 ROI와 고정 자산104개, 잠금·출처·미확정·충돌·안전 복귀 연결을 구현했다.
  F3 전용24개와 Flutter399개, 실제2560 미카25/25/25·히나25/25/0 상세 및 취소 복귀를 확인했다.
  최종 전체 Python365개와 자산/문서 검증을 통과하여 F3 완료다. 실제1280 상세 등 coverage 한계와
  재실행 이력은 결과 문서에 분리했다. [@f3-result]
- 후속 실제1280 미카25/25/25·히나25/25/0 상세 판독과 정상/취소 복귀가 통과하여 F4를 시작했다.
  synthetic 축소가 아닌 native1280 증거로 추가 기록했다. [@f4-result]

### F4 — 레벨 탭 폴백

- R07: Studio→glyph 경로 뒤에 레벨 탭 전용 ROI를 연결한다. 최초+추가2회 이내 캡처와 기본 탭 복귀를 구현한다.
  학습은 F11 경계로 분리한다.
- 완료: 한/두 자리, 실제 저레벨/최고레벨, blank, 기본 실패→상세 성공, retry 소진, 복귀 실패 tests 통과.
  기본 성공이면 탭 클릭0회, 상세 실패이면 기존 확정값 유실0건.
- 2026-08-31: 전용 숫자19장/ROI1개, Studio→glyph 실패 뒤 level tab 연결과 F2 복귀를 구현했다.
  전용18 tests 및 실제1280 Lv.1/Lv.90 탭 판독·복귀, 진단 기본실패→Lv.1 복구를 확인했다.
  Python383개·Flutter 순차399개 및 analyze/자산/SHA/문서 검증을 통과하여 F4 완료다.
  기본 병렬 Flutter5개 timeout 이력과 실제2560 등 미검증 범위는 결과 문서에 남겼다.
  학습은 F11로 남긴다. [@f4-result]

### F5 — 성급 추론·성급 탭 폴백

- R08/R09: 독립 flag ROI에서 장착/해금 후 미장착이 확정되면 학생5성을 `inferred`로 보완한다.
  학생 성급에서 유도한 무기 상태를 다시 성급 추론에 쓰지 않는다. 직접 별 판독과 모순되면 검토한다.
- 기본 별 판독이 불충분하고 독립 추론도 불가능하면 성급 탭 전용 ROI를 읽고 기본 탭으로 복귀한다.
- 완료: 1~5성, 무기 미장착5성, 무기 상태 불명, 성급 충돌, 순환 추론 금지, 복귀 tests 통과.
- 2026-08-31: 독립 flag 추론·현재 성급 ROI·F2 기본 복귀·sticky 충돌과 validator guard를 구현했다.
  전용22개/기존 무기9개 및 실제1280 미카5/미유3 판독·정상/취소 복귀·진단 폴백 통과.
  Python405개·Flutter 순차399개/analyze/자산/SHA/문서 검사 통과로 F5 완료다.
  신규 실제 미장착5성/1·2·4성/2560 입력은 미검증이며 F12 범위로 기록한다. [@f5-result]

### F6 — 스킬 상세창·전체 보기

- R10/R11: 확정 성급의 해금 규칙으로 잠긴 슬롯을 `skipped` 처리한다. 성급 불명은 잠금으로 추정하지 않는다.
- 기본 실패 시 패널 확인→전체 보기 확인→꺼진 경우에만 켜기→재캡처→전용 ROI 판독을 수행한다.
- 완료: EX1~5/일반1~10의 숫자·MAX, 잠긴 패시브/서브, 전체 보기 on/off/불명, 클릭 무반응 tests 통과.
  이미 켜진 체크박스를 끄지 않고 잠금 상태를 실패 숫자로 처리하지 않는다.
  전용22/전체Python427/Flutter399/analyze 및 실제1280 검증 통과. F6 완료. [@f6-result]

### F7 — 장비·애용품 상세 복구 완성

- R12~R15: unresolved 슬롯 공유 캡처를 유지하고 전체 보기 재확인·활성화와
  대상 일반 장비 전부 미확인 시 추가1회 캡처를 도입한다. 성공한 다른 슬롯은 손상시키지 않는다.
- 성장 버튼 기본 ROI를 읽어 `favorite_growth_active`에 연결한다. 빈칸/버튼 중 하나라도 불명일 때
  무조건 `love_locked`로 승격하지 않는다.
- T10/레벨70 특수 추론은 R14 전용 `inferred` source와 D2 gate를 거친다. 전체 티어 threshold를 낮추지 않는다.
- 완료: 잠금/빈칸/미확정 구별, 체크박스 off, 전체 실패→복구, 일부 실패, 애용품T1/T2/잠금,
  T10 경계·음성 fixture, 기존 장비 archive 및 shadow 비승격 회귀 통과.
- R12~R15 구현 및 실제1280 체크·일반T10/70·진단 재시도/추론·취소 복귀 확인.
  R15 native 잠금1280/2560·빈칸·T1/T2, D2 독립24슬롯과 합성120/음성321을 검증했다.
  `.55<=T10 score<.60`, margin≥.15, 독립 숫자7/0 각 score≥.80/margin≥.15일 때만
  native1280에서 inferred로 복구한다. 일반 .60 gate와 보정 학습 제외를 유지한다.
  Python463/Flutter399/analyze 최종 회귀 통과로 F7 완료다.
  자연 저점수/2560 특수 추론은 아직 검증되지 않았으며 F12에 명시했다. [@f7-result]

### F8 — 학생 식별·진입 복구·다중 폼

- R16~R18: 저신뢰 ID를 다른 필드의 확정 context로 쓰지 않고 새 기본 프레임으로 제한 재시도한다.
  첫 학생 실패 시 로비/목록/상세 상태를 확인해 첫 학생 기본 화면으로 복구한다.
- v7 전체 검색을 유지한다. v6 후보 축소·확대/속성 보완은 대조 fixture로 효과를 확인해 연결한다.
  속성이 같다는 이유만으로 학생을 확정하지 않는다.
- 폼 템플릿 미확정 시 속성 판별을 추가하고, 다른 폼 능력치를 읽은 뒤 원래 폼으로 복귀한다.
  canonical ID·폼별 DTO·중복 제거 계약을 먼저 고정해 서로 다른 폼 값을 섞지 않는다.
- 완료: 유사 초상화, 이미 본 학생, 첫 진입 실패, 속성 동률, 폼 판독/전환 실패,
  원래 폼 복귀, 좌우 순회 종료/입력 실패 구별 tests 통과.
- 2026-08-31 구현 후 전용23/23, 생산 adapter11/11 통과. 실제1280 로비/목록 진입,
  미카 진단 재촬영, 호시노 무장 두 폼 독립 능력치와 원폼1/2·취소 복귀를 확인했다.
  native1280 로비 표식만 고정3px 보정, 기존 threshold 유지. 숨김 UI/불명은 입력 없이 중단한다.
  2026-09-01 Python486/Flutter399/analyze 전체 회귀를 통과하여 F8 완료.
  실제2560·수영복 슌·장시간 순회는 F12 추가 coverage다. [@f8-result]

### F9 — 재고 실제 상세창·수량 폴백

- R19~R21: grid confidence 부족/수량 불명 슬롯을 열어 상세 ID·이름 template와 수량 ROI를 읽는다.
  상세 닫기와 동일 페이지·슬롯 복귀를 확인한 뒤 계속한다.
- 장비 수량 template 누락 사유에만 아이템 수량 bank를 대체한다. `weak_x_match` 복귀는 같은 슬롯의
  사전에 유효한 grid ID·수량·프로필 검증 결과가 있는 경우만 허용한다.
- 기존 `detail_template_fallback`의 same-crop rematch와 실제 상세 source를 구별한다. 구 진단 JSON 호환성을 유지한다.
- 완료: grid 성공시 클릭0회, 상세 복구, ID 충돌, missing templates, weak_x 허용/거부,
  상세/복귀 실패, 수량0과 미확정 구별 tests 통과. 자동 repository 반영은 하지 않는다.
- 2026-09-01 실제1280에서 장비 T10 목걸이306과 아이템 일반 노트843의 선택·상세 판독·
  원슬롯 정상/취소 복귀를 확인했다. 흐린 선택은 기준 완화 없이 최대3회 새 관측한다.
  실제24890의 약한 숫자와 새 청사진 ID는 partial로 남겨 오답 확정을 막았다.
  Python505/Flutter399/analyze 및 자산3046개 검증을 통과해 F9 완료. [@f9-result]

### F10 — 재고 필터·정렬·스크롤 복구

- R22/R23: 필터창 열림 확인/재클릭, 정렬 reference 확인/재설정과 상한 초과 중단을 구현한다.
  inventory scan profile과 사용자 계정 profile은 별도 식별자로 유지한다.
- 휠/드래그 결과를 행별 identity/hash·이동량·overlap으로 검증한다. 무이동 시 제한 재시도,
  잔여 오차 시 안정화 재캡처를 적용하고 실제 끝과 입력 실패를 구별한다.
- v6 정렬·프로필 순서·zero-fill 계약을 fixture로 고정한다. 실패·불완전 coverage에서는 zero-fill 금지.
  대체 입력은 같은 이동을 복구하는 데만 사용하고 확인 없이 중복 이동하지 않는다.
- 완료: 필터 실패→성공/소진, 잘못된 정렬, 무이동, 반쪽 행, near-zero overlap,
  중복/꼬리 페이지·누락 방지·취소 tests 및 여러 페이지 실게임 trace 통과.
- 2026-09-01: 필터/정렬 제한 확인, 짧은 foreground drag, slot 내부 RGB histogram 행 overlap,
  tail 전체 페이지1회 및 검증된 끝만 zero-fill을 production runtime에 연결했다. 선물75종의 v6
  자연 순서도 정적 catalog에 복원했다. 실제1280 기술 노트 전체 tail과 장비 세 화면을 확인했고,
  장비 불규칙 이동은 margin .002로 안전 중단 후 첫 페이지 복귀했다. Python521/Flutter399/analyze,
  자산3051개와 native fixture8개를 검증하여 F10 완료다. [@f10-result]

### F11 — 실행 중 보정 샘플·정답 샘플 격리

- R24: D1 결정을 구현한다. 학생 상세 레벨 성공→기본 glyph 보정과 기존 장비 임시 학습을
  공통 provenance·격리 정책으로 정리한다. 영구 사용자 정답 bank를 자동 덮어쓰지 않는다.
- 승인된 정책: 같은 학생/폼 + 상세 패널 확인 + 값 확정 + 충돌 없음일 때만 별도 session-local bank에 보관한다.
  사용자 확인 전에는 영구 저장·재시작 재사용하지 않는다.
- 자기 출력만 근거로 반복 학습하거나 calibration 결과를 사용자 확정 evidence로 표시하지 않는다.
- 완료: 상세 오류 주입, 오염 전파 방지, 사용자 샘플 우선권, 계정/실해상도/session 분리,
  취소·종료 폐기, 사용자 수정·재검증 영구 학습 회귀 tests 통과.
- 2026-09-01: `SessionCalibrationStore`를 profile/실해상도/session/generation/학생·폼/field로
  격리하고 matcher terminal/cancel에서 폐기하도록 연결했다. 상세 출처는 level tab과 equipment menu의
  독립 확정값만 허용하며 session 출력·충돌은 거부한다. 사용자 정답은 더 높은 matcher 우선권과
  별도 provenance를 유지한다. 실제1280 하나코(수영복)에서 상세 Lv90→session glyph2개→같은 학생
  기본 Lv90 재판독과 두 번째 패널 입력0회를 확인했다. Python529/Flutter399/analyze 통과. [@f11-result]

### F12 — 통합 검증·릴리스·완료 판정

- 단일/전체 학생·다중 폼·재고를 실제 Python/Dart process와 연결한다. UI에 추가되는 단계·실패 사유는
  localization·decoder/mock/contract tests를 함께 갱신한다.
- 과거 JSON 재검증, 프레임 replay, 새 실게임 scan을 따로 보고한다. 확정 오답/미확정/누락 dependency/계산 불일치,
  필드별 폴백 진입·성공·실패, 클릭·재캡처 횟수, 지연 p50/p95, 최대 대기·메모리/핸들 정리를 기록한다.
- 아래 검증과 실제 1280/2560 대표 trace를 통과한다. 합성 fixture만 있는 항목을 실게임 검증 완료로 표시하지 않는다.
- F7 D2의 자연 저점수 T10/70 및 native2560 특수 추론 coverage를 추가한다.
  현재 native1280의 합성 손상 복구를 자연 발생 실패 복구율로 해석하지 않는다.
- R01~R24 각각 구현 artifact, fixture, 테스트 결과, 실제 coverage/한계가 있어야 전체 완료다.
  미결정 gate, 중요 경로 미검증 또는 잘못된 학생을 확정하는 복구 사례가 있으면 완료 금지.
- 2026-09-01 구현·검증: R01~R24 audit 24/24, 실제 Dart→Python 단일/전체/다중 폼/재고,
  native1280/2560 대표 trace, Python533/Flutter400/analyze, Windows release와 번들 asset3051개를
  통과했다. 현재 아이템 표시창 변경에 맞춰 명시적 inventory profile과 외부 항목 거부, 검증되지 않은
  순서에서 partial/no-zero-fill을 연결했다. 최종 retained 오답과 mutation은 0건이다.
- 독립 native1280 24슬롯과 신규 실게임에서 자연 저점수 T10/70은 관측되지 않았다. 합성 손상5건을
  자연 coverage로 승격하지 않으며 native2560 특수 추론도 계속 비활성이다. 이후 1280x720,
  DPI 논리 1079x607(정수 반올림 16:9), 960x540의 세 창 크기에서 미카 장비 T10/Lv70 직접 판독,
  D2 특수 추론0건, mutation0건을 확인했다. 사용자 지시에 따라 남은 한계를 인지된 위험으로 기록하고
  F12와 전체 F0-F12를 완료 처리한다. [@f12-result]

## 구현 전 결정 gate

전부 복원할 범위는 확정이다. 아래는 누락 항목을 제외하기 위한 것이 아니라 기존 안전 정책과
충돌하지 않도록 구현 방식을 확정하는 gate다. **D1/D3은 2026-08-30 사용자 승인 완료다.**
D2는 F0 legacy 조건 고정 후 F7에서 현재 bank 독립 검증을 수행해 native1280 범위로 적용했다. [@f0-decisions] [@f7-result]

| ID | 결정 사항 | 결정 | gate |
|---|---|---|---|
| D1 | 자동 보정과 자동 판독값 영구 학습 금지의 관계 | 자동 보정은 session-local 별도 bank, 사용자 확인 샘플만 영구 저장 | F0 승인 완료, F11 구현 |
| D2 | v6 T10/레벨70 완화 기준 | 현재 bank 전용 native1280 제한 규칙, 공통 threshold 유지 | F7 독립24슬롯/음성 검증, 자연 저점수·2560은 F12 |
| D3 | 반복 후 닫기/ID/캡처 실패 | 화면 불명은 안전 중단, 화면 정상·필드 실패는 partial. 수집 완료 후보는 session 메모리에 검토용 보존; 자동 반영 없음 | F0 승인·목표 계약 완료, F1/F2 연결 |

승인된 D1/D3은 재질문하지 않는다. 새 정책 변경 없이 자동 영구 학습을 켜거나 화면 불명 상태에서
다음 학생으로 강행하지 않는다. 실패·취소 후보 보존은 검토용이며 기존 completed-only commit 규칙을 유지한다.

## 공통 검증과 산출물

각 F 단계는 `v6 특성화 → parity fixture → v7 구현 → focused tests → 기존 회귀 → 상태 갱신`을 따른다.
판독 정답 fixture와 입력 sequence용 fake capture/input을 분리한다. 템플릿을 같은 위치에 붙인 합성
프레임은 배선 검증이지 독립 실화면 정확도 증거가 아니다.

- slice 기록: 범위/R ID, v6 source SHA·함수, v7 파일, 결정, 전후 evidence,
  시도 상한·실패 결과, 실행 명령·결과·미검증 항목, 다음 단계.
- 인식 asset: 별도 versioned manifest, source/ROI/실해상도/SHA, 재현 가능한 sync/export tool.
  training/calibration/validation partition을 분리한다.
- 모든 slice: `cd backend; py -3.11 -m unittest discover -s tests -v`.
- protocol/UI 변경 slice 및 F12: `cd frontend; flutter analyze; flutter test`와 process E2E.
  자원 경합으로 `--concurrency=1` 재실행 시 첫 실패와 재실행을 모두 기록한다.
- F12: `cd frontend; flutter build windows --release`, release asset integrity, 실게임 확인.
- 문서: `codealmanac validate`, `codealmanac health`, `git diff --check`.

## 재개 지점

- **F0~F12 전체 완료**, 최종 Python533/Flutter400/analyze/release/asset 검증과 16:9 창 크기 3회
  D2 실게임 검증 통과.
  [@f0-result] [@f1-result] [@f2-result] [@f3-result] [@f4-result] [@f12-result]
- 자연 발생 native1280 저점수 T10/70 표본 부재와 native2560 특수 추론 비활성은 인지된 위험이다.
  새 독립 표본이 생기기 전에는 2560 branch를 켜지 않고 불확정 판독을 partial로 유지한다.
- 기존 S2W, Studio bank, 사용자 정답 샘플과 계산 검증 런타임은 F0에서 바꾸지 않았다.
  [@matchers] [@windows-input] [@equipment] [@weapon]
