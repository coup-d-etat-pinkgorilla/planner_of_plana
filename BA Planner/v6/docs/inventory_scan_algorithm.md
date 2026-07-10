# 아이템/장비 스캔 알고리즘

이 문서는 현재 아이템 및 장비 인벤토리 스캔 흐름을 Mermaid 다이어그램으로 정리한다.
코드 기준 진입점은 `main.py`의 `_run_scan_task()`, 실제 스캔 엔진은
`core/scanner.py`의 `scan_items()`, `scan_equipment()`, `_scan_grid()`이다.

## 전체 호출 흐름

```mermaid
flowchart TD
    A["사용자 스캔 요청<br/>main._request_scan(mode)"] --> B["스캔 메타 생성<br/>main._scan()"]
    B --> C["Scanner 생성<br/>_build_scanner(meta)"]
    C --> D["백그라운드 스캔 스레드 시작"]
    D --> E{"mode"}

    E -->|"items"| F["scanner.scan_items(profile)"]
    E -->|"equipment"| G["scanner.scan_equipment()"]
    E -->|"all"| H["학생/자원 후<br/>아이템 -> 장비 순서 실행"]

    H --> F
    H --> G

    F --> I["공통 그리드 스캔<br/>_scan_grid('item')"]
    G --> J["공통 그리드 스캔<br/>_scan_grid('equipment')"]

    I --> K["ScanResult.items"]
    J --> L["ScanResult.equipment"]
    K --> M["검토 필요 항목 판단<br/>_review_and_auto_save()"]
    L --> M
    M --> N["저장 또는 리뷰 다이얼로그"]
```

## 아이템과 장비의 차이

```mermaid
flowchart LR
    subgraph Items["아이템 스캔"]
        I1["scan_items(profile_id)"] --> I2["요청 프로필 정규화<br/>_item_scan_profiles()"]
        I2 --> I3{"프로필별 반복"}
        I3 --> I4["아이템 인벤토리 진입"]
        I4 --> I5["필터 초기화 및 선택<br/>tech_notes, tactical_bd,<br/>ooparts, presents 등"]
        I5 --> I6["정렬 규칙 확인"]
        I6 --> I7["_scan_grid('item')"]
    end

    subgraph Equip["장비 스캔"]
        E1["scan_equipment()"] --> E2["forced profile = equipment"]
        E2 --> E3["장비 인벤토리 진입"]
        E3 --> E4["장비 정렬 규칙 확인"]
        E4 --> E5["_scan_grid('equipment')"]
    end
```

아이템은 선택한 프로필을 여러 번 순회할 수 있다. 예를 들어 전체 스캔에서는
`tech_notes`, `tactical_bd`, `ooparts`, `presents`, `activity_reports`,
`student_elephs` 같은 프로필을 각각 준비하고 `_scan_grid()`를 실행한다.

장비는 `equipment` 프로필을 강제로 사용한다. 그래서 공통 그리드 엔진을 쓰지만
장비용 정렬 확인, 장비용 상세 템플릿, 장비용 수량 템플릿이 선택된다.

## 인벤토리 준비 단계

```mermaid
flowchart TD
    A["스캔 시작"] --> B{"현재 인벤토리 화면에서<br/>직접 스캔인가?"}
    B -->|"아니오"| C["메뉴 열기"]
    C --> D["아이템/장비 메뉴로 이동"]
    B -->|"예"| E["현재 화면 재사용"]
    D --> F["필터 패널 열기"]
    E --> F

    F --> G{"source"}
    G -->|"item"| H["필터 탭 클릭"]
    H --> I["필터 초기화"]
    I --> J{"profile_id별 필터 버튼"}
    J -->|"student_elephs"| J1["eleph_filter"]
    J -->|"tech_notes"| J2["note_filter"]
    J -->|"tactical_bd"| J3["bd_filter"]
    J -->|"ooparts / presents"| J4["ooparts_filter"]
    J -->|"activity_reports"| J5["reports_filter"]
    J -->|"all"| J6["필터 선택 없음"]
    J1 --> K["정렬 탭 클릭"]
    J2 --> K
    J3 --> K
    J4 --> K
    J5 --> K
    J6 --> K
    K --> L["정렬 규칙 이미지 매칭"]

    G -->|"equipment"| M["장비 정렬 규칙 이미지 매칭"]

    L --> N["확인 버튼 클릭"]
    M --> N
    N --> O["_reset_inventory_scan_state(source)"]
```

## 공통 그리드 스캔 루프

```mermaid
flowchart TD
    A["_scan_grid(section, source)"] --> B["ROI와 슬롯 목록 로드<br/>regions/item_regions.json 또는 equipment_regions.json"]
    B --> C["윈도우 rect 확인"]
    C --> D["프로필/템플릿/캐시 초기화"]
    D --> E["입력 백엔드 결정<br/>legacy drag 또는 focus navigation"]
    E --> F["스크롤 페이지 루프<br/>MAX_SCROLLS"]

    F --> G["화면 캡처"]
    G --> H["현재 y offset 반영 슬롯 계산"]
    H --> I["그리드 crop 해시 생성"]
    I --> J{"최근 본 그리드 해시인가?"}
    J -->|"예"| Z["중복 페이지로 판단하고 종료"]
    J -->|"아니오"| K["페이지 슬롯 스냅샷 생성"]

    K --> L["스캔할 슬롯 순서 계산<br/>row anchor 우선 또는 순차"]
    L --> M["슬롯 루프"]
    M --> N["슬롯 인식 및 수량 판독"]
    N --> O{"검증 성공?"}
    O -->|"아니오"| M
    O -->|"예"| P["ItemEntry 생성"]
    P --> Q{"이미 본 key인가?"}
    Q -->|"아니오"| R["items에 추가<br/>progress status 기록"]
    Q -->|"예, 기존 zero-fill보다 좋음"| S["zero-fill 항목 교체"]
    Q -->|"예"| M
    R --> M
    S --> M

    M --> T["페이지 프로필 추론/완료 판단"]
    T --> U{"프로필 완료, terminal 도달,<br/>limit 도달, stop 요청?"}
    U -->|"예"| V["루프 종료"]
    U -->|"아니오"| W["다음 페이지로 이동"]
    W --> X{"스크롤 성공 및<br/>drift 안전?"}
    X -->|"아니오"| V
    X -->|"예"| Y["겹침 행으로 다음 슬롯 범위 계산"]
    Y --> F

    V --> AA["프로필 gap zero-fill 및 정렬"]
    Z --> AA
    AA --> AB["items 반환"]
```

## 슬롯 하나를 판독하는 절차

```mermaid
flowchart TD
    A["슬롯 crop"] --> B["아이콘 템플릿 매칭<br/>_match_inventory_icon()"]
    B --> C{"grid matcher 활성화?"}

    C -->|"예"| D["슬롯 전체 템플릿 매칭<br/>match_inventory_grid_template()"]
    D --> E["티어 색상 힌트 탐지<br/>detect_inventory_grid_tier_hint()"]
    E --> F["프로필 row anchor / order hint 적용"]
    F --> G["슬롯 수량 판독<br/>read_item_slot_count()"]
    G --> H{"빠른 그리드 확정 조건 통과?"}

    H -->|"예"| I["상세 화면 열지 않음<br/>InventoryVerification 생성"]
    H -->|"아니오"| J["상세 화면 검증 필요"]
    C -->|"아니오"| J

    J --> K["슬롯 클릭 또는 입력 백엔드 confirm"]
    K --> L["상세 화면 캡처"]
    L --> M{"source/profile"}
    M -->|"equipment 또는 equipment profile"| N["장비 상세 수량 판독<br/>read_equipment_count_from_detail()"]
    M -->|"item"| O["아이템 상세 수량 판독<br/>read_item_count_from_detail()"]
    N --> P{"수량 성공?"}
    O --> P
    P -->|"아니오"| Q["슬롯 skip"]
    P -->|"예"| R{"profile_id 있음?"}
    R -->|"예"| S["상세 아이콘+이름 템플릿 매칭<br/>_match_inventory_detail_crop()"]
    R -->|"아니오"| T["상세 템플릿 fallback 불가<br/>skip"]
    S --> U{"item_id 확정?"}
    U -->|"아니오"| Q
    U -->|"예"| V["검증 결과 반환"]
    I --> V
```

빠른 경로는 `grid_template_score`, `margin`, `count_confidence`가 기준 이상일 때
상세 화면을 열지 않고 확정한다. 기준에 못 미치면 같은 슬롯을 열어 상세 화면에서
수량과 상세 템플릿을 다시 확인한다.

그리드 후보 생성은 프로필별 정책을 사용한다. 활동 보고서는 배경 티어로 후보를 한
개로 제한하고, 기술 노트와 전술 BD는 티어를 먼저 고른 뒤 각각의 학교 문양 ROI를
비교한다. 선물은 노랑/보라 희귀도 배경으로 후보를 나눈 뒤 전용 object ROI를
사용하며, 엘레프는 배경 티어 없이 얼굴과 외형 ROI를 결합한다. 오파츠는 티어별
가족 후보와 노란 배경의 워크북 3종 후보를 별도 branch로 평가한다.

## 프로필과 순서 힌트

```mermaid
flowchart TD
    A["활성 프로필"] --> B["ordered_item_ids / ordered_names"]
    B --> C["profile_cursor"]
    B --> D["row anchor state"]

    C --> E["다음 기대 아이템 계산"]
    E --> F["현재 grid best와 관계 비교"]
    F --> G{"관계"}
    G -->|"exact"| H["낮은 위험<br/>expected item 허용"]
    G -->|"same_family"| I["같은 학교/같은 계열<br/>점수 기준 통과 시 허용"]
    G -->|"workbook_tail"| J["ooparts workbook tail 보정"]
    G -->|"없음"| K["일반 grid 결과 사용"]

    D --> L["확정 슬롯을 row anchor로 기록"]
    L --> M["같은 행 후보 범위 축소"]
    M --> N["중간 gap은 zero-fill 후보"]

    H --> O["assigned_profile_idx 확정"]
    I --> O
    J --> O
    K --> O
    O --> P{"profile_cursor보다 뒤인가?"}
    P -->|"예"| Q["누락 구간 zero-fill<br/>단, 처리 전 슬롯이 있으면 defer"]
    P -->|"아니오"| R["현재 entry 확정"]
    Q --> R
```

프로필 기반 스캔은 게임 인벤토리가 보유 수량 0인 항목을 표시하지 않는 점을 이용한다.
정렬 순서가 보장되는 프로필에서 뒤쪽 항목이 확정되면, 그 사이에 비어 있는 항목은
`quantity = "0"`인 `zero_filled` 항목으로 보강할 수 있다.

## 스크롤과 drift 방지

```mermaid
flowchart TD
    A["현재 페이지 처리 완료"] --> B{"입력 백엔드 사용?"}
    B -->|"focus navigation"| C["_advance_inventory_page_with_input()"]
    B -->|"legacy drag"| D["_scroll_inventory_page()"]

    D --> E["스크롤 전 캡처 및 슬롯 해시"]
    E --> F["drag_scroll() 시도<br/>기본량 -> retry량"]
    F --> G["스크롤 후 캡처"]
    G --> H["이미지 유사도, 그리드 해시,<br/>슬롯 해시 배열 비교"]
    H --> I{"이동했나?"}
    I -->|"아니오"| J["마지막 페이지로 판단"]
    I -->|"예"| K["motion 추정<br/>_estimate_inventory_scroll_motion()"]
    K --> L["겹침 행 계산<br/>_inventory_overlap_rows_from_motion()"]
    L --> M{"겹침 행 확인됨?"}
    M -->|"아니오"| N["drift 위험으로 중단<br/>profile tail zero-fill 비활성"]
    M -->|"예"| O["다음 스캔 슬롯 계산<br/>_new_inventory_slot_indices()"]
    O --> P["다음 루프에서 새 행 위주 스캔"]

    C --> Q["이동 후 슬롯 해시 비교"]
    Q --> R["겹침 행 계산"]
    R --> O
```

스크롤 후 겹침 행이 없으면 사용자 조작, 튐, 드래그 drift 가능성이 있다고 보고
스캔을 멈춘다. 이 경우 프로필의 남은 꼬리 항목을 0으로 채우지 않는다.

## 종료 조건

```mermaid
flowchart TD
    A["페이지 처리 후"] --> B{"stop 요청?"}
    B -->|"예"| Z["종료"]
    B -->|"아니오"| C{"프로필 최대 unique 도달?"}
    C -->|"예"| Z
    C -->|"아니오"| D{"프로필 complete?"}
    D -->|"예"| Z
    D -->|"아니오"| E{"terminal item 확인?"}
    E -->|"예"| Z
    E -->|"아니오"| F{"스크롤 불가 또는 마지막 행 반복?"}
    F -->|"예"| Z
    F -->|"아니오"| G["다음 페이지 계속"]
```

## 주요 데이터와 결과

| 항목 | 위치 | 역할 |
| --- | --- | --- |
| `ItemEntry` | `core/scanner.py` | 스캔 결과 한 줄. `name`, `quantity`, `item_id`, `source`, `scan_meta`를 보유한다. |
| `InventoryScanProfile` | `core/inventory_profiles.py` | 프로필별 정렬 순서, 예상 item_id, terminal item을 정의한다. |
| `InventoryGridRowAnchorState` | `core/inventory_grid_matcher.py` | 확정된 슬롯과 프로필 인덱스를 이용해 같은 행 후보를 좁힌다. |
| `InventoryVerification` | `core/scanner.py` | 빠른 그리드 경로 또는 상세 화면 검증 결과를 담는다. |
| `scan_meta` | `main.py`, `core/scanner.py` | 필터, 직접 인벤토리 스캔 여부, 디버그 로그 경로 등 실행 메타데이터를 전달한다. |

`scan_meta` 안의 `detect_source`는 결과가 어떤 경로로 확정되었는지 알려준다.
대표 값은 `grid_template(...)`, `detail_image_template+detail(...)`,
`icon_template+detail(...)`, `detail_template`이다.

## 관련 코드 지도

| 흐름 | 함수 |
| --- | --- |
| UI 요청 및 스레드 실행 | `main._request_scan()`, `main._scan()`, `main._run_scan_task()` |
| 아이템 진입점 | `Scanner.scan_items()` |
| 장비 진입점 | `Scanner.scan_equipment()` |
| 필터/정렬 준비 | `Scanner._prepare_item_inventory()`, `Scanner._prepare_equipment_inventory()` |
| 공통 그리드 엔진 | `Scanner._scan_grid()` |
| 빠른 슬롯 매칭 | `match_inventory_grid_template()`, `read_item_slot_count()` |
| 상세 화면 검증 | `Scanner._verify_inventory_slot()` |
| 상세 템플릿 매칭 | `Scanner._match_inventory_detail_crop()` |
| 스크롤 및 겹침 계산 | `Scanner._scroll_inventory_page()`, `_new_inventory_slot_indices()` |
| 프로필 추론/완료 | `infer_inventory_scan_profile()`, `is_inventory_profile_complete()`, `is_inventory_profile_terminal_seen()` |
