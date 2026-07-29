# P9 상대 Identity·방어 Snapshot·전적 연결 입력

## 선행 기준

- P7 tactical v2 state/import 계약
- P8 `tactical_lobby` review candidate
- 기준 로비 fixture의 세 상대와 공개 방어 3슬롯

## 구현 목표

- 확정된 P8 로비 후보를 scan, candidate, opponent identity, 공개 defense snapshot으로 저장
- 같은 refresh generation 반복 저장을 새 노출 표본으로 만들지 않음
- 상대 표시 이름 변경을 alias/binding으로 기존 identity에 연결
- 선택 시각 기록과 전투 후 match의 자동·모호·수동·해제 연결
- 전투하지 않은 candidate 보존과 scan 삭제의 안전한 cascade
- 공개 snapshot과 전투 후 완전 snapshot의 provenance 분리

## 비범위

- P10 통계 집계
- P11 변경·신선도 분석
- P12 예상 방어덱 생성
- P13 외부 공유
