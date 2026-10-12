// FE1-g golden 기준선.
//
// 목적: 동작 보존 slice(FE1-b 80° 기하 공용화, FE2-a 등)가 화면을 바꾸지 않았음을
// golden diff 0으로 판정한다. 장면은 lib/에서 `tan(80…)` 인라인 계산이 있는 파일과
// 각도를 인자로 받는 사선 위젯 파일을 모두 한 번 이상 그리도록 골랐다.
// 파일 → 장면 대응표는 almanac/workflows/frontend-redesign-status.md의 FE1-g 절에 있다.
//
// PNG 생성(사용자 PC, Windows):  .\frontend\tool\fe_gate.ps1 -UpdateGoldens
// 비교:                          .\frontend\tool\fe_gate.ps1
//
// `golden` 태그: 2560×1392 렌더링이 CPU를 많이 써서, 실제 Python 프로세스를 띄우는
// E2E 테스트와 병렬로 돌면 그쪽 요청이 시간 초과로 실패했다(2026-10-06 gate 실행).
// fe_gate.ps1은 `--exclude-tags golden`과 `test/goldens`를 나눠서 차례로 돌린다.
@Tags(['golden'])
library;

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/kit/shortage_flyout.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_adapter.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_rules.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_goal_editor.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/models/student_filter_selection.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_rail.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:ba_planner_v7/ui/widgets/scan_student_review_workspace.dart';
import 'package:ba_planner_v7/ui/widgets/student_form_cycle.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

Future<GoldenMockAppService> _service() async {
  final service = GoldenMockAppService();
  addTearDown(service.dispose);
  return service;
}

/// 학생 장면용 mock: 학생 7명과 보유·계획 상태를 미리 저장한다.
Future<GoldenStudentMockAppService> _studentService() async {
  final service = GoldenStudentMockAppService();
  addTearDown(service.dispose);
  await service.seedStudentScene();
  return service;
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  expect(finder, findsOneWidget, reason: 'golden navigation key $key');
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openTitle(WidgetTester tester, AppService service) async {
  await tester.pumpWidget(
    goldenBoundary(BAPlannerApp(service: service, showTitle: true)),
  );
  await pumpUntilFound(tester, find.byKey(const ValueKey('title-settings')));
  await tester.pumpAndSettle();
  await finishStudentGridWarmup(tester, service);
  await tester.pumpAndSettle();
}

Future<void> _openShell(WidgetTester tester, AppService service) async {
  await tester.pumpWidget(goldenBoundary(BAPlannerApp(service: service)));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
}

Future<void> _openPlanning(
  WidgetTester tester,
  AppService service, {
  List<PlanElementPreset> presets = const [],
  bool loadRepositoryPlan = false,
}) async {
  await tester.pumpWidget(
    goldenMaterialHost(
      PlanningPage(
        service: service,
        initialPresets: presets,
        loadRepositoryPlan: loadRepositoryPlan,
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('planning-page')), findsOneWidget);
}

/// 계획 만들기 장면 mock(학생 장면 fixture + 고정 계산 결과).
Future<GoldenPlanFlowMockAppService> _planFlowService() async {
  final service = GoldenPlanFlowMockAppService();
  addTearDown(service.dispose);
  await service.seedStudentScene();
  return service;
}

/// 계획 탭 S1 "시나리오 생성"으로 계획 만들기 1단계를 연다.
Future<void> _openPlanFlow(
  WidgetTester tester,
  AppService service, {
  List<PlanElementPreset> presets = const [],
}) async {
  await _openPlanning(tester, service, presets: presets);
  await _tapKey(tester, 'plan-scenario-create-launch');
  expect(find.byKey(const ValueKey('plan-flow-rail')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('plan-flow-student-grid')),
    findsOneWidget,
  );
}

/// plan-flow-step3와 같은 세 명(호시노 2단계 · 아루 3단계 · 미보유 슌 2단계)으로 4단계 저장을 연다(FE4-e).
Future<void> _openPlanFlowSave(
  WidgetTester tester,
  GoldenPlanFlowMockAppService service,
) async {
  await _openPlanFlow(
    tester,
    service,
    presets: [goldenFlowStagePreset(), goldenFlowTwoStagePreset()],
  );
  for (final id in const ['hoshino', 'aru', 'shun_swimsuit']) {
    await _tapFlowCard(tester, id);
  }
  await _tapKey(tester, 'plan-flow-next');
  await _tapKey(tester, 'plan-flow-goal-preset-two-stage');
  await _tapKey(tester, 'plan-flow-goal-tab-aru');
  await _tapKey(tester, 'plan-flow-goal-preset-raid-three-stage');
  await _tapKey(tester, 'plan-flow-goal-tab-shun_swimsuit');
  await _tapKey(tester, 'plan-flow-goal-preset-two-stage');
  await _tapKey(tester, 'plan-flow-next');
  await _tapKey(tester, 'plan-flow-next');
  await tester.pump(planFlowCalculationDebounce);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('plan-flow-save-body')), findsOneWidget);
}

/// 1단계 B 그리드의 학생 카드를 누른다.
Future<void> _tapFlowCard(WidgetTester tester, String studentId) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('plan-flow-student-grid')),
      matching: find.byKey(ValueKey('student-$studentId')),
    ),
  );
  await tester.pump();
}

/// 시나리오 하나를 만든 뒤 활성 계획을 읽는 계획 화면을 연다.
Future<String> _openPlanningWithScenario(
  WidgetTester tester,
  GoldenMockAppService service,
) async {
  final profile = (await service.listProfiles()).firstWhere(
    (profile) => profile.selected,
  );
  final state = await service.loadRepositoryState(profile.id);
  final created = await service.createScenario(
    profileId: profile.id,
    expectedRevision: 0,
    idempotencyKey: 'fe1g-golden-scenario',
    name: '비교 후보',
    description: '',
    baseProfileRevision: state.revision,
    document: goldenScenarioDocument(
      'fe1g-golden-scenario',
      PlanningDocumentKind.scenario,
      level: 2,
    ),
  );
  await _openPlanning(tester, service, loadRepositoryPlan: true);
  return created.scenarioId;
}

/// 시나리오 목록 장면(FE5-a · FE5-b): 시나리오 다섯 개 · 이 장면의 활성 계획을 저장하고 목록을 연 뒤 "07 3단계
/// 우선순위"를 펼치고 02 · 07을 비교에 담는다. 미리보기(getScenario + compare)가 끝날 때까지 기다린다. 이름 → id.
Future<Map<String, String>> _openScenarioListScene(
  WidgetTester tester,
  GoldenScenarioListMockAppService service,
) async {
  final ids = await service.seedScenarioListScene();
  await _openPlanning(tester, service, loadRepositoryPlan: true);
  await _tapKey(tester, 'plan-scenario-list-launch');
  await _tapKey(tester, 'plan-scenario-row-${ids['07 3단계 우선순위']}');
  await _tapKey(tester, 'plan-scenario-compare-${ids['02 지원진 집중']}');
  await _tapKey(tester, 'plan-scenario-compare-${ids['07 3단계 우선순위']}');
  // 미리보기: 활성 계획(112M · 6종 · P1) → 07(73.8M · 7종 · P1), 학생 칩 세 가지.
  await pumpUntilFound(
    tester,
    find.byKey(const ValueKey('plan-scenario-preview-kpi-credits')),
  );
  await tester.pumpAndSettle();
  expect(
    find.descendant(
      of: find.byKey(const ValueKey('plan-scenario-preview-kpi-credits')),
      matching: find.text('73.8M'),
    ),
    findsOneWidget,
  );
  for (final (student, label) in const [
    ('aru', '이 시나리오에만'),
    ('ayane', '활성보다 낮은 목표'),
    ('hoshino', '활성 계획과 같음'),
  ]) {
    expect(
      find.descendant(
        of: find.byKey(
          ValueKey('plan-scenario-preview-student-$student-delta'),
        ),
        matching: find.text(label),
      ),
      findsOneWidget,
      reason: student,
    );
  }
  return ids;
}

/// 시나리오 보기 모드(07 3단계 우선순위)를 열고 S3 seg [label] 탭을 누른다(FE5-d).
Future<void> _openScenarioDetailTab(
  WidgetTester tester,
  GoldenScenarioListMockAppService service,
  String label,
) async {
  final ids = await _openScenarioListScene(tester, service);
  await _tapKey(tester, 'plan-scenario-open-${ids['07 3단계 우선순위']}');
  await pumpUntilFound(
    tester,
    find.byKey(const ValueKey('plan-scenario-detail-card-1')),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('plan-scenario-detail-tab')),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// 계획 홈 장면(FE5-c2): 활성 계획을 저장하고 읽어 Detail 홈을 연다(계산 대역 + 페이즈별 결과).
Future<void> _openActivePlanHome(WidgetTester tester) async {
  final service = GoldenActivePlanHomeMockAppService();
  addTearDown(service.dispose);
  await service.seedActivePlanHomeScene();
  await _openPlanning(tester, service, loadRepositoryPlan: true);
  await pumpUntilFound(
    tester,
    find.byKey(const ValueKey('plan-home-card-1')),
  );
  await tester.pumpAndSettle();
}

/// Detail 홈 S3 seg에서 [label] 탭을 누른다.
Future<void> _tapHomeTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(const ValueKey('plan-home-tab')),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadGoldenFonts);
  // FE3-e: 다중 폼 초상 교대 시계를 첫 폼(단계 0)에 고정한다(FD-064). 장면마다 같은 값이다.
  // 풀지 않는다(테스트 파일마다 isolate가 따로라 다른 테스트에 번지지 않는다).
  setUp(() => StudentFormClock.instance.freeze(0));

  // --- 타이틀·계정 -----------------------------------------------------------
  testWidgets('title', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openTitle(tester, service);
    expect(find.byKey(const ValueKey('title-brand-section')), findsOneWidget);
    await expectGoldenScene(tester, 'title');
  }, variant: goldenPlatform);

  testWidgets('account-manager', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openTitle(tester, service);
    await _tapKey(tester, 'title-settings');
    expect(
      find.byKey(const ValueKey('account-manager-section')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'account-manager');
  }, variant: goldenPlatform);

  testWidgets('account-editor', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openTitle(tester, service);
    await _tapKey(tester, 'title-settings');
    await _tapKey(tester, 'account-edit');
    expect(
      find.byKey(const ValueKey('account-editor-section')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'account-editor');
  }, variant: goldenPlatform);

  testWidgets('account-picker', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openTitle(tester, service);
    await _tapKey(tester, 'title-settings');
    await _tapKey(tester, 'account-edit');
    await _tapKey(tester, 'account-change-portrait');
    expect(
      find.byKey(const ValueKey('account-picker-section')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'account-picker');
  }, variant: goldenPlatform);

  // --- 셸·홈·학생 ------------------------------------------------------------
  testWidgets('home', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openShell(tester, service);
    await expectGoldenScene(tester, 'home');
  }, variant: goldenPlatform);

  // FE3-b·FE3-c: 학생 장면은 학생 10명 fixture(GoldenStudentMockAppService)를 쓴다.
  // 미보유·배지 2~3개 쌓기·긴 이름·인연 목표 있음/없음, 그리드 두 줄, S4 확장(결과 수·적용 필터·
  // 최근 본 학생)을 golden이 직접 본다.
  testWidgets('students-grid', (tester) async {
    setGoldenViewport(tester);
    final service = await _studentService();
    await _openShell(tester, service);
    await _tapKey(tester, 'top-tab-students');
    expect(find.byKey(const ValueKey('student-page')), findsOneWidget);
    expect(find.byType(StudentDiagonalGrid), findsWidgets);
    // 기본 선택(아루)은 인연 목표가 없다.
    expect(
      find.byKey(const ValueKey('student-detail-bond-target')),
      findsNothing,
    );
    // 최근 본 학생: 기본 선택 한 명.
    expect(find.byKey(const ValueKey('student-recent-aru')), findsOneWidget);
    await expectGoldenScene(tester, 'students-grid');
  }, variant: goldenPlatform);

  testWidgets('students-detail', (tester) async {
    setGoldenViewport(tester);
    final service = await _studentService();
    await _openShell(tester, service);
    await _tapKey(tester, 'top-tab-students');
    // 그리드와 다른 상태: 인연 목표가 있는 학생(아야네, 현재 24 → 목표 45)을 고른다.
    await _tapKey(
      tester,
      'student-${GoldenStudentMockAppService.bondTargetStudentId}',
    );
    expect(
      find.text(GoldenStudentMockAppService.bondTargetLabel),
      findsOneWidget,
    );
    // 최근 본 학생: 아야네(지금 선택) → 아루.
    expect(find.byKey(const ValueKey('student-recent-ayane')), findsOneWidget);
    expect(find.byKey(const ValueKey('student-recent-aru')), findsOneWidget);
    await expectGoldenScene(tester, 'students-detail');
  }, variant: goldenPlatform);

  testWidgets('students-grid-name-off', (tester) async {
    setGoldenViewport(tester);
    final service = await _studentService();
    await _openShell(tester, service);
    await _tapKey(tester, 'top-tab-students');
    // "학생 이름 표시"를 끄면 이름 줄을 접는다(FD-046 (a)).
    await _tapKey(tester, 'student-toggle-name-display');
    final grid = tester.widget<StudentDiagonalGrid>(
      find.byType(StudentDiagonalGrid).first,
    );
    expect(grid.showNames, isFalse);
    // 8열 그리드가 두 줄이라 접힌 행 피치(카드 + 3.84)가 장면에 보인다.
    expect(grid.students.length, greaterThan(grid.columns));
    await expectGoldenScene(tester, 'students-grid-name-off');
  }, variant: goldenPlatform);

  // FE3-e: 다중 폼 학생(슌(수영복))이 둘째 폼을 보이는 순간(시계 단계 1). students-grid와 같은 fixture다.
  testWidgets('students-grid-second-form', (tester) async {
    setGoldenViewport(tester);
    final service = await _studentService();
    await _openShell(tester, service);
    await _tapKey(tester, 'top-tab-students');
    StudentFormClock.instance.freeze(1);
    await tester.pump();
    final grid = tester.widget<StudentDiagonalGrid>(
      find.byType(StudentDiagonalGrid).first,
    );
    final shun = grid.students.firstWhere(
      (student) => student.studentId == 'shun_swimsuit',
    );
    expect(shun.isMultiForm, isTrue);
    expect(
      studentPortraitAssetAt(shun, StudentFormClock.instance.step),
      'assets/student_portraits/shun_swimsuit_1.png',
    );
    await expectGoldenScene(tester, 'students-grid-second-form');
  }, variant: goldenPlatform);

  // FE3-d2: 필터 모달(Student-Filter). 초안에 학교·역할·공격 타입 토글, 레벨 범위, 성급 범위, 일본 서버 전용
  // 제외를 넣는다. 머리 칩·"필터 · n"·학교 줄 학생 수가 장면에 보인다.
  testWidgets('students-filter-open', (tester) async {
    setGoldenViewport(tester);
    final service = await _studentService();
    await _openShell(tester, service);
    await _tapKey(tester, 'top-tab-students');
    await tester.tap(find.byKey(const ValueKey('student-open-filter')));
    await tester.pump();
    await tester.pump();
    final filter = tester
        .widget<StudentSectionLayout>(find.byType(StudentSectionLayout))
        .filterController!;
    filter.updateDraft(
      filter.draft!
          .toggle('school', 'Gehenna')
          .toggle('school', 'Abydos')
          .toggle('role', 'dealer')
          .toggle('attack_type', 'Explosive')
          .withRange(studentGrowthRangeRow('level')!, 70, 90)
          .withRange(studentGrowthRangeRow('star')!, 3, 6)
          .withHideJpOnly(true),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('student-filter-modal')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-filter-modal-chip-school-Gehenna')),
      findsOneWidget,
    );
    expect(find.text('필터 · 7'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('student-filter-chip-school-Gehenna')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'students-filter-open');
  }, variant: goldenPlatform);

  // FE3-f2a·f2b: 성장 계산기(Calc-Student). 학생 S1 "성장 계산기 열기"로 들어가 빠른 목표(스킬만 MAX)에
  // 레벨 90·장비 1 두 단계를 더한다. 머리말 제목·"← 학생" 칩, S1 계산기 버튼 묶음, S2 목표 행(바뀐
  // 칸 분홍)·바꾼 목표 칩, 크레딧 타일(보유 "스캔 없음" 빗금 + 9범주를 묶은 내역 막대 5줄)·재화 목록 6줄과
  // "더 보기"가 장면에 보인다. S3는 목표값(바뀐 칸 분홍, ★ 목표 테두리)과 "현재 …" 태그, S4는 선택 학생
  // 요약·"기준: 확정값" 칩·최근 계산(아루 한 칸)이다.
  // FE3-g: 인연 목표를 1 → 3으로 올려 인연 타일을 채운다(공유 fixture 사례 "아루 1→3, present 스캔 없음").
  // 필요 경험치 45, 선호 선물 (대) ×1 · 일반 선물 ×1(보유 미확인), 쓰다듬기 3회 · 최소 6시간, 인연 경고 1건.
  Future<void> openCalculatorScene(WidgetTester tester) async {
    final service = GoldenCalculatorMockAppService();
    addTearDown(service.dispose);
    await service.seedStudentScene();
    await _openShell(tester, service);
    await _tapKey(tester, 'top-tab-students');
    await _tapKey(tester, 'student-open-calculator');
    final state = tester
        .widget<StudentSectionLayout>(find.byType(StudentSectionLayout))
        .calculator!
        .state;
    state.applyQuickTarget(GrowthCalculatorQuickTarget.skills);
    state.setRowTarget(GrowthCalculatorRow.level, 90);
    state.setRowTarget(
      GrowthCalculatorRow.equipment1,
      state.rowTarget(GrowthCalculatorRow.equipment1) + 2,
    );
    state.setRowTarget(GrowthCalculatorRow.bond, 3);
    await tester.pump();
    await tester.pump(growthCalculatorDebounce);
    await tester.pump();
    expect(find.text('성장 계산기'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('page-header-back-chip')),
      findsOneWidget,
    );
    expect(find.text('18,420,000'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calculator-credit-breakdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calculator-current-tag-level')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('calculator-recent-aru')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('calculator-resource-more')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calculator-bond-option-preferredLarge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calculator-bond-warnings')),
      findsOneWidget,
    );
  }

  testWidgets('students-calculator', (tester) async {
    setGoldenViewport(tester);
    await openCalculatorScene(tester);
    await expectGoldenScene(tester, 'students-calculator');
  }, variant: goldenPlatform);

  // FE3-g: 선호 선물 (대)를 눌러 선물 목록 팝오버를 고정해 연다(고른 안 강조). 선물 1행(고풍스러운 달걀 공예품,
  // 1개 경험치 180 · 선호 ×3, ×1, 보유 빗금 + 미확인)과 합계 줄이 보인다.
  testWidgets('students-calculator-bond-popover', (tester) async {
    setGoldenViewport(tester);
    await openCalculatorScene(tester);
    await tester.tap(
      find.byKey(const ValueKey('calculator-bond-option-preferredLarge')),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('calculator-bond-popover-preferredLarge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calculator-bond-gift-Item_Icon_Favor_Lv2_3')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'students-calculator-bond-popover');
  }, variant: goldenPlatform);

  // --- 계획 메인(FE5-c2: 첫 화면 = 활성 계획 Detail 3섹션) ----------------------------
  // 시나리오 목록 장면의 활성 계획(P1 아야네 · 히나 · 케이 · 노아 · 호시노, P2 아야네 · 히나, P3 아야네)을 저장해 읽는다.
  // 계산 대역 기준 병목은 P1 아야네 1단계(네브라 최상급 −14)와 P2 아야네 2단계(파이스토스 −30 · 볼프세크 −8) 두 카드다.
  testWidgets('plan-bottleneck', (tester) async {
    setGoldenViewport(tester);
    await _openActivePlanHome(tester);
    expect(
      find.byKey(const ValueKey('plan-home-card-2')),
      findsOneWidget,
    );
    expect(find.text('병목 1 · 여기서 막힘'), findsOneWidget);
    expect(find.text('병목 2 · 여기서 막힘'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-home-kpis')),
      findsNothing,
    );
    await expectGoldenScene(tester, 'plan-bottleneck');
  }, variant: goldenPlatform);

  // FE5-d 시안 Scenario-Detail-Phase(비교 없음): 페이즈 카드 3장(P1 선택 → S2 P1 헤더 · 단계 강조), 크레딧 진입/필요/
  // 종료, 재화 타일 진입 · 필요 · 종료 + 충족 막대. 요약 행은 P1 네브라(최상급) 76/450(5명 중 0명만 완료).
  testWidgets('plan-by-phase', (tester) async {
    setGoldenViewport(tester);
    await _openActivePlanHome(tester);
    await _tapHomeTab(tester, '페이즈별');
    for (final number in const [1, 2, 3]) {
      expect(
        find.byKey(ValueKey('plan-home-phase-card-$number')),
        findsOneWidget,
        reason: 'P$number',
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-home-summary-byPhase-title')),
        matching: find.textContaining('P1에서 5명 중 0명만 완료'),
        matchRoot: true,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('plan-home-kpis')), findsNothing);
    await expectGoldenScene(tester, 'plan-by-phase');
  }, variant: goldenPlatform);

  // FE5-d 시안 Scenario-Detail-All(비교 없음): "재화 7종 · 한 행에 4", 크레딧 행 + 분야 그룹 3개(오파츠 · 노트 · BD ·
  // 장비 설계도), 마크 · 범례 · 활성 대비 칩 없음.
  testWidgets('plan-overall', (tester) async {
    setGoldenViewport(tester);
    await _openActivePlanHome(tester);
    await _tapHomeTab(tester, '전체');
    expect(
      find.byKey(const ValueKey('plan-home-overall-credits')),
      findsOneWidget,
    );
    for (final field in const ['ooparts', 'notes', 'equipment']) {
      expect(
        find.byKey(ValueKey('plan-home-overall-group-$field')),
        findsOneWidget,
        reason: field,
      );
    }
    expect(find.byKey(const ValueKey('plan-home-overall-legend')), findsNothing);
    await expectGoldenScene(tester, 'plan-overall');
  }, variant: goldenPlatform);

  // --- 계획 하위 화면 ---------------------------------------------------------
  // FE5-f1: 옛 계획 홈에서만 열리던 plan-phase-editor · plan-student-selector · plan-element-builder 장면 정의는 지웠다
  // (기준 PNG는 CF가 별도 삭제 커밋).
  testWidgets('plan-preset-manager', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openPlanning(tester, service, presets: [goldenTestPreset()]);
    // FE5-c2: 프리셋 관리는 시나리오 목록 S1 "프리셋 관리"에서 연다(새 계획 홈에는 옛 진입 버튼이 없다).
    await _tapKey(tester, 'plan-scenario-list-launch');
    await _tapKey(tester, 'plan-scenario-menu-presets');
    await expectGoldenScene(tester, 'plan-preset-manager');
  }, variant: goldenPlatform);

  // --- 계획 만들기 흐름(FE4-a1, FE4-b1에서 1단계 새 학생 고르기로 갱신) -----------------
  testWidgets('plan-flow-step1', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlow(tester, service);
    // 세 명: 긴 이름(말줄임), 아루, 미보유 + PLAN + JP(배지 셋). C는 목록 행, 그리드는 고른 순서 배지.
    for (final id in const ['hoshino', 'aru', 'shun_swimsuit']) {
      await _tapFlowCard(tester, id);
    }
    expect(find.text('3명 골랐습니다'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-flow-selected-shun_swimsuit')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-flow-step1');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step1-many', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlow(tester, service);
    // 여덟 명: C가 압축 그리드(순서 배지 · ×)와 정렬 세그먼트 · 경고 줄로 바뀐다(FD-077).
    for (final id in const [
      'aru',
      'ayane',
      'hoshino',
      'shun_swimsuit',
      'hina',
      'serika',
      'kei',
      'noa',
    ]) {
      await _tapFlowCard(tester, id);
    }
    expect(
      find.byKey(const ValueKey('plan-flow-selected-grid')),
      findsOneWidget,
    );
    expect(find.text('미보유 2명 · 이미 계획에 있는 학생 3명'), findsOneWidget);
    await expectGoldenScene(tester, 'plan-flow-step1-many');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step1-filter', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlow(tester, service);
    await _tapFlowCard(tester, 'aru');
    await tester.tap(find.byKey(const ValueKey('plan-flow-student-filter')));
    await tester.pump();
    await tester.pump();
    // 초안: 계획 칩 그룹 "계획에 없는 학생만" + 학교(시안 Flow-1-Students-Filter의 계획 칩 그룹 포함 팝업).
    await tester.tap(
      find.byKey(const ValueKey('student-filter-chip-plan-unplanned')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('student-filter-chip-school-Gehenna')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('plan-flow-student-filter-modal')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-flow-step1-filter');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step2', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlow(
      tester,
      service,
      presets: [goldenFlowStagePreset(), goldenTestPreset()],
    );
    // 세 명(아루 · 호시노 · 미보유 슌): 탭 줄은 고른 순서, 첫 학생(아루)부터 정한다.
    for (final id in const ['aru', 'hoshino', 'shun_swimsuit']) {
      await _tapFlowCard(tester, id);
    }
    await _tapKey(tester, 'plan-flow-next');
    expect(find.byKey(const ValueKey('plan-flow-goal-body')), findsOneWidget);
    // 3단계 프리셋 → 단계 카드 3장. 초안 계산(stage_results)은 디바운스 Timer 뒤에 부른다.
    await _tapKey(tester, 'plan-flow-goal-preset-raid-three-stage');
    await tester.pump();
    await tester.pump(planFlowCalculationDebounce);
    await tester.pump();
    // FE5-b: 계산 대역이 문서 의존이라 레일 크레딧은 이 초안의 단계 크레딧 합이다(고정 48.2M이 아니다).
    final flow = tester
        .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
        .flow;
    expect(flow.calculation?.credits, isNot(48200000));
    expect(find.text(planFlowCreditsLabel(flow)), findsOneWidget);
    expect(find.text('부족 1종'), findsOneWidget);
    expect(find.text('부족 2종'), findsOneWidget);
    expect(find.text('지금 가능'), findsOneWidget);
    await expectGoldenScene(tester, 'plan-flow-step2');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step2-saved', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await service.seedPresetScene();
    await _openPlanFlow(
      tester,
      service,
      presets: [goldenFlowStagePreset(), goldenTestPreset()],
    );
    // FE4-i: 1단계 C "내 그룹"(저장된 그룹, 목록에 없는 학생 1명은 고르지 않고 남긴다)으로 호시노·아루를 고른다.
    expect(
      find.byKey(const ValueKey('plan-flow-group-golden-group-count')),
      findsOneWidget,
    );
    await _tapKey(tester, 'plan-flow-group-golden-group');
    final flow = tester
        .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
        .flow;
    expect(flow.selectedStudentIds, ['hoshino', 'aru']);
    await _tapKey(tester, 'plan-flow-next');
    // 저장된 프리셋(단계 이름 포함)이 인메모리 프리셋 앞에 있다. 적용하면 카드 이름이 저장된 단계 이름이다.
    await _tapKey(tester, 'plan-flow-goal-preset-stored:golden-raid');
    await tester.pump();
    await tester.pump(planFlowCalculationDebounce);
    await tester.pump();
    expect(find.text('성장 기반'), findsWidgets);
    expect(
      find.byKey(
        const ValueKey('plan-flow-goal-aside-preset-stored:golden-raid-rename'),
      ),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-flow-step2-saved');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step2-more', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlow(tester, service, presets: [goldenFlowStagePreset()]);
    for (final id in const ['aru', 'shun_swimsuit']) {
      await _tapFlowCard(tester, id);
    }
    await _tapKey(tester, 'plan-flow-next');
    // 아루는 한 번에 MAX(완료), 미보유 슌은 직접 입력 1단계에서 레벨을 올리고 "더 보기"를 연다(FD-072·FD-076).
    await _tapKey(tester, 'plan-flow-goal-mode-max');
    await _tapKey(tester, 'plan-flow-goal-tab-shun_swimsuit');
    final nudge = find.byWidgetPredicate(
      (widget) =>
          widget is KeyedSubtree &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.endsWith('-level-nudge'),
    );
    for (var count = 0; count < 3; count++) {
      await tester.tap(
        find.descendant(of: nudge, matching: find.byType(KitPressable)).first,
      );
      await tester.pump();
    }
    final more = find.byWidgetPredicate(
      (widget) =>
          widget is KitPressable &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.endsWith('-more'),
    );
    await tester.tap(more);
    await tester.pump();
    await tester.pump(planFlowCalculationDebounce);
    await tester.pump(planFlowGoalPropagationHighlight);
    expect(find.text('모집 필요'), findsWidgets);
    expect(find.text('더 보기 · 카드에 없는 목표'), findsOneWidget);
    await expectGoldenScene(tester, 'plan-flow-step2-more');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step3', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlow(
      tester,
      service,
      presets: [goldenFlowStagePreset(), goldenFlowTwoStagePreset()],
    );
    // 세 명(호시노 2단계 · 아루 3단계 · 미보유 슌 2단계) = 단계 7개.
    for (final id in const ['hoshino', 'aru', 'shun_swimsuit']) {
      await _tapFlowCard(tester, id);
    }
    await _tapKey(tester, 'plan-flow-next');
    await _tapKey(tester, 'plan-flow-goal-preset-two-stage');
    await _tapKey(tester, 'plan-flow-goal-tab-aru');
    await _tapKey(tester, 'plan-flow-goal-preset-raid-three-stage');
    await _tapKey(tester, 'plan-flow-goal-tab-shun_swimsuit');
    await _tapKey(tester, 'plan-flow-goal-preset-two-stage');
    await _tapKey(tester, 'plan-flow-next');
    // FE4-d1: 칸 보드가 n단계를 n순위 칸에 넣는다(3칸). 호시노 2단계 카드를 고른다.
    expect(find.byKey(const ValueKey('plan-flow-order-body')), findsOneWidget);
    final flow = tester
        .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
        .flow;
    expect(flow.draft.stageCount, 7);
    expect(flow.draft.phases.map((phase) => phase.name), [
      '1순위',
      '2순위',
      '3순위',
    ]);
    final hoshinoSecond = flow.draft.stagesByStudent['hoshino']![1].id;
    await _tapKey(tester, 'plan-flow-order-card-$hoshinoSecond');
    await tester.pump();
    await tester.pump(planFlowCalculationDebounce);
    await tester.pump();
    // 상태 배지(FD-035): 병목 단계(호시노 1·2)는 부족, 같은 재화를 뒤에서 또 쓰는 아루 1~3은 막힘(3칸 머리도
    // 막힘), 미보유 슌은 모집 필요.
    expect(find.text('부족'), findsNWidgets(2));
    expect(find.text('막힘'), findsNWidgets(4));
    expect(find.text('모집 필요'), findsNWidgets(2));
    await expectGoldenScene(tester, 'plan-flow-step3');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step3-deferred', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlow(
      tester,
      service,
      presets: [goldenFlowStagePreset(), goldenFlowTwoStagePreset()],
    );
    // plan-flow-step3와 같은 세 명(호시노 2단계 · 아루 3단계 · 미보유 슌 2단계).
    for (final id in const ['hoshino', 'aru', 'shun_swimsuit']) {
      await _tapFlowCard(tester, id);
    }
    await _tapKey(tester, 'plan-flow-next');
    await _tapKey(tester, 'plan-flow-goal-preset-two-stage');
    await _tapKey(tester, 'plan-flow-goal-tab-aru');
    await _tapKey(tester, 'plan-flow-goal-preset-raid-three-stage');
    await _tapKey(tester, 'plan-flow-goal-tab-shun_swimsuit');
    await _tapKey(tester, 'plan-flow-goal-preset-two-stage');
    await _tapKey(tester, 'plan-flow-next');
    final flow = tester
        .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
        .flow;
    final aru = flow.draft.stagesByStudent['aru']!;
    final hoshinoSecond = flow.draft.stagesByStudent['hoshino']![1].id;
    // FE4-f1: 아루 3단계를 "나중에" 칸으로, 아루 1단계 → 호시노 2단계를 직접 선행(분홍 점선)으로 잇는다.
    expect(flow.moveStage(aru[2].id, phaseId: planFlowDeferredLaneId), isNull);
    expect(
      flow.addPrerequisite(stageId: hoshinoSecond, requiresStageId: aru[0].id),
      isNull,
    );
    await tester.pump();
    await _tapKey(tester, 'plan-flow-order-card-$hoshinoSecond');
    await tester.pump();
    await tester.pump(planFlowCalculationDebounce);
    await tester.pump();
    expect(flow.draft.deferredStageIds, [aru[2].id]);
    expect(flow.orderIssues, isEmpty);
    expect(
      find.byKey(
        const ValueKey('plan-flow-order-lane-$planFlowDeferredLaneId'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('plan-flow-order-aside-prerequisite-${aru[0].id}')),
      findsOneWidget,
    );
    expect(find.text('직접 이은 선행 조건'), findsOneWidget);
    await expectGoldenScene(tester, 'plan-flow-step3-deferred');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step4', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlowSave(tester, service);
    // FE4-e: B는 페이즈 P1~P3 · 활성 계획 비교 타일 · 크게 늘어나는 재화, C는 3지선다(시나리오로 저장 고름) ·
    // 패널 안 이름 · 저장한 뒤 토글 2개. A primary 글자는 C 선택과 같다.
    expect(find.byKey(const ValueKey('plan-flow-save-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-flow-save-aside')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-flow-save-compare-fulfillment')),
      findsOneWidget,
    );
    expect(find.text('새 시나리오 1'), findsOneWidget);
    // FE4-i: 비교 대역은 계산 대역과 같은 기준이다. 시나리오로 저장 대상이면 레일의 필요 크레딧·부족 재화 종 수
    // (초안 계산)와 비교 b쪽 값이 같다.
    final flow = tester
        .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
        .flow;
    final calculation = flow.calculation!;
    final compared = await service.compareScenarios(
      currentStudents: flow.context.currentStudentsWire,
      inventory: flow.context.inventoryWire,
      documentA: GoldenStudentMockAppService.activePlanDocument(),
      documentB: PlanFlowDocumentBoundary.toPlanDocument(
        flow.draft,
        id: 'golden-compare-check',
        name: '계획 만들기 초안',
      ),
    );
    expect(compared.comparison['credits_b'], calculation.credits);
    expect(
      compared.comparison['known_shortage_type_count_b'],
      calculation.shortageKinds,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-flow-save-compare-credits')),
        matching: find.textContaining('→ ${planFlowCreditsLabel(flow)}'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-flow-save-compare-shortage')),
        matching: find.textContaining('→ ${planFlowShortageLabel(flow)}'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<RailButton>(find.byKey(const ValueKey('plan-flow-next')))
          .semanticLabel,
      '시나리오로 저장',
    );
    await expectGoldenScene(tester, 'plan-flow-step4');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step4-append', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlowSave(tester, service);
    // 활성 계획에 페이즈로 추가: 활성 P1·P2 뒤 P3~P5, 비교는 활성 + 새 페이즈 병합 문서 기준(FD-080).
    await _tapKey(tester, 'plan-flow-save-target-appendPhases');
    expect(find.text('지금 P2 뒤에 P3~P5로 붙입니다'), findsOneWidget);
    expect(
      tester
          .widget<RailButton>(find.byKey(const ValueKey('plan-flow-next')))
          .semanticLabel,
      '활성 계획에 페이즈로 추가',
    );
    // P4(2순위) 행을 눌러 필요 재화 팝오버를 고정한다(앞 페이즈에서 쓰고 남은 양 기준).
    final flow = tester
        .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
        .flow;
    await _tapKey(tester, 'plan-flow-save-phase-${flow.draft.phases[1].id}');
    expect(find.text('앞 페이즈에서 쓰고 남은 양 기준입니다'), findsOneWidget);
    await expectGoldenScene(tester, 'plan-flow-step4-append');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step3-many', (tester) async {
    setGoldenViewport(tester);
    final service = await _planFlowService();
    await _openPlanFlow(tester, service, presets: [goldenFlowManyPreset()]);
    // 열 명 × 3단계 = 단계 30개. 12개를 넘어 3단계가 작게 보기로 열린다(FE4-d2).
    for (final id in const [
      'hoshino',
      'aru',
      'shun_swimsuit',
      'ayane',
      'hina',
      'serika',
      'kei',
      'hasumi',
      'nagusa',
      'noa',
    ]) {
      await _tapFlowCard(tester, id);
    }
    await _tapKey(tester, 'plan-flow-next');
    await _tapKey(tester, 'plan-flow-goal-preset-many-three');
    await _tapKey(tester, 'plan-flow-goal-apply-all');
    await _tapKey(tester, 'plan-flow-next');
    expect(
      find.byKey(const ValueKey('plan-flow-order-compact-board')),
      findsOneWidget,
    );
    final flow = tester
        .widget<PlanFlowWorkspace>(find.byType(PlanFlowWorkspace))
        .flow;
    expect(flow.draft.stageCount, 30);
    expect(flow.draft.phases, hasLength(3));
    expect(find.text('단계 30개'), findsOneWidget);
    // 호시노 2단계 칩을 골라 펼친다: 호시노 1 → 2 → 3 선만 그리고 나머지 칩은 흐리게.
    final hoshinoSecond = flow.draft.stagesByStudent['hoshino']![1].id;
    await _tapKey(tester, 'plan-flow-order-chip-$hoshinoSecond');
    await tester.pump();
    await tester.pump(planFlowCalculationDebounce);
    await tester.pump();
    expect(
      find.byKey(ValueKey('plan-flow-order-card-$hoshinoSecond')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-flow-order-selection')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-flow-step3-many');
  }, variant: goldenPlatform);

  // --- 시나리오 ---------------------------------------------------------------
  testWidgets('plan-scenario-list', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openPlanningWithScenario(tester, service);
    await _tapKey(tester, 'plan-scenario-list-launch');
    expect(
      find.byKey(const ValueKey('plan-scenario-list-motion')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-scenario-list');
  }, variant: goldenPlatform);

  // FE5-a 시안 Scenario-List 상태: 시나리오 다섯 개(하나는 저장 시점과 다름), "07 3단계 우선순위" 행 펼침, 비교 3/4
  // (A 활성 계획 + 02 · 07). FE5-b: 미리보기 S3가 활성 계획 대비 KPI · 학생 · 단계 · 분야별 부족으로 채워진다(계산 대역).
  testWidgets('plan-scenario-list-expanded', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenScenarioListMockAppService();
    addTearDown(service.dispose);
    final ids = await _openScenarioListScene(tester, service);
    expect(find.text('3 / 4'), findsOneWidget);
    expect(
      find.byKey(
        ValueKey('plan-scenario-delete-${ids['07 3단계 우선순위']}'),
      ),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-scenario-list-expanded');
  }, variant: goldenPlatform);

  // FE5-b 시안 Scenario-List의 부족 재화 팝오버(`.shw.open`): 위 장면에서 "부족 재화" KPI를 눌러 연다(FD-090).
  testWidgets('plan-scenario-list-shortage', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenScenarioListMockAppService();
    addTearDown(service.dispose);
    await _openScenarioListScene(tester, service);
    await _tapKey(tester, 'plan-scenario-preview-kpi-shortage');
    expect(find.byType(GroupedShortageRow), findsNWidgets(7));
    expect(find.text('부족 재화 7종'), findsOneWidget);
    await expectGoldenScene(tester, 'plan-scenario-list-shortage');
  }, variant: goldenPlatform);

  // FE5-c1 시안 Scenario-Detail-Bottleneck 상태: 위 장면에서 "07 3단계 우선순위"를 열어 보기 모드(병목 탭, 병목 1 선택).
  // 미리보기와 같은 비교 응답(캐시)으로 그린다. 계산 대역에서 병목은 P1 아루 1단계(네브라 최상급 −14)와 P2 아루
  // 2단계(파이스토스 −30 · 볼프세크 −8) 두 카드이고, 단계 상태는 아루 1 · 2단계가 여기서 막힘, 나머지는 앞 단계 대기다.
  testWidgets('plan-scenario-detail-bottleneck', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenScenarioListMockAppService();
    addTearDown(service.dispose);
    final ids = await _openScenarioListScene(tester, service);
    await _tapKey(tester, 'plan-scenario-open-${ids['07 3단계 우선순위']}');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('plan-scenario-detail-card-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-scenario-detail-card-2')),
      findsOneWidget,
    );
    // FE5-c2: 같은 활성 계획을 쓰는 Detail 홈이 화면 밖에 남아 있으므로 보기 모드 안에서만 찾는다.
    final detailView = find.byKey(const ValueKey('plan-scenario-detail-view'));
    for (final label in const ['병목 1 · 여기서 막힘', '병목 2 · 여기서 막힘']) {
      expect(
        find.descendant(of: detailView, matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(find.text('활성 계획과 다른 단계 3'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-scenario-detail-kpi-finishing')),
        matching: find.text('0 / 3'),
      ),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-scenario-detail-bottleneck');
  }, variant: goldenPlatform);

  // FE5-d 시안 Scenario-Detail-Phase(비교 있음): 위 보기 모드에서 페이즈별 탭. 07 시나리오 페이즈 카드 3장(P1 선택,
  // P2 카드는 타일이 많아 패널 아래로 이어진다), 타일 활성 대비 칩(재화 줄 단위 FD-038 (c), 아루 엘레프 "이 시나리오에만"),
  // 요약 행 칩 "활성보다 … 부족", KPI 4칸 그대로.
  testWidgets('plan-scenario-detail-phase', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenScenarioListMockAppService();
    addTearDown(service.dispose);
    await _openScenarioDetailTab(tester, service, '페이즈별');
    expect(
      find.byKey(const ValueKey('plan-scenario-detail-phase-card-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-scenario-detail-kpis')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-scenario-detail-phase');
  }, variant: goldenPlatform);

  // FE5-d 시안 Scenario-Detail-All(비교 있음): 전체 탭, 한 행에 4, 범례 · 마크(= / ±n / 신규) · "활성 a% → b%" 칩.
  testWidgets('plan-scenario-detail-all', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenScenarioListMockAppService();
    addTearDown(service.dispose);
    await _openScenarioDetailTab(tester, service, '전체');
    expect(
      find.byKey(const ValueKey('plan-scenario-detail-overall-legend')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-scenario-detail-summary-overall-delta')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-scenario-detail-all');
  }, variant: goldenPlatform);

  testWidgets('plan-scenario-compare', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    final scenarioId = await _openPlanningWithScenario(tester, service);
    // FE5-c2: A↔B 비교는 시나리오 목록 "나란히 비교"(활성 계획 + 담은 시나리오 하나)로 연다. 비교 화면 S1은 목록으로 ·
    // 활성 계획으로 메뉴다.
    await _tapKey(tester, 'plan-scenario-list-launch');
    await _tapKey(tester, 'plan-scenario-compare-$scenarioId');
    await _tapKey(tester, 'plan-scenario-compare-run');
    expect(
      find.byKey(const ValueKey('plan-comparison-menu')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-scenario-compare');
  }, variant: goldenPlatform);

  // FE5-e 시안 Scenario-Compare: 목록 장면(02 · 07을 담음)에서 04(저장 시점과 다름)를 더 담아 4열 비교를 연다.
  // 열 A 활성 계획(기준, 파랑) · B 02 · C 07 · D 04(stale 칩), 보기 토글은 시안 기본(최고 값 강조 · ± 표시 켬).
  testWidgets('plan-scenario-compare-4', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenScenarioListMockAppService();
    addTearDown(service.dispose);
    final ids = await _openScenarioListScene(tester, service);
    await _tapKey(tester, 'plan-scenario-compare-${ids['04 공격대 핵심']}');
    await _tapKey(tester, 'plan-scenario-compare-run');
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('plan-compare-cell-active-plan-credits')),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-compare-cell-active-plan-credits')),
        matching: find.text('112M'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-compare-base-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('plan-compare-stale-${ids['04 공격대 핵심']}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('plan-compare-column-${ids['02 지원진 집중']}')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-scenario-compare-4');
  }, variant: goldenPlatform);

  // --- 스캔 검토(스캐너 세션 소유 위젯, 그리기만 한다) --------------------------
  testWidgets('scan-student-review', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    final catalogList = await service.listStudents();
    StudentCatalogEntry entry(String id) => catalogList.firstWhere(
      (item) => item.studentId == id,
      orElse: () => StudentCatalogEntry.fallback(id),
    );
    final candidates = [
      ScannerCandidate(
        id: 'golden-aru',
        sessionId: 'golden-session',
        generation: 1,
        revision: 1,
        kind: ScannerKind.student,
        payload: const {
          'version': 1,
          'student_id': 'aru',
          'values': {'level': 90, 'bond_rank': 20, 'weapon_level': 60},
        },
        evidence: const [
          ScannerFieldEvidence(
            field: 'bond_rank',
            status: 'uncertain',
            source: 'fixture',
          ),
        ],
        reviewRequired: true,
        approved: false,
      ),
      ScannerCandidate(
        id: 'golden-hoshino',
        sessionId: 'golden-session',
        generation: 1,
        revision: 1,
        kind: ScannerKind.student,
        payload: const {
          'version': 1,
          'student_id': 'hoshino',
          'values': {'level': 80},
        },
        evidence: const [],
        reviewRequired: false,
        approved: false,
      ),
    ];
    await tester.pumpWidget(
      goldenMaterialHost(
        ScanStudentReviewWorkspace(
          candidates: candidates,
          currentStudents: {
            'hoshino': ConfirmedStudentState.fromValues('hoshino', {
              'level': 70,
            }),
          },
          catalog: {'aru': entry('aru'), 'hoshino': entry('hoshino')},
          busyCandidateIds: const {},
          candidateErrors: const {},
          singleScan: false,
          onRevalidate: (_, _, _, _) async {},
          onHold: (_) async {},
          onDiscard: (_) async {},
          onApply: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectGoldenScene(tester, 'scan-student-review');
  }, variant: goldenPlatform);
}
