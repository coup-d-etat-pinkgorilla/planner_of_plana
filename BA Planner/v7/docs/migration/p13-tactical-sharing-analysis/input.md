# P13 익명 공유와 고급 분석 입력

## 선행 기준

- P9의 실제 관측 match·snapshot 연결
- P10~P11의 관측 모집단·신선도·노출 의미
- P12의 prediction/observation 분리와 calibration gate

## 구현 목표

- 명시적 opt-in consent가 있어야만 생성되는 비식별 공유 payload
- 설치·scope·season 범위에서만 쓰는 contributor/opponent/source identity
- attempt session/index, 실제 경기 시각, 공유 시각과 방어 snapshot identity
- 중복 import, 철회 tombstone과 파생 aggregate cache의 원자적 일관성
- 독립 contributor·상대 수, 출처 집중도와 첫 시도/재도전 분석
- 발견자와 후속 사용자, 족보 수명, 변경 후 재검증과 한 슬롯 대체 분석
- season·patch·map·rank condition filter와 최소 표본 suppression

## 개인정보 경계

- 상대 표시 이름, 이름 ROI, screen hash, 원본 screenshot과 local prediction은 공유하지 않는다.
- 외부 전송은 P13 구현 범위가 아니며 로컬 prepare/import/analysis만 제공한다.
- 작은 표본의 세부 그룹은 contributor·opponent 최소 수를 모두 충족해야 반환한다.
- 머신러닝 학습·배포는 별도 승인 전까지 수행하지 않는다.
