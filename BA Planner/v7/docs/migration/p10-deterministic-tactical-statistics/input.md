# P10 결정론적 전술 통계 MVP 입력

## 선행 기준

- P7 provenance·slot·match·snapshot DTO
- P8 공개 3슬롯 signature
- P9 lobby exposure·selection·match link와 opponent identity

## 구현 목표

- 공개 signature별 노출·선택·연결된 전적과 서로 다른 상대 수
- signature별 공격덱 채택, 관측 승·패, Wilson 95% 구간과 출처 구성
- 전투 후 확인된 완전 방어덱 분포
- 상대별 최근 공개·완전 방어와 관측 결과
- 완전 동일 공격덱, striker/special 동일, 한 자리 변형, 3·4인 core 집계
- season, source, opponent, public signature, 기간 필터
- 날짜 보유율·출처 구성·중복 의심을 포함한 표본 품질

## 의미 제한

- 결과는 `관측 승률`이며 실제 승률·방어 성공률·확정 카운터가 아니다.
- 기간 필터가 있으면 날짜 없는 기록은 제외한다.
- 같은 refresh generation은 한 노출 표본으로만 센다.
- 통계 조회는 원본 저장 상태를 변경하지 않는다.
