# 계획 프리셋 관리 탭 다음 세션 Handoff

> 2026-08-05 첫 인메모리 vertical slice가 구현됐다. 계획-메인 Section 1의
> `프리셋 생성·관리`로 진입하며, 좌측 목록/CRUD 사다리꼴과 우측 다중 목표 편집
> 평행사변형을 사용한다. 기본 내장 프리셋은 제거됐고 repository/protocol 영속화는
> v6 사용자 데이터 연결 시점까지 보류한다. 미저장 상태에서 복귀하면 우측의 낮은
> 확인 평행사변형이 intro 80 / outro 260으로 나타난다.

## 목표

다음 세션은 계획-요소 제작 화면 옆의 **프리셋 관리 탭**을 설계하고 첫 vertical slice를
구현한다. 현재 Section 5의 프리셋 loader를 관리 UI로 오해하지 않는다. Section 5는 저장된
프리셋을 제작 draft에 적용하는 소비자이고, 다음 탭은 프리셋의 생성·편집·덮어쓰기·삭제 등
수명주기를 소유하는 생산자다.

이 문서는 `preset-builder-next-session-handoff-2026-07-31.md`를 대체한다. 7월 31일 문서에
남아 있던 다수의 제품 질문 중 절대 목표, 단계 승계, draft 덮어쓰기, 필드 범위와 계획-요소
화면 구조는 이미 확정·구현됐다.

## 시작할 때 반드시 읽을 문서

1. `AGENTS.md`
2. `README.md`
3. `docs/migration/v6-knowledge-baseline.md`
4. `almanac/workflows/p0-p6-workflow-status.md`
5. `almanac/design/plan-element-builder-lessons-2026-08-02.md`
6. `docs/migration/p2-planning-screen/plan-element-builder-contract-2026-07-31.md`
7. 이 handoff

프리셋 관리 UI가 사선 list나 새 Studio 문서를 사용한다면 추가로 읽는다.

- `almanac/design/section-template-studio.md`
- `almanac/design/responsive-diagonal-layout-policy.md`
- `almanac/design/plan-phase-editor-lessons-2026-07-31.md`

## 현재 source of truth

- 모델: `frontend/lib/ui/models/planning_models.dart`
- fixture와 적용 로직: `frontend/lib/ui/widgets/plan_element_builder.dart`
- 계획-요소 전체 배치: `frontend/lib/ui/studio/plan_starter_studio_layout.dart`
- 단계 카드 배치: `frontend/lib/ui/studio/preset_element_studio_layout.dart`
- Studio JSON:
  - `release/section-plan-starter.ba-section-studio.json`
  - `release/section-preset-element.ba-section-studio.json`
- 회귀 테스트: `frontend/test/plan_element_builder_test.dart`
- 진입/화면 전환: `frontend/lib/ui/pages/planning_page.dart`
- 관리 UI: `frontend/lib/ui/widgets/plan_preset_manager.dart`
- 관리 Studio projection:
  `frontend/lib/ui/studio/preset_management_studio_layout.dart`
- 관리 Studio JSON:
  `release/section-preset-management.ba-section-studio.json`
- 관리 회귀 테스트: `frontend/test/plan_preset_manager_test.dart`

## 현재 구현 상태

### 프리셋 모델

`PlanElementPreset`은 다음 네 필드만 가진 immutable 인메모리 DTO다.

- `id`
- `name`
- `isDefault`
- `List<Map<String, int>> stages`

version, 전역/프로필 scope, 생성·수정 시각, copy/rename/delete API, JSON wire, repository field는
없다. backend protocol이나 데이터베이스에도 프리셋 schema가 없다.

### 기본 fixture

`defaultPlanElementPresets`는 `plan_element_builder.dart` 안에 있다. 현재 `균형 육성`과
`최대 육성` fixture를 제공하며, 이는 저장된 사용자 프리셋이 아니다. 관리 탭을 구현할 때
fixture, 내장 preset, 사용자 preset의 ownership을 명확히 분리해야 한다.

### Section 5 loader

`PlanElementBuilder.presets`가 null이면 기본 fixture를 사용한다. Section 5는 preset 이름과
`기본` 표시를 가진 `OutlinedButton` 목록이며 선택하면 `_loadPreset`을 호출한다.

`_loadPreset`의 현재 계약:

1. 학생 현재값을 첫 baseline으로 둔다.
2. sparse stage의 미지정 값은 이전 snapshot에서 승계한다.
3. 목표는 이전 단계와 학생 현재값보다 낮아지지 않게 clamp한다.
4. 증가가 없는 완전 달성 단계는 제외한다.
5. 새 stage ID를 만들고 제작 draft 전체를 교체한다.
6. 적용할 단계가 하나도 없으면 현재값 한 단계로 fallback한다.

이 적용 로직은 관리 탭의 저장 모델과 분리한다. 관리 탭에서 학생 현재값을 preset 자체에
구워 넣으면 재사용 가능한 sparse 절대 목표라는 계약이 깨진다.

### 계획-요소 제작 화면

- Section 3: 학생 현재 상태
- Section 5: 프리셋 loader
- Section 6: 단계 편집
- Section 7: 미배정 결과

Section 6의 `_PlanPresetElementCard`는 private이다. 관리 탭에서 같은 카드 UI가 필요하다면
위젯 파일을 통째로 import하거나 복제하지 말고 public reusable boundary로 먼저 추출한다.

## 이미 확정된 제품 계약

- 프리셋은 복수 단계의 순서 있는 **절대 목표 snapshot** 묶음이다.
- 첫 단계의 미지정 필드는 적용 학생의 현재값을 유지한다.
- 이후 단계의 미지정 필드는 직전 단계 값을 승계한다.
- 프리셋을 적용하면 현재 제작 draft 전체를 덮어쓴다.
- 프리셋 저장도 기존 항목을 수정하는 경우 덮어쓰기 semantics를 사용한다.
- 한 번의 제작으로 복수 단계를 추가할 수 있다.
- 단계 순서는 엄격하며 사용자가 직접 순서를 재배치하지 않는다.
- 미보유 학생도 프리셋을 적용해 계획할 수 있다.
- 포함 가능한 현재 필드:
  - 학생 레벨
  - 전용무기 레벨
  - 인연 랭크
  - 학생·전용무기 성작
  - 네 스킬
  - 장비 1~3 티어·레벨과 애장품
  - HP·공격력·치유력 추가 능력치
  - 심상개화는 아직 잠금 표시만
- 인연 비용 아이템 메타데이터와 애장품 catalog 연결은 아직 완성되지 않았다.
- 프리셋 저장 UI는 계획-요소 Section 5가 아니라 별도 관리 탭/섹션에서 구현한다.

## 다음 세션 시작 전에 사용자에게 확인할 최소 질문

아래 항목은 아직 코드나 최신 계약에서 확정할 수 없다. 구현 전에 짧게 질문한다.

1. 관리 탭은 계획-요소 화면과 같은 상위 화면의 sibling tab인가, 계획 탭 내부의 별도 진입
   화면인가? 탭 헤더와 전환 motion도 함께 확정한다.
2. 첫 vertical slice의 범위는 인메모리 UI인가, 이번 세션부터 repository/protocol 영속화까지
   포함하는가?
3. 프리셋 scope는 전역인가, 프로필별인가?
4. 내장 fixture를 수정·삭제 불가 template로 유지할지, 사용자 프리셋으로 복제해서 편집하게
   할지 확정한다.
5. 관리 action 범위: 생성, 이름 변경, 복제, 삭제, 기본 지정 중 이번 slice에 포함할 항목을
   확정한다. 기존 preset 선택 후 저장은 덮어쓰기지만 삭제 확인과 undo 정책은 별도다.
6. 편집 중 다른 프리셋/탭으로 이동할 때 미저장 변경을 폐기·확인·자동 저장 중 어떻게 처리할지
   확정한다.
7. 관리 탭에서도 학생을 선택해 현재값 기반 preview를 보여줄지, 학생과 무관한 sparse 목표만
   편집할지 확정한다.

이 질문은 scope와 데이터 schema를 바꾸므로 임의로 추천안을 구현하지 않는다.

## 권장 첫 vertical slice

영속화가 명시적으로 승인되지 않았다면 다음 순서로 인메모리 UI부터 만든다.

### P0 — 상태 전이와 편집 모델

- `selectedPresetId`, `draft`, `isDirty`, `isBuiltIn`, `pendingDelete` 상태를 문서화한다.
- 신규 저장과 기존 항목 덮어쓰기를 분리한다.
- 적용용 immutable `PlanElementPreset`과 편집용 mutable/copyable draft를 구분한다.
- 저장 시 sparse stage normalization과 단조 증가 검증을 한 곳에서 수행한다.

### P1 — UI geometry

- 관리 탭 전용 Studio JSON을 새로 만든다. `section-plan-starter`나 페이즈 편집기 JSON을
  덮어쓰지 않는다.
- 목록, 편집 canvas, action 영역의 외곽 geometry부터 확정한다.
- canonical viewport는 최대화 `2560×1392`다.
- 반복 목록이 사선 rail을 따르면 row의 top/bottom에서 실제 rounded parent path를 샘플링한다.

### P2 — 재사용 경계 추출

- 필요하면 `_PlanPresetElementCard`와 target field helpers를 전용 public 파일로 추출한다.
- 기존 `PlanElementBuilder` call site와 테스트를 먼저 그대로 통과시킨다.
- 학생 현재값 표시와 preset sparse 값 편집을 같은 모델로 섞지 않는다.

### P3 — 인메모리 관리 UI

- preset 목록과 선택
- 신규 draft
- 이름과 단계 편집
- 기존 preset 덮어쓰기
- 승인된 경우 복제·삭제·기본 지정
- dirty 이동 보호

Section 5 loader와 동일한 `PlanElementPreset` 결과를 내보내 실제 적용 경로를 재사용한다.

### P4 — 계획-요소 연결

- 관리 탭에서 저장된 목록이 Section 5 loader에 즉시 반영되는지 확인한다.
- 선택 ID가 삭제·이름 변경·덮어쓰기 뒤 stale해지지 않게 한다.
- 프리셋 적용 뒤 사용자가 값을 수정했을 때 selected preset 표시를 유지할지 dirty 표시로
  바꿀지는 P0 결정대로 테스트한다.

### P5 — 영속화

사용자가 이번 범위에 포함한다고 명시한 경우에만 진행한다.

- scope와 version을 포함한 별도 protocol DTO를 만든다.
- 기존 goal/current/inventory/calculation bucket에 preset을 끼워 넣지 않는다.
- backend vertical slice와 repository migration을 추가한다.
- Dart/Python fixture와 process restart 복원 E2E를 함께 만든다.

## 데이터 경계와 주의사항

- 프리셋에는 스캔 현재 상태를 저장하지 않는다.
- 프리셋에는 계산된 필요 재화, shortage, inventory snapshot을 저장하지 않는다.
- 인연 비용 메타데이터 미연결을 0 비용으로 저장하지 않는다.
- 심상개화 잠금 상태를 구현된 target field처럼 직렬화하지 않는다.
- 학생별 적용 결과와 재사용 가능한 preset 정의를 같은 DTO로 쓰지 않는다.
- `defaultPlanElementPresets`를 영속 사용자 데이터로 오인하지 않는다.
- `release/*.ba-section-studio.json`은 local/ignored일 수 있어도 typed projection과 parity를
  함께 유지해야 한다.
- dirty worktree의 기존 변경을 보존하고 whole-file rewrite를 피한다.

## UI 시행착오 재발 방지

- fill·texture·outline owner와 clipped child owner를 분리한다. 같은 surface를 두 번 그리지 않는다.
- 이상적인 80도 polygon보다 실제 rounded path를 기준으로 rail과 content bounds를 계산한다.
- Studio 숫자만 전역 치환하지 말고 element/container ID 문맥을 포함해 patch한다.
- normalized placement를 viewport 비율만으로 추측하지 말고 runtime endpoint test를 만든다.
- 공용 위젯을 추출·수정하면 계획 집중 test뿐 아니라 학생 page의 작은 viewport도 실행한다.
- visual probe timeout 뒤에는 늦게 생성된 PNG와 `flutter_tester` process가 남았는지 확인한다.

상세 근거는 `almanac/design/plan-element-builder-lessons-2026-08-02.md`에 있다.

## 현재 검증 기준선

- 계획 요소·학생 Studio·학생 page 관련 75 tests 통과
- Flutter 전체 290 tests, `--concurrency=1` 통과
- `flutter analyze` 통과
- Windows release build 통과
- `codealmanac validate` 통과
- `git diff --check` 통과

다음 세션의 종료 gate:

1. 새 관리 탭 집중 widget tests
2. `frontend/test/plan_element_builder_test.dart`
3. 학생 탭 공용 위젯을 건드렸다면 `student_studio_layout_test.dart`와 `student_page_test.dart`
4. `flutter analyze`
5. `flutter test --concurrency=1`
6. protocol 변경 시 backend unit/contract/process tests
7. `flutter build windows --release`
8. `codealmanac validate`
9. `git diff --check`
10. 최대화 실화면 사용자 확인

## 다음 세션의 첫 행동

코드를 수정하기 전에 “다음 세션 시작 전에 사용자에게 확인할 최소 질문”을 제시한다. 답을
상태 전이와 scope 계약으로 먼저 기록한 다음, 관리 탭 전용 Studio geometry 또는 승인된
인메모리 모델부터 작업한다. 영속화는 명시적 승인 전에는 시작하지 않는다.
