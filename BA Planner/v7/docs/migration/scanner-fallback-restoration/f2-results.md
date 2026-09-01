# F2 — 공통 패널 복구·전용무기 안전 통합

2026-08-30. **F2 완료**. R03~R05 구현, 실제1280 게임 검증, Python341개·Flutter399개 회귀를 통과했다.
사용자의 조건부 요청에 따라 F1의 실게임 gate를 먼저 통과한 뒤 F2를 시작했다.

## F1 후속 실검증

`debug/scanner_f1_live/`의 로비/학생 목록/상세 PNG와 단계01~08 JSON은 실제 adapter 결과다.
비활성 게임 캡처, 미카↔히나(드레스)의 좌우 키/버튼 왕복, 첫 미카→끝 미유→첫 미카 순환을 확인했다.
게임 입력8회, 모두 SendInput. PrintWindow3 첫 방법 성공. 정상 경로와 기존 실패/취소 tests를 근거로
F1을 완료했다. 실제2560, OS 입력 거부 강제 재현, 장시간 핸들 측정까지 통과했다는 의미는 아니다.

## 구현과 계약

구현 전 `f2-panel-parity.json`에 v6 호출·임계값·제한·값 보존 계약을 작성했다.
참조는 v6 `_click_student_region_and_wait`, `_close_student_panel`, `_restore_basic_tab`,
`_is_student_panel_title_capture`와 제목/탭 템플릿이다. F0 소스 SHA 이력은 유지하며 F2 파일 SHA는
`f2-source-manifest.json`에 별도 고정한다. v6 런타임 import나 Qt UI 복사는 없다.

- 새 `student_panel_recovery.py`가 기본 확인→열기→제목 확인→판독/재캡처→닫기→동일 학생 기본 복귀를 소유한다.
  production student scan도 기본 탭 확인 전에 종속 숫자를 판독하지 않는다.
- 장비·고유무기·스킬·능력치 제목4개를 경쟁시킨다. 제목 점수는 0.7 NCC+0.3 color, 최소0.86/차이0.04다.
  제목이 애매하면 기본 탭으로 간주하지 않는다. 템플릿 누락을 permissive 성공으로 바꾸지 않는다.
- 기본/레벨/성급 활성 탭은 color≥0.90과 NCC≥0.75를 함께 요구한다. 처음 사용한 혼합점수는 실제1280
  레벨 탭을0.888로 거부했다. 밝은 활성 표면과 글자 상관을 따로 확인하는 방식으로 보완했으며,
  기본/레벨/성급 실제 화면 및 black/white/gray 음성을 회귀에 고정했다. 임계값을 동적으로 학습하지 않는다.
- 기본 복귀에는 활성 탭 외에 사전 nameplate(color≥0.985)와 초상 영역(color≥0.90) 일치를 요구한다.
  다른 학생으로 복귀하면 중단한다. 수집한 로비 음성도 기본 화면으로 판정하지 않는다.
- 열기는 입력1회, 사전 기본1회+대상 확인4회 이하, 공통4초다. 추가 대기/최종 확인을 포함한다.
  닫기는 상태 확인7회 이하/입력3회 이하/5초다. 확인된 패널의 X→같은 X 내부 대체점→Escape 순서이며,
  모르는 화면에 임의의 X 좌표를 누르지 않는다. 레벨/성급 탭이면 기본 탭으로 복귀한다.
- 무기 판독은 최초+추가2회다. 재판독 전에도 대상 제목을 확인하며 재캡처마다 확인2회/2초 이하다.
  최대 무기 transaction은 안정화 호출16회, F1의 호출당 최대180방법을 곱한 이론상2880방법 이하다.
  단계 deadline(열기4+재캡처2×2+닫기5초)이 먼저 적용되며, F1 worker 강제 종료의 별도 정리 예산은 유지된다.
- 취소는 새 열기/재판독을 막는다. 이미 열린 패널은 독립된 제한 시간/취소 토큰으로 닫기를 검증한다.
  Escape는 일반 scan code로 전송하고 좌우 키의 extended flag와 구분한다.
- production 장비/무기는 한 recovery 인스턴스를 공유한다. 종료 시 baseline crop과 템플릿/worker를 정리한다.

## 관측값·실패 처리

확정된 기본값이나 이전 재시도값을 더 높은 confidence의 미확정값으로 덮어쓰지 않는다.
확정값이 서로 다르면 첫 값을 candidate payload에 남기고 `panel_value_conflict`/uncertain evidence에
두 값과 출처를 기록한다. 이후 retry로 충돌을 지우지 않고 review_required를 켜며 그 값을 보정 학습에 쓰지 않는다.
보존된 기본값도 상세 정답으로 재사용하지 않는다. 기존 장비 임시 보정은 새 `equipment_menu_digit` 출처만 받는다.
상세값 일부만 복구되면 해당 필드만 보완한다. 무기 장착 상태가 불명이면 상세창을 열지 않는다.

열림/판독 실패 뒤 **같은 학생 기본 복귀가 확인된 경우만** 기존 값을 유지하고 partial evidence를 반환한다.
잘못된 학생, target/input 안전 오류, 기본 복귀 실패는 계속 실패로 전달한다. D3의 이전 완료 후보 보존과
failed/cancelled commit 금지는 유지한다. F3~F11의 새로운 필드 폴백/영구 학습은 켜지 않았다.

## 실제 게임 증거

`debug/scanner_f2_live/`:

| 경로 | 관측 |
|---|---|
| `weapon-roundtrip/` | 제목 weapon≈0.959, 레벨60·4성 판독, 미카 기본 복귀; 2.765초 |
| `equipment-roundtrip/` | 제목 equipment≈0.970, 경쟁 stat≈0.833, 기본 복귀; 2.875초 |
| `weapon-cancel-roundtrip/` | 열린 후 취소, 재캡처0회, 정리 닫기와 기본 복귀; 2.891초 |
| `03-level-tab-negative.png`, `04-star-tab-negative.png` | 기본 화면이 아닌 실제 활성 탭 음성, 이후 기본 복귀 |
| `student-mika-single.json` | 실제 단일 matcher 1.250초, 미카90/인연74/5성, 무기60/4성, T10/70×3; 기본 성공으로 상세 클릭0회 |

새 전환 코드를 통해 고유무기·장비를 실제 열고 닫았고 복귀 PNG를 육안 확인했다.
보조 reference 열기/닫기와 탭 조회 외 강화 실행·장착 변경·재화 사용·계정 전환은 없었다.
후보는 파일/메모리에만 기록했으며 repository와 사용자 정답 bank에 쓰지 않았다.

`backend/tests/fixtures/student_panel_f2_live/`에는 SHA를 고정한 실제1280 프레임8개를 별도 보관했다.
이 프레임들은 개발/회귀 자료이며 runtime 학습 템플릿이 아니다. 활성 탭 보완에 관측을 사용했으므로
보지 않은 holdout 정확도로 주장하지 않는다. 원본2560/derived1280과도 혼동하지 않는다.

## 자동 검증

- F2 전용19개 통과(1.886초): 지연 최종 확인, 무반응, 오패널, 대체 X/ESC, 닫기 소진,
  다른 학생, 취소, 재캡처 상태, 누락 템플릿, 값 보존/충돌, 실제8프레임, 경쟁 제목.
- S2W9개 통과(14.148초): 기존 무기 회귀 + 미확정 상태 클릭 금지 + 충돌 payload 보존.
- S3 장비16개 통과(10.046초). 기존 검은 메뉴 fake의 source 기대를 교체해 실제 unresolved 슬롯만
  읽고 기존 관측값/partial evidence를 보존하는 계약을 검사한다.
- 전체 Python 최초340개: 2개 실패, 자산 개수1801 기대가 신규8개를 포함한1809와 불일치했다
  (`f2-python-tests-first.txt`,141.431초). 기대값 갱신 후340/340 통과(126.472초,
  `f2-python-tests-pre-calibration-guard.txt`). 보정 출처 guard와 추가1개 테스트를 포함한341개 실행에서는
  기존 Studio builder의 `renderer_spec.json` write가 일회성 OSError22를 반환했다(129.388초,
  `f2-python-tests-renderer-io-error.txt`). 원인은 미확정이며 코드/테스트를 바꾸지 않고 해당6개를 재실행해
  모두 통과했다(4.677초). 최종 전체341/341 통과(128.195초, `f2-python-tests.txt`).
- Flutter analyze: 문제 없음(2.2초). 전체 `flutter test --concurrency=1`은399/399 통과(3분15초, process E2E 포함).
- `codealmanac validate`, `codealmanac health`, `git diff --check` 통과. recognition1809개 missing/corrupt0,
  F2 구현/fixture16파일·실게임 증거37파일 SHA 확인 통과. Windows release 빌드는 F12 범위다.

## 남은 범위

F3의 능력 개방 판독, F4/F5/F6의 탭/스킬 숫자 폴백, F7 전체 보기/애용품, F8 ID/폼 복구,
F9/F10 재고, F11 보정 수명은 이번 변경에 포함하지 않았다. 제목/탭 확인은 이들의 공통 기반이다.
실제 오류를 유발하는 창 강제 종료·OS 입력 거부·강제 틀린 패널은 fake tests로 검증했으며,
실제1280 정상/취소 경로와 구분한다. 실제2560와 여러 DPI·장시간 자원 추적은 F12 통합 검증에 남는다.
