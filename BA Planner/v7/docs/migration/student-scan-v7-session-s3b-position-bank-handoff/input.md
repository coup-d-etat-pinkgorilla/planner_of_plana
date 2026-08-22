# S3B 위치별 숫자 bank 입력

## 범위

`C:\Users\brigh\Pictures\Screenshots\BA\S3B_1280_DIGITS`에 추가된 다섯 화면을 확인하고,
필요한 digit coverage가 충족되면 S3B의 남은 숫자 matcher 구현·검증·문서화를 완료한다.
S4/S5는 변경하지 않는다.

## 승인된 전제

- Promotion 근거는 exact 16:9, exact 1280x720만 사용한다.
- 장비 레벨 숫자는 같은 폰트, -0.25 shear와 같은 두 위치를 사용한다.
- 한 자리 숫자는 두 자리 layout의 첫 번째 위치를 사용한다.
- v6 mask의 픽셀 형상과 위치는 과거 육안 검증했다.
- 필요한 runtime template는 첫 위치 1~9, 둘째 위치 0~9의 19개다.
- 원본 screenshot pixel과 runtime recognition asset은 분리한다.

## 완료 조건

- 새 실화면 답지와 test-only fixture를 남긴다.
- compact 19-mask bank와 production level 경로를 구현한다.
- 오판독 0, exact-1280 coverage, fallback/menu-call 감소, cold/warm 비용을 기록한다.
- 불확실한 판독과 별도 tier 실패는 안전 fallback으로 보존한다.
- Almanac과 S3B 문서를 갱신하고 handoff 계약으로 인계한다.
