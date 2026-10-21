// F3c-5: Mock 튜토리얼 빈틈 메우기 — 계획 진입점 표 · 대본 읽기, 예시 시나리오 seed · 마키 값, 시나리오 목록 비교 담기
// (튜토리얼일 때만), 중복 등록 경고(프레임 뒤), 3단계 뒤 남은 후보 정리(임시 계정만), 튜토리얼이 꺼져 있으면 계획 탭 그대로.
// 1~10단계 실제 화면 동작 한 바퀴는 `tutorial_host_f3c3_test.dart`의 "Mock walkthrough"가 본다.
import 'dart:async';

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_tutorial_practice.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/navigation/app_navigation_intent.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_flow.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial_host/tutorial_session.dart';
import 'package:ba_planner_v7/ui/tutorial_targets/tutorial_hooks.dart';
import 'package:ba_planner_v7/ui/widgets/plan_scenario_list.dart';
import 'package:ba_planner_v7/ui/widgets/plan_tutorial_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _hold = Duration(milliseconds: 60);

/// 학생 후보 폐기(검토 거절) 횟수를 세는 Mock.
class _CountingService extends MockAppService {
  int discards = 0;

  @override
  Future<ScannerCandidate> reviewScannerCandidate(
    ScannerSession session,
    ScannerCandidate candidate,
    Map<String, dynamic> payload, {
    required bool approve,
    required String reason,
    Map<int, int>? relationshipRanks,
    Set<String>? confirmedFields,
  }) {
    if (!approve) discards += 1;
    return super.reviewScannerCandidate(
      session,
      candidate,
      payload,
      approve: approve,
      reason: reason,
      relationshipRanks: relationshipRanks,
      confirmedFields: confirmedFields,
    );
  }
}

Future<RepositoryProfile> _origin(MockAppService service) async =>
    (await service.listProfiles()).singleWhere((profile) => profile.selected);

Future<PracticeProfile> _createPractice(MockAppService service) async {
  final origin = await _origin(service);
  final state = await service.createPractice(
    PracticeCreateRequest(
      originProfileId: origin.id,
      expectedOriginRevision: origin.revision,
      idempotencyKey: 'f3c5-create',
    ),
  );
  return state.practice!;
}

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var index = 0; index < count * 10; index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _finishScene(WidgetTester tester, TutorialSession session) async {
  final index = session.flow!.flowIndex;
  while (session.flow?.phase == TutorialPhase.dialogue &&
      session.flow?.flowIndex == index) {
    session.flow!.advanceLine();
    await tester.pump();
  }
  await _frames(tester);
}

/// 선택 계정에 [names] 시나리오를 만든다(학생 하나, 한 페이즈).
Future<void> _seedScenarios(MockAppService service, List<String> names) async {
  final origin = await _origin(service);
  final state = await service.loadRepositoryState(origin.id);
  for (final (index, name) in names.indexed) {
    final list = await service.listScenarios(origin.id);
    await service.createScenario(
      profileId: origin.id,
      expectedRevision: list.revision,
      idempotencyKey: 'f3c5-seed-$index',
      name: name,
      description: '',
      baseProfileRevision: state.revision,
      document: PlanningDocument(
        id: 'f3c5-$index',
        name: name,
        kind: PlanningDocumentKind.scenario,
        phases: [
          PlanningDocumentPhase(
            id: 'f3c5-$index-phase',
            name: '1순위',
            stages: [
              PlanningDocumentStage(
                id: 'f3c5-$index-stage',
                studentId: 'aru',
                name: '목표',
                targets: {
                  for (final key in planningDocumentTargetKeys)
                    key: key == 'bond_rank' ? 1 : 0,
                  'level': 2,
                  'student_star': 1,
                  'ex_skill': 1,
                  'skill1': 1,
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 계획 화면을 [hooks] 아래에 띄우고 시나리오 목록을 연다.
Future<List<String>> _openListCompareIds(
  WidgetTester tester,
  MockAppService service,
  TutorialHooks hooks,
) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: TutorialHooksScope(
          hooks: hooks,
          child: PlanningPage(service: service, loadRepositoryPlan: true),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
  await tester.pumpAndSettle();
  final list = tester.widget<PlanScenarioListSection>(
    find.byType(PlanScenarioListSection),
  );
  final names = {
    for (final scenario in (await service.listScenarios(
      (await _origin(service)).id,
    )).scenarios)
      scenario.id: scenario.name,
  };
  return [for (final id in list.controller!.compareIds) names[id]!];
}

void main() {
  group('plan tutorial entry', () {
    test('scene modes cover every plan scene of the script', () {
      expect(planTutorialSceneModes.keys.toSet(), {
        for (final MapEntry(key: scene, value: section)
            in tutorialSceneSections.entries)
          if (section == AppSection.plan) scene,
      });
      expect(
        planTutorialSceneModes['plana-08'],
        PlanTutorialMode.students,
        reason: '08 계획 만들기 1(학생 고르기)',
      );
      expect(planTutorialFlowStep(PlanTutorialMode.goals), PlanFlowStep.goals);
      expect(
        planTutorialFlowStep(PlanTutorialMode.goalsMaki),
        PlanFlowStep.goals,
      );
      expect(planTutorialFlowStep(PlanTutorialMode.order), PlanFlowStep.order);
      expect(planTutorialFlowStep(PlanTutorialMode.save), PlanFlowStep.save);
      for (final mode in const [
        PlanTutorialMode.students,
        PlanTutorialMode.scenarioList,
        PlanTutorialMode.compare,
      ]) {
        expect(planTutorialFlowStep(mode), isNull);
      }
    });

    test('script values: scenario name, Maki tab, student ids', () {
      expect(planTutorialScenarioName(), '총력전 비나 대비');
      expect(planTutorialFocusName(PlanTutorialMode.goalsMaki), '마키');
      expect(planTutorialFocusName(PlanTutorialMode.goals), isNull);
      expect(planTutorialScenarioName(const {}), isNull);
    });

    test('entry request ids rise; clear drops the request', () {
      final entry = PlanTutorialEntry();
      var notified = 0;
      entry.addListener(() => notified += 1);
      entry.open(PlanTutorialMode.goals);
      final first = entry.request!;
      entry.open(PlanTutorialMode.goals);
      expect(entry.request!.id, greaterThan(first.id));
      expect(entry.request!.mode, PlanTutorialMode.goals);
      entry.clear();
      expect(entry.request, isNull);
      expect(notified, 3);
      entry.dispose();
      entry.open(PlanTutorialMode.order);
      expect(entry.request, isNull, reason: 'dispose 뒤 요청 무시');
    });

    testWidgets('without a tutorial session the outer navigation passes', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final intent = PlanNavigationIntent.students(const ['aru']);
      final seen = <PlanNavigationIntent?>[];
      await tester.pumpWidget(
        PlanTutorialNavigation(
          service: service,
          navigation: intent,
          builder: (context, navigation) {
            seen.add(navigation);
            return const SizedBox();
          },
        ),
      );
      expect(seen.single, same(intent));
      expect(
        PlanTutorialEntry.of(tester.element(find.byType(SizedBox))),
        isNull,
      );
    });
  });

  group('practice seed', () {
    test('practice account has the script example scenario', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final origin = await _origin(service);
      final practice = await _createPractice(service);
      expect((await service.listScenarios(origin.id)).scenarios, isEmpty);
      final list = await service.listScenarios(practice.profileId);
      expect(list.scenarios.map((scenario) => scenario.name), [
        tutorialPracticeExampleScenarioName,
      ]);
      final record = (await service.getScenario(
        practice.profileId,
        list.scenarios.single.id,
      )).scenario;
      expect(
        [
          for (final phase in record.document.phases)
            '${phase.name}: '
                '${[for (final stage in phase.stages) stage.studentId].join(' ')}',
        ],
        [
          '1순위: kanna_swimsuit maki mika',
          '2순위: shiroko_swimsuit himari_battle neru_school_uniform',
          '3순위: akane',
        ],
      );
      for (final stage in record.document.stages) {
        expect(stage.targets['skill2'], 10);
        expect(stage.targets['level'], 90);
      }
      // 대본 7-2b(M/M/1/1)가 될 수 있게 마키 강화 · 서브는 1이다.
      final state = await service.loadRepositoryState(practice.profileId);
      final maki = state.students.singleWhere(
        (student) => student.studentId == 'maki',
      );
      expect(maki.values['skill2'], 1);
      expect(maki.values['skill3'], 1);
      expect(maki.values['skill1'], 4);
    });

    test('reset puts exactly one example back', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final practice = await _createPractice(service);
      final reset = await service.resetPractice(
        PracticeResetRequest(
          profileId: practice.profileId,
          expectedRevision: practice.revision,
          idempotencyKey: 'f3c5-reset',
        ),
      );
      final list = await service.listScenarios(reset.practice!.profileId);
      expect(list.scenarios.map((scenario) => scenario.name), [
        tutorialPracticeExampleScenarioName,
      ]);
    });
  });

  group('scenario list compare slots', () {
    const names = ['다른 안', '비나 대비 · 한 번에 MAX', '총력전 비나 대비'];

    testWidgets('tutorial active: script scenarios fill the slots in order', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final hooks = TutorialHooks()..active.value = true;
      addTearDown(hooks.dispose);
      await _seedScenarios(service, names);
      expect(await _openListCompareIds(tester, service, hooks), [
        '총력전 비나 대비',
        '비나 대비 · 한 번에 MAX',
      ]);
    });

    testWidgets('tutorial off: slots stay empty', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final hooks = TutorialHooks();
      addTearDown(hooks.dispose);
      await _seedScenarios(service, names);
      expect(await _openListCompareIds(tester, service, hooks), isEmpty);
    });

    testWidgets('tutorial active but one script scenario missing: empty', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final hooks = TutorialHooks()..active.value = true;
      addTearDown(hooks.dispose);
      await _seedScenarios(service, names.take(2).toList());
      expect(await _openListCompareIds(tester, service, hooks), isEmpty);
    });
  });

  group('duplicate target warning', () {
    testWidgets('a target swapped within one frame does not warn', (
      tester,
    ) async {
      final hooks = TutorialHooks();
      addTearDown(hooks.dispose);
      Widget host(Key key) => Directionality(
        textDirection: TextDirection.ltr,
        child: TutorialHooksScope(
          hooks: hooks,
          child: TutorialTarget(
            key: key,
            id: 'swap',
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );
      await tester.pumpWidget(host(const ValueKey('old')));
      // 새 위젯이 먼저 등록되고 옛 위젯은 같은 프레임 끝에 떨어진다(계정 전환으로 탭을 다시 만드는 프레임).
      await tester.pumpWidget(host(const ValueKey('new')));
      await tester.pump();
      expect(hooks.registry.duplicateWarnings, isEmpty);
      expect(hooks.registry.ids.toList(), ['swap']);
    });
  });

  group('candidate cleanup after step 3', () {
    testWidgets('a real account under the scan controller is left alone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2560, 1392);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final service = _CountingService();
      addTearDown(service.dispose);
      final session = TutorialSession(service: service, completeHold: _hold);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        BAPlannerApp(
          service: service,
          showTitle: false,
          tutorial: true,
          tutorialSession: session,
        ),
      );
      await tester.pumpAndSettle();
      final origin = await _origin(service);
      unawaited(session.start(origin));
      await _frames(tester, 4);
      await _finishScene(tester, session); // 프라나 01
      await _finishScene(tester, session); // 프라나 02
      final hooks = session.hooks;
      await tester.tap(
        find.byKey(
          const ValueKey('home-connect-panel-row-$practiceVirtualTargetId'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
      await tester.pump();
      await tester.pump(_hold * 2);
      await _frames(tester);
      await _finishScene(tester, session); // 프라나 03
      expect(session.flow!.step!.id, '2');
      await tester.tap(find.byKey(const ValueKey('scan-pick-student-full')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
      for (
        var round = 0;
        round < 200 && session.flow!.phase == TutorialPhase.step;
        round++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pump(_hold * 2);
      await _frames(tester);
      await _finishScene(tester, session); // 프라나 04
      expect(session.flow!.step!.id, '3');
      final scan = session.scanSession.value!;
      expect(scan.candidates, isNotEmpty);
      // 스캔 컨트롤러를 진짜 계정으로 옮긴 뒤 3단계를 마친다 → 정리하지 않는다.
      await scan.selectProfile(origin);
      await tester.pump();
      expect(scan.profile!.id, origin.id);
      hooks.signals.emit(TutorialSignals.studentReviewApplied);
      await tester.pump(_hold * 2);
      await _frames(tester);
      expect(session.flow!.scene?.id, 'plana-05');
      expect(service.discards, 0);
      expect(session.clearedCandidates, 0);
      await _finishScene(tester, session);
      expect(session.flow!.step!.id, '4');
      expect(session.stepNote, isNull);
      expect(find.byKey(const ValueKey('tutorial-card-note')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
