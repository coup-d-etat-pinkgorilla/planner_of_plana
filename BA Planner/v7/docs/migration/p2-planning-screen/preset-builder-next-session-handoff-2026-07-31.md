# 계획 프리셋 제조 섹션 다음 세션 Handoff

> 2026-08-02 기준 최신 구현과 결정은
> `preset-management-next-session-handoff-2026-08-02.md`로 승계됐다. 다음 세션은 새 문서를
> 기준으로 시작한다.

## 목표

다음 세션의 범위는 계획 탭에서 사용할 **육성 목표 프리셋 제조 섹션**의 계약을
확정하고, 승인된 범위 안에서 첫 vertical slice를 만드는 것이다.

`next-session-handoff-2026-07-30.md`는 페이즈 편집기 구현 전 상태를 설명하는
과거 기록이다. 현재 작업은 이 문서를 기준으로 이어간다.

## 시작할 때 읽을 문서

1. `AGENTS.md`
2. `README.md`
3. `docs/migration/v6-knowledge-baseline.md`
4. `almanac/workflows/p0-p6-workflow-status.md`
5. `almanac/design/frontend-section-direction-and-user-flows.md`
6. `almanac/design/section-template-studio.md`
7. `almanac/design/plan-phase-editor-lessons-2026-07-31.md`
8. 이 handoff

현재 구현의 source of truth:

- `frontend/lib/ui/widgets/plan_section_layout.dart`
- `frontend/lib/ui/widgets/plan_phase_editor.dart`
- `frontend/lib/ui/pages/planning_page.dart`
- `frontend/test/ui/planning_page_test.dart`
- 계획 관련 versioned protocol과 repository 구현

## 현재 상태

- 계획 메인 Section 1에는 임시 `페이즈 만들기` 진입 버튼이 있다.
- 페이즈 편집기는 4개 section, 드래그/빠른 배정/전체 배정/복원, 페이즈 생성·삭제,
  이름 편집, 완료 전환까지 인메모리로 구현되어 있다.
- 완료 시 편집기 Section 4가 계획 메인 Section 2 위치로 이동하고, 나머지 메인
  section이 진입한다.
- 계획 화면의 데이터는 아직 더미·인메모리이며 재시작 복원은 없다.
- `PlanningPage`가 받는 `AppService`와 `initialSeed`는 현재 계획 레이아웃에
  연결되지 않았다.
- 계획 프리셋용 DTO, protocol version, repository field는 존재하지 않는다.

## 이미 합의된 제품 흐름

- 프리셋은 계획 탭의 기능 그룹에서 만든다.
- 학생 탭의 `계획에 추가` 흐름에서 프리셋을 선택한다.
- 기본 프리셋이 있으면 선택 화면에 명시적으로 보여준다.
- 프리셋은 스캔 현재 상태, 정적 메타데이터, 사용자 목표, 총계 계산 결과,
  인벤토리 기반 부족량의 다섯 데이터 bucket을 섞지 않는다.

## 구현 전에 사용자에게 확정받을 항목

다음 항목은 화면과 저장 계약을 바꾸므로 추측하지 않는다.

1. 프리셋 값은 절대 목표인가, 단계별 상대 증가량인가?
2. 포함 필드는 레벨·성급·전용무기·스킬·장비 티어/레벨·애장품 중 어디까지인가?
3. 프리셋에서 비워 둔 필드는 현재값 유지인가, 목표 해제인가?
4. 이름 변경·복제·삭제·순서 변경·기본 지정과 내장 프리셋이 필요한가?
5. 학생 추가 시 선택을 필수로 할 것인가, 기본 프리셋을 빠르게 적용할 것인가?
6. 프리셋은 전역인가, 프로필별인가?
7. 이번 범위가 인메모리 UI 검증까지인가, 영속화와 실제 적용까지인가?
8. 계획 메인 Section 1의 진입 방식과 프리셋 제조 화면의 section 수는 무엇인가?

## 권장 작업 순서

### P0 — 계약

- 위 결정을 받고 한 페이지 상태 전이를 작성한다.
- 저장, 취소, 삭제, 기본 지정, 학생에게 적용하는 시점과 실패 처리를 명시한다.

### P1 — Studio

- 페이즈 편집기 JSON을 수정하지 말고 프리셋 제조 전용 Studio JSON을 만든다.
- 현재 모니터에서 창을 최대화한 `2560×1392`를 canonical viewport로 사용한다.
- content/form/list geometry를 먼저 확정하고 동작 버튼은 이후에 배치한다.

### P2 — 인메모리 모델

- 승인 전에는 repository goal DTO를 프리셋으로 재사용하지 않는다.
- 임시 모델이 필요하면 `id`, `name`, `isDefault`, `scope`, `version`,
  nullable target fields만 가진 `PlanPresetDraft` 같은 별도 타입으로 둔다.
- 인벤토리, 필요 재화, 부족량, 계산 결과는 프리셋 안에 저장하지 않는다.

### P3 — UI vertical slice

- 프리셋 목록, 선택 상태, 편집 폼, 미리보기를 먼저 만든다.
- 생성·복제·삭제·기본 지정·저장·취소는 승인된 상태 전이에 맞춰 추가한다.
- 80° facing edge의 법선 seam과 컨트롤 간격은 기본 12px를 사용한다.

### P4 — 계획 탭 연결

- 계획 메인의 정식 진입/복귀/취소 lifecycle을 연결한다.
- 편집 중 이탈, 미저장 변경, 삭제 복구 동작을 테스트한다.

### P5 — 학생 탭 적용

- 선택 필수 여부와 기본 프리셋 정책이 승인된 뒤에만 학생 탭 흐름에 연결한다.
- 적용 전 목표 요약을 검토할 수 있어야 한다.

### P6 — 영속화

- 전역/프로필 scope가 정해진 뒤 versioned protocol과 repository schema를 만든다.
- backend vertical slice, parity fixture, Flutter/Python 계약 테스트를 함께 추가한다.

## 시각·상호작용 계약

- maximize `2560×1392`를 기준으로 조정하고 다른 크기는 반응형 회귀로 확인한다.
- Studio 좌표는 시작점이며 런타임 bounds와 constraints가 최종 기준이다.
- 반복 항목의 bilateral path는 자기 bounds 안에서 만든다.
- fill, border, clip, hit test는 동일한 경로를 공유한다.
- section마다 glass와 lifted shadow를 한 번만 적용한다.
- 좁은 action은 아이콘과 tooltip/semantics를 사용한다.
- 전용 사선 scrollbar가 있으면 플랫폼 scrollbar painting을 끈다.
- intro/outro 벡터는 Flutter의 아래쪽 양수 Y를 반영한다.

## 하지 말아야 할 것

- `../v6`를 런타임 dependency로 import하지 않는다.
- 승인되지 않은 프리셋 저장 schema를 임의로 만들지 않는다.
- 기존 사용자 목표 schema 안에 프리셋을 바로 끼워 넣지 않는다.
- UI Component Studio의 이미지 preset과 육성 목표 preset을 혼동하지 않는다.
- 페이즈 편집기 Studio JSON과 위젯을 덮어써서 프리셋 화면으로 바꾸지 않는다.
- 사용자 변경이 섞인 파일을 whole-file rewrite하지 않는다.

## 검증 기준

현재 기준선은 다음과 같다.

- `flutter analyze` 통과
- 계획 화면 집중 35 tests 통과
- Flutter 전체 243 tests, `--concurrency=1` 통과
- Windows release build 통과

다음 세션에서는 변경 범위에 맞춰 다음 순서로 검증한다.

1. `flutter analyze`
2. 프리셋 제조 화면 집중 widget tests
3. 계획/학생 흐름 회귀 tests
4. `flutter test --concurrency=1`
5. protocol 변경 시 backend unit/contract tests
6. Windows release build
7. `codealmanac validate`
8. `git diff --check`
9. 최대화 실화면 사용자 확인

## 다음 세션의 첫 행동

코드를 수정하기 전에 “구현 전에 사용자에게 확정받을 항목”을 짧게 제시해 답을
받는다. 답을 상태 전이와 데이터 경계로 문서화한 다음 전용 Studio JSON을 만든다.
