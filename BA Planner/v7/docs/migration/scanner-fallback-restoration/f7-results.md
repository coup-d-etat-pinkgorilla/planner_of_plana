# F7 장비·애용품 복구 완료 기록

## 2026-08-31 후속 구현·검증

R15 잠금 판독 보완과 R14의 `D2-native1280-v1` 제한적 추론을 구현했다.
전용36 tests, 아래 실게임 검증과 최종 Python463/Flutter399/analyze를 통과하여 F7을 완료했다.
F8은 미착수이며 native2560 특수 추론과 자연 저점수 사례는 명시된 F12 검증 범위로 남긴다.
아래의 최초 구현 기록과 초기 source manifest는 과거 증거로 보존한다.

### R15 빈칸 표시 부재

기존 ROI에는 흰 배경뿐 아니라 장비 카드의 둥근 우상단 모서리가 들어 있었다.
상단/우측의 밝은 배경과 좌하단의 중립색 카드가 함께 확인되는 경우에만 dot 부재로 판정한다.
흰색/회색/검은색 단색, 일부 주황점, 가려진 모서리는 unknown을 유지한다.
성장 버튼 inactive와 dot=false가 모두 확인되어야 `love_locked`가 된다.

- 실제 미유 기본 화면을 생산 `StudentMatcherAdapter._scan_current`로 읽어 학생 ID/레벨까지
  자동 식별하고 `equip4=love_locked`, source=`favorite_growth_lock`를 얻었다. 입력 포트 자체가 없다.
- 실제 시즈코 empty와 토키 T2 기본 판독도 확인했다. 검토한 native PNG6개에
  미유1280/2560 잠금, 시즈코 빈칸, 모미지T1, 토키/세리카T2를 고정했다.
  `backend/tests/fixtures/student_equipment_f7_favorite/manifest.json`은 개발 회귀용이며 D2 holdout이 아니다.
- 기존 S3의 상세 fallback 테스트1건이 이제 기본 잠금을 읽어 상세창을 열지 않아 실패했다.
  테스트의 목적에 맞게 성장 상태를 명시적으로 unknown으로 주입했다. 실제 lock 판독은 별도 tests로 검증한다.
  첫 실패 로그는 `debug/scanner_f7_followup/s3-regression.txt`에 보존했다.

### R14 / D2 독립 검증과 적용 범위

보관된 정상 크기 이미지297장에는 장비 상세창이 없었다. 게임에서 장비를 변경하지 않고
8명의 native1280 상세창을 새로 수집했다. 정답은 기본/상세 화면을 직접 확인하여 고정했고,
기존 tier/digit bank에 추가하거나 학습하지 않았다.

| 학생 | 슬롯1 | 슬롯2 | 슬롯3 |
| --- | --- | --- | --- |
| 시즈코 | T8/60 | T8/60 | T5/45 |
| 아스나 | T2/20 | T1/10 | T1/10 |
| 메구 | T6/50 | T6/50 | T6/50 |
| 토키 | T10/70 | T8/60 | T10/70 |
| 토키(바니걸) | T4/40 | T4/40 | T4/40 |
| 토모에(치파오) | T4/37 | T7/54 | T8/59 |
| 미모리 | T9/65 | T10/70 | T9/65 |
| 하스미(수영복) | T3/30 | T3/30 | T3/30 |

미카는 이전 개발 자료로만 사용했다. 미카 tier ROI에 고정 seed와 sigma0~200 잡음을 적용하여
점수 범위를 특성화했다. 일반 gate .60을 유지하면서 .55 이상 .60 미만으로만 후보 범위를 제한했다.
후속 독립 자료에는 미리 정한 sigma100/110/120/130/140와 다른 seed를 적용했다.
이미지 손상은 모두 합성이며 실제 게임 화면이나 장비 값은 변경하지 않았다.

현재 적용 조건은 다음 모두가 참인 경우다.

- native1280×720 일반 장비 슬롯1~3, 레벨 판독 활성, top1=T10.
- tier score `[.55, .60)`, top2와 margin≥.15. 일반 tier threshold .60은 그대로다.
- 티어 추측과 무관하게 두 숫자 ROI가 각각 `7`, `0`이고 각 score≥.80, margin≥.15.
- 누락/동률/`v` 셀 또는 다른 레벨은 허용하지 않는다. 다른 티어나 이미 확정된 값을 덮어쓰지 않는다.

출력은 tier와 level 모두 `inferred`, source=`equipment_level70_t10`, note=`level70_implies_t10`이다.
기존 일반 digit source와 구분하여 기본 레벨 보정 학습에 들어가지 않는다. 기존 partial/conflict 병합을 유지한다.
비교 실행은 `allow_t10_inference=False`로 수행할 수 있다.

- 독립 원본24/24 정답, T1~T10 전체 포함. T10/70 양성3개는 정상 gate로 판독된다.
- 합성 tier 손상120건: 특수 추론 복구5건, 하위 tier 오승격0건.
- 실제70 숫자를 남기고 tier ROI만 단색/잡음/숫자·버튼 등 다른 종류로 바꾼321건: 오승격0건.
- 실제 하위 tier21개에 반사실적70 숫자를 결합해도 원래 tier를 보존하고 호환되지 않는 level은 미확정이다.
- tier/digit bank 동률, 점수 경계, 레벨69/불명, scan_level=false, native2560에서 특수 추론이 차단됨을 확인했다.

**한계:** 자연 발생한 낮은 점수의 T10은 관측하지 않았다. 합성5건 복구는 자연 오류 복구율이 아니다.
8명/24개 슬롯의 작은 검증 집합이며, 현재 특수 규칙은 native1280에만 적용한다.
native2560와 자연 저점수 사례는 F12 coverage 항목이다. 2560 일반 판독은 기존 동작을 유지한다.
v6의 .66/.72를 그대로 복사하지 않았으며 공통 threshold를 낮추지 않았다.

### 수정 후 실게임

- 미카 정상 상세창 T10/70 세 슬롯 모두 기존 일반 source로 판독, 체크 ON 추가 입력0, 동일 학생 기본 복귀.
- 미카 캡처의 tier 픽셀에만 메모리상 잡음을 주입하는 진단에서는 슬롯1(.5891)/3(.5687)을
  특수 source로 복구하고 .5381인 슬롯2는 미확정/partial로 유지했다. 일부 성공이므로 추가 재시도 없음.
  동일 학생 기본으로 돌아왔다. 이는 자연 오류가 아닌 명시적 진단이다.
- 시즈코·아스나·메구·토키·바니토키·치파오토모에·미모리·수영복하스미 상세 조회 모두 기본 화면 복귀.
  성장/최대 투입/선택권 자동 사용/장비 변경/구매 조작 없음. 검색을 지우고 미카 기본 화면으로 복원했다.

재현 명령과 고정 자료:

```powershell
py -3.11 backend/tools/export_student_equipment_f7_d2.py
py -3.11 backend/tools/benchmark_student_equipment_f7_d2.py --output docs/migration/scanner-fallback-restoration/f7-d2-audit.json
cd backend
py -3.11 -m unittest discover -s tests -p 'test_student_equipment_f7*.py' -v
```

독립 원본/SHA: `backend/tests/fixtures/student_equipment_f7_d2/manifest.json`.
입력 trace와 원본/진단 PNG: `debug/scanner_f7_followup/*/trace.json` 및 같은 디렉터리.
전용36/36(15.861s). 최종 전체 Python/Flutter, 자산/SHA/wiki 검사는 다음과 같다.

최종 Python 전체463/463 통과(216.529s). 기존 S3 장비16/16 통과(8.259s).
첫 전체463 실행은 위 S3 fixture 가정1건만 실패(201.408s)했으며
`f7-continuation-python-first-failed.txt`에 보존했다. 수정 뒤 재실행에서는 실패가 없었다.
자산1983 ready/누락0/손상0, 후속 source24 및 native18(초기4+애용품6+D2 8) SHA 일치.
초기 F7 snapshot을 덮어쓰지 않고 `f7-continuation-source-manifest.json`을 별도로 고정했다.
codealmanac validate/health 전체0, git diff --check 오류0(CRLF 변환 경고만 있음).
Flutter analyze 이상0(55.8s), `flutter test --concurrency=1` 399/399 통과(2:34).
Python과 Flutter 전체 검증은 겹치지 않게 실행했다. 최종 로그는
`f7-continuation-python-tests.txt`, `f7-continuation-flutter-analyze.txt`,
`f7-continuation-flutter-tests.txt`에 있다. 프로필/학습 저장·재화 소비·release·commit은 하지 않았다.

## 최초 구현 기록 (후속 결과와 구분)

2026-08-31. F6 자동회귀(Python427, Flutter399, analyze)와 실제1280 검증 통과 후 F7 시작.
R12/R13 및 R15 연결을 구현했다. **F7 전체 완료는 아니며 R14/D2 승격 검증은 남아 있다.**

- R12: 검증된 장비창에서 전체 보기 on/off/unknown을 구분한다. on은 클릭0회,
  off는 추가 프레임에서 재확인한 뒤 여전히 off일 때 한 번만 클릭한다.
  재캡처에서도 on을 확인해야 판독한다. unknown/무반응은 판독하지 않고 F2 복귀 후 partial이다.
- R13: unresolved 슬롯은 하나의 상세 프레임을 공유한다. 대상 **일반 장비 티어가 전부 미확정**일 때만
  추가 판독1회다. 일부 티어 성공, 기본 티어 확정, sticky conflict, 애용품 단독에는 재시도하지 않는다.
  재시도에서도 체크 상태를 확인하며 다시 켜는 클릭은 하지 않는다. 기본 확정값을 보존한다.
  애용품에 존재하지 않는 equip4_level을 요구하지 않으며, 빈칸/잠금의 skipped 레벨은 실패로 세지 않는다.
- R15: 기본 화면의 기존 equipment_button ROI를 고정 possible/impossible 템플릿으로 읽어
  favorite_growth_active에 연결했다. 동일한 ‘장비 성장’ 문구 때문에 색상을 주로 비교한다.
  첫 실제 probe에서는 공통 체크박스 가중치가 버튼을 unknown으로 남겼다(margin.0419).
  버튼 전용 색상 가중치로 분리한 후 active 확인(score.9023/margin.1108), threshold.75/margin.10 유지.
  빈칸 표시가 없다는 판정도 밝은 중립색 배경이 확실할 때만 허용한다.
  버튼 또는 dot ROI가 없거나 불명인 경우 love_locked로 추정하지 않는다.
- v6 흐름과 한도를 parity fixture에 먼저 고정했다. 고정 control 자산4개 추가, 총1983개.
  기존 tier/digit/flag bank와 임계값은 변경하지 않았다. Qt/v6 runtime 의존성 없음.

실게임은 native1280×720 미카에서 확인했다. 현재 ‘일괄 성장 ON’ 체크는 표시 모드이며,
하단 성장 실행, 최대 투입, 선택권 자동 사용, 장비 교체는 조작하지 않았다.

| 사례 | 결과 | 증거 디렉터리 |
| --- | --- | --- |
| ON 상태 | 클릭0, T10/70 세 슬롯 판독, 기본 복귀 | debug/scanner_f7_live/mika-panel |
| OFF→ON | off 두 번 확인, 클릭1, on 확인, 동일 판독·복귀 | debug/scanner_f7_live/mika-off-on |
| 첫 판독 전체 미확정 주입 | 추가 캡처1회로 세 슬롯 복구, 기본 복귀 | debug/scanner_f7_live/mika-retry |
| 열기 후 취소 | 새 캡처 차단, 기본 복귀 | debug/scanner_f7_live/mika-cancel |
| 미유 기본 화면 읽기 | 성장 버튼 inactive 확인, 장비1 empty/2·3 level_locked, 애용품 dot 불명은 미확정 유지 | debug/scanner_f7_live/miyu-basic |

실패 주입은 자연 발생 오류로 주장하지 않는다. native PNG4개/SHA를
`backend/tests/fixtures/student_equipment_f7_live/manifest.json`에 고정했다.
개발 회귀 자료이며 D2 holdout 또는 자동학습 자료가 아니다.
미유 진단은 화면에서 확인한 학생/레벨1을 recognizer 인자로 사용한 입력0회 기본 판독이다.
실제 애용품은 잠금이지만 dot ROI 부재 판단이 아직 불명이라 love_locked로 승격하지 않았다.
이는 R15의 남은 coverage/판독 보완 항목이다. 비활성 성장 버튼은 누르지 않았고 최종 화면은 미카 기본으로 돌려두었다.

D2에 관한 현재 증거와 다음 작업:

- 실제 미카의 T10은 기존 일반 상세 판독에서 .88~.95 점수로 통과했다. 이는 저점수 T10 추론의 근거가 아니다.
- 기존 direct-tier archive의 학습 분할은 하루나(체육복)T1~T10이고 독립 검증은 쿠루미T2뿐이다.
  기존 promotion-probe는 T1/T2의 숫자 레벨1/8/9/12/16/18을 검증하며 D2 검증셋이 아니다.
- 따라서 현재 bank의 T10/70 양성과 T1~9·blank/noise·동률·wrong-family 음성을 독립 분할에서
  측정하는 D2 gate를 충족하지 못했다. v6의 .66~.72 기준을 복사하거나 inferred 출력을 활성화하지 않았다.
- 다음 F7 작업은 독립 D2 데이터 확보·점수 분석·음성 평가 후 제한적 추론 구현/승격 여부 결정이다.
  미유 잠금의 dot absence 판독 보완, 애용품 빈칸/T1/T2와 다른 해상도 입력 coverage도 추가해야 한다.

검증 기록:

- 전용25/25(0.935s), 기존 S3 장비16/16. native fixed4 PNG의 checksum/화면/일반T10 판독 포함.
- 빈칸/잠금 skipped 처리 보완 전 전체Python450/450(192.796s).
  보완 후452 실행에서는 기존 studio text builder의 debug JSON 쓰기에서 OSError errno22가1회 발생했다.
  Flutter 검사와 겹친 실행이었지만 인과관계는 확인하지 못했다. 실패 로그는
  `f7-python-concurrent-io-failed.txt`에 보존했고 해당6 tests의 단독 재실행은 통과(4.864s)했다.
  최종 Python 전체 단독 재실행 **452/452 통과(186.396s)**. 파일 쓰기 오류는 재현되지 않았고 원인은 미확정이다.
- F7 이후 Flutter399/399(순차3:34), analyze 이상0(2.5s).
- 자산1983 ready/누락0/손상0, F7 source18개 및 native4개 SHA 일치,
  codealmanac validate/health 전체0, git diff --check 통과.

F0~F6 snapshots는 변경하지 않는다.
프로필 저장·재화 소비·성장 실행·학습 추가·release/commit 없음.
