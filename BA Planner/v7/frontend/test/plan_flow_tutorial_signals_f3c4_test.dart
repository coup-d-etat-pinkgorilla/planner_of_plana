// F3c-4: 계획 만들기 흐름의 튜토리얼 신호 5개(F3a 대본 7-1 · 7-2b · 7-2c · 7-3 · 7-5, F3c-2 "없음" 4 + 7-1 조건)와 대본 ↔
// F3c-1 seed id 대조. 조건은 대본 카드 문장에서 읽는다(사용자 결정 2026-10-21).
import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_tutorial_practice.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/planning_growth_rules.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/tutorial/tutorial_script.dart';
import 'package:ba_planner_v7/ui/tutorial_targets/tutorial_hooks.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_tutorial_watch.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 대본 학생 이름 → 카탈로그 id(대조 표의 기대값).
const _scriptIds = {
  '아카네': 'akane',
  '칸나(수영복)': 'kanna_swimsuit',
  '마키': 'maki',
  '미카': 'mika',
  '히마리(무장)': 'himari_battle',
  '시로코(수영복)': 'shiroko_swimsuit',
  '네루(교복)': 'neru_school_uniform',
};

const _planSignals = [
  TutorialSignals.planStudentsConfirmed,
  TutorialSignals.planMakiStage1Set,
  TutorialSignals.planMakiStage2Set,
  TutorialSignals.planRanksPlaced,
  TutorialSignals.planLaterMoved,
];

Future<PlanFlowContext> _context(MockAppService service) async {
  final profile = (await service.listProfiles()).firstWhere(
    (profile) => profile.selected,
  );
  return PlanFlowContext(
    repositoryState: await service.loadRepositoryState(profile.id),
    catalog: {
      for (final entry in await service.listStudents()) entry.studentId: entry,
    },
  );
}

PlanningStudentSeed _seed(String id) => PlanningStudentSeed(
  handoffId: 'seed-$id',
  studentId: id,
  metadata: const {},
  currentValues: const {},
);

Map<String, int?> _skills(int ex, int s1, int s2, int s3) => {
  'ex_skill': ex,
  'skill1': s1,
  'skill2': s2,
  'skill3': s3,
};

/// 대본대로 다 된 초안. [change]로 한 곳씩 어긋나게 만든다.
PlanFlowDraft _draft({
  List<String>? students,
  Map<String, int?>? makiStage1,
  Map<String, int?>? makiStage2,
  bool withMakiStage2 = true,
  List<List<String>>? ranks,
  List<String>? deferred,
}) {
  final ids = students ?? _scriptIds.values.toList();
  return PlanFlowDraft(
    students: [for (final id in ids) _seed(id)],
    stagesByStudent: {
      for (final id in ids)
        id: [
          PlanFlowStageDraft(
            id: '$id-1',
            name: '1단계',
            targets: id == 'maki'
                ? (makiStage1 ?? _skills(5, 10, 1, 1))
                : const {'level': 90},
          ),
          if (id == 'maki' && withMakiStage2)
            PlanFlowStageDraft(
              id: 'maki-2',
              name: '2단계',
              targets: makiStage2 ?? _skills(5, 10, 7, 7),
            ),
        ],
    },
    phases: [
      for (final (index, lane)
          in (ranks ??
                  [
                    ['kanna_swimsuit-1', 'maki-1', 'mika-1'],
                    ['shiroko_swimsuit-1', 'himari_battle-1'],
                    ['akane-1'],
                  ])
              .indexed)
        PlanFlowPhase(
          id: 'phase-${index + 1}',
          name: planFlowDefaultPhaseName(index),
          stageIds: lane,
        ),
    ],
    deferredStageIds: deferred ?? const ['neru_school_uniform-1', 'maki-2'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the conditions are read from the script cards', () {
    final script = PlanFlowTutorialScript.parse();
    expect(script.students, _scriptIds.keys.toList());
    final stage1 = script.stageGoals[TutorialSignals.planMakiStage1Set]!;
    expect(stage1.card, const PlanFlowTutorialCard('마키', 1));
    // M = 최대(EX 5 · 스킬 10).
    expect(stage1.values, {
      'ex_skill': planElementTargetMaximums['ex_skill'],
      'skill1': planElementTargetMaximums['skill1'],
      'skill2': 1,
      'skill3': 1,
    });
    final stage2 = script.stageGoals[TutorialSignals.planMakiStage2Set]!;
    expect(stage2.card, const PlanFlowTutorialCard('마키', 2));
    expect(stage2.values, {
      'ex_skill': 5,
      'skill1': 10,
      'skill2': 7,
      'skill3': 7,
    });
    expect(script.ranks, {
      const PlanFlowTutorialCard('칸나(수영복)', 1): 1,
      const PlanFlowTutorialCard('마키', 1): 1,
      const PlanFlowTutorialCard('미카', 1): 1,
      const PlanFlowTutorialCard('시로코(수영복)', 1): 2,
      const PlanFlowTutorialCard('히마리(무장)', 1): 2,
      const PlanFlowTutorialCard('아카네', 1): 3,
    });
    expect(script.later, const [
      PlanFlowTutorialCard('네루(교복)', 1),
      PlanFlowTutorialCard('마키', 2),
    ]);
  });

  test(
    'script names resolve to catalog ids that the F3c-1 seed uses',
    () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final byName = {
        for (final entry in await service.listStudents())
          entry.displayName: entry.studentId,
      };
      final script = PlanFlowTutorialScript.parse();
      final names = {
        ...script.students,
        for (final card in script.ranks.keys) card.name,
        for (final card in script.later) card.name,
      };
      expect({for (final name in names) name: byName[name]}, _scriptIds);
      // seed(지난 학생) + 가상 스캔 결과에 일곱 명이 모두 있다(네루(교복)는 새 학생).
      final seeded = {
        for (final student in tutorialPracticePreviousStudents)
          student.studentId,
        for (final example in tutorialPracticeStudentExamples)
          example.student.studentId,
      };
      expect(seeded, containsAll(_scriptIds.values));
      expect(
        tutorialPracticeStudentExamples
            .firstWhere(
              (example) => example.student.studentId == _scriptIds['네루(교복)'],
            )
            .classification,
        TutorialPracticeStudentClass.added,
      );
      // XB 데이터셋의 계획 학생 · 예시 시나리오 이름이 대본과 같다.
      final dataset =
          jsonDecode(File('../$tutorialPracticeDatasetPath').readAsStringSync())
              as Map<String, dynamic>;
      expect(
        (dataset['planning_students'] as List).toSet(),
        _scriptIds.values.toSet(),
      );
      final example = (dataset['example_scenario'] as Map)['name'] as String;
      expect(example, '비나 대비 · 한 번에 MAX');
      expect(tutorialSteps['8']!.why, contains("'$example'"));
      expect(tutorialSteps['7-6']!.why, contains("'총력전 비나 대비'"));
    },
  );

  group('watch.check', () {
    late PlanFlowContext context;

    setUp(() async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      context = await _context(service);
    });

    test('all five once when the script values are met', () {
      final watch = PlanFlowTutorialWatch();
      expect(watch.check(_draft(), context, enteredGoals: true), _planSignals);
      expect(watch.check(_draft(), context, enteredGoals: true), isEmpty);
      expect(watch.emitted, _planSignals.toSet());
    });

    test('none while a condition is not met', () {
      final cases = <String, (PlanFlowDraft, bool)>{
        'six students': (
          _draft(students: _scriptIds.values.take(6).toList()),
          true,
        ),
        'not entering goals': (_draft(), false),
        'maki stage 1 still all MAX': (
          _draft(makiStage1: _skills(5, 10, 10, 10)),
          true,
        ),
        'maki stage 2 not synced yet': (_draft(withMakiStage2: false), true),
        'maki stage 2 at 7/6': (_draft(makiStage2: _skills(5, 10, 7, 6)), true),
        'akane in rank 2': (
          _draft(
            ranks: [
              ['kanna_swimsuit-1', 'maki-1', 'mika-1'],
              ['shiroko_swimsuit-1', 'himari_battle-1', 'akane-1'],
            ],
          ),
          true,
        ),
        'neru still in a rank': (
          _draft(
            ranks: [
              ['kanna_swimsuit-1', 'maki-1', 'mika-1'],
              ['shiroko_swimsuit-1', 'himari_battle-1'],
              ['akane-1', 'neru_school_uniform-1'],
            ],
            deferred: const ['maki-2'],
          ),
          true,
        ),
      };
      const missing = {
        'six students': TutorialSignals.planStudentsConfirmed,
        'not entering goals': TutorialSignals.planStudentsConfirmed,
        'maki stage 1 still all MAX': TutorialSignals.planMakiStage1Set,
        'maki stage 2 not synced yet': TutorialSignals.planMakiStage2Set,
        'maki stage 2 at 7/6': TutorialSignals.planMakiStage2Set,
        'akane in rank 2': TutorialSignals.planRanksPlaced,
        'neru still in a rank': TutorialSignals.planLaterMoved,
      };
      for (final MapEntry(key: name, value: (draft, entered))
          in cases.entries) {
        final signals = PlanFlowTutorialWatch().check(
          draft,
          context,
          enteredGoals: entered,
        );
        expect(signals, isNot(contains(missing[name])), reason: name);
      }
      // 2단계가 아직 없으면 나중에 칸 조건(마키 2단계)도 아니다.
      expect(
        PlanFlowTutorialWatch().check(
          _draft(withMakiStage2: false),
          context,
          enteredGoals: true,
        ),
        isNot(contains(TutorialSignals.planLaterMoved)),
      );
    });
  });

  group('workspace wiring', () {
    Future<(PlanFlowController, List<String>, TutorialHooks)> pump(
      WidgetTester tester, {
      required bool active,
    }) async {
      tester.view.physicalSize = const Size(2560, 1208);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      final flow = PlanFlowController(
        purpose: PlanFlowPurpose.newScenario,
        context: await _context(service),
        service: service,
        initialDraft: PlanFlowDraft(
          students: [for (final id in _scriptIds.values) _seed(id)],
        ),
      );
      addTearDown(flow.dispose);
      final hooks = TutorialHooks()..active.value = active;
      addTearDown(hooks.dispose);
      final signals = <String>[];
      hooks.signals.listener = signals.add;
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: TutorialHooksScope(
              hooks: hooks,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 2560,
                  height: 1208,
                  child: PlanFlowWorkspace(
                    flow: flow,
                    service: service,
                    onClosed: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return (flow, signals, hooks);
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(planFlowCalculationDebounce);
      await tester.pump(const Duration(milliseconds: 600));
    }

    Map<String, int> editor(Map<String, int> skills) => {
      ...planElementTargetMinimums,
      ...skills,
    };

    testWidgets('tutorial on: 7-1 and 7-2b fire once from the flow', (
      tester,
    ) async {
      final (flow, signals, _) = await pump(tester, active: true);
      flow.goTo(PlanFlowStep.goals);
      await settle(tester);
      expect(signals, [TutorialSignals.planStudentsConfirmed]);
      flow.setStudentStages('maki', [
        PlanElementStageDraft(
          id: 'maki-1',
          name: '1단계',
          targets: editor({
            'ex_skill': 5,
            'skill1': 10,
            'skill2': 1,
            'skill3': 1,
          }),
        ),
      ]);
      await settle(tester);
      flow.setStudentStages('maki', [
        PlanElementStageDraft(
          id: 'maki-1',
          name: '1단계',
          targets: editor({
            'ex_skill': 5,
            'skill1': 10,
            'skill2': 1,
            'skill3': 1,
            'level': 2,
          }),
        ),
      ]);
      await settle(tester);
      expect(signals, [
        TutorialSignals.planStudentsConfirmed,
        TutorialSignals.planMakiStage1Set,
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tutorial off: no plan signal at all', (tester) async {
      final (flow, signals, hooks) = await pump(tester, active: false);
      flow.goTo(PlanFlowStep.goals);
      await settle(tester);
      flow.setStudentStages('maki', [
        PlanElementStageDraft(
          id: 'maki-1',
          name: '1단계',
          targets: editor({
            'ex_skill': 5,
            'skill1': 10,
            'skill2': 1,
            'skill3': 1,
          }),
        ),
      ]);
      await settle(tester);
      expect(signals, isEmpty);
      expect(hooks.active.value, isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
