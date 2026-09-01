# F11 실행 중 보정 샘플·정답 샘플 격리 결과

2026-09-01 사용자 지시로 R24와 승인된 D1 정책을 구현했다. 자동 보정은 현재 스캐너 session의
메모리 안에서만 존재하고, 사용자 명시 확인 샘플만 기존 영구 bank에 저장된다. native1280 실제
게임에서 상세 레벨 정답으로 만든 샘플의 같은 학생 재판독을 확인했으며 Python529개,
Flutter399개와 analyze를 통과해 F11을 완료했다. F12는 시작하지 않았다.

## 구현과 격리 계약

- `backend/tests/fixtures/session_calibration_f11_v6_parity.json`에 v6의 상세 레벨/장비 메뉴 성공값→
  기본 glyph run template 호출과 D1 목표 계약을 구현 전에 고정했다. Qt facade와 v6 runtime import는
  추가하지 않았다.
- `backend/core/session_calibration.py`의 `SessionCalibrationStore`는 profile ID, 실제 캡처 크기,
  scanner session ID/generation, canonical 학생/폼, field와 ROI로 샘플을 구분한다. 각 digit/ROI는
  최대4개이며 모두 Pillow 메모리 이미지다. 파일 경로나 저장 API가 없다.
- 자동 샘플은 검증된 `level_tab_template` 또는 `equipment_menu_digit` 상세 출처, 확정된 정수값,
  충돌 없음이 모두 성립할 때만 들어간다. panel conflict, 미확정 상세, session 보정 출처는 거부한다.
  따라서 matcher 출력이 자신의 다음 정답 label이 되는 경로가 없다.
- `ScannerSessionService.start`가 내부 target에 실제 session ID와 generation을 전달한다.
  `StudentMatcherAdapter.__call__`이 bank를 만들고 `finally`에서 모든 활성 session template와 원본
  sample을 닫는다. 취소·성공·실패 terminal이 같은 정리 경계를 사용한다. profile이나 실제 캡처
  해상도가 바뀌어도 기존 sample을 즉시 폐기한다.
- 다음 학생 판독 전에는 동일 canonical 학생/폼의 sample만 활성화한다. 레벨 상세 성공은 학생 레벨
  Studio cell에, 장비 메뉴 성공은 해당 slot ROI에만 연결한다. 기존 recognizer 인스턴스 수명
  `_empirical` 학습은 production caller에서 제거해 session 밖 누출을 막았다.
- `StudioNumericBank` 우선순위는 사용자 확인(+0.08), session 보정(+0.04), 번들 순이다.
  결과 출처도 `_user_confirmed`, `_session_calibrated`, 기본 번들로 구분한다. 자동 sample을 사용자
  확인 evidence로 표시하지 않는다. 명시적 후보 재검증만 `RecognitionAnswerSampleStore.save_*`를
  호출하는 기존 경계는 그대로다.

## native1280 실게임 검증

학생 목록에서 하나코(수영복) 기본 화면을 열고 진단 주입으로 첫 기본 레벨만 미확정 처리했다.
검증된 레벨 탭은 Lv.90을 `level_tab_template`로 읽고 같은 학생 기본 화면으로 복귀했다. 기본 화면의
두 digit cell에서 session sample 2개가 생성됐다. 같은 session에서 즉시 두 번째 판독을 실행하자
Lv.90이 `student_level_studio_position_bank_session_calibrated` 출처로 확정됐고 두 번째 레벨 패널
입력은0회였다. 첫 상세 open/restore와 동일 학생 복귀 상태는 trace에 남겼다.

검증 후 session bank는 닫혔고 게임은 시작 화면인 학생 목록으로 복귀했다. 게임 계정의 학생 상태,
장비, 성장, 재화, profile/repository와 `recognition_samples/`에는 쓰지 않았다. 결과는
`debug/scanner_f11_live/session-calibration-1280.json`에 있으며 첫 Lv90, session sample2,
두 번째 Lv90/provenance/입력0을 함께 기록한다.

## 자동 검증

- F11 전용8/8: D1 fixture, 상세 오류·충돌·자기출력 거부, 학생/폼·profile·해상도·session/generation
  분리, scope 변경·terminal 폐기, 사용자 정답 우선권과 provenance를 확인했다.
- 정답 sample/session focused26/26와 레벨18/18, 장비 F7 28/28, production adapter12/12를 통과했다.
  사용자 수정·재검증만 영구 학습하는 기존 회귀도 포함한다.
- 최종 Python529/529(274.584초), Flutter analyze 문제 없음(2.3초), Flutter399/399 순차
  테스트(3:39)를 통과했다. 전체 suite는 서로 겹쳐 실행하지 않았다.
- `git diff --check`, `codealmanac validate`, `codealmanac health`는 최종 문서 검사에서 확인한다.

```powershell
cd backend
py -3.11 -m unittest discover -s tests -v
py -3.11 tools/verify_student_potential_live.py --target <target> `
  --output ../debug/scanner_f11_live/session-calibration-1280.json `
  --verify-session-calibration
cd ../frontend
flutter analyze
flutter test --concurrency=1
```

한계: 새 실게임 증거는 native1280 한국어 UI의 학생 레벨90 한 조건이다. 장비 session 보정은
같은 공통 store/Studio bank 배선과 기존 실제 장비 메뉴 자료를 사용한 자동 회귀로 검증했으며,
이번 F11에서 별도의 자연 발생 기본 장비 실패를 만들었다고 주장하지 않는다. native2560, 다른 DPI/
언어, 여러 학생·폼 장시간 full scan, 실제 Dart↔Python process의 session 종료·재시작은 F12 통합
coverage로 남긴다. 자동 sample의 영구 승격은 계속 금지된다.
