# P11 방어 변경·신선도·노출 분석 입력

## 선행 기준

- P9의 중복 없는 refresh generation, candidate 선택과 match link
- P10의 순수 조회, 관측 승률, 공격/방어 분리와 동일 모집단 필터

## 구현 목표

- 상대별 공개 signature 변경을 이전 마지막 관측~새 signature 최초 관측 구간으로 반환
- 공개 signature 유지 기간과 비연속 재사용 감지
- 공개 signature가 유지된 동안 확인된 완전 방어덱 변경 감지
- 새로고침당 등장, 연속 refresh 잔류와 rank difference별 노출 분석
- 노출→선택→전투→결과 funnel과 상대·signature·rank difference별 선택률
- 마지막 성공·실패, 최신 공개 관측/변경 이후 검증과 시간 감쇠 기반 구식 경고

## 결정론 경계

- `as_of`를 요청 필수값으로 받아 시간 감쇠를 재현 가능하게 계산한다.
- 날짜 없는 기록은 변경·수명·신선도에서 제외한다.
- prediction과 방어 match는 공격 족보 검증에서 제외한다.
- 모든 조회는 저장 상태를 변경하지 않는다.
