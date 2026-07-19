# Qt UI Scaling

BA Planner Qt Viewer는 1920×1080을 디자인 기준으로 사용하며, 각 최상위 창이 독립적인
`UIScaleContext`를 소유합니다.

## 배율 계약

```text
scale = clamp(min(client_width / 1920, client_height / 1080), 0.5, 1.8)
font_point_size = 11.0 × scale
```

geometry, layout margin/spacing, icon, custom paint 치수와 폰트는 같은 scale을 사용합니다.
Qt의 화면 geometry는 device-independent pixel이므로 Windows DPI 배율이 적용된 모니터에서도
동일한 계산을 사용합니다. `BA_UI_SCALE` 환경 변수가 있으면 최초 scale을 명시적으로
덮어쓸 수 있습니다.

## 리사이즈

기존 Qt Widgets Viewer 창은 시작한 모니터의 전체 화면 geometry에서 화면 비율을 구해 유지합니다. 작업 표시줄
등을 제외한 사용 가능 영역 안에서 같은 화면 비율로 맞추며, 160ms 동안 크기 변경이 멈추면
가장 가까운 동일 비율 크기로 보정한 뒤 새 scale로 UI 표현 트리를 재생성합니다. 학생·플랜·
인벤토리 등 로드된 데이터 객체와 이미지 cache는 유지하며 DB와 프로필 파일을 다시 읽지
않습니다. 실행 중인 스캔이 있으면 UI 재생성을 실행하지 않습니다.

UI 재생성 시 현재 메인 탭, 홈 스캔 workspace, 학생/인벤토리 스캔 미리보기 모드를 복원합니다.

새 Qt Quick Viewer는 이 재생성 경로를 사용하지 않습니다. 1920×1080 `designCanvas`를 한 번
생성하고 client 크기에 따라 canvas의 scale과 중앙 정렬 offset만 갱신합니다. 학생·인벤토리·
플랜 목록은 `GridView`/`ListView` delegate 가상화를 사용합니다. 상세 전환 계약은
`docs/design/qt-quick-migration.md`를 따릅니다.

## UCS 검증 크기

UI Component Studio는 다음 Preview preset을 제공합니다.

- 자동 · 현재 모니터
- 1920×1080
- 1600×900
- 1366×768
- 1280×720
- 960×540

상단 상태 줄에서 실제 Preview 크기, scale, 창별 폰트 pt를 함께 확인합니다. Preview를 직접
리사이즈해도 Planner와 같은 scale 재생성 경로가 실행됩니다.

## 남은 컴포넌트 하한값

일부 기존 custom painter와 작은 상태 strip은 클릭·식별 가능성을 위해 고정 pixel 하한을
유지합니다. 이 값은 무작정 제거하지 않고 각 컴포넌트의 최소 렌더 크기 테스트와 함께
`UIScaleContext` 토큰으로 순차 이전합니다.
