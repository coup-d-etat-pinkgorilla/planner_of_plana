import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/studio/plan_starter_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/preset_element_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/section_studio_document.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:ba_planner_v7/ui/widgets/plan_phase_editor.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
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
    'school': 'Abydos',
    'equipment_slot_1': 'Shoes',
    'equipment_slot_2': 'Bag',
    'equipment_slot_3': 'Charm',
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
  test('typed plan starter layout matches the saved Studio document', () {
    final saved = jsonDecode(
      File(
        '../release/section-plan-starter.ba-section-studio.json',
      ).readAsStringSync(),
    );
    expect(
      jsonDecode(encodeSectionStudioDocument(planStarterStudioDocument)),
      saved,
    );
  });

  test('typed preset element layout matches the saved Studio document', () {
    final saved = jsonDecode(
      File(
        '../release/section-preset-element.ba-section-studio.json',
      ).readAsStringSync(),
    );
    expect(
      jsonDecode(encodeSectionStudioDocument(presetElementStudioDocument)),
      saved,
    );
  });

  test('preset element projection retains the right-side protrusions', () {
    const size = Size(480, 860);
    final outer = planPresetElementRect(size, 'element-5');
    for (final id in const ['element-2', 'element-3', 'element-4']) {
      expect(planPresetElementRect(size, id).right, greaterThan(outer.right));
    }
    expect(planPresetElementUnionPath(size).getBounds().right, closeTo(480, 1));
  });

  test('preset element paths are derived from their saved Studio specs', () {
    const size = Size(180, 200);
    final element = planPresetElement('element-1');
    final depth = size.height * element.spec.height / sectionTemplateGridSize;
    final sourceSize = Size(
      size.width - sectionTemplateCutDepth(depth),
      size.height,
    );
    final expected = buildRoundedSectionPolygon(
      buildAttachedSectionPolygon(sourceSize, element.spec),
      radius: 9,
    );
    final actual = planPresetElementLocalPath(size, element.id);

    expect(actual.getBounds(), expected.getBounds());
    expect(
      actual.computeMetrics().single.length,
      closeTo(expected.computeMetrics().single.length, 0.001),
    );
  });

  test('plan starter projection keeps the current Section 3 structure', () {
    expect(
      planStarterStudioDocument.containers
          .where((item) => item.parentSectionId == 'element-3')
          .map((item) => item.id),
      const [
        'container-1',
        'container-2',
        'container-3',
        'container-5',
        'container-6',
        'container-7',
        'container-8',
        'container-9',
      ],
    );
    expect(planStarterStudioDocument.features.map((item) => item.id), const [
      'feature-2',
      'feature-5',
    ]);
    expect(
      planStarterStudioDocument.containers.any(
        (item) => item.id == 'container-10',
      ),
      isFalse,
    );
  });

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
    for (final id in const [
      'container-1',
      'container-5',
      'container-6',
      'container-7',
      'container-8',
      'container-9',
    ]) {
      expect(find.byKey(ValueKey('plan-starter-status-$id')), findsOne);
    }
    expect(
      find.byKey(const ValueKey('plan-starter-status-container-10')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('student-detail-level')), findsOne);
    expect(find.byKey(const ValueKey('student-detail-school-logo')), findsOne);
    expect(find.byKey(const ValueKey('plan-starter-weapon-level')), findsOne);
    expect(find.byKey(const ValueKey('student-detail-bond-rank')), findsOne);
    expect(find.byKey(const ValueKey('student-detail-bond-gauge')), findsOne);
    expect(
      find.byKey(const ValueKey('plan-starter-student-portrait')),
      findsOne,
    );
    final bondStatus = tester.widget<StudentBondStatus>(
      find.byType(StudentBondStatus),
    );
    final bondPath = planStarterContainerPath(
      tester.getSize(find.byType(PlanElementBuilder)),
      'container-8',
    );
    expect(
      bondStatus.outerPath.getBounds().width,
      closeTo(bondPath.getBounds().width, 0.01),
    );
    expect(
      bondStatus.outerPath.getBounds().height,
      closeTo(bondPath.getBounds().height, 0.01),
    );
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(
      find.byKey(const ValueKey('plan-starter-bond-metadata-header')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('student-detail-potential-locked')),
      findsOne,
    );
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
      find.descendant(of: firstCard, matching: find.text('Lv 2')),
      findsOne,
    );
    expect(
      find.descendant(of: secondCard, matching: find.text('Lv 2')),
      findsOne,
    );

    await tester.tap(find.byKey(const ValueKey('plan-stage-1-level-decrease')));
    await tester.pump();
    expect(
      find.descendant(of: firstCard, matching: find.text('Lv 1')),
      findsOne,
    );
    expect(
      find.descendant(of: secondCard, matching: find.text('Lv 2')),
      findsOne,
    );
  });

  testWidgets('stage card uses all nine preset surfaces and exact ratio', (
    tester,
  ) async {
    await _pumpBuilder(tester);

    final card = find.byKey(
      const ValueKey('plan-starter-stage-hoshino-stage-1'),
    );
    final size = tester.getSize(card);
    expect(
      size.height / size.width,
      closeTo(
        presetElementReferenceBounds.height /
            presetElementReferenceBounds.width,
        0.001,
      ),
    );
    for (final id in const [
      'element-1',
      'element-2',
      'element-3',
      'element-4',
      'element-5',
      'element-6',
      'element-7',
      'element-8',
      'element-9',
    ]) {
      expect(find.byKey(ValueKey('plan-preset-element-1-$id')), findsOne);
    }
    expect(find.text('1단계'), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('plan-stage-1-student-star-5')))
          .height,
      greaterThanOrEqualTo(28),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('plan-stage-1-level-increase'))),
      const Size(18, 22),
    );
  });

  testWidgets('star strip writes student and weapon star targets', (
    tester,
  ) async {
    List<PlanElementStageDraft>? confirmed;
    await _pumpBuilder(tester, onConfirm: (value) => confirmed = value);

    await tester.tap(find.byKey(const ValueKey('plan-stage-1-student-star-5')));
    await tester.tap(find.byKey(const ValueKey('plan-stage-1-weapon-star-4')));
    await tester.tap(find.byKey(const ValueKey('plan-starter-confirm')));
    await tester.pump();

    expect(confirmed?.single.targets['student_star'], 5);
    expect(confirmed?.single.targets['weapon_star'], 4);
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
        PlanElementStageDraft(
          id: 'stage-1',
          name: '1단계',
          targets: {...current, 'level': 2},
        ),
        PlanElementStageDraft(
          id: 'stage-2',
          name: '2단계',
          targets: {...current, 'level': 3},
        ),
        PlanElementStageDraft(
          id: 'stage-3',
          name: '3단계',
          targets: {...current, 'level': 4},
        ),
      ],
    );

    await tester.drag(
      find.byKey(const ValueKey('plan-starter-stage-scroll')),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-starter-stage-stage-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-starter-remove-stage')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-starter-add-stage')));
    await tester.pump();

    final added = find.byKey(
      const ValueKey('plan-starter-stage-hoshino-stage-1'),
    );
    expect(find.descendant(of: added, matching: find.text('Lv 2')), findsOne);
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
