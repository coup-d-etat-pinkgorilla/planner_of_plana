# S3B input — 장비 기본 화면 binary matcher 보강

## 선행 조건과 범위

S3 master-accepted snapshot에서만 시작한다. S3의 empty/locked/family/tier 판독, 작은 ROI
generated matcher, unresolved-only 단일 장비-menu fallback과 애용품 판독은 안전망으로
보존한다. S4 인연 OCR, 스탯 mismatch evidence, Flutter 검토 UI와 protocol 확장은 제외한다.

## 확인된 탐색 근거

- 재고 그리드의 고정색 `#2D4663`, 고정 슬롯 좌표와 재고 숫자 템플릿을 Mika 기본 장비
  `Lv.70` 셀에 그대로 적용하면 셀당 0~5픽셀만 검출되고 IoU는 사실상 0이므로 직접 재사용은
  부적합하다.
- 장비 전용 adaptive dark-ink mask는 같은 셀에서 364~430픽셀과 20x28 normalized glyph를
  만든다.
- 위 glyph를 기존 장비-menu 슬롯·자리별 binary digit mask와 그리드식 IoU로 비교한 탐색
  실험은 Mika/Hibiki 6개 실제 프레임, 36개 `7`/`0` 셀에서 top-1 36/36을 기록했다. score는
  0.459459~0.631818, 2위 margin은 0.054173~0.080536이었다.
- 이 결과는 digit 7/0, T10/Lv70, 1280x720/100% UI scale만 포함하므로 production threshold나
  전체 숫자 정확도를 확정하는 근거가 아니다.

## 목표

그리드 수량 판독의 유효한 개념만 장비 전용 pure-Pillow binary matcher로 분리해 기본 화면
레벨 fallback률을 낮춘다. 오판독 값을 늘리거나 기존 menu fallback을 제거해서는 안 된다.

## 구현 계약

1. 기존 48x36 장비 레벨 ROI를 유지한다. 장비-menu baseline은 두 자리 셀 분할을 유지하지만,
   생성형 glyph 경로는 전체 level string을 먼저 판독해 실제 한 자리 숫자를 반으로 자르지 않는다.
2. 장비 전용 adaptive dark-ink mask를 20x28 canonical glyph로 trim/normalize한다.
3. 장비-menu digit asset을 슬롯·자리·label별 baseline으로 유지한다. 추가 생성형 경로는 v7
   renderer의 transparent text layer에서 background/icon을 제외한 outline/fill+outline/fill
   whole-string template를 비교하며 production runtime에는 승인된 variant만 bounded하게 준비한다.
4. IoU와 normalized correlation을 함께 기록하고 최고 score와 2위 margin으로 판정한다.
5. 정위치 비교를 먼저 수행하고 불확정일 때만 작은 +/-1px 이동을 시도한다.
6. 실제 한 자리 레벨은 전체 ROI foreground로 검증한다. 합성 두 번째 blank만으로 실제 blank
   coverage를 주장하지 않으며 T1~T10 최대 레벨 규칙을 함께 검증한다.
7. 실행 순서는 `empty/locked -> family/tier -> binary -> small-ROI generated -> one-menu`
   로 한다. 앞 단계가 확정한 슬롯은 뒤 단계가 다시 읽지 않는다.
8. binary 결과가 불확실하면 값을 만들지 않고 기존 generated/menu 경로로 넘긴다.
9. v6 inventory matcher, OpenCV/numpy, 6자리 좌표, `x`/`k` suffix, 고정 재고 RGB와 재고용
   threshold/confusion 보정을 통째로 가져오지 않는다.
10. runtime template와 원본 screenshot dataset은 계속 분리하고 cache는 bounded하게 유지한다.

## 데이터와 평가 계약

- 현재 Mika/Hibiki Lv70 자료는 smoke/shadow fixture로만 사용한다.
- production 승격 전 가능한 실제 장비 레벨에서 0~9와 한 자리 blank를 포함하고, 각 관측
  조건은 2~3개의 안정 반복을 확보한다. 슬롯·family·tier·해상도 차이도 metadata에 기록한다.
- menu 판독 또는 육안 답지를 ground truth로 사용한다. 같은 프레임에서 만든 template로 같은
  프레임을 평가하는 leakage는 금지한다.
- coverage가 불충분하면 matcher는 shadow evidence만 생성하고 candidate value를 확정하지
  않는다. threshold, ROI, confusion pair는 `MASTER_REQUIRED`로 남긴다.
- 기존 generated matcher, binary matcher, binary+generated, 최종 menu 결과를 동일 답지에서
  비교한다.

## 수용 조건

- 실캡처 평가에서 committed false positive가 0이다.
- 현재 Mika/Hibiki Lv70 6프레임/36셀 결과가 유지되고, level 세 쌍이 모두 70으로 결합된다.
- 확보된 전체 숫자/blank coverage에서 슬롯·자리·digit confusion matrix와 정확/오판독/
  fallback률을 기록한다.
- binary 도입 전후 실제 기본 화면 fallback률 감소량과 최종 menu 호출 횟수를 기록한다.
- cold, warm p50/p95, template prepare, shift retry, cache hit/miss, peak bytes를 기록하며 S3의
  full-size candidate canvas 0과 bounded cache 조건을 유지한다.
- low score/margin, template/feature 누락, 잘못된 tier-level 조합은 모두 기존 fallback으로
  안전하게 내려간다.
- focused S2/S3/S3B/production/asset tests와 가능한 전체 backend tests를 실행하고 기존 범위 밖
  baseline 실패는 별도로 구분한다.

## 인계

`slave-artifact-handoff.md` 계약에 따라 input과 같은 디렉터리의 별도 S3B handoff 폴더에
`output.md`, patch, benchmark 원자료, 실캡처 답지, confusion matrix와 verification을 저장한다.
S3B master acceptance 전에는 S4를 시작하지 않는다.
