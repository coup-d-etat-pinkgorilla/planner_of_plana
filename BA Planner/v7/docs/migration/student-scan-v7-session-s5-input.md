# S5 input — 학생 스캔 검토 UI와 통합 E2E

## 선행 조건

S4 snapshot은 사용자에게 잠정 승인되었다. 독립 rank-6 재생 성공을 근거로 한 자리 수 경로를
진행 가능 상태로 보고, rank 1/9 원본 부재는 더 이상 S5 차단 조건으로 취급하지 않는다. 최종
S4 인수는 S5 완료 후 실제 게임 클라이언트 실행으로 확인한다.

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

## 2026-08-24 현재 상태와 남은 실행 순서

사용자 승인으로 Scan 탭 소유의 결과 목록/상세 작업공간, 빨강·초록 상태 테두리,
`수정`·`재검증`·`보류`·`적용`·확인형 `후보 폐기`, 저장소 충돌 복구까지 UI 1단계가
먼저 구현되었다. 이 예외는 S4 미확인 값을 검증된 것으로 승격하지 않는다.

1. **S4 계산·근거 통합 — 구현 완료, 실제 클라이언트 확인 대기**
   - 2560x1440 랭크 100 원본은 보정 데이터로 검증 완료했다.
   - 한 자리 수는 독립 rank-6 원본 재생 성공으로 동작 가능하다고 가정한다. rank 1/9는 후속
     보강 자료이며 현재 차단 조건이 아니다.
   - `skill2` 패시브의 primary-stat 계수와 전용무기 2성 이상 `WeaponPassive` 추가치를 실제
     계산에 포함한다. 해금된 패시브 레벨 누락은 명시적 dependency다.
   - S4 snapshot은 잠정 승인 상태이며 실제 클라이언트 S5 실행 후 최종 확인한다.
2. **S5 기능·표현 종료**
   - 다른 의상 dependency 및 적용된 보너스를 해당 학생 portrait, 확인 rank, ownership,
     flat/coefficient/base modifier와 함께 표시한다. 이 항목은 구현 및 widget 검증 완료했다.
   - `dependency_missing`과 `suspicious`의 전용 시각/접근성 회귀를 추가한다.
   - 실제 Python process에서 편집 → revision 증가 → 재검증 → 적용/commit과 stale
     candidate/repository conflict 복구 및 backend 재시작 후 반복 흐름을 검증 완료했다.
   - 검토 작업공간 자체를 800x720, 1280x720, 1440x900, 1920x1080 viewport에서 검증했다.
3. **S5 인수 종료**
   - 전체 Python 214개, Flutter 387개(`--concurrency=1`), `flutter analyze`, Windows release
     build와 release bundle 동기화를 통과했다.
   - 실제 게임 스캔 결과의 빨강 → 초록 → 적용 흐름에 대한 사용자 시각 검토만 남았다.
   - 자동 검증, release 확인 및 SHA-256은 handoff `output.md`에 기록했다. 사용자 승인 후
     screenshot/영상 경로와 최종 S4/S5 승인 상태를 추가한다.

## 인계 계약

patch, screenshot 또는 검토 영상, test output, release 확인과 master 실행 프롬프트를 artifacts에
저장하고 `output.md`에 크기·SHA-256을 기록한다.
