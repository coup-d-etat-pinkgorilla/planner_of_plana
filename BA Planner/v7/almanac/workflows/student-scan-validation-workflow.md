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
  - id: s3b-input
    type: file
    path: docs/migration/student-scan-v7-session-s3b-input.md
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
- 장비 기본 화면에는 S3 뒤의 S3B에서 장비 전용 binary matcher를 추가 검증한다. 재고
  그리드 matcher의 알고리즘 개념만 사용하고 재고 좌표·고정색·템플릿은 직접 재사용하지 않는다.

## 현재 기준선

학생 identity portrait의 `student_texture_region`은 상단 자원 바와 AP 아이콘을 포함하지
않는다. 2560x1440 기준 기존 crop 시작 y=12에서 상단 82px를 제거해 새 시작점을 y=94
(`y1=0.0653`)로 고정한다. 하단은 y=624(`y2=0.4333`)로 두어 기준 2560x1440 추출 크기를
647x530으로 유지한다. 기존 `student-template`도 같은 82px를 제거하며, 이후 developer-tool
추출은 이 ROI를 그대로 사용한다. 따라서 AP 아이콘의 수평 배치나 상단 바 UI 변경은 학생
identity similarity에 들어가지 않는다.

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

### S3B binary matcher 결정

S3 master 실캡처 이후 수행한 탐색 실험은 binary 경로의 가능성과 직접 복사의 한계를 함께
확인했다. 재고 그리드의 고정 `#2D4663` 마스크와 숫자 템플릿을 Mika 장비 셀에 그대로
적용하면 글자를 거의 검출하지 못했다. 반면 장비 adaptive dark-ink mask를 20x28 glyph로
정규화하고 기존 장비-menu의 자리별 binary mask와 IoU로 비교하면 Mika/Hibiki 6프레임의
`7`/`0` 36셀에서 top-1 36/36이었다. 최소 score는 0.459459, 최소 margin은 0.054173이었다.

이 결과는 T10/Lv70 한 조건뿐이므로 threshold 확정이나 menu fallback 제거 근거가 아니다.
S3B는 다음 경계로 별도 순차 slice를 갖는다. [@s3b-input]

- 48x36 ROI와 두 셀 분할, 장비 adaptive dark-ink 추출, canonical glyph 정규화를 사용한다.
- 장비-menu digit asset을 슬롯·자리별 binary template로 준비하고 IoU와 normalized
  correlation, 최고 score와 2위 margin을 기록한다.
- exact alignment를 먼저 비교하고 불확정일 때만 +/-1px를 시도한다.
- 실행 순서는 `empty/locked -> family/tier -> binary -> small-ROI generated -> one-menu`다.
- low confidence/margin, asset 누락, invalid tier-level은 값을 확정하지 않고 기존 fallback으로
  내린다. 기존 menu fallback은 제거하지 않는다.
- inventory의 6자리 geometry, 고정 RGB, `x`/`k` suffix, OpenCV/numpy 구현과 confusion 보정을
  통째로 반입하지 않는다.
- 실제 0~9와 blank coverage가 부족하면 binary 결과는 shadow evidence로만 남긴다.

S3B promotion gate는 실제 답지에서 committed false positive 0, 숫자·자리·슬롯 confusion
matrix, binary 전후 fallback/menu-call 감소량, cold/warm p50/p95와 bounded cache를 요구한다.
같은 캡처에서 만든 template로 그 캡처를 평가하는 leakage는 금지하며, 실캡처 coverage가
부족하면 threshold·ROI·혼동쌍을 `MASTER_REQUIRED`로 유지한다.

S3B 구현 결과는 production 승격과 분리한다. 20x28 glyph는 Python integer bitset으로 준비하고
51개 slot/position menu digit template(3,570 bytes)을 시작 시 한 번 읽는다. 기본 화면에서는
adaptive dark-ink 뒤 75% IoU + 25% normalized binary correlation으로 순위를 매기며 exact가
불확실할 때만 +/-1px를 재시도한다. 결과는 `equipment_binary_shadow` evidence로 generated보다
앞서 기록되지만 `shadow` status라 confirmed payload나 fallback 대상 집합을 바꾸지 않는다.

현재 Mika/Hibiki Lv70의 18개 level pair/36개 digit cell은 모두 `70`/`7,0` top-1이었다.
committed false positive는 0이며 shadow 상태의 fallback 감소와 menu 호출 감소도 각각 0,
기존과 같은 6회다. cold startup 26.38ms(그중 template prepare 25.10ms), warm 3-slot p50
1.264ms/p95 1.450ms, full-size canvas 0으로 측정했다. 이는 smoke gate 통과이지 production
threshold 확정이 아니다. 실제 digits 1-6/8/9, single-digit blank, slot/tier/family/resolution
반복과 전체 confusion matrix는 계속 `MASTER_REQUIRED`다.

추가 archive 검증은 `C:\Users\brigh\Pictures\Screenshots\BA`의 PNG 194장을 read-only source로
사용했다. runtime의 ID → metadata family → icon tier gate를 통과한 116개 2560x1440 화면에서
298개 ROI를 얻었고, 64명·9 families·3 slots·T1-T10을 포함한다. 4배 확대 RGB contact sheet
7장을 육안 대조한 결과 298/298 level pair가 일치했다. 값 coverage는
10/20/21/30/37/40/43/45/50/54/55/59/60/65/70이며, position 1은 1-7 전체, position 2는
0/1/3/4/5/7/9를 포함한다. score 0.521064-0.650632, margin 0.043264-0.117650이었다.

source screenshot은 runtime asset으로 복제하지 않았다. 대신 48x36 ROI 298개를 960x540
test-only atlas로 묶고 source filename/SHA-256, student/family/tier/slot, 육안 답지와 atlas
좌표를 manifest에 보존했다. 기존 smoke와 합치면 316/316 level pairs, 632/632 digit cells,
committed false positive 0이다. 그러나 position-2 digit 2/6/8, actual single-digit blank와
non-Lv70 1280x720 evidence가 없으므로 production gate는 아직 닫히지 않는다.

후속 production probe로 exact 2560x1440 화면 6장을 추가했다. T1의 1/8/9와 T2의
12/16/18을 각각 서로 다른 학생 3명으로 반복했으므로 누락 숫자를 실제 화면에서 관찰하는
목적은 달성했다. 그러나 T1 9개 ROI는 한 자리 숫자가 두 고정 cell의 가운데에 놓여
15/31/45, 15/38/47, 12/38/47 후보로 분절되어 0/9가 실패했다. 실제 한 자리 화면에서는
두 번째 cell이 단순 blank가 아니므로 기존 합성 blank test를 production 근거로 사용하지 않는다.

T2 9개 ROI의 top-1 후보는 세 반복 모두 12/16/18로 맞았지만 score 0.488096-0.499431과
margin 0.019369-0.069415 때문에 현 0.52/0.04 gate에서 0/9가 확정되었다. 기존 archive의
최소 통과값이 score 0.521064, margin 0.043264이므로 전역 threshold를 낮춰 해결하지 않는다.
중앙 정렬 한 자리 parser, 실제 1/8/9 template coverage, 12/16/18의 정규화/template 개선을
먼저 적용하고 기존 316쌍과 새 18쌍을 독립 답지로 전부 재생해 false positive 0을 확인한다.

또한 새 화면 중 Saori (Swimsuit) 두 장만 student ID/family/tier end-to-end gate를 통과했고
Niko/Kurumi 네 장은 student matcher margin 부족으로 중단되었다. 두 학생의 recognition asset을
추가 검증해야 새 18 ROI 전부를 end-to-end production evidence로 셀 수 있다. 여섯 장은 모두
2560x1440이므로 non-Lv70 exact 1280x720 반복 gate도 여전히 별도로 남는다.

### S3B 생성형 glyph template 실험

현재 S3B binary template의 출처를 구분한다. 이는 inventory grid의
`templates/inventory_count/`가 아니다. v6의 장비-menu 자리별
`templates/equip{slot}level_digit{position}/`에서 v7 recognition asset으로 54개가 byte-identical
복사되었고, 숫자 51개만 matcher가 읽으며 `v` marker 3개는 제외한다. 따라서 grid의 고정
RGB mask, 6자리 geometry, `x`/`k` suffix와 confusion 보정을 반입하지 않았다는 기존 결정은
유효하다.

그러나 장비-menu template도 학생 기본 상세 화면과는 다른 화면에서 나온 asset이다. 글자
크기, antialiasing, 배치가 다르고 position-1 bank에는 1-7만 있다. 실제 한 자리 1/8/9가
고정 두 cell 중앙에서 잘못 분절되고, 12/16/18의 top-1은 맞아도 score가 낮은 결과는 이
cross-screen domain mismatch를 production blocker로 취급할 근거다. 기존 menu bank는 비교
기준 또는 보조 fallback 후보로 유지할 수 있지만 그 자체로 production template 승격 근거가
되지 않는다.

후속 S3B 실험은 사용자가 제안한 v6 생성형 경로에서 숫자 layer만 분리한다. v6/v7 renderer는
200x160 배경과 family/tier icon 위에 28px Bold 흰색 숫자, 1px `#505878` outline, -0.25 shear를
합성하고 bicubic으로 실제 slot/quad ROI를 만든다. 현재 adaptive dark-ink는 흰 fill보다 남색
outline을 주 신호로 추출하므로 outline을 먼저 제거하지 않는다. 대신 다음 후보를 같은 frozen
답지에서 독립 비교한다.

1. 현재 장비-menu binary bank
2. 생성형 outline-only glyph
3. 생성형 fill+outline alpha silhouette
4. 생성형 fill-only glyph
5. 기존 background+icon+number full-composite generated matcher

생성형 glyph는 background/icon RGB를 포함하지 않는다. 투명 text layer에 동일한 위치·shear·
quad transform을 적용하거나 full composite 결과를 transformed text alpha와 교차해 text
pixel만 남긴다. 이를 통해 실제 geometry와 resampling은 보존하되 family/tier 배경 오염은
차단한다. Outline-only는 우선 가설일 뿐이며 variant 결과 전에는 확정하지 않는다.

한 자리 숫자는 먼저 전체 48x36 level ROI에서 foreground bounding box 또는 connected
component를 찾고 하나의 centered glyph로 정규화한다. 두 component가 검출된 경우에만 자리별
cell/template 비교로 전환한다. 합성 `digit+blank` cell만으로 실제 blank coverage를 주장하지
않는다.

Template 생성은 합성이므로 실캡처 답지를 직접 복제하지 않지만 threshold·variant 선택에는
별도 calibration set을 사용한다. 기존 316 accepted level pairs와 새 18 probe pairs는 frozen
validation으로 유지하며 template 생성이나 threshold tuning에 사용하지 않는다. Variant별로
single-digit 1/8/9, two-digit 12/16/18, 기존 10-70 confusion, score/margin, false positive,
fallback/menu-call, cold/warm p50/p95와 bounded memory를 비교한다. Production 승격은 전체
frozen replay의 committed false positive 0, non-Lv70 exact 1280x720 반복과 master 명시 승인을
모두 만족한 뒤에만 가능하다.

2026-08-22 구현 결과에서 생성형 glyph는 background/icon을 포함하지 않는 transparent text
layer와 screen의 near-white fill locality seed를 사용한다. 짧은 background/icon component를
제외하고 전체 숫자 문자열을 40x28 integer bitset으로 정규화하므로 한 자리 1/8/9를 기존
24px cell 경계에서 자르지 않는다. Outline과 fill+outline은 fill 주변으로 제한해 배경의
남색 픽셀이 outline으로 섞이지 않게 한다.

육안 검증한 새 6장은 source SHA-256을 확인한 뒤 18 ROI/432x72 test-only atlas로 고정했다.
기존 archive 298, Mika/Hibiki 1280x720 Lv70 18, 새 T1/T2 probe 18을 합친 frozen 334 pair에서
비교 결과는 다음과 같다.

| 방법 | top-1 | 현 gate accepted | accepted wrong | fallback |
|---|---:|---:|---:|---:|
| 장비-menu binary | 325/334 | 316/334 | 0 | 18 |
| generated outline | 334/334 | 331/334 | 0 | 3 |
| generated fill+outline | 334/334 | 310/334 | 0 | 24 |
| generated fill | 334/334 | 334/334 | 0 | 0 |

Generated fill의 최소 score는 0.616097, 최소 margin은 0.065519였다. 이는 가장 강한 shadow
lead를 정한 결과이지 production variant나 threshold를 승인한 결과가 아니다. Frozen 334는
variant 비교와 회귀 검증에만 쓰고 threshold calibration에는 사용하지 않는다. Runtime은
`equipment_generated_binary_shadow` evidence를 별도로 내보내며 candidate payload와 기존
generated/menu fallback 대상은 바꾸지 않는다.

Fill runtime bank는 슬롯 간 공유하는 level 1-70 whole-string 70개 bitset/9,800 bytes다.
비교용 outline/fill+outline은 benchmark에서 lazy 생성하며 세 variant 전체는 210개/
29,400 bytes다. Menu+fill cold construction 206.438ms 중 fill prepare가 173.055ms이고 warm
3-slot fill p50/p95는 4.525/4.925ms, full-size canvas는 0이다. Production 전에는 fill bank를
build-time compact asset으로 만들거나 동등한 lazy/precompute 방법으로 cold 비용을 낮춘 뒤
다시 측정한다.

후속 재평가에서 Niko/Kurumi asset과 별도 T2 repeat의 student gate는 통과했다. 새 18 ROI의
generated fill도 tier가 확인된 17개에서는 17/17 정답이었지만 Kurumi Necklace T2 tier가
score 0.493740, margin 0.009946으로 거부되어 전체 end-to-end는 17/18이다.

BA archive의 저해상도 자료는 exact 1280x720이 아니라 client-area 1275x720 8장과 framed
1276x752 2장이다. 육안 답지가 있는 1275x720 level-bearing 11개에서 generated fill은 정답 6,
오답 3, fallback 2였다. 오답 세 개는 모두 Aris T9의 실제 Lv65를 Lv6으로 확신 있게 수락한
것이며 outline/fill+outline/fill 전 variant와 세 slot에서 동일하게 재현됐다. Tier-eligible
blank/non-level 세 개는 모두 fallback해 blank false positive는 없었다. 따라서 threshold만
조정해서는 승격할 수 없고, client scale에서 두 번째 digit component를 보존하는 추출 수정과
Lv65/Lv6 회귀가 먼저 필요하다.

남은 gate는 1275x720 portable reviewed regression, scale-aware two-digit 보존, Kurumi T2 slot-3
tier 보정, 독립 calibration/validation 분리, fallback/menu-call 감소량, cold 최적화와 master
명시 승인이다. 이 조건 전까지 generated fill도 shadow-only이고 S4/S5를 시작하지 않는다.

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

## Exact 1280x720 장비 전수 matrix

사용자 결정에 따라 16:9가 아니거나 pixel size가 정확히 1280x720이 아닌 screenshot은
calibration, validation과 promotion evidence에서 제외한다. 1275x720과 1276x752 결과는
scale diagnostic으로만 남기며 exact 1280x720에서 재현하기 전에는 pass/fail 분모에 넣지 않는다.

일반 장비 9 family 각각의 tier별 유효 level 수 합은 445이므로 equipped 원자 경우는
9x445=4,005개다. Shiroko(Hat/Hairpin/Watch), Hoshino(Shoes/Bag/Charm),
Ako(Gloves/Badge/Necklace) 세 tuple이 9 family를 중복 없이 덮는다. 세 slot을 같은
tier-level로 성장시키면 학생당 445, 총 1,335 capture configurations이며 stable repeat
3회 기준 4,005 PNG다.

Runtime factorization을 이용하면 실캡처 core는 더 줄일 수 있다. Tier icon은 family-specific,
level glyph는 slot-specific/family-independent이므로 90 family-tier observations의 하한은
화면당 3 slot 기준 30장이다. 30-row matrix는 각 slot에서 한 자리 1~9, tens 1~7, ones
0~9, tier max 10개와 12/23/34·56/65 혼동쌍을 모두 포함하며 Shiroko T4 화면에 실제
12/23/34를 배치한다. Shiroko/Hoshino/Ako calibration 30설정과 Aru/Eimi/Kotama Camping
validation 30설정을 분리한다. Stable repeat 3회 기준 90+90=180 PNG가 production-quality
최소 2-split이다. 모든 family-level Cartesian pair를 직접 요구할 때만 1,335설정을 사용한다.

별도로 student level band에 따른 empty/equipped/locked 물리 상태 14개, unlock boundary
Lv1/9/10/19/20, favorite unsupported/empty/love-locked/T1/T2/uncertain 6개를 둔다. Unresolved
slot mask 7개와 blank, 0, tier max+1, 70 초과, partial digit, nonnumeric contamination은
synthetic-only negative/fallback 검증으로 분리한다. 전체 규칙과 기계 판독 manifest는
`docs/migration/student-scan-v7-s3b-1280x720-equipment-coverage.md` 및 해당 handoff artifact를
따른다.

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

### S3B — 장비 기본 화면 binary matcher 보강

- S3의 안전한 generated/menu fallback을 유지한 채 장비 전용 binary matcher를 shadow로
  먼저 추가한다.
- adaptive dark-ink, canonical glyph, 장비-menu binary template, IoU/correlation과 조건부
  shift를 사용한다.
- 장비-menu template의 cross-screen 한계가 실측되면 v6 생성형 text layer에서 background와
  icon을 제외한 glyph를 만들고 outline-only/fill+outline/fill-only를 frozen 답지로 비교한다.
- 한 자리 숫자는 전체 ROI의 centered component로 먼저 판독하고, 실제 두 component가 있을
  때만 자리별 분할을 적용한다.
- 실제 digit 0~9와 한 자리 blank coverage에서 false-positive 0과 fallback 감소를 입증한
  경우에만 candidate value를 확정하는 production 단계로 승격한다.
- 충분한 답지가 없으면 threshold/ROI/confusion 보정을 확정하지 않고 shadow evidence와
  `MASTER_REQUIRED`로 인계한다.
- 상세 입력과 acceptance는 `student-scan-v7-session-s3b-input.md`를 따른다. [@s3b-input]

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

단계는 순차 의존한다. S3B는 accepted S3 snapshot에서 시작하고 S4는 S3B master 검증을
통과한 accepted snapshot에서만 시작한다. 동일한 scanner 대형 모듈을 여러 세션이 동시에
수정하지 않는다.

## 전체 완료 조건

- 실제 학생 한 명 이상에서 ID부터 인연·장비·전투 스탯까지 candidate가 생성된다.
- 완전한 입력의 계산값과 스캔값 일치가 `verified`로 표시된다.
- 다른 의상 인연이 누락된 후보는 오류가 아닌 dependency missing으로 표시된다.
- 계산 불일치 후보는 명시적 검토 없이는 commit되지 않는다.
- 장비 matcher는 후보마다 2560x1440 합성 canvas를 만들지 않는다.
- Python 전체 test, Flutter 전체 test, `flutter analyze`, 실제 process E2E, Windows release와
  시각 검토를 통과한다.
- recognition asset과 runtime UI asset은 계속 분리된다.
