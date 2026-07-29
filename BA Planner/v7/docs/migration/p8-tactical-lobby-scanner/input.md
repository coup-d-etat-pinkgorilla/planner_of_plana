# P8 전술대항전 로비 스캐너

## 승인 입력

- 기준 화면: `C:/Users/brigh/Pictures/Screenshots/스크린샷 2026-07-07 201820.png`
- 해상도: 2560×1440
- 화면: 전술대항전 상대 선택, 세 행이 완전히 표시된 정지 화면

## 목표

P5 scanner session을 호환 확장해 현재 순위와 상대 세 명의 이름·순위·공개 스트라이커
1명·스페셜 2명을 OCR 없이 template matching으로 읽고 review 가능한 후보를 만든다.

## 기준 정답

| 행 | 순위 | 이름 | 스트라이커 1번 | 스페셜 1 | 스페셜 2 |
|---:|---:|---|---|---|---|
| 0 | 5 | 마리나9데스티니 | `tsubaki` | `hibiki` | `michiru_dress` |
| 1 | 6 | 우그웃 | `eimi` | `michiru_dress` | `yakumo` |
| 2 | 7 | 메라조마 | `tsubaki` | `michiru_dress` | `hibiki` |

현재 순위는 8이다.

## 완료 범위

- 2560×1440 ROI profile과 ratio projection
- rank digit, registered name, public portrait templates
- best score, runner-up, margin, overall confidence와 review-required
- screen hash와 deterministic refresh generation
- 동일 화면 반복, 낮은 margin, 미등록·긴·유사 이름, 배율·부분 가림 fixture
- P5 start/cancel/event/review/snapshot의 `tactical_lobby` 확장
- runtime UI asset과 recognition template 분리

## 제외 범위

- P9 상대 identity·snapshot 영구 저장과 전적 연결
- OCR과 임의 문자열 판독
- 실제 게임 새로고침 클릭 자동화
- P10 이후 통계·추천·공유

