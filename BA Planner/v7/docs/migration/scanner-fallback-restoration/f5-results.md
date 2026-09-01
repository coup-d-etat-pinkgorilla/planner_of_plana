# F5 성급 추론·성급 탭 폴백

2026-08-31. **F5 완료**. R08/R09 구현, 전용22개 검사와 실제1280 게임 검증,
전체 Python405개·Flutter 순차399개 회귀를 통과했다. F6 이후는 시작하지 않았다.

## 구현과 안전 경계

- v6 `scanner_components/student.py:read_student_star`, `matcher.py:read_star_result`,
  `read_student_star_v5_result`, `student_star_region.json`을 특성화하고 parity fixture를 먼저 고정했다.
  v6 런타임 import나 UI 코드를 복사하지 않았다.
- 기존 기본 별 판독을 유지하고, 학생 성급을 전달하지 않은 독립 flag ROI 판독을 먼저 수행한다.
  `basic_weapon_state_template` 출처와 `ok` 상태의 장착/해금 후 미장착만 학생5성 추론에 사용한다.
  `student_star_gate`, `basic_weapon_values` 및 다른 `inferred` 상태는 역추론에 사용할 수 없다.
- 기본 확정값과 추론이 일치하면 기본 출처를 유지한다. 기본1~4와 무기 해금이 모순되면 기본값을
  `panel_value_conflict`로 보존하여 검토 대상으로 남긴다. 재시도로 충돌을 지우지 않는다.
  이 값은 확정 성급 gate로 사용하지 않으며 stats validator도 계산 성공으로 처리하지 않는다.
- 기본과 독립 추론 모두 불충분한 경우 `StarMenuCaptureAdapter`가 F2 recovery로 성급 탭을 확인한다.
  `StudentStarRecognizer`가 현재 성급의 전용 ROI를 한 번 읽는다. 오른쪽 성장 후 예상 별은 읽지 않는다.
  무기 미해금만으로는 특정 학생 성급을 추정하지 않는다.
- v6 별1~5 템플릿5개와 ROI1개를 recognition manifest에 별도로 추가했다. 총1939개 자산이다.
  별 bank는 상세 판독 때 지연 로드하며 기본 성공/무기 추론/준비·창 목록에서는 디코딩하지 않는다.
  v7은 정규화 상관계수≥0.60, 후보 차이≥0.035 및 밝기/분산 신호 검사를 적용한다.
  v6 masked matcher와 동일 알고리즘이라고 주장하지 않는다. blank/템플릿 부재는1성으로 기본값 처리하지 않는다.
- 기본 성공·독립 추론 성공은 성급 탭 클릭0회. 상세 실패 후 안전 복귀는 partial이고 다른 확정 필드는 보존한다.
  활성 성급 탭에서 기본 정보 탭을 눌러 동일 학생 복귀를 확인한다. 다른 학생/복귀 불명은 안전 중단한다.
  F2의 열기4초/복귀5초 deadline과 취소 cleanup을 공유한다. 성급 상세 숫자 판독은1회이다.
- 성급 보완은 능력 개방과 성급 기반 무기 gate보다 먼저 실행된다. F11 학습, 프로필 반영,
  게임 성장/재화 사용/장비 변경, Flutter UI나 protocol 변경은 추가하지 않았다.

## 실제 게임 확인

기존 게임창 native1280×720에서 실행했다. 확대·축소한 합성 화면을 실제 증거로 대체하지 않았다.
모든 성장 버튼은 누르지 않았고 탭 이동·학생 좌우 이동·기존 읽기 전용 상세 열기만 실행했다.

| 검증 | 결과 | 증거 (`debug/scanner_f5_live/`) |
| --- | --- | --- |
| 미카 성급 탭 | 현재5성, score0.8915/margin0.0510, 기본 복귀 | `mika-star/` |
| 미유 성급 탭 | 현재3성, score0.9380/margin0.0466; 예상4성과 구분, 기본 복귀 | `miyu-star/` |
| 미카 정상 단일 스캔 | 기본5성 유지, 성급 탭 클릭0회 | `mika-natural/` |
| 미카 기본 성급 미확정 주입 | 실제 독립 무기 flag에서5성 inferred, 성급 탭 클릭0회 | `mika-inferred/` |
| 미카 기본+무기 미확정 주입 | 실제 성급 탭5성 복구, 열기1회/복귀1회 | `mika-fallback/` |
| 미유 기본 성급 미확정 주입 | 무기 잠금을5성으로 오인하지 않고 실제 탭3성 복구 | `miyu-fallback/` |
| 미유 성급 탭 진입 후 취소 | 추가 캡처 중단, 동일 학생 기본 복귀 | `miyu-cancel/` |

`verify_student_star_live.py --diagnostic`는 해당 실행의 관측 결과만 미확정으로 치환한다.
위 주입 사례는 자연 발생 기본 판독 오류가 아니다. 게임 픽셀이나 사용자 데이터를 변경하지 않는다.
취소 probe의 저장 이미지 판독은 증거용이며 runtime은 취소 후 판독을 하지 않는 별도 검사로 검증했다.
최종 게임은 미카 기본 화면으로 복귀시켰다 (`02-mika-return.png/json`).

## 회귀·재현

- F5 전용22/22 통과,6.040초 (`f5-focused-tests.txt`). 1~5성 고정 템플릿을1280/2560 크기로
  구성한 검사, blank/동률/누락, 독립 장착/미장착 추론, 순환 금지, 충돌 및 종속 gate 순서,
  실패/취소/다른 학생 복귀, native1280 현재 성급/복귀 SHA 검사를 포함한다.
- 기존 전용무기 S2W9/9 통과,12.671초 (`f5-weapon-regression.txt`).
- `student_star_f5_live/manifest.json`의 PNG4개는 육안으로 확인한 개발 회귀 자료다.
  holdout 정확도나 runtime 자동 학습 자료가 아니다. 별1~5 합성 검사는 실게임 전체 성급 검증과 구분한다.
- 재현 도구: `sync_student_star_f5_assets.py`, `export_student_star_f5_fixtures.py`,
  `verify_student_panel_live.py star`, `verify_student_star_live.py`.
- 전체 Python405/405 통과,149.304초 (`f5-python-tests.txt`).
- Flutter analyze 이슈0,37.7초 (`f5-flutter-analyze.txt`), `flutter test --concurrency=1` 전체399/399
  통과,2분53초 (`f5-flutter-tests.txt`). F4의 병렬 초기 응답 timeout 이력을 고려해 처음부터 순차
  실행했으며 이번 실행에는 실패가 없었다. Python 전체 테스트와도 겹치지 않게 실행했다.
- 인식 자산1939개 ready, missing/corrupt0. `f5-source-manifest.json` 소스21개와 native PNG4개 SHA
  일치. Almanac validate/health 및 git diff --check 통과.
- 실제1/2/4성, 실제 해금 후 미장착5성의 신규 게임창 입력, 실제2560 입력, 다중 DPI와 장시간 자원 측정은
  미검증이다. 미장착 추론은 기존 S2W 상태 fixture로 검증했다. 남은 통합 coverage는 F12에서 추적한다.
- F0~F4 historical source manifest는 유지하며 F5 스냅샷을 별도로 작성한다. 릴리스 빌드는 F12 범위다.
