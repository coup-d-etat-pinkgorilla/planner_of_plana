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
import 'package:ba_planner_v7/ui/models/growth_calculator_adapter.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_rules.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/models/student_filter_selection.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:ba_planner_v7/ui/widgets/plan_student_selector.dart';
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

Future<void> _selectFirstPlanStudent(WidgetTester tester) async {
  await _tapKey(tester, 'plan-student-selector-launch');
  final grid = tester.widget<StudentDiagonalGrid>(
    find.byKey(const ValueKey('plan-student-selector-grid')),
  );
  await tester.tap(
    find.byKey(ValueKey('student-${grid.students.first.studentId}')),
  );
  await tester.pump();
  await _tapKey(tester, 'plan-student-selector-confirm-selection');
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
  testWidgets('students-calculator', (tester) async {
    setGoldenViewport(tester);
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
    await expectGoldenScene(tester, 'students-calculator');
  }, variant: goldenPlatform);

  // --- 계획 메인 -------------------------------------------------------------
  testWidgets('plan-bottleneck', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openPlanning(tester, service);
    expect(
      find.byKey(const ValueKey('plan-section-3-1-bottleneck')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-bottleneck');
  }, variant: goldenPlatform);

  testWidgets('plan-by-phase', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openPlanning(tester, service);
    await _tapKey(tester, 'plan-resource-tab-byPhase');
    await expectGoldenScene(tester, 'plan-by-phase');
  }, variant: goldenPlatform);

  testWidgets('plan-overall', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openPlanning(tester, service);
    await _tapKey(tester, 'plan-resource-tab-overall');
    await expectGoldenScene(tester, 'plan-overall');
  }, variant: goldenPlatform);

  // --- 계획 하위 화면 ---------------------------------------------------------
  testWidgets('plan-phase-editor', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openPlanning(tester, service);
    await _tapKey(tester, 'plan-phase-editor-launch');
    expect(find.byKey(const ValueKey('plan-phase-editor')), findsOneWidget);
    await expectGoldenScene(tester, 'plan-phase-editor');
  }, variant: goldenPlatform);

  testWidgets('plan-student-selector', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openPlanning(tester, service);
    await _tapKey(tester, 'plan-student-selector-launch');
    expect(
      find.byKey(const ValueKey('plan-range-condition-section')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-student-selector');
  }, variant: goldenPlatform);

  testWidgets('plan-element-builder', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openPlanning(tester, service, presets: [goldenTestPreset()]);
    await _selectFirstPlanStudent(tester);
    await _tapKey(tester, 'plan-starter-preset-balanced-growth');
    expect(
      find.byKey(const ValueKey('plan-starter-return-to-plan')),
      findsOneWidget,
    );
    await expectGoldenScene(tester, 'plan-element-builder');
  }, variant: goldenPlatform);

  testWidgets('plan-preset-manager', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openPlanning(tester, service, presets: [goldenTestPreset()]);
    await _tapKey(tester, 'plan-preset-manager-launch');
    await expectGoldenScene(tester, 'plan-preset-manager');
  }, variant: goldenPlatform);

  // --- 계획 만들기 흐름(FE4-a1) ------------------------------------------------
  testWidgets('plan-flow-step1', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenPlanFlowMockAppService();
    addTearDown(service.dispose);
    await _openPlanning(tester, service);
    await _tapKey(tester, 'plan-scenario-create-launch');
    expect(find.byKey(const ValueKey('plan-flow-rail')), findsOneWidget);
    expect(find.byType(PlanStudentSelector), findsOneWidget);
    await expectGoldenScene(tester, 'plan-flow-step1');
  }, variant: goldenPlatform);

  testWidgets('plan-flow-step2', (tester) async {
    setGoldenViewport(tester);
    final service = GoldenPlanFlowMockAppService();
    addTearDown(service.dispose);
    await _openPlanning(tester, service, presets: [goldenTestPreset()]);
    await _tapKey(tester, 'plan-scenario-create-launch');
    final grid = tester.widget<StudentDiagonalGrid>(
      find.byKey(const ValueKey('plan-student-selector-grid')),
    );
    await tester.tap(
      find.byKey(ValueKey('student-${grid.students.first.studentId}')),
    );
    await tester.pump();
    await _tapKey(tester, 'plan-student-selector-confirm-selection');
    await _tapKey(tester, 'plan-starter-preset-balanced-growth');
    await tester.tap(find.byKey(const ValueKey('plan-starter-confirm')));
    // 초안 계산은 디바운스 Timer 뒤에 부른다.
    await tester.pump();
    await tester.pump(planFlowCalculationDebounce);
    await tester.pump();
    expect(find.byType(PlanElementBuilder), findsOneWidget);
    expect(find.text('48.2M'), findsOneWidget);
    expect(find.text('5종'), findsOneWidget);
    await expectGoldenScene(tester, 'plan-flow-step2');
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

  testWidgets('plan-scenario-compare', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    final scenarioId = await _openPlanningWithScenario(tester, service);
    await _tapKey(tester, 'plan-scenario-compare-launch');
    await tester.tap(
      find.byKey(const ValueKey('plan-compare-candidate-active-plan')),
    );
    await tester.tap(find.byKey(ValueKey('plan-compare-candidate-$scenarioId')));
    await tester.pump();
    await _tapKey(tester, 'plan-scenario-compare-confirm');
    await expectGoldenScene(tester, 'plan-scenario-compare');
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
