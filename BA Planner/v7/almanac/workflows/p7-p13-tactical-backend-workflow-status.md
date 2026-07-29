---
title: "P7-P13 Tactical Challenge Backend Workflow Status"
summary: "P7부터 P13까지의 단계별 상태, 산출물, 검증과 다음 행동을 기록합니다."
topics: [workflow, architecture, migration, data, tactical]
sources:
  - id: workflow
    type: file
    path: almanac/workflows/p7-p13-tactical-backend-workflow.md
---

# P7-P13 Tactical Challenge Backend Workflow Status

이 문서는 P7 활성화 이후 P13까지의 실제 진행 상태를 기록한다. 단계 정의와 완료 조건은
[P7-P13 Tactical Challenge Backend Workflow](p7-p13-tactical-backend-workflow)를 따른다.
[@workflow]

## 상태 원칙

- 선행 단계 fixture와 contract test를 재현한 뒤 다음 단계를 시작한다.
- 구현 보고만으로 완료 처리하지 않고 마스터가 산출물과 검증 결과를 직접 확인한다.
- 각 단계의 `input.md`, `output.md`, `artifacts/` 위치와 검증 명령을 기록한다.
- 코드와 이 문서가 다르면 코드와 실제 검증 결과를 우선하고 즉시 문서를 바로잡는다.

## 현재 현황

2026-07-29 P7~P12를 완료했다. 지정한
`Pictures/Screenshots/스크린샷 2026-07-07 201820.png`를 P8의 2560×1440 전술대항전
상대 선택 기준 fixture를 P9의 identity·snapshot 연결 fixture로 이어서 사용한다.

| 단계 | 상태 | 산출물 또는 근거 | 다음 행동 |
|---|---|---|---|
| P7 | `완료` | v2 DTO/schema, v6 import preview·commit, Python/Dart fixture·E2E, 실제 DB preview와 release 검증 통과 | 계약 회귀 유지 |
| P8 | `완료` | 실제 로비 fixture·ratio ROI·template matcher·review DTO·Python/Dart 검증 | 계약 회귀 유지 |
| P9 | `완료` | scan·candidate·identity·snapshot 저장, 자동/수동 match 연결, Python/Dart E2E | 계약 회귀 유지 |
| P10 | `완료` | 읽기 전용 결정론 통계·strict filter·Wilson 구간·Python/Dart E2E | 계약 회귀 유지 |
| P11 | `완료` | 변경 구간·신선도 감쇠·노출 funnel·Python/Dart E2E | 계약 회귀 유지 |
| P12 | `완료` | 6단계 관측 시나리오·추천 근거·prediction 분리 저장·시간순 backtest | 계약 회귀 유지 |
| P13 | `대기` | P12 완료 필요 | opt-in 공유와 고급 분석 |

## P7 결정과 조사 결과

- P6 `tactical.*` v1 CRUD는 현재 UI 호환을 위해 유지한다.
- P7은 기존 payload shape를 깨지 않고 별도 `tactical.v2.*` method namespace와 payload
  version 2 계약으로 추가한다.
- 실제 v6 SQLite는 읽기 전용으로만 조사·import하며 v6 Python을 runtime import하지 않는다.
- v6 표시 이름은 정확한 표시 이름 우선으로 canonical student ID에 매핑한다. alias/tag
  fallback은 정확히 한 후보일 때만 허용한다.
- v6 덱에서 기록되지 않은 슬롯은 `unknown`이며 실제 빈 슬롯 `empty`로 추정하지 않는다.
- 중복 학생 슬롯, 알 수 없는 학생과 잘못된 날짜는 preview issue가 되며 비검토 commit에서
  제외한다.

## P7 검증 기록

- 2026-07-29 실제 v6 `tactical_challenge.db`를 SQLite read-only URI로 열고
  `PRAGMA integrity_check=ok` 확인.
- 전적 10,475개, 족보 2개, 출처 `내 기록` 696·`타인 전적` 9,180·`스크린샷` 599.
- 학생 표시 219종은 정확한 표시 이름으로 v7 canonical ID에 모두 일대일 대응.
- 중복 학생 슬롯 전적 6건과 공격/방어 방향을 판별할 덱이 없는 전적 6건을 확인했으며
  preview issue로 반환하고 명시적 검토 없는 commit 대상에서 제외할 계약으로 결정.
- 실제 DB preview 결과: 전적 10,475·족보 2·상대 identity 121·방어 snapshot 9,797,
  자동 변환 가능 기록 10,465·검토 issue 12.
- Python 전체 84 tests 통과.
- Flutter 전체 213 tests와 `flutter analyze` 통과.
- 실제 Dart→Python process에서 v6 fixture preview → issue 승인 → atomic commit → v2 state
  복원 E2E 통과.
- `flutter build windows --release`, `codealmanac validate`, `codealmanac health`,
  `git diff --check` 통과.

## P7 완료 판정

2026-07-29 마스터가 P7 산출물과 완료 조건을 직접 확인해 완료 처리했다. 기존 P6
`tactical.*` v1 UI 계약은 그대로 유지되고 P7은 별도 `tactical.v2.*` 경계로 추가됐다.
P8은 아래 기준 화면 결정에 따라 이어서 구현했다.

## P8 시작 결정

- 기준 화면은 2560×1440, 16:9 전술대항전 상대 선택 화면이다.
- 완전히 보이는 세 행은 5·6·7위이며 현재 순위는 8위다.
- 이름은 `마리나9데스티니`, `우그웃`, `메라조마`를 등록 template fixture로 사용한다.
- 공개 슬롯 기준값은 순서대로 `tsubaki/hibiki/michiru_dress`,
  `eimi/michiru_dress/yakumo`, `tsubaki/michiru_dress/hibiki`다.
- 원본 screenshot은 개인정보가 포함된 로컬 fixture이므로 P13 공유 payload에는 포함하지
  않으며 P8 test/recognition artifact 경계에서만 사용한다.

## P8 구현 결과

- 2560×1440 기준 ROI를 ratio 좌표로 고정하고 2560×1440, 1920×1080, 1280×720에서
  같은 현재 순위·세 상대·공개 슬롯과 같은 `refresh_generation`을 복원한다.
- rank, 등록 상대 이름, 공개 학생 초상 template을 runtime UI asset과 분리된 recognition
  catalog에 SHA-256과 함께 등록했다. 같은 identity의 여러 초상 template은 identity별 최고
  점수로 먼저 합친 뒤 runner-up margin을 계산한다.
- 한 번의 안정 프레임은 로비 전체 후보 하나가 된다. 확정값과 제안값, field evidence,
  score, margin, screen hash, frame completeness, overall confidence를 함께 보존한다.
- 가림·미등록·유사 이름과 낮은 margin은 값을 자동 확정하지 않고 `review_required`로 둔다.
  로비에서 숨겨진 striker 2~4번은 `empty`가 아니라 `unknown`이다.
- P5 session start/cancel/event/snapshot/review에 `tactical_lobby`를 추가했다. P8 완료
  시점에는 저장을 보류했으며 P9에서 tactical v2 저장 경계를 연결했다.
- Dart에는 snake-case wire 변환과 typed tactical lobby candidate/service 경계를 추가했다.

## P8 검증 기록

- Python 전체 90 tests 통과. 실제 screenshot 정답, 세 지원 해상도, 동일 갱신 ID,
  부분 가림, 유사 이름 저마진, 취소, session review와 P9 저장 차단을 포함한다.
- Flutter 전체 215 tests와 `flutter analyze` 통과.
- Windows release build, `codealmanac validate`, `codealmanac health`, `git diff --check` 통과.
- 상세 산출물과 검증 결과는 `docs/migration/p8-tactical-lobby-scanner/output.md`에 기록했다.

## P8 완료 판정

2026-07-29 기준 screenshot으로 요구한 P8 로비 스캐너 수직 슬라이스와 review 경계를
구현했다. P9에서 이 review 후보를 상대 identity와 방어 snapshot 영속 레코드로 연결한다.

## P9 구현 결과

- 확정된 P8 후보 하나를 `lobby_scan` 1개, 행별 `lobby_candidate` 3개, 공개
  `defense_snapshot` 3개로 atomic 저장한다.
- 동일 profile의 같은 `refresh_generation`은 새 노출 표본으로 중복 생성하지 않는다.
- 표시 이름 exact alias 또는 명시적 identity binding으로 상대를 연결한다. 이름 변경과
  `name_template_id` 추가는 기존 identity의 alias/template 이력에 누적한다.
- candidate 선택 시각을 기록하며 같은 상대, 6시간 이내, season 호환, 공개 3슬롯 일치가
  유일할 때만 match를 자동 연결한다.
- 자동 후보가 둘 이상이면 `ambiguous`와 `review_required`로 남기며, 수동 연결·재연결·해제를
  지원한다. 한 match에 연결된 candidate는 최대 하나다.
- 전투하지 않은 candidate와 공개 snapshot도 유지한다. lobby 삭제는 해당 scan의
  candidate와 공개 snapshot만 제거하고 match 원본은 변경하지 않는다.
- 기존 P7 저장 파일은 읽을 때 P9 collection과 name-template 목록을 빈 값으로 보완한다.
- scanner candidate commit은 runtime에서 P9 tactical 저장 경계로 위임하며, 별도
  `tactical.v2.lobby.commit`은 season·map·identity binding을 함께 받을 수 있다.

## P9 검증 기록

- Python 전체 95 tests 통과: 재시작 복원, 중복 refresh, alias, 공개/완전 snapshot 연결,
  자동·모호·수동 재연결·해제·삭제, atomic failure와 idempotency conflict 포함.
- Flutter 전체 216 tests와 `flutter analyze` 통과.
- 실제 Dart→Python process에서 v6 match import → P8형 lobby commit → 상대 선택 → 자동
  match 연결 → history 복원 E2E 통과.
- Windows release build, `codealmanac validate`, `codealmanac health`, `git diff --check` 통과.

## P9 완료 판정

2026-07-29 P9 저장·연결 계약과 완료 fixture를 직접 검증해 완료 처리했다. 다음 단계는
원본을 변경하지 않는 P10 결정론적 통계 MVP다.

## P10 구현 결과

- `tactical.v2.stats.query` 읽기 전용 조회와 strict filter DTO를 Python·Dart에 추가했다.
- 공개 signature별 노출·선택·상대 수, 연결 전적, 공격덱 결과와 완전 방어덱 분포를 집계한다.
- 상대별 최근 공개/완전 snapshot과 공격/방어 관측 결과를 서로 다른 필드로 반환한다.
- 공격 match만 사용해 완전 동일, striker/special 동일, 한 슬롯 변형, 3·4인 core 패턴을
  결정론적으로 정렬한다.
- 승률 이름은 `observed_win_rate`로 고정하고 Wilson 95% 구간과 모집단 경고를 함께 제공한다.
- prediction은 관측 결과에서 제외하며 날짜 없는 기록은 기간 추세와 최근 완전 snapshot에서
  제외한다. source·season·상대·signature·기간 필터는 분자와 분모에 함께 적용한다.
- 날짜 보유율, 방향별 match 수, 출처 구성, 상대 수와 중복 의심 수를 표본 품질로 반환한다.
- 조회 전후 저장 파일 SHA-256이 같음을 검사해 조회가 원본 상태를 쓰지 않음을 확인했다.

## P10 검증 기록

- Python 전체 101 tests 통과.
- Flutter 전체 216 tests와 `flutter analyze` 통과.
- 실제 Dart→Python P7 import→P9 연결→P10 filter query E2E 통과.
- `flutter build windows --release`, `codealmanac validate`, `codealmanac health`,
  `git diff --check` 통과.
- 상세 의미 규칙은
  `docs/migration/p10-deterministic-tactical-statistics/artifacts/statistics-semantics.md`, 결과는
  `docs/migration/p10-deterministic-tactical-statistics/output.md`에 기록했다.

## P10 완료 판정

2026-07-29 P10의 결정론적 통계 계약, 독립 fixture, Python 계약/불변성 테스트와 Dart 실제
process E2E를 확인해 완료 처리했다. P11은 이 고정된 집계 모집단 위에서 시간순 변경·신선도·
노출 분석을 추가하며 P10 원시 통계 의미를 변경하지 않는다.

## P11 구현 결과

- `tactical.v2.trends.query`를 P10과 분리된 읽기 전용 조회로 추가했다.
- 공개 signature 변경을 마지막 이전 관측~최초 새 관측 구간으로 반환하며 연속 유지 run과
  비연속 재사용을 감지한다.
- 같은 공개 signature가 유지된 구간에서 전투 후 확인된 완전 방어덱 변경을 별도 기록한다.
- 확정 refresh generation을 표본으로 새로고침당 노출, 상대 잔류, 상대·공개 signature·
  `상대 순위-현재 순위`별 노출/선택/전투/결과를 집계한다.
- 노출→선택→전투→결과 funnel과 관측 승률을 별도 count/rate로 반환한다. 전투하지 않은
  후보는 승률 분모에 들어가지 않는다.
- 필수 `as_of`와 반감기형 `stale_after_hours`로 마지막 전투·성공·실패, 최신 공개 관측과
  변경 이후 검증 여부, 신선도 가중치와 구식 경고를 결정론적으로 계산한다.
- prediction과 방어 match는 공격 근거에서 제외하고 날짜 없는 자료는 변경·수명·신선도에서
  제외한다. 조회 전후 저장 파일 hash가 같음을 확인했다.

## P11 검증 기록

- Python 전체 106 tests 통과.
- Flutter 전체 216 tests와 `flutter analyze` 통과.
- 실제 Dart→Python P7 import→P9 연결→P10 통계→P11 trend query E2E 통과.
- `flutter build windows --release`, `codealmanac validate`, `codealmanac health`,
  `git diff --check` 통과.
- 의미 규칙은 `docs/migration/p11-tactical-change-exposure/artifacts/trend-semantics.md`, 결과는
  `docs/migration/p11-tactical-change-exposure/output.md`에 기록했다.

## P11 완료 판정

2026-07-29 네 refresh의 공개 덱 A→A→B→A, 두 전투와 공개 유지 중 완전 방어 변경 fixture로
P11 완료 조건을 검증했다. P12는 관측 snapshot을 우선하는 예상 완전 방어덱과 설명 가능한
추천을 추가하며 P11의 관측/예측 경계를 변경하지 않는다.

## P12 구현 결과

- `tactical.v2.recommend.query`에 같은 상대+공개 signature+시즌부터 전체 상대의 같은 공개
  signature까지 6단계 근거 탐색을 추가했다.
- 좁은 단계의 표본이 부족할 때 뒤 단계의 새로운 실제 snapshot만 거리별 0.5 할인으로
  보정한다. fallback stage·eligible·contributed snapshot 수를 모두 반환한다.
- 날짜가 있고 confirmed인 실제 완전 방어 snapshot만 TOP-K로 반환하며 슬롯별 독립 조합으로
  관측되지 않은 덱을 생성하지 않는다.
- 시나리오별 근거 가중 점유율, 대상 상대 근거 점유율, 마지막 확인, 상대·match·snapshot 수,
  숨은 슬롯 후보와 공개 signature 모호성을 제공한다.
- 공격덱 추천 점수는 Wilson 관측 결과, 최근성, 표본, 상대/완전 방어 범위와 출처 품질을
  개별 구성 요소와 함께 반환한다. 요청의 보유 학생 ID로 부족 학생을 별도 표시한다.
- 시간순 holdout으로 TOP-1/TOP-K/숨은 슬롯, Brier와 log loss를 계산하고 동일 snapshot의
  train/test 중복을 금지했다. 기준 fixture는 calibration gate를 통과하지 않으므로
  `evidence_weight_share_not_probability`와 low/medium/high 등급을 기본 표현으로 고정했다.
- `recommend.save/get`과 독립 `predictions` collection을 추가했다. 저장 record는 근거 state
  revision·filter·결과를 가지며 관측 snapshot·match·lobby history를 변경하지 않는다.

## P12 검증 기록

- Python 전체 112 tests 통과.
- Flutter 전체 216 tests와 `flutter analyze` 통과.
- 실제 Dart→Python P7 import→P9 link→P10/P11 조회→P12 query·save·idempotent retry·get·
  state restore E2E 통과.
- `flutter build windows --release`, `codealmanac validate`, `codealmanac health`,
  `git diff --check` 통과.
- 의미 규칙과 backtest는 `docs/migration/p12-tactical-defense-recommendation/artifacts/`, 결과는
  `docs/migration/p12-tactical-defense-recommendation/output.md`에 기록했다.

## P12 완료 판정

2026-07-29 관측 덱 전용 시나리오, 명시적 fallback, 근거 분해 추천, prediction 분리 저장과
시간 누수 없는 baseline backtest를 확인해 P12를 완료 처리했다. P13은 opt-in 공유와 익명화,
독립 사용자 재현성 단계이며 별도 승인 전에는 로컬 이름·ROI·prediction을 외부로 보내지 않는다.
