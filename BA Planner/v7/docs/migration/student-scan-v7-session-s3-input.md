# S3 input — 장비·애용품 스캔 최적화

## 선행 조건

S2 accepted snapshot에서만 시작한다.

## 목표

v6 장비 스캔의 사용자 동작을 보존하면서 후보 레벨마다 2560x1440 합성 canvas를 만드는
성능 병목과 warm 판독의 반복 feature 계산을 제거한다. 첨부된 과거 조사 프롬프트는 구현
명령이 아니라 재현해야 할 가설과 측정 기준선이다.

## 확인된 v6 기준선

- 과거 측정: T10 cold 약 0.9~1.05초, 동일 조합 warm 약 52ms. S3 시작 시 accepted
  snapshot과 고정 fixture에서 profiler로 재현한다.
- cold miss는 레벨마다 파일 open, 카드·폰트 합성, 2560x1440 canvas, warp, 셀 분리와
  feature 계산을 반복한다.
- warm 비교도 각 RGB 후보의 gray/percentile 정규화와 edge plane을 다시 계산한다.
- 유효 family-slot은 9개이며 family 하나의 T1~T10 유효 레벨 합은 445개다. 4,005개 카드와
  8,010개 셀을 개별 PNG로 배포하는 안은 파일 open/decode 비용을 측정하기 전 채택하지 않는다.

## v6 참조 경계

동작 참조는 `../v6/core/scanner_components/student.py`의 `read_equipment()`과
`_read_basic_equipment_slot()`, `../v6/core/matcher.py`의 basic-equipment 함수들이다.
전처리 비교는 `../v6/core/inventory_slot_count_matcher.py`의 prepared mask 흐름만 대상으로
한다. `../v6`를 import하거나 파일을 통째로 복사하지 않으며, 대형 matcher에 다시 집중시키지
말고 v7 전용 작은 모듈과 versioned recognition 계약으로 분리한다.

회귀 의미는 v6의 `test_basic_equipment_generated_level.py`,
`test_basic_equipment_empty_dot.py`, `test_equipment_tier_inference.py`,
`test_weapon_scan_corrections.py`를 먼저 확인하고 v7 fixture로 재작성한다.

## 구현 순서

1. 현 생성 경로를 세분화한 cold/warm benchmark와 profiler fixture를 만든다.
2. 학생 레벨 기반 locked slot, empty-dot, family 제한, icon tier 판독을 보존한다.
3. 카드·폰트 cache와 전체 화면이 아닌 작은 card/ROI 직접 합성으로 무위험 반복 비용을 줄인다.
4. 다음 네 방식을 같은 답지에서 비교한다.
   - v6 생성 RGB matcher의 offline 기준 결과
   - 사전 준비 RGB/gray/edge feature bundle
   - 실캡처 navy/dark-ink 정규화 binary glyph matcher
   - 실캡처 우선 + 작은 ROI 생성형 fallback
5. 실캡처 matcher에는 작은 위치 이동, score와 2위 margin, 숫자별 confusion matrix를 적용한다.
   인벤토리 수량 OCR 전체를 재사용하지 말고 필요한 전처리 개념만 분리한다.
6. 정확도·시작 시간·RAM·설치 용량을 비교한 후에만 PNG/NPZ/atlas/묶음 형식을 선택한다.
7. 확정 실패 슬롯만 한 번의 장비-menu capture로 fallback한다.
8. 애용품 empty/locked/T1/T2를 판독한다.

## 실캡처 데이터셋 계약

원본 전체 화면을 보존하고 crop/feature는 versioned region으로 재생성한다. 데이터셋은 runtime
UI asset 및 배포 recognition template와 분리한다.

`{source_width}x{source_height}/slot{1|2|3}/{family}/T{tier}/level_{level}/` 아래에
`full_screen.png`와 `metadata.json`을 둔다. metadata는 slot, family, tier, level, client
해상도, UI scale·에뮬레이터, 캡처 시각, ROI 버전, 안정 프레임 여부, 반복 sample 번호를
포함한다. 가능하면 같은 조건을 2~3회 캡처한다.

## 성능 완료 조건

- 후보 레벨당 full-size reference canvas를 만들지 않는다.
- cold 시작/첫 판독, 학생당 warm p50/p95, template load, feature prepare 시간을 기록한다.
- 정확/오판독/fallback률 및 슬롯·티어·숫자별 confusion matrix를 기록한다.
- cache miss, 생성·로드 횟수, peak/transient RAM과 설치 파일 증가량을 기록한다.
- cache는 bounded하고 session이 끝난 뒤 불필요한 full capture를 보유하지 않는다.
- cold/warm 결과 동일, T1~T10 경계, 한 자리+blank, 잘못된 tier-level 거부를 검증한다.
- feature/catalog 누락 시 기존 동작과 동등한 작은 ROI fallback을 유지한다.
- empty, level-locked, unknown, favorite locked 상태 fixture가 있다.
- fallback은 unresolved slot에만 실행된다.

실캡처 답지가 충분하지 않으면 threshold, ROI, 혼동쌍 보정 또는 기존 fallback 제거를 임의로
확정하지 않는다. 정확도나 배포 저장 형식의 선택이 남으면 결과표와 권고안을 제출하고
`MASTER_REQUIRED`로 남긴다.

## 제외

- 인연 OCR과 계산 mismatch evidence
- Flutter review UI
- v6 matcher 파일의 통째 복사 또는 runtime import

## 인계 계약

`output.md`와 artifacts에 patch, benchmark 원자료, fixture, verification을 포함한다. Flutter가
필요한 후속 검증은 `MASTER_REQUIRED`로 명시한다.
