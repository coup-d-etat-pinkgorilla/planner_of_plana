# F3 능력 개방 기본·상세 판독

2026-08-31, R06 구현·실게임 확인·최종 전체 회귀를 통과하여 **F3 완료**다.
F4 이후 구현과 F12 release build는 이번 범위에 포함하지 않는다.

후속 요청의 실제1280 상세·복귀 재검증도 통과했다. 아래는 최초 F3 완료 당시 기록이며,
추가 검증 및 F4 구현은 [후속 결과](f4-results.md)에 별도로 기록한다.

## 구현

- 구현 전에 `backend/tests/fixtures/student_potential_f3_v6_parity.json`에 v6 레벨90/5성 gate,
  기본 배지 존재·부재, 0–25 범위, 기본/상세 ROI와 안전 차이를 고정했다.
  v6 `read_basic_combat_stats`, `read_stats`, `read_basic_additional_stat_badge_result`,
  `read_basic_additional_stat_value_result`, `read_stat_value_result`를 행동 참조로 읽었다.
  v6 런타임 import, Qt UI 복사, 추가 Python dependency는 없다.
- `StudentPotentialRecognizer`가 HP/ATK/HEAL 능력 개방을 `stat_hp/stat_atk/stat_heal`로 판독한다.
  표시 전투 능력치 `combat_hp/combat_atk/combat_def/combat_heal`은 별개다.
- 레벨90 미만 또는 5성 미만이 확정이면 잠금 gate로 0을 추론하고 패널을 열지 않는다.
  조건이 불명이면 세 필드를 `dependency_missing`으로 남기며 잠금이나 해금을 추측하지 않는다.
- 기본 배지의 파랑 비율 ≥0.08은 존재, ≤0.02이면서 밝은 정보 표면과 글자 신호가 있을 때만 부재다.
  검정·흰색·회색 빈 ROI, 희미한 배지, 부족한 정보는 부재가 아니며 0으로 바꾸지 않는다.
  별도 `potential_badge_*` evidence는 payload 저장 필드에 넣지 않는다.
- 기본 부재 확정은 `potential_badge_absent`/inferred 0, 숫자는 `potential_basic_template`다.
  배지의 대표 파랑 표면 안쪽 숫자를 정규화하여 MAX 외곽선과 공통 Lv 접두어를 비교에서 제외한다.
  흰색 숫자와 노란 최대치 숫자를 모두 처리한다. 고정 번들 원본과 1/2 크기에서 glyph 변형을 만들며,
  사용자/게임 관측 이미지를 bank에 추가하거나 영구 학습하지 않는다.
  bank는 실제 판독 시 해당 종류만 지연 초기화하므로 readiness/창 목록 조회와 잠금 gate는
  숫자 템플릿을 디코딩·정규화하지 않는다.
- 템플릿 비교는 binary IoU 0.55 + 정규화 상관 0.45, 최소 점수0.78이다.
  기본 최소 차이0.035, 제목 확인을 거친 상세 전용 ROI는 작은 글자 차이를 고려하여0.025다.
  v6 상세의 최소0.60·차이 미요구보다 보수적이며, 낮은 분리도는 미확정으로 남는다.
- 세 기본값이 모두 확정이면 패널 입력 없이 종료한다. 하나라도 미확정이면 상세 세 ROI를 읽는다.
  `StatMenuCaptureAdapter`는 장비/무기와 같은 F2 recovery 인스턴스를 공유한다.
  열기 입력1회/4초, 최초+추가2회 판독, 재캡처별2초, 닫기5초/입력3회 및 동일 학생 복귀를 유지한다.
  합산 단계 deadline은 최대13초이며 worker 강제 정리 예산은 F1 계약을 따른다.
- 확정값은 약한/미확정 값으로 덮어쓰지 않는다. 기본·상세 확정값 충돌은 첫 값과 두 출처를 보존하고
  `panel_value_conflict`와 review_required를 유지한다. 안전한 기본 복귀 후 판독 실패는 partial,
  화면 불명/학생 변경/취소는 기존 F2 안전 중단 경계를 따른다.
- 계산 검증은 `details.potential_inputs`에 값·source·fresh를 기록한다. 저장값은 계산 참고용
  `profile_fallback`일 뿐 새 화면 검증의 누락 의존성을 해소하지 않는다. 충돌·범위 밖 값·bool도
  fresh가 아니다. 기존 프로필이나 후보 payload를 변경하지 않고 `dependency_missing`을 반환한다.

## 자산과 회귀

- `sync_student_potential_f3_assets.py`: 기본25장 + 상세3×26장 + ROI1개 =104개.
  `student_potential_manifest.json`에 원본 경로/bytes/SHA를 기록한다. 전체 recognition asset은1913개다.
- 전용24 tests: gate/잠금, 전부0, 일부25/중간값, 존재·부재·불명, 모든 원본103개 label,
  상세3회 상한/값 보존/충돌/열기 실패/복귀 실패/취소, 실제 matcher 연결,
  저장값 분리/새 값 우선/충돌·유효 범위, 실제1280/2560 캡처와 synthetic1280 상세 보완.
- 실게임6 PNG를 `student_potential_f3_live/manifest.json`에 SHA와 육안 정답으로 고정했다.
  개발 중 사용한 회귀 데이터이며 독립 holdout 정확도로 주장하지 않는다. runtime asset과도 분리한다.
- 실제1280 기본 미카 샘플은 HP/ATK의23/25 분리도가 부족하므로 미확정이다. 상세 보완 tests의1280
  상세 이미지는 실제2560을 축소한 synthetic 입력이다. 실제1280 상세창 입력 검증은 이번에 하지 않았다.
- 초기 전체362개 실행은 기존 S4 계산 tests의 저장값-only verified 기대2건과 S2의 능력 개방 필드
  제외 기대1건에서 실패했다. 새 F3 계약에 맞춰 테스트를 갱신했으며 최초 로그를 보존한다.
  1280 추가 회귀 중에는 MAX/Lv 공통 픽셀과 작은 글자 분리 문제를 확인하고 위 정규화/폴백을 보완했다.

## 실제 게임 확인

선택한 게임 `hwnd:de0e88`, 클라이언트2560×1440, 2026-08-31 KST.

- 미카 기본·상세: 25/25/25. 최종 단일 학생 스캔도 실제 레벨90/5성과 능력 개방25/25/25를 읽었고
  최종 재검증에서 패널 입력 없이2.656초에 반환했다. `debug/scanner_f3_live/mika-single-scan-final.json`.
- 히나(드레스) 기본·상세: 25/25/0. 기본 치유 배지 부재의0이 상세 Lv.0과 일치했다.
- 미유 기본: Lv.1/3성 잠금, 회귀에서 잠금 gate와0/0/0을 확인했다. 잠긴 창은 열지 않았다.
- 실제 상세창 정상 복귀, 취소 후 새 캡처 중단 및 동일 학생 기본 복귀를 trace/PNG로 기록했다.
  최초 열기1회는 입력이 반영되지 않아 제한 확인 후 `panel_open_failed`/기본 복귀로 끝났다.
  원인을 확정하지 않았고 자동 재클릭을 추가하지 않았다. 이후 독립 실행의 진입/복귀는 성공했다.
- 게임은 미카 기본 화면에 남겼다. 재화 사용, 성장, 장비 변경, 계정 조작, repository 반영은 없다.

## 검증 결과와 한계

- F3 focused:24/24 통과,12.361초 (`f3-focused-tests.txt`). 실제 stdio3/3 통과,4.961초 (`f3-stdio-tests.txt`).
- Flutter: analyze 이슈0,399/399 tests 통과 (`f3-flutter-analyze.txt`, `f3-flutter-tests.txt`).
- 전체364개 첫 실행에서 F3 관련 검사는 통과했지만 기존 Studio builder가 두 번째 생성의
  `debug/student_suggestion_rois/templates/font.ttf` 재쓰기 중 `OSError 22`로 실패했다.
  F2에도 같은 생성 폴더의 간헐적 쓰기 실패 이력이 있다. 원인은 확정하지 않았고 builder를
  수정하지 않았다. 실패 로그는 `f3-python-tests-font-write-error.txt`, 단독6/6 통과 로그는
  `f3-studio-rerun.txt`에 보존했다. 다른 템플릿 생성 작업과 겹치지 않게 전체 재실행했다.
- 다음364개 실행에서는 Studio가 통과하고 실제 backend readiness/target-list process가10초 제한을
  넘겼다 (`f3-python-tests-startup-timeout.txt`). 정확한 지연 원인은 확정하지 않았으나 F3의 불필요한
  시작 시 숫자 bank 정규화를 종류별 첫 판독 시점으로 옮겼다. 시간 제한이나 판독 임계값은 올리지
  않았으며, 실제 stdio 재검증과 준비/잠금 중 glyph 디코딩 금지 회귀가 통과했다.
- 최종 전체 Python365/365 통과,182.767초 (`f3-python-tests.txt`).
- 자산1913개 ready, missing/corrupt0; F3 source24파일/참조함수5개와 live6 PNG SHA 일치.
  Almanac validate/health 및 git diff --check 통과.
- 실제 중간값/해금 전부0의 게임 패널, 실제1280 상세, 다중 DPI, 장시간 자원 측정은 미검증이다.
  0–25 원본 템플릿 회귀나 축소 입력을 그 실제 게임 coverage와 동일시하지 않는다.
- F0/F1/F2의 역사적 source manifest는 변경하지 않는다. F3 snapshot은 `f3-source-manifest.json`이다.
  다음 단계는 F4 레벨 탭 폴백이다.
