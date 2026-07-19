# BA Planner v7 Flutter frontend

Phase 0에서 AOC Adaptive-Sync와 실제 홈 PNG hover를 통과한 Flutter Windows
기준선을 v7 shell로 옮긴 것입니다. 이미지는 Flutter asset bundle에 포함되며 v6
파일 경로에 의존하지 않습니다.

현재 화면은 렌더러 회귀 기준입니다. 이후 실제 UI를 구축하면서도 다음 조건을
유지합니다.

- 상시 animation이나 강제 frame loop 없음
- PNG hover 시 해당 카드만 상태 갱신
- software renderer 강제 없음
- 카드별 repaint isolation 비교 가능

