import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/studio/plan_starter_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/preset_management_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/section_studio_document.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:ba_planner_v7/ui/widgets/plan_preset_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<MockAppService> _pumpPlanningPage(
  WidgetTester tester, {
  Size size = const Size(2560, 1392),
}) async {
  final service = MockAppService();
  addTearDown(service.dispose);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(body: PlanningPage(service: service)),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

Future<void> _openManager(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('plan-preset-manager-launch')));
  await tester.pumpAndSettle();
  expect(find.byType(PlanPresetManager), findsOneWidget);
}

void main() {
  test('preset manager owns dedicated geometry and requested motions', () {
    expect(planPresetManagerListMotion.intro, 0);
    expect(planPresetManagerListMotion.outro, 180);
    expect(planPresetManagerEditorMotion.intro, 80);
    expect(planPresetManagerEditorMotion.outro, 260);
    expect(planPresetManagerConfirmMotion.intro, 80);
    expect(planPresetManagerConfirmMotion.outro, 260);
    expect(defaultPlanElementPresets, isEmpty);
    final managerEditor = presetManagementStudioDocument.elements
        .firstWhere((item) => item.id == 'element-2')
        .rect;
    final elementBuilderEditor = planStarterStudioDocument.elements
        .firstWhere((item) => item.id == 'element-6')
        .rect;
    expect(
      (
        managerEditor.x,
        managerEditor.y,
        managerEditor.width,
        managerEditor.height,
      ),
      (
        elementBuilderEditor.x,
        elementBuilderEditor.y,
        elementBuilderEditor.width,
        elementBuilderEditor.height,
      ),
    );

    final saved = jsonDecode(
      File(
        '../release/section-preset-management.ba-section-studio.json',
      ).readAsStringSync(),
    );
    expect(
      jsonDecode(encodeSectionStudioDocument(presetManagementStudioDocument)),
      saved,
    );

    for (final size in const [Size(1280, 720), Size(2560, 1392)]) {
      final list = planPresetManagerSectionPath(size, 'element-1').getBounds();
      final editor = planPresetManagerSectionPath(
        size,
        'element-2',
      ).getBounds();
      final confirm = planPresetManagerSectionPath(
        size,
        'element-3',
      ).getBounds();
      expect(list.left, 0);
      expect(
        planPresetManagerFacingSeamDistance(size),
        closeTo(planPresetManagerPanelGap, 0.01),
      );
      expect(confirm.left, greaterThan(editor.right));
      expect(confirm.height, lessThan(editor.height / 3));
    }
  });

  testWidgets('creates, edits, saves, and deletes a multi-stage preset', (
    tester,
  ) async {
    await _pumpPlanningPage(tester);
    await _openManager(tester);

    expect(find.text('생성된 프리셋이 없습니다.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-preset-manager-stage-preset-stage-1')),
      findsOneWidget,
    );
    final nameField = tester.widget<TextField>(
      find.byKey(const ValueKey('plan-preset-manager-name')),
    );
    expect(nameField.decoration?.isDense, isTrue);
    expect(nameField.decoration?.hintText, '프리셋 이름');
    expect(nameField.decoration?.prefixIcon, isA<Icon>());
    expect(
      find.byKey(const ValueKey('plan-preset-manager-list-container')),
      findsOneWidget,
    );
    for (final key in const [
      'plan-preset-manager-add-stage',
      'plan-preset-manager-remove-stage',
      'plan-preset-manager-reset',
      'plan-preset-manager-save',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }

    await tester.enterText(
      find.byKey(const ValueKey('plan-preset-manager-name')),
      '공격 프리셋',
    );
    await tester.tap(
      find.byKey(const ValueKey('plan-preset-manager-add-stage')),
    );
    await tester.pump();
    expect(find.byType(PlanPresetElementCard), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('plan-preset-manager-save')));
    await tester.pump();
    expect(find.text('공격 프리셋 · 2단계'), findsOneWidget);

    await tester.tap(find.text('공격 프리셋 · 2단계'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-preset-manager-delete')));
    await tester.pump();
    expect(find.text('공격 프리셋 · 2단계'), findsNothing);
    expect(find.text('생성된 프리셋이 없습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsaved return opens the compact confirmation section', (
    tester,
  ) async {
    await _pumpPlanningPage(tester);
    await _openManager(tester);

    await tester.enterText(
      find.byKey(const ValueKey('plan-preset-manager-name')),
      '미저장 프리셋',
    );
    await tester.tap(find.byKey(const ValueKey('plan-preset-manager-back')));
    await tester.pump(planPresetManagerMotionDuration ~/ 2);

    final transform = tester.widget<Transform>(
      find
          .descendant(
            of: find.byKey(
              const ValueKey('plan-preset-manager-confirm-motion'),
            ),
            matching: find.byType(Transform),
          )
          .first,
    );
    final translation = transform.transform.getTranslation();
    expect(translation.x, lessThan(0));
    expect(translation.y, greaterThan(0));

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-preset-manager-confirm-section')),
      findsOneWidget,
    );
    expect(find.byType(PlanPresetManager), findsOneWidget);
    expect(find.text('저장하지 않은 변경사항을 버리고\n돌아갈까요?'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('plan-preset-manager-confirm-exit')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlanPresetManager), findsNothing);
    expect(
      find.byKey(const ValueKey('plan-preset-manager-launch')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('preset editor star endpoints toggle off when tapped again', (
    tester,
  ) async {
    await _pumpPlanningPage(tester);
    await _openManager(tester);

    await tester.tap(find.byKey(const ValueKey('plan-stage-1-student-star-5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-stage-1-student-star-5')));
    await tester.pump();
    expect(
      tester
          .widget<PlanPresetElementCard>(find.byType(PlanPresetElementCard))
          .stage
          .targets['student_star'],
      4,
    );

    await tester.tap(find.byKey(const ValueKey('plan-stage-1-weapon-star-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-stage-1-weapon-star-1')));
    await tester.pump();
    expect(
      tester
          .widget<PlanPresetElementCard>(find.byType(PlanPresetElementCard))
          .stage
          .targets['weapon_star'],
      0,
    );
  });

  testWidgets('preset manager remains usable at the narrow viewport', (
    tester,
  ) async {
    await _pumpPlanningPage(tester, size: const Size(1280, 720));
    await _openManager(tester);

    expect(
      find.byKey(const ValueKey('plan-preset-manager-back')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-preset-manager-name')),
      findsOneWidget,
    );
    expect(find.byType(PlanPresetElementCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
