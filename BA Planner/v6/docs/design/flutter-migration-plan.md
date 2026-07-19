# Flutter frontend migration plan

## Decision

BA Planner의 새 프런트엔드는 Flutter for Windows를 1순위 후보로 검증한다.
기존 QML/Qt Quick 및 QWidget 화면을 새 화면의 기반으로 재사용하지 않고,
검증된 Python 도메인 로직과 저장 형식만 유지한다.

단, Flutter 채택은 아래 Phase 0의 Adaptive-Sync 실기기 검증을 통과해야 확정한다.
Flutter도 Windows에서 GPU 합성 경로를 사용하므로 프레임워크 교체만으로 VRR 문제가
해결된다고 가정하지 않는다.

## Why this is a gated migration

Flutter 공식 아키텍처 문서에 따르면 Windows 앱은 Win32 호스트 안에서 실행되며,
ANGLE이 OpenGL 호출을 DirectX 11 호출로 변환해 화면을 그린다. 프레임은 운영체제가
제공하는 VSync 신호에 맞춰 처리된다. 따라서 현재 Qt Quick의 Direct3D 11 경로에서
관찰된 AOC Adaptive-Sync 밝기 변동과 완전히 다른 출력 경로라고 볼 수 없다.

현재 공식 Flutter API에는 Windows 앱 단위로 Adaptive-Sync/VRR을 끄거나 고정 재생
빈도를 요청하는 고수준 옵션이 없다. 지속적인 애니메이션으로 프레임을 강제하는 것은
가능하지만 전력, GPU 사용량, 발열이라는 기존의 큰 트레이드오프를 그대로 만든다.

참고:

- [Flutter architectural overview](https://docs.flutter.dev/resources/architectural-overview)
- [Flutter frame scheduling API](https://api.flutter.dev/flutter/scheduler/SchedulerBinding/scheduleFrame.html)
- [Building Windows apps with Flutter](https://docs.flutter.dev/platform-integration/windows/building)

## Target architecture

```text
Flutter Windows frontend (Dart)
  - widgets, layout, navigation, accessibility
  - view state and presentation-only formatting
  - typed IPC client
              |
              | versioned local request / response / event protocol
              v
Python application service (headless child process)
  - use cases and orchestration
  - cancellation, progress, errors
  - DTO serialization
              |
              v
Existing core domain and infrastructure
  - scanner and capture
  - planning and cost calculation
  - repositories, profiles and configuration
  - tactical analysis and metadata
```

Flutter가 Python을 라이브러리처럼 직접 포함하는 구조는 우선 채택하지 않는다.
Python 런타임, OpenCV와 Windows 캡처 의존성을 보존하면서 충돌 범위를 줄이려면
별도 백엔드 프로세스가 가장 명확하다. Flutter가 백엔드 프로세스의 생성과 종료를
소유하며, 비정상 종료를 감지해 사용자에게 복구 동작을 제공한다.

EasyOCR은 새 백엔드에 포함하지 않는다. 현재 EasyOCR 실행 경로는 로비의 크레딧과
청휘석을 읽는 `scan_resources()`뿐이며, 이 값은 새 UI의 사용자 입력으로 대체한다.
학생·장비·인벤토리 스캔은 기존 템플릿/글리프 매칭 경로를 유지한다. 따라서
`easyocr`, `torch`, `torchvision` 및 EasyOCR 전용 과학 계산 의존성은 백엔드
requirements와 배포 수집 대상에서 제거한다.

초기 IPC 후보는 길이 접두어가 있는 UTF-8 JSON 메시지를 표준 입출력으로 교환하는
방식이다. 단순 줄 단위 JSON보다 로그나 개행 데이터에 안전하고, 로컬 포트와 방화벽을
사용하지 않는다. 로그는 stderr로 분리한다. 처리량 측정에서 병목이 확인될 때만
MessagePack 또는 named pipe로 확장한다. 스크린샷과 대형 이미지는 JSON에 넣지 않고
허용된 로컬 파일 경로와 메타데이터로 전달한다.

## Backend extraction boundary

`gui/quick/models.py`와 `gui/viewer_shared.py`는 새 백엔드 API가 아니다. 현재 두 파일에는
Qt 모델/시그널, SQLite 조회, subprocess 관리, 필터링, 스캔 상태, 계획 저장과 UI 표시
문자열이 함께 들어 있다. 이 로직에서 Qt와 화면 상태를 제거한 애플리케이션 서비스 계층을
새로 만든다.

보존할 핵심 모듈의 예:

- `core/config.py`와 프로필/저장 경로 계약
- `core/repository.py` 및 DB 접근 계층
- `core/planning.py`, `core/planning_calc.py`
- `core/student_meta.py`
- `core/scanner.py`와 scanner components
- 캡처 및 창 선택 로직
- tactical challenge와 screenshot 분석 로직

서비스가 반환하는 DTO는 Qt 타입이나 화면 위젯을 포함하지 않는다. 특히 다음 데이터
버킷을 하나의 편의 객체로 합쳐 저장하지 않는다.

1. 현재 스캔 상태
2. 정적 학생 메타데이터
3. 계획 목표
4. 계산 결과
5. 인벤토리 기반 부족량

`StudentRecord`는 표시를 위해 병합된 읽기 모델로만 취급하고, `StudentGoal`과 계산 결과의
원본 계약은 기존 의미를 보존한다. 통계가 현재 필터링된 학생 집합을 사용한다는 동작도
명시적인 요청 파라미터와 회귀 테스트로 고정한다.

## IPC contract baseline

모든 메시지는 다음 공통 필드를 갖는다.

```json
{
  "protocol": 1,
  "id": "request-id",
  "type": "request|response|event",
  "method": "scan.start",
  "payload": {}
}
```

필수 계약:

- 요청 ID 기반 응답 대응과 중복 요청 처리
- 안정적인 오류 코드, 사용자 메시지, 디버그 상세의 분리
- 긴 작업의 progress 이벤트 및 cancellation
- 백엔드 시작 시 protocol/capability handshake
- 정상 종료, 강제 종료, 백엔드 crash의 구분
- 프로필 전환 시 오래된 이벤트를 거부할 generation/session ID
- DTO 스키마 fixture를 Python과 Dart 양쪽 테스트에서 공유

## Migration phases and gates

### Phase 0 — renderer and packaging spike

실제 BA Planner 기능을 옮기기 전에 작은 Flutter Windows EXE를 만든다.

검증 화면에는 다음을 의도적으로 포함한다.

- 홈 화면과 동일한 PNG 텍스처 버튼 여러 개
- hover 진입/이탈, 포커스, 클릭, 탭 전환
- 정적 상태에서 긴 유휴 시간과 간헐적 갱신
- 창 모드, 최대화, 전체 화면
- 현재 AOC 모니터의 Adaptive-Sync ON 상태
- NVIDIA 제어판의 앱별 고정 재생 빈도 설정을 제거한 상태
- debug/profile/release 빌드 비교

통과 기준:

- 현재 AOC 장비에서 반복 가능한 밝기 깜빡임이 없음
- 모니터가 꺼졌다 켜지는 듯한 모드 전환이 없음
- 두 번째 PC와 서로 다른 GPU/모니터 조합에서도 기능 회귀가 없음
- 유휴 상태에서 지속 재렌더링을 사용하지 않음
- 소프트웨어 렌더러를 배포 기본값으로 강제하지 않음

이 gate가 실패하면 Flutter 전체 이식을 중지하고 동일한 최소 화면으로 WPF/WinUI 또는
Tauri/WebView2 후보를 비교한다.

### Phase 1 — characterize and extract the Python service

- 현재 `AppController`의 공개 기능을 use-case 목록으로 고정한다.
- Qt signal, Tk callback, subprocess/status-file, 문자열 키, JSON 설정 소비자를 각각 찾는다.
- 프로필, 창 연결, 스캔, 인벤토리, 학생, 계획, tactical 기능별 characterization test를 만든다.
- Qt import가 없는 application service와 DTO를 한 기능씩 추출한다.
- 기존 QML/QWidget은 이 서비스의 임시 adapter를 사용하도록 해 추출 중 회귀를 확인한다.

### Phase 2 — protocol and backend executable

- protocol v1 스키마와 capability handshake를 확정한다.
- Python headless entry point를 만든다.
- 요청/응답, 이벤트, cancellation, crash recovery를 테스트한다.
- 기존 로컬 데이터에서 읽고 쓴 결과가 현재 앱과 동일한지 contract test를 수행한다.

### Phase 3 — Flutter shell and design system

- 창 lifecycle, 라우팅, 키보드/마우스/포커스, 오류 경계를 먼저 만든다.
- 색상, typography, spacing, radius, elevation, animation duration을 design token으로 정의한다.
- Button, image tile, card, tab header, list row, filter, dialog 등 공통 컴포넌트를 만든다.
- 앱 화면과 분리된 component catalog에서 상태별 모양을 검토한다.
- 1280x720, 1600x900, 1920x1080 및 고 DPI golden screenshot을 고정한다.

기존 1920x1080 전체 캔버스를 일괄 배율 조정하는 방식은 그대로 옮기지 않는다. Flutter의
constraint 기반 레이아웃으로 다시 설계하며, 디자인상 절대 크기가 필요한 장식과 실제
정보 레이아웃을 분리한다.

### Phase 4 — vertical slices

추천 순서는 위험과 의존성을 기준으로 한다.

1. 설정, 프로필, 창 선택/연결
2. 홈과 스캔 상태/로그
3. 인벤토리
4. 학생 목록, 필터, 상세
5. 계획 편집과 비용 계산
6. 통계와 tactical 기능
7. 대화상자, 오류 보고, 업데이트/배포 흐름

각 slice는 UI 표시만 완성하는 것이 아니라 Python contract test, Dart unit/widget test,
Windows integration test, golden test까지 통과해야 완료로 본다.

### Phase 5 — packaging and cutover

- Flutter release 파일과 Python backend runtime/dependencies/assets를 하나의 설치 단위로 묶는다.
- 사용자 데이터는 설치 디렉터리 밖의 기존 프로필/DB 위치를 유지한다.
- 백엔드와 프런트엔드 버전 불일치를 시작 시 감지한다.
- 기존 배포본에서 upgrade/rollback과 데이터 무변경을 검증한다.
- 기능 동등성과 실기기 VRR matrix를 통과한 뒤에만 QML/QWidget 진입점을 제거한다.

## UI implementation options

| 후보 | UI 설계 생산성 | Python 보존 | Adaptive-Sync 관점 | 주요 비용 | 판단 |
| --- | --- | --- | --- | --- | --- |
| Flutter | 강한 컴포넌트 조합, hot reload, custom paint | 별도 프로세스 IPC | ANGLE→D3D11이므로 실기기 검증 필수 | Dart/배포 체계 추가 | 1순위, Phase 0 조건부 |
| Tauri + React/Svelte | CSS/Figma 연계와 웹 UI 생태계가 강함 | sidecar IPC 용이 | Windows WebView2/Chromium GPU 경로이므로 보장 없음 | 웹+Rust+Python 3중 스택 | 2순위 fallback |
| WPF 또는 WinUI 3 | Windows 입력/접근성/창 통합이 좋음 | 별도 프로세스 IPC | DirectX 합성이라 역시 검증 필요 | C#/XAML 전면 이식, Windows 전용 | Windows 전용성을 최우선할 때 |
| Avalonia | XAML/MVVM, 크로스플랫폼 | 별도 프로세스 IPC | Skia/Direct3D 또는 software 경로, 실기기 검증 필요 | C# 전면 이식과 생태계 평가 | Flutter 실패 시 비교 후보 |
| 새 Qt Widgets UI | Python 백엔드 재사용이 가장 쉬움 | 직접 호출 가능 | 현재 QWidget 결과를 별도 확인해야 함 | 기존 부채 재유입 방지 규율 필요 | 최소 언어 전환 대안 |
| 게임 엔진/Immediate UI | 커스텀 그래픽 자유도 높음 | IPC 필요 | 상시 렌더 루프는 VRR 밝기 안정에 유리할 수 있음 | 전력, 접근성, 폼/표/텍스트 UI 비용 | 본 앱에는 비추천 |

프레임워크 종류만으로 VRR 안전성을 보장하는 후보는 없다. WPF도 하드웨어 가속 DirectX,
Avalonia도 GPU composition을 사용할 수 있고, Tauri는 Windows 시스템 WebView2를 쓴다.
따라서 모든 후보는 동일한 Phase 0 테스트를 통과해야 한다.

## Scanner language strategy

초기 Flutter 이식에서는 scanner를 다른 언어로 전면 재작성하지 않는다. 현재 scanner의
이미지 연산 대부분은 Python wrapper 아래의 OpenCV C++/NumPy 네이티브 코드에서 이미
실행되며, 전체 스캔 시간에는 게임 UI 대기, 캡처, 안정 프레임 확인과 입력 지연이 포함된다.
따라서 언어 교체 전에 단계별 CPU 시간과 대기 시간을 분리해서 측정한다.

언어 독립적인 scanner IPC와 캡처 fixture를 먼저 만들고, 다음 순서로만 네이티브화를
확대한다.

1. Python 구현을 기준으로 offline capture replay와 결과 contract를 고정한다.
2. 병목이 확인된 템플릿 후보 생성·수량 판독 루프만 Rust 또는 C++ extension으로 옮긴다.
3. 같은 캡처를 Python과 새 구현에 동시에 넣는 shadow 비교를 수행한다.
4. 충분한 성능·용량 이득과 결과 동등성이 확인될 때만 독립 scanner service를 검토한다.

독립 구현 후보의 우선순위는 Rust service, C++/OpenCV service, C# service 순이다.
Flutter/Dart로 scanner 전체를 옮기는 방식은 OpenCV·Windows 캡처·입력 계층의 재구축
비용이 크므로 기본 후보에서 제외한다. 순수 Rust로 OpenCV까지 제거하는 방식은 가장 작은
배포본을 만들 수 있지만, 현재 인식 알고리즘과 수치 결과를 재현해야 하므로 장기 연구
과제로만 취급한다.

참고:

- [WPF graphics rendering tiers](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/graphics-rendering-tiers)
- [Avalonia architecture](https://docs.avaloniaui.net/docs/fundamentals/architecture)
- [Tauri architecture](https://v2.tauri.app/concept/architecture/)

## UI design workflow

새 런타임 UI 편집기를 다시 만드는 것보다 다음 산출물을 source of truth로 사용한다.

1. Figma: 화면 흐름, 컴포넌트 variant, 디자인 토큰과 검토용 시안
2. 저장소의 token 파일: 색상/간격/타입/모션을 코드가 소비하는 값으로 관리
3. Flutter component catalog: 실제 렌더러에서 모든 상태와 DPI를 검증
4. golden tests: 승인된 화면 이미지와 픽셀 회귀 비교
5. interaction specs: hover/focus/pressed/disabled, 키보드 탐색, loading/error/empty 상태

Figma에서 생성된 화면 코드를 직접 제품 코드의 기준으로 삼지 않는다. 디자인 토큰과
컴포넌트 명세만 연결하고, 레이아웃/상태/접근성은 Flutter 컴포넌트에서 명시적으로
구현한다. Blue Archive 스타일의 대각선 표면은 일반 레이아웃 영역을 유지한 채
`CustomPainter`/`ClipPath` 같은 presentation 컴포넌트로 격리한다.

## Explicitly rejected defaults

Adaptive-Sync 증상을 숨기기 위해 다음 방법을 제품 기본값으로 채택하지 않는다.

- 모든 hover 효과 제거
- 홈 PNG를 별도 네이티브 이미지 공급자로 우회
- 소프트웨어 렌더러 강제
- 화면을 계속 60/165 FPS로 재렌더링
- NVIDIA 제어판의 고정 재생 빈도를 사용자에게 필수 설정으로 요구

이 항목들은 진단 실험에는 사용할 수 있지만, 배포 아키텍처의 전제가 되어서는 안 된다.
