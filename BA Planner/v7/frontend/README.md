# BA Planner v7 Flutter frontend

v7 프런트엔드는 Flutter for Windows로 작성하며 Python 백엔드와는 `AppService` 경계만 공유합니다. 현재는 `MockAppService`가 UI 상태를 제공하고, 이후 동일한 계약을 구현하는 `V6ProcessAppService`로 교체합니다.

```text
Flutter UI
   ↓
AppService
   ├─ MockAppService
   └─ V6ProcessAppService (예정)
```

## 실행

```powershell
cd frontend
flutter run -d windows
```

- 코드 저장 또는 `r`: Hot Reload
- `R`: Hot Restart
- `q`: 종료
- 모델 생성자나 앱 초기화 변경은 Hot Restart가 필요합니다.
- Python 변경은 백엔드 프로세스만 재시작하고 Flutter 서비스가 재연결하도록 구성합니다.

### DevTools 실행 파일

v7 최상위의 다음 실행 파일은 Windows Flutter 앱을 해당 모드로 시작하고, 연결된
DevTools URL을 기본 브라우저에서 자동으로 엽니다.

- `BA Planner v7 DevTools Debug.exe`: Inspector, 디버깅, Hot Reload/Restart용
- `BA Planner v7 DevTools Profile.exe`: 실제 프레임과 렌더링 성능 측정용

런처 창을 닫으면 런처가 시작한 Flutter 앱도 종료됩니다. 실행 파일을 다시 만들려면
다음 명령을 사용합니다.

```powershell
cd frontend
.\tool\build_windows_devtools_launchers.ps1
```

## 현재 UI 골격

- 홈, 학생, 계획, 인벤토리, 전술대항전, 통계, 스캔, 설정 탭
- 탭 상태를 보존하는 `IndexedStack` 기반 앱 셸
- 색상·간격·Material 컴포넌트를 모은 공통 테마
- 연결, 스캔, 데이터, 이미지, 큰 수치, 긴 이름, 누락 메타데이터 상태를 바꾸는 목업 개발 패널
- 설정과 개발 패널에서 진입할 수 있는 Adaptive-Sync 진단 화면

런타임 UI 이미지는 Flutter asset bundle에 포함하며 Python scanner 인식 템플릿과 분리합니다.

## 검증

```powershell
flutter analyze
flutter test
flutter build windows --release
```

## v7 최상위 실행 파일과 자동 동기화

Flutter Windows 앱은 실행 파일과 DLL·data 묶음이 함께 필요합니다. 다음 스크립트는 런타임 묶음을 `v7/release/`에 배치하고, 최상위에 바로 실행할 수 있는 `BA Planner v7.exe` 런처를 생성합니다.

```powershell
.\tool\build_windows_release.ps1
```

최상위 런처는 실행할 때마다 소스 지문을 빠르게 확인합니다. Dart 코드, UI asset,
Windows runner 또는 `pubspec`이 마지막 Release 이후 달라졌다면 진행 창을 표시하고
Release를 자동 갱신한 다음 앱을 엽니다. 변경이 없으면 기존 번들을 바로 사용합니다.

자동 동기화만 직접 실행하거나 최신성만 검사할 수도 있습니다.

```powershell
# 변경된 경우에만 빌드하고 release/를 교체
.\tool\sync_windows_release.ps1

# 빌드하지 않고 오래된 Release인지 검사
.\tool\sync_windows_release.ps1 -CheckOnly
```

Release 앱이 실행 중이면 Windows가 파일 교체를 막으므로 앱을 닫고 런처를 다시
실행해야 합니다. Flutter가 PATH에 없으면 `FLUTTER_ROOT` 또는
`-FlutterCommand C:\path\to\flutter.bat`을 사용할 수 있습니다.

UI Dart 코드와 asset은 `release/data/`에 들어가므로 변경 후에도 네이티브 runner
EXE 자체는 같은 바이너리일 수 있습니다. 스크립트는 EXE 표시 시각도 갱신하지만,
정확한 최신성 기준은 `release/.ba_planner_build.json`의 SHA-256 소스 지문입니다.
