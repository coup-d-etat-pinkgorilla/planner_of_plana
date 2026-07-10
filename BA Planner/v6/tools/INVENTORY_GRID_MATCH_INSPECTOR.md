# Inventory Grid Match Inspector

저장된 아이템·장비 스크롤 캡처에서 생산 그리드 matcher가 실제로 비교하는
screen ROI와 합성 템플릿을 나란히 확인하는 오프라인 PySide6 도구입니다. 게임
창을 찾거나 새 화면을 캡처하지 않습니다.

## 실행

프로젝트 루트에서 실행합니다.

```powershell
python -m tools.inventory_grid_match_inspector
```

또는 다음 배치 파일을 실행합니다.

```powershell
run_inventory_grid_match_inspector.bat
```

다른 캡처 루트를 열려면:

```powershell
python -m tools.inventory_grid_match_inspector --capture-root "C:\path\to\item_equip_scroll_debugger"
```

기존 스크롤 캡처 레이아웃도 지원합니다. 오파츠 캡처 묶음을 열 때는 다음처럼 실행합니다.

```powershell
python -m tools.inventory_grid_match_inspector --capture-root "debug\inventory_scroll_scan"
```

로더는 `item/<profile>/captures/scroll_*`와
`*_item_<profile>/scroll_*` 디렉터리 형태를 모두 인식합니다.

기본 입력은 `debug/item_equip_scroll_debugger/` 아래의 `summary.json`,
`before_capture.png`, `after_capture.png`입니다. `summary.json`의 before/after
y-offset을 각각 적용한 뒤 `regions/item_regions.json` 또는
`regions/equipment_regions.json`의 슬롯을 crop합니다.

## 슬롯 비교

각 행은 다음 이미지를 표시합니다.

- y-offset이 적용된 원본 슬롯과 ROI 경계
- 생산 matcher에 전달되는 최종 screen ROI
- 후보 드롭다운에서 선택한 아이템의 최종 합성 템플릿
- 두 최종 이미지의 absolute difference
- 생산 색상 검색이 선택한 sample patch

후보를 변경하면 생산 matcher와 동일한 NCC·픽셀 차이 결합 점수를 다시
계산합니다. `최고 후보 계산`은 해당 슬롯에 한해 프로필 후보 전체를 계산해
드롭다운을 점수순으로 바꿉니다.

`Production auto`, `Composite`, `Direct icon` 경로를 전환할 수 있습니다.
`Production auto`가 기본이며 현재 유효 설정에 따라 생산 경로를 선택합니다.

생산 매칭은 합성 템플릿을 캡처 슬롯 크기로 직접 렌더링합니다. 즉 304x240 원본
아이콘을 슬롯 크기로 다운스케일하며, 캡처 ROI를 업스케일하지 않습니다. GUI의 확대
표시는 미리보기일 뿐 생산 매칭 방향을 바꾸지 않습니다.

## ROI와 색상 실험

오른쪽 패널에서 composite crop의 left/right/top/bottom을 기준 슬롯
`234x190` 픽셀 단위로 조정할 수 있습니다.

색상 패널에서는 다음 값을 조정할 수 있습니다.

- sample X/Y/width/height
- search X/Y/width/height
- search stride
- 색상 판정 활성화
- production search 또는 fixed sample

방향 버튼은 1픽셀씩 이동합니다. 원본 슬롯 이미지를 클릭하거나 드래그하면
sample box 중심이 해당 위치로 이동합니다. 현재 목록 전체의 인식 수, unknown
수, 최악 팔레트 거리, 최소 margin과 최악 슬롯이 함께 갱신됩니다.

## Production과 Experiment

도구 시작 시 저장소의 생산 설정을 사용합니다. ROI 또는 색상 영역을 바꾸면
화면의 `Experiment` 점수만 바뀌고 `Production` 기준 점수는 유지됩니다.

`세션 저장`은 실험값과 슬롯별 선택 후보를 JSON으로 저장합니다. 기본 권장
위치는 다음과 같습니다.

```text
debug/item_equip_scroll_debugger/inspector_sessions/
```

도구는 `regions/*.json`을 자동 수정하지 않습니다. 검증된 실험값만 별도의
소스 변경으로 반영해야 합니다.
