---
title: "Inventory Scan Flow"
summary: "프로필 준비, 그리드 인식, 상세 fallback, 스크롤 겹침 보정, 종료 판정으로 이어지는 인벤토리 스캔 흐름입니다."
topics: [scanning, architecture]
sources:
  - id: scan-algorithm
    type: file
    path: docs/inventory_scan_algorithm.md
  - id: sorting-contract
    type: file
    path: docs/inventory_sorting.md
  - id: scanner-engine
    type: file
    path: core/scanner.py
  - id: grid-matcher
    type: file
    path: core/inventory_grid_matcher.py
  - id: slot-count
    type: file
    path: core/inventory_slot_count_matcher.py
---

# Inventory Scan Flow

아이템과 장비 스캔은 공통 그리드 엔진을 사용하지만, 프로필별 필터·정렬·템플릿·종료
조건이 다릅니다. 프로필 순서는 단순 표시 순서가 아니라 누락 항목 복구와 후보 제한에
사용되는 계약입니다. [@scan-algorithm] [@sorting-contract]

각 페이지에서는 그리드 템플릿과 수량 글리프를 먼저 판독합니다. 점수와 margin이
충분한 빠른 경로만 상세 화면을 생략할 수 있습니다. 그렇지 않으면 슬롯을 열어 상세
아이콘·이름·수량으로 다시 검증합니다. [@grid-matcher] [@slot-count]

스크롤 뒤에는 이전·현재 캡처의 움직임과 겹침 행을 계산해 새 슬롯만 읽습니다.
near-zero 이동, 불확실한 겹침, 마지막 빈 슬롯은 서로 다른 종료 신호입니다. 하나의
점수만으로 모두 종료시키면 중복 수집이나 마지막 행 누락이 생길 수 있습니다.
[@scanner-engine]

## 불변식

- 정렬·필터가 확인되기 전에는 프로필 순서를 신뢰하지 않습니다.
- 낮은 신뢰도 아이콘과 수량을 결합해 높은 신뢰도처럼 취급하지 않습니다.
- 겹침 추정이 불확실하면 보수적인 전체 페이지 경로를 유지합니다.
- 이미 확인한 anchor와 zero-fill보다 강한 새 증거만 기존 항목을 교체합니다.
- 템플릿, ROI, threshold 변경은 해당 이미지 fixture와 스크롤 회귀 테스트를 함께
  갱신합니다.
- 사용자 검토에서 확정한 상세 crop은 계정 프로필 루트 아래에 실제 캡처 해상도별로
  누적합니다. 같은 계정·같은 해상도에서만 다시 후보로 사용하며, 배포 기본 에셋은 항상
  fallback 후보로 유지합니다. 자동 판정만으로 답지 샘플을 생성하지 않습니다.

`core/scanner.py`에서 이 흐름을 분리할 때는
[Large Module Change Safety](../gotchas/large-module-change-safety)의 호출자·상태 소유권
확인 절차를 먼저 수행합니다.
