# F8 학생 식별·진입 복구·다중 폼 완료 기록

2026-08-31. 사용자의 F8 시작 지시에 따라 R16~R18을 구현했다.
2026-09-01 전용 단위·실제1280 검증과 전체 Python486/Flutter399/analyze 회귀를 통과하여 완료했다.
F9~F12는 착수하지 않았다. F0~F7 기록과 source manifest는 과거 증거로 보존한다.

## 계약과 구현

- R16: 필드를 자르거나 장비 family context를 만들기 전에 학생을 확정한다. 저신뢰 식별은
  .6초 간격의 새 기본 프레임으로 최대2회 재시도하고, 실패하면 `identity_unconfirmed`로 중단한다.
  첫 학생만 한 차례 로비→목록→기본, 목록→기본 또는 확인된 레벨/성급 탭→기본 복구가 가능하다.
  단계마다 클릭1회와 확인 캡처 최대3회다. 전환 중 capture timeout은 예산을 소비하며 재클릭하지 않는다.
  알 수 없는 화면이나 뒤 학생 실패에 첫 학생 진입을 시도하지 않는다.
- R17: 기존 전체 초상화 검색을 유지한다. v6의 후보 축소/확대보다 이미 넓은 범위를 검색하므로
  속성 후보가 경쟁 학생을 제거하거나 속성만으로 ID를 확정하도록 연결하지 않는다.
  5개 속성의 고정 template19개, score=.7×NCC+.3×색상 유사도≥.90/margin≥.10을 사용한다.
  속성3개 이상, 최대32명의 후보 cohort를 기록한다. 현재 실제 미카는2개만 확정되어 후보군을 만들지 않는다.
  원래 초상화 gate .82/.04를 유지하며 같은 학생의 여러 폼은 base ID별 최고 점수로 묶는다.
  다른 학생과의 간격이 충분하고 해당 학생의 속성 일치 폼이 정확히1개일 때만 폼을 보완한다.
- R18: v6의 속성 동률/캡처 실패 시 기본1번 선택은 이식하지 않았다. 속성이 같은 수영복 슌 등은
  폼 초상화까지 미확정이면 unknown이다. 각 폼의 candidate key는 기존 canonical form ref이며
  `hoshino_battle`과 `hoshino_battle#2`를 사용한다. 전체 순회 중복 확인은 base ID로 한다.
  다른 폼에서는 네 전투 능력치를 새 프레임에서 읽고 공유 성장 값만 복사한다.
  원래 폼의 전투 값이나 학습 crop을 다른 폼으로 복사하지 않는다. 읽기 실패/취소에도 별도 cleanup
  토큰으로 원래 학생·폼을 확인해 복귀한다. 다른 학생/불명 화면에는 추측한 복귀 클릭을 하지 않는다.
  복귀 확인 실패는 안전 중단하며 이미 완료한 후보를 세션에 남긴다. 안전 복귀한 읽기 실패는 partial이다.

이식 전 대조 계약: `backend/tests/fixtures/student_identity_f8_v6_parity.json`.
구현: `student_identity_recovery.py`, `student_form_recovery.py`, `scanner_matchers.py`, `scanner_runtime.py`.
고정 인식 자산은 속성19+진입 표식2+영역1=22개이며 전체2005개다. v6 런타임 import는 없다.

## 실제 게임 검증

모든 자료는 native1280×720 클라이언트에서 얻었다. 게임 조회/폼 선택만 사용했고 성장, 구매,
최대 투입, 선택권 자동 사용, 장비 변경, 프로필 저장이나 학습 승인을 하지 않았다.

| 시나리오 | 결과 | 입력 |
| --- | --- | --- |
| 미카 첫 식별만 진단상 미확정 | 새 프레임에서 미카 확정 | 0 |
| 학생 목록 진입 | 목록→미카 기본 확인 | 1 |
| 로비 진입 | 로비→목록→미카 기본 확인 | 2 |
| 호시노 무장 1번→2번 읽기→1번 | 두 폼 값 분리, 원폼 복귀 | 2 |
| 다른 폼 읽기 직후 진단 취소 | cancelled, 완료 후보 보존, 원폼1 복귀 | 2 |
| 원폼2에서 초상화 margin을 진단상0으로 설정 | 속성 보완, 1번 읽기, 원폼2 복귀 | 2 |

호시노의 원본에서도 두 폼 초상화 간격이 .04에 못 미쳐 `student_texture_attribute_form`이 사용됐다.
이는 진단 주입 없이 확인한 속성 폼 보완이다. 다른 학생과의 base 간격은 .149~.159 수준이다.
화면의 탱커/딜러 표시, 선택된 스타일 체크, 능력치와 반환 canonical ref를 대조했다.

| 폼 | 최대체력 | 공격력 | 방어력 | 치유력 |
| --- | ---: | ---: | ---: | ---: |
| 호시노 무장1 | 106747 | 3383 | 2771 | 4538 |
| 호시노 무장2 | 48823 | 8633 | 1949 | 5674 |

원본 및 입력 trace: `debug/scanner_f8_live/{mika-retry,list-entry,lobby-entry-bounded,hoshino-forms,hoshino-cancel,hoshino-original2-tie}`.
검증 종료 후 호시노를 최초1번 폼으로 복원하고 검색어를 지운 뒤 미카 기본 화면으로 돌아왔다.
크레딧407,256,746/청휘석23,536은 유지됐다. AP 증가는 시간 경과에 따른 것이며 소비 조작은 없었다.

## 발견한 문제와 제한

- 로비 표식은 native1280에서 v6 ROI보다3px 위에 있었다. 기존 .90 gate를 낮추지 않고
  native1280 전용 고정 ROI로 보정했다. 보정 전 프레임과 이후 별도 캡처를 개발 fixture로 고정했다.
  다른 해상도는 기존 ROI를 유지하며 이 보정이 검증됐다고 주장하지 않는다.
- 로비 UI가 숨겨진 화면은 unknown/입력0으로 중단했다. UI를 표시한 직후 첫 클릭이 전환되지 않은
  실행도 `entry_unconfirmed`로 안전 중단했다. 다음 실행의 로딩 중 `capture_timeout`을 보고
  한 번의 예산 내에서 재촬영하도록 보완한 뒤 전체 진입에 성공했다. 실패 trace도 삭제하지 않았다.
- 기존 생산 adapter tests의 object.__new__ seam에는 새 optional form controller가 없어5건 실패했다.
  optional 접근을 수정한 뒤11/11 통과했다. 첫 실패 로그 `debug/f8-production-tests.txt`를 보존했다.
- 최초 식별 실패/취소/강제 동률은 명시적 진단이다. 자연 오류 복구율로 계산하지 않는다.
  native7개는 개발 회귀이며 별도 성능 holdout이나 학습 자료가 아니다.
- 실제2560, 다중 DPI, 수영복 슌의 능동 폼 전환, 장시간 전체 순회는 F12 추가 coverage다.
  알 수 없는 좌우 끝은 완료로 오인하지 않으며 기존 F1 순환/무이동/입력 실패 계약을 유지한다.

## 자동 검증

- 식별13/13(27.207s): 새 캡처, context 차단, 첫 진입 한정, 동률/다른 학생 경쟁,
  native 상태/폼/능력치, 단색/숨김 UI 거부, 전환 timeout 재촬영 상한.
- 폼10/10(8.037s): 양방향 복귀, 무응답 클릭, 다른 학생 등장, 읽기 실패, 취소 cleanup,
  독립 전투 값, specimen 분리, 중복 폼 순회 방지, 완료 후보 보존, base 중복 제거.
- 기존 생산 adapter11/11(31.409s), 전체 Python486/486 통과(246.584s).
- Flutter analyze 이상0(2.3s), `flutter test --concurrency=1` 399/399 통과(3:30).
  Python 전체 검증 종료 후 Flutter를 실행했으며 전체 검증의 실패는 없었다.
- 실제 폼 후보6개는 생산 세션 DTO 검증에도 통과했다. 프로필에 저장하지 않았다.
- 자산2005 ready/누락0/손상0, source22/native7 SHA 일치, 이전 F7 snapshot SHA 유지.
  고정 호시노 원본의 폼 간격은1번 .01465/2번 .00448로 단독 gate 미달이고,
  속성 보완 후 두 canonical form ref가 정확하다. 밝기40/60/80% 합성 음성9건은 unknown이다.
  이는 자연 오류나 해상도별 holdout이 아니다. 감사 결과는 `f8-audit.json`, source는 `f8-source-manifest.json`.
- `codealmanac validate/health` 전체0, `git diff --check` 오류0(CRLF 변환 경고만 있음).
  최종 로그는 `f8-python-tests.txt`, `f8-flutter-analyze.txt`, `f8-flutter-tests.txt`.
  전용 로그는 `debug/f8-identity-final.txt`, `debug/f8-forms-final.txt`, `debug/f8-production-tests-final.txt`.
  다음 단계는 F9 재고 상세창·수량 폴백이며 미착수다. release build와 commit은 하지 않았다.

```powershell
py -3.11 backend/tools/sync_student_identity_f8_assets.py
py -3.11 backend/tools/export_student_identity_f8_fixtures.py
cd backend
py -3.11 -m unittest discover -s tests -v
cd ../frontend
flutter analyze
flutter test --concurrency=1
```

현재 게임 핸들은 세션마다 달라진다. live probe는 `--target`에 도구에서 확인한 핸들을 사용하고,
`--forms`, `--first-identity-missing`, `--form-template-tie`, `--cancel-after-form-read`를 지원한다.
고정 PNG/SHA는 `backend/tests/fixtures/student_identity_f8_live/manifest.json`에 있다.
