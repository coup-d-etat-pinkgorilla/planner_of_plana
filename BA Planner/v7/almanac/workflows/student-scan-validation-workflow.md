---
title: "Student Scan Validation Workflow"
summary: "v6 학생 스캔을 v7 session/candidate 경계에 이전하고 스탯 계산으로 결과를 교차 검증하는 순차 워크플로입니다."
topics: [workflow, scanning, validation, migration, data]
sources:
  - id: migration-baseline
    type: file
    path: docs/migration/v6-knowledge-baseline.md
  - id: p0-p6-status
    type: file
    path: almanac/workflows/p0-p6-workflow-status.md
  - id: scanner-session
    type: file
    path: backend/core/scanner_session.py
  - id: scanner-matcher
    type: file
    path: backend/core/scanner_matchers.py
  - id: scanner-contract
    type: file
    path: contracts/scanner-protocol-v1.schema.json
---

# Student Scan Validation Workflow

이 문서는 v6 학생 스캔의 실제 인식 기능을 v7 Python scanner session과 Flutter 검토
화면에 연결하고, SchaleDB 방식의 학생 스탯 계산을 독립 검증 증거로 사용하는 후속
워크플로를 고정한다. 기존 P5/P6의 session, candidate, review, commit 경계를 교체하지
않고 그 안의 학생 수직 슬라이스를 완성한다. [@migration-baseline] [@scanner-session]

## 승인된 결정

- 학생 스탯 계산은 도입한다. 주 용도는 상세 스탯 표시와 학생 스캔 교차 검증이다.
- 학생 스캔에는 인연 랭크가 필수 입력이다. v6에는 해당 인식이 없으므로 신규 구현한다.
- 장비 스캔은 v6 동작을 참고하되 생성형 레벨 템플릿의 고비용 경로를 그대로 이전하지 않는다.
- 스캔한 현재 상태, 정적 Schale 원천값, 계산 결과와 사용자 목표는 서로 다른 버킷이다.
- 계산 불일치는 자동 수정 근거가 아니라 사용자 검토를 요구하는 독립 evidence다.
- `../v6`는 동작과 fixture의 참조일 뿐 v7 런타임 dependency가 아니다.

## 현재 기준선

v7의 `StudentMatcherAdapter`는 현재 안정 프레임에서 학생 이미지 템플릿만 매칭하고
`values: {}` 후보를 반환한다. 반면 repository DTO와 recognition region에는 레벨,
성급, 무기, 장비, HP, ATK, DEF, HEAL 필드의 자리가 이미 있다. Flutter는 candidate를
학생 탭으로 넘기고 승인·보류·commit할 수 있지만 현재 검토 표면은 raw map과 evidence
문자열을 나열하는 수준이다. 현재 구현 및 단계 상태는 matcher와 P0-P6 상태 문서를
기준으로 한다. [@scanner-matcher] [@p0-p6-status]

v6는 학생 기본 화면과 추가 패널을 이동하며 다음 값을 읽는다.

- 학생 ID와 다중 폼
- 레벨, 학생 성급, EX/일반/패시브/서브 스킬
- 전용무기 보유·성급·레벨
- 장비 1~3의 티어·레벨과 애용품
- HP, ATK, DEF, HEAL 및 능력 개방 HP/ATK/HEAL

v6에는 인연 랭크 판독 함수, ROI 또는 템플릿이 없다. 따라서 인연 랭크는 실제 게임
화면 fixture를 먼저 확보하고 위치·글꼴·최대 자릿수·폼 전환 영향을 특성화해야 한다.

## 장비 스캔 성능 위험

v6의 기본 화면 fast path 자체는 유지할 가치가 있다. 빈 슬롯을 점으로 판정하고,
학생 메타데이터로 장비 계열을 제한하며, 기본 화면에서 확정되지 않은 슬롯만 장비
메뉴를 연다. 한 장의 메뉴 캡처를 세 슬롯이 공유하는 것도 보존한다.

그대로 이전하면 안 되는 부분은 생성형 장비 레벨 템플릿이다. 현재 v6 구현은 cache miss
때 가능한 각 레벨마다 `2560 x 1440 RGB` 참조 이미지를 새로 만들고 장비 카드·텍스트를
합성한 뒤 ROI를 추출한다. 참조 이미지 하나가 약 10.5 MiB이고 T10은 최대 70개 후보를
생성하므로, 한 `(slot, equipment family, tier, geometry)` miss에서 약 738 MiB의 일시적
픽셀 할당이 발생할 수 있다. 학생·슬롯·장비 계열이 바뀌면 제한된 LRU가 쉽게 교체된다.

이전 v6 조사에서 보고된 T10 cold 판독은 약 0.9~1.05초, 동일 조합 warm 판독은 약
52ms였다. 이 수치는 과거 측정 기준선이며 v7 acceptance 값이 아니다. S3는 accepted
snapshot과 동일한 fixture에서 profiler와 benchmark로 먼저 재현해야 한다. 코드 대조 결과
cold 경로는 후보 레벨마다 배경·아이콘·폰트·카드·전체 화면·warp를 다시 만들고, warm
경로도 저장된 RGB 후보마다 grayscale/percentile 정규화와 edge plane을 다시 계산한다.
따라서 RGB crop만 사전 생성하면 cold 비용 일부만 줄고 warm 비교 비용은 남는다.

현재 메타데이터의 유효 family-slot은 9개이고 한 family에서 T1~T10의 유효 레벨 합은
445개다. 모든 완성 카드를 무조건 runtime asset으로 만드는 방식은 4,005개 카드와 8,010개
숫자 셀을 만들 수 있다. 수천 개의 작은 PNG는 open/decode 비용을 새 병목으로 만들 수
있으므로 PNG, NPZ, atlas 또는 family/slot/tier 단위 묶음 중 저장 형식을 미리 확정하지
않는다. prepared feature를 포함한 시작 시간·RAM·설치 증가량을 비교한 뒤 선택한다.

v7 장비 matcher는 다음 순서로 구현한다.

1. 잠금 레벨과 빈 슬롯을 계산·색상 신호로 먼저 제거한다.
2. 학생 정적 메타데이터로 슬롯별 장비 계열을 하나로 제한한다.
3. 아이콘 ROI로 T1~T10을 판정한다.
4. 티어 최대 레벨로 숫자 후보 범위를 제한한다.
5. navy/dark-ink mask, 정규화 binary glyph, 작은 위치 이동, 최고 score와 2위 margin을
   함께 쓰는 장비 전용 두 셀 matcher를 우선 실험한다. 인벤토리 수량 OCR 전체를 복사하지
   않고 필요한 전처리 개념만 분리한다.
6. 기본 화면에서 확정되지 않은 슬롯만 한 번의 장비 메뉴 캡처로 fallback한다.
7. 합성 fallback이 필요해도 작은 card/ROI 좌표계에서 만들고 전체 2560x1440 canvas를
   후보마다 생성하지 않는다.

구현은 v6 생성형 matcher의 offline 기준 결과, 사전 준비 RGB/gray/edge feature bundle,
실캡처 정규화 glyph, 실캡처 우선+소형 합성 fallback을 같은 답지로 비교한다. 이 비교는
`../v6` runtime import를 허용하지 않는다. 실제 캡처 coverage와 confusion matrix가 충분해질
때까지 fallback을 제거하지 않는다. 특히 5/6 등 실제 혼동쌍 보정과 threshold/ROI는 답지
없이 추측하지 않는다.

실험 원본은 runtime UI asset이나 배포 recognition template와 분리한 source dataset으로
보존한다. `{resolution}/slot{n}/{family}/T{tier}/level_{level}/` 아래에 원본 전체 화면과
metadata를 두고, metadata에는 slot/family/tier/level, client 해상도, UI scale·에뮬레이터,
캡처 시각, ROI 버전, 안정 프레임 여부, 반복 sample 번호를 기록한다. 같은 조건을 가능하면
2~3회 캡처하고 ROI crop과 prepared feature는 원본과 versioned region에서 재생성한다.

성능 acceptance gate는 첫 학생 warm-up과 이후 steady-state를 분리해 다음을 기록한다.

- 정확 판독률, 오판독률, fallback률과 슬롯·티어·숫자별 confusion matrix
- cold 시작/첫 판독 시간, 학생당 warm p50/p95, template load와 feature prepare 시간
- cache miss, 생성·로드 횟수, peak/transient RAM, 설치 파일 증가량
- cold/warm 결과 동일성, T1~T10 경계, 한 자리+blank, 잘못된 tier-level 거부
- feature 누락 시 fallback 보존과 후보별 full-size canvas 생성 금지

## 인연 스탯과 검증 dependency

학생 한 의상의 인연 보너스는 `FavorStatType` 두 항목과 `FavorStatValue` 일곱 구간을
사용한다. 랭크 2~5, 6~10, 11~15, 16~20, 21~30, 31~40, 41~50에서 각 랭크 증가량을
누적하며 51~100은 추가 스탯이 없다. `FavorAlts`의 다른 의상은 각 의상의 현재 인연
랭크와 자체 증가표로 계산해 모두 합산한다.

따라서 스탯 검증은 다음 dependency 상태를 명시해야 한다.

- 현재 의상 인연 랭크를 읽지 못함: 계산 검증 불가
- 다른 의상을 보유하지만 아직 해당 인연 랭크를 모름: 정확 비교 금지, dependency missing
- 다른 의상을 보유하지 않음: 인연 1, 보너스 0으로 계산
- 모든 관련 의상 랭크가 있음: exact relationship contribution 계산

스캔 순서 때문에 아직 만나지 않은 다른 의상 값이 없을 수 있다. 첫 pass에서 이를 오류로
판정하지 않고 repository 기존값을 사용하거나 `pending_dependency`로 남긴다. 전체 scan이
끝난 뒤 관련 후보를 다시 검증하는 second pass가 필요하다.

## 계산 검증 정책

검증 대상은 기본 화면의 HP, ATK, DEF, HEAL 네 값이다. 계산 입력은 학생 ID/폼, 레벨,
성급, 장비 티어와 레벨, 전용무기, 인연, 애용품, 능력 개방이다. 패시브가 게임 기본 화면
표시에 포함되는지는 실제 screenshot parity fixture로 고정하기 전까지 추측하지 않는다.

판정은 다음 네 상태를 사용한다.

| 상태 | 의미 | commit 정책 |
|---|---|---|
| `verified` | 필수 dependency가 있고 네 값이 정확히 일치 | 일반 confidence 규칙 적용 |
| `partial` | 일부 값만 일치하거나 비교 가능한 스탯이 제한됨 | 자동 승인 금지 |
| `dependency_missing` | 다른 의상 인연 등 입력이 부족함 | 오류로 세지 않고 재검증 대기 |
| `suspicious` | 입력이 완전한데 계산과 OCR이 불일치 | 명시적 사용자 검토 필수 |

계산기는 관측값을 수정하지 않는다. 대신 expected, observed, delta, 사용한 dependency,
근접 입력 탐색 결과를 구조화된 evidence detail로 반환한다. 레벨 ±1, 장비 레벨/티어의
인접값처럼 제한된 후보가 네 스탯을 동시에 설명할 때만 수정 제안을 표시한다.
이 evidence 확장은 기존 protocol v1의 candidate/review/commit 형태를 유지하는 additive
변경으로 설계한다. [@scanner-contract]

## 프로토콜 원칙

- candidate payload는 계속 repository에 저장 가능한 `ConfirmedStudent` 형식이다.
- 계산 결과는 `values`에 넣지 않고 evidence에 둔다.
- scanner protocol v1을 확장한다면 `fieldEvidence.details` 같은 optional 구조로 추가하고
  Python schema, fixture, backend validator, Dart decoder와 mock을 같은 slice에서 갱신한다.
- `review_required`는 OCR 불확실성뿐 아니라 `suspicious` 계산 결과에도 true가 된다.
- `dependency_missing`만으로 기존 확정값을 지우거나 candidate를 실패시키지 않는다.
- review에서 사용자가 수정한 candidate payload는 revision을 올리고 계산을 다시 수행한
  뒤 승인할 수 있어야 한다.

## 순차 구현 단계

### S1 — 정적 스탯 데이터와 순수 계산 코어

- SchaleDB 원본을 v7 전용 versioned DTO로 정규화한다.
- 학생/장비/전용무기/인연/애용품/능력 개방 계산을 UI·scanner 없이 구현한다.
- 장비 중간 레벨 보간과 Schale 반올림 순서를 parity fixture로 고정한다.
- 다른 의상 인연 dependency를 입력으로 명시한다.
- 생성 데이터는 `student_meta_data.py`를 광범위하게 손수 수정하지 않는다.

### S2 — v6 학생 인식의 headless v7 수직 슬라이스

- 캡처·입력 orchestration과 matcher를 작은 모듈로 분리한다.
- ID, 폼, 레벨, 성급, 스킬, 무기, 전투 스탯을 candidate values/evidence로 반환한다.
- 한 기본 캡처의 named ROI를 소비자들이 공유하고 full screenshot 보존 시간을 제한한다.
- v6 callback·Qt 상태를 반입하지 않고 session cancel/progress contract를 사용한다.

### S3 — 최적화된 장비/애용품 스캔

- 위 fast path와 fallback 순서를 구현한다.
- 먼저 v6 기준선의 cold/warm profile을 재현하고 카드·폰트 cache와 소형 ROI 합성으로
  즉시 제거 가능한 반복 비용을 분리한다.
- prepared feature bundle과 실캡처 정규화 glyph를 동일 답지에서 비교하며, 저장 형식은
  정확도·시작 시간·RAM·설치 용량 근거가 나온 뒤 결정한다.
- 선택한 matcher는 score와 2위 margin, bounded cache와 session-local calibration을 쓴다.
- 기존 v6의 tier/level 호환 검증과 empty/locked 의미를 보존한다.
- cold/warm benchmark, confusion matrix, cache/feature 준비 횟수와 fallback 회귀를 추가한다.

### S4 — 인연 랭크 OCR과 계산 교차 검증

- 실제 screenshot fixture로 인연 ROI와 숫자 matcher를 고정한다.
- current/alternate outfit dependency와 second-pass 재검증을 구현한다.
- 네 전투 스탯의 expected/observed/delta evidence를 생성한다.
- 불일치를 자동 수정하지 않고 review-required로 승격한다.

### S5 — 학생 스캔 검토 UI와 통합 E2E

- 학생 portrait, 현재값, 스캔값, 계산값, 차이와 confidence를 한 검토 workspace에 표시한다.
- 의심 필드, 누락 dependency, 수정 제안과 raw evidence를 계층적으로 구분한다.
- 후보 학생을 자동 선택하되 사용자의 현재 편집 상태를 덮어쓰지 않는다.
- 수정 → 재검증 → 승인/보류/거절 → commit 및 stale revision 경로를 테스트한다.
- 좁은/보통/최대화 viewport와 실제 Python process E2E를 통과한다.

단계는 순차 의존한다. 다음 단계는 이전 단계가 master 검증을 통과한 accepted snapshot에서만
시작한다. 동일한 scanner 대형 모듈을 여러 세션이 동시에 수정하지 않는다.

## 전체 완료 조건

- 실제 학생 한 명 이상에서 ID부터 인연·장비·전투 스탯까지 candidate가 생성된다.
- 완전한 입력의 계산값과 스캔값 일치가 `verified`로 표시된다.
- 다른 의상 인연이 누락된 후보는 오류가 아닌 dependency missing으로 표시된다.
- 계산 불일치 후보는 명시적 검토 없이는 commit되지 않는다.
- 장비 matcher는 후보마다 2560x1440 합성 canvas를 만들지 않는다.
- Python 전체 test, Flutter 전체 test, `flutter analyze`, 실제 process E2E, Windows release와
  시각 검토를 통과한다.
- recognition asset과 runtime UI asset은 계속 분리된다.
