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
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/scan_student_review_workspace.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

Future<GoldenMockAppService> _service() async {
  final service = GoldenMockAppService();
  addTearDown(service.dispose);
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

  testWidgets('students-grid', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openShell(tester, service);
    await _tapKey(tester, 'top-tab-students');
    expect(find.byKey(const ValueKey('student-page')), findsOneWidget);
    expect(find.byType(StudentDiagonalGrid), findsWidgets);
    await expectGoldenScene(tester, 'students-grid');
  }, variant: goldenPlatform);

  testWidgets('students-detail', (tester) async {
    setGoldenViewport(tester);
    final service = await _service();
    await _openShell(tester, service);
    await _tapKey(tester, 'top-tab-students');
    final grid = tester.widget<StudentDiagonalGrid>(
      find.byType(StudentDiagonalGrid).first,
    );
    await _tapKey(tester, 'student-${grid.students.first.studentId}');
    await expectGoldenScene(tester, 'students-detail');
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
