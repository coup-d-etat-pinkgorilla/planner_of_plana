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
| `tools/` | 메타데이터 동기화, 템플릿 제작, 디버깅, 릴리스 도구 |
| `tests/` | 인식·스캔·저장·계산 회귀 테스트 |
| `regions/` | 해상도 비율 기반 ROI와 클릭 좌표 |
| `templates/` | 이미지 인식 템플릿과 표시용 에셋 |
| `data/planning/` | 성장 비용 기준표 |
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
- `docs/design/imagegen-brief.md`: UI 목업 이미지 생성을 위한 화면·정보·시각 방향 브리프
- `docs/REPOSITORY_POLICY.md`: 공개 릴리스 저장소와 로컬 데이터 정책
- `docs/LOCAL_UPDATE_WORKFLOW.md`: 앱·에셋 업데이트 절차
- `docs/BETA_TESTING.md`: 베타 패키징과 테스트 체크리스트
- `tools/TEMPLATE_ALIGNMENT_STUDIO.md`: 템플릿·ROI 조정 도구
- `tools/INVENTORY_GRID_MATCH_INSPECTOR.md`: 저장 캡처 기반 그리드 ROI·합성 템플릿 비교 도구

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
