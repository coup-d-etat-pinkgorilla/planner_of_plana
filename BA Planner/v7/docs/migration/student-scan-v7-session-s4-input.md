# S4 input — 인연 랭크 OCR과 스탯 교차 검증

## 선행 조건

S3 accepted snapshot과 실제 인연 랭크 화면 fixture가 필요하다. 최소 rank 1/9/10/20/50/100,
두 해상도와 다른 의상 학생 fixture를 권장한다. fixture 없이 ROI를 추측하지 않는다.

## 목표

인연 랭크를 숫자로 판독하고, S1 계산 코어로 예상 HP/ATK/DEF/HEAL을 산출해 OCR 관측값과
비교하는 구조화 evidence를 만든다.

## 범위

- ratio/perspective ROI와 `0~9` digit matcher
- rank 범위·학생 성급 cap semantic validation
- `FavorAlts` 다른 의상 dependency 추적
- 전체 scan 후 pending 후보 second-pass 재검증
- expected/observed/delta/dependencies/suggestion evidence detail
- verified/partial/dependency_missing/suspicious 판정
- suspicious이면 review-required, payload 자동 수정 금지
- schema/fixture/backend/Dart decoder/mock의 additive protocol 변경이 필요하면 함께 갱신

## 완료 조건

- rank 1/9/10/20/50/100 fixture를 정확히 구분한다.
- bond 51~100에서 스탯 증가가 50과 같음을 검증한다.
- 다른 의상 랭크 누락은 mismatch가 아니라 dependency missing이다.
- 완전한 입력의 정확 일치와 의도적 한 자리 OCR 오류 fixture가 있다.
- 근접 입력 제안은 네 스탯을 함께 설명할 때만 생성된다.

## 인계 계약

patch, 캡처 fixture manifest, 개인정보/계정명 제거 확인, test output과 SHA-256을 artifacts로
인계한다. 실제 게임 캡처가 없어서 남은 항목은 숨기지 말고 `NOT_VERIFIED`로 기록한다.

