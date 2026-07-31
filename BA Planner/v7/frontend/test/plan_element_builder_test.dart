import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:ba_planner_v7/ui/widgets/plan_phase_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningStudentSeed _seed({
  String handoffId = 'handoff-1',
  bool owned = true,
}) => PlanningStudentSeed(
  handoffId: handoffId,
  studentId: 'hoshino',
  metadata: const {
    'student_id': 'hoshino',
    'display_name': '호시노',
    'rarity': '3',
  },
  currentValues: const {
    'level': 1,
    'bond_rank': 1,
    'student_star': 3,
    'weapon_level': 0,
    'weapon_star': 0,
    'ex_skill': 1,
    'skill1': 1,
    'skill2': 1,
    'skill3': 1,
    'equip1': 'T1',
    'equip2': 'T1',
    'equip3': 'T1',
    'equip4': null,
    'equip1_level': 1,
    'equip2_level': 1,
    'equip3_level': 1,
    'stat_hp': 0,
    'stat_atk': 0,
    'stat_heal': 0,
  },
  owned: owned,
);

Future<void> _pumpBuilder(
  WidgetTester tester, {
  List<PlanElementStageDraft> initialStages = const [],
  ValueChanged<List<PlanElementStageDraft>>? onConfirm,
}) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: PlanElementBuilder(
          seed: _seed(),
          initialStages: initialStages,
          unassignedItems: const [],
          hasPlanElements: false,
          onConfirm: onConfirm ?? (_) {},
          onRenameUnassigned: (_, _) {},
          onOpenPhaseEditor: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test(
    'unowned students use an explicit metadata-derived virtual baseline',
    () {
      final current = planElementCurrentTargets(_seed(owned: false));
      expect(current['level'], 1);
      expect(current['student_star'], 3);
      expect(current['weapon_level'], 0);
      expect(current['equip1_tier'], 0);
      expect(current['stat_hp'], 0);
    },
  );

  testWidgets('planning seed opens the four-section element builder', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.binding.setSurfaceSize(const Size(2560, 1392));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: PlanningPage(service: service, initialSeed: _seed()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('plan-starter-element-3')), findsOne);
    expect(find.byKey(const ValueKey('plan-starter-element-5')), findsOne);
    expect(find.byKey(const ValueKey('plan-starter-element-6')), findsOne);
    expect(find.byKey(const ValueKey('plan-starter-element-7')), findsOne);
    expect(find.text('호시노'), findsOne);
    expect(find.text('확정된 현재 상태'), findsOne);
  });

  testWidgets('raising an earlier stage propagates only upward', (
    tester,
  ) async {
    await _pumpBuilder(
      tester,
      initialStages: [
        PlanElementStageDraft(
          id: 'stage-1',
          name: '1단계',
          targets: planElementCurrentTargets(_seed()),
        ),
        PlanElementStageDraft(
          id: 'stage-2',
          name: '2단계',
          targets: planElementCurrentTargets(_seed()),
        ),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('plan-stage-1-level-increase')));
    await tester.pump();

    final firstCard = find.byKey(const ValueKey('plan-starter-stage-stage-1'));
    final secondCard = find.byKey(const ValueKey('plan-starter-stage-stage-2'));
    expect(
      find.descendant(of: firstCard, matching: find.text('레벨 2')),
      findsOne,
    );
    expect(
      find.descendant(of: secondCard, matching: find.text('레벨 2')),
      findsOne,
    );

    await tester.tap(find.byKey(const ValueKey('plan-stage-1-level-decrease')));
    await tester.pump();
    expect(
      find.descendant(of: firstCard, matching: find.text('레벨 1')),
      findsOne,
    );
    expect(
      find.descendant(of: secondCard, matching: find.text('레벨 2')),
      findsOne,
    );
  });

  testWidgets('adding to a reopened draft keeps stage ids unique', (
    tester,
  ) async {
    await _pumpBuilder(
      tester,
      initialStages: [
        PlanElementStageDraft(
          id: 'hoshino-stage-1',
          name: '1단계',
          targets: planElementCurrentTargets(_seed()),
        ),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('plan-starter-add-stage')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('plan-starter-stage-hoshino-stage-1')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('plan-starter-stage-hoshino-stage-2')),
      findsOne,
    );
  });

  testWidgets('deleting a stage focuses the previous stage', (tester) async {
    final current = planElementCurrentTargets(_seed());
    await _pumpBuilder(
      tester,
      initialStages: [
        PlanElementStageDraft(id: 'stage-1', name: '1단계', targets: current),
        PlanElementStageDraft(id: 'stage-2', name: '2단계', targets: current),
        PlanElementStageDraft(id: 'stage-3', name: '3단계', targets: current),
      ],
    );

    await tester.tap(find.byKey(const ValueKey('plan-starter-stage-stage-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-starter-remove-stage')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-starter-add-stage')));
    await tester.pump();

    final added = find.byKey(
      const ValueKey('plan-starter-stage-hoshino-stage-1'),
    );
    final formerNext = find.byKey(const ValueKey('plan-starter-stage-stage-3'));
    expect(
      tester.getTopLeft(added).dy,
      lessThan(tester.getTopLeft(formerNext).dy),
    );
  });

  testWidgets(
    'preset overwrites the draft and confirmation creates unassigned items',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: PlanningPage(service: service, initialSeed: _seed()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('plan-starter-preset-balanced-growth')),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('plan-starter-confirm')));
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('plan-starter-unassigned-count')),
            )
            .data,
        '3',
      );
      expect(
        find.byKey(const ValueKey('plan-starter-open-phase-editor')),
        findsOne,
      );
    },
  );

  testWidgets(
    'confirmed stages flow into phases and leave no unassigned item',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: PlanningPage(service: service, initialSeed: _seed()),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('plan-starter-preset-balanced-growth')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-starter-confirm')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('plan-starter-open-phase-editor')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan-phase-editor')), findsOne);
      await tester.tap(
        find.byKey(const ValueKey('plan-phase-editor-assign-all')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('plan-phase-editor-complete')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan-phase-editor')), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('plan-starter-unassigned-count')),
            )
            .data,
        '0',
      );
    },
  );

  testWidgets('phase editor rejects a drop that reverses student stages', (
    tester,
  ) async {
    const first = PlanPhaseEditorItem<int>(
      id: 'stage-1',
      label: '1단계',
      iconAsset: 'assets/student_portraits/hoshino.png',
      data: 1,
      sequenceGroup: 'hoshino',
      sequenceIndex: 1,
    );
    const second = PlanPhaseEditorItem<int>(
      id: 'stage-2',
      label: '2단계',
      iconAsset: 'assets/student_portraits/hoshino.png',
      data: 2,
      sequenceGroup: 'hoshino',
      sequenceIndex: 2,
    );
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: PlanPhaseEditor<int>(
            items: const [first, second],
            itemBuilder: (_, item, _) => Text(item.label),
            onCancel: () {},
            onComplete: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('plan-phase-editor-quick-assign-stage-2')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('plan-phase-editor-quick-assign-stage-1')),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('plan-phase-editor-source-stage-1')),
      findsOne,
    );
    expect(find.text('같은 학생의 단계 순서를 지켜 배치하세요.'), findsOne);
  });
}
