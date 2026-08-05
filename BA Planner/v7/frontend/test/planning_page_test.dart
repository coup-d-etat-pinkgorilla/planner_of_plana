import 'dart:math' as math;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/studio/plan_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/widgets/bond_rank_portrait.dart';
import 'package:ba_planner_v7/ui/widgets/diagonal_media_list_item.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:ba_planner_v7/ui/widgets/plan_phase_editor.dart';
import 'package:ba_planner_v7/ui/widgets/plan_section_layout.dart';
import 'package:ba_planner_v7/ui/widgets/plan_student_selector.dart';
import 'package:ba_planner_v7/ui/widgets/scroll_viewport_fog.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:ba_planner_v7/ui/widgets/student_range_condition_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanElementPreset _planningTestPreset() => PlanElementPreset(
  id: 'balanced-growth',
  name: '테스트 프리셋',
  isDefault: false,
  stages: const [
    {'level': 30},
  ],
);

void main() {
  test('plan phase items use the expanded readable height', () {
    expect(planPhaseItemHeight, 65);
    expect(planPhaseItemExtent, 69);
    expect(phaseEditorDetailItemHeight, planPhaseItemHeight);
    expect(phaseEditorDetailItemExtent, planPhaseItemExtent);
    expect(phaseEditorPhaseHeaderHeight, planPhaseHeaderHeight);
    expect(phaseEditorPhaseFlowGap, planPhaseFlowGap);
  });

  test('all section 3 tab bodies use intro 80 and outro 260', () {
    expect(planSection3TabMotion.intro, 80);
    expect(planSection3TabMotion.outro, 260);
  });

  test('all plan student selector panels use intro 80 and outro 260', () {
    expect(planStudentSelectorMotion.intro, 80);
    expect(planStudentSelectorMotion.outro, 260);
  });

  test(
    'phase editor uses the requested motions and responsive section sizes',
    () {
      expect(phaseEditorMotionFor('element-1'), (0, 180));
      expect(phaseEditorMotionFor('element-2'), (80, 260));
      expect(phaseEditorMotionFor('element-4'), (80, 260));
      expect(phaseEditorMotionFor('element-3'), (180, 0));
      final intro80 = phaseEditorMotionDirection(80);
      final outro260 = phaseEditorMotionDirection(260);
      expect(intro80.dx, greaterThan(0));
      expect(intro80.dy, lessThan(0));
      expect(outro260.dx, lessThan(0));
      expect(outro260.dy, greaterThan(0));

      final initial = phaseEditorElements(0);
      final section2 = initial.singleWhere(
        (element) => element.id == 'element-2',
      );
      final section4 = initial.singleWhere(
        (element) => element.id == 'element-4',
      );
      final section1 = initial.singleWhere(
        (element) => element.id == 'element-1',
      );
      expect(section2.rect.width, planStudioDocument.elements[1].rect.width);
      expect(section2.rect.height, planStudioDocument.elements[1].rect.height);
      expect(section1.rect.width, phaseEditorSection1Width);
      expect(section4.rect.width, phaseEditorSection4Width);
      expect(section4.rect.width, section2.rect.width);
      expect(section4.rect.height, planStudioDocument.elements[1].rect.height);
      const viewport = Size(2560, 1392);
      final section2Inner = phaseEditorMainSectionSizedInnerRect(
        viewport,
        section2,
      );
      final section4Inner = phaseEditorMainSectionSizedInnerRect(
        viewport,
        section4,
      );
      expect(section4Inner.width, closeTo(section2Inner.width, 0.01));
      expect(section4Inner.height, closeTo(section2Inner.height, 0.01));

      final completedSection4 = phaseEditorElements(
        1,
      ).singleWhere((element) => element.id == 'element-4');
      expect(completedSection4.rect.x, planStudioDocument.elements[1].rect.x);
      expect(completedSection4.rect.y, planStudioDocument.elements[1].rect.y);
      expect(
        completedSection4.rect.width,
        planStudioDocument.elements[1].rect.width,
      );
      expect(
        completedSection4.rect.height,
        planStudioDocument.elements[1].rect.height,
      );
    },
  );

  test('phase editor detail contents follow main section 2 sizing', () {
    const size = Size(2560, 1392);
    final elements = phaseEditorElements(0);
    final section2 = elements.singleWhere((item) => item.id == 'element-2');
    final section3 = elements.singleWhere((item) => item.id == 'element-3');

    expect(
      phaseEditorMainSectionSizedInnerRect(size, section2),
      buildSectionCanvasElementPath(
        size,
        section2,
      ).getBounds().deflate(phaseEditorContainerInset),
    );
    expect(
      phaseEditorMainSectionSizedInnerRect(size, section3),
      buildSectionCanvasElementPath(
        size,
        section3,
      ).getBounds().deflate(phaseEditorContainerInset),
    );
  });

  test('phase editor side lists use the short edge and equal margins', () {
    const size = Size(2560, 1392);
    final elements = phaseEditorElements(0);
    for (final id in const ['element-1', 'element-3']) {
      final element = elements.singleWhere((item) => item.id == id);
      final sectionBounds = buildSectionCanvasElementPath(
        size,
        element,
      ).getBounds();
      final listRect = phaseEditorCenteredTrapezoidListRect(size, element);
      final leftMargin = listRect.left - sectionBounds.left;
      final rightMargin = sectionBounds.right - listRect.right;
      final visibleHorizontalEdge =
          listRect.width - listRect.height / math.tan(80 * math.pi / 180);
      final horizontalGap =
          phaseEditorCompactListNormalGap / math.sin(80 * math.pi / 180);

      expect(leftMargin, closeTo(rightMargin, 0.01));
      expect(
        visibleHorizontalEdge,
        closeTo(
          phaseEditorShortTrapezoidEdgeLength(size, element) -
              horizontalGap * 2,
          0.01,
        ),
      );
      expect(listRect.top, closeTo(sectionBounds.top + 10, 0.01));
      expect(listRect.bottom, closeTo(sectionBounds.bottom - 10, 0.01));
      expect(
        phaseEditorCompactListDiagonalNormalGap(size, element),
        greaterThanOrEqualTo(phaseEditorCompactListNormalGap - 0.01),
      );
      expect(
        phaseEditorCompactListStraightSideGap(size, element),
        greaterThanOrEqualTo(phaseEditorCompactListNormalGap),
      );
    }
  });

  test('phase editor side-list gaps survive responsive resizing', () {
    for (final size in const [
      Size(1280, 720),
      Size(1920, 1080),
      Size(2560, 1392),
    ]) {
      final elements = phaseEditorElements(0);
      for (final id in const ['element-1', 'element-3']) {
        final element = elements.singleWhere((item) => item.id == id);
        expect(
          phaseEditorCompactListDiagonalNormalGap(size, element),
          greaterThanOrEqualTo(phaseEditorCompactListNormalGap - 0.01),
          reason: '$id diagonal gap at $size',
        );
        expect(
          phaseEditorCompactListStraightSideGap(size, element),
          greaterThanOrEqualTo(phaseEditorCompactListNormalGap - 0.01),
          reason: '$id straight-side gap at $size',
        );
      }
    }
  });

  test('phase editor detail rows reserve one full-height assign button', () {
    expect(phaseEditorSelectionColor, diagonalMediaHighlightColor);
    for (final size in const [
      Size(360, 680),
      Size(540, 1080),
      Size(750, 1340),
    ]) {
      final hostWidth = phaseEditorDiagonalListItemHostWidth(
        size,
        phaseEditorDetailItemHeight,
      );
      expect(
        phaseEditorCanonicalDetailItemWidth(size) +
            phaseEditorDetailItemButtonGap +
            phaseEditorQuickAssignButtonWidth,
        closeTo(hostWidth, 0.01),
      );
      expect(phaseEditorQuickAssignButtonWidth, phaseEditorDetailItemHeight);
    }
  });

  test('phase editor item surface is a bilateral 80 degree parallelogram', () {
    const size = Size(240, 65);
    final path = phaseEditorItemPath(size);
    final depth = size.height / math.tan(80 * math.pi / 180);
    final bounds = path.getBounds();
    expect(bounds.left, closeTo(0, 0.001));
    expect(bounds.top, closeTo(0, 0.001));
    expect(bounds.width, closeTo(240, 0.001));
    expect(bounds.height, closeTo(65, 0.001));
    expect(path.contains(const Offset(1, 1)), isFalse);
    expect(path.contains(Offset(depth + 5, 5)), isTrue);
    expect(path.contains(Offset(size.width - 1, size.height - 1)), isFalse);
  });

  test('phase editor scrollbar follows the same 80 degree rail', () {
    const size = Size(300, 600);
    final top = phaseEditorScrollbarTrackPoint(size, 10);
    final bottom = phaseEditorScrollbarTrackPoint(size, 590);
    expect(top.dx, closeTo(300 - 10 - 10 / math.tan(80 * math.pi / 180), 0.01));
    expect(
      bottom.dx,
      closeTo(300 - 10 - 590 / math.tan(80 * math.pi / 180), 0.01),
    );
    expect(bottom.dx, lessThan(top.dx));
  });

  test('phase editor facing sections preserve the explicit diagonal seam', () {
    for (final size in const [
      Size(1280, 720),
      Size(1920, 1080),
      Size(2560, 1392),
    ]) {
      final elements = phaseEditorElements(0);
      final section1 = elements.singleWhere((item) => item.id == 'element-1');
      final section2 = elements.singleWhere((item) => item.id == 'element-2');
      final section3 = elements.singleWhere((item) => item.id == 'element-3');
      final section4 = elements.singleWhere((item) => item.id == 'element-4');
      expect(
        phaseEditorFacingSeamDistance(size, section1, section2),
        greaterThanOrEqualTo(phaseEditorSectionSeamGap),
        reason: 'section 1-2 normal seam at $size',
      );
      expect(
        phaseEditorFacingSeamDistance(size, section4, section3),
        greaterThanOrEqualTo(phaseEditorSectionSeamGap),
        reason: 'section 4-3 normal seam at $size',
      );
    }
  });

  test(
    'phase editor controls preserve equal height and diagonal clearances',
    () {
      for (final size in const [
        Size(1280, 720),
        Size(1920, 1080),
        Size(2560, 1392),
      ]) {
        final elements = phaseEditorElements(0);
        final section1 = elements.singleWhere((item) => item.id == 'element-1');
        final section3 = elements.singleWhere((item) => item.id == 'element-3');
        final section1Rect = sectionCanvasElementRect(size, section1);
        final section3Rect = sectionCanvasElementRect(size, section3);
        final section1Paths = phaseEditorResponsivePaths(
          size,
          elements,
          'element-1',
        );
        final section3Paths = phaseEditorResponsivePaths(
          size,
          elements,
          'element-3',
        );
        expect(
          section1Paths.buttons.keys,
          unorderedEquals(const ['back', 'assign-all', 'return-all']),
        );
        expect(
          section3Paths.buttons.keys,
          unorderedEquals(const [
            'move-up',
            'move-down',
            'add',
            'remove',
            'complete',
          ]),
        );

        final allPaths = <String, Path>{
          for (final entry in section1Paths.buttons.entries)
            'section-1-${entry.key}': entry.value,
          for (final entry in section3Paths.buttons.entries)
            'section-3-${entry.key}': entry.value,
        };
        for (final entry in allPaths.entries) {
          final path = entry.value;
          expect(path.computeMetrics(), isNotEmpty);
          expect(
            path.getBounds().height,
            closeTo(phaseEditorControlHeight(section1Rect), 0.01),
            reason: '${entry.key} at $size',
          );
        }

        final section1Bounds = [
          for (final id in const ['back', 'assign-all', 'return-all'])
            section1Paths.button(id).getBounds(),
        ];
        expect(
          section1Bounds.first.top - section1Rect.top,
          closeTo(phaseEditorControlGap, 0.01),
        );
        for (var index = 1; index < section1Bounds.length; index++) {
          expect(
            section1Bounds[index].top - section1Bounds[index - 1].bottom,
            closeTo(phaseEditorControlGap, 0.01),
          );
        }
        for (final bounds in section1Bounds) {
          expect(
            bounds.left - section1Rect.left,
            closeTo(phaseEditorControlGap, 0.01),
          );
        }

        final section3Bounds = [
          for (final id in const ['move-up', 'move-down', 'add', 'complete'])
            section3Paths.button(id).getBounds(),
        ];
        expect(
          section3Rect.bottom - section3Bounds.last.bottom,
          closeTo(phaseEditorControlGap, 0.01),
        );
        for (var index = 1; index < section3Bounds.length; index++) {
          expect(
            section3Bounds[index].top - section3Bounds[index - 1].bottom,
            closeTo(phaseEditorControlGap, 0.01),
          );
        }
        for (final id in const ['move-up', 'move-down', 'remove', 'complete']) {
          expect(
            section3Rect.right - section3Paths.button(id).getBounds().right,
            closeTo(phaseEditorControlGap, 0.01),
          );
        }
        expect(
          section3Paths.button('add').getBounds().top,
          closeTo(section3Paths.button('remove').getBounds().top, 0.01),
        );
        expect(
          section3Paths.button('add').getBounds().height,
          closeTo(section3Paths.button('remove').getBounds().height, 0.01),
        );
        final leftTrapezoid = section1Paths.button('return-all');
        final leftBounds = leftTrapezoid.getBounds();
        final leftDepth = leftBounds.height / math.tan(80 * math.pi / 180);
        expect(
          leftTrapezoid.contains(
            Offset(leftBounds.right - leftDepth - 3, leftBounds.bottom - 3),
          ),
          isTrue,
        );
        final rightTrapezoid = section3Paths.button('move-up');
        final rightBounds = rightTrapezoid.getBounds();
        final rightDepth = rightBounds.height / math.tan(80 * math.pi / 180);
        expect(
          rightTrapezoid.contains(
            Offset(rightBounds.left + rightDepth + 3, rightBounds.top + 3),
          ),
          isTrue,
        );
      }
    },
  );

  test('phase editor outer container is clipped as a parallelogram', () {
    const size = Size(2560, 1392);
    final elements = phaseEditorElements(0);
    for (final id in const ['element-2', 'element-4']) {
      final element = elements.singleWhere((item) => item.id == id);
      final path = phaseEditorOuterContainerPath(size, element);
      final bounds = path.getBounds();
      final expected = phaseEditorMainSectionSizedInnerRect(size, element);
      expect(bounds.left, closeTo(expected.left, 3));
      expect(bounds.top, closeTo(expected.top, 3));
      expect(bounds.width, closeTo(expected.width, 3));
      expect(bounds.height, closeTo(expected.height, 3));
      expect(path.contains(bounds.center), isTrue);
      expect(path.contains(Offset(bounds.left + 30, bounds.top + 10)), isFalse);
      expect(
        path.contains(Offset(bounds.right - 30, bounds.bottom - 10)),
        isFalse,
      );
      expect(path.contains(Offset(bounds.right - 30, bounds.top + 10)), isTrue);
      expect(
        path.contains(Offset(bounds.left + 30, bounds.bottom - 10)),
        isTrue,
      );
    }
  });

  test(
    'regular equipment uses the v6 default item background at every tier',
    () {
      for (var tier = 1; tier <= 10; tier += 1) {
        final resource = PlanBottleneckResourcePreview(
          id: 'equipment-t$tier',
          name: '장비',
          remainingAtEntry: 0,
          requiredAtEntry: 1,
          shortage: 1,
          iconAsset: 'equipment.png',
          affectedStageKeys: const {'phase-1:student:1'},
          backgroundAsset: planPhaseShortageBackgroundAsset,
          equipmentTier: tier,
        );
        expect(
          resource.effectiveBackgroundAsset,
          planDefaultItemBackgroundAsset,
        );
      }
    },
  );

  test('overall consumption is the exact sum of phase consumption', () {
    final phaseTotals = <String, int>{};
    final phaseConsumers = <String, Set<String>>{};
    for (final phase in dummyPlanPhaseConsumptions) {
      for (final resource in phase.resources) {
        final aggregateId = resource.id.replaceFirst(
          RegExp(r'^phase-\d+-'),
          'overall-',
        );
        phaseTotals.update(
          aggregateId,
          (amount) => amount + resource.amount,
          ifAbsent: () => resource.amount,
        );
        phaseConsumers
            .putIfAbsent(aggregateId, () => <String>{})
            .addAll(resource.affectedStageKeys);
      }
    }
    expect({
      for (final resource in dummyPlanOverallConsumption.resources)
        resource.id: resource.amount,
    }, phaseTotals);
    expect({
      for (final resource in dummyPlanOverallConsumption.resources)
        resource.id: resource.affectedStageKeys,
    }, phaseConsumers);
    expect([
      for (final detail in dummyPlanBottleneckDetails)
        for (final resource in detail.resources) resource.affectedStageKeys,
      for (final phase in dummyPlanPhaseConsumptions)
        for (final resource in phase.resources) resource.affectedStageKeys,
      for (final resource in dummyPlanOverallConsumption.resources)
        resource.affectedStageKeys,
    ], everyElement(isNotEmpty));
  });

  test('resource categories filter and sort the section 3 data', () {
    expect(PlanResourceCategory.values, hasLength(10));
    expect(
      PlanResourceCategory.values.map((category) => category.label).toSet(),
      hasLength(10),
    );
    expect(
      planResourceCategory(
        id: 'phase-1-basic-bd',
        iconAsset: planBasicTacticalBdIconAsset,
      ),
      PlanResourceCategory.tacticalBd,
    );
    expect(
      planResourceCategory(
        id: 'phase-2-nebra-t3',
        iconAsset: planPrimaryBottleneckIconAsset,
      ),
      PlanResourceCategory.ooparts,
    );
    expect(
      planResourceCategory(
        id: 'phase-2-hairpin-t10',
        iconAsset: 'assets/equipment_icons/hairpin_t10.png',
        equipmentTier: 10,
      ),
      PlanResourceCategory.equipment,
    );
    expect(
      planResourceCategory(
        id: 'phase-1-credits',
        iconAsset: planCreditIconAsset,
      ),
      PlanResourceCategory.credits,
    );

    final shortagesOnly = filterPlanConsumptionGroups(
      dummyPlanPhaseConsumptions,
      categories: PlanResourceCategory.values.toSet(),
      hideSatisfied: true,
      sort: PlanResourceSort.shortageDescending,
    );
    final phase2 = shortagesOnly.singleWhere((group) => group.id == 'phase-2');
    expect(phase2.resources.map((resource) => resource.id), [
      'phase-2-antikythera-t4',
      'phase-2-hairpin-t10',
    ]);
    expect(phase2.resources.every((resource) => resource.isBottleneck), isTrue);

    final oopartsOnly = filterPlanConsumptionGroups(
      dummyPlanPhaseConsumptions,
      categories: const {PlanResourceCategory.ooparts},
      hideSatisfied: false,
      sort: PlanResourceSort.defaultOrder,
    );
    expect(
      oopartsOnly
          .expand((group) => group.resources)
          .map(
            (resource) => planResourceCategory(
              id: resource.id,
              iconAsset: resource.iconAsset,
              equipmentTier: resource.equipmentTier,
            ),
          ),
      everyElement(PlanResourceCategory.ooparts),
    );
  });

  Future<void> pumpPage(
    WidgetTester tester,
    AppService service, {
    Size size = const Size(900, 900),
    List<PlanElementPreset> presets = const [],
  }) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningPage(service: service, initialPresets: presets),
        ),
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

  test('section 4 controls and section 6 share the canonical geometry', () {
    const size = Size(2560, 1392);
    final section4 = planSectionPath(size, 'element-4');
    final controls = planResourceControlPaths(size);
    expect(controls, hasLength(3));
    expect(
      controls.map((path) => path.getBounds().center.dy).toList(),
      orderedEquals(
        controls.map((path) => path.getBounds().center.dy).toList()..sort(),
      ),
    );
    for (final control in controls) {
      expect(section4.contains(control.getBounds().center), isTrue);
    }
    final section4Bounds = section4.getBounds();
    final expectedHeight = (section4Bounds.height * 0.095)
        .clamp(44.0, 68.0)
        .toDouble();
    final firstBounds = controls[0].getBounds();
    final secondBounds = controls[1].getBounds();
    expect(
      secondBounds.top - firstBounds.bottom,
      closeTo(planResourceControlGap, 0.01),
    );
    expect(firstBounds.height, closeTo(expectedHeight, 0.01));

    final section5Bounds = planSectionPath(size, 'element-5').getBounds();
    final section6Bounds = planResourceFilterSectionPath(size).getBounds();
    expect(section6Bounds, section5Bounds);
    expect(
      section6Bounds.contains(planResourceFilterGroupRect(size).center),
      isTrue,
    );
    expect(
      section6Bounds.contains(
        planResourceFilterResetPath(size).getBounds().center,
      ),
      isTrue,
    );
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

  test(
    'two-column resources keep their size and align to long control rails',
    () {
      const cardSize = Size(1000, 353);
      const gridTop = 174.0;
      final left = planDiagonalTwoColumnTileRect(
        cardSize: cardSize,
        gridTop: gridTop,
        index: 0,
      );
      final right = planDiagonalTwoColumnTileRect(
        cardSize: cardSize,
        gridTop: gridTop,
        index: 1,
      );
      const tileHeight = 107.0;
      const oldGap = 8.0;
      final rowBottom = gridTop + tileHeight;
      final oldLeft = planPhaseLeftBoundary(cardSize, rowBottom) + 12;
      final oldRight = planPhaseRightBoundary(cardSize, gridTop) - 12;
      final oldWidth = (oldRight - oldLeft - oldGap) / 2;
      expect(left.width, closeTo(oldWidth, 0.001));
      expect(right.width, closeTo(oldWidth, 0.001));
      expect(left.height, tileHeight);
      expect(right.height, tileHeight);

      final tileDepth = tileHeight / math.tan(80 * math.pi / 180);
      final longControlRailInset = 16 + 38 / math.tan(80 * math.pi / 180);
      expect(
        left.left + tileDepth - planPhaseLeftBoundary(cardSize, gridTop),
        closeTo(longControlRailInset, 0.001),
      );
      expect(
        planPhaseRightBoundary(cardSize, gridTop) - right.right,
        closeTo(longControlRailInset, 0.001),
      );
      expect(
        left.left - planPhaseLeftBoundary(cardSize, rowBottom),
        closeTo(longControlRailInset, 0.001),
      );
      expect(
        planPhaseRightBoundary(cardSize, rowBottom) - (right.right - tileDepth),
        closeTo(longControlRailInset, 0.001),
      );
    },
  );

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

  test(
    'bottleneck container is inset to 95 percent with a small top margin',
    () {
      const size = Size(1280, 720);
      final sectionBounds = planSectionPath(size, 'element-3').getBounds();
      final containerBounds = planBottleneckContainerPath(size).getBounds();

      expect(
        containerBounds.width / sectionBounds.width,
        closeTo(planBottleneckContainerScale, 0.01),
      );
      expect(
        containerBounds.height / sectionBounds.height,
        closeTo(planBottleneckContainerScale, 0.01),
      );
      expect(
        containerBounds.top,
        closeTo(
          sectionBounds.top +
              sectionBounds.height * planBottleneckContainerTopRatio,
          0.01,
        ),
      );
    },
  );

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
      find.byKey(const ValueKey('plan-section-3-1-bottleneck')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-bottleneck-container-foundation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-bottleneck-scroll')),
      findsOneWidget,
    );
    expect(find.text('병목 1'), findsOneWidget);
    final focusItem = find.byKey(
      const ValueKey('plan-bottleneck-bottleneck-1-focus-item'),
    );
    expect(focusItem, findsOneWidget);
    final focusTile = tester.widget<PlanStudentStepTile>(focusItem);
    expect(focusTile.step.studentId, 'hoshino');
    expect(focusTile.step.step, 2);
    expect(focusTile.bottleneckField, PlanBottleneckFocusField.skills);
    expect(
      find.descendant(
        of: focusItem,
        matching: find.byType(DiagonalMediaListItem),
      ),
      findsOneWidget,
    );
    final pinkFocusTexts = tester
        .widgetList<Text>(
          find.descendant(of: focusItem, matching: find.byType(Text)),
        )
        .where((text) => text.style?.color == diagonalMediaHighlightColor);
    expect(pinkFocusTexts, isNotEmpty);
    expect(tester.getSize(focusItem).height, planPhaseItemHeight);
    expect(find.text('기초 전술교육 BD : 아비도스'), findsOneWidget);
    expect(find.text('단계 진입 잔량 4 / 단계 필요량 12'), findsOneWidget);
    expect(find.text('8개 부족'), findsOneWidget);
    expect(
      find.text('이 병목으로 지연되는 단계'),
      findsNWidgets(dummyPlanBottleneckDetails.length),
    );
    expect(find.text('호시노 2단계'), findsNothing);
    expect(find.text('노노미 2단계'), findsNothing);
    expect(find.text('아코 3단계'), findsNothing);
    expect(find.text('크레딧'), findsNothing);
    expect(find.text('120,000 / 850,000'), findsOneWidget);
    expect(find.text('730,000 부족'), findsOneWidget);
    expect(find.text('전자파 차단 헤어핀 (T10)'), findsOneWidget);
    final creditImages = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('plan-bottleneck-credit-shortage')),
            matching: find.byType(Image),
          ),
        )
        .map((image) => image.image)
        .toList();
    expect(creditImages, [const AssetImage(planCreditIconAsset)]);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('plan-bottleneck-credit-shortage-icon')),
      ),
      const Size(30, 30),
    );
    final creditRowSize = tester.getSize(
      find.byKey(const ValueKey('plan-bottleneck-credit-shortage')),
    );
    final delayedActionSize = tester.getSize(
      find.byKey(const ValueKey('plan-bottleneck-bottleneck-2-delayed-action')),
    );
    expect(creditRowSize.width, closeTo(delayedActionSize.width, 0.001));
    expect(creditRowSize.height, closeTo(delayedActionSize.height, 0.001));
    expect(
      find.byKey(const ValueKey('plan-bottleneck-resource-credits-square')),
      findsNothing,
    );
    final multiResourceGrid = find.byKey(
      const ValueKey('plan-bottleneck-bottleneck-2-resource-grid'),
    );
    expect(
      find.descendant(
        of: multiResourceGrid,
        matching: find.byType(PlanBottleneckResourceTile),
      ),
      findsNWidgets(2),
    );
    final multiResourceImages = tester
        .widgetList<Image>(
          find.descendant(of: multiResourceGrid, matching: find.byType(Image)),
        )
        .map((image) => image.image)
        .toList();
    expect(
      multiResourceImages,
      isNot(contains(const AssetImage(planCreditIconAsset))),
    );
    expect(
      multiResourceImages,
      contains(const AssetImage(planPhaseShortageIconAsset)),
    );
    expect(
      multiResourceImages,
      contains(const AssetImage(planPrimaryBottleneckIconAsset)),
    );
    final bdImages = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byKey(
              const ValueKey('plan-bottleneck-bottleneck-1-resource-grid'),
            ),
            matching: find.byType(Image),
          ),
        )
        .map((image) => image.image)
        .toList();
    expect(bdImages, contains(const AssetImage(planBasicTacticalBdIconAsset)));
    expect(
      bdImages,
      contains(const AssetImage(planDefaultItemBackgroundAsset)),
    );
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byKey(
                    const ValueKey(
                      'plan-bottleneck-bottleneck-1-resource-grid',
                    ),
                  ),
                  matching: find.byType(PlanBottleneckResourceTile),
                )
                .first,
          )
          .height,
      107,
    );
    final equipmentGrid = find.byKey(
      const ValueKey('plan-bottleneck-bottleneck-3-resource-grid'),
    );
    final equipmentImages = tester
        .widgetList<Image>(
          find.descendant(of: equipmentGrid, matching: find.byType(Image)),
        )
        .map((image) => image.image)
        .toList();
    expect(
      equipmentImages,
      contains(const AssetImage(planDefaultItemBackgroundAsset)),
    );
    expect(
      equipmentImages,
      isNot(contains(const AssetImage(planPhaseShortageBackgroundAsset))),
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
    final firstPhase = tester.getRect(
      find.byKey(ValueKey('plan-phase-${dummyPlanPhases.first.id}')),
    );
    final firstFlowTriangle = tester.getRect(
      find.byKey(const ValueKey('plan-phase-flow-triangle')).first,
    );
    expect(
      firstFlowTriangle.center.dx,
      closeTo(
        firstPhase.left +
            (firstPhase.width -
                    firstPhase.height / math.tan(80 * math.pi / 180)) /
                2,
        0.5,
      ),
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
        dummyPlanPhases.fold(0, (total, phase) => total + phase.steps.length) +
            dummyPlanBottleneckDetails.length,
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

  testWidgets(
    'bottleneck is first and overall uses its dedicated two-line summary',
    (tester) async {
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
          .getTopLeft(
            find.byKey(const ValueKey('plan-resource-tab-bottleneck')),
          )
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
        find.byKey(const ValueKey('plan-section-3-3-overall')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-section-3-1-bottleneck')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plan-primary-bottleneck-summary')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plan-overall-summary')),
        findsOneWidget,
      );
      expect(find.text('전체 요구량의 72% 확보'), findsOneWidget);
      expect(find.text('14종 부족 · 6명의 성장 계획에 영향'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('plan-resource-tab-bottleneck')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plan-primary-bottleneck-summary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-section-3-1-bottleneck')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resource summaries highlight their affected students in every tab',
    (tester) async {
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

      await tester.tap(find.byKey(const ValueKey('plan-overall-action')));
      await tester.pumpAndSettle();
      const overallRows = [
        'plan-step-phase-1-shiroko-1',
        'plan-step-phase-1-hoshino-1',
        'plan-step-phase-1-serika-1',
        'plan-step-phase-1-haruka-1',
        'plan-step-phase-2-nonomi-1',
        'plan-step-phase-3-azusa-3',
      ];
      for (final key in overallRows) {
        expect(item(key).highlighted, isTrue);
      }
      expect(item('plan-step-phase-2-yuuka-2').highlighted, isFalse);

      await tester.tap(find.byKey(const ValueKey('plan-resource-tab-byPhase')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plan-section-3-2-phase')),
        findsOneWidget,
      );
      for (final key in overallRows) {
        expect(item(key).highlighted, isFalse);
      }
      expect(find.text('2단계에서 4명 중 1명만 완료 가능'), findsOneWidget);
      final phaseImages = tester
          .widgetList<Image>(
            find.descendant(
              of: find.byKey(const ValueKey('plan-phase-shortage-summary')),
              matching: find.byType(Image),
            ),
          )
          .map((image) => image.image);
      expect(
        phaseImages,
        contains(const AssetImage(planPhaseShortageIconAsset)),
      );
      expect(
        phaseImages,
        contains(const AssetImage(planPhaseShortageBackgroundAsset)),
      );

      await tester.tap(
        find.byKey(const ValueKey('plan-phase-shortage-action')),
      );
      await tester.pumpAndSettle();
      expect(item('plan-step-phase-2-yuuka-2').highlighted, isTrue);
      expect(item('plan-step-phase-1-shiroko-1').highlighted, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phase consumption cards reuse resources and overall aggregates one group',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(tester, service, size: const Size(1280, 720));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('plan-resource-tab-byPhase')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final sectionThreeStack = find.byKey(
        const ValueKey('plan-section-3-tab-stack'),
        skipOffstage: false,
      );
      final outgoingTransformFinder = find.descendant(
        of: sectionThreeStack,
        matching: find.byKey(
          const ValueKey('animated-section-0'),
          skipOffstage: false,
        ),
        skipOffstage: false,
      );
      final outgoingTransform = tester.widget<Transform>(
        outgoingTransformFinder,
      );
      expect(
        find.descendant(
          of: outgoingTransformFinder,
          matching: find.byKey(
            const ValueKey('plan-element-3-foundation'),
            skipOffstage: false,
          ),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      final incomingTransformFinder = find.descendant(
        of: sectionThreeStack,
        matching: find.byKey(
          const ValueKey('animated-section-1'),
          skipOffstage: false,
        ),
        skipOffstage: false,
      );
      expect(
        find.descendant(
          of: incomingTransformFinder,
          matching: find.byKey(
            const ValueKey('plan-element-3-phase-foundation'),
            skipOffstage: false,
          ),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      final outgoingTranslation = outgoingTransform.transform.getTranslation();
      expect(
        outgoingTranslation.x.abs() + outgoingTranslation.y.abs(),
        greaterThan(0.1),
      );
      await tester.pumpAndSettle();

      final phaseSection = find.byKey(const ValueKey('plan-section-3-2-phase'));
      expect(phaseSection, findsOneWidget);
      expect(
        find.descendant(
          of: phaseSection,
          matching: find.byType(PlanStudentStepTile),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: phaseSection,
          matching: find.text('이 병목으로 지연되는 단계'),
        ),
        findsNothing,
      );
      for (var index = 1; index <= dummyPlanPhaseConsumptions.length; index++) {
        expect(
          find.byKey(ValueKey('plan-phase-consumption-card-$index')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(
          const ValueKey('plan-phase-consumption-phase-1-credits-credit-row'),
        ),
        findsOneWidget,
      );
      final phaseTwoGrid = find.byKey(
        const ValueKey('plan-phase-consumption-phase-2-resource-grid'),
      );
      final phaseTwoTiles = find.descendant(
        of: phaseTwoGrid,
        matching: find.byType(PlanConsumptionResourceTile),
      );
      expect(phaseTwoTiles, findsNWidgets(3));
      final phaseTwoTilePositions = [
        for (final tile in phaseTwoTiles.evaluate())
          tester.getTopLeft(find.byWidget(tile.widget)),
      ];
      expect(phaseTwoTilePositions[0].dy, phaseTwoTilePositions[1].dy);
      expect(
        phaseTwoTilePositions[2].dy,
        greaterThan(phaseTwoTilePositions[0].dy),
      );
      expect(
        phaseTwoTilePositions[2].dx,
        lessThan(phaseTwoTilePositions[0].dx),
      );
      expect(find.text('페이즈 소모량'), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey(
                  'plan-phase-consumption-phase-2-antikythera-t4-name',
                ),
              ),
            )
            .data,
        '온전한 안티키테라 장치',
      );
      expect(find.text('진입 3  │ 필요 5 │ 종료 -2'), findsOneWidget);
      expect(find.text('부족 2'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(
                const ValueKey('plan-phase-consumption-phase-2-nebra-t3-name'),
              ),
            )
            .data,
        '마모된 네브라 디스크',
      );
      expect(find.text('전자파 차단 헤어핀 (T10)'), findsOneWidget);
      expect(find.text('진입 2  │ 필요 3 │ 종료 -1'), findsOneWidget);
      expect(find.text('부족 1'), findsOneWidget);
      expect(find.text('진입 9  │ 필요 7 │ 종료 2'), findsOneWidget);
      expect(find.text('충족'), findsWidgets);
      final antikytheraAmount = find.byKey(
        const ValueKey('plan-phase-consumption-phase-2-antikythera-t4-amount'),
      );
      final antikytheraBalance = find.byKey(
        const ValueKey('plan-phase-consumption-phase-2-antikythera-t4-balance'),
      );
      expect(
        tester.getCenter(antikytheraBalance).dy,
        greaterThan(tester.getCenter(antikytheraAmount).dy),
      );
      expect(
        find.byKey(
          const ValueKey('plan-phase-consumption-phase-2-hairpin-t10-square'),
        ),
        findsOneWidget,
      );
      final firstPhaseCard = find.byKey(
        const ValueKey('plan-phase-consumption-card-1'),
      );
      final beforeScroll = tester.getTopLeft(firstPhaseCard);
      await tester.drag(
        find.byKey(const ValueKey('plan-phase-consumption-scroll')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      final afterScroll = tester.getTopLeft(firstPhaseCard);
      expect(afterScroll.dy, lessThan(beforeScroll.dy));
      expect(afterScroll.dx, isNot(closeTo(beforeScroll.dx, 0.001)));

      await tester.tap(find.byKey(const ValueKey('plan-resource-tab-overall')));
      await tester.pumpAndSettle();

      final overallSection = find.byKey(
        const ValueKey('plan-section-3-3-overall'),
      );
      expect(overallSection, findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-overall-consumption-card-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('plan-overall-consumption-overall-label')),
        findsOneWidget,
      );
      expect(find.text('전체 계획'), findsOneWidget);
      expect(find.text('전체 소모량'), findsNothing);
      expect(find.text('기초 전술교육 BD : 아비도스'), findsOneWidget);
      expect(find.text('보유 20 / 필요 30'), findsOneWidget);
      expect(find.text('부족 10'), findsOneWidget);
      expect(find.text('크레딧'), findsNothing);
      expect(find.text('보유 4,000,000 / 필요 4,410,000'), findsOneWidget);
      expect(find.text('부족 410,000'), findsOneWidget);
      final basicBdProgress = tester.widget<PlanInventoryCoverageBar>(
        find.byKey(
          const ValueKey('plan-overall-consumption-overall-basic-bd-progress'),
        ),
      );
      expect(basicBdProgress.percent, 67);
      expect(basicBdProgress.ratio, closeTo(2 / 3, 0.001));
      expect(basicBdProgress.scale, greaterThan(0));
      final basicBdProgressFinder = find.byKey(
        const ValueKey('plan-overall-consumption-overall-basic-bd-progress'),
      );
      final paintedBar = find.descendant(
        of: basicBdProgressFinder,
        matching: find.byType(CustomPaint),
      );
      expect(tester.getSize(paintedBar).height, greaterThan(0));
      expect(
        tester.getSize(paintedBar).height,
        closeTo(10.8 * basicBdProgress.scale, 0.01),
      );
      expect(
        tester.getSize(basicBdProgressFinder).height,
        closeTo(12 * basicBdProgress.scale, 0.01),
      );
      final percentageText = find.descendant(
        of: basicBdProgressFinder,
        matching: find.text('67%'),
      );
      expect(
        tester.getTopRight(basicBdProgressFinder).dx -
            tester.getTopRight(percentageText).dx,
        greaterThan(8),
      );
      final creditProgress = tester.widget<PlanInventoryCoverageBar>(
        find.byKey(
          const ValueKey('plan-overall-consumption-overall-credits-progress'),
        ),
      );
      expect(creditProgress.percent, 91);
      final creditProgressFinder = find.byKey(
        const ValueKey('plan-overall-consumption-overall-credits-progress'),
      );
      final paintedCreditBar = find.descendant(
        of: creditProgressFinder,
        matching: find.byType(CustomPaint),
      );
      expect(tester.getSize(creditProgressFinder).height, closeTo(8, 0.01));
      expect(tester.getSize(paintedCreditBar).height, closeTo(7.2, 0.01));
      expect(
        find.byKey(
          const ValueKey('plan-overall-consumption-overall-credits-credit-row'),
        ),
        findsOneWidget,
      );
      final overallGrid = find.byKey(
        const ValueKey('plan-overall-consumption-overall-resource-grid'),
      );
      expect(
        find.descendant(
          of: overallGrid,
          matching: find.byType(PlanConsumptionResourceTile),
        ),
        findsNWidgets(6),
      );
      expect(
        find.descendant(
          of: overallSection,
          matching: find.byType(PlanStudentStepTile),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: overallSection,
          matching: find.text('이 병목으로 지연되는 단계'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'section 3 resources focus exact consuming plans in every resource tab',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(tester, service, size: const Size(1280, 720));
      await tester.pumpAndSettle();

      DiagonalMediaListItem planItem(String key) =>
          tester.widget<DiagonalMediaListItem>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(DiagonalMediaListItem),
            ),
          );

      final bottleneckBdAction = find.byKey(
        const ValueKey('plan-bottleneck-resource-basic-tactical-bd-action'),
      );
      await tester.tap(bottleneckBdAction);
      await tester.pumpAndSettle();
      for (final key in const [
        'plan-step-phase-2-hoshino-2',
        'plan-step-phase-3-nonomi-2',
        'plan-step-phase-4-ako-3',
      ]) {
        expect(planItem(key).highlighted, isTrue);
      }
      expect(planItem('plan-step-phase-2-yuuka-2').highlighted, isFalse);
      expect(
        tester
            .widget<PlanBottleneckResourceTile>(
              find.ancestor(
                of: bottleneckBdAction,
                matching: find.byType(PlanBottleneckResourceTile),
              ),
            )
            .selected,
        isTrue,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('plan-bottleneck-bottleneck-1-delayed-action'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PlanBottleneckResourceTile>(
              find.ancestor(
                of: bottleneckBdAction,
                matching: find.byType(PlanBottleneckResourceTile),
              ),
            )
            .selected,
        isFalse,
      );

      await tester.tap(find.byKey(const ValueKey('plan-resource-tab-byPhase')));
      await tester.pumpAndSettle();
      final phaseAntikytheraAction = find.byKey(
        const ValueKey('plan-phase-consumption-phase-2-antikythera-t4-action'),
      );
      await tester.ensureVisible(phaseAntikytheraAction);
      await tester.pumpAndSettle();
      await tester.tap(phaseAntikytheraAction);
      await tester.pumpAndSettle();
      expect(planItem('plan-step-phase-2-yuuka-2').highlighted, isTrue);
      expect(planItem('plan-step-phase-3-azusa-3').highlighted, isFalse);
      expect(
        tester
            .widget<PlanConsumptionResourceTile>(
              find.ancestor(
                of: phaseAntikytheraAction,
                matching: find.byType(PlanConsumptionResourceTile),
              ),
            )
            .selected,
        isTrue,
      );

      final phaseTwoCreditAction = find.byKey(
        const ValueKey('plan-phase-consumption-phase-2-credits-action'),
      );
      await tester.drag(
        find.byKey(const ValueKey('plan-phase-consumption-scroll')),
        const Offset(0, 90),
      );
      await tester.pumpAndSettle();
      await tester.tap(phaseTwoCreditAction);
      await tester.pumpAndSettle();
      for (final key in const [
        'plan-step-phase-2-shiroko-2',
        'plan-step-phase-2-nonomi-1',
        'plan-step-phase-2-hoshino-2',
        'plan-step-phase-2-yuuka-2',
      ]) {
        expect(planItem(key).highlighted, isTrue);
      }
      expect(planItem('plan-step-phase-3-azusa-3').highlighted, isFalse);
      expect(
        tester
            .widget<PlanConsumptionCreditRow>(
              find.ancestor(
                of: phaseTwoCreditAction,
                matching: find.byType(PlanConsumptionCreditRow),
              ),
            )
            .selected,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('plan-resource-tab-overall')));
      await tester.pumpAndSettle();
      final overallBdAction = find.byKey(
        const ValueKey('plan-overall-consumption-overall-basic-bd-action'),
      );
      await tester.tap(overallBdAction);
      await tester.pumpAndSettle();
      for (final key in const [
        'plan-step-phase-1-hoshino-1',
        'plan-step-phase-1-haruka-1',
        'plan-step-phase-3-nonomi-2',
        'plan-step-phase-3-azusa-3',
      ]) {
        expect(planItem(key).highlighted, isTrue);
      }
      expect(planItem('plan-step-phase-2-yuuka-2').highlighted, isFalse);

      final overallCreditAction = find.byKey(
        const ValueKey('plan-overall-consumption-overall-credits-action'),
      );
      await tester.tap(overallCreditAction);
      await tester.pumpAndSettle();
      for (final phase in dummyPlanPhases) {
        for (final step in phase.steps) {
          expect(
            planItem(
              'plan-step-${phase.id}-${step.studentId}-${step.step}',
            ).highlighted,
            isTrue,
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bottleneck delayed-stage button highlights exact rows and list scrolls',
    (tester) async {
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

      await tester.tap(
        find.byKey(
          const ValueKey('plan-bottleneck-bottleneck-1-delayed-action'),
        ),
      );
      await tester.pumpAndSettle();

      for (final key in const [
        'plan-step-phase-2-hoshino-2',
        'plan-step-phase-3-nonomi-2',
        'plan-step-phase-4-ako-3',
      ]) {
        expect(item(key).highlighted, isTrue);
      }
      for (final key in const [
        'plan-step-phase-1-hoshino-1',
        'plan-step-phase-2-nonomi-1',
        'plan-step-phase-3-azusa-3',
      ]) {
        expect(item(key).highlighted, isFalse);
      }

      await tester.tap(
        find.byKey(const ValueKey('plan-primary-bottleneck-action')),
      );
      await tester.pumpAndSettle();
      expect(item('plan-step-phase-2-hoshino-2').highlighted, isFalse);
      expect(item('plan-step-phase-4-ako-3').highlighted, isFalse);
      for (final key in const [
        'plan-step-phase-1-haruka-1',
        'plan-step-phase-2-nonomi-1',
        'plan-step-phase-3-nonomi-2',
        'plan-step-phase-3-azusa-3',
      ]) {
        expect(item(key).highlighted, isTrue);
      }

      final scroll = find.byKey(const ValueKey('plan-bottleneck-scroll'));
      final scrollable = find.descendant(
        of: scroll,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(position.viewportDimension));
      final before = tester.getTopLeft(
        find.byKey(const ValueKey('plan-bottleneck-card-2')),
      );
      await tester.drag(scroll, const Offset(0, -320));
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(
        find.byKey(const ValueKey('plan-bottleneck-card-2')),
      );
      expect(after.dy, lessThan(before.dy));
      expect(after.dx, greaterThan(before.dx));
      expect(position.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('section 4 opens and operates the resource type filter', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service, size: const Size(2560, 1392));
    await tester.pumpAndSettle();

    const filterButton = ValueKey('plan-resource-type-filter-button');
    const hideButton = ValueKey('plan-hide-satisfied-button');
    const sortDropdown = ValueKey('plan-resource-sort-dropdown');
    expect(find.byKey(filterButton), findsOneWidget);
    expect(find.byKey(hideButton), findsOneWidget);
    expect(find.byKey(sortDropdown), findsOneWidget);
    for (final buttonKey in [filterButton, hideButton]) {
      expect(
        find.descendant(of: find.byKey(buttonKey), matching: find.byType(Text)),
        findsNothing,
      );
    }
    expect(
      tester
          .widget<Tooltip>(
            find.ancestor(
              of: find.byKey(filterButton),
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      '재화 유형 필터',
    );
    final sortPaint = tester.widget<CustomPaint>(
      find
          .ancestor(
            of: find.byKey(sortDropdown),
            matching: find.byType(CustomPaint),
          )
          .first,
    );
    expect(
      sortPaint.painter.runtimeType.toString(),
      '_PlanResourceSortDropdownBorderPainter',
    );
    final compactSortLabel = find.descendant(
      of: find.byKey(sortDropdown),
      matching: find.text(PlanResourceSort.defaultOrder.compactLabel),
    );
    expect(
      tester.getTopLeft(compactSortLabel).dx -
          tester.getTopLeft(find.byKey(sortDropdown)).dx,
      closeTo(26, 0.01),
    );
    expect(find.byType(PlanResourceHeader), findsOneWidget);
    expect(find.byType(PlanResourceTypeFilterSection), findsNothing);

    await tester.tap(find.byKey(filterButton));
    await tester.pumpAndSettle();
    expect(find.byType(PlanResourceHeader), findsNothing);
    expect(find.byType(PlanResourceTypeFilterSection), findsOneWidget);
    expect(
      find.byKey(const ValueKey('plan-element-6-foundation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-resource-filter-group')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('plan-resource-filter-container')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('plan-resource-filter-scroll')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(PlanResourceTypeFilterSection),
        matching: find.byType(Scrollable),
      ),
      findsNothing,
    );
    final firstRowCenters = [
      tester.getCenter(find.byKey(const ValueKey('plan-resource-filter-all'))),
      tester.getCenter(
        find.byKey(const ValueKey('plan-resource-filter-tacticalBd')),
      ),
      tester.getCenter(
        find.byKey(const ValueKey('plan-resource-filter-skillNote')),
      ),
      tester.getCenter(
        find.byKey(const ValueKey('plan-resource-filter-ooparts')),
      ),
    ];
    expect(firstRowCenters[1].dy, closeTo(firstRowCenters[0].dy, 0.01));
    expect(firstRowCenters[2].dy, closeTo(firstRowCenters[0].dy, 0.01));
    expect(firstRowCenters[3].dy, closeTo(firstRowCenters[0].dy, 0.01));
    expect(firstRowCenters[1].dx, greaterThan(firstRowCenters[0].dx));
    expect(firstRowCenters[2].dx, greaterThan(firstRowCenters[1].dx));
    expect(firstRowCenters[3].dx, greaterThan(firstRowCenters[2].dx));
    expect(
      tester
          .getCenter(
            find.byKey(const ValueKey('plan-resource-filter-equipment')),
          )
          .dy,
      greaterThan(firstRowCenters[0].dy),
    );
    expect(tester.widget<Text>(find.text('표시할 재화')).style?.fontSize, 18);
    expect(
      tester
          .widget<Text>(find.text(PlanResourceCategory.tacticalBd.label))
          .style
          ?.fontSize,
      15.75,
    );
    expect(
      find.text(PlanResourceCategory.enhancementStone.label),
      findsOneWidget,
    );

    Checkbox checkboxFor(String key) => tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(ValueKey('plan-resource-filter-$key')),
        matching: find.byType(Checkbox),
      ),
    );

    expect(checkboxFor('all').value, isTrue);
    for (final category in PlanResourceCategory.values) {
      expect(checkboxFor(category.name).value, isTrue);
    }

    await tester.tap(
      find.byKey(const ValueKey('plan-resource-filter-ooparts')),
    );
    await tester.pump();
    expect(checkboxFor('ooparts').value, isFalse);
    expect(checkboxFor('all').value, isNull);

    await tester.tap(find.byKey(const ValueKey('plan-resource-filter-reset')));
    await tester.pump();
    expect(checkboxFor('all').value, isTrue);
    expect(checkboxFor('ooparts').value, isTrue);

    await tester.tap(find.byKey(filterButton));
    await tester.pumpAndSettle();
    expect(find.byType(PlanResourceHeader), findsOneWidget);
    expect(find.byType(PlanResourceTypeFilterSection), findsNothing);

    await tester.tap(find.byKey(hideButton));
    await tester.pump();
    final hideSemantics = tester.widgetList<Semantics>(
      find.ancestor(
        of: find.byKey(hideButton),
        matching: find.byType(Semantics),
      ),
    );
    expect(
      hideSemantics.any((widget) => widget.properties.selected == true),
      isTrue,
    );

    await tester.tap(find.byKey(sortDropdown));
    await tester.pumpAndSettle();
    expect(
      find.text(PlanResourceSort.shortageDescending.menuLabel),
      findsOneWidget,
    );
    await tester.tap(find.text(PlanResourceSort.shortageDescending.menuLabel));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(sortDropdown),
        matching: find.textContaining(
          PlanResourceSort.shortageDescending.compactLabel,
        ),
      ),
      findsOneWidget,
    );
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

  testWidgets('phase editor keeps lists and side controls interactive', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service, size: const Size(2560, 1392));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('plan-phase-editor-launch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('plan-phase-editor')), findsOneWidget);
    for (final id in const [
      'element-1',
      'element-2',
      'element-3',
      'element-4',
    ]) {
      expect(
        find.byKey(ValueKey('plan-phase-editor-$id-foundation')),
        findsOneWidget,
      );
    }
    for (final prefix in const [
      'plan-phase-editor-source',
      'plan-phase-editor-unassigned',
      'plan-phase-editor-phase-list',
      'plan-phase-editor-assignment',
    ]) {
      expect(
        find.byKey(ValueKey('$prefix-diagonal-scrollbar')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('$prefix-fog')), findsOneWidget);
    }
    expect(find.byType(Scrollbar), findsNothing);
    expect(find.byType(RawScrollbar), findsNothing);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey(
                'plan-phase-editor-assignment-number-editor-phase-1',
              ),
            ),
          )
          .style,
      AppTextStyles.planPhaseNumber,
    );
    expect(find.text('시로코 · 3단계'), findsWidgets);
    final squareBackgrounds = tester
        .widgetList<Image>(find.byType(Image))
        .where(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName ==
                  'assets/item_backgrounds/square.png',
        );
    expect(squareBackgrounds, isNotEmpty);
    const firstSourceItemId = 'phase-1-shiroko-1';
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey('plan-phase-editor-source-media-$firstSourceItemId'),
        ),
      ),
      phaseEditorSourceMediaSize,
    );
    expect(
      tester
          .widget<Image>(
            find.byKey(
              const ValueKey(
                'plan-phase-editor-source-square-$firstSourceItemId',
              ),
            ),
          )
          .fit,
      BoxFit.contain,
    );
    for (final key in const [
      'plan-phase-editor-back',
      'plan-phase-editor-assign-all',
      'plan-phase-editor-return-all',
      'plan-phase-editor-move-up',
      'plan-phase-editor-move-down',
      'plan-phase-editor-add',
      'plan-phase-editor-remove',
      'plan-phase-editor-complete',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    final lockedComplete = find.byKey(
      const ValueKey('plan-phase-editor-complete'),
    );
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(of: lockedComplete, matching: find.byType(Tooltip)),
          )
          .message,
      '계획 요소를 전부 배치하세요',
    );
    expect(
      find.descendant(
        of: lockedComplete,
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('plan-phase-editor-name-editor-phase-1')),
    );
    await tester.pump();
    final nameField = find.byKey(
      const ValueKey('plan-phase-editor-name-field-editor-phase-1'),
    );
    await tester.enterText(nameField, '레이드 준비');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('레이드 준비'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey('plan-phase-editor-name-editor-phase-1')),
    );
    await tester.pump();
    final outsideCommitField = find.byKey(
      const ValueKey('plan-phase-editor-name-field-editor-phase-1'),
    );
    await tester.enterText(outsideCommitField, '야외 작전');
    await tester.tap(find.byKey(const ValueKey('plan-phase-editor-complete')));
    await tester.pump();
    expect(outsideCommitField, findsNothing);
    expect(find.text('야외 작전'), findsWidgets);

    final itemIds = [
      for (final phase in dummyPlanPhases)
        for (final step in phase.steps)
          '${phase.id}-${step.studentId}-${step.step}',
    ];
    final quickItemId = itemIds.first;
    final quickSource = find.byKey(
      ValueKey('plan-phase-editor-unassigned-$quickItemId'),
    );
    final quickSourceRect = tester.getRect(quickSource);
    final quickButton = find.byKey(
      ValueKey('plan-phase-editor-quick-assign-$quickItemId'),
    );
    expect(tester.getSize(quickButton), const Size(65, 65));
    final quickButtonInk = find.descendant(
      of: quickButton,
      matching: find.byType(InkWell),
    );
    final quickButtonInkWidget = tester.widget<InkWell>(quickButtonInk);
    expect(quickButtonInkWidget.hoverColor, phaseEditorButtonHoverColor);
    expect(quickButtonInkWidget.highlightColor, phaseEditorButtonPressedColor);
    expect(
      find.descendant(of: quickButton, matching: find.byType(ClipPath)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: quickButton, matching: find.byType(Material)),
      findsOneWidget,
    );

    final feedbackGesture = await tester.startGesture(
      tester.getCenter(quickSource),
    );
    await feedbackGesture.moveBy(const Offset(24, 0));
    await tester.pump();
    final feedback = find.byKey(
      ValueKey('plan-phase-editor-drag-feedback-$quickItemId'),
    );
    expect(tester.getSize(feedback), quickSourceRect.size);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(of: feedback, matching: find.byType(Opacity)),
          )
          .opacity,
      phaseEditorDragFeedbackOpacity,
    );
    await feedbackGesture.up();
    await tester.pumpAndSettle();

    await tester.tap(quickButton);
    await tester.pump();
    final quickAssigned = find.byKey(
      ValueKey('plan-phase-editor-assigned-$quickItemId'),
    );
    expect(quickSource, findsNothing);
    final quickAssignedSize = tester.getSize(quickAssigned);
    expect(quickAssignedSize.width, greaterThan(quickSourceRect.width));
    expect(quickAssignedSize.height, closeTo(quickSourceRect.height, 0.01));
    final assignmentCard = find.byKey(
      const ValueKey('plan-phase-editor-drop-editor-phase-1'),
    );
    final assignmentCardRect = tester.getRect(assignmentCard);
    final expectedAssignedRect = phaseEditorAssignmentItemRect(
      assignmentCardRect.size,
      0,
    ).shift(assignmentCardRect.topLeft);
    final actualAssignedRect = tester.getRect(quickAssigned);
    expect(actualAssignedRect.left, closeTo(expectedAssignedRect.left, 0.01));
    expect(actualAssignedRect.right, closeTo(expectedAssignedRect.right, 0.01));
    expect(
      tester
          .widget<Semantics>(
            find.byKey(
              const ValueKey(
                'plan-phase-editor-assignment-phase-editor-phase-1',
              ),
            ),
          )
          .properties
          .selected,
      isTrue,
    );

    for (final itemId in itemIds.skip(1)) {
      final source = find.byKey(
        ValueKey('plan-phase-editor-unassigned-$itemId'),
      );
      final gesture = await tester.startGesture(tester.getCenter(source));
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();
      final target = find.byKey(
        const ValueKey('plan-phase-editor-insert-editor-phase-1-0'),
      );
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pump();
      expect(source, findsNothing, reason: 'drag $itemId should be accepted');
    }

    expect(find.text('모든 계획 요소를 페이즈에 배정했습니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-phase-editor')), findsOneWidget);
    for (final key in const [
      'plan-phase-editor-back',
      'plan-phase-editor-assign-all',
      'plan-phase-editor-return-all',
      'plan-phase-editor-move-up',
      'plan-phase-editor-move-down',
      'plan-phase-editor-add',
      'plan-phase-editor-remove',
      'plan-phase-editor-complete',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plan-phase-editor-complete')),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phase editor bulk and phase-order controls update editor state',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      final items = [
        for (final id in const ['a', 'b', 'c'])
          PlanPhaseEditorItem<String>(
            id: id,
            label: '학생 $id · 1단계',
            iconAsset: 'assets/student_portraits/shiroko.png',
            data: id,
          ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanPhaseEditor<String>(
              items: items,
              itemBuilder: (context, item, order) => ColoredBox(
                color: Colors.blueGrey,
                child: Text('$order:${item.data}'),
              ),
              onCancel: () {},
              onComplete: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final complete = find.byKey(const ValueKey('plan-phase-editor-complete'));
      final returnAll = find.byKey(
        const ValueKey('plan-phase-editor-return-all'),
      );
      expect(
        find.descendant(
          of: complete,
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: returnAll,
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('plan-phase-editor-add')));
      await tester.pump();
      final phase1 = find.byKey(
        const ValueKey('plan-phase-editor-name-editor-phase-1'),
      );
      final phase2 = find.byKey(
        const ValueKey('plan-phase-editor-name-editor-phase-2'),
      );
      expect(phase2, findsOneWidget);
      expect(
        tester.getTopLeft(phase1).dy,
        lessThan(tester.getTopLeft(phase2).dy),
      );

      await tester.tap(
        find.byKey(const ValueKey('plan-phase-editor-assign-all')),
      );
      await tester.pump();
      for (final id in const ['a', 'b', 'c']) {
        expect(
          find.byKey(ValueKey('plan-phase-editor-unassigned-$id')),
          findsNothing,
        );
        expect(
          find.byKey(ValueKey('plan-phase-editor-assigned-$id')),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: complete,
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsNothing,
      );

      final moveUpRect = tester.getRect(
        find.byKey(const ValueKey('plan-phase-editor-move-up')),
      );
      await tester.tapAt(
        Offset(
          moveUpRect.left + moveUpRect.width * 0.75,
          moveUpRect.top + moveUpRect.height * 0.75,
        ),
      );
      await tester.pump();
      expect(
        tester.getTopLeft(phase2).dy,
        lessThan(tester.getTopLeft(phase1).dy),
      );

      await tester.tap(find.byKey(const ValueKey('plan-phase-editor-remove')));
      await tester.pump();
      expect(phase2, findsNothing);
      for (final id in const ['a', 'b', 'c']) {
        expect(
          find.byKey(ValueKey('plan-phase-editor-unassigned-$id')),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.byKey(const ValueKey('plan-phase-editor-assign-all')),
      );
      await tester.pump();
      final returnAllRect = tester.getRect(returnAll);
      await tester.tapAt(
        Offset(
          returnAllRect.left + returnAllRect.width * 0.25,
          returnAllRect.top + returnAllRect.height * 0.25,
        ),
      );
      await tester.pump();
      for (final id in const ['a', 'b', 'c']) {
        expect(
          find.byKey(ValueKey('plan-phase-editor-unassigned-$id')),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(
          of: complete,
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('phase editor inserts and reorders items between phase rows', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1280, 720));
    final items = [
      for (final id in const ['a', 'b', 'c'])
        PlanPhaseEditorItem<String>(
          id: id,
          label: '학생 $id · 1단계',
          iconAsset: 'assets/student_portraits/shiroko.png',
          data: id,
        ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanPhaseEditor<String>(
            items: items,
            itemBuilder: (context, item, order) => ColoredBox(
              color: Colors.blueGrey,
              child: Text('$order:${item.data}'),
            ),
            onCancel: () {},
            onComplete: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> dragTo(Finder source, Finder target) async {
      final gesture = await tester.startGesture(tester.getCenter(source));
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 140));
      final line = find.descendant(
        of: target,
        matching: find.byKey(
          const ValueKey('plan-phase-editor-insertion-line'),
        ),
      );
      final decoration =
          tester.widget<AnimatedContainer>(line).decoration as BoxDecoration;
      expect(decoration.color, const Color(0xfff2b3ef));
      await gesture.up();
      await tester.pump();
    }

    Finder assigned(String id) =>
        find.byKey(ValueKey('plan-phase-editor-assigned-$id'));
    Finder insertion(int index) =>
        find.byKey(ValueKey('plan-phase-editor-insert-editor-phase-1-$index'));
    Finder quickAssign(String id) =>
        find.byKey(ValueKey('plan-phase-editor-quick-assign-$id'));

    await tester.tap(quickAssign('a'));
    await tester.pump();
    await tester.tap(quickAssign('b'));
    await tester.pump();
    expect(
      tester.getTopLeft(assigned('a')).dy,
      lessThan(tester.getTopLeft(assigned('b')).dy),
    );

    await dragTo(assigned('b'), insertion(0));
    expect(
      tester.getTopLeft(assigned('b')).dy,
      lessThan(tester.getTopLeft(assigned('a')).dy),
    );

    await dragTo(assigned('b'), insertion(2));
    expect(
      tester.getTopLeft(assigned('a')).dy,
      lessThan(tester.getTopLeft(assigned('b')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('phase editor source rows follow the diagonal scroll rail', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, service, size: const Size(1280, 720));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-phase-editor-launch')));
    await tester.pumpAndSettle();

    final scroll = find.byKey(
      const ValueKey('plan-phase-editor-source-scroll'),
    );
    final trackedItem = find.byKey(
      const ValueKey('plan-phase-editor-source-phase-2-shiroko-2'),
    );
    final sourceFog = find.byKey(
      const ValueKey('plan-phase-editor-source-fog'),
    );
    expect(tester.widget<ScrollViewportFog>(sourceFog).showTop, isFalse);
    expect(tester.widget<ScrollViewportFog>(sourceFog).showBottom, isTrue);
    final before = tester.getTopLeft(trackedItem);
    await tester.drag(scroll, const Offset(0, -180));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(trackedItem);

    expect(after.dy, lessThan(before.dy));
    expect(after.dx, greaterThan(before.dx));
    expect(tester.widget<ScrollViewportFog>(sourceFog).showTop, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'phase editor sections play their outro when the plan tab deactivates',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      var active = true;
      late StateSetter setHostState;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return Scaffold(
                body: PlanningPage(service: service, active: active),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('plan-phase-editor-launch')));
      await tester.pumpAndSettle();

      Offset motionOffset(String id) {
        final motion = find.byKey(ValueKey('plan-phase-editor-$id-motion'));
        final transform = find.descendant(
          of: motion,
          matching: find.byType(Transform),
        );
        final translation = tester
            .widget<Transform>(transform.first)
            .transform
            .getTranslation();
        return Offset(translation.x, translation.y);
      }

      for (final id in const [
        'element-1',
        'element-2',
        'element-3',
        'element-4',
      ]) {
        expect(motionOffset(id), Offset.zero);
      }

      setHostState(() => active = false);
      await tester.pump();
      await tester.pump(
        Duration(milliseconds: phaseEditorMotionDuration.inMilliseconds ~/ 2),
      );

      final section1 = motionOffset('element-1');
      final section2 = motionOffset('element-2');
      final section3 = motionOffset('element-3');
      final section4 = motionOffset('element-4');
      expect(section1.dx, lessThan(0));
      expect(section1.dy.abs(), lessThan(0.01));
      expect(section2.dx, lessThan(0));
      expect(section2.dy, greaterThan(0));
      expect(section3.dx, greaterThan(0));
      expect(section3.dy.abs(), lessThan(0.01));
      expect(section4.dx, lessThan(0));
      expect(section4.dy, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'student selector keeps section 1 and resets search and filters on exit',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(tester, service, size: const Size(2560, 1392));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('plan-student-selector-launch')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlanStudentSelector), findsOneWidget);
      expect(find.text('보유 상태'), findsOneWidget);
      expect(find.text('계획 상태'), findsOneWidget);
      final gridSection = find.byKey(
        const ValueKey('plan-student-selector-grid-section'),
      );
      final filterSection = find.byKey(
        const ValueKey('plan-student-selector-filter-section'),
      );
      final conditionSection = find.byKey(
        const ValueKey('plan-range-condition-section'),
      );
      final selectorRect = tester.getRect(
        find.byKey(const ValueKey('plan-student-selector-view')),
      );
      final gridSectionRect = tester.getRect(gridSection);
      final filterSectionRect = tester.getRect(filterSection);
      final conditionSectionRect = tester.getRect(conditionSection);
      for (final section in [gridSection, filterSection]) {
        expect(
          find.descendant(
            of: section,
            matching: find.byType(SectionTemplateSurface),
          ),
          findsNothing,
        );
        final foundations = tester
            .widgetList<CustomPaint>(
              find.descendant(of: section, matching: find.byType(CustomPaint)),
            )
            .where(
              (paint) => paint.painter is PlanStudentSelectorSectionPainter,
            )
            .toList();
        expect(foundations, hasLength(1));
      }
      for (final key in const [
        'plan-student-selector-grid-motion',
        'plan-student-selector-filter-motion',
        'plan-student-selector-condition-motion',
      ]) {
        final motion = tester.widget<PlanStudentSelectorMotion>(
          find.byKey(ValueKey(key)),
        );
        expect(motion.introDegrees, 80);
        expect(motion.outroDegrees, 260);
      }
      final section1Bounds = planSectionPath(
        selectorRect.size,
        'element-1',
      ).getBounds();
      final section1Right = planStudentSelectorSection1RightAtReference(
        selectorRect.size,
      );
      final selectorDepth = sectionTemplateCutDepth(gridSectionRect.height);
      final gridLeftAtReference =
          gridSectionRect.left - selectorRect.left + selectorDepth / 2;
      expect(
        gridLeftAtReference - section1Right,
        closeTo(planStudentSelectorSectionGap, 0.01),
      );
      expect(
        filterSectionRect.left +
            selectorDepth / 2 -
            (gridSectionRect.right - selectorDepth / 2),
        closeTo(planStudentSelectorSectionGap, 0.01),
      );
      expect(
        conditionSectionRect.left +
            selectorDepth / 2 -
            (filterSectionRect.right - selectorDepth / 2),
        closeTo(studentRangeConditionSectionGap, 0.01),
      );
      final localFilterLeft = filterSectionRect.left - selectorRect.left;
      final previousFilterWidth = selectorRect.width * 0.985 - localFilterLeft;
      expect(
        filterSectionRect.width,
        closeTo(
          previousFilterWidth * planStudentSelectorFilterWidthScale,
          0.01,
        ),
      );
      expect(gridSectionRect.top, closeTo(section1Bounds.top, 0.01));
      expect(gridSectionRect.bottom, closeTo(section1Bounds.bottom, 0.01));
      expect(filterSectionRect.top, closeTo(section1Bounds.top, 0.01));
      expect(filterSectionRect.bottom, closeTo(section1Bounds.bottom, 0.01));
      expect(conditionSectionRect.top, closeTo(section1Bounds.top, 0.01));
      expect(conditionSectionRect.bottom, closeTo(section1Bounds.bottom, 0.01));
      expect(
        find.descendant(
          of: conditionSection,
          matching: find.byType(PlanPresetElementCard),
        ),
        findsNWidgets(2),
      );
      final gridContainer = find.byKey(
        const ValueKey('plan-student-selector-grid-container'),
      );
      final filterContainer = find.byKey(
        const ValueKey('plan-student-selector-filter-container'),
      );
      expect(
        find.descendant(of: gridContainer, matching: find.byType(ClipPath)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: filterContainer, matching: find.byType(ClipPath)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: filterContainer,
          matching: find.byKey(const ValueKey('plan-student-selector-search')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: filterContainer,
          matching: find.byKey(
            const ValueKey('plan-student-selector-filter-reset'),
          ),
        ),
        findsNothing,
      );
      final filterOuterPath = buildSectionTemplatePath(
        filterSectionRect.size,
        SectionShape.bilateral,
      );
      Rect localControlRect(String key) => tester
          .getRect(find.byKey(ValueKey(key)))
          .shift(-filterSectionRect.topLeft)
          .deflate(1);
      for (final control in [
        localControlRect('plan-student-selector-search'),
        localControlRect('plan-student-selector-filter-reset'),
      ]) {
        expect(filterOuterPath.contains(control.topLeft), isTrue);
        expect(filterOuterPath.contains(control.topRight), isTrue);
        expect(filterOuterPath.contains(control.bottomLeft), isTrue);
        expect(filterOuterPath.contains(control.bottomRight), isTrue);
      }
      expect(
        tester.getRect(gridContainer).top - gridSectionRect.top,
        closeTo(planStudentSelectorInnerInset, 0.01),
      );
      final filterContainerRect = tester.getRect(filterContainer);
      final filterListRect = tester.getRect(
        find.byKey(const ValueKey('plan-student-selector-filter-list')),
      );
      expect(
        filterContainerRect.right - filterListRect.right,
        closeTo(planStudentSelectorFilterContentInset, 0.01),
      );
      expect(
        filterListRect.left - filterContainerRect.left,
        closeTo(planStudentSelectorFilterContentInset, 0.01),
      );
      expect(
        tester
            .widget<StudentViewportFog>(
              find.byKey(const ValueKey('student-filter-fog')),
            )
            .color,
        studentSection2ContainerColor,
      );
      expect(
        tester
            .widget<StudentDiagonalGrid>(
              find.byKey(const ValueKey('plan-student-selector-grid')),
            )
            .columns,
        planStudentSelectorGridColumns,
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey('plan-student-selector-search')))
            .top,
        lessThan(
          tester
              .getRect(
                find.byKey(const ValueKey('plan-student-selector-filter-list')),
              )
              .top,
        ),
      );

      Offset sectionMotionOffset(String id) {
        final transform = find.descendant(
          of: find.byKey(ValueKey('plan-$id-motion')),
          matching: find.byType(Transform),
        );
        final translation = tester
            .widget<Transform>(transform.first)
            .transform
            .getTranslation();
        return Offset(translation.x, translation.y);
      }

      expect(sectionMotionOffset('element-1'), Offset.zero);
      expect(sectionMotionOffset('element-2'), isNot(Offset.zero));

      await tester.enterText(
        find.byKey(const ValueKey('plan-student-selector-search')),
        '아루',
      );
      final filterList = tester.widget<StudentDiagonalFilterList>(
        find.byKey(const ValueKey('plan-student-selector-filter-list')),
      );
      expect(
        filterList.definitions!.map((definition) => definition.key),
        containsAll(const ['ownership', 'plan_status']),
      );
      filterList.onToggle('ownership', 'owned');
      await tester.pump();
      expect(filterList.selected['ownership'], contains('owned'));

      await tester.tap(
        find.byKey(
          const ValueKey('plan-range-condition-lower-enabled-control'),
        ),
      );
      await tester.pump();
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('plan-range-condition-lower-enabled-control'),
                ),
                matching: find.byType(Checkbox),
              ),
            )
            .value,
        isTrue,
      );

      await tester.tap(
        find.byKey(const ValueKey('plan-student-selector-launch')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanStudentSelector), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('plan-student-selector-launch')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('plan-student-selector-search')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('plan-range-condition-lower-enabled-control'),
                ),
                matching: find.byType(Checkbox),
              ),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<StudentDiagonalFilterList>(
              find.byKey(const ValueKey('plan-student-selector-filter-list')),
            )
            .selected['ownership'],
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'student selector panels play outro when the plan tab deactivates',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1440, 900));

      var active = true;
      late StateSetter setHostState;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return Scaffold(
                body: PlanningPage(service: service, active: active),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('plan-student-selector-launch')),
      );
      await tester.pumpAndSettle();

      Offset selectorMotionOffset(String panel) {
        final transform = find.descendant(
          of: find.byKey(ValueKey('plan-student-selector-$panel-motion')),
          matching: find.byType(Transform),
        );
        final translation = tester
            .widget<Transform>(transform.first)
            .transform
            .getTranslation();
        return Offset(translation.x, translation.y);
      }

      for (final panel in const ['grid', 'filter', 'condition']) {
        expect(selectorMotionOffset(panel), Offset.zero);
      }

      setHostState(() => active = false);
      await tester.pump();
      await tester.pump(
        Duration(
          milliseconds: planStudentSelectorMotionDuration.inMilliseconds ~/ 2,
        ),
      );

      for (final panel in const ['grid', 'filter', 'condition']) {
        final offset = selectorMotionOffset(panel);
        expect(offset.dx, lessThan(0));
        expect(offset.dy, greaterThan(0));
      }
      expect(find.byType(PlanStudentSelector), findsOneWidget);

      await tester.pumpAndSettle();
      setHostState(() => active = true);
      await tester.pumpAndSettle();

      for (final panel in const ['grid', 'filter', 'condition']) {
        expect(selectorMotionOffset(panel), Offset.zero);
      }
      Offset planMotionOffset(String id) {
        final transform = find.descendant(
          of: find.byKey(ValueKey('plan-$id-motion')),
          matching: find.byType(Transform),
        );
        final translation = tester
            .widget<Transform>(transform.first)
            .transform
            .getTranslation();
        return Offset(translation.x, translation.y);
      }

      expect(planMotionOffset('element-1'), Offset.zero);
      for (final id in const [
        'element-2',
        'element-3',
        'element-4',
        'element-5',
      ]) {
        expect(planMotionOffset(id), isNot(Offset.zero));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'student selection exits both panels before opening and reopening the builder',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(
        tester,
        service,
        size: const Size(2560, 1392),
        presets: [_planningTestPreset()],
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('plan-student-selector-launch')),
      );
      await tester.pumpAndSettle();
      final firstSelectionGrid = tester.widget<StudentDiagonalGrid>(
        find.byKey(const ValueKey('plan-student-selector-grid')),
      );
      final selectedStudentId = firstSelectionGrid.students.first.studentId;
      await tester.tap(find.byKey(ValueKey('student-$selectedStudentId')));
      await tester.pump();
      await tester.pump(
        Duration(
          milliseconds: planStudentSelectorMotionDuration.inMilliseconds ~/ 2,
        ),
      );

      expect(find.byType(PlanStudentSelector), findsOneWidget);
      expect(find.byType(PlanElementBuilder), findsNothing);
      for (final panel in const ['grid', 'filter', 'condition']) {
        final transform = find.descendant(
          of: find.byKey(ValueKey('plan-student-selector-$panel-motion')),
          matching: find.byType(Transform),
        );
        final translation = tester
            .widget<Transform>(transform.first)
            .transform
            .getTranslation();
        expect(translation.x, lessThan(0));
        expect(translation.y, greaterThan(0));
      }
      await tester.pumpAndSettle();

      expect(find.byType(PlanStudentSelector), findsNothing);
      expect(find.byType(PlanElementBuilder), findsOneWidget);
      expect(
        tester
            .widget<PlanElementBuilder>(find.byType(PlanElementBuilder))
            .seed
            .studentId,
        selectedStudentId,
      );

      await tester.tap(
        find.byKey(const ValueKey('plan-starter-preset-balanced-growth')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-starter-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('plan-starter-return-to-plan')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('plan-student-selector-launch')),
      );
      await tester.pumpAndSettle();
      final planFilterList = tester.widget<StudentDiagonalFilterList>(
        find.byKey(const ValueKey('plan-student-selector-filter-list')),
      );
      planFilterList.onToggle('plan_status', 'planned');
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('student-$selectedStudentId')));
      await tester.pumpAndSettle();

      final reopened = tester.widget<PlanElementBuilder>(
        find.byType(PlanElementBuilder),
      );
      expect(reopened.seed.studentId, selectedStudentId);
      expect(reopened.initialStages, isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scenario list keeps section 1 and uses the 80 to 260 diagonal workspace',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(tester, service, size: const Size(2560, 1392));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('plan-scenario-compare-launch')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
      await tester.pumpAndSettle();

      expect(find.byType(PlanScenarioListSection), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-element-1-foundation')),
        findsOneWidget,
      );
      expect(
        find.text('저장된 시나리오가 없습니다.\n섹션 1의 시나리오 생성 버튼으로 시작할 수 있습니다.'),
        findsOneWidget,
      );
      final motion = tester.widget<PlanSectionMotion>(
        find.byKey(const ValueKey('plan-scenario-list-motion')),
      );
      expect(motion.introDegrees, 80);
      expect(motion.outroDegrees, 260);
      expect(
        find.byKey(const ValueKey('plan-scenario-list-foundation')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
      await tester.pumpAndSettle();
      expect(find.byType(PlanScenarioListSection), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scenario creation reuses student builder and phase editor without bulk apply',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpPage(
        tester,
        service,
        size: const Size(2560, 1392),
        presets: [_planningTestPreset()],
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-create-launch')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanStudentSelector), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-scenario-bulk-apply')),
        findsNothing,
      );

      final grid = tester.widget<StudentDiagonalGrid>(
        find.byKey(const ValueKey('plan-student-selector-grid')),
      );
      await tester.tap(
        find.byKey(ValueKey('student-${grid.students.first.studentId}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanElementBuilder), findsOneWidget);

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
      await tester.tap(
        find.byKey(const ValueKey('plan-phase-editor-assign-all')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('plan-phase-editor-complete')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('plan-scenario-save-dialog')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('plan-scenario-name-field')),
        '빠른 성장 후보',
      );
      await tester.tap(
        find.byKey(const ValueKey('plan-scenario-save-confirm')),
      );
      await tester.pumpAndSettle();

      final list = await service.listScenarios('000000000000000000000001');
      expect(list.scenarios, hasLength(1));
      expect(list.scenarios.single.name, '빠른 성장 후보');
      expect(list.scenarios.single.phaseCount, 1);
      expect(
        find.byKey(const ValueKey('plan-scenario-create-launch')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('plan-scenario-list-launch')));
      await tester.pumpAndSettle();
      expect(find.text('빠른 성장 후보'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('plan-scenario-diagonal-scroll')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
