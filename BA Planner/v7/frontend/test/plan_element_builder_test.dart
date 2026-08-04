import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/studio/plan_starter_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/preset_element_studio_layout.dart';
import 'package:ba_planner_v7/ui/studio/section_studio_document.dart';
import 'package:ba_planner_v7/ui/studio/section_template.dart';
import 'package:ba_planner_v7/ui/widgets/asset_image_grid.dart';
import 'package:ba_planner_v7/ui/widgets/plan_element_builder.dart';
import 'package:ba_planner_v7/ui/widgets/plan_phase_editor.dart';
import 'package:ba_planner_v7/ui/widgets/section_template_surface.dart';
import 'package:ba_planner_v7/ui/widgets/student_section_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PlanningStudentSeed _seed({
  String handoffId = 'handoff-1',
  bool owned = true,
  bool jpOnly = false,
  String? hasFavoriteItem,
}) => PlanningStudentSeed(
  handoffId: handoffId,
  studentId: 'hoshino',
  metadata: {
    'student_id': 'hoshino',
    'display_name': '호시노',
    'rarity': '3',
    'school': 'Abydos',
    'equipment_slot_1': 'Shoes',
    'equipment_slot_2': 'Bag',
    'equipment_slot_3': 'Charm',
    'jp_only': jpOnly,
    ...hasFavoriteItem == null
        ? const <String, String>{}
        : {'has_favorite_item': hasFavoriteItem},
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

PlanElementPreset _threeStageTestPreset() => PlanElementPreset(
  id: 'balanced-growth',
  name: '테스트 프리셋',
  isDefault: false,
  stages: const [
    {'level': 30},
    {'level': 50},
    {'level': 70},
  ],
);

Future<void> _pumpBuilder(
  WidgetTester tester, {
  List<PlanElementStageDraft> initialStages = const [],
  ValueChanged<List<PlanElementStageDraft>>? onConfirm,
  PlanningStudentSeed? seed,
  bool hasPlanElements = false,
  List<PlanElementUnassignedItem> unassignedItems = const [],
  void Function(String id, String name)? onRenameUnassigned,
  ValueChanged<String>? onDeleteUnassigned,
  VoidCallback? onExitToPlan,
  VoidCallback? onOpenPhaseEditor,
}) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: PlanElementBuilder(
          seed: seed ?? _seed(),
          initialStages: initialStages,
          unassignedItems: unassignedItems,
          hasPlanElements: hasPlanElements,
          onConfirm: onConfirm ?? (_) {},
          onRenameUnassigned: onRenameUnassigned ?? (_, _) {},
          onDeleteUnassigned: onDeleteUnassigned ?? (_) {},
          onExitToPlan: onExitToPlan ?? () {},
          onOpenPhaseEditor: onOpenPhaseEditor ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('preset builder sections use the requested motion directions', () {
    expect(planElementBuilderSectionMotions['element-3']?.intro, 0);
    expect(planElementBuilderSectionMotions['element-3']?.outro, 180);
    expect(planElementBuilderSectionMotions['element-5']?.intro, 0);
    expect(planElementBuilderSectionMotions['element-5']?.outro, 180);
    expect(planElementBuilderSectionMotions['element-6']?.intro, 80);
    expect(planElementBuilderSectionMotions['element-6']?.outro, 260);
    expect(planElementBuilderSectionMotions['element-7']?.intro, 180);
    expect(planElementBuilderSectionMotions['element-7']?.outro, 0);
  });

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

  test('preset panels halve row gaps but preserve edge and column gaps', () {
    const width = 620.0;
    final size = Size(width, planPresetListCardHeight(width));
    final tangent = math.tan(80 * math.pi / 180);
    final sine = math.sin(80 * math.pi / 180);
    final rows = [
      planPresetElementRect(size, 'element-1'),
      planPresetElementRect(size, 'element-4'),
      planPresetElementRect(size, 'element-6'),
      planPresetElementRect(size, 'element-7'),
      planPresetElementRect(size, 'element-8'),
      planPresetElementRect(size, 'element-9'),
    ];
    final topRow = [
      planPresetElementRect(size, 'element-1'),
      planPresetElementRect(size, 'element-2'),
      planPresetElementRect(size, 'element-3'),
    ];

    expect(topRow.map((rect) => rect.top).toSet(), hasLength(1));
    expect(topRow.map((rect) => rect.height).toSet(), hasLength(1));
    for (var index = 0; index < topRow.length - 1; index++) {
      final currentRightRail =
          topRow[index].right + topRow[index].top / tangent;
      final nextLeftRail =
          topRow[index + 1].left + topRow[index + 1].bottom / tangent;
      expect(
        (nextLeftRail - currentRightRail) * sine,
        closeTo(planPresetElementColumnGap, 0.001),
      );
    }
    expect(rows.first.top, closeTo(planPresetElementEdgeGap, 0.001));
    for (var index = 0; index < rows.length - 1; index++) {
      expect(
        rows[index + 1].top - rows[index].bottom,
        closeTo(planPresetElementPanelGap, 0.001),
      );
    }
    expect(
      size.height - rows.last.bottom,
      closeTo(planPresetElementEdgeGap, 0.001),
    );
    final unit =
        (width / planPresetElementWidthScale * 36 / 28 - 24 * 7) /
        (4 + 1 + 4 + 7 + 3 + 3);
    expect(rows[0].height, closeTo(unit * 4 * 0.5, 0.001));
    expect(rows[1].height, closeTo(unit, 0.001));
    expect(rows[2].height, closeTo(unit * 4 * 0.6, 0.001));
    expect(rows[3].height, closeTo(unit * 7 * 0.63, 0.001));
    expect(rows[3].height / (unit * 7 * 0.6), closeTo(1.05, 0.001));
    expect(rows[4].height, closeTo(unit * 3 * 0.8, 0.001));
    expect(rows[5].height, closeTo(unit * 3, 0.001));
    for (final rect in rows) {
      final leftRail = rect.left + rect.bottom / tangent;
      expect(
        (leftRail - size.height / tangent) * sine,
        closeTo(planPresetElementEdgeGap, 0.001),
      );
    }
  });

  test(
    'condition preset layout reserves a diagonal header by compacting two rows',
    () {
      const width = 680.0;
      final standardSize = Size(width, planPresetListCardHeight(width));
      final conditionSize = Size(
        width,
        planPresetListCardHeight(
          width,
          layout: PlanPresetElementLayout.condition,
        ),
      );
      expect(conditionSize.height, closeTo(standardSize.height, 0.001));

      Rect standard(String id) => planPresetElementRect(standardSize, id);
      Rect condition(String id) => planPresetElementRect(
        conditionSize,
        id,
        layout: PlanPresetElementLayout.condition,
      );

      expect(
        condition('element-1').top - standard('element-1').top,
        closeTo(planPresetConditionHeaderReserve, 0.001),
      );
      expect(
        standard('element-6').height - condition('element-6').height,
        closeTo(planPresetConditionCompactRowReduction, 0.001),
      );
      expect(
        standard('element-8').height - condition('element-8').height,
        closeTo(planPresetConditionCompactRowReduction, 0.001),
      );
      expect(condition('element-7').height, standard('element-7').height);
      expect(
        condition('element-9').bottom,
        closeTo(standardSize.height - 24, 0.001),
      );

      final rows = [
        condition('element-1'),
        condition('element-4'),
        condition('element-6'),
        condition('element-7'),
        condition('element-8'),
        condition('element-9'),
      ];
      for (var index = 0; index < rows.length - 1; index++) {
        expect(
          rows[index + 1].top - rows[index].bottom,
          closeTo(planPresetElementPanelGap, 0.001),
        );
      }
      final tangent = math.tan(80 * math.pi / 180);
      final sine = math.sin(80 * math.pi / 180);
      for (final rect in rows) {
        final leftRail = rect.left + rect.bottom / tangent;
        expect(
          (leftRail - conditionSize.height / tangent) * sine,
          closeTo(planPresetElementEdgeGap, 0.001),
        );
      }
    },
  );

  test('preset element projection keeps the compact vertical contract', () {
    final byId = {
      for (final element in presetElementStudioDocument.elements)
        element.id: element.rect,
    };
    expect(presetElementReferenceBounds.width, 28);
    expect(presetElementReferenceBounds.height, 27);
    expect(byId['element-1']?.height, 3);
    expect(byId['element-2']?.height, 3);
    expect(byId['element-3']?.height, 3);
    expect(byId['element-4']?.height, 2);
    expect(byId['element-6']?.height, 3);
    expect(byId['element-7']?.height, 5);
    expect(byId['element-8']?.height, 3);
    expect(byId['element-9']?.height, 4);
  });

  test('preset list container follows the plan-main phase inset contract', () {
    const canvasSize = Size(2560, 1392);
    final sectionPath = planStarterSectionPath(canvasSize, 'element-6');
    final section = sectionPath.getBounds();
    final containerPath = planPresetListContainerPath(canvasSize);
    final container = containerPath.getBounds();
    final vertices = planPresetListContainerVertices(canvasSize);
    final content = planStageEditorContentRect(canvasSize);
    final tangent = math.tan(80 * math.pi / 180);
    final sine = math.sin(80 * math.pi / 180);
    final railInset = planElementBuilderGap / sine;
    final outside = Path.combine(
      PathOperation.difference,
      containerPath,
      sectionPath,
    );

    expect(outside.computeMetrics().isEmpty, isTrue);
    final sectionLeftRail = section.left + section.bottom / tangent;
    final sectionRightRail = section.right + section.top / tangent;
    final containerLeftRail = vertices.first.dx + vertices.first.dy / tangent;
    final containerRightRail = vertices[1].dx + vertices[1].dy / tangent;
    expect(
      (containerLeftRail - sectionLeftRail) * sine,
      closeTo(planElementBuilderGap, 0.001),
    );
    expect(
      (sectionRightRail - containerRightRail) * sine,
      closeTo(planElementBuilderGap, 0.001),
    );
    expect(vertices.first.dy - section.top, closeTo(12, 0.001));
    expect(
      section.bottom - vertices.last.dy,
      closeTo(
        planStarterStageControlHeight +
            planStarterStageControlBottomInset +
            planElementBuilderGap +
            planStarterStageMessageHeight +
            planStarterStageMessageGap,
        0.001,
      ),
    );
    final contentTop = content.top - container.top;
    final contentLeftRail =
        content.left - container.left + (contentTop + content.height) / tangent;
    final horizontalCenterOffset =
        (content.width / planPresetElementWidthScale - content.width) / 2;
    expect(
      (contentLeftRail - container.height / tangent) * sine,
      closeTo(planElementBuilderGap + horizontalCenterOffset * sine, 0.001),
    );
    expect(
      content.width / planPresetElementWidthScale,
      closeTo(
        container.width -
            container.height / tangent -
            railInset * 2 -
            14 +
            content.height / tangent,
        0.001,
      ),
    );
  });

  test('stage cards follow the 80 degree rail while scrolling', () {
    const viewportHeight = 900.0;
    const itemTop = 180.0;
    const itemHeight = 560.0;
    final before = planStageDiagonalCardLeft(
      viewportHeight: viewportHeight,
      itemTop: itemTop,
      itemHeight: itemHeight,
      scrollOffset: 0,
      cardWidth: 420,
    );
    final after = planStageDiagonalCardLeft(
      viewportHeight: viewportHeight,
      itemTop: itemTop,
      itemHeight: itemHeight,
      scrollOffset: 120,
      cardWidth: 420,
    );

    expect(after - before, closeTo(120 / math.tan(80 * math.pi / 180), 0.001));
  });

  test('unassigned rows follow the same 80 degree scroll rail', () {
    final before = planUnassignedRowLeft(
      viewportHeight: 900,
      rowTop: 180,
      rowHeight: 66,
      scrollOffset: 0,
    );
    final after = planUnassignedRowLeft(
      viewportHeight: 900,
      rowTop: 180,
      rowHeight: 66,
      scrollOffset: 120,
    );
    expect(after - before, closeTo(120 / math.tan(80 * math.pi / 180), 0.001));
  });

  test('builder controls and unassigned rows use exact 80 degree paths', () {
    const buttonSize = Size(180, planStarterStageControlHeight);
    const rowSize = Size(462, 60);
    final tangent = math.tan(80 * math.pi / 180);
    for (final path in [
      planStarterControlButtonPath(buttonSize),
      planUnassignedItemPath(rowSize),
    ]) {
      final bounds = path.getBounds();
      final depth = bounds.height / tangent;
      expect(path.contains(const Offset(1, 1)), isFalse);
      expect(path.contains(Offset(depth + 4, 4)), isTrue);
      expect(
        path.contains(Offset(bounds.width - 1, bounds.height - 1)),
        isFalse,
      );
    }
  });

  test(
    'right list and phase action reuse the requested blue-purple palettes',
    () {
      expect(planPresetListTexture.baseColor, const Color(0x8a29435b));
      expect(planPresetListTexture.panelColor, const Color(0x8a355a75));
      expect(planPresetListTexture.randomSeed, 8404);
      expect(planPresetListTexture, same(phaseEditorPathSurfaceTexture));
      final action = planStarterPhaseActionTexture(60);
      expect(action.baseColor, const Color(0xff80688e));
      expect(action.panelColor, const Color(0xff92779e));
      expect(action.triangleSize, closeTo(48, 0.001));
    },
  );

  test('right action buttons stack inside the section diagonal', () {
    const size = Size(2560, 1392);
    final geometry = planStarterRightSectionGeometry(size);
    final section = planStarterSectionPath(size, 'element-7');
    final deleteBounds = geometry.deleteButtonPath.getBounds();
    final returnBounds = geometry.returnButtonPath.getBounds();
    final phaseBounds = geometry.buttonPath.getBounds();

    expect(deleteBounds.bottom, lessThan(returnBounds.top));
    expect(returnBounds.bottom, lessThan(phaseBounds.top));
    for (final bounds in [deleteBounds, returnBounds, phaseBounds]) {
      expect(bounds.isEmpty, isFalse);
      expect(section.contains(bounds.center), isTrue);
    }
  });

  test('right list shrinks to 70 percent while action sizes stay fixed', () {
    const size = Size(2560, 1392);
    final current = planStarterRightSectionGeometry(size);
    final legacy = planStarterRightSectionGeometry(
      size,
      sectionRectOverride: const SectionGridRect(68, 3, 28, 90),
    );
    final currentSection = planStarterSectionRect(size, 'element-7');

    expect(currentSection.right, closeTo(size.width, 0.001));
    expect(
      current.listPath.getBounds().width / legacy.listPath.getBounds().width,
      closeTo(0.70, 0.01),
    );
    for (final pair in [
      (current.deleteButtonPath, legacy.deleteButtonPath),
      (current.returnButtonPath, legacy.returnButtonPath),
      (current.buttonPath, legacy.buttonPath),
    ]) {
      expect(
        pair.$1.getBounds().width,
        closeTo(pair.$2.getBounds().width, 0.01),
      );
      expect(
        pair.$1.getBounds().height,
        closeTo(pair.$2.getBounds().height, 0.01),
      );
      expect(
        pair.$1.getBounds().right,
        closeTo(pair.$2.getBounds().right, 0.01),
      );
    }
  });

  test('stale diagonal-list offsets clamp to the shortened content extent', () {
    expect(
      planStageEffectiveScrollOffset(
        rawOffset: 720,
        contentHeight: 840,
        viewportHeight: 800,
      ),
      40,
    );
    expect(
      planStageEffectiveScrollOffset(
        rawOffset: 720,
        contentHeight: 760,
        viewportHeight: 800,
      ),
      0,
    );
  });

  test('preset element envelope contains every panel path', () {
    const width = 480.0;
    final size = Size(width, planPresetListCardHeight(width));
    final envelope = planPresetElementEnvelopePath(size);
    for (final element in presetElementStudioDocument.elements) {
      if (element.id == 'element-5') continue;
      final outside = Path.combine(
        PathOperation.difference,
        planPresetElementPath(size, element.id),
        envelope,
      );
      expect(
        outside.computeMetrics().isEmpty,
        isTrue,
        reason: '${element.id} must be enclosed by the card envelope',
      );
    }
  });

  test('preset element envelope is one exact 80 degree parallelogram', () {
    const width = 480.0;
    final size = Size(width, planPresetListCardHeight(width));
    final vertices = planPresetElementEnvelopeVertices(size);
    expect(vertices, hasLength(4));
    for (final vertex in vertices) {
      expect(vertex.dx, inInclusiveRange(0, size.width));
      expect(vertex.dy, inInclusiveRange(0, size.height));
    }
    final leftEdge = vertices[3] - vertices[0];
    final rightEdge = vertices[2] - vertices[1];
    final leftAngle =
        math.atan2(leftEdge.dy.abs(), leftEdge.dx.abs()) * 180 / math.pi;
    final rightAngle =
        math.atan2(rightEdge.dy.abs(), rightEdge.dx.abs()) * 180 / math.pi;
    expect(leftAngle, closeTo(80, 0.001));
    expect(rightAngle, closeTo(80, 0.001));
    expect(leftEdge.dx, closeTo(rightEdge.dx, 0.001));
    expect(leftEdge.dy, closeTo(rightEdge.dy, 0.001));
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
    final section3 = planStarterStudioDocument.elements.firstWhere(
      (item) => item.id == 'element-3',
    );
    expect(section3.rect.width, 27);
    expect(
      planStarterStudioDocument.containers
          .where((item) => item.parentSectionId == 'element-3')
          .map((item) => item.id),
      const [
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
        (item) => item.id == 'container-1',
      ),
      isFalse,
    );
    expect(
      planStarterStudioDocument.containers.any(
        (item) => item.id == 'container-10',
      ),
      isFalse,
    );
    final bond = planStarterContainer('container-8');
    expect(bond.spec.mode, SectionShapeMode.triangle);
    expect(bond.spec.face, SectionAttachmentFace.left);
    expect(bond.triangleTexture, isTrue);
    expect(bond.rect.left, planStarterContainer('container-5').rect.left);
    expect(bond.rect.height, closeTo(0.3075401951251054 * 1.3, 0.0000000001));
    final metadata = planStarterContainer('container-2');
    expect(metadata.rect.left, closeTo(0.5602870942110612, 0.0000000001));
    expect(metadata.rect.width, closeTo(0.3479522131790751, 0.0000000001));
    expect(metadata.rect.right, closeTo(0.9082393073901363, 0.0000000001));
    expect(
      planStarterStatusFoundationPaintsContainer(
        planStarterContainer('container-3'),
      ),
      isFalse,
    );
    expect(
      planStarterStatusFoundationPaintsContainer(
        planStarterContainer('container-5'),
      ),
      isTrue,
    );
  });

  test('Section 3 panels follow the resized outer rail', () {
    const size = Size(2560, 1392);
    final section = planStarterStudioDocument.elements.firstWhere(
      (item) => item.id == 'element-3',
    );
    final sectionRect = sectionCanvasElementRect(size, section);
    final tangent = math.tan(80 * math.pi / 180);

    List<Offset> rawPoints(String id) {
      final container = planStarterContainer(id);
      final rect = studioContainerRect(
        size,
        planStarterStudioDocument.elements,
        container,
      )!;
      return buildAttachedSectionPolygon(
        rect.size,
        container.spec,
        gridSize: sectionTemplateDetailGridSize,
      ).map((point) => point + rect.topLeft).toList(growable: false);
    }

    double outerRightAt(double y) =>
        sectionRect.right - (y - sectionRect.top) / tangent;

    for (final id in const [
      'container-3',
      'container-5',
      'container-6',
      'container-7',
      'container-9',
    ]) {
      final points = rawPoints(id);
      final topRight = points[1];
      expect(outerRightAt(topRight.dy) - topRight.dx, closeTo(12, 0.01));
    }

    final bondPath = planStarterContainerPath(size, 'container-8');
    expect(bondPath.getBounds().height, greaterThan(242));
    final bondPoints = rawPoints('container-8');
    final skillPoints = rawPoints('container-5');
    expect(bondPoints[0].dx, closeTo(skillPoints[0].dx, 0.001));
    expect(bondPoints[2].dx, closeTo(skillPoints[3].dx, 0.001));
    final portraitSlot = planStarterPortraitRect(size);
    final portraitCard = Alignment.center.inscribe(
      applyBoxFit(
        BoxFit.contain,
        studentGridCardSourceSize,
        portraitSlot.size,
      ).destination,
      portraitSlot,
    );
    final portraitPath = studentGridCardPath(portraitCard);
    final metadataPath = planStarterContainerPath(size, 'container-2');
    expect(portraitCard, portraitSlot);
    expect(portraitCard.height, closeTo(metadataPath.getBounds().height, 0.01));
    expect(
      Path.combine(
        PathOperation.intersect,
        bondPath,
        portraitPath,
      ).computeMetrics(),
      isEmpty,
    );
    expect(portraitSlot.left, greaterThan(sectionRect.left + 90));

    final metadata = rawPoints('container-2');
    expect(metadata[0].dx - portraitCard.right, closeTo(12, 0.01));
    final metadataTopRight = metadata[1];
    expect(
      outerRightAt(metadataTopRight.dy) - metadataTopRight.dx,
      inInclusiveRange(12, 16),
    );
  });

  test('level and school split follows an exact 80 degree rail', () {
    const size = Size(240, 120);
    final endpoints = studentLevelSplitEndpoints(size);
    final run = (endpoints.first.dx - endpoints.last.dx).abs();
    final rise = (endpoints.last.dy - endpoints.first.dy).abs();
    final angle = math.atan2(rise, run) * 180 / math.pi;

    expect(angle, closeTo(80, 0.000001));
    final valueRegion = studentLevelValueRegion(size);
    final schoolRegion = studentLevelSchoolRegion(size);
    expect(valueRegion.right, closeTo(endpoints.last.dx, 0.000001));
    expect(schoolRegion.left, closeTo(endpoints.first.dx, 0.000001));
    expect(valueRegion.overlaps(schoolRegion), isFalse);
    expect(schoolRegion.left - valueRegion.right, closeTo(run, 0.000001));
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
    for (final id in const [
      'element-3',
      'element-5',
      'element-6',
      'element-7',
    ]) {
      expect(find.byKey(ValueKey('plan-starter-$id-motion')), findsOne);
    }
    expect(
      find.byKey(const ValueKey('plan-preset-list-container-foundation')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('plan-starter-stage-diagonal-scrollbar')),
      findsOne,
    );
    expect(find.byKey(const ValueKey('plan-starter-stage-fog')), findsOne);
    expect(find.text('호시노'), findsNothing);
    for (final id in const [
      'container-5',
      'container-6',
      'container-7',
      'container-8',
      'container-9',
    ]) {
      expect(find.byKey(ValueKey('plan-starter-status-$id')), findsOne);
    }
    expect(
      find.byKey(const ValueKey('plan-starter-status-container-1')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('plan-starter-student-portrait-host')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('plan-starter-status-container-10')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('student-detail-level')), findsOne);
    expect(find.byKey(const ValueKey('student-detail-level-only')), findsOne);
    expect(
      find.byKey(const ValueKey('student-detail-level-split')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-detail-school-region')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('student-detail-school-logo')),
      findsNothing,
    );
    final levelStatus = tester.widget<StudentLevelStatus>(
      find.byType(StudentLevelStatus),
    );
    expect(levelStatus.showSchool, isFalse);
    expect(levelStatus.schoolLogoAsset, isNull);
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
    expect(bondStatus.inverted, isTrue);
    expect(bondStatus.fillFromBottom, isTrue);
    const gaugeBounds = Rect.fromLTWH(10, 20, 30, 100);
    expect(
      studentBondGaugeFillRect(
        gaugeBounds,
        0.4,
        fillFromBottom: bondStatus.fillFromBottom,
      ),
      const Rect.fromLTRB(10, 80, 40, 120),
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
    final bondHost = find.byKey(
      const ValueKey('plan-starter-status-container-8'),
    );
    expect(
      find.descendant(of: bondHost, matching: find.byType(ColoredBox)),
      findsNothing,
    );
    expect(
      find.descendant(of: bondHost, matching: find.byType(CustomPaint)),
      findsOne,
    );
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(
      find.byKey(const ValueKey('plan-starter-bond-metadata-header')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('plan-starter-student-name')),
      findsNothing,
    );
    final portrait = tester.widget<AssetImageGrid>(
      find.byKey(const ValueKey('plan-starter-student-portrait')),
    );
    expect(portrait.items.first.edgeCropFraction, 0.11);
    expect(portrait.items.first.clipPathBuilder, studentGridCardPath);
    expect(portrait.items.last.scale, 0.98);
    expect(portrait.items.last.clipRadiusFraction, 0.12);
    expect(portrait.items.last.alphaThreshold, 0.04);
    final portraitOverlay = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('plan-starter-student-portrait-status')),
    );
    final overlayPainter =
        portraitOverlay.painter! as StudentGridCardOverlayPainter;
    expect(overlayPainter.ownedIds, {'hoshino'});
    expect(overlayPainter.plannedIds, isEmpty);
    expect(overlayPainter.students.single.jpOnly, isFalse);
    expect(
      find.byKey(const ValueKey('student-detail-favorite-locked')),
      findsNothing,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('student-detail-favorite-value')),
          )
          .data,
      '-',
    );
    expect(
      find.byKey(const ValueKey('student-detail-potential-locked')),
      findsOne,
    );
  });

  testWidgets('portrait badges follow ownership, plan, and JP metadata', (
    tester,
  ) async {
    await _pumpBuilder(
      tester,
      seed: _seed(owned: false, jpOnly: true),
      hasPlanElements: true,
    );

    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('plan-starter-student-portrait-status')),
    );
    final painter = customPaint.painter! as StudentGridCardOverlayPainter;
    expect(painter.ownedIds, isEmpty);
    expect(painter.plannedIds, {'hoshino'});
    expect(painter.students.single.jpOnly, isTrue);
  });

  testWidgets('favorite item locks only when its metadata exists', (
    tester,
  ) async {
    await _pumpBuilder(tester, seed: _seed(hasFavoriteItem: 'yes'));

    expect(
      find.byKey(const ValueKey('student-detail-favorite-locked')),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey('student-detail-favorite-value')),
      findsNothing,
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
      tester
          .widget<Text>(
            find.descendant(
              of: firstCard,
              matching: find.byKey(const ValueKey('plan-stage-1-level-value')),
            ),
          )
          .data,
      '2',
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: secondCard,
              matching: find.byKey(const ValueKey('plan-stage-2-level-value')),
            ),
          )
          .data,
      '2',
    );

    await tester.tap(find.byKey(const ValueKey('plan-stage-1-level-decrease')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: firstCard,
              matching: find.byKey(const ValueKey('plan-stage-1-level-value')),
            ),
          )
          .data,
      '1',
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: secondCard,
              matching: find.byKey(const ValueKey('plan-stage-2-level-value')),
            ),
          )
          .data,
      '2',
    );
  });

  testWidgets('stage card wraps all nine surfaces at the scaled width', (
    tester,
  ) async {
    await _pumpBuilder(tester);

    final card = find.byKey(
      const ValueKey('plan-starter-stage-hoshino-stage-1'),
    );
    final size = tester.getSize(card);
    expect(size.height, closeTo(planPresetListCardHeight(size.width), 0.001));
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
      const Size(22, 24),
    );
    final starStatus = tester.widget<StudentStarStatus>(
      find.descendant(of: card, matching: find.byType(StudentStarStatus)),
    );
    expect(starStatus.studentStars, 3);
    expect(starStatus.weaponStars, 0);
    expect(starStatus.targetStudentStars, 3);
    expect(starStatus.targetWeaponStars, 0);
  });

  testWidgets(
    'editable preset element card can be hosted outside the builder',
    (tester) async {
      const width = 1000.0;
      final current = planElementCurrentTargets(_seed());
      final changes = <String, int>{};
      var selected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: planPresetListCardHeight(width),
                child: PlanPresetElementCard(
                  key: const ValueKey('standalone-editable-preset-card'),
                  stage: PlanElementStageDraft(
                    id: 'standalone-stage',
                    name: '외부 단계',
                    targets: {...current, 'level': 2},
                  ),
                  startTargets: current,
                  stageNumber: 1,
                  selected: false,
                  propagatedFields: const {},
                  equipmentTypes: const ['Shoes', 'Bag', 'Charm'],
                  hasFavoriteItem: true,
                  onSelected: () => selected = true,
                  onChanged: (key, value) => changes[key] = value,
                ),
              ),
            ),
          ),
        ),
      );

      final card = find.byKey(
        const ValueKey('standalone-editable-preset-card'),
      );
      expect(card, findsOneWidget);
      final cardInkWell = find
          .descendant(of: card, matching: find.byType(InkWell))
          .first;
      tester.widget<InkWell>(cardInkWell).onTap!();
      expect(selected, isTrue);

      await tester.tap(
        find.byKey(const ValueKey('plan-stage-1-level-increase')),
      );
      await tester.pump();
      expect(changes['level'], 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preset cards use phase-style flow triangles between items', (
    tester,
  ) async {
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

    expect(find.byKey(const ValueKey('plan-starter-stage-flow-0')), findsOne);
    expect(find.byKey(const ValueKey('plan-starter-stage-flow-1')), findsOne);
    expect(
      find.byKey(const ValueKey('plan-preset-flow-triangle')),
      findsNWidgets(2),
    );
    final firstCard = tester.getRect(
      find.byKey(const ValueKey('plan-starter-stage-stage-1')),
    );
    final firstTriangle = tester.getRect(
      find.byKey(const ValueKey('plan-preset-flow-triangle')).first,
    );
    expect(
      firstTriangle.center.dx,
      closeTo(
        firstCard.left +
            (firstCard.width -
                    firstCard.height / math.tan(80 * math.pi / 180)) /
                2,
        0.5,
      ),
    );
  });

  testWidgets(
    'right section mirrors the phase panel with editable media rows',
    (tester) async {
      String? renamed;
      await _pumpBuilder(
        tester,
        unassignedItems: const [
          PlanElementUnassignedItem(
            id: 'stage-1',
            studentId: 'hoshino',
            displayName: '호시노',
            stageNumber: 1,
            stageName: '1단계',
            targetSummary: 'Lv. 2',
          ),
        ],
        onRenameUnassigned: (_, name) => renamed = name,
      );

      final builder = find.byType(PlanElementBuilder);
      final canvasSize = tester.getSize(builder);
      final geometry = planStarterRightSectionGeometry(canvasSize);
      final containerPath = geometry.listPath;
      final containerBounds = containerPath.getBounds();
      final listHost = tester.getRect(
        find.byKey(const ValueKey('plan-starter-unassigned-list-host')),
      );
      final foundation = tester.getRect(
        find.byKey(
          const ValueKey('plan-starter-unassigned-container-foundation'),
        ),
      );
      expect(listHost.width, closeTo(containerBounds.width, 0.001));
      expect(foundation, listHost);
      expect(
        find.byKey(const ValueKey('plan-starter-open-phase-editor')),
        findsOne,
      );
      final phaseButtonTap = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(const ValueKey('plan-starter-open-phase-editor')),
          matching: find.byType(InkWell),
        ),
      );
      expect(phaseButtonTap.onTap, isNull);
      expect(
        find.byKey(const ValueKey('plan-starter-phase-action-texture')),
        findsOne,
      );
      expect(
        planStarterSectionPath(
          canvasSize,
          'element-7',
        ).contains(geometry.buttonPath.getBounds().center),
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('plan-starter-unassigned-count')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plan-starter-unassigned-scroll')),
        findsOne,
      );
      expect(
        find.byKey(
          const ValueKey('plan-starter-unassigned-container-foundation'),
        ),
        findsOne,
      );
      expect(
        find.byKey(
          const ValueKey('plan-starter-unassigned-diagonal-scrollbar'),
        ),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('plan-unassigned-row-host-stage-1')),
        findsOne,
      );
      final row = tester.getRect(
        find.byKey(const ValueKey('plan-unassigned-row-host-stage-1')),
      );
      final nameField = tester.getRect(
        find.byKey(const ValueKey('plan-unassigned-name-stage-1')),
      );
      final media = tester.getRect(
        find.byKey(const ValueKey('plan-unassigned-media-stage-1')),
      );
      expect(row.width, greaterThan(containerBounds.width * 0.45));
      expect(containerPath.contains(row.center), isTrue);
      expect(containerPath.contains(nameField.center), isTrue);
      expect(containerPath.contains(media.center), isTrue);
      expect(find.text('호시노 ·'), findsOne);

      await tester.enterText(
        find.byKey(const ValueKey('plan-unassigned-name-stage-1')),
        '새 단계',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(renamed, '새 단계');
    },
  );

  testWidgets('restored phase button opens only after plan elements exist', (
    tester,
  ) async {
    var opened = false;
    await _pumpBuilder(
      tester,
      hasPlanElements: true,
      onOpenPhaseEditor: () => opened = true,
    );

    final button = find.byKey(const ValueKey('plan-starter-open-phase-editor'));
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: button, matching: find.byType(InkWell)),
          )
          .onTap,
      isNotNull,
    );
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 180));
    expect(opened, isFalse);
    await tester.pumpAndSettle();
    expect(opened, isTrue);
  });

  testWidgets('right list selection enables deletion for one stage', (
    tester,
  ) async {
    String? deleted;
    await _pumpBuilder(
      tester,
      unassignedItems: const [
        PlanElementUnassignedItem(
          id: 'stage-1',
          studentId: 'hoshino',
          displayName: 'Hoshino',
          stageNumber: 1,
          stageName: 'Stage 1',
          targetSummary: 'Lv. 2',
        ),
        PlanElementUnassignedItem(
          id: 'stage-2',
          studentId: 'hoshino',
          displayName: 'Hoshino',
          stageNumber: 2,
          stageName: 'Stage 2',
          targetSummary: 'Lv. 3',
        ),
      ],
      onDeleteUnassigned: (id) => deleted = id,
    );

    final delete = find.byKey(const ValueKey('plan-starter-delete-unassigned'));
    InkWell deleteInk() => tester.widget<InkWell>(
      find.descendant(of: delete, matching: find.byType(InkWell)),
    );
    expect(deleteInk().onTap, isNull);

    await tester.tap(
      find.byKey(const ValueKey('plan-unassigned-media-stage-1')),
    );
    await tester.pump();
    expect(deleteInk().onTap, isNotNull);

    await tester.tap(delete);
    await tester.pump();
    expect(deleted, 'stage-1');
  });

  testWidgets('return button waits for the builder outro', (tester) async {
    var returned = false;
    await _pumpBuilder(tester, onExitToPlan: () => returned = true);

    await tester.tap(find.byKey(const ValueKey('plan-starter-return-to-plan')));
    await tester.pump(const Duration(milliseconds: 180));
    expect(returned, isFalse);
    await tester.pumpAndSettle();
    expect(returned, isTrue);
  });

  testWidgets(
    'blocked reason occupies the reserved strip above slanted controls',
    (tester) async {
      await _pumpBuilder(tester);

      final reason = find.byKey(const ValueKey('plan-starter-blocked-reason'));
      final reasonHost = find.byKey(
        const ValueKey('plan-starter-blocked-reason-host'),
      );
      expect(reason, findsOne);
      expect(find.text('현재 상태보다 높은 목표를 하나 이상 설정하세요.'), findsOne);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('plan-starter-stage-scroll')))
            .bottom,
        lessThan(tester.getRect(reasonHost).top),
      );

      for (final key in const [
        ValueKey('plan-starter-add-stage'),
        ValueKey('plan-starter-remove-stage'),
        ValueKey('plan-starter-reset'),
        ValueKey('plan-starter-confirm'),
      ]) {
        final button = find.byKey(key);
        expect(button, findsOne);
        expect(
          find.descendant(
            of: button,
            matching: find.byKey(
              const ValueKey('plan-starter-control-button-paint'),
            ),
          ),
          findsOne,
        );
      }
      final confirm = find.byKey(const ValueKey('plan-starter-confirm'));
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: confirm, matching: find.byType(InkWell)),
            )
            .onTap,
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('plan-stage-1-level-max')));
      await tester.pumpAndSettle();
      expect(reason, findsNothing);
      expect(
        tester
            .widget<InkWell>(
              find.descendant(of: confirm, matching: find.byType(InkWell)),
            )
            .onTap,
        isNotNull,
      );
    },
  );

  testWidgets('preset controls use indicator proportions and max badges', (
    tester,
  ) async {
    List<PlanElementStageDraft>? confirmed;
    await _pumpBuilder(tester, onConfirm: (value) => confirmed = value);
    final card = find.byKey(
      const ValueKey('plan-starter-stage-hoshino-stage-1'),
    );

    final levelValue = tester.widget<Text>(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('plan-stage-1-level-value')),
      ),
    );
    expect(levelValue.style?.fontSize, 25.2);
    expect(find.descendant(of: card, matching: find.text('Lv')), findsNothing);
    expect(find.descendant(of: card, matching: find.text('EX')), findsNothing);
    expect(find.descendant(of: card, matching: find.text('R')), findsNothing);
    final bondValue = tester.widget<Text>(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('plan-stage-1-bond_rank-value')),
      ),
    );
    expect(bondValue.data, isNot(endsWith('*')));
    final starSurface = tester.widget<ColoredBox>(
      find.byKey(
        const ValueKey('plan-preset-element-1-element-4-surface-fill'),
      ),
    );
    final starSurfacePaint = tester.widget<CustomPaint>(
      find.byKey(
        const ValueKey('plan-preset-element-1-element-4-surface-paint'),
      ),
    );
    expect(starSurface.color, Colors.transparent);
    expect(starSurfacePaint.foregroundPainter, isNull);

    final plus = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('plan-stage-1-level-increase')),
        matching: find.text('+'),
      ),
    );
    expect(plus.style?.fontSize, 16.5);
    expect(find.byKey(const ValueKey('plan-stage-1-level-max')), findsOne);

    final atkLabel = tester.widget<Text>(
      find.byKey(const ValueKey('plan-stage-1-stat_atk-label')),
    );
    final atkValue = tester.widget<Text>(
      find.byKey(const ValueKey('plan-stage-1-stat_atk-value')),
    );
    expect(atkLabel.data, 'ATK');
    expect(atkLabel.style?.fontSize, 13.5);
    expect(atkValue.style?.fontSize, 13.5);
    expect(find.text('공격'), findsNothing);
    expect(find.text('치유'), findsNothing);

    final equipmentIcon = find.byKey(
      const ValueKey('plan-stage-1-equipment-1-icon'),
    );
    expect(equipmentIcon, findsOne);
    expect(
      tester.widget<FractionallySizedBox>(equipmentIcon).widthFactor,
      0.672,
    );

    await tester.tap(find.byKey(const ValueKey('plan-stage-1-level-max')));
    await tester.tap(
      find.byKey(const ValueKey('plan-stage-1-equipment-1-max')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-starter-confirm')));
    await tester.pump();
    expect(confirmed?.single.targets['level'], 90);
    expect(confirmed?.single.targets['equip1_tier'], 10);
    expect(confirmed?.single.targets['equip1_level'], 70);
  });

  testWidgets('top-row steppers are centered in their compact panels', (
    tester,
  ) async {
    await _pumpBuilder(tester);

    for (final entry in const {
      'element-1': 'level',
      'element-2': 'weapon_level',
      'element-3': 'bond_rank',
    }.entries) {
      final panel = find.byKey(ValueKey('plan-preset-element-1-${entry.key}'));
      final stepper = find.byKey(ValueKey('plan-stage-1-${entry.value}'));
      expect(
        tester.getCenter(stepper).dx,
        closeTo(tester.getCenter(panel).dx, 0.5),
      );
    }
  });

  testWidgets('resized preset containers enclose their controls', (
    tester,
  ) async {
    await _pumpBuilder(tester);
    for (final entry in const {
      'element-1': 'plan-stage-1-level-max',
      'element-3': 'plan-stage-1-bond_rank-max',
      'element-6': 'plan-stage-1-ex_skill-max',
      'element-7': 'plan-stage-1-equipment-1-max',
      'element-8': 'plan-stage-1-stat_atk-max',
    }.entries) {
      final surface = tester.getRect(
        find.byKey(ValueKey('plan-preset-element-1-${entry.key}')),
      );
      final control = tester.getRect(find.byKey(ValueKey(entry.value)));
      expect(
        surface.contains(control.topLeft) &&
            surface.contains(control.bottomRight),
        isTrue,
        reason: '${entry.value} must remain inside ${entry.key}',
      );
    }
  });

  testWidgets('equipment max badges keep explicit lower-edge clearance', (
    tester,
  ) async {
    await _pumpBuilder(tester);
    final equipmentPanel = tester.getRect(
      find.byKey(const ValueKey('plan-preset-element-1-element-7')),
    );

    for (var slot = 1; slot <= 3; slot++) {
      final badge = tester.getRect(
        find.byKey(ValueKey('plan-stage-1-equipment-$slot-max')),
      );
      expect(
        equipmentPanel.bottom - badge.bottom,
        greaterThanOrEqualTo(6),
        reason: 'equipment slot $slot MAX badge must clear the lower edge',
      );
    }
  });

  testWidgets('star strip writes student and weapon star targets', (
    tester,
  ) async {
    List<PlanElementStageDraft>? confirmed;
    await _pumpBuilder(tester, onConfirm: (value) => confirmed = value);

    await tester.tap(find.byKey(const ValueKey('plan-stage-1-student-star-5')));
    await tester.tap(find.byKey(const ValueKey('plan-stage-1-weapon-star-4')));
    await tester.pump();
    final starStatus = tester.widget<StudentStarStatus>(
      find.byType(StudentStarStatus),
    );
    expect(starStatus.studentStars, 3);
    expect(starStatus.weaponStars, 0);
    expect(starStatus.targetStudentStars, 5);
    expect(starStatus.targetWeaponStars, 4);
    await tester.tap(find.byKey(const ValueKey('plan-starter-confirm')));
    await tester.pump();

    expect(confirmed?.single.targets['student_star'], 5);
    expect(confirmed?.single.targets['weapon_star'], 4);
  });

  testWidgets('later star strips fill from the previous stage snapshot', (
    tester,
  ) async {
    final current = planElementCurrentTargets(_seed());
    await _pumpBuilder(
      tester,
      initialStages: [
        PlanElementStageDraft(
          id: 'stage-1',
          name: '1단계',
          targets: {...current, 'student_star': 4, 'weapon_star': 1},
        ),
        PlanElementStageDraft(
          id: 'stage-2',
          name: '2단계',
          targets: {...current, 'student_star': 5, 'weapon_star': 3},
        ),
      ],
    );

    final secondCard = find.byKey(const ValueKey('plan-starter-stage-stage-2'));
    final status = tester.widget<StudentStarStatus>(
      find.descendant(of: secondCard, matching: find.byType(StudentStarStatus)),
    );
    expect(status.studentStars, 4);
    expect(status.weaponStars, 1);
    expect(status.targetStudentStars, 5);
    expect(status.targetWeaponStars, 3);
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
    final addedLevel = find.descendant(
      of: added,
      matching: find.byKey(const ValueKey('plan-stage-2-level-value')),
    );
    expect(tester.widget<Text>(addedLevel).data, '2');
  });

  testWidgets('deleting a scrolled stage restores the first card rail', (
    tester,
  ) async {
    await _pumpBuilder(tester);
    const firstCardKey = ValueKey('plan-starter-stage-hoshino-stage-1');
    final initialLeft = tester.getTopLeft(find.byKey(firstCardKey)).dx;

    await tester.tap(find.byKey(const ValueKey('plan-starter-add-stage')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('plan-starter-add-stage')));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('plan-starter-stage-scroll')),
      const Offset(0, -1200),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(firstCardKey)).dx,
      greaterThan(initialLeft),
    );

    await tester.tap(find.byKey(const ValueKey('plan-starter-remove-stage')));
    await tester.pump();

    final viewport = find.byKey(const ValueKey('plan-starter-stage-scroll'));
    final viewportRect = tester.getRect(viewport);
    final itemHeight = tester.getSize(find.byKey(firstCardKey)).height;
    final twoCardContentHeight =
        12 + itemHeight * 2 + planElementBuilderCardGap;
    final twoCardMaxScroll = math.max(
      0.0,
      twoCardContentHeight - viewportRect.height,
    );
    final expectedTwoCardLeft =
        viewportRect.left +
        planStageDiagonalCardLeft(
          viewportHeight: viewportRect.height,
          itemTop: 6,
          itemHeight: itemHeight,
          scrollOffset: twoCardMaxScroll,
          cardWidth: tester.getSize(find.byKey(firstCardKey)).width,
        );
    expect(
      tester.getTopLeft(find.byKey(firstCardKey)).dx,
      closeTo(expectedTwoCardLeft, 0.5),
    );

    await tester.tap(find.byKey(const ValueKey('plan-starter-remove-stage')));
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(firstCardKey)).dx,
      closeTo(initialLeft, 0.5),
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
            body: PlanningPage(
              service: service,
              initialSeed: _seed(),
              initialPresets: [_threeStageTestPreset()],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('plan-starter-preset-balanced-growth')),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('plan-starter-confirm')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('plan-starter-unassigned-scroll')),
        findsOne,
      );
      expect(
        find.byKey(const ValueKey('plan-starter-open-phase-editor')),
        findsOne,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(
                  const ValueKey('plan-starter-open-phase-editor'),
                ),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNotNull,
      );
    },
  );

  testWidgets(
    'builder deletes only the selected unassigned stage and return preserves the rest',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.binding.setSurfaceSize(const Size(2560, 1392));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: PlanningPage(
              service: service,
              initialSeed: _seed(),
              initialPresets: [_threeStageTestPreset()],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('plan-starter-preset-balanced-growth')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-starter-confirm')));
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('plan-unassigned-media-hoshino-stage-2')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('plan-starter-delete-unassigned')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('plan-unassigned-row-host-hoshino-stage-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plan-unassigned-row-host-hoshino-stage-3')),
        findsOne,
      );

      await tester.tap(
        find.byKey(const ValueKey('plan-starter-return-to-plan')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PlanElementBuilder), findsNothing);
      expect(find.byKey(const ValueKey('plan-phase-editor-launch')), findsOne);

      await tester.tap(find.byKey(const ValueKey('plan-phase-editor-launch')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('plan-phase-editor-source-hoshino-stage-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plan-phase-editor-source-hoshino-stage-3')),
        findsOne,
      );
    },
  );

  testWidgets('phase completion exits the builder and returns to plan main', (
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
          body: PlanningPage(
            service: service,
            initialSeed: _seed(),
            initialPresets: [_threeStageTestPreset()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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
    await tester.tap(find.byKey(const ValueKey('plan-phase-editor-complete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('plan-phase-editor')), findsNothing);
    expect(find.byType(PlanElementBuilder), findsNothing);
    expect(find.byKey(const ValueKey('plan-phase-scroll')), findsOne);
  });

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
