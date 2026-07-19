# Flutter flicker probe

BA Planner의 Flutter Windows 전환 전제인 Adaptive-Sync 동작을 확인하는 독립
Phase 0 프로토타입입니다. 기존 Python/QML 실행 경로와 데이터를 변경하지 않습니다.

## 포함한 조건

- `assets/ui/home_menu`의 실제 PNG 7개
- 현재 홈 버튼과 같은 대각선 클리핑 및 즉시 hover 오버레이
- 홈/설정 화면 전환
- 카드별 `RepaintBoundary` ON/OFF 비교
- 주기적 타이머, 상시 애니메이션 및 강제 프레임 생성 없음

프로토타입은 실행 작업 디렉터리의 상위 폴더에서
`assets/ui/home_menu`를 탐색합니다. 따라서 이 저장소 안에서 실행해야 실제 이미지가
표시됩니다.

## Windows 빌드 도구

Visual Studio Installer에서 기존 Visual Studio 2019를 **수정**하고
`Desktop development with C++` workload를 선택합니다. 다음 개별 구성요소가 포함되어야
합니다.

- MSVC v142 C++ x64/x86 build tools
- C++ CMake tools for Windows
- Windows 10 SDK

설치 후 새 PowerShell에서 확인합니다.

```powershell
flutter doctor -v
```

## 실행

저장소 루트에서:

```powershell
cd prototypes/flutter_flicker_probe
flutter run -d windows
```

실제 판정은 release 빌드에서도 수행합니다.

```powershell
flutter build windows --release
./build/windows/x64/runner/Release/flutter_flicker_probe.exe
```

## 권장 비교 순서

1. AOC Adaptive-Sync ON, NVIDIA 앱별 고정 재생 빈도 설정 OFF
2. 창 모드에서 PNG 버튼 사이로 커서를 빠르게 왕복
3. 최대화 상태에서 같은 동작 반복
4. `RepaintBoundary` ON/OFF 비교
5. 홈/설정 전환 및 창 크기 변경 반복
6. 30초 이상 유휴 상태 후 첫 hover 확인
7. debug와 release 결과를 별도로 기록
