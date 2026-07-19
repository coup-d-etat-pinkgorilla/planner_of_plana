# BA Planner

BA Planner는 Blue Archive의 학생 성장 상태와 인벤토리를 Windows 화면에서 스캔하고,
성장 목표와 필요한 재화를 계산하는 데스크톱 도구입니다. 메인 제어 화면은 Tkinter,
학생·플랜·인벤토리 뷰어는 PySide6를 사용합니다.

## 실행

권장 애플리케이션 런타임은 Python 3.11입니다.

```powershell
py -3.11 -m pip install -r requirements.txt
py -3.11 main.py
```

Windows에서는 `run_main.bat`로도 실행할 수 있습니다. 뷰어만 실행하려면:

```powershell
py -3.11 student_viewer.py
```

UI 컴포넌트 디자인 도구는 기본적으로 Qt Quick 고정 논리 캔버스에서 디자인 JSON만
읽습니다. 실제 Viewer QWidget 트리는 만들지 않으며, 섹션 미리보기에는 데이터 로드를 끈
Qt Quick `Main.qml`을 생성해 선택 섹션의 실제 자식 트리와 1920×1080 좌표를 재사용합니다.

```powershell
py -3.11 -m tools.ui_component_studio_quick
# 또는 더블클릭
run_ui_component_studio.bat
```

기존 QWidget 스냅샷·상태 머신 감사 Studio는 호환 명령
`py -3.11 -m tools.ui_component_studio`로 유지됩니다.

Qt Quick 기반의 고정 논리 캔버스 뷰어가 기본 Viewer입니다.
실제 프로필 인벤토리를 가상 목록으로 표시하며, 창 크기 변경 시 화면 객체를 재생성하지
않습니다.

```powershell
py -3.11 -m gui.quick_app
# 전체 main 기본 진입 경로
py -3.11 main.py
# 고급 호환 기능용 기존 QWidget Viewer
py -3.11 main.py --legacy-ui
```

기존 Tk 제어 화면에서 Viewer를 여는 경로도 새 화면을 기본으로 사용합니다. 해당 경로에서
기존 QWidget Viewer를 강제로 사용하려면 `BA_PLANNER_LEGACY_UI=1`을 설정합니다.

## 테스트

```powershell
py -3.11 -m unittest discover -s tests -v
```

Cloudflare bug report Worker:

```powershell
cd bug-report-worker
npm test
```

실제 게임 창 입력, 화면 캡처, GPU OCR, 가상 게임패드가 필요한 동작은 단위 테스트와
별도로 Windows 환경에서 확인해야 합니다.

## 코드 지도

| 경로 | 책임 |
| --- | --- |
| `main.py` | Tk 제어 앱, 스캔 상태 전이, 검토·저장 흐름 |
| `core/` | 캡처, 입력, 인식, 스캔, 저장, 플래너 계산 |
| `gui/` | PySide6 뷰어와 Tk 보조 창 |
| `gui/quick/` | Qt Quick 고정 논리 캔버스, 가상 목록 모델과 QML 페이지 |
| `tools/` | 메타데이터 동기화, 템플릿 제작, 디버깅, 릴리스 도구 |
| `tests/` | 인식·스캔·저장·계산 회귀 테스트 |
| `regions/` | 해상도 비율 기반 ROI와 클릭 좌표 |
| `templates/` | 이미지 인식 템플릿과 표시용 에셋 |
| `data/planning/` | 성장 비용 기준표 |
| `prototypes/flutter_flicker_probe/` | Flutter Windows Adaptive-Sync Phase 0 검증 앱 |
| `bug-report-worker/` | 독립 Cloudflare Workers 서비스 |

호환 진입점은 `gui/viewer_app_qt.py`, `core/scanner.py`, `core/student_meta.py`이며,
실제 구현은 각각 `gui/viewer_components/`, `core/scanner_components/`,
`core/student_meta_data.py`로 분리되어 있습니다. 공용 타입과 helper는
`gui/viewer_shared.py`, `core/scanner_shared.py`, `core/student_meta_types.py`에 둡니다.
`core/matcher.py`도 인식 흐름의 중심 파일이므로 변경 전에 영향 범위를 확인합니다.
작업 규칙과 필독 문서는 `AGENTS.md`에서 확인합니다.

## 문서

- `almanac/`: 설계 의도, 교차 파일 흐름, 불변식, gotcha
- `STUDENT_PLANNER_HANDOFF.md`: 학생 뷰어·플래너·통계의 데이터 계약
- `docs/inventory_scan_algorithm.md`: 아이템·장비 스캔 전체 흐름
- `docs/inventory_sorting.md`: 프로필별 정렬과 순서 계약
- `docs/gui_element_glossary.md`: GUI 표면과 구성요소 명칭
- `docs/design/current-ui-audit.md`: 현재 UI의 사용자 흐름, 정보 계층, 시각·해상도 문제 감사
- `docs/design/ui-scaling.md`: Qt Viewer의 창별 폰트·geometry 배율과 모니터 비율 리사이즈 계약
- `docs/ui-behavior/README.md`: UCS에서 렌더링하는 메인 탭·섹션 간 Mermaid 연결 지도
- `docs/design/imagegen-brief.md`: UI 목업 이미지 생성을 위한 화면·정보·시각 방향 브리프
- `docs/REPOSITORY_POLICY.md`: 공개 릴리스 저장소와 로컬 데이터 정책
- `docs/LOCAL_UPDATE_WORKFLOW.md`: 앱·에셋 업데이트 절차
- `docs/BETA_TESTING.md`: 베타 패키징과 테스트 체크리스트
- `tools/TEMPLATE_ALIGNMENT_STUDIO.md`: 템플릿·ROI 조정 도구
- `tools/INVENTORY_GRID_MATCH_INSPECTOR.md`: 저장 캡처 기반 그리드 ROI·합성 템플릿 비교 도구
- `tools/UI_COMPONENT_STUDIO.md`: 전체 Qt 컴포넌트·팔레트·애니메이션 디자인 도구

- `docs/design/flutter-migration-plan.md`: Flutter 후보 검증, Python 백엔드 분리, UI 재구축과 단계별 전환 계획
- `prototypes/flutter_flicker_probe/README.md`: 실제 홈 PNG와 hover를 사용하는 Flutter flickering 검증 절차

## CodeAlmanac

`almanac/`은 저장소에 커밋하는 수동 관리 위키입니다. 현재 설정에서는 transcript
sync, Garden, 자동 업데이트, 자동 커밋이 모두 비활성화되어 있습니다.

```powershell
codealmanac search "inventory scan"
codealmanac show flows/inventory-scan
codealmanac validate
codealmanac health
```

코드에서 바로 확인 가능한 사실이나 일회성 TODO는 Almanac에 기록하지 않습니다.
새 설계 결정, 장기 불변식, 재발 가능한 장애 교훈이 생겼을 때만 관련 페이지를
갱신합니다.

## 빌드와 배포

PyInstaller와 릴리스 도구는 `requirements-build.txt`,
`docs/BETA_TESTING.md`, `docs/LOCAL_UPDATE_WORKFLOW.md`,
`docs/REPOSITORY_POLICY.md`를 기준으로 사용합니다.

런타임 `profiles/`, DB, 로그, 스캔 결과, `build/`, `dist/`, `release/`는
소스 변경과 분리해 관리합니다.
