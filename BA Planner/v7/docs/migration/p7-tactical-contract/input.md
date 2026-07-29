# P7 전술 데이터 계약과 저장 기반

## 목표

P6 전술 CRUD를 호환 유지하면서 P7 DTO, provenance, versioned protocol과 실제 v6 SQLite
import preview/commit 수직 슬라이스를 구현한다.

## 필수 범위

- `TacticalDeck`, `TacticalMatch`, `TacticalJokbo`, `TacticalOpponentIdentity`,
  `TacticalDefenseSnapshot`, `TacticalSlotObservation` version 2 wire DTO
- unknown과 실제 empty 슬롯 분리, canonical student ID, provenance와 네 시각 분리
- 실제 v6 SQLite 읽기 전용 특성화와 최소 비식별 parity fixture
- import preview, fingerprint 검증, atomic commit과 batch/source idempotency
- Python/Dart 공용 valid/invalid fixture와 contract test
- 기존 `tactical.*` v1 UI와 저장 호환 유지

## 제외 범위

- P8 로비 캡처·템플릿 매칭
- P9 자동 상대 연결
- P10 이후 통계·예측·공유
- v6 Python runtime import와 실제 v6 DB 변경

## 완료 조건

`almanac/workflows/p7-p13-tactical-backend-workflow.md`의 P7 완료 조건을 모두 충족해야 한다.

