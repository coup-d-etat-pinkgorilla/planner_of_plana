# F1 — 캡처·입력 복구 기반

2026-08-30. R01/R02 구현과 D3 내부 결과 전달을 연결했다. **F1 완료**.
후속 사용자 요청으로 실제 1280×720 게임 창에서 캡처·좌우 키·버튼·끝 순환을 확인했다.
전체 Python319개·Flutter399개와 정적 분석을 통과했다. F2~F12는 이번 변경 범위가 아니다.

## 참조와 변경 범위

- 구현 전에 `backend/tests/fixtures/scanner_fallback_restoration/f1-capture-input-parity.json`을 작성했다.
- v6 참조는 F0 `source-manifest.json`에 고정한 `core/capture.py:_print_window`,
  `core/scanner_components/runtime.py:_capture`, `core/input.py:click_point`,
  `core/scanner_components/student.py:_send_student_arrow`다. v6 runtime import는 없다.
- F0 소스 SHA는 당시 이력으로 유지한다. F1 이후 현재 v7 파일과 F0 SHA의 불일치는 예상된다.
  `f1-source-manifest.json`은 F1 변경 파일의 새 SHA와 v6 참조 SHA를 별도로 기록한다.
- 구현 파일은 `windows_scanner_adapter.py`, 새 `windows_capture_worker.py`,
  `scanner_matchers.py`, `scanner_session.py`, `scanner_runtime.py`다.
  인식 asset, 영구 샘플, profile/repository, wire schema, Flutter 소스는 이 slice에서 변경하지 않았다.

## 캡처와 입력 계약

캡처 순서는 client PrintWindow(3), client PrintWindow(1), full-window PrintWindow(2),
full-window PrintWindow(0), foreground client BitBlt다. full-window 결과는 실제 client 원점으로
잘라낸다. 검은색/균일 프레임을 성공으로 인정하지 않으며 최대 3라운드, 호출당 15방법을 시도한다.
안정화는 최대 12프레임 요청, 실패 요청 최대 3개, 연속 유사도 0.995 비교 2개를 요구한다.
중첩 방법 시도는 최대 180개이고 공통 deadline(기본 2초, 요청 상한 5초)을 공유한다.
라운드 간 대기는 최대 0.1초이며 취소 가능하다. 픽셀 수는 16,777,216 이하로 제한한다.

PrintWindow는 동기 호출이므로 별도 숨김 캡처 프로세스에 격리했다. 부모는 deadline 또는 취소 시
프로세스를 종료하고, 다음 캡처에서 새 프로세스를 만든다. 이 프로세스는 입력을 수행하지 않는다.
종료 시 process wait와 reader join은 각각 최대 1초의 정리 예산이 추가된다.
GDI bitmap을 DC에서 분리한 뒤 읽고, 모든 성공/실패 경로에서 DC/bitmap과 불필요한 PIL 이미지를 정리한다.
동기 호출과 client/full-window 의미는 [Microsoft PrintWindow 문서](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-printwindow)를 참조했다.

입력 전에 HWND, PID/thread 바인딩, 제목, 가시성, 최소화 여부를 확인한다. 최소화 창을 자동 복원하지 않는다.
비활성 창은 한 번 활성화를 시도하며, 실패하면 커서를 이동하지 않고 같은 HWND에 메시지를 보낸다.
전경 입력은 client→screen 변환, 창 위치/크기 재확인, foreground와 클릭 지점의 root HWND를 확인한다.
물리 입력이 0개 삽입된 경우만 메시지 대체를 허용한다. 부분 삽입은 release를 시도하고 중단한다.
양쪽 화살표는 확장 scan code down/up을 사용한다. 사용자가 modifier/마우스 버튼을 누른 상태에서는
물리 입력을 보류한다. [Microsoft SendInput 문서](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendinput)의
삽입 개수와 기존 키 상태 제약을 반영했다.

학생 순회는 키 API 실패 또는 동일 학생 재관측 시 버튼을 한 번 시도한다. 우측 무이동이면 왼쪽으로
전환하되, 왼쪽에서도 키/버튼 후 무이동이면 `navigation_unconfirmed`로 중단한다. 무이동을 목록 끝으로
단정하지 않는다. 서로 다른 학생을 거친 뒤 기존 학생으로 우측 순환한 경로는 기존 완료 동작을 유지한다.
순회 상한은 500회다. 저신뢰 ID는 종속 필드 판독 전에 중단하며 ID 재시도/끝 predicate는 F8에 남는다.

## D3 후보 소유권

내부 `ScanBatchResult`는 candidates/outcome/error/screen_state/coverage_complete를 전달한다.
외부에는 기존 candidate 이벤트를 먼저 보내고 기존 terminal 이벤트를 마지막에 보낸다.
실패·취소 전에 수집한 학생 후보와 재고 슬롯은 세션 메모리에 검토용으로 남긴다. 불완전 재고의
미확정 수량은 null이며 zero-fill하지 않는다. 실패·취소 세션의 commit은 계속 거부한다.
후속 후보 변환이 실패하면 이미 전달한 specimen은 세션이 보유하고, 나머지만 정리한다.
화면 상태는 F2 predicate 도입 전까지 unknown이다. 취소 이후 새 탐색은 금지하고 명시적 패널 닫기만 허용한다.

## 검증 기록

- F1 전용 29개 tests 통과(2.350초): native API fake, 실패→복구/15회 소진, full crop,
  비활성·최소화·소멸·HWND 재사용·초점/가림, 좌우 입력과 대체, 부분 삽입,
  안정화·이미지 수명, 실제 subprocess deadline/취소 종료 및 IPC 오류 왕복,
  학생·재고 후보 보존과 failed commit 거부를 포함한다.
- 최초 scanner-only 실행: 59개 중 1개 실패. 기존 테스트가 단일 `GetClientRect failed` 문구를
  기대했으나 새 동작은 15방법 소진 오류를 반환했다. 기대 오류를 새 계약에 맞추고 15회 상한 assertion을 추가했다.
- 전체 Python: 319/319 통과, 103.618초 (`f1-python-tests.txt`).
- Flutter analyze: 문제 없음, 44.1초 (`f1-flutter-analyze.txt`).
- Flutter 전체 test `--concurrency=1`(실제 Python process E2E 포함): 399/399 통과, 2분36초
  (`f1-flutter-tests.txt`).
  초기부터 순차 실행을 선택했으며 경합 실패 후 결과를 숨긴 재실행이 아니다.
- `codealmanac validate`, `codealmanac health`, `git diff --check` 통과. F1 SHA 무결성 확인 통과.
  Windows release는 F12 범위이므로 이번에 빌드하지 않았다.
- 실제 창 탐색: `f1-live-availability.json`. 검색 결과 0개. 게임 입력, 계정 변경, 재화 사용은 0회다.

## 남은 gate와 한계

- 후속 실검증: `debug/scanner_f1_live/00-background.png`와 `01`~`08` PNG/JSON.
  비활성 게임 capture 0.328초, 입력 후 안정화/프로세스 정리 포함 1.156~1.688초.
  8회 입력(목록/상세 진입2, 좌우 키4, 좌우 버튼2)이 모두 SendInput으로 성공했다.
  미카↔히나(드레스), 첫 미카→왼쪽 끝 미유→오른쪽 첫 미카 순환을 육안 확인했다.
  캡처는 모두 client PrintWindow3 첫 방법으로 성공했다. 재화 사용·강화·장착 변경·저장0회.
  F1 완료 판단은 이 실제1280 정상 경로와 앞선 실패/취소 자동 tests를 함께 근거로 한다.
  실제2560·메시지 거부·OS 핸들 장기 추적 coverage는 여전히 F12에 남으며 실검증으로 과장하지 않는다.
- OS의 foreground 확인과 SendInput 사이에는 원자적 HWND 잠금이 없다. 직전 재검사로 위험을 줄였지만
  동시 사용자 입력의 모든 race를 보장하지는 못한다. 실검증 중 마우스/키보드 개입을 피해야 한다.
- BitBlt는 foreground일 때만 시도하지만 부분 가림의 모든 픽셀을 보증하지 않는다.
  게임별 PrintWindow 동작, DPI/모니터 환경, OS 핸들 수 장기 추적은 실검증 전까지 미확인이다.
- HWND가 다른 PID/thread로 재사용되면 기존 adapter는 거부하며 재시작이 필요할 수 있다.
- F2의 패널 열림/닫힘·기본 복귀 확인, F8의 검증된 좌우 끝, F10의 재고 무이동/실제 끝 구별은 미구현이다.
  이번 D3 연결을 전체 화면 복구 구현 완료로 해석하지 않는다.
