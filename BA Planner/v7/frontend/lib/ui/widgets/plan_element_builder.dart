import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../models/planning_growth_rules.dart';
import '../models/planning_models.dart';
import '../studio/plan_starter_studio_layout.dart';
import '../studio/preset_element_studio_layout.dart';
import '../studio/section_template.dart';
import 'animated_section_stack.dart';
import 'asset_image_grid.dart';
import 'ba_triangle_background.dart';
import 'bond_rank_portrait.dart';
import 'diagonal_flow_indicator.dart';
import 'lifted_path_shadow.dart';
import 'plan_phase_editor.dart' show phaseEditorPathSurfaceTexture;
import 'scroll_viewport_fog.dart';
import 'section_template_surface.dart';
import 'student_section_layout.dart';

export '../models/planning_growth_rules.dart'
    show planElementTargetMaximums, planElementTargetMinimums;

const planElementBuilderSectionOpacity = 0.76;
const planElementBuilderGap = 12.0;
const planElementBuilderCardGap = 14.0;
const planStarterStageControlHeight = 62.0;
const planStarterStageControlBottomInset = 10.0;
const planStarterStageMessageHeight = 30.0;
const planStarterStageMessageGap = 6.0;
const planStarterRightSectionInset = 12.0;
const planStarterRightControlMinimumHeight = 44.0;
const planStarterRightControlMaximumHeight = 72.0;
const planStarterRightControlHeightRatio = 0.065;
const planPresetElementWidthScale = 0.95;
const planPresetElementPanelGap = 12.0;
const planPresetElementEdgeGap = 24.0;
const planPresetElementColumnGap = 24.0;
const _planPresetElementSourceGap = 24.0;
const planPresetConditionHeaderReserve = 40.0;
const planPresetConditionCompactRowReduction = 20.0;
const _planPresetElementRowWeights = <double>[4, 1, 4, 7, 3, 3];
const _planPresetElementHeightScales = <double>[0.5, 1, 0.6, 0.63, 0.8, 1];

enum PlanPresetElementLayout { standard, condition }

const planElementBuilderSectionMotions = <String, SectionMotionSpec>{
  'element-3': SectionMotionSpec(intro: 0, outro: 180),
  'element-5': SectionMotionSpec(intro: 0, outro: 180),
  'element-6': SectionMotionSpec(intro: 80, outro: 260),
  'element-7': SectionMotionSpec(intro: 180, outro: 0),
};

const planStarterPortraitLeftFraction = 0.13277;

/// Presets are user-created in the in-memory preset manager.
///
/// v7 intentionally ships without built-in presets. Persistence is deferred
/// until the v6 user-data migration supplies the repository/protocol boundary.
final defaultPlanElementPresets = <PlanElementPreset>[];

Map<String, int> planElementCurrentTargets(PlanningStudentSeed seed) {
  int value(String key, int fallback) {
    final raw = seed.currentValues[key];
    return raw is int ? raw : fallback;
  }

  int equipmentTier(String key) {
    final raw = seed.currentValues[key];
    if (raw is int) return raw;
    final match = RegExp(r'(\d+)').firstMatch(raw?.toString() ?? '');
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  int initialStar() {
    final raw = seed.metadata['rarity'];
    final match = RegExp(r'(\d+)').firstMatch(raw?.toString() ?? '');
    return match == null ? 1 : int.parse(match.group(1)!).clamp(1, 5);
  }

  if (!seed.owned) {
    return normalizePlanningGrowthTargets({
      'level': 1,
      'bond_rank': 1,
      'student_star': initialStar(),
      'weapon_level': 0,
      'weapon_star': 0,
      'ex_skill': 1,
      'skill1': 1,
      'skill2': 1,
      'skill3': 1,
      'equip1_tier': 0,
      'equip2_tier': 0,
      'equip3_tier': 0,
      'equip1_level': 0,
      'equip2_level': 0,
      'equip3_level': 0,
      'equip4_tier': 0,
      'stat_hp': 0,
      'stat_atk': 0,
      'stat_heal': 0,
    }, hasFavoriteItem: planStudentHasFavoriteItemMetadata(seed.metadata));
  }
  return normalizePlanningGrowthTargets({
    'level': value('level', 1),
    'bond_rank': value('bond_rank', 1),
    'student_star': value('student_star', 1),
    'weapon_level': value('weapon_level', 0),
    'weapon_star': value('weapon_star', 0),
    'ex_skill': value('ex_skill', 1),
    'skill1': value('skill1', 1),
    'skill2': value('skill2', 1),
    'skill3': value('skill3', 1),
    'equip1_tier': equipmentTier('equip1'),
    'equip2_tier': equipmentTier('equip2'),
    'equip3_tier': equipmentTier('equip3'),
    'equip1_level': value('equip1_level', 0),
    'equip2_level': value('equip2_level', 0),
    'equip3_level': value('equip3_level', 0),
    'equip4_tier': equipmentTier('equip4'),
    'stat_hp': value('stat_hp', 0),
    'stat_atk': value('stat_atk', 0),
    'stat_heal': value('stat_heal', 0),
  }, hasFavoriteItem: planStudentHasFavoriteItemMetadata(seed.metadata));
}

String planElementTargetSummary(Map<String, int> target) {
  final skillText =
      '${target['ex_skill']}/${target['skill1']}/${target['skill2']}/${target['skill3']}';
  final equipmentText =
      'T${target['equip1_tier']}/T${target['equip2_tier']}/T${target['equip3_tier']}';
  return 'Lv.${target['level']} · ★${target['student_star']} · '
      '전무 ${target['weapon_star']} · 스킬 $skillText · $equipmentText';
}

Path planStarterSectionPath(Size size, String id) {
  final section = planStarterStudioDocument.elements.firstWhere(
    (element) => element.id == id,
  );
  return buildSectionCanvasElementPath(size, section);
}

Rect planStarterSectionRect(Size size, String id) {
  final section = planStarterStudioDocument.elements.firstWhere(
    (element) => element.id == id,
  );
  return sectionCanvasElementRect(size, section);
}

Rect planStageEditorContentRect(Size canvasSize) {
  const top = 6.0;
  final viewport = planStageEditorViewportRect(canvasSize);
  final cardWidth = planPresetListCardWidth(viewport.size);
  final cardHeight = planPresetListCardHeight(cardWidth);
  final left = planStageDiagonalCardLeft(
    viewportHeight: viewport.height,
    itemTop: top,
    itemHeight: cardHeight,
    scrollOffset: 0,
    cardWidth: cardWidth,
  );
  return Rect.fromLTRB(
    viewport.left + left,
    viewport.top + top,
    viewport.left + left + cardWidth,
    viewport.top + top + cardHeight,
  );
}

Rect planStageEditorViewportRect(Size canvasSize) {
  return planPresetListContainerPath(canvasSize).getBounds();
}

Path planPresetListContainerPath(Size canvasSize) {
  final sectionPath = planStarterSectionPath(canvasSize, 'element-6');
  final raw = buildRoundedSectionPolygon(
    planPresetListContainerVertices(canvasSize),
    radius: 10,
  );
  return Path.combine(PathOperation.intersect, raw, sectionPath);
}

Path planPresetLoaderContainerPath(Size canvasSize) {
  final sectionPath = planStarterSectionPath(canvasSize, 'element-5');
  final raw = buildRoundedSectionPolygon(
    planPresetLoaderContainerVertices(canvasSize),
    radius: 10,
  );
  return Path.combine(PathOperation.intersect, raw, sectionPath);
}

List<Offset> planPresetLoaderContainerVertices(Size canvasSize) {
  const normalGap = planElementBuilderGap;
  const headerHeight = 48.0;
  final sectionBounds = planStarterSectionPath(
    canvasSize,
    'element-5',
  ).getBounds();
  final tangent = math.tan(80 * math.pi / 180);
  final railInset = normalGap / math.sin(80 * math.pi / 180);
  final top = sectionBounds.top + headerHeight;
  final bottom = sectionBounds.bottom - normalGap;
  final leftRail = sectionBounds.left + railInset + bottom / tangent;
  final rightRail =
      sectionBounds.right + sectionBounds.top / tangent - railInset;
  return [
    Offset(leftRail - top / tangent, top),
    Offset(rightRail - top / tangent, top),
    Offset(rightRail - bottom / tangent, bottom),
    Offset(leftRail - bottom / tangent, bottom),
  ];
}

List<Offset> planPresetListContainerVertices(Size canvasSize) {
  const normalGap = planElementBuilderGap;
  final sectionBounds = planStarterSectionPath(
    canvasSize,
    'element-6',
  ).getBounds();
  final tangent = math.tan(80 * math.pi / 180);
  final railDelta = normalGap / math.sin(80 * math.pi / 180);
  final top = sectionBounds.top + normalGap;
  final bottom =
      sectionBounds.bottom -
      planStarterStageControlHeight -
      planStarterStageControlBottomInset -
      normalGap -
      planStarterStageMessageHeight -
      planStarterStageMessageGap;
  final leftRail = sectionBounds.left + sectionBounds.bottom / tangent;
  final rightRail = sectionBounds.right + sectionBounds.top / tangent;
  return [
    Offset(leftRail + railDelta - top / tangent, top),
    Offset(rightRail - railDelta - top / tangent, top),
    Offset(rightRail - railDelta - bottom / tangent, bottom),
    Offset(leftRail + railDelta - bottom / tangent, bottom),
  ];
}

double planPresetListCardWidth(Size viewportSize) {
  const normalGap = planElementBuilderGap;
  const scrollbarReserve = 14.0;
  final tangent = math.tan(80 * math.pi / 180);
  final railInset = normalGap / math.sin(80 * math.pi / 180);
  final unwrappedAspect =
      presetElementUnwrappedReferenceBounds.height /
      presetElementUnwrappedReferenceBounds.width;
  final weightTotal = _planPresetElementRowWeights.fold<double>(
    0,
    (total, weight) => total + weight,
  );
  final scaledWeightTotal =
      Iterable<int>.generate(_planPresetElementRowWeights.length).fold<double>(
        0,
        (total, index) =>
            total +
            _planPresetElementRowWeights[index] *
                _planPresetElementHeightScales[index],
      );
  final wrappedRatio = scaledWeightTotal / weightTotal;
  final wrappedFixedHeight =
      planPresetElementEdgeGap * 2 +
      planPresetElementPanelGap * 5 -
      _planPresetElementSourceGap * 7 * wrappedRatio;
  final wrappedAspect = unwrappedAspect * wrappedRatio;
  final railWidth =
      viewportSize.width -
      viewportSize.height / tangent -
      railInset * 2 -
      scrollbarReserve;
  final baseWidth = math
      .max(
        116,
        (railWidth + wrappedFixedHeight / tangent) /
            (1 - wrappedAspect / tangent),
      )
      .clamp(116.0, math.max(116, viewportSize.width - railInset * 2))
      .toDouble();
  return baseWidth * planPresetElementWidthScale;
}

double _planPresetElementUnwrappedHeight(double cardWidth) =>
    cardWidth /
    planPresetElementWidthScale *
    presetElementUnwrappedReferenceBounds.height /
    presetElementUnwrappedReferenceBounds.width;

List<double> _planPresetElementStandardRowHeights(double cardWidth) {
  final unwrappedHeight = _planPresetElementUnwrappedHeight(cardWidth);
  final usableHeight = math.max(
    0.0,
    unwrappedHeight - _planPresetElementSourceGap * 7,
  );
  final unit =
      usableHeight /
      _planPresetElementRowWeights.fold<double>(0, (a, b) => a + b);
  return [
    for (var index = 0; index < _planPresetElementRowWeights.length; index++)
      _planPresetElementRowWeights[index] *
          unit *
          _planPresetElementHeightScales[index],
  ];
}

List<double> _planPresetElementRowHeights(
  double cardWidth,
  PlanPresetElementLayout layout,
) {
  final heights = _planPresetElementStandardRowHeights(cardWidth);
  if (layout == PlanPresetElementLayout.condition) {
    for (final index in const [2, 4]) {
      heights[index] = math.max(
        0,
        heights[index] - planPresetConditionCompactRowReduction,
      );
    }
  }
  return heights;
}

double _planPresetElementHeaderReserve(
  double cardWidth,
  PlanPresetElementLayout layout,
) {
  if (layout == PlanPresetElementLayout.standard) return 0;
  final standard = _planPresetElementStandardRowHeights(cardWidth);
  final compact = _planPresetElementRowHeights(cardWidth, layout);
  return (standard[2] - compact[2]) + (standard[4] - compact[4]);
}

double planPresetListCardHeight(
  double cardWidth, {
  PlanPresetElementLayout layout = PlanPresetElementLayout.standard,
}) =>
    planPresetElementEdgeGap * 2 +
    planPresetElementPanelGap * 5 +
    _planPresetElementHeaderReserve(cardWidth, layout) +
    _planPresetElementRowHeights(
      cardWidth,
      layout,
    ).fold<double>(0, (total, height) => total + height);

double planStageDiagonalCardLeft({
  required double viewportHeight,
  required double itemTop,
  required double itemHeight,
  required double scrollOffset,
  required double cardWidth,
  double normalGap = planElementBuilderGap,
}) =>
    normalGap / math.sin(80 * math.pi / 180) +
    (cardWidth / planPresetElementWidthScale - cardWidth) / 2 +
    (viewportHeight - (itemTop + itemHeight - scrollOffset)) /
        math.tan(80 * math.pi / 180);

double planStageEffectiveScrollOffset({
  required double rawOffset,
  required double contentHeight,
  required double viewportHeight,
}) => rawOffset
    .clamp(0.0, math.max(0.0, contentHeight - viewportHeight))
    .toDouble();

StudioContainerElement planStarterContainer(String id) =>
    planStarterStudioDocument.containers.firstWhere(
      (container) => container.id == id,
    );

bool planStarterStatusFoundationPaintsContainer(
  StudioContainerElement container,
) => container.parentSectionId == 'element-3' && container.id != 'container-3';

Path planStarterContainerPath(Size size, String id) => buildStudioContainerPath(
  size,
  planStarterStudioDocument.elements,
  planStarterContainer(id),
)!;

@immutable
class PlanStarterRightSectionGeometry {
  const PlanStarterRightSectionGeometry({
    required this.listPath,
    required this.editButtonPath,
    required this.deleteButtonPath,
    required this.returnButtonPath,
    required this.buttonPath,
  });

  final Path listPath;
  final Path editButtonPath;
  final Path deleteButtonPath;
  final Path returnButtonPath;
  final Path buttonPath;
}

PlanStarterRightSectionGeometry planStarterRightSectionGeometry(
  Size size, {
  SectionGridRect? sectionRectOverride,
}) {
  var section = planStarterStudioDocument.elements.firstWhere(
    (element) => element.id == 'element-7',
  );
  if (sectionRectOverride != null) {
    section = section.copyWith(rect: sectionRectOverride);
  }
  final sectionPath = buildSectionCanvasElementPath(size, section);
  final sectionBounds = sectionPath.getBounds();
  final sectionRect = sectionCanvasElementRect(size, section);
  final sectionPoints = buildAttachedSectionPolygon(
    sectionRect.size,
    section.spec,
    gridSize: sectionTemplateDetailGridSize,
  );
  final horizontalEdges = <double>[];
  for (var index = 0; index < sectionPoints.length; index++) {
    final start = sectionPoints[index];
    final end = sectionPoints[(index + 1) % sectionPoints.length];
    if ((start.dy - end.dy).abs() <= 0.01) {
      horizontalEdges.add((start.dx - end.dx).abs());
    }
  }
  final shortEdge = horizontalEdges.isEmpty
      ? sectionBounds.width
      : horizontalEdges.reduce(math.min);
  final tangent = math.tan(80 * math.pi / 180);
  final horizontalGap =
      planStarterRightSectionInset / math.sin(80 * math.pi / 180);
  final listTop = sectionBounds.top + planStarterRightSectionInset;
  final listBottom = sectionBounds.bottom - planStarterRightSectionInset;
  final listHeight = math.max(1.0, listBottom - listTop);
  final targetBottomEdge = math.max(1.0, shortEdge - horizontalGap * 2);
  final listWidth = math.min(
    sectionBounds.width,
    targetBottomEdge + listHeight / tangent,
  );
  final listRect = Rect.fromLTWH(
    sectionBounds.center.dx - listWidth / 2,
    listTop,
    listWidth,
    listHeight,
  );
  final listPath = Path.combine(
    PathOperation.intersect,
    _bilateralPath(listRect.size).shift(listRect.topLeft),
    sectionPath,
  );

  double listRightAt(double y) =>
      listRect.right - (y - listRect.top).clamp(0.0, listRect.height) / tangent;
  final controlHeight =
      (sectionBounds.height * planStarterRightControlHeightRatio)
          .clamp(
            planStarterRightControlMinimumHeight,
            planStarterRightControlMaximumHeight,
          )
          .toDouble();
  final buttonRight = sectionBounds.right - planStarterRightSectionInset;
  Path actionPath(int slotFromBottom) {
    final buttonBottom =
        sectionBounds.bottom -
        planStarterRightSectionInset -
        slotFromBottom * (controlHeight + planElementBuilderGap);
    final buttonTop = buttonBottom - controlHeight;
    final buttonLeftTop = math.min(
      buttonRight - planStarterRightControlMinimumHeight,
      listRightAt(buttonTop) + horizontalGap,
    );
    final buttonLeftBottom = math.min(
      buttonRight - planStarterRightControlMinimumHeight,
      listRightAt(buttonBottom) + horizontalGap,
    );
    return Path.combine(
      PathOperation.intersect,
      buildRoundedSectionPolygon([
        Offset(buttonLeftTop, buttonTop),
        Offset(buttonRight, buttonTop),
        Offset(buttonRight, buttonBottom),
        Offset(buttonLeftBottom, buttonBottom),
      ], radius: 8),
      sectionPath,
    );
  }

  return PlanStarterRightSectionGeometry(
    listPath: listPath,
    editButtonPath: actionPath(3),
    deleteButtonPath: actionPath(2),
    returnButtonPath: actionPath(1),
    buttonPath: actionPath(0),
  );
}

Rect planStarterPortraitRect(Size size) {
  final section = planStarterStudioDocument.elements.firstWhere(
    (element) => element.id == 'element-3',
  );
  final sectionRect = sectionCanvasElementRect(size, section);
  final metadataBounds = planStarterContainerPath(
    size,
    'container-2',
  ).getBounds();
  final height = metadataBounds.height;
  return Rect.fromLTWH(
    sectionRect.left + sectionRect.width * planStarterPortraitLeftFraction,
    metadataBounds.top,
    height * studentGridCardSourceSize.width / studentGridCardSourceSize.height,
    height,
  );
}

bool planStudentHasFavoriteItemMetadata(Map<String, dynamic> metadata) {
  final raw = metadata.containsKey('has_favorite_item_kr')
      ? metadata['has_favorite_item_kr']
      : metadata['has_favorite_item'];
  if (raw is bool) return raw;
  return const {'yes', 'true', '1'}.contains(raw?.toString().toLowerCase());
}

StudentCatalogEntry planStudentCatalogEntry(PlanningStudentSeed seed) {
  String text(String key, String fallback) {
    final value = seed.metadata[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  String? nullableText(String key) {
    final value = seed.metadata[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  return StudentCatalogEntry(
    studentId: seed.studentId,
    displayName: text('display_name', seed.studentId),
    templateName: text('template_name', '${seed.studentId}.png'),
    group: text('group', seed.studentId),
    variant: nullableText('variant'),
    school: nullableText('school'),
    rarity: nullableText('rarity'),
    attackType: nullableText('attack_type'),
    defenseType: nullableText('defense_type'),
    combatClass: nullableText('combat_class'),
    role: nullableText('role'),
    position: nullableText('position'),
    equipmentSlot1: nullableText('equipment_slot_1'),
    equipmentSlot2: nullableText('equipment_slot_2'),
    equipmentSlot3: nullableText('equipment_slot_3'),
    jpOnly: seed.metadata['jp_only'] == true,
    searchTags: const [],
    krSearchTags: const [],
  );
}

StudioFeatureElement planStarterFeature(String id) => planStarterStudioDocument
    .features
    .firstWhere((feature) => feature.id == id);

Path planStarterFeaturePath(Size size, String id) => buildStudioFeaturePath(
  size,
  planStarterStudioDocument.elements,
  planStarterStudioDocument.containers,
  planStarterFeature(id),
)!;

SectionCanvasElement planPresetElement(String id) => presetElementStudioDocument
    .elements
    .firstWhere((element) => element.id == id);

Rect planPresetElementRect(
  Size size,
  String id, {
  PlanPresetElementLayout layout = PlanPresetElementLayout.standard,
}) {
  if (id == 'element-5') return Offset.zero & size;
  final tangent = math.tan(80 * math.pi / 180);
  final sine = math.sin(80 * math.pi / 180);
  const rowGap = planPresetElementPanelGap;
  const edgeGap = planPresetElementEdgeGap;
  final railInset = edgeGap / sine;
  final heights = _planPresetElementRowHeights(size.width, layout);
  final tops = <double>[];
  var top = edgeGap + _planPresetElementHeaderReserve(size.width, layout);
  for (final height in heights) {
    tops.add(top);
    top += height + rowGap;
  }

  Rect fullWidthRow(int row) {
    final rowTop = tops[row];
    final rowHeight = heights[row];
    final left =
        size.height / tangent + railInset - (rowTop + rowHeight) / tangent;
    final width =
        size.width -
        size.height / tangent -
        railInset * 2 +
        rowHeight / tangent;
    return Rect.fromLTWH(left, rowTop, width, rowHeight);
  }

  if (id == 'element-1' || id == 'element-2' || id == 'element-3') {
    final rowTop = tops[0];
    final rowHeight = heights[0];
    final interColumnRailGap = planPresetElementColumnGap / sine;
    final availableRailWidth =
        size.width - size.height / tangent - railInset * 2;
    final columnRailWidth = (availableRailWidth - interColumnRailGap * 2) / 3;
    final index = switch (id) {
      'element-1' => 0,
      'element-2' => 1,
      _ => 2,
    };
    final leftRail =
        size.height / tangent +
        railInset +
        index * (columnRailWidth + interColumnRailGap);
    return Rect.fromLTWH(
      leftRail - (rowTop + rowHeight) / tangent,
      rowTop,
      columnRailWidth + rowHeight / tangent,
      rowHeight,
    );
  }

  return switch (id) {
    'element-4' => fullWidthRow(1),
    'element-6' => fullWidthRow(2),
    'element-7' => fullWidthRow(3),
    'element-8' => fullWidthRow(4),
    'element-9' => fullWidthRow(5),
    _ => throw StateError('Unknown preset element: $id'),
  };
}

Path planPresetElementLocalPath(Size size, String id) {
  final element = planPresetElement(id);
  assert(element.spec.mode == SectionShapeMode.parallelogram);
  assert(element.spec.face == SectionAttachmentFace.bottom);
  final requestedDepth =
      size.height * element.spec.height / sectionTemplateGridSize;
  final cut = sectionTemplateCutDepth(requestedDepth);
  final sourceSize = Size(math.max(1, size.width - cut), size.height);
  return buildRoundedSectionPolygon(
    buildAttachedSectionPolygon(sourceSize, element.spec),
    radius: math.min(9, size.shortestSide * 0.22),
  );
}

Path planPresetElementPath(Size size, String id) {
  final rect = planPresetElementRect(size, id);
  return planPresetElementLocalPath(rect.size, id).shift(rect.topLeft);
}

Path planPresetElementUnionPath(Size size) {
  var union = Path();
  for (final element in presetElementStudioDocument.elements) {
    union = Path.combine(
      PathOperation.union,
      union,
      planPresetElementPath(size, element.id),
    );
  }
  return union;
}

Path planPresetElementEnvelopePath(Size size, {double padding = 0}) {
  return buildRoundedSectionPolygon(
    planPresetElementEnvelopeVertices(size, padding: padding),
    radius: math.min(12, size.shortestSide * 0.025),
  );
}

List<Offset> planPresetElementEnvelopeVertices(
  Size size, {
  double padding = 0,
}) {
  final tangent = math.tan(80 * math.pi / 180);
  final sine = math.sin(80 * math.pi / 180);
  final railInset = padding / sine;
  final top = padding;
  final bottom = size.height - padding;
  final leftRail = size.height / tangent + railInset;
  final rightRail = size.width - railInset;
  return [
    Offset(leftRail - top / tangent, top),
    Offset(rightRail - top / tangent, top),
    Offset(rightRail - bottom / tangent, bottom),
    Offset(leftRail - bottom / tangent, bottom),
  ];
}

class PlanElementBuilder extends StatefulWidget {
  const PlanElementBuilder({
    super.key,
    required this.seed,
    required this.unassignedItems,
    required this.hasPlanElements,
    required this.onConfirm,
    required this.onRenameUnassigned,
    required this.onDeleteUnassigned,
    this.onEditStudent,
    required this.onExitToPlan,
    required this.onOpenPhaseEditor,
    this.initialStages = const [],
    this.presets,
    this.active = true,
  });

  final PlanningStudentSeed seed;
  final List<PlanElementStageDraft> initialStages;
  final List<PlanElementUnassignedItem> unassignedItems;
  final bool hasPlanElements;
  final List<PlanElementPreset>? presets;
  final bool active;
  final ValueChanged<List<PlanElementStageDraft>> onConfirm;
  final void Function(String id, String name) onRenameUnassigned;
  final ValueChanged<String> onDeleteUnassigned;
  final ValueChanged<String>? onEditStudent;
  final VoidCallback onExitToPlan;
  final VoidCallback onOpenPhaseEditor;

  @override
  State<PlanElementBuilder> createState() => _PlanElementBuilderState();
}

@immutable
class PlanElementUnassignedItem {
  const PlanElementUnassignedItem({
    required this.id,
    required this.studentId,
    required this.displayName,
    required this.stageNumber,
    required this.stageName,
    required this.targetSummary,
  });

  final String id;
  final String studentId;
  final String displayName;
  final int stageNumber;
  final String stageName;
  final String targetSummary;
}

class _PlanElementBuilderState extends State<PlanElementBuilder>
    with SingleTickerProviderStateMixin {
  static const _sectionMotionDuration = Duration(milliseconds: 360);
  late List<PlanElementStageDraft> _stages;
  String? _selectedStageId;
  String? _selectedPresetId;
  String? _selectedUnassignedId;
  bool _transitionPending = false;
  int _nextStageId = 1;
  final Set<String> _propagatedFields = {};
  Timer? _propagationTimer;
  late final AnimationController _sectionMotionController = AnimationController(
    vsync: this,
    duration: _sectionMotionDuration,
    reverseDuration: _sectionMotionDuration,
  );

  Map<String, int> get _current => planElementCurrentTargets(widget.seed);
  bool get _hasFavoriteItem =>
      planStudentHasFavoriteItemMetadata(widget.seed.metadata);
  List<PlanElementPreset> get _presets =>
      widget.presets ?? defaultPlanElementPresets;

  @override
  void initState() {
    super.initState();
    _resetFromInitial();
    if (widget.active) _sectionMotionController.forward(from: 0);
  }

  @override
  void didUpdateWidget(PlanElementBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seed.handoffId != widget.seed.handoffId) {
      _resetFromInitial();
      _selectedUnassignedId = null;
      _transitionPending = false;
      if (widget.active) _sectionMotionController.forward(from: 0);
    }
    if (oldWidget.active != widget.active) {
      if (widget.active) {
        _sectionMotionController.forward(from: 0);
      } else {
        _sectionMotionController.reverse(from: 1);
      }
    }
    if (_selectedUnassignedId != null &&
        !widget.unassignedItems.any(
          (item) => item.id == _selectedUnassignedId,
        )) {
      _selectedUnassignedId = null;
    }
  }

  @override
  void dispose() {
    _propagationTimer?.cancel();
    _sectionMotionController.dispose();
    super.dispose();
  }

  Future<void> _exitAfterSectionOutro(VoidCallback callback) async {
    if (_transitionPending) return;
    _transitionPending = true;
    await _sectionMotionController.reverse(
      from: _sectionMotionController.value,
    );
    if (!mounted) return;
    callback();
  }

  void _deleteSelectedUnassigned() {
    final selectedId = _selectedUnassignedId;
    if (selectedId == null) return;
    final selectedIndex = widget.unassignedItems.indexWhere(
      (item) => item.id == selectedId,
    );
    final remaining = [
      for (final item in widget.unassignedItems)
        if (item.id != selectedId) item,
    ];
    setState(() {
      _selectedUnassignedId = remaining.isEmpty
          ? null
          : remaining[selectedIndex.clamp(0, remaining.length - 1)].id;
    });
    widget.onDeleteUnassigned(selectedId);
  }

  void _editSelectedStudent() {
    final selectedId = _selectedUnassignedId;
    if (selectedId == null) return;
    final selected = widget.unassignedItems
        .cast<PlanElementUnassignedItem?>()
        .firstWhere((item) => item?.id == selectedId, orElse: () => null);
    if (selected == null) return;
    final callback = widget.onEditStudent;
    if (callback == null) return;
    _exitAfterSectionOutro(() => callback(selected.studentId));
  }

  void _resetFromInitial() {
    _nextStageId = 1;
    _stages = widget.initialStages.isEmpty
        ? [
            PlanElementStageDraft(
              id: _newStageId(),
              name: '1단계',
              targets: _current,
            ),
          ]
        : [
            for (final stage in widget.initialStages)
              stage.copyWith(
                targets: normalizePlanningGrowthTargets(
                  stage.targets,
                  hasFavoriteItem: _hasFavoriteItem,
                ),
              ),
          ];
    final usedStageIds = _stages.map((stage) => stage.id).toSet();
    while (usedStageIds.contains(
      '${widget.seed.studentId}-stage-$_nextStageId',
    )) {
      _nextStageId += 1;
    }
    _selectedStageId = _stages.firstOrNull?.id;
    _selectedPresetId = null;
  }

  String _newStageId() => '${widget.seed.studentId}-stage-${_nextStageId++}';

  int get _selectedIndex =>
      _stages.indexWhere((stage) => stage.id == _selectedStageId);

  void _addStage() {
    final selectedIndex = _selectedIndex;
    final source = selectedIndex >= 0
        ? _stages[selectedIndex]
        : _stages.isEmpty
        ? null
        : _stages.last;
    final insertIndex = selectedIndex >= 0 ? selectedIndex + 1 : _stages.length;
    final stage = PlanElementStageDraft(
      id: _newStageId(),
      name: '${insertIndex + 1}단계',
      targets: source?.targets ?? _current,
    );
    setState(() {
      _stages.insert(insertIndex, stage);
      _renumberDefaultNames();
      _selectedStageId = stage.id;
    });
  }

  void _removeSelectedStage() {
    final index = _selectedIndex;
    if (index < 0 || _stages.length <= 1) return;
    setState(() {
      _stages.removeAt(index);
      _renumberDefaultNames();
      _selectedStageId = _stages[math.max(0, index - 1)].id;
    });
  }

  void _renumberDefaultNames() {
    for (var index = 0; index < _stages.length; index++) {
      final name = _stages[index].name;
      if (RegExp(r'^\d+단계$').hasMatch(name)) {
        _stages[index] = _stages[index].copyWith(name: '${index + 1}단계');
      }
    }
  }

  void _resetDraft() {
    setState(() {
      _stages = [
        PlanElementStageDraft(
          id: _newStageId(),
          name: '1단계',
          targets: _current,
        ),
      ];
      _selectedStageId = _stages.first.id;
      _selectedPresetId = null;
    });
  }

  void _loadPreset(PlanElementPreset preset) {
    var previous = Map<String, int>.from(_current);
    final next = <PlanElementStageDraft>[];
    for (final sparse in preset.stages) {
      final expanded = {...previous};
      for (final entry in sparse.entries) {
        expanded[entry.key] = math.max(
          previous[entry.key] ?? planElementTargetMinimums[entry.key] ?? 0,
          entry.value,
        );
      }
      final effectiveRaw = {
        for (final entry in expanded.entries)
          entry.key: math.max(entry.value, _current[entry.key] ?? entry.value),
      };
      final effective = normalizePlanningGrowthTargets(
        effectiveRaw,
        changedKeys: sparse.keys.toSet(),
        hasFavoriteItem: _hasFavoriteItem,
      );
      if (_hasIncreaseOver(effective, previous)) {
        next.add(
          PlanElementStageDraft(
            id: _newStageId(),
            name: '${next.length + 1}단계',
            targets: effective,
          ),
        );
        previous = effective;
      }
    }
    setState(() {
      _selectedPresetId = preset.id;
      _stages = next.isEmpty
          ? [
              PlanElementStageDraft(
                id: _newStageId(),
                name: '1단계',
                targets: _current,
              ),
            ]
          : next;
      _selectedStageId = _stages.first.id;
    });
  }

  bool _hasIncreaseOver(Map<String, int> target, Map<String, int> baseline) =>
      target.entries.any(
        (entry) => entry.value > (baseline[entry.key] ?? entry.value),
      );

  void _setTarget(int stageIndex, String key, int requested) {
    final contractMinimum = planElementTargetMinimums[key] ?? 0;
    final previous = stageIndex == 0
        ? _current[key] ?? contractMinimum
        : _stages[stageIndex - 1].targets[key] ?? contractMinimum;
    final minimum = math.max(contractMinimum, previous);
    final maximum = planElementTargetMaximums[key] ?? requested;
    final value = requested.clamp(minimum, maximum);
    final propagated = <String>{};
    setState(() {
      final selectedTargets = Map<String, int>.from(
        _stages[stageIndex].targets,
      );
      selectedTargets[key] = value;
      final normalized = normalizePlanningGrowthTargets(
        selectedTargets,
        changedKeys: {key},
        hasFavoriteItem: _hasFavoriteItem,
      );
      final affectedKeys = {
        for (final entry in normalized.entries)
          if (entry.value != _stages[stageIndex].targets[entry.key]) entry.key,
      };
      _stages[stageIndex] = _stages[stageIndex].copyWith(targets: normalized);
      for (var index = stageIndex + 1; index < _stages.length; index++) {
        final targets = Map<String, int>.from(_stages[index].targets);
        var changed = false;
        for (final affectedKey in affectedKeys) {
          final required = normalized[affectedKey]!;
          if ((targets[affectedKey] ?? required) >= required) continue;
          targets[affectedKey] = required;
          propagated.add('${_stages[index].id}:$affectedKey');
          changed = true;
        }
        if (!changed) continue;
        _stages[index] = _stages[index].copyWith(
          targets: normalizePlanningGrowthTargets(
            targets,
            changedKeys: affectedKeys,
            hasFavoriteItem: _hasFavoriteItem,
          ),
        );
      }
      _propagatedFields
        ..clear()
        ..addAll(propagated);
    });
    _propagationTimer?.cancel();
    _propagationTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(_propagatedFields.clear);
    });
  }

  void _confirm() {
    final effective = <PlanElementStageDraft>[];
    var baseline = _current;
    for (final stage in _stages) {
      if (_hasIncreaseOver(stage.targets, baseline)) {
        effective.add(stage);
        baseline = stage.targets;
      }
    }
    if (effective.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('현재 상태보다 높은 목표를 하나 이상 설정하세요.')),
      );
      return;
    }
    widget.onConfirm(List.unmodifiable(effective));
  }

  bool get _canConfirmPlanElement {
    final baseline = _current;
    for (final stage in _stages) {
      if (_hasIncreaseOver(stage.targets, baseline)) return true;
    }
    return false;
  }

  String? get _planElementBlockedReason =>
      _canConfirmPlanElement ? null : '현재 상태보다 높은 목표를 하나 이상 설정하세요.';

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final id in const [
              'element-3',
              'element-5',
              'element-7',
              'element-6',
            ])
              Positioned.fill(
                child: _PlanElementSectionMotion(
                  key: ValueKey('plan-starter-$id-motion'),
                  animation: _sectionMotionController,
                  motion: planElementBuilderSectionMotions[id]!,
                  child: _PlanStarterSection(
                    key: ValueKey('plan-starter-$id'),
                    path: planStarterSectionPath(size, id),
                    child: switch (id) {
                      'element-3' => _buildStudentStatus(size),
                      'element-5' => _buildPresetPanel(size),
                      'element-6' => _buildStageEditor(size),
                      'element-7' => _buildUnassignedSection(size),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _buildStudentStatus(Size canvasSize) {
    final current = _current;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('plan-starter-student-status-foundation'),
            painter: _PlanStudentStatusFoundationPainter(
              canvasSize: canvasSize,
              studentStars: current['student_star'] ?? 0,
              weaponStars: current['weapon_star'] ?? 0,
            ),
          ),
        ),
        Positioned.fromRect(
          key: const ValueKey('plan-starter-student-portrait-host'),
          rect: planStarterPortraitRect(canvasSize),
          child: _PlanStudentPortrait(
            student: planStudentCatalogEntry(widget.seed),
            owned: widget.seed.owned,
            planned: widget.hasPlanElements,
            bondRank: current['bond_rank'],
            portraitAsset:
                'assets/student_portraits/${widget.seed.studentId}.png',
          ),
        ),
        _statusFeature(
          canvasSize,
          'feature-2',
          StudentLevelStatus(
            level: current['level'],
            schoolLogoAsset: null,
            showSchool: false,
          ),
        ),
        _statusFeature(
          canvasSize,
          'feature-5',
          _PlanWeaponLevelStatus(
            level: current['weapon_level'],
            unlocked: (current['weapon_star'] ?? 0) > 0,
          ),
        ),
        _statusContainer(
          canvasSize,
          'container-5',
          StudentSkillStatus(
            values: [
              _skillDisplay(current['ex_skill'], 5),
              _skillDisplay(current['skill1'], 10),
              _skillDisplay(current['skill2'], 10),
              _skillDisplay(current['skill3'], 10),
            ],
          ),
        ),
        _statusContainer(
          canvasSize,
          'container-6',
          StudentEquipmentStatus(
            student: null,
            equipmentTypes: [
              widget.seed.metadata['equipment_slot_1']?.toString(),
              widget.seed.metadata['equipment_slot_2']?.toString(),
              widget.seed.metadata['equipment_slot_3']?.toString(),
            ],
            tiers: [
              _equipmentTierDisplay(current['equip1_tier']),
              _equipmentTierDisplay(current['equip2_tier']),
              _equipmentTierDisplay(current['equip3_tier']),
            ],
            levels: [
              current['equip1_level'],
              current['equip2_level'],
              current['equip3_level'],
            ],
            favoriteItem:
                planStudentHasFavoriteItemMetadata(widget.seed.metadata)
                ? _equipmentTierDisplay(current['equip4_tier'])
                : '-',
            favoriteItemLocked:
                planStudentHasFavoriteItemMetadata(widget.seed.metadata) &&
                (current['equip4_tier'] ?? 0) == 0,
          ),
        ),
        _statusContainer(
          canvasSize,
          'container-7',
          StudentAbilityStatus(
            hp: current['stat_hp'],
            atk: current['stat_atk'],
            heal: current['stat_heal'],
          ),
        ),
        _statusContainer(
          canvasSize,
          'container-9',
          const StudentPotentialStatus(),
        ),
        _statusBondContainer(canvasSize, 'container-8', current['bond_rank']),
      ],
    );
  }

  Widget _statusContainer(
    Size canvasSize,
    String id,
    Widget child, {
    bool foreground = false,
  }) {
    final path = planStarterContainerPath(canvasSize, id);
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      key: ValueKey('plan-starter-status-$id'),
      rect: bounds,
      child: ClipPath(
        clipper: _FixedPathClipper(localPath),
        child: ColoredBox(
          color: foreground
              ? AppColors.surfaceRaised.withValues(alpha: 0.96)
              : Colors.transparent,
          child: CustomPaint(
            foregroundPainter: _LocalPathBorderPainter(localPath),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _statusFeature(Size canvasSize, String id, Widget child) {
    final path = planStarterFeaturePath(canvasSize, id);
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      key: ValueKey('plan-starter-status-$id'),
      rect: bounds,
      child: ClipPath(
        clipper: _FixedPathClipper(localPath),
        child: CustomPaint(
          foregroundPainter: _LocalPathBorderPainter(localPath),
          child: child,
        ),
      ),
    );
  }

  Widget _statusBondContainer(Size canvasSize, String id, int? rank) {
    final path = planStarterContainerPath(canvasSize, id);
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      key: ValueKey('plan-starter-status-$id'),
      rect: bounds,
      child: ClipPath(
        clipper: _FixedPathClipper(localPath),
        child: StudentBondStatus(
          bondRank: rank,
          outerPath: localPath,
          inverted: true,
          fillFromBottom: true,
        ),
      ),
    );
  }

  String _skillDisplay(int? value, int maximum) {
    if (value == null) return '-';
    return value >= maximum ? 'M' : '$value';
  }

  String _equipmentTierDisplay(int? value) =>
      value == null || value <= 0 ? '-' : 'T$value';

  Widget _buildPresetPanel(Size canvasSize) {
    final bounds = planStarterSectionRect(canvasSize, 'element-5');
    final containerPath = planPresetLoaderContainerPath(canvasSize);
    final viewportRect = containerPath.getBounds();
    final localContainerPath = containerPath.shift(-viewportRect.topLeft);
    return Stack(
      children: [
        Positioned(
          left: bounds.left + 16,
          top: bounds.top + 13,
          child: Text(
            '프리셋 불러오기',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('plan-starter-preset-container-foundation'),
            painter: _PlanPresetListContainerPainter(containerPath),
          ),
        ),
        Positioned.fromRect(
          key: const ValueKey('plan-starter-preset-list-host'),
          rect: viewportRect,
          child: ClipPath(
            clipper: _FixedPathClipper(localContainerPath),
            child: _presets.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        '저장된 프리셋이 없습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  )
                : _PlanPresetLoaderDiagonalList(
                    presets: _presets,
                    selectedPresetId: _selectedPresetId,
                    onSelected: _loadPreset,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStageEditor(Size canvasSize) {
    final bounds = planStarterSectionRect(canvasSize, 'element-6');
    final containerPath = planPresetListContainerPath(canvasSize);
    final contentRect = planStageEditorContentRect(canvasSize);
    final viewportRect = containerPath.getBounds();
    final localContainerPath = containerPath.shift(-viewportRect.topLeft);
    return Stack(
      children: [
        IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('plan-preset-list-container-foundation'),
            painter: _PlanPresetListContainerPainter(containerPath),
          ),
        ),
        Positioned.fromRect(
          rect: viewportRect,
          child: ClipPath(
            clipper: _FixedPathClipper(localContainerPath),
            child: PlanPresetDiagonalList(
              keyPrefix: 'plan-starter-stage',
              itemCount: _stages.length,
              cardWidth: contentRect.width,
              itemBuilder: (context, index) {
                final stage = _stages[index];
                return PlanPresetElementCard(
                  key: ValueKey('plan-starter-stage-${stage.id}'),
                  stage: stage,
                  startTargets: index == 0
                      ? _current
                      : _stages[index - 1].targets,
                  stageNumber: index + 1,
                  selected: stage.id == _selectedStageId,
                  propagatedFields: _propagatedFields,
                  equipmentTypes: [
                    widget.seed.metadata['equipment_slot_1']?.toString(),
                    widget.seed.metadata['equipment_slot_2']?.toString(),
                    widget.seed.metadata['equipment_slot_3']?.toString(),
                  ],
                  hasFavoriteItem: planStudentHasFavoriteItemMetadata(
                    widget.seed.metadata,
                  ),
                  onSelected: () => setState(() => _selectedStageId = stage.id),
                  onChanged: (key, value) => _setTarget(index, key, value),
                );
              },
            ),
          ),
        ),
        Positioned(
          key: const ValueKey('plan-starter-blocked-reason-host'),
          left: bounds.left + 20,
          right: canvasSize.width - bounds.right + 20,
          bottom:
              canvasSize.height -
              bounds.bottom +
              planStarterStageControlBottomInset +
              planStarterStageControlHeight +
              planStarterStageMessageGap,
          height: planStarterStageMessageHeight,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _planElementBlockedReason == null
                ? const SizedBox.shrink()
                : Row(
                    key: const ValueKey('plan-starter-blocked-reason'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _planElementBlockedReason!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        Positioned(
          left: bounds.left + 14,
          right: canvasSize.width - bounds.right + 14,
          bottom:
              canvasSize.height -
              bounds.bottom +
              planStarterStageControlBottomInset,
          height: planStarterStageControlHeight,
          child: PlanBuilderControls(
            canRemove: _stages.length > 1,
            onAdd: _addStage,
            onRemove: _removeSelectedStage,
            onReset: _resetDraft,
            onConfirm: _canConfirmPlanElement ? _confirm : null,
          ),
        ),
      ],
    );
  }

  Widget _buildUnassignedSection(Size canvasSize) {
    final geometry = planStarterRightSectionGeometry(canvasSize);
    final listBounds = geometry.listPath.getBounds();
    final localListPath = geometry.listPath.shift(-listBounds.topLeft);
    final buttonBounds = geometry.buttonPath.getBounds();
    final localButtonPath = geometry.buttonPath.shift(-buttonBounds.topLeft);
    final returnBounds = geometry.returnButtonPath.getBounds();
    final localReturnPath = geometry.returnButtonPath.shift(
      -returnBounds.topLeft,
    );
    final deleteBounds = geometry.deleteButtonPath.getBounds();
    final localDeletePath = geometry.deleteButtonPath.shift(
      -deleteBounds.topLeft,
    );
    final editBounds = geometry.editButtonPath.getBounds();
    final localEditPath = geometry.editButtonPath.shift(-editBounds.topLeft);
    return Stack(
      children: [
        Positioned.fromRect(
          rect: listBounds,
          child: IgnorePointer(
            child: CustomPaint(
              key: const ValueKey(
                'plan-starter-unassigned-container-foundation',
              ),
              painter: _PlanPresetListContainerPainter(localListPath),
            ),
          ),
        ),
        Positioned.fromRect(
          key: const ValueKey('plan-starter-unassigned-list-host'),
          rect: listBounds,
          child: ClipPath(
            clipper: _FixedPathClipper(localListPath),
            child: SizedBox.expand(
              key: const ValueKey('plan-starter-unassigned-viewport'),
              child: widget.unassignedItems.isEmpty
                  ? const Center(
                      child: Text(
                        '미배정 요소가 없습니다.',
                        key: ValueKey('plan-starter-unassigned-empty'),
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : _UnassignedDiagonalList(
                      items: widget.unassignedItems,
                      onRename: widget.onRenameUnassigned,
                      selectedId: _selectedUnassignedId,
                      onSelected: (id) =>
                          setState(() => _selectedUnassignedId = id),
                    ),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: editBounds,
          child: _PlanStarterSideActionButton(
            key: const ValueKey('plan-starter-edit-selected-student'),
            path: localEditPath,
            icon: Icons.edit_rounded,
            label: '선택한 학생 계획 수정',
            onPressed:
                _selectedUnassignedId == null || widget.onEditStudent == null
                ? null
                : _editSelectedStudent,
          ),
        ),
        Positioned.fromRect(
          rect: deleteBounds,
          child: _PlanStarterSideActionButton(
            key: const ValueKey('plan-starter-delete-unassigned'),
            path: localDeletePath,
            icon: Icons.delete_outline_rounded,
            label: '단계 삭제',
            onPressed: _selectedUnassignedId == null
                ? null
                : _deleteSelectedUnassigned,
          ),
        ),
        Positioned.fromRect(
          rect: returnBounds,
          child: _PlanStarterSideActionButton(
            key: const ValueKey('plan-starter-return-to-plan'),
            path: localReturnPath,
            icon: Icons.arrow_back_rounded,
            label: '계획 메뉴로 돌아가기',
            onPressed: () => _exitAfterSectionOutro(widget.onExitToPlan),
          ),
        ),
        Positioned.fromRect(
          rect: buttonBounds,
          child: _PlanStarterPhaseActionButton(
            key: const ValueKey('plan-starter-open-phase-editor'),
            path: localButtonPath,
            onPressed: widget.hasPlanElements
                ? () => _exitAfterSectionOutro(widget.onOpenPhaseEditor)
                : null,
          ),
        ),
      ],
    );
  }
}

class _PlanWeaponLevelStatus extends StatelessWidget {
  const _PlanWeaponLevelStatus({required this.level, required this.unlocked});

  final int? level;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final railInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
      return Padding(
        padding: EdgeInsets.fromLTRB(railInset + 8, 2, railInset + 8, 2),
        child: Row(
          children: [
            const Text(
              'WEAPON',
              style: TextStyle(
                color: AppColors.primary,
                fontFamily: 'GyeonggiTitle',
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                unlocked ? 'Lv. ${level ?? '--'}' : 'Lv. --',
                key: const ValueKey('plan-starter-weapon-level'),
                style: const TextStyle(
                  color: AppColors.text,
                  fontFamily: 'GyeonggiTitle',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PlanStudentPortrait extends StatelessWidget {
  const _PlanStudentPortrait({
    required this.portraitAsset,
    required this.bondRank,
    required this.student,
    required this.owned,
    required this.planned,
  });

  final String portraitAsset;
  final int? bondRank;
  final StudentCatalogEntry student;
  final bool owned;
  final bool planned;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      AssetImageGrid(
        key: const ValueKey('plan-starter-student-portrait'),
        items: [
          AssetImageGridItem(
            asset: bondRankPortraitBackgroundAsset(bondRank),
            column: 0,
            row: 0,
            edgeCropFraction: 0.11,
            clipPathBuilder: studentGridCardPath,
          ),
          AssetImageGridItem(
            asset: portraitAsset,
            column: 0,
            row: 0,
            scale: 0.98,
            clipRadiusFraction: 0.12,
            alphaThreshold: 0.04,
          ),
        ],
      ),
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: const ValueKey('plan-starter-student-portrait-status'),
            painter: StudentGridCardOverlayPainter(
              students: [student],
              ownedIds: owned ? {student.studentId} : const {},
              columns: 1,
              rows: 1,
              columnGap: 0,
              rowGap: 0,
              rowHorizontalOffsets: const [0],
              contentPadding: EdgeInsets.zero,
              showAttributes: false,
              showNames: false,
              selectedIndex: null,
              plannedIds: planned ? {student.studentId} : const {},
            ),
          ),
        ),
      ),
    ],
  );
}

class _PlanStudentStatusFoundationPainter extends CustomPainter {
  const _PlanStudentStatusFoundationPainter({
    required this.canvasSize,
    required this.studentStars,
    required this.weaponStars,
  });

  final Size canvasSize;
  final int studentStars;
  final int weaponStars;

  @override
  void paint(Canvas canvas, Size size) {
    final containers = planStarterStudioDocument.containers.where(
      planStarterStatusFoundationPaintsContainer,
    );
    for (final container in containers) {
      final path = planStarterContainerPath(canvasSize, container.id);
      if (container.triangleTexture) {
        canvas.save();
        canvas.clipPath(path, doAntiAlias: true);
        BATriangleTexturePainter(_planElementTexture).paint(canvas, size);
        canvas.restore();
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.surfaceRaised.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.outline.withValues(alpha: 0.74)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
    for (final feature in planStarterStudioDocument.features) {
      if (feature.parentContainerId != 'container-2') continue;
      final path = planStarterFeaturePath(canvasSize, feature.id);
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xff203243).withValues(alpha: 0.98),
      );
    }
    _paintStarIndicator(canvas);
  }

  void _paintStarIndicator(Canvas canvas) {
    final bounds = planStarterContainerPath(
      canvasSize,
      'container-3',
    ).getBounds();
    paintStudentStarStatus(
      canvas,
      bounds,
      studentStars: studentStars,
      weaponStars: weaponStars,
    );
  }

  @override
  bool shouldRepaint(_PlanStudentStatusFoundationPainter oldDelegate) =>
      oldDelegate.canvasSize != canvasSize ||
      oldDelegate.studentStars != studentStars ||
      oldDelegate.weaponStars != weaponStars;
}

class _LocalPathBorderPainter extends CustomPainter {
  const _LocalPathBorderPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.74)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(_LocalPathBorderPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _PlanElementSectionMotion extends StatelessWidget {
  const _PlanElementSectionMotion({
    super.key,
    required this.animation,
    required this.motion,
    required this.child,
  });

  final Animation<double> animation;
  final SectionMotionSpec motion;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final progress = Curves.easeInOutCubic.transform(
          animation.value.clamp(0.0, 1.0).toDouble(),
        );
        final exiting = animation.status == AnimationStatus.reverse;
        final direction = sectionMotionOffset(
          constraints.biggest,
          exiting ? motion.outro : motion.intro,
        );
        return Transform.translate(
          key: ValueKey('$key-transform'),
          offset: direction * (exiting ? 1 - progress : progress - 1),
          child: child,
        );
      },
    ),
  );
}

class _PlanStarterSection extends StatelessWidget {
  const _PlanStarterSection({
    super.key,
    required this.path,
    required this.child,
  });

  final Path path;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        child: CustomPaint(painter: _PlanStarterFoundationPainter(path)),
      ),
      ClipPath(clipper: _FixedPathClipper(path), child: child),
    ],
  );
}

class _PlanStarterFoundationPainter extends CustomPainter {
  const _PlanStarterFoundationPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..color = AppColors.surface.withValues(
          alpha: planElementBuilderSectionOpacity,
        ),
    );
  }

  @override
  bool shouldRepaint(_PlanStarterFoundationPainter oldDelegate) =>
      oldDelegate.path != path;
}

const planPresetListTexture = phaseEditorPathSurfaceTexture;

BATriangleTextureConfig planStarterPhaseActionTexture(double height) =>
    BATriangleTextureConfig(
      baseColor: const Color(0xff80688e),
      panelColor: const Color(0xff92779e),
      softColor: const Color(0xffa98daf),
      accentColor: const Color(0xffd6a5d5),
      triangleSize: math.max(6, height * 0.8),
      tessellationContrast: 0.035,
      randomSeed: 9127,
      macroTriangleChance: 0.08,
      macroTriangleScale: 2.4,
      macroTriangleContrast: 0.024,
      lightStrength: 0.14,
      edgeVignetteStrength: 0.12,
      fogStrength: 0.07,
    );

class _PlanStarterPhaseActionButton extends StatelessWidget {
  const _PlanStarterPhaseActionButton({
    super.key,
    required this.path,
    required this.onPressed,
  });

  final Path path;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final button = Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          key: const ValueKey('plan-starter-phase-action-texture'),
          painter: _PlanStarterPhaseActionPainter(path: path, enabled: enabled),
        ),
        ClipPath(
          clipper: _FixedPathClipper(path),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              hoverColor: Colors.white.withValues(alpha: 0.10),
              highlightColor: Colors.white.withValues(alpha: 0.14),
              splashColor: Colors.white.withValues(alpha: 0.12),
              child: Icon(
                enabled ? Icons.account_tree_outlined : Icons.lock_rounded,
                size: 20,
                color: enabled
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.62),
              ),
            ),
          ),
        ),
      ],
    );
    return Tooltip(
      message: enabled ? '페이즈 구성 열기' : '계획 요소를 먼저 만드세요',
      child: button,
    );
  }
}

class _PlanStarterPhaseActionPainter extends CustomPainter {
  const _PlanStarterPhaseActionPainter({
    required this.path,
    required this.enabled,
  });

  final Path path;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..color = planPresetListTexture.baseColor);
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(
      planStarterPhaseActionTexture(size.height),
    ).paint(canvas, size);
    if (!enabled) {
      canvas.drawColor(Colors.black.withValues(alpha: 0.14), BlendMode.srcOver);
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(
          0xffe5a0ea,
        ).withValues(alpha: enabled ? 0.82 : 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_PlanStarterPhaseActionPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.enabled != enabled;
}

class _PlanStarterSideActionButton extends StatelessWidget {
  const _PlanStarterSideActionButton({
    super.key,
    required this.path,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Path path;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _PlanStarterSideActionPainter(
                path: path,
                enabled: enabled,
              ),
            ),
            ClipPath(
              clipper: _FixedPathClipper(path),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  hoverColor: Colors.white.withValues(alpha: 0.08),
                  highlightColor: Colors.white.withValues(alpha: 0.12),
                  splashColor: Colors.white.withValues(alpha: 0.10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            enabled ? icon : Icons.lock_rounded,
                            size: 18,
                            color: enabled
                                ? AppColors.text
                                : AppColors.textMuted.withValues(alpha: 0.62),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            maxLines: 1,
                            style: TextStyle(
                              color: enabled
                                  ? AppColors.text
                                  : AppColors.textMuted.withValues(alpha: 0.62),
                              fontFamily: 'GyeonggiTitle',
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanStarterSideActionPainter extends CustomPainter {
  const _PlanStarterSideActionPainter({
    required this.path,
    required this.enabled,
  });

  final Path path;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = enabled
            ? const Color(0xff29475f)
            : AppColors.surfaceRaised.withValues(alpha: 0.72),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = enabled
            ? AppColors.primary.withValues(alpha: 0.54)
            : AppColors.outline.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PlanStarterSideActionPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.enabled != enabled;
}

class _PlanPresetLoaderDiagonalList extends StatefulWidget {
  const _PlanPresetLoaderDiagonalList({
    required this.presets,
    required this.selectedPresetId,
    required this.onSelected,
  });

  final List<PlanElementPreset> presets;
  final String? selectedPresetId;
  final ValueChanged<PlanElementPreset> onSelected;

  @override
  State<_PlanPresetLoaderDiagonalList> createState() =>
      _PlanPresetLoaderDiagonalListState();
}

class _PlanPresetLoaderDiagonalListState
    extends State<_PlanPresetLoaderDiagonalList> {
  static const _verticalInset = 8.0;
  static const _normalGap = 10.0;
  static const _scrollbarReserve = 14.0;
  static const _rowHeight = 46.0;
  static const _rowGap = 8.0;
  final ScrollController _controller = ScrollController();
  bool _scrollCorrectionScheduled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleScrollCorrection() {
    if (_scrollCorrectionScheduled) return;
    _scrollCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCorrectionScheduled = false;
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final corrected = _controller.offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((_controller.offset - corrected).abs() > 0.01) {
        _controller.jumpTo(corrected);
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contentHeight =
          _verticalInset * 2 +
          widget.presets.length * _rowHeight +
          math.max(0, widget.presets.length - 1) * _rowGap;
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final rawScroll = _controller.hasClients ? _controller.offset : 0.0;
          final scroll = planStageEffectiveScrollOffset(
            rawOffset: rawScroll,
            contentHeight: contentHeight,
            viewportHeight: constraints.maxHeight,
          );
          if ((rawScroll - scroll).abs() > 0.01) {
            _scheduleScrollCorrection();
          }
          final maxScroll = math.max(
            0.0,
            contentHeight - constraints.maxHeight,
          );
          final fogVisibility = scrollViewportFogVisibility(
            minScrollExtent: 0,
            maxScrollExtent: maxScroll,
            pixels: scroll,
          );
          final tangent = math.tan(80 * math.pi / 180);
          final horizontalGap = _normalGap / math.sin(80 * math.pi / 180);
          final rowWidth = math.max(
            1.0,
            constraints.maxWidth -
                (constraints.maxHeight + _rowHeight) / tangent -
                horizontalGap * 2 -
                _scrollbarReserve,
          );
          final rows = <Widget>[];
          var top = _verticalInset;
          for (final preset in widget.presets) {
            final viewportTop = top - scroll;
            final left =
                horizontalGap + (constraints.maxHeight - viewportTop) / tangent;
            rows.add(
              Positioned(
                left: left,
                top: top,
                width: rowWidth,
                height: _rowHeight,
                child: _PlanPresetLoaderRow(
                  key: ValueKey('plan-starter-preset-${preset.id}'),
                  preset: preset,
                  selected: widget.selectedPresetId == preset.id,
                  onPressed: () => widget.onSelected(preset),
                ),
              ),
            );
            top += _rowHeight + _rowGap;
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  key: const ValueKey('plan-starter-preset-scroll'),
                  controller: _controller,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: contentHeight,
                    child: Stack(clipBehavior: Clip.none, children: rows),
                  ),
                ),
              ),
              Positioned.fill(
                child: ScrollViewportFog(
                  key: const ValueKey('plan-starter-preset-fog'),
                  keyPrefix: 'plan-starter-preset-viewport-fog',
                  showTop: fogVisibility.showTop,
                  showBottom: fogVisibility.showBottom,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('plan-starter-preset-diagonal-scrollbar'),
                  painter: _PlanPresetDiagonalScrollbarPainter(
                    offset: scroll,
                    contentExtent: contentHeight,
                  ),
                ),
              ),
              if (maxScroll > 0)
                Positioned(
                  left: math.max(
                    0,
                    constraints.maxWidth - constraints.maxHeight / tangent - 24,
                  ),
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: const ValueKey('plan-starter-preset-scrollbar-drag'),
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) {
                      const trackInset = 10.0;
                      final trackHeight = math.max(
                        1.0,
                        constraints.maxHeight - trackInset * 2,
                      );
                      final handleHeight = math.max(
                        28.0,
                        trackHeight * constraints.maxHeight / contentHeight,
                      );
                      final travel = math.max(1.0, trackHeight - handleHeight);
                      _controller.jumpTo(
                        (_controller.offset +
                                details.delta.dy * maxScroll / travel)
                            .clamp(0.0, maxScroll),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

class _PlanPresetLoaderRow extends StatelessWidget {
  const _PlanPresetLoaderRow({
    super.key,
    required this.preset,
    required this.selected,
    required this.onPressed,
  });

  final PlanElementPreset preset;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final path = _bilateralPath(constraints.biggest, radius: 8);
      return Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PlanPresetLoaderRowPainter(
              path: path,
              selected: selected,
            ),
          ),
          ClipPath(
            clipper: _FixedPathClipper(path),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          preset.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.text,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (preset.isDefault)
                        const Text(
                          '기본',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PlanPresetLoaderRowPainter extends CustomPainter {
  const _PlanPresetLoaderRowPainter({
    required this.path,
    required this.selected,
  });

  final Path path;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? AppColors.primaryMuted.withValues(alpha: 0.76)
            : AppColors.surfaceRaised.withValues(alpha: 0.76),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selected ? AppColors.primary : AppColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 1,
    );
  }

  @override
  bool? hitTest(Offset position) => path.contains(position);

  @override
  bool shouldRepaint(_PlanPresetLoaderRowPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.selected != selected;
}

class _PlanPresetListContainerPainter extends CustomPainter {
  const _PlanPresetListContainerPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(planPresetListTexture).paint(canvas, size);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PlanPresetListContainerPainter oldDelegate) =>
      oldDelegate.path != path;
}

class PlanPresetDiagonalList extends StatefulWidget {
  const PlanPresetDiagonalList({
    super.key,
    required this.keyPrefix,
    required this.itemCount,
    required this.cardWidth,
    required this.itemBuilder,
  });

  final String keyPrefix;
  final int itemCount;
  final double cardWidth;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<PlanPresetDiagonalList> createState() => _PlanPresetDiagonalListState();
}

class _PlanPresetDiagonalListState extends State<PlanPresetDiagonalList> {
  static const _verticalInset = 6.0;
  final ScrollController _controller = ScrollController();
  bool _scrollCorrectionScheduled = false;

  void _scheduleScrollCorrection() {
    if (_scrollCorrectionScheduled) return;
    _scrollCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCorrectionScheduled = false;
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final corrected = _controller.offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((_controller.offset - corrected).abs() > 0.01) {
        _controller.jumpTo(corrected);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final itemHeight = planPresetListCardHeight(widget.cardWidth);
      final contentHeight =
          _verticalInset * 2 +
          itemHeight * widget.itemCount +
          planElementBuilderCardGap * math.max(0, widget.itemCount - 1);
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final rawScroll = _controller.hasClients ? _controller.offset : 0.0;
          final maxScroll = math.max(
            0.0,
            contentHeight - constraints.maxHeight,
          );
          final scroll = planStageEffectiveScrollOffset(
            rawOffset: rawScroll,
            contentHeight: contentHeight,
            viewportHeight: constraints.maxHeight,
          );
          if ((rawScroll - scroll).abs() > 0.01) {
            _scheduleScrollCorrection();
          }
          final fogVisibility = scrollViewportFogVisibility(
            minScrollExtent: 0.0,
            maxScrollExtent: maxScroll,
            pixels: scroll,
          );
          var top = _verticalInset;
          final cards = <Widget>[];
          for (var index = 0; index < widget.itemCount; index++) {
            final cardLeft = planStageDiagonalCardLeft(
              viewportHeight: constraints.maxHeight,
              itemTop: top,
              itemHeight: itemHeight,
              scrollOffset: scroll,
              cardWidth: widget.cardWidth,
            );
            cards.add(
              Positioned(
                left: cardLeft,
                top: top,
                width: widget.cardWidth,
                height: itemHeight,
                child: widget.itemBuilder(context, index),
              ),
            );
            if (index < widget.itemCount - 1) {
              final indicatorTop = top + itemHeight + 2;
              final indicatorHeight = planElementBuilderCardGap - 4;
              cards.add(
                Positioned(
                  key: ValueKey('${widget.keyPrefix}-flow-$index'),
                  left: cardLeft,
                  top: indicatorTop,
                  width: widget.cardWidth,
                  height: indicatorHeight,
                  child: DiagonalFlowIndicator(
                    parallelogramHeight: itemHeight,
                    paintKey: const ValueKey('plan-preset-flow-triangle'),
                  ),
                ),
              );
            }
            top += itemHeight + planElementBuilderCardGap;
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  key: ValueKey('${widget.keyPrefix}-scroll'),
                  controller: _controller,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: contentHeight,
                    child: Stack(clipBehavior: Clip.none, children: cards),
                  ),
                ),
              ),
              Positioned.fill(
                child: ScrollViewportFog(
                  key: ValueKey('${widget.keyPrefix}-fog'),
                  keyPrefix: '${widget.keyPrefix}-viewport-fog',
                  showTop: fogVisibility.showTop,
                  showBottom: fogVisibility.showBottom,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  key: ValueKey('${widget.keyPrefix}-diagonal-scrollbar'),
                  painter: _PlanPresetDiagonalScrollbarPainter(
                    offset: scroll,
                    contentExtent: contentHeight,
                  ),
                ),
              ),
              if (maxScroll > 0)
                Positioned(
                  left: math.max(
                    0,
                    constraints.maxWidth -
                        constraints.maxHeight / math.tan(80 * math.pi / 180) -
                        24,
                  ),
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: ValueKey('${widget.keyPrefix}-scrollbar-drag'),
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) {
                      const trackInset = 10.0;
                      final trackHeight = math.max(
                        1.0,
                        constraints.maxHeight - trackInset * 2,
                      );
                      final handleHeight = math.max(
                        28.0,
                        trackHeight * constraints.maxHeight / contentHeight,
                      );
                      final travel = math.max(1.0, trackHeight - handleHeight);
                      _controller.jumpTo(
                        (_controller.offset +
                                details.delta.dy * maxScroll / travel)
                            .clamp(0.0, maxScroll),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

class _PlanPresetDiagonalScrollbarPainter extends CustomPainter {
  const _PlanPresetDiagonalScrollbarPainter({
    required this.offset,
    required this.contentExtent,
  });

  final double offset;
  final double contentExtent;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 10.0;
    final trackHeight = math.max(1.0, size.height - inset * 2);
    final maxScroll = math.max(0.0, contentExtent - size.height);
    final handleHeight = maxScroll <= 0
        ? trackHeight
        : math.max(28.0, trackHeight * size.height / contentExtent);
    final travel = math.max(0.0, trackHeight - handleHeight);
    final handleTop =
        inset +
        (maxScroll <= 0 ? 0 : travel * (offset / maxScroll).clamp(0.0, 1.0));
    Offset point(double y) =>
        Offset(size.width - inset - y / math.tan(80 * math.pi / 180), y);
    final trackPaint = Paint()
      ..color = AppColors.outline.withValues(alpha: 0.48)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final handlePaint = Paint()
      ..color = const Color(0xffe5a0ea)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(point(inset), point(size.height - inset), trackPaint);
    if (maxScroll <= 0) return;
    canvas.drawLine(
      point(handleTop),
      point(handleTop + handleHeight),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(_PlanPresetDiagonalScrollbarPainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.contentExtent != contentExtent;
}

/// An editable plan-stage item used by the diagonal preset/stage list.
///
/// The caller owns stage state. Every editor reports through [onChanged], so the
/// same card can be hosted outside [PlanElementBuilder] without inheriting its
/// route or list state.
class PlanPresetElementCard extends StatelessWidget {
  const PlanPresetElementCard({
    super.key,
    required this.stage,
    required this.startTargets,
    required this.stageNumber,
    required this.selected,
    required this.propagatedFields,
    required this.equipmentTypes,
    required this.hasFavoriteItem,
    required this.onSelected,
    required this.onChanged,
    this.showStageNumber = true,
    this.headerLeading,
    this.headerTrailing,
    this.layout = PlanPresetElementLayout.standard,
  });

  final PlanElementStageDraft stage;
  final Map<String, int> startTargets;
  final int stageNumber;
  final bool selected;
  final Set<String> propagatedFields;
  final List<String?> equipmentTypes;
  final bool hasFavoriteItem;
  final VoidCallback onSelected;
  final void Function(String key, int value) onChanged;
  final bool showStageNumber;
  final Widget? headerLeading;
  final Widget? headerTrailing;
  final PlanPresetElementLayout layout;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final height = constraints.hasBoundedHeight
          ? constraints.maxHeight
          : planPresetListCardHeight(width, layout: layout);
      final size = Size(width, height);
      final envelopePath = planPresetElementEnvelopePath(size);
      const headerTop = 6.0;
      const headerHeight = 32.0;
      final headerTopInterval = _pathHorizontalInterval(
        envelopePath,
        width,
        headerTop + 1,
      );
      final headerBottomInterval = _pathHorizontalInterval(
        envelopePath,
        width,
        headerTop + headerHeight - 1,
      );
      final headerLeft =
          math.max(headerTopInterval.$1, headerBottomInterval.$1) + 8;
      final headerRight =
          width - math.min(headerTopInterval.$2, headerBottomInterval.$2) + 8;
      return SizedBox(
        height: height,
        child: ClipPath(
          clipper: _FixedPathClipper(envelopePath),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onSelected,
              child: CustomPaint(
                foregroundPainter: _CardBorderPainter(
                  envelopePath,
                  selected: selected,
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: KeyedSubtree(
                        key: ValueKey(
                          'plan-preset-element-$stageNumber-element-5',
                        ),
                        child: ColoredBox(
                          color: selected
                              ? AppColors.surfaceRaised.withValues(alpha: 0.98)
                              : AppColors.surfaceRaised.withValues(alpha: 0.88),
                          child: Align(
                            alignment: const Alignment(-0.82, -0.92),
                            child: showStageNumber
                                ? Text(
                                    '$stageNumber',
                                    key: ValueKey(
                                      'plan-stage-$stageNumber-number',
                                    ),
                                    style: AppTextStyles.planPhaseNumber,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    _surface(
                      size,
                      'element-1',
                      child: _PresetRegionContent(
                        title: '학생 레벨',
                        centerControls: true,
                        children: [_stepper('', 'level')],
                      ),
                    ),
                    _surface(
                      size,
                      'element-2',
                      child: _PresetRegionContent(
                        title: '전용무기 레벨',
                        centerControls: true,
                        children: [_stepper('', 'weapon_level')],
                      ),
                    ),
                    _surface(
                      size,
                      'element-3',
                      child: _PresetRegionContent(
                        title: '인연 랭크',
                        compact: true,
                        centerControls: true,
                        children: [_stepper('', 'bond_rank')],
                      ),
                    ),
                    _surface(
                      size,
                      'element-4',
                      color: Colors.transparent,
                      showBorder: false,
                      child: _StarTargetStrip(
                        stageNumber: stageNumber,
                        currentStudentStar: _start('student_star'),
                        currentWeaponStar: _start('weapon_star'),
                        studentStar: _target('student_star'),
                        weaponStar: _target('weapon_star'),
                        studentPropagated: _propagated('student_star'),
                        weaponPropagated: _propagated('weapon_star'),
                        onChanged: onChanged,
                        interactive: false,
                      ),
                    ),
                    _surface(
                      size,
                      'element-6',
                      child: _PresetRegionContent(
                        title: '스킬 레벨',
                        singleRow: true,
                        children: [
                          _stepper('', 'ex_skill'),
                          _stepper('', 'skill1'),
                          _stepper('', 'skill2'),
                          _stepper('', 'skill3'),
                        ],
                      ),
                    ),
                    _surface(
                      size,
                      'element-7',
                      child: _PresetEquipmentEditor(
                        stageNumber: stageNumber,
                        stage: stage,
                        equipmentTypes: equipmentTypes,
                        hasFavoriteItem: hasFavoriteItem,
                        propagatedFields: propagatedFields,
                        onChanged: onChanged,
                      ),
                    ),
                    _surface(
                      size,
                      'element-8',
                      child: _PresetRegionContent(
                        title: '추가 능력치',
                        compact: true,
                        singleRow: true,
                        children: [
                          _stepper('HP', 'stat_hp'),
                          _stepper('ATK', 'stat_atk'),
                          _stepper('HEAL', 'stat_heal'),
                        ],
                      ),
                    ),
                    _surface(
                      size,
                      'element-9',
                      color: Colors.black.withValues(alpha: 0.34),
                      child: const _LockedTargetRegion(),
                    ),
                    _starHitSurface(size),
                    if (headerLeading != null)
                      Positioned(
                        left: headerLeft,
                        top: headerTop,
                        child: headerLeading!,
                      ),
                    if (headerTrailing != null)
                      Positioned(
                        right: headerRight,
                        top: headerTop,
                        child: headerTrailing!,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  (double, double) _pathHorizontalInterval(Path path, double width, double y) {
    var left = 0.0;
    while (left < width && !path.contains(Offset(left, y))) {
      left += 1;
    }
    var right = width;
    while (right > left && !path.contains(Offset(right, y))) {
      right -= 1;
    }
    return (left, right);
  }

  int _target(String key) =>
      stage.targets[key] ?? planElementTargetMinimums[key] ?? 0;

  int _start(String key) =>
      startTargets[key] ?? planElementTargetMinimums[key] ?? 0;

  bool _propagated(String key) => propagatedFields.contains('${stage.id}:$key');

  Widget _surface(
    Size size,
    String id, {
    required Widget child,
    Color? color,
    bool showBorder = true,
  }) {
    final rect = planPresetElementRect(size, id, layout: layout);
    final localPath = planPresetElementLocalPath(rect.size, id);
    return Positioned.fromRect(
      rect: rect,
      child: KeyedSubtree(
        key: ValueKey('plan-preset-element-$stageNumber-$id'),
        child: ClipPath(
          clipper: _FixedPathClipper(localPath),
          child: ColoredBox(
            key: ValueKey('plan-preset-element-$stageNumber-$id-surface-fill'),
            color:
                color ??
                const Color(
                  0xff30485f,
                ).withValues(alpha: selected ? 0.82 : 0.68),
            child: CustomPaint(
              key: ValueKey(
                'plan-preset-element-$stageNumber-$id-surface-paint',
              ),
              foregroundPainter: showBorder
                  ? _CardBorderPainter(localPath, selected: false)
                  : null,
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _starHitSurface(Size size) {
    final visibleRect = planPresetElementRect(
      size,
      'element-4',
      layout: layout,
    );
    final hitHeight = math.max(28.0, visibleRect.height);
    final rect = Rect.fromCenter(
      center: visibleRect.center,
      width: visibleRect.width,
      height: hitHeight,
    );
    return Positioned.fromRect(
      rect: rect,
      child: _StarTargetStrip(
        stageNumber: stageNumber,
        currentStudentStar: _start('student_star'),
        currentWeaponStar: _start('weapon_star'),
        studentStar: _target('student_star'),
        weaponStar: _target('weapon_star'),
        studentPropagated: _propagated('student_star'),
        weaponPropagated: _propagated('weapon_star'),
        onChanged: onChanged,
        interactive: true,
        cutReferenceHeight: visibleRect.height,
      ),
    );
  }

  Widget _stepper(String label, String key, {bool unsupported = false}) =>
      _CompactTargetStepper(
        key: ValueKey('plan-stage-$stageNumber-$key'),
        label: label,
        value: stage.targets[key] ?? planElementTargetMinimums[key] ?? 0,
        minimum: planElementTargetMinimums[key] ?? 0,
        maximum: planElementTargetMaximums[key] ?? 99,
        propagated: propagatedFields.contains('${stage.id}:$key'),
        unsupported: unsupported,
        valueFontSize: key.startsWith('stat_') ? 13.5 : 25.2,
        onChanged: (value) => onChanged(key, value),
      );
}

class _PresetRegionContent extends StatelessWidget {
  const _PresetRegionContent({
    required this.title,
    required this.children,
    this.compact = false,
    this.singleRow = false,
    this.centerControls = false,
  });

  final String title;
  final List<Widget> children;
  final bool compact;
  final bool singleRow;
  final bool centerControls;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cutInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          cutInset + 1.5,
          compact ? 1 : 3,
          cutInset + 1.5,
          compact ? 1 : 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: _titleStyle),
            SizedBox(height: compact ? 0 : 2),
            Expanded(
              child: centerControls
                  ? Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: children.single,
                      ),
                    )
                  : singleRow
                  ? _singleRow()
                  : _wrapped(),
            ),
          ],
        ),
      );
    },
  );

  Widget _singleRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final child in children)
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
    ],
  );

  Widget _wrapped() => Wrap(
    spacing: compact ? 2 : 4,
    runSpacing: compact ? 0 : 2,
    alignment: compact ? WrapAlignment.end : WrapAlignment.spaceBetween,
    children: children,
  );

  static const _titleStyle = TextStyle(
    color: AppColors.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );
}

class _PresetEquipmentEditor extends StatelessWidget {
  const _PresetEquipmentEditor({
    required this.stageNumber,
    required this.stage,
    required this.equipmentTypes,
    required this.hasFavoriteItem,
    required this.propagatedFields,
    required this.onChanged,
  });

  final int stageNumber;
  final PlanElementStageDraft stage;
  final List<String?> equipmentTypes;
  final bool hasFavoriteItem;
  final Set<String> propagatedFields;
  final void Function(String key, int value) onChanged;

  int _value(String key) =>
      stage.targets[key] ?? planElementTargetMinimums[key] ?? 0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cutInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
      return Padding(
        padding: EdgeInsets.fromLTRB(cutInset + 2, 2, cutInset + 2, 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('장비 상태', style: _PresetRegionContent._titleStyle),
            const SizedBox(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < 3; index++) ...[
                    if (index > 0) const _PresetEquipmentDivider(),
                    Expanded(
                      child: _PresetEquipmentSlot(
                        stageNumber: stageNumber,
                        slot: index + 1,
                        equipmentType: index < equipmentTypes.length
                            ? equipmentTypes[index]
                            : null,
                        tier: _value('equip${index + 1}_tier'),
                        level: _value('equip${index + 1}_level'),
                        tierPropagated: propagatedFields.contains(
                          '${stage.id}:equip${index + 1}_tier',
                        ),
                        levelPropagated: propagatedFields.contains(
                          '${stage.id}:equip${index + 1}_level',
                        ),
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                  const _PresetEquipmentDivider(),
                  Expanded(
                    child: _PresetFavoriteItemSlot(
                      stageNumber: stageNumber,
                      value: _value('equip4_tier'),
                      enabled: hasFavoriteItem,
                      propagated: propagatedFields.contains(
                        '${stage.id}:equip4_tier',
                      ),
                      onChanged: (value) => onChanged('equip4_tier', value),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PresetEquipmentDivider extends StatelessWidget {
  const _PresetEquipmentDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 6,
    child: CustomPaint(painter: _PresetEquipmentDividerPainter()),
  );
}

class _PresetEquipmentDividerPainter extends CustomPainter {
  const _PresetEquipmentDividerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final endpoints = studentDiagonalDividerEndpoints(size);
    canvas.drawLine(
      endpoints[0],
      endpoints[1],
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PresetEquipmentDividerPainter oldDelegate) => false;
}

class _PresetEquipmentSlot extends StatelessWidget {
  const _PresetEquipmentSlot({
    required this.stageNumber,
    required this.slot,
    required this.equipmentType,
    required this.tier,
    required this.level,
    required this.tierPropagated,
    required this.levelPropagated,
    required this.onChanged,
  });

  final int stageNumber;
  final int slot;
  final String? equipmentType;
  final int tier;
  final int level;
  final bool tierPropagated;
  final bool levelPropagated;
  final void Function(String key, int value) onChanged;

  String get _tierKey => 'equip${slot}_tier';
  String get _levelKey => 'equip${slot}_level';

  String? get _assetPath {
    if (equipmentType == null || tier < 1 || tier > 10) return null;
    return 'assets/item_icons/equipment/'
        'Equipment_Icon_${equipmentType}_Tier$tier.png';
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    color: tierPropagated || levelPropagated
        ? AppColors.primary.withValues(alpha: 0.14)
        : Colors.transparent,
    child: Column(
      children: [
        _EquipmentValueControl(
          controlKey: 'plan-stage-$stageNumber-$_tierKey',
          value: 'T$tier',
          valueFontSize: 13.5,
          canDecrease: tier > (planElementTargetMinimums[_tierKey] ?? 0),
          canIncrease: tier < (planElementTargetMaximums[_tierKey] ?? tier),
          onDecrease: () => onChanged(_tierKey, tier - 1),
          onIncrease: () => onChanged(_tierKey, tier + 1),
        ),
        Expanded(
          child: FractionallySizedBox(
            key: ValueKey('plan-stage-$stageNumber-equipment-$slot-icon'),
            widthFactor: 0.672,
            heightFactor: 0.672,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  defaultStudentPortraitBackgroundAsset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
                if (_assetPath != null)
                  Image.asset(
                    _assetPath!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
              ],
            ),
          ),
        ),
        _EquipmentValueControl(
          controlKey: 'plan-stage-$stageNumber-$_levelKey',
          value: 'Lv. $level',
          valueFontSize: 16.2,
          canDecrease: level > (planElementTargetMinimums[_levelKey] ?? 0),
          canIncrease: level < (planElementTargetMaximums[_levelKey] ?? level),
          onDecrease: () => onChanged(_levelKey, level - 1),
          onIncrease: () => onChanged(_levelKey, level + 1),
        ),
        _MaxBadge(
          controlKey: 'plan-stage-$stageNumber-equipment-$slot',
          enabled:
              tier < (planElementTargetMaximums[_tierKey] ?? tier) ||
              level < (planElementTargetMaximums[_levelKey] ?? level),
          onTap: () {
            onChanged(_tierKey, planElementTargetMaximums[_tierKey] ?? tier);
            onChanged(_levelKey, planElementTargetMaximums[_levelKey] ?? level);
          },
        ),
        const SizedBox(height: 6),
      ],
    ),
  );
}

class _PresetFavoriteItemSlot extends StatelessWidget {
  const _PresetFavoriteItemSlot({
    required this.stageNumber,
    required this.value,
    required this.enabled,
    required this.propagated,
    required this.onChanged,
  });

  final int stageNumber;
  final int value;
  final bool enabled;
  final bool propagated;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    color: propagated
        ? AppColors.primary.withValues(alpha: 0.14)
        : Colors.transparent,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '애장품',
            style: TextStyle(
              color: AppColors.textMuted,
              fontFamily: 'GyeonggiTitle',
              fontSize: 8,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 1),
        if (!enabled)
          const Text('-', style: TextStyle(fontSize: 21))
        else
          _EquipmentValueControl(
            controlKey: 'plan-stage-$stageNumber-equip4_tier',
            value: 'T$value',
            valueFontSize: 16.2,
            canDecrease:
                value > (planElementTargetMinimums['equip4_tier'] ?? 0),
            canIncrease:
                value < (planElementTargetMaximums['equip4_tier'] ?? value),
            onDecrease: () => onChanged(value - 1),
            onIncrease: () => onChanged(value + 1),
          ),
        const SizedBox(height: 1),
        _MaxBadge(
          controlKey: 'plan-stage-$stageNumber-equip4_tier',
          enabled:
              enabled &&
              value < (planElementTargetMaximums['equip4_tier'] ?? value),
          onTap: () =>
              onChanged(planElementTargetMaximums['equip4_tier'] ?? value),
        ),
      ],
    ),
  );
}

class _EquipmentValueControl extends StatelessWidget {
  const _EquipmentValueControl({
    required this.controlKey,
    required this.value,
    required this.valueFontSize,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String controlKey;
  final String value;
  final double valueFontSize;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepTextButton(
          key: ValueKey('$controlKey-decrease'),
          text: '−',
          enabled: canDecrease,
          onTap: onDecrease,
        ),
        Text(
          value,
          key: ValueKey('$controlKey-value'),
          style: TextStyle(
            color: AppColors.text,
            fontFamily: 'GyeonggiTitle',
            fontSize: valueFontSize,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        _StepTextButton(
          key: ValueKey('$controlKey-increase'),
          text: '+',
          enabled: canIncrease,
          onTap: onIncrease,
        ),
      ],
    ),
  );
}

class _StarTargetStrip extends StatelessWidget {
  const _StarTargetStrip({
    required this.stageNumber,
    required this.currentStudentStar,
    required this.currentWeaponStar,
    required this.studentStar,
    required this.weaponStar,
    required this.studentPropagated,
    required this.weaponPropagated,
    required this.onChanged,
    required this.interactive,
    this.cutReferenceHeight,
  });

  final int stageNumber;
  final int currentStudentStar;
  final int currentWeaponStar;
  final int studentStar;
  final int weaponStar;
  final bool studentPropagated;
  final bool weaponPropagated;
  final void Function(String key, int value) onChanged;
  final bool interactive;
  final double? cutReferenceHeight;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (!interactive) {
        return StudentStarStatus(
          studentStars: currentStudentStar,
          weaponStars: currentWeaponStar,
          targetStudentStars: studentStar,
          targetWeaponStars: weaponStar,
          studentTargetPropagated: studentPropagated,
          weaponTargetPropagated: weaponPropagated,
        );
      }
      final visibleHeight = cutReferenceHeight ?? constraints.maxHeight;
      final visibleTop = (constraints.maxHeight - visibleHeight) / 2;
      final segmentRects = studentStarSegmentRects(
        Rect.fromLTWH(0, visibleTop, constraints.maxWidth, visibleHeight),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < segmentRects.length; index++)
            Positioned.fromRect(
              rect: Rect.fromLTRB(
                segmentRects[index].left,
                0,
                segmentRects[index].right,
                constraints.maxHeight,
              ),
              child: _starHitTarget(index),
            ),
        ],
      );
    },
  );

  Widget _starHitTarget(int index) {
    final studentSegment = index < 5;
    final value = studentSegment ? index + 1 : index - 4;
    final selectedValue = studentSegment ? studentStar : weaponStar;
    final requestedValue = value <= selectedValue ? value - 1 : value;
    final keyPrefix = studentSegment
        ? 'plan-stage-$stageNumber-student-star'
        : 'plan-stage-$stageNumber-weapon-star';
    return Semantics(
      button: true,
      selected: value == selectedValue,
      label: '${studentSegment ? '학생' : '전용무기'} 성급 $value',
      child: InkResponse(
        key: ValueKey('$keyPrefix-$value'),
        onTap: () => onChanged(
          studentSegment ? 'student_star' : 'weapon_star',
          requestedValue,
        ),
        radius: 14,
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _LockedTargetRegion extends StatelessWidget {
  const _LockedTargetRegion();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cutInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: cutInset + 6),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text(
              '심상개화 · 준비 중',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      );
    },
  );
}

class _CompactTargetStepper extends StatelessWidget {
  const _CompactTargetStepper({
    super.key,
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.propagated,
    required this.unsupported,
    required this.valueFontSize,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final bool propagated;
  final bool unsupported;
  final double valueFontSize;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final controlKey = key is ValueKey<String>
        ? (key! as ValueKey<String>).value
        : label;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: propagated
            ? AppColors.primary.withValues(alpha: 0.22)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StepTextButton(
                  key: ValueKey('$controlKey-decrease'),
                  text: '−',
                  enabled: value > minimum,
                  onTap: () => onChanged(value - 1),
                ),
                if (label.isNotEmpty) ...[
                  Text(
                    label,
                    key: ValueKey('$controlKey-label'),
                    style: TextStyle(
                      fontFamily: 'GyeonggiTitle',
                      fontSize: valueFontSize,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  '$value${unsupported ? '*' : ''}',
                  key: ValueKey('$controlKey-value'),
                  style: TextStyle(
                    fontFamily: 'GyeonggiTitle',
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                _StepTextButton(
                  key: ValueKey('$controlKey-increase'),
                  text: '+',
                  enabled: value < maximum,
                  onTap: () => onChanged(value + 1),
                ),
              ],
            ),
            _MaxBadge(
              controlKey: controlKey,
              enabled: value < maximum,
              onTap: () => onChanged(maximum),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTextButton extends StatelessWidget {
  const _StepTextButton({
    super.key,
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  final String text;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkResponse(
    onTap: enabled ? onTap : null,
    radius: 14,
    child: SizedBox(
      width: 22,
      height: 24,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: enabled ? AppColors.text : AppColors.textMuted,
            fontFamily: 'GyeonggiTitle',
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

class _MaxBadge extends StatelessWidget {
  const _MaxBadge({
    required this.controlKey,
    required this.enabled,
    required this.onTap,
  });

  final String controlKey;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: '최대값',
    child: InkWell(
      key: ValueKey('$controlKey-max'),
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 28, minHeight: 11),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.surfaceRaised.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.72)
                : AppColors.textMuted.withValues(alpha: 0.24),
            width: 0.8,
          ),
        ),
        child: Text(
          'MAX',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: enabled ? AppColors.text : AppColors.textMuted,
            fontFamily: 'GyeonggiTitle',
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ),
    ),
  );
}

class PlanBuilderControls extends StatelessWidget {
  const PlanBuilderControls({
    super.key,
    required this.canRemove,
    required this.onAdd,
    required this.onRemove,
    required this.onReset,
    required this.onConfirm,
    this.keyPrefix = 'plan-starter',
    this.resetTooltip = '현재 상태로 초기화',
    this.confirmTooltip = '계획 요소 확정',
    this.confirmKeySuffix = 'confirm',
  });

  final bool canRemove;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onReset;
  final VoidCallback? onConfirm;
  final String keyPrefix;
  final String resetTooltip;
  final String confirmTooltip;
  final String confirmKeySuffix;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _iconButton(
          key: ValueKey('$keyPrefix-add-stage'),
          tooltip: '단계 추가',
          icon: Icons.add_rounded,
          onPressed: onAdd,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _iconButton(
          key: ValueKey('$keyPrefix-remove-stage'),
          tooltip: '선택 단계 삭제',
          icon: Icons.remove_rounded,
          onPressed: canRemove ? onRemove : null,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _iconButton(
          key: ValueKey('$keyPrefix-reset'),
          tooltip: resetTooltip,
          icon: Icons.restart_alt_rounded,
          onPressed: onReset,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _iconButton(
          key: ValueKey('$keyPrefix-$confirmKeySuffix'),
          tooltip: confirmTooltip,
          icon: Icons.check_rounded,
          onPressed: onConfirm,
        ),
      ),
    ],
  );

  Widget _iconButton({
    required Key key,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => Tooltip(
    message: tooltip,
    child: _PlanStarterControlButton(
      key: key,
      onPressed: onPressed,
      icon: icon,
    ),
  );
}

Path planStarterControlButtonPath(Size size) => _bilateralPath(
  size,
  radius: math.min(9, math.min(size.width, size.height) / 2),
);

class _PlanStarterControlButton extends StatelessWidget {
  const _PlanStarterControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final path = planStarterControlButtonPath(constraints.biggest);
      final enabled = onPressed != null;
      return Semantics(
        button: true,
        enabled: enabled,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              key: const ValueKey('plan-starter-control-button-paint'),
              painter: _PlanStarterControlButtonPainter(
                path: path,
                enabled: enabled,
              ),
            ),
            ClipPath(
              clipper: _FixedPathClipper(path),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  hoverColor: Colors.white.withValues(alpha: 0.10),
                  highlightColor: Colors.white.withValues(alpha: 0.14),
                  splashColor: Colors.white.withValues(alpha: 0.12),
                  child: Icon(
                    icon,
                    size: 20,
                    color: enabled
                        ? const Color(0xff123349)
                        : AppColors.textMuted.withValues(alpha: 0.54),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _PlanStarterControlButtonPainter extends CustomPainter {
  const _PlanStarterControlButtonPainter({
    required this.path,
    required this.enabled,
  });

  final Path path;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = enabled
            ? AppColors.primary.withValues(alpha: 0.92)
            : AppColors.surfaceRaised.withValues(alpha: 0.72),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = enabled
            ? AppColors.primary.withValues(alpha: 0.88)
            : AppColors.outline.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PlanStarterControlButtonPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.enabled != enabled;
}

class _UnassignedDiagonalList extends StatefulWidget {
  const _UnassignedDiagonalList({
    required this.items,
    required this.onRename,
    required this.selectedId,
    required this.onSelected,
  });

  final List<PlanElementUnassignedItem> items;
  final void Function(String id, String name) onRename;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<_UnassignedDiagonalList> createState() =>
      _UnassignedDiagonalListState();
}

class _UnassignedDiagonalListState extends State<_UnassignedDiagonalList> {
  static const _verticalInset = 6.0;
  static const _rowHeight = 60.0;
  static const _rowGap = 10.0;
  final ScrollController _controller = ScrollController();
  bool _scrollCorrectionScheduled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scheduleScrollCorrection() {
    if (_scrollCorrectionScheduled) return;
    _scrollCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCorrectionScheduled = false;
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final corrected = _controller.offset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if ((_controller.offset - corrected).abs() > 0.01) {
        _controller.jumpTo(corrected);
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final contentHeight =
          _verticalInset * 2 +
          _rowHeight * widget.items.length +
          _rowGap * math.max(0, widget.items.length - 1);
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final rawScroll = _controller.hasClients ? _controller.offset : 0.0;
          final scroll = planStageEffectiveScrollOffset(
            rawOffset: rawScroll,
            contentHeight: contentHeight,
            viewportHeight: constraints.maxHeight,
          );
          if ((rawScroll - scroll).abs() > 0.01) {
            _scheduleScrollCorrection();
          }
          final maxScroll = math.max(
            0.0,
            contentHeight - constraints.maxHeight,
          );
          final rowWidth = planUnassignedRowWidth(
            viewportSize: constraints.biggest,
            rowHeight: _rowHeight,
          );
          var top = _verticalInset;
          final rows = <Widget>[];
          for (var index = 0; index < widget.items.length; index++) {
            final item = widget.items[index];
            rows.add(
              Positioned(
                key: ValueKey('plan-unassigned-row-host-${item.id}'),
                left: planUnassignedRowLeft(
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: _rowHeight,
                  scrollOffset: scroll,
                ),
                top: top,
                width: rowWidth,
                height: _rowHeight,
                child: _UnassignedPlanElementRow(
                  item: item,
                  selected: widget.selectedId == item.id,
                  onSelected: () => widget.onSelected(item.id),
                  onRename: (name) => widget.onRename(item.id, name),
                ),
              ),
            );
            top += _rowHeight + _rowGap;
          }
          final fogVisibility = scrollViewportFogVisibility(
            minScrollExtent: 0,
            maxScrollExtent: maxScroll,
            pixels: scroll,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  key: const ValueKey('plan-starter-unassigned-scroll'),
                  controller: _controller,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: contentHeight,
                    child: Stack(clipBehavior: Clip.none, children: rows),
                  ),
                ),
              ),
              Positioned.fill(
                child: ScrollViewportFog(
                  key: const ValueKey('plan-starter-unassigned-fog'),
                  keyPrefix: 'plan-starter-unassigned-viewport-fog',
                  showTop: fogVisibility.showTop,
                  showBottom: fogVisibility.showBottom,
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey(
                    'plan-starter-unassigned-diagonal-scrollbar',
                  ),
                  painter: _PlanPresetDiagonalScrollbarPainter(
                    offset: scroll,
                    contentExtent: contentHeight,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

double planUnassignedRowWidth({
  required Size viewportSize,
  required double rowHeight,
}) {
  const normalGap = planElementBuilderGap;
  const scrollbarReserve = 14.0;
  final tangent = math.tan(80 * math.pi / 180);
  final railInset = normalGap / math.sin(80 * math.pi / 180);
  final railSpan =
      viewportSize.width -
      viewportSize.height / tangent -
      railInset * 2 -
      scrollbarReserve;
  return math.max(80.0, railSpan + rowHeight / tangent);
}

double planUnassignedRowLeft({
  required double viewportHeight,
  required double rowTop,
  required double rowHeight,
  required double scrollOffset,
}) =>
    planElementBuilderGap / math.sin(80 * math.pi / 180) +
    (viewportHeight - (rowTop + rowHeight - scrollOffset)) /
        math.tan(80 * math.pi / 180);

class _UnassignedPlanElementRow extends StatefulWidget {
  const _UnassignedPlanElementRow({
    required this.item,
    required this.selected,
    required this.onSelected,
    required this.onRename,
  });

  final PlanElementUnassignedItem item;
  final bool selected;
  final VoidCallback onSelected;
  final ValueChanged<String> onRename;

  @override
  State<_UnassignedPlanElementRow> createState() =>
      _UnassignedPlanElementRowState();
}

class _UnassignedPlanElementRowState extends State<_UnassignedPlanElementRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.item.stageName,
  );

  @override
  void didUpdateWidget(_UnassignedPlanElementRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.stageName != widget.item.stageName &&
        _controller.text != widget.item.stageName) {
      _controller.text = widget.item.stageName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final name = _controller.text.trim();
    widget.onRename(name.isEmpty ? widget.item.stageName : name);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 60,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final path = planUnassignedItemPath(constraints.biggest);
        return Semantics(
          selected: widget.selected,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) => widget.onSelected(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: ValueKey('plan-unassigned-surface-${widget.item.id}'),
                  painter: _PlanUnassignedItemPainter(
                    path,
                    selected: widget.selected,
                  ),
                ),
                ClipPath(
                  clipper: _FixedPathClipper(path),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey('plan-unassigned-select-${widget.item.id}'),
                      onTap: widget.onSelected,
                    ),
                  ),
                ),
                ClipPath(
                  clipper: _FixedPathClipper(path),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 14, 8),
                    child: Row(
                      children: [
                        SizedBox(
                          key: ValueKey(
                            'plan-unassigned-media-${widget.item.id}',
                          ),
                          width: 44,
                          height: 44,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/item_backgrounds/square.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                              SizedBox.square(
                                dimension: 36,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.asset(
                                    'assets/student_portraits/${widget.item.studentId}.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.item.displayName} ·',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: TextField(
                            key: ValueKey(
                              'plan-unassigned-name-${widget.item.id}',
                            ),
                            controller: _controller,
                            maxLines: 1,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onTap: widget.onSelected,
                            onSubmitted: (_) => _commit(),
                            onTapOutside: (_) {
                              _commit();
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Path planUnassignedItemPath(Size size) => _bilateralPath(size, radius: 7);

class _PlanUnassignedItemPainter extends CustomPainter {
  const _PlanUnassignedItemPainter(this.path, {required this.selected});

  final Path path;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = selected ? const Color(0xd12d5069) : const Color(0xb7213c52),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? const Color(0xffe5a0ea).withValues(alpha: 0.92)
            : AppColors.outline.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.4 : 0.9,
    );
  }

  @override
  bool shouldRepaint(_PlanUnassignedItemPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.selected != selected;
}

Path _bilateralPath(Size size, {double radius = 9}) {
  final depth = size.height / math.tan(80 * math.pi / 180);
  return buildRoundedSectionPolygon([
    Offset(depth, 0),
    Offset(size.width, 0),
    Offset(size.width - depth, size.height),
    Offset(0, size.height),
  ], radius: radius);
}

class _FixedPathClipper extends CustomClipper<Path> {
  const _FixedPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_FixedPathClipper oldDelegate) => oldDelegate.path != path;
}

class _CardBorderPainter extends CustomPainter {
  const _CardBorderPainter(this.path, {required this.selected});

  final Path path;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.5 : 0.9
        ..color = selected
            ? AppColors.primary
            : AppColors.outline.withValues(alpha: 0.72),
    );
  }

  @override
  bool shouldRepaint(_CardBorderPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.selected != selected;
}

const _planElementTexture = BATriangleTextureConfig(
  baseColor: Color(0xff263747),
  panelColor: AppColors.surfaceRaised,
  softColor: Color(0xff8295a6),
  accentColor: AppColors.primaryMuted,
  triangleSize: 76,
  tessellationContrast: 0.05,
  randomSeed: 7319,
  macroTriangleChance: 0.08,
  macroTriangleScale: 2.5,
  macroTriangleContrast: 0.035,
  lightStrength: 0.11,
  edgeVignetteStrength: 0.11,
  fogStrength: 0.06,
);
