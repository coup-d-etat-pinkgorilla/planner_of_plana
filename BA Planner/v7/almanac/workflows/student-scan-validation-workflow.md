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
  - id: student-basic-recognizer
    type: file
    path: backend/core/student_scan_recognizer.py
  - id: equipment-position-bank
    type: file
    path: backend/tools/build_student_equipment_position_digit_bank.py
---

# Student Scan Validation Workflow

## Production Studio numeric bank (2026-08-28)

The production scanner loads one required compact asset named
`student-studio-numeric-digit-bank`. The stable-frame crop phase emits exact polygon cells for all 16
approved positions; consumers never need to retain or reconstruct the full frame. Student level, weapon
level and relationship rank use the bank before their empirical readers. Equipment uses the new
slot-specific two-digit bank first and preserves the prior compact position bank for centered one-digit
levels and older low-resolution raster generations.

Promotion gates are frozen by SHA-resolved archive replay: student 10/10, weapon 89/89, equipment
307/307 and relationship 24/24. A production change must preserve both these current-generation results
and the old 1280 Mika fallback repeats. Regenerate the asset and region integrity together with
`backend/tools/sync_student_studio_numeric_bank.py` after any Studio text or ROI edit.

## Relationship layout completion (2026-08-28)

Relationship rank uses separate centered position banks for each supported display width. The one-digit
layout uses `x=103..120`; the two-digit layout uses `x=95..112 / 112..129`; and the three-digit layout
uses `x=86..103 / 103..120 / 120..137`. Every cell shares `y=1133..1159` and is generated from the
user-aligned 32 px, unsheared, zero-stroke fill layer in `suggestion_text_1.json`, `suggestion_text.json`,
or `suggestion_text_100.json` respectively. Do not reuse the two-digit positions by padding values.

The frozen archive gate covers rank 6, 22 two-digit records, and rank 100: 24/24 values and 48/48 digits
are correct. Keep layout-specific atlas pages and per-layout summaries when changing these coordinates or
the foreground mask.

이 문서는 v6 학생 스캔의 실제 인식 기능을 v7 Python scanner session과 Flutter 검토
화면에 연결하고, SchaleDB 방식의 학생 스탯 계산을 독립 검증 증거로 사용하는 후속
워크플로를 고정한다. 기존 P5/P6의 session, candidate, review, commit 경계를 교체하지
않고 그 안의 학생 수직 슬라이스를 완성한다. [@migration-baseline] [@scanner-session]

## 승인된 결정

- 전체 학생 스캔을 시작하면 메인 UI는 같은 Flutter 상태를 유지한 채 Windows 도크 화면으로
  전환된다. 도크는 게임 창과 같은 외곽 높이, 가로:세로 3:8이며 우측을 우선하되 여유가 더
  큰 쪽에 붙는다. 위치 이동만으로 함께 배치할 수 없을 때만 게임 외곽 크기를 1280x720으로
  맞춘다. 종료·실패·취소 시 두 창의 원래 위치와 크기를 복원하고 메인 결과 검토 화면을 연다.
- protocol v1의 `feedback` 이벤트는 최종 candidate 이전에 확정된 학생 필드를 실시간으로
  전달한다. 도크 상단은 대상·모드·단계·진행·인식 수·취소를 표시하고, 하단 80도 사다리꼴은
  학생 탭 상세 정보 구조를 축약해 표시한다. 학생 교체는 `기존 카드 0도 퇴장 완료 → 게임의
  학생 이동 → 다음 학생 ID 카드 180도 입장 완료 → 인식 필드 실시간 반영` 순서로 실행한다.
  이를 위해 matcher는 이동 전에 `__student_exit__` 피드백을 보내고, 다음 화면에서는 학생
  ID를 값 없는 카드로 먼저 보낸다. 같은 학생의 후속 필드 갱신에는 교체 애니메이션을
  재시작하지 않는다.

- 실제 Steam Windows 클라이언트에서 백그라운드 캡처와 학생 인식은 가능하지만 마우스
  클릭과 드래그 메시지는 소비되지 않는다. 전체 스캔의 방향키 이동은 성공하더라도 게임
  창이 포그라운드로 전환되므로 완전한 백그라운드 전체 스캔으로 표시하지 않는다.

- 학생 스탯 계산은 도입한다. 주 용도는 상세 스탯 표시와 학생 스캔 교차 검증이다.
- 학생 스캔에는 인연 랭크가 필수 입력이다. v6에는 해당 인식이 없으므로 신규 구현한다.
- 학생 1명 스캔은 결과 화면에서 나머지 보유 의상의 인연 랭크를 입력받아 같은 후보를
  재검증한다. 입력값은 검증 문맥이며 다른 의상의 확정 저장값으로 승격하지 않는다.
- 전체 학생 스캔은 v6처럼 다음 학생을 반복 순회하되 후보를 즉시 검증·표시하지 않는다.
  반복 종료 후 후보 전원의 인연 랭크를 SchaleDB ID로 합산하고 한 번에 교차 검증한 뒤
  결과 화면을 공개한다.
- 결과 화면의 후보 목록은 계획-시작 중앙 목록과 같은 80도 사선 스크롤 투영을 사용한다.
  단일 스캔의 보유 의상 인연 랭크는 주 후보 바로 아래 의상 행에서 입력·확인한다.
- 전체 학생 결과는 카탈로그의 `group`을 기준으로 같은 캐릭터의 모든 의상을 위아래로
  인접 배치하되, 캐릭터의 최초 등장 순서와 그룹 안의 스캔 순서는 보존한다.
- 전체 학생의 다음 화면 이동은 대상 창의 우측 방향키 입력을 우선 사용한다. 같은 학생이
  즉시 다시 인식되면 우측 버튼 입력을 한 번 보완하고 안정화 대기 후 재확인한다. 입력이
  실제로 반영되지 않은 상황을 정상 순회 완료로 즉시 오판하지 않는다. 목록 오른쪽 끝이면
  왼쪽으로 방향을 바꾸고 이미 확인한 학생을 건너뛰면서 반대쪽 끝까지 수집한다.
- 장비 스캔은 v6 동작을 참고하되 생성형 레벨 템플릿의 고비용 경로를 그대로 이전하지 않는다.
- 스캔한 현재 상태, 정적 Schale 원천값, 계산 결과와 사용자 목표는 서로 다른 버킷이다.
- 계산 불일치는 자동 수정 근거가 아니라 사용자 검토를 요구하는 독립 evidence다.
- `../v6`는 동작과 fixture의 참조일 뿐 v7 런타임 dependency가 아니다.
- 장비 기본 화면에는 S3 뒤의 S3B에서 장비 전용 binary matcher를 추가 검증한다. 재고
  그리드 matcher의 알고리즘 개념만 사용하고 재고 좌표·고정색·템플릿은 직접 재사용하지 않는다.
- 학생 레벨, 전용무기 레벨, 인연 랭크와 장비 레벨 숫자는 먼저 실제 화면의 숫자 ROI를
  자리별로 확정한다. 기울어진 글자를 역기울기 affine transform으로 펴고 직사각형으로
  자르지 않는다. 원본 픽셀을 유지한 채 서로 평행한 사선 경계 사이를 평행사변형 cell로
  잘라낸다. 이 ROI gate를 통과한 뒤에만 게임 글꼴·채움·외곽선·기울기·자리 배치를 재현한
  결정론적 합성 템플릿을 평가한다. 실제 게임 캡처는 ROI와 renderer 파라미터를 고정하는
  calibration 및 독립 validation 답지로만 사용하며 runtime template에는 포함하지 않는다.

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

## 학생·전용무기·인연·장비 숫자 ROI 우선 전환

현재 학생 레벨은 검수된 실제 화면에서 잘라낸 숫자 bank, 전용무기 레벨은 생성 이력이
남아 있지 않은 v6 정규화 mask, 인연 랭크는 검수 화면에서 파생한 whole-rank 및 digit bank,
장비 레벨은 위치별 합성 bank를 사용한다. 네 경로의 첫 공통 계약은 template가 아니라
`field ROI -> foreground mask -> source-preserving parallelogram digit cells`이다. 각 화면의
서로 다른 색·외곽선·자리 배치는 유지한다. 자리 ROI를 육안으로 승인한 뒤에만
`synthetic text layer -> same parallelogram geometry -> canonical glyph`를 평가한다.
[@student-basic-recognizer] [@equipment-position-bank]

### ROI 우선 계약

- 원본 field ROI 안에서 숫자 전경만 추출한다. 학생·무기·장비는 흰 채움과 남색 외곽선의
  역할을 분리해 보고, 인연은 하트 중앙 숫자 상자만 사용한다. UI 배경, 하트 장식, 장비
  아이콘과 레벨 접두사는 digit cell에 들어오면 안 된다.
- 분할 좌표는 `u = x - shear * (y - y_center)` 축에서 자리 사이의 low-ink valley를 찾되,
  화면 bitmap을 이 축으로 변환하지 않는다. 실제 cut은 원본 좌표의
  `x = u + shear * (y - y_center)`인 두 평행선 사이 polygon mask로 수행한다. 따라서 잘린
  glyph에는 inverse shear, bicubic/bilinear resampling 또는 형태 복원이 없다.
- 학생 레벨은 두 자리까지, 전용무기와 장비는 한/두 자리, 인연은 한/두 자리와 `100`의
  세 자리 layout을 각각 검증한다. 인연 shear `0`은 같은 알고리즘의 직사각형 특수 사례다.
- renderer shear는 초기 경계 후보로만 사용한다: 학생 `-0.20`, 전용무기와 장비 `-0.25`,
  인연 `0`. 실제 ROI 경계 기울기와 바깥 여백은 실캡처 contact sheet의 육안 승인으로
  별도 고정하며 template 점수를 높이기 위해 조정하지 않는다.
- 사용자가 v6 Template Alignment Studio에서 저장한 `suggestion.json`이 있으면 D2의 수동
  경계 권위로 사용한다. v6의 `width`는 slant를 포함한 bounding width가 아니므로 v7은
  `x/y/width`를 재조합하지 않고 저장된 `points` 네 점을 직접 읽는다. 기준 화면과 다른
  해상도에는 reference width/height 비율로 점을 투영하되, 추출은 bounding crop과 polygon
  alpha mask만 사용하고 quad warp를 적용하지 않는다.
- Studio `suggestion_text.json`이 함께 있으면 D3 renderer의 font path, size, shear, fill 및
  stroke metadata를 우선 calibration 후보로 사용한다. 비교용 matcher template는 화면의 RGB
  색을 보존하지 않고 전경을 흰색 binary mask로 canonicalize한다. 배경 제거 후 숫자 신호가
  흰색인 현재 pipeline에서는 합성 template도 흰색이어야 하며, fill-only와 configured-stroke를
  실제 ROI에서 모두 비교한다. `Lv.`/`.` 및 이웃 outline처럼 polygon 경계에 걸린 별도 connected
  component는 제거하되 숫자 본체와 연결된 획은 임의로 깎지 않는다.
- ROI gate는 각 cell의 숫자 획 잘림 0, 이웃 자리 획 혼입 0, 빈 cell 0, 원본 전경 픽셀의
  합집합 보존과 source pixel 값 불변을 요구한다. 이 조건을 통과하기 전에는 recognition
  score, threshold, font size나 자간을 최적화하지 않는다.
- 2026-08-27 BA screenshot archive replay에서 이 gate가 필드별로 갈렸다. 현재 두 자리 장비
  cell은 visual ground truth 307/307을 통과했지만, 인연은 13/22이며 학생은 legacy-confirmed
  값과 59/122만 일치했다. 인연 41/47과 학생 90에서는 첫 cell에 점 또는 세로획만 남았다.
  따라서 하나의 두 자리 Studio 절대좌표를 모든 값에 재사용하지 않는다. 게임이 전체 문자열을
  가운데 정렬하므로 layout별 전체 숫자 bounds를 먼저 검출하고 그 bounds에 상대적인 평행사변형
  cell을 만들거나, 값 layout별 anchor/cell geometry를 별도로 승인한다. 색·threshold·폰트
  재탐색은 이 geometry gate를 대체할 수 없다.
- 후속 색상-mask replay에서 학생 90의 첫 cell은 실제로 9 본체 263픽셀을 포함하고 있었다.
  기존 후처리가 경계에 닿지 않은 2픽셀 점을 본체보다 우선한 것이 `9->1`의 원인이었다.
  숫자 cell에서는 높이가 cell의 30% 미만인 점 성분을 제외한 뒤 가장 큰 성분을 유지한다.
  이 규칙은 학생 legacy agreement를 122/122로 회복했고 ROI -1/-2 이동은 추가 이득이 없어
  학생의 육안 승인 좌표를 변경하지 않는다. 인연은 남색 hue mask와 -2 reference-pixel 이동으로
  14/22까지만 개선되므로 이 결과를 production으로 승격하지 않는다.
- 자리별 atlas에서는 인연의 `(2,2)` 최적 shift 군이 26/26 정답이고, 세로 shift `1` 군은
  3/15만 정답이었다. 같은 숫자의 정답/오답 mask 모두 글자 본체를 유지하므로 전체 ROI를 다시
  이동하는 대신 position별 두 번째 baseline/raster variant 또는 translation 이후의 shape
  normalization을 shadow 비교한다. 학생 atlas는 현재 레벨 90의 `9/0`만 포함하므로 122/122
  일치는 그 두 숫자에 한정하고 다른 레벨 숫자의 production coverage로 확대 해석하지 않는다.
- 이후 BA 폴더의 별도 육안 답지 series `1/12/23/34/45/56/67/78/89/90`을 찾아 학생 레벨
  범위를 바로잡았다. 현재 합성 경로는 10/10 값과 19/19 가시 숫자를 맞히며 레벨 1의 둘째
  cell도 blank로 유지한다. 첫째 자리는 1-9, 둘째 자리는 0과 2-9를 실제 화면으로 확인했다.
  둘째 자리 1만 실화면 미확보로 기록하되, 사용 가능한 BA 데이터에서는 오답이 없으므로 다음
  numeric 개선 대상은 인연 랭크로 전환한다.
- 갱신된 인연 `suggestion_text`의 rank-37 `3/7` fill alpha를 기준으로 두 cell을 각각 17px로
  넓혀 오른쪽 끝 1px 잘림을 제거했다. 이후 남은 실패는 ROI가 아니라 2560 기준 17x26 합성
  template를 1280 기준 약 9x13 실제 cell에 크기 보정 없이 비교한 문제로 판명됐다. Binary
  template를 실제 ROI 크기에 nearest-neighbor로 맞춘 뒤 shift 비교하며, 두 자리 답지는
  2560 13/13과 1280 9/9, 합계 22/22 값·44/44 숫자를 통과한다. 한 자리 및 `100`은 별도
  layout gate로 계속 남긴다.

### 고정 산출물

- 하나의 versioned renderer spec에 필드별 font file SHA-256, font size, fill, outline와 두께,
  shear, anchor/baseline, source canvas, quad ROI, output size, center trim, cell bounds를 기록한다.
- builder는 외부 설치 글꼴이나 OS font fallback을 사용하지 않고 recognition asset에 포함된
  고정 TTF/OTF만 읽는다. 같은 입력에서 JSON/atlas 또는 bitset bank의 byte hash가 항상 같아야
  한다.
- 학생 레벨은 `1..100`, 전용무기 레벨은 `1..60`, 인연 랭크는 `1..100`의 유효 범위를
  생성한다. 저장은 모든 완성 문자열 PNG가 아니라 실제 layout이 다른 위치별 equivalence
  class로 축약한다. 학생·전용무기는 한 자리/두 자리 배치를, 인연은 한 자리/두 자리와
  `100`의 세 자리 배치를 별도로 표현한다.
- template identity에는 최소한 `field`, `position`, `digit`, `layout_width`가 들어간다.
  위치가 동일하다는 실측 근거가 없는 필드끼리는 숫자 모양이 같아도 bank를 공유하지 않는다.
- calibration screenshot, validation screenshot과 예상값은 test fixture 및 provenance manifest에
  남기되 그 픽셀로 runtime template를 만들지 않는다.
- 글꼴과 기울기는 자동 탐색으로 결정하지 않는다. 사용자가 v6 Template Alignment Studio에서
  육안으로 확인한 값을 승인 기준으로 사용한다. 세 필드는 모두 경기천년제목 Medium을 쓰며,
  학생 레벨은 shear `-0.2`, 인연 랭크는 shear `0`, 전용무기 레벨은 장비 레벨과 같은
  shear `-0.25`를 사용하되 별도 글자 크기를 갖는다. Font size, 테두리색과 두께, raster
  variant는 이 고정 조건 안에서 calibration 점수를 참고해 선택하고 독립 screenshot으로
  validation한다.

### 순차 전환 단계

1. **D0 기준선 동결** — 현재 학생/전용무기/인연/장비 reader의 모든 실제 fixture에서 값, score,
   runner-up margin, fallback/review 상태와 처리 시간을 기록한다. 기존 asset은 이 단계에서
   삭제하지 않는다.
2. **D1 field ROI 특성화** — 네 필드에서 숫자 전경만 남는 outer ROI와 field-specific mask를
   실제 한/두/세 자리 화면으로 고정한다. 숫자 획을 자르거나 UI 배경을 포함한 표본은
   renderer 작업으로 넘기지 않는다.
3. **D2 평행사변형 자리 추출** — 예상 layout별 low-ink valley와 평행한 polygon 경계를
   계산하거나 사용자가 승인한 Studio `suggestion.json`의 points를 사용해 원본 픽셀을 그대로
   자리별로 자른다. actual ROI, 경계 overlay, 각 digit cell을 한 contact sheet에 배치해
   사용자가 육안 승인한다. 수동 suggestion과 자동 valley가 다르면 suggestion을 우선하되,
   불필요한 UI 픽셀이 들어온 수동 cell은 승인된 것으로 간주하지 않고 Studio에서 다시 조정한다.
4. **D3 renderer 특성화** — 사용자가 Template Alignment Studio에서 승인한 글꼴과 shear를
   고정한다. 그 안에서 필드별 font size, baseline, fill/outline 색과 두께를 calibration으로
   선택한다. 같은 화면으로 renderer를 맞추고 평가하지 않도록 calibration과 validation을
   화면 단위로 분리하고 선택값과 탐색 범위를 manifest에 기록한다.
5. **D4 결정론적 bank 생성** — 고정 renderer spec과 승인된 동일 polygon cell geometry로
   위치별 digit mask를 생성하고 asset
   catalog에 별도 purpose로 등록한다. builder 재실행 hash, 누락 digit/position, runtime UI
   asset 혼입 여부를 자동 검사한다.
6. **D5 shadow 비교** — 기존 reader의 candidate를 바꾸지 않은 채 합성 matcher의 top-1,
   score, margin, shift, 예상값을 evidence로 수집한다. 학생 레벨, 전용무기 레벨, 인연 랭크와 장비 레벨을
   각각 독립 confusion matrix로 평가한다.
7. **D6 필드별 승격** — ROI gate와 matcher gate를 모두 통과한 필드만 하나씩 합성 bank를
   production primary로 승격한다. 앞 필드의 회귀와 실제 전체 스캔을 통과하기 전에는 다음
   필드를 승격하지 않는다. 승격 중 불확실한 합성 결과는 기존 확정값을 덮지 않고 review로
   보낸다.
8. **D7 legacy runtime 제거** — 네 필드가 모두 acceptance gate를 통과하면 실캡처 파생
   digit/whole-rank asset과 출처 불명 weapon glyph를 runtime manifest에서 제거한다. 해당
   이미지는 필요한 경우 test-only fixture로만 보존하며, production에서는 합성 bank 외의
   legacy matcher로 조용히 fallback하지 않는다.

### 승격 기준

- 독립 validation에서 accepted wrong가 필드별 0이어야 하며, 현재 실제 fixture의 확정값을
  하나도 잃지 않아야 한다. 오답을 fallback/review로 내리는 것은 허용하지만 확정 오답은
  허용하지 않는다.
- 각 필드는 0~9 숫자 모양, 가능한 모든 자리, 한 자리 blank, 최소·최대 경계와 `8/9`,
  `1/7`, `3/8`, `5/6` 혼동쌍을 validation에서 다룬다. 실제 계정에 없는 값은 합성 self-test로
  geometry만 확인할 수 있지만 production 정확도 분모에는 넣지 않는다.
- 학생 레벨은 1/9/10/89/90/99/100, 전용무기는 1/9/10/49/50/59/60, 인연은
  1/8/9/10/89/90/99/100 경계를 실제 캡처 또는 사용자가 명시적으로 승인한 대체 근거로
  고정한다. 확보되지 않은 실제 경계는 `MASTER_REQUIRED`로 남기며 검증되었다고 표기하지 않는다.
- 1280x720 exact client가 필수 validation 기준이다. 더 큰 해상도는 scale diagnostic으로
  추가하되 exact 기준을 대신하지 않는다.
- cold bank 준비 시간, warm field p50/p95, prepared memory와 설치 용량을 기록한다. 스캔 중
  문자열별 전체 화면을 다시 렌더링하거나 OS 글꼴을 반복 로드해서는 안 된다.
- 단일 스캔과 전체 스캔, 다른 학생/의상 전환, 결과 재검증에서 값과 evidence source가
  동일해야 한다. 전체 스탯 교차 검증도 새 숫자 입력으로 기존 exact fixture를 유지해야 한다.

이 전환의 완료 상태는 필드별 `specified -> generated -> shadow -> production -> legacy_removed`
중 하나로 P0-P6 상태 문서에 기록한다. 현재 결정만으로 정확도 승격을 간주하지 않으며,
세 필드는 모두 `specified`에서 시작한다.

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

### S3B 위치별 19-mask production 결정 (2026-08-23)

사용자는 게임이 장비 레벨을 항상 같은 위치와 같은 폰트/기울기로 표시하고, v6 mask의
픽셀 단위 형상과 위치도 과거에 모두 육안 검증했다고 확정했다. 한 자리 숫자는 두 자리
layout의 첫 번째 위치를 그대로 사용한다. 따라서 전체 문자열 70개나 tier별 digit Cartesian
표본을 production 전제조건으로 삼지 않고 다음 19개 equivalence class만 유지한다.

- 첫 번째 위치: 1~9 아홉 개
- 두 번째 위치: 0~9 열 개
- 두 번째 위치 blank: 별도 숫자 template가 아니라 foreground 부재와 tier-level validity로 검증

`S3B_1280_DIGITS`의 exact 1280x720 네 장은 10~19를 세 slot에서 관측해 일의 자리 0~9를
모두 채운다. 함께 제공된 2560x1440 한 장은 diagnostic-only다. 이 자료는 template pixel
source가 아니라 독립 답지/fixture이며 runtime bank는 v7 renderer의 white fill, navy 1px
outline, -0.25 shear와 고정 cell placement에서 생성한다. 결과 bank는 19개/1,330 prepared
bytes이고 source screenshot pixel을 포함하지 않는다.

Production-selected level 경로는 cell별 near-white fill을 추출하고, occupied cell마다 tall
connected component가 정확히 하나인지 확인한 뒤 0.52 score와 0.04 margin gate를 적용한다.
349쌍 replay에서 349/349 정답, accepted wrong 0, fallback 0이며 exact 1280x720은 30/30이다.
최소 score/margin은 0.654438/0.086389다. Cold construction 36.288ms, bank load 0.462ms,
warm one-ROI p50/p95 2.768/3.206ms이고, 여섯 integration frame의 menu 호출은 6→0이다.

이 승격은 장비 level에만 적용한다. Kurumi Necklace T2 icon은 T2가 top-1이어도 기존 tier
gate에서 거부되므로 full S3B end-to-end production 완료 주장은 보류한다. Tier가 확정되지
않거나 위치 matcher가 불확실하면 기존 generated/menu 경로로 내리며 S4/S5는 시작하지 않는다.

### S3B 실제 tier ROI pilot (2026-08-23)

기본 화면 tier reader의 기존 template는 실제 화면 crop이 아니다. v6 inventory icon을 공통
`square.png` 배경 위에 합성하고 매 판독마다 family의 T1~T10 후보를 열어 비교한다. 사용자는
합성 오차와 반복 I/O를 함께 제거하기 위해 실제 고정 inner ROI의 직접 대조를 제안했다.

Exact 1280x720 하루나(체육복) T1~T10 열 장에서 Shoes/Bag/Necklace 30개 70x40 inner ROI를
template split으로 만들고, 쿠루미 T2 네 장의 같은 세 family 12개 ROI를 identity-independent
validation으로 분리했다. 전체 screenshot은 runtime asset에 들어가지 않으며 test-only atlas와
source SHA-256 manifest만 보존한다.

| 방식 | 쿠루미 T2 정답/12 | fallback | 최소 margin | warm p50/p95 ms |
|---|---:|---:|---:|---:|
| 기존 배경+아이콘 합성 | 8 | 4 | Necklace 0.035068 | 51.928 / 52.810 |
| 실제 ROI correlation | 12 | 0 | 0.502763 | 9.317 / 10.260 |
| 실제 ROI prepared feature | 12 | 0 | 0.144884 | 2.233 / 2.386 |
| 실제 ROI RGB mean only | 12 | 0 | 0.039230 | 0.766 / 0.848 |

Prepared feature가 속도와 margin의 균형이 가장 좋아 현재 pilot lead다. RGB mean-only는 빠르지만
Necklace margin이 좁아 선택하지 않는다. 아직 Shoes/Bag/Necklace의 독립 검증도 T2에 한정되며
나머지 여섯 family template가 없으므로 production reader는 변경하지 않는다. 다음 입력은
아이리(밴드)의 Hat/Hairpin/Charm T1~T10 열 장과 칸나의 Gloves/Badge/Watch T1~T10 열 장이다.
그 뒤 치히로·마리나(치파오)·츠루기(수영복)의 identity-disjoint T1~T10 30장을 validation으로
사용해 전체 9-family gate를 판정한다.

#### 실제 ROI production 후속 결정

아이리(밴드)의 Hat/Hairpin/Charm T1~T10과 칸나의 Gloves/Badge/Watch T1~T10 exact
1280x720 자료가 추가되어 하루나(체육복) 자료와 함께 9 family x 10 tier의 90-template bank가
완성됐다. 사용자는 v6에서 장비 아이콘이 정확히 같은 위치에 배치됨을 이미 검증했으므로
새로운 identity-disjoint T1~T10 validation을 생략하기로 결정했다. 이 면제는 fixed tier-icon
ROI에만 적용한다.

Runtime은 700x360 atlas 한 장과 provenance metadata를 읽어 90개의 70x40 `PreparedFeature`를
시작 시 한 번 만든다. 학생 metadata로 family를 제한한 뒤 열 tier만 비교하며 score 0.65,
margin 0.08을 모두 통과할 때 `equipment_direct_icon_tier`를 확정한다. 불확실하거나 asset이
없을 때만 기존 배경+inventory-icon 합성 reader로 fallback한다.

90 template self-check는 90/90, wrong 0, 최소 margin 0.129761이다. 기존에 확보된 쿠루미 T2
4프레임과 Mika/Hibiki T10 6프레임의 30 ROI도 30/30, wrong 0, direct source 30/30이며 최소
score/margin은 0.999764/0.144884다. Warm p50/p95는 1.960/2.269ms, bank prepare 52.269ms,
cold recognizer 91.631ms, prepared memory 1,310,400 bytes다. 이에 actual ROI 경로를 production
선택하고 기존 합성 경로는 안전 fallback으로 유지한다.

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
성급, 장비 티어와 레벨, 전용무기, 인연, 애용품, 능력 개방이다. 2026-08-26 실제 Mika와
Mika(수영복) 캡처 parity로 기본 정보의 네 값에는 패시브/전용무기 패시브 전투 버프를
포함하지 않으며, 장비·전용무기·인연·능력 개방의 `*_Base` 값은 장비 계수 적용 전의
multiplier-eligible flat 합계에 들어감을 확정했다.

이 계산 계약은 과거 GitHub 저장소가 아니라 2026-08-26 현재 `https://schaledb.com/`가
실제로 내려주는 브라우저 번들에서도 다시 확인했다. 현재 사이트는 계산을 원격 API에만
위임하지 않는 Vite/Vue SPA이며, HTML이 로드하는 `assets/index-57036167.js`, 학생 화면의
`assets/StudentView-6410470d.js`, 스탯 조립 코드가 있는
`assets/StudentListModal-fd52132b.js`에 계산 코드가 포함되어 있다. 배포 번들의 누적기는
다음 순서를 사용한다.

1. 레벨·성급으로 학생 기본값을 네 자리 소수 보간 및 반올림한다.
2. 전용무기·인연·능력 개방·장비의 `Base`를 multiplier-eligible flat으로 합산한다.
3. 장비의 `Coefficient`를 `amount / 10000`으로 누적한다.
4. `round((base + Base) * Coefficient) + BaseOuter`로 최종값을 만든다.

현재 번들의 능력 개방 값은 `round(해당 레벨의 성급 미적용 보간 스탯 × 개방 레벨 ×
0.002)`이며 레벨 90·5성 이상에서 활성화된다. 기본 정보 조립 경로는 패시브 효과를 별도
옵션으로 유지하므로 게임 기본 정보 교차 검증에서는 `include_skill_buffs=false`가 맞다.
라이브 asset hash는 새 배포에서 바뀔 수 있으므로 URL은 조사 증거이며, parity fixture와
위 수식이 지속 계약이다.

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
- 후속 D0~D5에서 학생 레벨과 전용무기 레벨의 실캡처/출처 불명 digit bank를 필드별
  합성 위치 bank로 교체한다. 합성 bank가 승격되기 전까지 기존 S2 reader는 기준선이다.

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
- 전체 랭크 crop matcher만으로 미관측 숫자를 가장 가까운 기지 랭크에 강제하지 않는다.
  하트 중앙의 숫자 영역을 별도 ROI로 좁히고 navy/저채도 숫자 ink를 자리별로 분리한다.
- 현재 실캡처 파생 digit/whole-rank 경로는 D0 기준선과 D3 shadow 비교에만 유지한다.
  필드별 renderer spec으로 만든 합성 위치 bank의 score와 runner-up margin이 충분할 때만
  D4에서 자리별 결과를 production으로 승격한다.
- 현재 답지의 8과 9 표본 부족은 합성 self-test로 해소되었다고 간주하지 않는다. 가능한
  exact 1280x720 숫자 중심 crop을 추가 확보하고, D5 이후에는 불확실한 결과를 legacy
  whole-rank로 숨겨 확정하지 않고 review로 보낸다.
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
- 학생 레벨·전용무기 레벨·인연 랭크는 고정 renderer spec에서 재현 가능한 합성 위치 bank를
  사용하고, 실캡처 파생 runtime digit asset과 출처 불명 weapon glyph가 제거되어 있다.
- Python 전체 test, Flutter 전체 test, `flutter analyze`, 실제 process E2E, Windows release와
  시각 검토를 통과한다.
- recognition asset과 runtime UI asset은 계속 분리된다.
