# BA Planner v7

BA Planner v7은 Flutter for Windows 프론트엔드와 headless Python 백엔드를
분리해 새로 구축하는 세대입니다. v6의 Qt/QML/QWidget/Tk UI를 복사하지 않고,
검증된 도메인 로직과 데이터 계약만 수직 슬라이스 단위로 이전합니다.

## 현재 상태

- Flutter Windows 렌더러와 실제 홈 PNG hover 검증 화면
- v6 시각 규칙을 Flutter로 재작성한 고정 시드 BA 삼각형 배경
- 고정 ㄴ자 글라스 그림자와 상태 보존형 페이지 섹션 전환
- v6의 80° 사다리꼴 홈 섹션과 가시 간격을 보존하는 평행사변형 메뉴 행
- 계획 목표 모델과 성장 비용 계산
- 학생 정적 메타데이터 lookup API
- v6 계산 결과를 고정한 Python parity fixture
- protocol v1 계약과 Python JSONL process/Dart process client
- mock 기본값을 보존한 `ProcessAppService` 실제 backend 선택 경로

스캐너와 저장소는 아직 이전하지 않았습니다. v6 `repository`가 scanner DTO를
직접 import하고 scanner가 캡처·입력·matcher·상태 callback에 결합되어 있으므로,
DTO와 application service 경계를 먼저 분리한 뒤 옮깁니다.

## 구조

| 경로 | 책임 |
| --- | --- |
| `frontend/` | Flutter Windows UI와 UI 전용 asset |
| `backend/` | UI 프레임워크에 의존하지 않는 Python 로직 |
| `contracts/` | Flutter/Python 공용 IPC envelope와 fixture |
| `docs/migration/` | v6 지식, 복사 근거와 이전 상태 |
| `almanac/` | v7의 장기 경계와 불변식 |

## 검증

```powershell
cd backend
py -3.11 -m unittest discover -s tests -v

cd ../frontend
flutter analyze
flutter test
flutter build windows --release
```

## 실제 Python backend로 실행

기본 실행은 UI 개발과 Widget test 안정성을 위해 `MockAppService`를 사용합니다.
planning protocol v1 Python process를 사용하려면 backend 경로를 명시합니다.

```powershell
cd frontend
flutter run -d windows `
  --dart-define=BA_PLANNER_USE_REAL_BACKEND=true `
  --dart-define="BA_PLANNER_BACKEND_DIR=C:\path\to\BA Planner\v7\backend"
```

기본 Python launcher는 Windows의 `py -3.11`입니다. 별도 실행 파일을 쓰려면
`--dart-define="BA_PLANNER_PYTHON=C:\path\to\python.exe"`를 추가합니다.
backend 경로는 실제 연결을 시작할 때 확인하므로 경로가 잘못되어도 앱 shell은
연결 끊김 상태로 실행됩니다. P1에는 scanner가 포함되지 않아 실제 backend 모드의
스캔 버튼은 `스캐너 미연결` 상태로 비활성화됩니다.
배포용 Python runtime과 backend source/data 번들은 아직 release packaging 범위에
포함되지 않습니다.

## Windows 실행 파일

UI 검사와 성능 측정을 위한 DevTools 런처는 최상위의
`BA Planner v7 DevTools Debug.exe`와 `BA Planner v7 DevTools Profile.exe`입니다.
각 런처는 Windows Flutter 앱과 연결된 DevTools를 자동으로 열며, 다음 명령으로
다시 생성할 수 있습니다.

```powershell
cd frontend
.\tool\build_windows_devtools_launchers.ps1
```

개발 작업공간의 최상위 `BA Planner v7.exe`는 고정된 Release 복사본이 아니라
소스 최신성을 확인하는 런처입니다. 실행할 때 `frontend/lib`, UI asset,
Windows runner와 `pubspec`의 SHA-256 지문을 비교하며, 변경이 있으면 Flutter
Release 번들을 자동으로 다시 만든 뒤 `release/ba_planner_v7.exe`를 실행합니다.

최상위 런처까지 처음 만들거나 런처 코드를 갱신할 때는 다음 명령을 사용합니다.

```powershell
cd frontend
.\tool\build_windows_release.ps1
```

Release 최신성만 검사하려면 다음 명령을 사용합니다. 오래된 경우 실패 코드로
종료하므로 로컬 검증이나 CI에도 사용할 수 있습니다.

```powershell
cd frontend
.\tool\sync_windows_release.ps1 -CheckOnly
```

Flutter의 Dart 코드와 asset은 `release/data/`에 포함되므로 UI만 변경된 빌드는
네이티브 runner EXE의 바이트가 이전 빌드와 같을 수 있습니다. 동기화 스크립트는
혼동을 줄이기 위해 EXE 표시 시각을 빌드 시각으로 맞추지만, 실제 최신성 판단은
`release/.ba_planner_build.json`의 소스 지문을 기준으로 합니다.

## v6 관계

v6는 안정판과 회귀 기준으로 남습니다. v7은 `../v6`를 런타임에서 import하지
않으며, 새 기능의 기준 구현은 v7입니다. 필요한 v6 버그 수정은 명시적으로
선별해 역이식합니다.
