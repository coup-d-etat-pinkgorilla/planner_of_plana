import 'dart:math' as math;

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/studio/plan_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/widgets/bond_rank_portrait.dart';
import 'package:ba_planner_v7/ui/widgets/diagonal_media_list_item.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart';
import 'package:ba_planner_v7/ui/widgets/scroll_viewport_fog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plan phase items use the expanded readable height', () {
    expect(planPhaseItemHeight, 65);
    expect(planPhaseItemExtent, 69);
  });

  Future<void> pumpPage(
    WidgetTester tester,
    AppService service, {
    Size size = const Size(900, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlanningPage(service: service)),
      ),
    );
  }

  test('projects the five sections from the plan Studio document', () {
    expect(
      planStudioDocument.elements
          .map(
            (element) => (
              element.rect.x,
              element.rect.y,
              element.rect.width,
              element.rect.height,
            ),
          )
          .toList(),
      const [
        (0, 2, 37, 92),
        (12, 2, 29, 94),
        (45, 2, 42, 92),
        (89, 14, 7, 80),
        (53, 1, 42, 14),
      ],
    );
    final section3 = planStudioDocument.elements.singleWhere(
      (element) => element.id == 'element-3',
    );
    final section5 = planStudioDocument.elements.singleWhere(
      (element) => element.id == 'element-5',
    );
    expect(section3.spec.face, SectionAttachmentFace.bottom);
    expect(section3.spec.height, 80);
    expect(section5.spec.face, SectionAttachmentFace.top);
    expect(section5.spec.height, 96);
    final section3VisualTop =
        section3.rect.bottom - section3.rect.height * section3.spec.height / 96;
    final sectionGap = section3VisualTop - section5.rect.bottom;
    expect(sectionGap, closeTo(2.3333333333, 1e-9));
  });

  test('uses the requested per-section intro and outro directions', () {
    expect(planSection1Motion.intro, 0);
    expect(planSection1Motion.outro, 180);
    expect(planSection2Motion.intro, 80);
    expect(planSection2Motion.outro, 260);
    expect(planSection3Motion.intro, 80);
    expect(planSection3Motion.outro, 260);
    expect(planSection4Motion.intro, 180);
    expect(planSection4Motion.outro, 0);
    expect(planSection5Motion.intro, 260);
    expect(planSection5Motion.outro, 80);
  });

  test('dummy phases keep student steps in execution order', () {
    final shirokoSteps = [
      for (final phase in dummyPlanPhases)
        for (final step in phase.steps)
          if (step.studentId == 'shiroko') step.step,
    ];
    expect(shirokoSteps, [1, 2, 3]);
    expect(dummyPlanPhases.map((phase) => phase.id).toList(), [
      'phase-1',
      'phase-2',
      'phase-3',
      'phase-4',
    ]);
    expect(
      dummyPlanPhases.fold<int>(
        0,
        (total, phase) => total + phase.steps.length,
      ),
      16,
    );
    expect([
      for (final phase in dummyPlanPhases)
        for (final step in phase.steps)
          if (step.bondRank != null) step.bondRank,
    ], containsAll(<int>[50, 100]));
  });

  test('phase items follow the parent parallelogram edges', () {
    const size = Size(320, 224);
    final rect = planPhaseItemRect(size, 1);
    final itemDepth = planPhaseItemHeight / math.tan(80 * math.pi / 180);
    expect(rect.height, planPhaseItemHeight);
    expect(
      rect.left,
      closeTo(planPhaseLeftBoundary(size, rect.bottom) + 9, 1e-9),
    );
    expect(
      rect.left + itemDepth,
      closeTo(planPhaseLeftBoundary(size, rect.top) + 9, 1e-9),
    );
    expect(
      rect.right - itemDepth,
      closeTo(planPhaseRightBoundary(size, rect.bottom) - 9, 1e-9),
    );
  });

  test('resource header follows the section 5 parallelogram safe interval', () {
    const size = Size(1280, 720);
    final section = planSectionPath(size, 'element-5');
    final tabs = planResourceTabShelfRect(size);
    final header = planResourceHeaderPath(size);
    final content = planResourceHeaderContentRect(size);

    for (final point in [
      tabs.topLeft,
      tabs.topRight,
      tabs.bottomLeft,
      tabs.bottomRight,
      content.centerLeft,
      content.centerRight,
    ]) {
      expect(section.contains(point), isTrue);
    }
    expect(header.contains(content.center), isTrue);
    expect(tabs.bottom, lessThan(header.getBounds().top));
    expect(
      header.getBounds().height,
      lessThanOrEqualTo(planResourceHeaderHeight),
    );
  });

  testWidgets('places five sections and a diagonal phase preview', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpPage(tester, service);

    final page = find.byKey(const ValueKey('planning-page'));
    expect(page, findsOneWidget);
    expect(
      find.descendant(of: page, matching: find.byType(ColoredBox)),
      findsNothing,
    );
    expect(find.byType(PlanSectionMotion), findsNWidgets(5));
    for (final id in const [
      'element-1',
      'element-2',
      'element-3',
      'element-4',
      'element-5',
    ]) {
      expect(find.byKey(ValueKey('plan-$id-motion')), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.byKey(ValueKey('plan-$id-foundation')),
      );
      expect(
        paint.painter,
        isA<PlanSectionFoundationPainter>().having(
          (painter) => painter.sectionId,
          'sectionId',
          id,
        ),
      );
    }
    expect(
      find.byKey(const ValueKey('plan-phase-container-foundation')),
      findsOneWidget,
    );
    expect(find.byType(PlanResourceHeader), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-resource-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-resource-tabs')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-resource-header-surface')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-resource-header-content-bottleneck')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-primary-bottleneck-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-primary-bottleneck-square')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-primary-bottleneck-icon')),
      findsOneWidget,
    );
    expect(find.text('가장 심한 병목 요소'), findsOneWidget);
    expect(
      find.text(
        '보유량 : $planPrimaryBottleneckOwned / '
        '필요량 : $planPrimaryBottleneckRequired',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        '확보 시 학생 $planPrimaryBottleneckStudentCount명의 '
        '목표 단계가 가능해집니다',
      ),
      findsOneWidget,
    );
    final bottleneckImages = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('plan-primary-bottleneck-summary')),
            matching: find.byType(Image),
          ),
        )
        .map((image) => image.image)
        .toList();
    expect(
      bottleneckImages,
      contains(const AssetImage(planPrimaryBottleneckBackgroundAsset)),
    );
    expect(
      bottleneckImages,
      contains(const AssetImage(planPrimaryBottleneckIconAsset)),
    );
    expect(
      tester
              .getSize(
                find.byKey(const ValueKey('plan-primary-bottleneck-square')),
              )
              .height /
          tester
              .getSize(
                find.byKey(const ValueKey('plan-primary-bottleneck-summary')),
              )
              .height,
      closeTo(0.85, 0.01),
    );
    expect(find.text('페이즈별 재화'), findsNothing);
    expect(find.text('전체 필요 재화'), findsNothing);
    expect(find.text('병목 재화'), findsNothing);
    for (final view in PlanResourceView.values) {
      expect(
        find.byKey(ValueKey('plan-resource-tab-${view.name}')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('plan-phase-scroll')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-phase-diagonal-scrollbar')),
      findsOneWidget,
    );
    final initialFog = tester.widget<ScrollViewportFog>(
      find.byKey(const ValueKey('plan-phase-fog')),
    );
    expect(initialFog.showTop, isFalse);
    expect(initialFog.showBottom, isTrue);
    expect(
      find.byKey(const ValueKey('plan-phase-viewport-fog-top')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('plan-phase-viewport-fog-bottom')),
      findsOneWidget,
    );
    for (final phase in dummyPlanPhases) {
      expect(find.byKey(ValueKey('plan-phase-${phase.id}')), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('plan-phase-flow-triangle')),
      findsNWidgets(3),
    );
    expect(
      find.byKey(const ValueKey('plan-step-phase-1-shiroko-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-step-phase-2-shiroko-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-step-phase-3-shiroko-3')),
      findsOneWidget,
    );
    final bond50 = tester.widget<BondRankPortrait>(
      find.descendant(
        of: find.byKey(const ValueKey('plan-step-phase-2-yuuka-2')),
        matching: find.byType(BondRankPortrait),
      ),
    );
    final bond100 = tester.widget<BondRankPortrait>(
      find.descendant(
        of: find.byKey(const ValueKey('plan-step-phase-3-azusa-3')),
        matching: find.byType(BondRankPortrait),
      ),
    );
    expect(bond50.bondRank, 50);
    expect(bond100.bondRank, 100);
    expect(
      bondRankPortraitBackgroundAsset(bond50.bondRank),
      yellowStudentPortraitBackgroundAsset,
    );
    expect(
      bondRankPortraitBackgroundAsset(bond100.bondRank),
      purpleStudentPortraitBackgroundAsset,
    );
    expect(
      find.byType(DiagonalMediaListItem),
      findsNWidgets(
        dummyPlanPhases.fold(0, (total, phase) => total + phase.steps.length),
      ),
    );
    final shirokoImages = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('plan-step-phase-1-shiroko-1')),
            matching: find.byType(Image),
          ),
        )
        .map((image) => image.image)
        .toList();
    expect(
      shirokoImages,
      contains(const AssetImage('assets/student_portraits/shiroko.png')),
    );
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottleneck is the first tab and other tabs clear its summary', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpPage(tester, service, size: const Size(1280, 500));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('plan-resource-header-content-bottleneck')),
      findsOneWidget,
    );
    final bottleneckLeft = tester
        .getTopLeft(find.byKey(const ValueKey('plan-resource-tab-bottleneck')))
        .dx;
    final byPhaseLeft = tester
        .getTopLeft(find.byKey(const ValueKey('plan-resource-tab-byPhase')))
        .dx;
    final overallLeft = tester
        .getTopLeft(find.byKey(const ValueKey('plan-resource-tab-overall')))
        .dx;
    expect(bottleneckLeft, lessThan(byPhaseLeft));
    expect(byPhaseLeft, lessThan(overallLeft));

    await tester.tap(find.byKey(const ValueKey('plan-resource-tab-overall')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-resource-header-content-overall')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-primary-bottleneck-summary')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('plan-resource-tab-bottleneck')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan-primary-bottleneck-summary')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottleneck item highlights every affected student row', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service, size: const Size(1280, 720));
    await tester.pumpAndSettle();

    DiagonalMediaListItem item(String key) =>
        tester.widget<DiagonalMediaListItem>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(DiagonalMediaListItem),
          ),
        );

    const affectedRows = [
      'plan-step-phase-1-haruka-1',
      'plan-step-phase-2-nonomi-1',
      'plan-step-phase-3-nonomi-2',
      'plan-step-phase-3-azusa-3',
    ];
    for (final key in affectedRows) {
      expect(item(key).highlighted, isFalse);
    }
    expect(item('plan-step-phase-1-shiroko-1').highlighted, isFalse);

    await tester.tap(
      find.byKey(const ValueKey('plan-primary-bottleneck-action')),
    );
    await tester.pumpAndSettle();

    for (final key in affectedRows) {
      expect(item(key).highlighted, isTrue);
    }
    expect(item('plan-step-phase-1-shiroko-1').highlighted, isFalse);

    await tester.tap(find.byKey(const ValueKey('plan-resource-tab-overall')));
    await tester.pumpAndSettle();
    for (final key in affectedRows) {
      expect(item(key).highlighted, isFalse);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('phase list scrolls while preserving its diagonal container', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service, size: const Size(1280, 720));
    await tester.pumpAndSettle();

    final scroll = find.byKey(const ValueKey('plan-phase-scroll'));
    final scrollable = find.descendant(
      of: scroll,
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.maxScrollExtent, greaterThan(position.viewportDimension));
    final before = tester.getTopLeft(
      find.byKey(const ValueKey('plan-phase-phase-2')),
    );
    final lastBefore = tester.getTopLeft(
      find.byKey(const ValueKey('plan-step-phase-4-ako-3')),
    );
    await tester.drag(scroll, const Offset(0, -240));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(
      find.byKey(const ValueKey('plan-phase-phase-2')),
    );
    final lastAfter = tester.getTopLeft(
      find.byKey(const ValueKey('plan-step-phase-4-ako-3')),
    );

    expect(after.dy, lessThan(before.dy));
    expect(lastAfter.dy, lessThan(lastBefore.dy));
    expect(position.pixels, greaterThan(0));
    final middleFog = tester.widget<ScrollViewportFog>(
      find.byKey(const ValueKey('plan-phase-fog')),
    );
    expect(middleFog.showTop, isTrue);
    expect(middleFog.showBottom, isTrue);

    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    final bottomFog = tester.widget<ScrollViewportFog>(
      find.byKey(const ValueKey('plan-phase-fog')),
    );
    expect(bottomFog.showTop, isTrue);
    expect(bottomFog.showBottom, isFalse);
    expect(
      find.byKey(const ValueKey('plan-phase-viewport-fog-top')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-phase-viewport-fog-bottom')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('plan-phase-container-foundation')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
