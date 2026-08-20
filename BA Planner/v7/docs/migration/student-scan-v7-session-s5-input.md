# S5 input — 학생 스캔 검토 UI와 통합 E2E

## 선행 조건

S4 accepted snapshot에서만 시작한다.

## 목표

현재 raw candidate 텍스트 영역을 학생 이미지 기반 검토 workspace로 교체하고, 수정·재검증·
승인·보류·거절·commit 흐름을 실제 Python process와 연결한다.

## 사용자 화면

- 학생 portrait/name과 candidate identity
- 현재 확정값 / 스캔값 / 계산값 / 차이 4열 비교
- confidence와 verified/partial/dependency missing/suspicious 배지
- 인연 다른 의상 dependency와 해당 학생 portrait
- 의심 필드만 우선 표시하고 raw evidence는 접을 수 있는 상세 영역
- candidate payload 편집 후 재검증
- 승인·보류·거절, stale revision과 repository conflict 안내

## 제약

- 후보 handoff 시 해당 학생을 선택하지만 진행 중인 수동 draft를 몰래 덮어쓰지 않는다.
- 계산 mismatch만으로 값을 자동 변경하지 않는다.
- 계산 evidence를 repository 현재 상태로 저장하지 않는다.
- 기존 section motion/diagonal hit geometry와 좁은 viewport를 보존한다.

## 완료 조건

- Mock과 실제 process에서 수정 → revision 증가 → 재검증 → commit이 통과한다.
- review-required 후보는 승인 전 commit할 수 없다.
- dependency missing과 suspicious가 시각적으로 구분된다.
- narrow/normal/maximized widget tests, 전체 Flutter tests, `flutter analyze`, process E2E,
  Windows release build와 실제 시각 검토 결과를 기록한다.

## 인계 계약

patch, screenshot 또는 검토 영상, test output, release 확인과 master 실행 프롬프트를 artifacts에
저장하고 `output.md`에 크기·SHA-256을 기록한다.

