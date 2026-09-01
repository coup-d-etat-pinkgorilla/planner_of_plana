# F3 실제1280 재확인 및 F4 레벨 탭 폴백

2026-08-31 사용자가 “1280에서도 재확인하고 정상일 경우 F4 시작”을 요청했다.
F3 실제1280 gate 통과 후 F4 R07 구현과 검증을 완료했다. Python383개 및 Flutter 순차399개 회귀를 통과했다.

## F3 실제1280 gate

게임 창은 이미1280×720이었다. 별도 확대/축소 없이 native client 캡처로 검증했다.
`debug/scanner_f3_1280_live/00-basic.json`에 크기와 PNG SHA를 기록했다.

- 미카의 실제 단일 학생 스캔은 기본 HP/ATK 배지의 부족한 분리도를 상세창으로 보완하여
  `stat_hp/stat_atk/stat_heal=25/25/25`를 얻었다. 상세창 열기1회·기본 복귀1회였다.
- 독립 미카 상세 판독25/25/25, 히나(드레스)25/25/0이 육안 화면과 일치했다.
- 정상 복귀와 취소 후 새 캡처 중단·동일 학생 기본 복귀를 확인했다.
- F3 판독 코드나 임계값은 변경하지 않았다. 기존 F3의 synthetic1280 상세 대신 실제1280
  상세 PNG를 별도의 F4 live fixture로 추가했다. F3 historical SHA manifest는 유지한다.
- 증거: `debug/scanner_f3_1280_live/{mika-single.json,mika-stat/,mika-cancel/,hina-stat/}`.

이 결과로 사용자가 정한 F4 시작 조건을 충족했다.

## F4 구현 계약

- v6 `read_level`, `read_student_level_v5`, `read_student_level`, `read_level_digit`와
  `student_level_info_regions.json`을 읽고 parity fixture를 먼저 작성했다.
  `../v6` 런타임 import, Qt UI 복사, 새로운 패키지 dependency는 없다.
- `StudentBasicRecognizer.read_level`의 Studio→glyph 경로를 유지한다. 두 경로로 기본 레벨을
  확정하면 레벨 탭 입력은0회다. 미확정이면 `StudentLevelRecognizer.resolve`가 레벨 탭으로 보완한다.
- 전용 `level_digit_1/2` ROI와 v6 숫자19장 + ROI1개를 버전 manifest로 고정했다.
  전체 recognition asset1933개. 첫 자리1–9, 둘째0–9이며 값은 프로젝트 최대레벨90으로 제한한다.
- v6의 `2_null.png`는 숫자처럼 보이며 v6 matcher도 숫자 범위만 구성해 그 파일을 사용하지 않는다.
  이를 부재 정답으로 복사하지 않았다. 둘째 ROI가 충분히 밝고 균일하며 잉크 비율≤0.005인 경우만
  한 자리로 판독한다. 둘째 자리 판독 실패를 한 자리 성공으로 줄이지 않고, 첫 자리 실패 시 둘째
  자리만 성공값으로 채택하지 않는다. 검정/흰색/회색 전체 화면은 레벨로 확정하지 않는다.
- 숫자의 어두운 글자 mask를 정규화하여 위치별 고정 원본/1/2 크기 glyph와 비교한다.
  최소 IoU0.58, 후보 차이0.035. 준비/창 목록 호출은 glyph bank를 만들지 않고 실제 판독 때 지연 로드한다.
- `LevelMenuCaptureAdapter`가 기존 F2 recovery를 공유한다. 활성 레벨 탭 확인 후 최초+추가2회
  판독까지 허용하며, 매 재캡처에도 레벨 탭을 확인한다. 열기4초, 재캡처별2초, 복귀5초의
  기존 단계 deadline을 유지한다. UI 캡처 안정화 횟수와 숫자 판독3회 상한은 구분한다.
- 복귀는 기본 정보 탭 클릭과 같은 학생 이름/초상 확인이다. 패널 X 좌표를 레벨 탭에 적용하지 않는다.
  취소는 판독을 중지하고 독립 cleanup으로 복귀한다. 복귀 불명이나 다른 학생은 안전 중단한다.
- 상세 실패 후 안전 복귀는 level 미확정 + level_panel/partial로 남긴다. 확정된 다른 필드는
  유지하며, 기존 확정 레벨이나 sticky conflict는 재판독으로 덮어쓰지 않는다.
- 레벨 보완은 능력 개방·장비 gate보다 먼저 적용된다. 상세 레벨 출처는 `level_tab_template`이며,
  F11의 session-local 자동 학습을 앞당겨 추가하지 않았다. 프로토콜 필드/Flutter UI 변경은 없다.

## 실제 게임 및 진단

- 실제1280 미카 레벨 탭 Lv.90과 미유 Lv.1을 읽었고 각각 동일 학생 기본 화면으로 복귀했다.
  미유 취소 후 복귀도 통과했다. 모든 클릭은 탭 전환 또는 기존 읽기 전용 상세창에 한정했다.
- `verify_student_potential_live.py --force-level-fallback`은 진단 실행에서만 기본 레벨 결과를
  미확정으로 치환한다. 실제 게임 픽셀/레벨은 바꾸지 않는다. 미유 진단 전체 스캔은 실제 레벨 탭의
  Lv.1로 복구했고 그 값으로 잠금 gate를 처리했다. 자연 발생 기본 판독 실패 사례로 주장하지 않는다.
  `miyu-injected-single-final.json`에 진단 표시, level_tab_template 출처, 별도 level_fallback_trace를 기록했다.
- 증거: `debug/scanner_f4_live/`의 기본/레벨/복귀 PNG, 패널 정상·취소 trace와 진단 JSON.
- 게임 성장, 보고서 선택, 자동 선택, 레벨 업 실행, 장비 변경, repository 반영은 하지 않았다.

## 회귀와 재현

- `test_student_level_f4.py`18 tests: 원본으로 구성한1–90 레벨, blank/미확정 자리/범위 밖,
  기본 성공 클릭0, 3회 성공·소진, 안전 실패/복귀 실패/취소/다른 학생, 확정 필드 보존,
  실제 matcher 종속 gate 순서, 실제1280 F3/F4 판독 및 화면 상태.
- `student_level_f4_live/manifest.json`에 실제1280 PNG9개를 SHA와 육안 정답으로 고정했다.
  개발 회귀이며 holdout 정확도나 runtime 학습 자료가 아니다. 원본 템플릿 조합 tests도 실제
  모든 레벨의 게임 검증과 동등하다고 주장하지 않는다.
- 재현 도구: `sync_student_level_f4_assets.py`, `export_student_level_f4_fixtures.py`,
  `verify_student_panel_live.py level`, 선택적인 `--force-level-fallback` 단일 학생 진단.
- 전체 Python383/383 통과,234.887초 (`f4-python-tests.txt`). Flutter analyze 이슈0,2.0초
  (`f4-flutter-analyze.txt`).
- Flutter 기본 병렬 실행은 Python 전체 검사와 동시 실행 및 Flutter 단독 재실행 모두394/399 통과,
  planning/repository/scenario/tactical의 실제 Python process E2E5개가 최초 응답10초 제한을 넘겼다.
  각각 `f4-flutter-tests-first-failed.txt`, `f4-flutter-tests-second-failed.txt`에 원본 로그를 보존했다.
  F2 검증과 같은 `flutter test --concurrency=1` 전체 재검증은399/399 통과,3분30초
  (`f4-flutter-tests.txt`). 제한 시간이나 제품 코드는
  이 실패를 피하려고 변경하지 않았다. 병렬 실행에서의 지연 원인은 확정하지 않았다.
- 인식 자산1933개 ready, missing/corrupt0. `f4-source-manifest.json`의 소스19개와 실제 PNG9개 SHA
  일치. 기존 F0~F3 소스 스냅샷을 재생성하지 않았다. Almanac validate/health 및 git diff --check 통과.
- F4의 실제2560 탭 입력, 실제 중간 레벨 다수, 다중 DPI·장시간 자원 측정은 미검증이다.
  F12 통합/릴리스 항목과 구분한다. F5 이후는 시작하지 않았다.
