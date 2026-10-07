import 'dart:math' as math;
import 'package:flutter/foundation.dart' show listEquals, setEquals;
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/ba_modal.dart';
import '../kit/diagonal_scrollbar.dart';
import '../kit/game_assets.dart';
import '../kit/hatch.dart';
import '../kit/kit_pressable.dart';
import '../kit/skew_box.dart';
import '../models/active_plan_bond_target.dart';
import '../models/growth_calculator_rules.dart';
import '../models/growth_calculator_state.dart';
import '../models/student_filter_controller.dart';
import '../models/student_filter_selection.dart';
import '../studio/section_template.dart';
import '../studio/student_studio_layout.dart';
import 'animated_section_stack.dart';
import 'asset_image_grid.dart';
import 'ba_triangle_background.dart';
import 'bond_rank_portrait.dart';
import 'growth_calculator_section.dart';
import 'lifted_path_shadow.dart';
import 'plan_student_step_tile.dart';
import 'scroll_viewport_fog.dart';
import 'section_surface.dart';
import 'section_template_surface.dart';
import 'student_filter_modal.dart';
import 'student_form_cycle.dart';
import 'student_portrait_status_overlay.dart';

const studentTextureTessellationContrast = 0.030;
const _studentTexture = BATriangleTextureConfig(
  baseColor: Color(0xff30485f),
  panelColor: Color(0xff36556f),
  softColor: Color(0xff3d607b),
  accentColor: Color(0xff71c7f4),
  triangleSize: 96,
  tessellationContrast: studentTextureTessellationContrast,
  randomSeed: 4187,
  macroTriangleChance: 0.055,
  macroTriangleContrast: 0.016,
  lightStrength: 0.1,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.07,
);

const _studentActionTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 112,
  tessellationContrast: 0.026,
  randomSeed: 2718,
  macroTriangleChance: 0.06,
  macroTriangleContrast: 0.018,
  lightStrength: 0.12,
  edgeVignetteStrength: 0.13,
  fogStrength: 0.08,
);

const studentSectionBevelGap = 12.0;
const studentSectionOpacity = sectionSurfaceOpacity;
const studentViewportFogExtent = scrollViewportFogExtent;
const studentSortAccentColor = Color(0xffe9b0ee);
const studentSortCompactFontSize = 15.0;
const studentSortMenuFontSize = 18.0;
const studentGridDisplayToggleFontSize = 16.5;
const studentSection2ContainerColor = Color(0xff162431);
const _studentSection1ControlInset = 0.06;
const _studentSection1ControlGap = 0.05;
const _studentSection1ControlLeft = 0.12;
const studentSection1Motion = SectionMotionSpec(intro: 0, outro: 180);
const studentSection3Motion = SectionMotionSpec(intro: 180, outro: 0);
const studentSection4Motion = SectionMotionSpec(intro: 180, outro: 0);

enum StudentGridSort {
  nameAscending('이름 ↑', '이름 · 오름차순'),
  nameDescending('이름 ↓', '이름 · 내림차순'),
  levelAscending('LV ↑', 'LV · 오름차순'),
  levelDescending('LV ↓', 'LV · 내림차순'),
  starAscending('성작 ↑', '성작 상태 · 오름차순'),
  starDescending('성작 ↓', '성작 상태 · 내림차순'),
  bondAscending('인연 ↑', '인연 랭크 · 오름차순'),
  bondDescending('인연 ↓', '인연 랭크 · 내림차순');

  const StudentGridSort(this.compactLabel, this.menuLabel);

  final String compactLabel;
  final String menuLabel;
}

enum StudentSection2View { list, grid }

Map<String, int> studentListTargetValues(
  StudentCatalogEntry student,
  Map<String, dynamic> currentValues, {
  required bool owned,
}) {
  int value(String key, int fallback) {
    final raw = currentValues[key];
    return raw is int ? raw : fallback;
  }

  int equipmentTier(String key) {
    final raw = currentValues[key];
    if (raw is int) return raw;
    final match = RegExp(r'(\d+)').firstMatch(raw?.toString() ?? '');
    return match == null ? 0 : int.parse(match.group(1)!);
  }

  int initialStar() {
    final match = RegExp(r'(\d+)').firstMatch(student.rarity ?? '');
    return match == null ? 1 : int.parse(match.group(1)!).clamp(1, 5);
  }

  return {
    'level': owned ? value('level', 1) : 1,
    'bond_rank': owned ? value('bond_rank', 1) : 1,
    'student_star': owned
        ? value('student_star', initialStar())
        : initialStar(),
    'weapon_level': owned ? value('weapon_level', 0) : 0,
    'weapon_star': owned ? value('weapon_star', 0) : 0,
    'ex_skill': owned ? value('ex_skill', 1) : 1,
    'skill1': owned ? value('skill1', 1) : 1,
    'skill2': owned ? value('skill2', 1) : 1,
    'skill3': owned ? value('skill3', 1) : 1,
    'equip1_tier': owned ? equipmentTier('equip1') : 0,
    'equip2_tier': owned ? equipmentTier('equip2') : 0,
    'equip3_tier': owned ? equipmentTier('equip3') : 0,
    'equip1_level': owned ? value('equip1_level', 0) : 0,
    'equip2_level': owned ? value('equip2_level', 0) : 0,
    'equip3_level': owned ? value('equip3_level', 0) : 0,
    'equip4_tier': owned ? equipmentTier('equip4') : 0,
    'stat_hp': owned ? value('stat_hp', 0) : 0,
    'stat_atk': owned ? value('stat_atk', 0) : 0,
    'stat_heal': owned ? value('stat_heal', 0) : 0,
  };
}

PlanStudentStepPreview studentListStepPreview(
  StudentCatalogEntry student,
  Map<String, dynamic> currentValues, {
  required bool owned,
}) {
  final targets = studentListTargetValues(student, currentValues, owned: owned);
  return PlanStudentStepPreview(
    studentId: student.studentId,
    displayName: student.displayName,
    step: 1,
    target: '현재 상태',
    bondRank: targets['bond_rank'],
    targetValues: targets,
  );
}

List<StudentCatalogEntry> sortStudentGridEntries(
  Iterable<StudentCatalogEntry> students,
  StudentGridSort sort,
  Map<String, Map<String, dynamic>> valuesById,
) {
  final result = students.toList(growable: false);
  final descending = switch (sort) {
    StudentGridSort.nameDescending ||
    StudentGridSort.levelDescending ||
    StudentGridSort.starDescending ||
    StudentGridSort.bondDescending => true,
    _ => false,
  };
  final numericKey = switch (sort) {
    StudentGridSort.levelAscending ||
    StudentGridSort.levelDescending => 'level',
    StudentGridSort.starAscending ||
    StudentGridSort.starDescending => 'student_star',
    StudentGridSort.bondAscending ||
    StudentGridSort.bondDescending => 'bond_rank',
    _ => null,
  };
  int byName(StudentCatalogEntry left, StudentCatalogEntry right) =>
      left.displayName.toLowerCase().compareTo(right.displayName.toLowerCase());

  result.sort((left, right) {
    if (numericKey == null) {
      final comparison = byName(left, right);
      return descending ? -comparison : comparison;
    }
    final leftValue = valuesById[left.studentId]?[numericKey];
    final rightValue = valuesById[right.studentId]?[numericKey];
    final leftNumber = leftValue is num ? leftValue : null;
    final rightNumber = rightValue is num ? rightValue : null;
    if (leftNumber == null || rightNumber == null) {
      if (leftNumber == null && rightNumber == null) return byName(left, right);
      return leftNumber == null ? 1 : -1;
    }
    final comparison = leftNumber.compareTo(rightNumber);
    if (comparison != 0) return descending ? -comparison : comparison;
    return byName(left, right);
  });
  return result;
}

@immutable
class StudentFilterDefinition {
  const StudentFilterDefinition({
    required this.key,
    required this.label,
    required this.read,
  });

  final String key;
  final String label;
  final String? Function(StudentCatalogEntry student) read;
}

final List<StudentFilterDefinition> studentFilterDefinitions = [
  StudentFilterDefinition(
    key: 'school',
    label: '학교',
    read: (student) => student.school,
  ),
  StudentFilterDefinition(
    key: 'rarity',
    label: '초기 성급',
    read: (student) => student.rarity,
  ),
  StudentFilterDefinition(
    key: 'attack_type',
    label: '공격 타입',
    read: (student) => student.attackType,
  ),
  StudentFilterDefinition(
    key: 'defense_type',
    label: '방어 타입',
    read: (student) => student.defenseType,
  ),
  StudentFilterDefinition(
    key: 'combat_class',
    label: '편성',
    read: (student) => student.combatClass,
  ),
  StudentFilterDefinition(
    key: 'role',
    label: '역할',
    read: (student) => student.role,
  ),
  StudentFilterDefinition(
    key: 'position',
    label: '포지션',
    read: (student) => student.position,
  ),
];

const Map<String, Map<String, String>> studentFilterValueLabels = {
  'ownership': {'owned': '보유', 'unowned': '미보유'},
  'plan_status': {'planned': '계획 포함', 'unplanned': '미계획'},
  'school': {
    'Abydos': '아비도스',
    'Arius': '아리우스',
    'ETC': '기타',
    'Etc': '기타',
    'Gehenna': '게헨나',
    'Highlander': '하이랜더',
    'Hyakkiyako': '백귀야행',
    'Millennium': '밀레니엄',
    'Red Winter': '붉은겨울',
    'RedWinter': '붉은겨울',
    'Shanhaijing': '산해경',
    'SRT': 'SRT',
    'Trinity': '트리니티',
    'Valkyrie': '발키리',
    'Wild Hunt': '와일드헌트',
    'Wildhunt': '와일드헌트',
  },
  'attack_type': {
    'Chemical': '화학',
    'Explosive': '폭발',
    'Mystic': '신비',
    'Piercing': '관통',
    'Sonic': '진동',
  },
  'defense_type': {
    'Composite': '복합장갑',
    'Elastic': '탄력장갑',
    'Heavy': '중장갑',
    'Light': '경장갑',
    'Special': '특수장갑',
  },
  'combat_class': {'special': '스페셜', 'striker': '스트라이커'},
  'role': {
    'dealer': '딜러',
    'healer': '힐러',
    'supporter': '서포터',
    't_s': '택티컬 서포트',
    'tanker': '탱커',
  },
  'position': {'back': '후열', 'front': '전열', 'middle': '중열'},
};

String studentFilterValueLabel(String key, String value) {
  if (key == 'rarity') return '$value성';
  return studentFilterValueLabels[key]?[value] ??
      value
          .replaceAll('_', ' ')
          .split(' ')
          .map((part) {
            if (part.isEmpty) return part;
            return '${part[0].toUpperCase()}${part.substring(1)}';
          })
          .join(' ');
}

double studentStarSegmentDepth(Rect rect) =>
    math.min(rect.width * 0.45, diagonalCutDepth(rect.height));

Path studentStarSegmentPath(Rect rect) {
  final depth = studentStarSegmentDepth(rect);
  return buildRoundedSectionPolygon([
    Offset(rect.left + depth, rect.top),
    rect.topRight,
    Offset(rect.right - depth, rect.bottom),
    rect.bottomLeft,
  ], radius: 3);
}

List<Rect> studentStarSegmentRects(Rect bounds) {
  final gap = math.max(1.2, bounds.width * 0.006);
  final segmentWidth = (bounds.width - gap * 8) / 9;
  return [
    for (var index = 0; index < 9; index++)
      Rect.fromLTWH(
        bounds.left + index * (segmentWidth + gap),
        bounds.top,
        segmentWidth,
        bounds.height,
      ),
  ];
}

void paintStudentStarStatus(
  Canvas canvas,
  Rect bounds, {
  required int studentStars,
  required int weaponStars,
  int? targetStudentStars,
  int? targetWeaponStars,
  bool studentTargetPropagated = false,
  bool weaponTargetPropagated = false,
}) {
  final rects = studentStarSegmentRects(bounds);
  for (var index = 0; index < rects.length; index++) {
    final studentSegment = index < 5;
    final localIndex = studentSegment ? index : index - 5;
    final currentValue = studentSegment ? studentStars : weaponStars;
    final targetValue = studentSegment ? targetStudentStars : targetWeaponStars;
    final activeColor = studentSegment
        ? AppColors.starDisplay
        : AppColors.primary;
    final path = studentStarSegmentPath(rects[index]);
    canvas.drawPath(
      path,
      Paint()
        ..isAntiAlias = true
        ..color = localIndex < currentValue
            ? activeColor.withValues(alpha: 0.86)
            : AppColors.outline.withValues(alpha: 0.48),
    );
    if (targetValue != null && localIndex < targetValue) {
      final propagated = studentSegment
          ? studentTargetPropagated
          : weaponTargetPropagated;
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..color = activeColor.withValues(alpha: propagated ? 0.62 : 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, math.min(2.2, bounds.height * 0.14))
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }
}

class StudentStarStatus extends StatelessWidget {
  const StudentStarStatus({
    super.key,
    required this.studentStars,
    required this.weaponStars,
    this.targetStudentStars,
    this.targetWeaponStars,
    this.studentTargetPropagated = false,
    this.weaponTargetPropagated = false,
  });

  final int studentStars;
  final int weaponStars;
  final int? targetStudentStars;
  final int? targetWeaponStars;
  final bool studentTargetPropagated;
  final bool weaponTargetPropagated;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey('student-star-status'),
    painter: _StudentStarStatusPainter(
      studentStars: studentStars,
      weaponStars: weaponStars,
      targetStudentStars: targetStudentStars,
      targetWeaponStars: targetWeaponStars,
      studentTargetPropagated: studentTargetPropagated,
      weaponTargetPropagated: weaponTargetPropagated,
    ),
    size: Size.infinite,
  );
}

class _StudentStarStatusPainter extends CustomPainter {
  const _StudentStarStatusPainter({
    required this.studentStars,
    required this.weaponStars,
    required this.targetStudentStars,
    required this.targetWeaponStars,
    required this.studentTargetPropagated,
    required this.weaponTargetPropagated,
  });

  final int studentStars;
  final int weaponStars;
  final int? targetStudentStars;
  final int? targetWeaponStars;
  final bool studentTargetPropagated;
  final bool weaponTargetPropagated;

  @override
  void paint(Canvas canvas, Size size) => paintStudentStarStatus(
    canvas,
    Offset.zero & size,
    studentStars: studentStars,
    weaponStars: weaponStars,
    targetStudentStars: targetStudentStars,
    targetWeaponStars: targetWeaponStars,
    studentTargetPropagated: studentTargetPropagated,
    weaponTargetPropagated: weaponTargetPropagated,
  );

  @override
  bool shouldRepaint(_StudentStarStatusPainter oldDelegate) =>
      oldDelegate.studentStars != studentStars ||
      oldDelegate.weaponStars != weaponStars ||
      oldDelegate.targetStudentStars != targetStudentStars ||
      oldDelegate.targetWeaponStars != targetWeaponStars ||
      oldDelegate.studentTargetPropagated != studentTargetPropagated ||
      oldDelegate.weaponTargetPropagated != weaponTargetPropagated;
}

Rect studentSectionRect(Size size, String id) {
  final element = studentStudioDocument.elements.firstWhere(
    (item) => item.id == id,
  );
  final rect = sectionCanvasElementRect(size, element);
  if (id != 'element-4') return rect;
  final detail = sectionCanvasElementRect(
    size,
    studentStudioDocument.elements.firstWhere((item) => item.id == 'element-3'),
  );
  final tangent = diagonalTan80;
  final left = detail.left + (detail.bottom - rect.bottom) / tangent;
  return Rect.fromLTRB(left, rect.top, rect.right, rect.bottom);
}

Path studentSectionPath(Size size, String id) {
  final element = studentStudioDocument.elements.firstWhere(
    (item) => item.id == id,
  );
  if (id != 'element-2' && id != 'element-4') {
    return buildSectionCanvasElementPath(size, element);
  }
  if (id == 'element-4') {
    final rect = studentSectionRect(size, id);
    final raw = buildRoundedSectionPolygon(
      buildAttachedSectionPolygon(
        rect.size,
        element.spec,
      ).map((point) => point + rect.topLeft).toList(growable: false),
    );
    final canvasBounds = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      );
    return Path.combine(PathOperation.intersect, raw, canvasBounds);
  }
  final actionSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-1',
  );
  final actionRect = sectionCanvasElementRect(size, actionSection);
  final rect = sectionCanvasElementRect(size, element);
  final depth = diagonalCutDepth(rect.height);
  final leftTop = actionRect.right + studentSectionBevelGap;
  final raw = buildRoundedSectionPolygon([
    Offset(leftTop, rect.top),
    Offset(rect.right + depth, rect.top),
    rect.bottomRight,
    Offset(leftTop - depth, rect.bottom),
  ]);
  final canvasBounds = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
    );
  return Path.combine(PathOperation.intersect, raw, canvasBounds);
}

double studentDiagonalRowHorizontalOffset({
  required double viewportHeight,
  required double rowTop,
  required double rowHeight,
  required double scrollOffset,
}) {
  final bottomViewportY = rowTop + rowHeight - scrollOffset;
  return diagonalRowTranslateOffset(
    viewportHeight: viewportHeight,
    rowBottomInViewport: bottomViewportY,
  );
}

double studentDiagonalFilterRowWidth({
  required double viewportWidth,
  required double viewportHeight,
  required double rowHeight,
  required double horizontalInset,
  required double scrollbarReserve,
}) {
  final tangent = diagonalTan80;
  return math.max(
    120.0,
    viewportWidth -
        horizontalInset * 2 -
        scrollbarReserve -
        (viewportHeight - rowHeight) / tangent,
  );
}

double studentFilterGroupContentInset(double height) =>
    diagonalCutDepth(height) + 8;

List<StudioContainerElement> studentRuntimeContainers(Size size) {
  final detailSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-3',
  );
  final detailRect = sectionCanvasElementRect(size, detailSection);
  final aspect = detailRect.height / detailRect.width;
  final source = studentStudioDocument.containers;
  final tangent = diagonalTan80;
  const stackIds = ['container-5', 'container-6', 'container-7', 'container-9'];
  final sourceById = {for (final item in source) item.id: item};
  final firstStackRect = sourceById[stackIds.first]!.rect;
  final secondStackRect = sourceById[stackIds[1]]!.rect;
  final stackGap = secondStackRect.top - firstStackRect.bottom;
  final stackRects = <String, StudioPlacementRect>{};
  var nextStackTop = firstStackRect.top;
  for (final id in stackIds) {
    final rect = sourceById[id]!.rect.copyWith(top: nextStackTop);
    stackRects[id] = rect;
    nextStackTop = rect.bottom + stackGap;
  }
  final anchor = stackRects[stackIds.first]!;
  double leftAt(double bottom) =>
      anchor.left - (bottom - anchor.bottom) * aspect / tangent;
  double rightAt(double bottom) =>
      anchor.right - (bottom - anchor.bottom) * aspect / tangent;

  final stackRightRail = anchor.right + anchor.bottom * aspect / tangent;
  final detailGapPixels = stackGap * detailRect.height;
  final c4Source = sourceById['container-4']!.rect;
  final c4RailGap =
      detailGapPixels / (detailRect.width * diagonalSin80);
  final c4Left =
      stackRightRail + c4RailGap - c4Source.bottom * aspect / tangent;
  final c4Rect = c4Source.copyWith(
    left: c4Left,
    width: c4Source.right - c4Left,
  );

  const actionInset = _studentSection1ControlInset;
  const actionGap = _studentSection1ControlGap;
  const actionLeft = _studentSection1ControlLeft;
  final actionRightInset = diagonalNormalInset(actionLeft);
  const actionIds = ['container-16', 'container-13', 'container-11'];
  final actionSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-1',
  );
  final actionSectionRect = sectionCanvasElementRect(size, actionSection);
  final searchContainer = sourceById['container-14']!;
  final searchSectionRect = studentSectionRect(size, 'element-4');
  final searchRect = studioPlacementRectWithin(
    searchSectionRect,
    searchContainer.rect,
  );
  final sortHeight = math.min(
    0.16,
    math.max(
      studioMinimumPlacementExtent,
      searchRect.height / actionSectionRect.height,
    ),
  );
  final actionHeight =
      (1 - actionInset * 2 - actionGap * 4 - sortHeight * 2) / 3;

  return [
    for (final container in source)
      if (actionIds.contains(container.id))
        () {
          final top =
              actionInset +
              sortHeight +
              actionGap +
              sortHeight +
              actionGap +
              actionIds.indexOf(container.id) * (actionHeight + actionGap);
          final sectionRect = actionSectionRect;
          final sectionAspect = sectionRect.height / sectionRect.width;
          final rightEdgeAtTop = 1 - top * sectionAspect / tangent;
          final width = rightEdgeAtTop - actionLeft - actionRightInset;
          return container.copyWith(
            rect: StudioPlacementRect(
              actionLeft,
              top,
              math.max(studioMinimumPlacementExtent, width),
              actionHeight,
            ),
          );
        }()
      else if (container.id == 'container-4')
        container.copyWith(rect: c4Rect)
      else if ({
        'container-1',
        'container-3',
        'container-5',
        'container-6',
        'container-7',
        'container-9',
      }.contains(container.id))
        () {
          final baseRect = stackRects[container.id] ?? container.rect;
          final left = leftAt(baseRect.bottom);
          final alignRight = stackIds.contains(container.id);
          return container.copyWith(
            rect: baseRect.copyWith(
              left: left,
              width: alignRight
                  ? rightAt(baseRect.bottom) - left
                  : baseRect.width,
            ),
          );
        }()
      else
        container,
  ];
}

StudioPlacementRect _studentSection1ControlRowPlacement(Size size, double top) {
  const actionLeft = _studentSection1ControlLeft;
  final tangent = diagonalTan80;
  final actionSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-1',
  );
  final sectionRect = sectionCanvasElementRect(size, actionSection);
  final containers = studentRuntimeContainers(size);
  final searchContainer = containers.firstWhere(
    (item) => item.id == 'container-14',
  );
  final searchRect = studioPlacementRectWithin(
    studentSectionRect(size, 'element-4'),
    searchContainer.rect,
  );
  final height = math.min(
    0.16,
    math.max(
      studioMinimumPlacementExtent,
      searchRect.height / sectionRect.height,
    ),
  );
  final rightInset = diagonalNormalInset(actionLeft);
  final sectionAspect = sectionRect.height / sectionRect.width;
  final rightEdgeAtTop = 1 - top * sectionAspect / tangent;
  return StudioPlacementRect(
    actionLeft,
    top,
    math.max(
      studioMinimumPlacementExtent,
      rightEdgeAtTop - actionLeft - rightInset,
    ),
    height,
  );
}

StudioPlacementRect studentSortDropdownPlacement(Size size) {
  final firstRow = _studentSection1ControlRowPlacement(
    size,
    _studentSection1ControlInset,
  );
  return _studentSection1ControlRowPlacement(
    size,
    firstRow.bottom + _studentSection1ControlGap,
  );
}

StudioPlacementRect studentViewTogglePlacement(Size size) {
  return _studentSection1ControlRowPlacement(
    size,
    _studentSection1ControlInset,
  );
}

List<Path> studentViewTogglePaths(Size size) {
  return [
    for (final polygon in studentViewTogglePolygons(size))
      buildRoundedSectionPolygon(
        polygon,
        radius: math.min(5, (polygon[3].dy - polygon[0].dy) * 0.18),
      ),
  ];
}

List<List<Offset>> studentViewTogglePolygons(Size size) {
  final actionSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-1',
  );
  final sectionRect = sectionCanvasElementRect(size, actionSection);
  final rowRect = studioPlacementRectWithin(
    sectionRect,
    studentViewTogglePlacement(size),
  );
  final sectionPath = studentSectionPath(size, 'element-1');
  final topSpan = _studentPathHorizontalSpan(sectionPath, rowRect.top + 0.001);
  final bottomSpan = _studentPathHorizontalSpan(
    sectionPath,
    rowRect.bottom - 0.001,
  );
  final rightInset =
      diagonalNormalInset(_studentSection1ControlLeft) *
      sectionRect.width;
  final rightTop = topSpan.right - rightInset;
  final rightBottom = bottomSpan.right - rightInset;
  final railShift = rightTop - rightBottom;
  final gap = math.min(6.0, (rightBottom - rowRect.left) * 0.12);
  final splitTop = rowRect.left + (rightTop - rowRect.left - gap) / 2;
  final splitBottom = splitTop - railShift;
  final gridLeftTop = splitTop + gap;
  final gridLeftBottom = splitBottom + gap;
  return [
    [
      rowRect.topLeft,
      Offset(splitTop, rowRect.top),
      Offset(splitBottom, rowRect.bottom),
      rowRect.bottomLeft,
    ],
    [
      Offset(gridLeftTop, rowRect.top),
      Offset(rightTop, rowRect.top),
      Offset(rightBottom, rowRect.bottom),
      Offset(gridLeftBottom, rowRect.bottom),
    ],
  ];
}

Path studentSortDropdownPath(Size size) {
  final actionSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-1',
  );
  final sectionRect = sectionCanvasElementRect(size, actionSection);
  final rect = studioPlacementRectWithin(
    sectionRect,
    studentSortDropdownPlacement(size),
  );
  final source = studentStudioDocument.containers.firstWhere(
    (item) => item.id == 'container-16',
  );
  final raw = buildRoundedSectionPolygon(
    buildAttachedSectionPolygon(
      rect.size,
      source.spec,
      gridSize: sectionTemplateDetailGridSize,
    ).map((point) => point + rect.topLeft).toList(growable: false),
    radius: 5,
  );
  return Path.combine(
    PathOperation.intersect,
    raw,
    studentSectionPath(size, 'element-1'),
  );
}

Path? studentContainerPath(Size size, String id) {
  final containers = studentRuntimeContainers(size);
  final container = containers.firstWhere((item) => item.id == id);
  final parentRect = studentSectionRect(size, container.parentSectionId);
  final rect = studioPlacementRectWithin(parentRect, container.rect);
  final localPoints = buildAttachedSectionPolygon(
    rect.size,
    container.spec,
    gridSize: sectionTemplateDetailGridSize,
  );
  final raw = buildRoundedSectionPolygon(
    localPoints.map((point) => point + rect.topLeft).toList(growable: false),
    radius: 10,
  );
  return Path.combine(
    PathOperation.intersect,
    raw,
    studentSectionPath(size, container.parentSectionId),
  );
}

Path? studentFeaturePath(Size size, String id) {
  final containers = studentRuntimeContainers(size);
  final feature = studentStudioDocument.features.firstWhere(
    (item) => item.id == id,
  );
  final raw = buildStudioFeatureRawPath(
    size,
    studentStudioDocument.elements,
    containers,
    feature,
  );
  final parent = studentContainerPath(size, feature.parentContainerId);
  if (raw == null || parent == null) return null;
  return Path.combine(PathOperation.intersect, raw, parent);
}

class StudentSectionLayout extends StatefulWidget {
  const StudentSectionLayout({
    super.key,
    required this.students,
    required this.ownedIds,
    required this.selectedId,
    this.selectedStudent,
    required this.selectedValues,
    this.studentValuesById = const {},
    this.plannedIds = const {},
    this.selectedBondTarget,
    this.filterController,
    this.totalStudentCount,
    this.recentStudents = const [],
    required this.searchController,
    required this.onSearchChanged,
    required this.onStudentSelected,
    required this.onAddToPlan,
    required this.onOpenScan,
    required this.onOpenFilter,
    this.onOpenCalculator,
    this.calculator,
    this.active = true,
  });

  final List<StudentCatalogEntry> students;
  final Set<String> ownedIds;
  final String? selectedId;
  final StudentCatalogEntry? selectedStudent;
  final Map<String, dynamic>? selectedValues;
  final Map<String, Map<String, dynamic>> studentValuesById;
  final Set<String> plannedIds;

  /// 선택 학생의 활성 계획 인연 목표(FD-049). 없으면 null. 보일지는 게이지가 정한다(FD-050).
  final int? selectedBondTarget;

  /// 필터 상태(FE3-c). 페이지가 소유하고 필터 모달에 주입한다(FD-104). 없으면 레이아웃이 자기 것을 만든다.
  final StudentFilterController? filterController;

  /// S4 결과 수 줄의 "전체" 수(검색 전 catalog 크기). 없으면 [students] 수.
  final int? totalStudentCount;

  /// S4 최근 본 학생(가장 최근이 앞, 최대 6명, FD-061).
  final List<StudentCatalogEntry> recentStudents;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStudentSelected;
  final VoidCallback? onAddToPlan;
  final VoidCallback? onOpenScan;
  /// 필터 모달을 연 뒤 알린다(S1 필터 버튼 · S4 "+n" 칩).
  final VoidCallback? onOpenFilter;

  /// S1 "성장 계산기 열기"(FD-160 (a), 예전 "포커스 학생으로 계획 열기" 자리).
  final VoidCallback? onOpenCalculator;

  /// 성장 계산기 모드(FE3-f2a). 있으면 S1 버튼 세트와 S2 본문을 계산기로 바꾼다. S3·S4는 f2b에서 바꾼다.
  final GrowthCalculatorModeData? calculator;
  final bool active;

  @override
  State<StudentSectionLayout> createState() => _StudentSectionLayoutState();
}

class _StudentSectionLayoutState extends State<StudentSectionLayout>
    with TickerProviderStateMixin {
  static const _motionDuration = AppMotion.section;
  late final AnimationController _section1Controller;
  late final AnimationController _listController;
  late final AnimationController _section3Controller;
  late final AnimationController _section4Controller;
  final _filterModal = BaModalController();
  bool _switchingListSection = false;
  bool _showStudentAttributes = true;
  bool _showStudentNames = true;
  StudentSection2View _section2View = StudentSection2View.grid;
  StudentGridSort _gridSort = StudentGridSort.nameAscending;
  StudentFilterController? _ownFilter;
  String? _revealStudentId;
  int _revealRequest = 0;
  List<StudentFilterCandidate>? _candidates;

  StudentFilterController get _filter =>
      widget.filterController ?? (_ownFilter ??= StudentFilterController());

  void _filterChanged() {
    if (mounted) setState(() {});
  }

  /// 필터를 거는 학생들(속성 + 보유 + 현재 성장 값). 학생·보유·현재 값이 바뀔 때만 다시 만든다.
  List<StudentFilterCandidate> get _filterCandidates =>
      _candidates ??= [
        for (final student in widget.students)
          StudentFilterCandidate.fromValues(
            student: student,
            owned: widget.ownedIds.contains(student.studentId),
            currentValues:
                widget.studentValuesById[student.studentId] ?? const {},
          ),
      ];

  /// 페이지는 빌드마다 새 목록을 넘기므로 내용으로 비교한다(학생 값 맵은 같은 객체인지만 본다).
  static bool _sameFilterInputs(StudentSectionLayout a, StudentSectionLayout b) {
    if (!listEquals(a.students, b.students) ||
        !setEquals(a.ownedIds, b.ownedIds) ||
        a.studentValuesById.length != b.studentValuesById.length) {
      return false;
    }
    for (final entry in a.studentValuesById.entries) {
      if (!identical(b.studentValuesById[entry.key], entry.value)) return false;
    }
    return true;
  }

  /// 필터 모달을 연다(S1 필터 버튼 · S4 "+n" 칩). 적용 값을 초안으로 복사한다.
  void _openFilterModal() {
    if (_filterModal.isOpen) return;
    _filter.beginEdit();
    _filterModal.open();
    widget.onOpenFilter?.call();
  }

  /// "적용": 초안을 그리드에 걸고 닫는다.
  void _applyFilterModal() {
    _filter.applyDraft();
    _filterModal.close();
  }

  /// 모달이 닫히면(닫기 · Esc · 스크림) 적용하지 않은 초안을 버린다.
  void _filterModalChanged() {
    if (!_filterModal.isOpen) _filter.discardDraft();
    if (mounted) setState(() {});
  }

  /// 최근 본 학생 썸네일: 그 학생을 고르고 그리드를 그 학생까지 스크롤한다(FD-061).
  void _openRecentStudent(String studentId) {
    setState(() {
      _revealStudentId = studentId;
      _revealRequest += 1;
    });
    widget.onStudentSelected(studentId);
  }

  @override
  void initState() {
    super.initState();
    _filter.addListener(_filterChanged);
    _filterModal.addListener(_filterModalChanged);
    _section1Controller = _controller();
    _listController = _controller();
    _section3Controller = _controller();
    _section4Controller = _controller();
    if (widget.active) _setTabSectionsActive(true);
  }

  AnimationController _controller() => AnimationController(
    vsync: this,
    duration: _motionDuration,
    reverseDuration: _motionDuration,
  );

  @override
  void didUpdateWidget(StudentSectionLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filterController != widget.filterController) {
      (oldWidget.filterController ?? _ownFilter)?.removeListener(
        _filterChanged,
      );
      _filter.addListener(_filterChanged);
    }
    if (!_sameFilterInputs(oldWidget, widget)) _candidates = null;
    // 계산기 모드를 열고 닫을 때 S1·S2 내용이 바뀌므로 그 두 섹션만 다시 들어온다.
    if (widget.active &&
        (oldWidget.calculator == null) != (widget.calculator == null)) {
      _section1Controller.forward(from: 0);
      _listController.forward(from: 0);
    }
    if (oldWidget.active != widget.active) {
      _setTabSectionsActive(widget.active);
      // 탭을 떠나면 열린 필터 모달을 닫는다(초안은 버린다). 숨은 탭이 모달 자리를 의미 구조에서 빼기 전에.
      if (!widget.active && _filterModal.isOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _filterModal.close();
        });
      }
    }
  }

  void _setTabSectionsActive(bool active) {
    for (final controller in [
      _section1Controller,
      _listController,
      _section3Controller,
      _section4Controller,
    ]) {
      if (active) {
        controller.forward(from: 0);
      } else {
        controller.reverse(from: 1);
      }
    }
  }

  @override
  void dispose() {
    _filter.removeListener(_filterChanged);
    _filterModal.removeListener(_filterModalChanged);
    _filterModal.dispose();
    _ownFilter?.dispose();
    _section1Controller.dispose();
    _listController.dispose();
    _section3Controller.dispose();
    _section4Controller.dispose();
    super.dispose();
  }

  Future<void> _switchSection2View(StudentSection2View nextView) async {
    if (_switchingListSection || nextView == _section2View) return;
    setState(() => _switchingListSection = true);
    try {
      // 계산기 모드를 열고 닫을 때 S2를 다시 들이면(forward(from: 0)) 이 애니메이션이 끊긴다. orCancel로
      // 끊김을 받아야 아래 finally가 전환 표시를 푼다.
      await _listController.reverse().orCancel;
      if (!mounted) return;
      setState(() => _section2View = nextView);
      await _listController.forward().orCancel;
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) setState(() => _switchingListSection = false);
    }
  }

  /// S4 아래쪽 확장(FE3-c, W-Student-Search): 구분선, 결과 수, 적용 필터 칩, 최근 본 학생.
  /// 각 줄 왼쪽은 S4 왼쪽 80° 변을 따라 줄 밑변 높이에서 22px 안쪽, 오른쪽은 검색 상자 오른쪽이다.
  /// S4 높이를 넘는 줄은 그리지 않는다(작은 창에서 축소하지 않는다).
  List<Widget> _section4Extension({
    required Size size,
    required Rect searchBounds,
    required int shownCount,
  }) {
    final section = studentSectionRect(size, 'element-4');
    final right = searchBounds.right;
    double leftAt(double bottom) =>
        section.left +
        (section.bottom - bottom) / diagonalTan80 +
        studentSearchRowRailInset;
    final limit = section.bottom - studentSearchRowBottomMargin;
    final rows = <Widget>[];
    var top =
        searchBounds.bottom +
        studentSearchToggleTopGap +
        studentSearchToggleRowHeight * 4 +
        studentSearchDividerGap;

    void add(double height, double gapAfter, Widget Function(Rect) builder) {
      final rect = Rect.fromLTRB(
        leftAt(top + height),
        top,
        right,
        top + height,
      );
      top = rect.bottom + gapAfter;
      if (rect.bottom > limit || rect.width <= 0) return;
      rows.add(Positioned.fromRect(rect: rect, child: builder(rect)));
    }

    final filter = _filter;
    add(
      studentSearchDividerHeight,
      studentSearchDividerGap - studentSearchDividerHeight,
      (_) => const ColoredBox(
        key: ValueKey('student-search-divider'),
        color: studentSearchDividerColor,
      ),
    );
    add(
      studentSearchCountRowHeight,
      studentSearchCountRowGap,
      (_) => StudentResultCountRow(
        key: const ValueKey('student-result-count'),
        shown: shownCount,
        total: widget.totalStudentCount ?? widget.students.length,
        owned: widget.ownedIds.length,
        planned: widget.plannedIds.length,
      ),
    );
    add(
      studentSearchChipRowHeight,
      studentSearchChipRowGap,
      (_) => StudentAppliedFilterRow(
        key: const ValueKey('student-applied-filters'),
        filters: filter.searchRowChips,
        onRemove: filter.removeApplied,
        onClearAll: filter.clearApplied,
        onShowMore: _openFilterModal,
      ),
    );
    add(
      studentSearchRecentLabelHeight,
      studentSearchRecentLabelGap,
      (_) => const Align(
        key: ValueKey('student-recent-label'),
        alignment: Alignment.centerLeft,
        child: Text(
          '최근 본 학생',
          maxLines: 1,
          style: studentSearchLabelStyle,
        ),
      ),
    );
    add(
      studentRecentThumbSize.height,
      0,
      (_) => StudentRecentStrip(
        key: const ValueKey('student-recent-strip'),
        students: widget.recentStudents,
        selectedId: widget.selectedId,
        onSelected: _openRecentStudent,
      ),
    );
    return rows;
  }

  /// 계산기 S1 버튼 세트(Calc-Student, 학생 S1과 같은 자리):
  /// 보기 토글 → 확정값 기준/직접 입력(FD-168), 정렬 → 빠른 목표(FD-169), 계획 열기 → 이 목표로 계획에 추가
  /// (FE4-g 전 비활성), 학생 스캔 → 학생 스캔으로 현재값 갱신, 필터 → 현재값으로 되돌리기.
  List<Widget> _calculatorRail(Size size, GrowthCalculatorModeData calculator) {
    final state = calculator.state;
    final paths = studentViewTogglePaths(size);
    return [
      _StudentViewModeButton(
        path: paths[0],
        buttonKey: const ValueKey('calculator-basis-confirmed'),
        tooltip: '확정값 기준',
        icon: Icons.fact_check_outlined,
        selected: state.basis == GrowthCalculatorBasis.confirmed,
        onTap: () => state.setBasis(GrowthCalculatorBasis.confirmed),
      ),
      _StudentViewModeButton(
        path: paths[1],
        buttonKey: const ValueKey('calculator-basis-direct'),
        tooltip: '직접 입력',
        icon: Icons.edit_note_rounded,
        selected: state.basis == GrowthCalculatorBasis.direct,
        onTap: () => state.setBasis(GrowthCalculatorBasis.direct),
      ),
      _CalculatorQuickTargetDropdown(
        canvasSize: size,
        onSelected: state.applyQuickTarget,
      ),
      _StudentActionButton(
        canvasSize: size,
        containerId: 'container-16',
        key: const ValueKey('calculator-add-to-plan'),
        tooltip: '이 목표로 계획에 추가',
        icon: Icons.playlist_add_rounded,
        onPressed: calculator.onAddToPlan,
      ),
      _StudentActionButton(
        canvasSize: size,
        containerId: 'container-13',
        key: const ValueKey('calculator-open-scan'),
        tooltip: '학생 스캔으로 현재값 갱신',
        icon: Icons.document_scanner_outlined,
        onPressed: calculator.onOpenScan,
      ),
      _StudentActionButton(
        canvasSize: size,
        containerId: 'container-11',
        key: const ValueKey('calculator-revert-all'),
        tooltip: '현재값으로 되돌리기',
        icon: Icons.restart_alt_rounded,
        onPressed: state.cellCounts.changing == 0 ? null : state.resetToCurrent,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => BaModal(
    controller: _filterModal,
    scrim: BaScrim.filter,
    label: '필터',
    builder: (context) {
      final filter = _filter;
      return StudentFilterModal(
        key: const ValueKey('student-filter-modal'),
        selection: filter.draft ?? filter.applied,
        onChanged: filter.updateDraft,
        candidates: _filterCandidates,
        groups: filter.groups,
        totalCount: widget.totalStudentCount ?? widget.students.length,
        onApply: _applyFilterModal,
        onReset: filter.resetDraft,
        onClose: _filterModal.close,
      );
    },
    child: _buildLayout(),
  );

  Widget _buildLayout() => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.maxHeight.isFinite ? constraints.maxHeight : 660,
      );
      Rect containerBounds(String id) {
        return studentContainerPath(size, id)!.getBounds();
      }

      final listBounds = containerBounds('container-12');
      final portraitBounds = containerBounds('container-1');
      final searchBounds = containerBounds('container-14');
      final selectedStudent =
          widget.selectedStudent ??
          widget.students.cast<StudentCatalogEntry?>().firstWhere(
            (student) => student?.studentId == widget.selectedId,
            orElse: () => null,
          );
      final filter = _filter;
      final calculator = widget.calculator;
      final filteredGridStudents = [
        for (final candidate in _filterCandidates)
          if (filter.matches(candidate)) candidate.student,
      ];
      final gridStudents = sortStudentGridEntries(
        filteredGridStudents,
        _gridSort,
        widget.studentValuesById,
      );

      return SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: StudentSectionMotion(
                key: const ValueKey('student-section-2-motion'),
                animation: _listController,
                introDegrees: 80,
                outroDegrees: 260,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: CustomPaint(
                        key: const ValueKey('student-section-2-foundation'),
                        painter: _StudentSectionFoundationPainter(
                          selectedValues: widget.selectedValues,
                          sectionIds: const {'element-2'},
                          bare: calculator != null,
                        ),
                      ),
                    ),
                    if (calculator != null)
                      Positioned.fill(
                        child: GrowthCalculatorSection(
                          key: const ValueKey('growth-calculator-section'),
                          canvasSize: size,
                          state: calculator.state,
                          engine: calculator.engine,
                          student: calculator.student,
                          onAddToPlan: calculator.onAddToPlan,
                        ),
                      )
                    else
                    Positioned.fromRect(
                      rect: listBounds,
                      child: ClipPath(
                        clipper: _ContainerBoundsClipper(
                          'container-12',
                          size,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_section2View == StudentSection2View.grid)
                              StudentDiagonalGrid(
                                key: const ValueKey(
                                  'student-section-2-grid-view',
                                ),
                                students: gridStudents,
                                ownedIds: widget.ownedIds,
                                studentValuesById: widget.studentValuesById,
                                plannedIds: widget.plannedIds,
                                selectedId: widget.selectedId,
                                showAttributes: _showStudentAttributes,
                                showNames: _showStudentNames,
                                onSelected: widget.onStudentSelected,
                                revealStudentId: _revealStudentId,
                                revealRequest: _revealRequest,
                              )
                            else
                              StudentDiagonalList(
                                key: const ValueKey(
                                  'student-section-2-list-view',
                                ),
                                students: gridStudents,
                                ownedIds: widget.ownedIds,
                                studentValuesById: widget.studentValuesById,
                                selectedId: widget.selectedId,
                                onSelected: widget.onStudentSelected,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: StudentSectionMotion(
                key: const ValueKey('student-section-4-motion'),
                animation: _section4Controller,
                introDegrees: studentSection4Motion.intro,
                outroDegrees: studentSection4Motion.outro,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: CustomPaint(
                        key: const ValueKey('student-section-4-foundation'),
                        painter: _StudentSectionFoundationPainter(
                          selectedValues: null,
                          sectionIds: {'element-4'},
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: searchBounds,
                      child: ClipPath(
                        clipper: _ContainerBoundsClipper('container-14', size),
                        child: TextField(
                          key: const ValueKey('student-search'),
                          controller: widget.searchController,
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: '학생 이름 검색',
                            filled: false,
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.only(left: 14),
                            suffixIcon: Icon(Icons.search_rounded, size: 19),
                            suffixIconConstraints: BoxConstraints(
                              minWidth: 34,
                              minHeight: 0,
                            ),
                          ),
                          onChanged: widget.onSearchChanged,
                        ),
                      ),
                    ),
                    Positioned(
                      left: searchBounds.left,
                      top: searchBounds.bottom + 6,
                      width: searchBounds.width,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StudentGridDisplayToggle(
                            key: const ValueKey(
                              'student-toggle-attribute-display',
                            ),
                            label: '학생 공격/방어 속성 표시',
                            value: _showStudentAttributes,
                            onChanged: (value) =>
                                setState(() => _showStudentAttributes = value),
                          ),
                          _StudentGridDisplayToggle(
                            key: const ValueKey('student-toggle-name-display'),
                            label: '학생 이름 표시',
                            value: _showStudentNames,
                            onChanged: (value) =>
                                setState(() => _showStudentNames = value),
                          ),
                          _StudentGridDisplayToggle(
                            key: const ValueKey('student-toggle-hide-unowned'),
                            label: '미보유 학생 숨김',
                            value: filter.hideUnowned,
                            onChanged: (value) => filter.hideUnowned = value,
                          ),
                          _StudentGridDisplayToggle(
                            key: const ValueKey('student-toggle-hide-jp-only'),
                            label: '일본 서버 전용 숨김',
                            value: filter.hideJpOnly,
                            onChanged: (value) => filter.hideJpOnly = value,
                          ),
                        ],
                      ),
                    ),
                    ..._section4Extension(
                      size: size,
                      searchBounds: searchBounds,
                      shownCount: gridStudents.length,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: StudentSectionMotion(
                key: const ValueKey('student-section-3-motion'),
                animation: _section3Controller,
                introDegrees: studentSection3Motion.intro,
                outroDegrees: studentSection3Motion.outro,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: CustomPaint(
                        key: const ValueKey('student-section-3-foundation'),
                        painter: _StudentSectionFoundationPainter(
                          selectedValues: widget.selectedValues,
                          sectionIds: {'element-3'},
                        ),
                      ),
                    ),
                    Positioned.fromRect(
                      rect: portraitBounds,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          // 선택 카드도 다중 폼이면 공용 시계로 교대한다(FD-064).
                          StudentFormCycleBuilder(
                            active: selectedStudent?.isMultiForm ?? false,
                            builder: (context, formStep) => AssetImageGrid(
                              key: const ValueKey('student-focused-portrait'),
                              items: [
                                AssetImageGridItem(
                                  asset: bondRankPortraitBackgroundAsset(
                                    widget.selectedValues?['bond_rank'] as int?,
                                  ),
                                  column: 0,
                                  row: 0,
                                  edgeCropFraction: 0.11,
                                  clipPathBuilder: studentGridCardPath,
                                ),
                                if (widget.selectedId != null)
                                  AssetImageGridItem(
                                    asset: selectedStudent == null
                                        ? 'assets/student_portraits/${widget.selectedId}.png'
                                        : studentPortraitAssetAt(
                                            selectedStudent,
                                            formStep,
                                          ),
                                    column: 0,
                                    row: 0,
                                    scale: 0.98,
                                    clipRadiusFraction: 0.12,
                                    alphaThreshold: 0.04,
                                  ),
                              ],
                            ),
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                key: const ValueKey(
                                  'student-focused-portrait-status',
                                ),
                                painter: StudentGridCardOverlayPainter(
                                  students: [?selectedStudent],
                                  ownedIds: widget.ownedIds,
                                  columns: 1,
                                  rows: 1,
                                  columnGap: 0,
                                  rowGap: 0,
                                  rowHorizontalOffsets: const [0],
                                  contentPadding: EdgeInsets.zero,
                                  showAttributes: false,
                                  showNames: false,
                                  selectedIndex: null,
                                  plannedIds: widget.plannedIds,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StudentStatusIndicators(
                      canvasSize: size,
                      student: selectedStudent,
                      values: widget.selectedValues,
                      bondTarget: widget.selectedBondTarget,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: StudentSectionMotion(
                key: const ValueKey('student-section-1-motion'),
                animation: _section1Controller,
                introDegrees: studentSection1Motion.intro,
                outroDegrees: studentSection1Motion.outro,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: CustomPaint(
                        key: const ValueKey('student-section-1-foundation'),
                        painter: _StudentSectionFoundationPainter(
                          selectedValues: null,
                          sectionIds: {'element-1'},
                        ),
                      ),
                    ),
                    if (calculator != null)
                      ListenableBuilder(
                        listenable: calculator.state,
                        builder: (context, _) => Stack(
                          fit: StackFit.expand,
                          children: _calculatorRail(size, calculator),
                        ),
                      )
                    else ...[
                    _StudentActionButton(
                      canvasSize: size,
                      containerId: 'container-16',
                      key: const ValueKey('student-open-calculator'),
                      tooltip: '성장 계산기 열기',
                      icon: Icons.calculate_outlined,
                      onPressed: widget.selectedId == null
                          ? null
                          : widget.onOpenCalculator,
                    ),
                    _StudentActionButton(
                      canvasSize: size,
                      containerId: 'container-13',
                      key: const ValueKey('student-open-scan'),
                      tooltip: '학생 스캔 열기',
                      icon: Icons.document_scanner_outlined,
                      onPressed: widget.onOpenScan,
                    ),
                    _StudentActionButton(
                      canvasSize: size,
                      containerId: 'container-11',
                      key: const ValueKey('student-open-filter'),
                      tooltip: '필터 열기',
                      icon: Icons.tune_rounded,
                      // "필터 · n" 배지(FD-058): 모달이 닫혀 있고 조건이 걸려 있을 때. 열려 있으면 모달이 시안
                      // 위치에 같은 배지를 그린다.
                      badgeCount: _filterModal.isOpen || filter.activeCount == 0
                          ? null
                          : filter.activeCount,
                      onPressed: _openFilterModal,
                    ),
                    _StudentSortDropdown(
                      canvasSize: size,
                      value: _gridSort,
                      onChanged: (value) => setState(() => _gridSort = value),
                    ),
                    _StudentViewModeButtons(
                      canvasSize: size,
                      value: _section2View,
                      onChanged: _switchSection2View,
                    ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _StudentGridDisplayToggle extends StatelessWidget {
  const _StudentGridDisplayToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => onChanged(!value),
      child: SizedBox(
        height: 27,
        child: Row(
          children: [
            SizedBox(
              width: 25,
              child: Transform.scale(
                scale: 0.72,
                child: IgnorePointer(
                  child: Checkbox(value: value, onChanged: (_) {}),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: studentGridDisplayToggleFontSize,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// --- S4 확장(FE3-c, W-Student-Search) ------------------------------------------
// 시안 값(기준 viewport): 토글 4줄(27) 아래 6 → 구분선 1(#71c7f4@.28, 구분선 위끝에서 6) → 결과 수 줄 24 → 8 →
// 적용 필터 줄 26 → 10 → "최근 본 학생" 20 → 2 → 썸네일 50×40.5(간격 5). 줄 왼쪽은 S4 왼쪽 80° 변에서
// 줄 밑변 높이 기준 22px 안쪽, 오른쪽 끝은 검색 상자 오른쪽.

const studentSearchToggleTopGap = 6.0;
const studentSearchToggleRowHeight = 27.0;
const studentSearchDividerGap = 6.0;
const studentSearchDividerHeight = 1.0;
const studentSearchCountRowHeight = 24.0;
const studentSearchCountRowGap = 8.0;
const studentSearchChipRowHeight = 26.0;
const studentSearchChipRowGap = 10.0;
const studentSearchRecentLabelHeight = 20.0;
const studentSearchRecentLabelGap = 2.0;
const studentSearchRowRailInset = 22.0;
const studentSearchRowBottomMargin = 4.0;
const studentSearchDividerColor = Color.fromRGBO(113, 199, 244, 0.28);
const studentRecentThumbSize = Size(50, 40.5);
const studentRecentThumbGap = 5.0;
const studentSearchLabelStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  color: AppColors.textMuted,
  fontSize: AppType.bodySmallSize,
  height: 1.2,
);

/// 적용 필터 칩 색(시안 `rgba(233,176,238,.12)` 바탕 + `#e9b0ee` 글자).
const studentAppliedFilterTone = AppTone(
  base: studentSortAccentColor,
  backgroundAlpha: 0.12,
  foreground: studentSortAccentColor,
);

/// 결과 수 줄: "표시 48 / 전체 170 · 보유 128 · 계획 중 8".
class StudentResultCountRow extends StatelessWidget {
  const StudentResultCountRow({
    super.key,
    required this.shown,
    required this.total,
    required this.owned,
    required this.planned,
  });

  final int shown;
  final int total;
  final int owned;
  final int planned;

  static String detail({
    required int total,
    required int owned,
    required int planned,
  }) => '/ 전체 $total · 보유 $owned · 계획 중 $planned';

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '표시',
        style: studentSearchLabelStyle.copyWith(fontSize: AppType.bodySize),
      ),
      const SizedBox(width: 8),
      Text(
        '$shown',
        key: const ValueKey('student-result-count-shown'),
        style: const TextStyle(
          fontFamily: AppFonts.display,
          fontFamilyFallback: AppFonts.fallback,
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          detail(total: total, owned: owned, planned: planned),
          key: const ValueKey('student-result-count-detail'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: studentSearchLabelStyle.copyWith(fontSize: AppType.bodySize),
        ),
      ),
    ],
  );
}

/// 칩이 한 줄에 몇 개 들어가는지(넘치면 "+n" 칩 자리를 남긴다, FD-060).
/// [chipWidths]는 칩 폭, [gap]은 칩 사이, [moreWidth]는 "+n" 칩 폭이다.
int studentVisibleChipCount({
  required List<double> chipWidths,
  required double maxWidth,
  required double gap,
  required double Function(int hidden) moreWidth,
}) {
  var used = 0.0;
  for (var index = 0; index < chipWidths.length; index++) {
    final next = used + (index == 0 ? 0 : gap) + chipWidths[index];
    final hiddenAfter = chipWidths.length - index - 1;
    final reserve = hiddenAfter == 0 ? 0.0 : gap + moreWidth(hiddenAfter);
    if (next + reserve > maxWidth) return index;
    used = next;
  }
  return chipWidths.length;
}

/// [label] 제거형 [BaChip]의 폭(테두리 변형: 가로 여백 9 + 글자 + 5 + × 11 + 9).
double studentRemovableChipWidth(String label, TextScaler scaler) =>
    BaChip.widthFor(
      label,
      textScaler: scaler,
      removable: true,
      shape: BaChipShape.outlined,
    );

/// "+n"처럼 × 없는 [BaChip]의 폭.
double studentPlainChipWidth(String label, TextScaler scaler) =>
    BaChip.widthFor(label, textScaler: scaler, shape: BaChipShape.outlined);

/// 적용 필터 줄: "적용 필터" · 칩(×) 한 줄 + "+n" · "모두 지우기"(FD-060).
class StudentAppliedFilterRow extends StatelessWidget {
  const StudentAppliedFilterRow({
    super.key,
    required this.filters,
    required this.onRemove,
    required this.onClearAll,
    this.onShowMore,
  });

  final List<StudentFilterChipItem> filters;
  final ValueChanged<StudentFilterChipItem> onRemove;
  final VoidCallback onClearAll;

  /// "+n" 칩을 누르면(필터 모달을 연다, FE3-d2).
  final VoidCallback? onShowMore;

  static const chipGap = 8.0;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Text('적용 필터', maxLines: 1, style: studentSearchLabelStyle),
      const SizedBox(width: 8),
      Expanded(
        child: filters.isEmpty
            ? Text(
                '없음',
                key: const ValueKey('student-applied-filter-empty'),
                maxLines: 1,
                style: studentSearchLabelStyle.copyWith(
                  color: AppColors.textDim,
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final scaler = MediaQuery.textScalerOf(context);
                  final visible = studentVisibleChipCount(
                    chipWidths: [
                      for (final filter in filters)
                        studentRemovableChipWidth(filter.label, scaler),
                    ],
                    maxWidth: constraints.maxWidth,
                    gap: chipGap,
                    moreWidth: (hidden) =>
                        studentPlainChipWidth('+$hidden', scaler),
                  );
                  final hidden = filters.length - visible;
                  return ClipRect(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Row(
                        children: [
                          for (var index = 0; index < visible; index++) ...[
                            if (index > 0) const SizedBox(width: chipGap),
                            BaChip(
                              key: ValueKey(
                                'student-applied-filter-${filters[index].id}',
                              ),
                              label: filters[index].label,
                              tone: studentAppliedFilterTone,
                              shape: BaChipShape.outlined,
                              onRemove: () => onRemove(filters[index]),
                            ),
                          ],
                          if (hidden > 0) ...[
                            if (visible > 0) const SizedBox(width: chipGap),
                            KitPressable(
                              key: const ValueKey(
                                'student-applied-filter-more',
                              ),
                              onPressed: onShowMore,
                              semanticLabel: '적용 필터 $hidden개 더 보기',
                              builder: (context, state) => ExcludeSemantics(
                                child: BaChip(
                                  label: '+$hidden',
                                  tone: AppTones.gray,
                                  shape: BaChipShape.outlined,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      if (filters.isNotEmpty) ...[
        const SizedBox(width: 8),
        TextButton(
          key: const ValueKey('student-filter-clear-all'),
          onPressed: onClearAll,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(
              fontFamily: AppFonts.body,
              fontSize: AppType.bodySmallSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('모두 지우기'),
        ),
      ],
    ],
  );
}

/// 최근 본 학생 줄: 50×40.5 카드 썸네일, 간격 5, 지금 선택은 핑크 외곽선(FD-061).
class StudentRecentStrip extends StatelessWidget {
  const StudentRecentStrip({
    super.key,
    required this.students,
    required this.selectedId,
    required this.onSelected,
  });

  final List<StudentCatalogEntry> students;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  /// [width]에 들어가는 썸네일 수(넘치는 썸네일은 그리지 않는다).
  static int fittingCount(double width) => math.max(
    0,
    ((width + studentRecentThumbGap) /
            (studentRecentThumbSize.width + studentRecentThumbGap))
        .floor(),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = math.min(
        students.length,
        fittingCount(constraints.maxWidth),
      );
      return Row(
        children: [
          for (var index = 0; index < count; index++) ...[
            if (index > 0) const SizedBox(width: studentRecentThumbGap),
            StudentRecentThumb(
              key: ValueKey('student-recent-${students[index].studentId}'),
              student: students[index],
              selected: students[index].studentId == selectedId,
              onTap: () => onSelected(students[index].studentId),
            ),
          ],
        ],
      );
    },
  );
}

/// 최근 본 학생 썸네일 하나(그리드 카드와 같은 경로·배경·초상).
class StudentRecentThumb extends StatelessWidget {
  const StudentRecentThumb({
    super.key,
    required this.student,
    required this.selected,
    required this.onTap,
  });

  final StudentCatalogEntry student;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '최근 본 학생 ${student.displayName}',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.fromSize(
        size: studentRecentThumbSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            StudentFormCycleBuilder(
              active: student.isMultiForm,
              builder: (context, formStep) => AssetImageGrid(
                items: [
                  AssetImageGridItem(
                    asset: bondRankPortraitBackgroundAsset(null),
                    column: 0,
                    row: 0,
                    edgeCropFraction: 0.11,
                    clipPathBuilder: studentGridCardPath,
                  ),
                  AssetImageGridItem(
                    asset: studentPortraitAssetAt(student, formStep),
                    column: 0,
                    row: 0,
                    scale: 0.98,
                    clipRadiusFraction: 0.12,
                    alphaThreshold: 0.04,
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                painter: _StudentRecentThumbOutlinePainter(selected: selected),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StudentRecentThumbOutlinePainter extends CustomPainter {
  const _StudentRecentThumbOutlinePainter({required this.selected});

  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      studentGridCardPath(studentGridCardFittedRect(Offset.zero & size)),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = selected ? 1.6 : 1
        ..color = selected
            ? studentGridCardSelectionColor
            : Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_StudentRecentThumbOutlinePainter oldDelegate) =>
      oldDelegate.selected != selected;
}

class StudentSectionMotion extends StatelessWidget {
  const StudentSectionMotion({
    super.key,
    required this.animation,
    required this.introDegrees,
    required this.outroDegrees,
    required this.child,
  });

  final Animation<double> animation;
  final double introDegrees;
  final double outroDegrees;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(
      (((introDegrees - outroDegrees).abs() % 360) - 180).abs() < 0.001,
      'Intro and outro must be opposite directions on one trajectory.',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            return Transform.translate(
              key: key == null ? null : ValueKey('$key-transform'),
              offset: studentSectionMotionTranslation(
                size: size,
                introDegrees: introDegrees,
                outroDegrees: outroDegrees,
                progress: animation.value,
                exiting: animation.status == AnimationStatus.reverse,
              ),
              child: child,
            );
          },
        );
      },
    );
  }
}

Offset studentSectionMotionTranslation({
  required Size size,
  required double introDegrees,
  required double outroDegrees,
  required double progress,
  required bool exiting,
}) {
  final curved = AppMotion.sectionCurve.transform(
    progress.clamp(0.0, 1.0).toDouble(),
  );
  final remaining = 1 - curved;
  final direction = sectionMotionOffset(
    size,
    exiting ? outroDegrees : introDegrees,
  );
  return direction * (exiting ? remaining : -remaining);
}

class _StudentActionButton extends StatelessWidget {
  const _StudentActionButton({
    super.key,
    required this.canvasSize,
    required this.containerId,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount,
  });

  final Size canvasSize;
  final String containerId;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  /// 아이콘 오른쪽 위 개수 배지(S1 필터 버튼 "필터 · n", FD-058). null이면 없다.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final path = studentContainerPath(canvasSize, containerId)!;
    final bounds = path.getBounds();
    final iconSize = math.min(22.0, bounds.shortestSide * 0.52);
    final iconCenter = studentActionIconCenter(bounds);
    return Positioned.fromRect(
      rect: bounds,
      child: Tooltip(
        message: tooltip,
        child: ClipPath(
          clipper: _LocalPathClipper(path.shift(-bounds.topLeft)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: iconCenter.dx - iconSize / 2,
                    top: iconCenter.dy - iconSize / 2,
                    width: iconSize,
                    height: iconSize,
                    child: Icon(
                      icon,
                      size: iconSize,
                      color: onPressed == null
                          ? AppColors.textMuted.withValues(alpha: 0.45)
                          : AppColors.text,
                    ),
                  ),
                  if (badgeCount case final count?)
                    Positioned(
                      left: iconCenter.dx + iconSize * 0.18,
                      top: iconCenter.dy - iconSize / 2 - 7,
                      child: StudentFilterButtonBadge(
                        key: const ValueKey('student-filter-count-badge'),
                        count: count,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// S1 필터 버튼 개수 배지(FD-058, 워커 재량): 모달이 닫힌 뒤 걸린 조건 수. 모달 배지와 같은 색
/// (#0d151f + 1.5px 핑크 링, 글자 #f7c9f4)의 작은 알약이다.
class StudentFilterButtonBadge extends StatelessWidget {
  const StudentFilterButtonBadge({super.key, required this.count});

  final int count;

  static const height = 18.0;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '필터 · $count',
    child: ExcludeSemantics(
      child: Container(
        height: height,
        constraints: const BoxConstraints(minWidth: height),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.popover,
          borderRadius: BorderRadius.all(Radius.circular(height / 2)),
          boxShadow: [BoxShadow(color: AppColors.accent, spreadRadius: 1.5)],
        ),
        child: Text(
          '$count',
          maxLines: 1,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: AppType.captionSize,
            height: 1,
            fontWeight: AppType.bold,
            color: AppColors.accentText,
          ),
        ),
      ),
    ),
  );
}

class _StudentSortDropdown extends StatelessWidget {
  const _StudentSortDropdown({
    required this.canvasSize,
    required this.value,
    required this.onChanged,
  });

  final Size canvasSize;
  final StudentGridSort value;
  final ValueChanged<StudentGridSort> onChanged;

  @override
  Widget build(BuildContext context) {
    final path = studentSortDropdownPath(canvasSize);
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      rect: bounds,
      child: CustomPaint(
        painter: _StudentSortDropdownBorderPainter(localPath),
        child: ClipPath(
          clipper: _LocalPathClipper(localPath),
          child: Material(
            color: Colors.transparent,
            child: PopupMenuButton<StudentGridSort>(
              key: const ValueKey('student-grid-sort-dropdown'),
              tooltip: '학생 정렬',
              initialValue: value,
              color: AppColors.surfaceRaised,
              padding: EdgeInsets.zero,
              onSelected: onChanged,
              itemBuilder: (context) => [
                for (final option in StudentGridSort.values)
                  PopupMenuItem(
                    value: option,
                    child: Text(
                      option.menuLabel,
                      style: const TextStyle(
                        color: studentSortAccentColor,
                        fontSize: studentSortMenuFontSize,
                      ),
                    ),
                  ),
              ],
              child: bounds.width < 26
                  ? const SizedBox.expand()
                  : Padding(
                      padding: EdgeInsets.only(
                        left: math.min(11, bounds.width * 0.16),
                        right: math.min(20, bounds.width * 0.28),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value.compactLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: studentSortAccentColor,
                            fontSize: studentSortCompactFontSize,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 계산기 S1 "빠른 목표 고르기"(FD-169). 학생 정렬 드롭다운과 같은 자리·모양이다.
class _CalculatorQuickTargetDropdown extends StatelessWidget {
  const _CalculatorQuickTargetDropdown({
    required this.canvasSize,
    required this.onSelected,
  });

  final Size canvasSize;
  final ValueChanged<GrowthCalculatorQuickTarget> onSelected;

  @override
  Widget build(BuildContext context) {
    final path = studentSortDropdownPath(canvasSize);
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      rect: bounds,
      child: CustomPaint(
        painter: _StudentSortDropdownBorderPainter(localPath),
        child: ClipPath(
          clipper: _LocalPathClipper(localPath),
          child: Material(
            color: Colors.transparent,
            child: PopupMenuButton<GrowthCalculatorQuickTarget>(
              key: const ValueKey('calculator-quick-target-dropdown'),
              tooltip: '빠른 목표 고르기',
              color: AppColors.surfaceRaised,
              padding: EdgeInsets.zero,
              onSelected: onSelected,
              itemBuilder: (context) => [
                for (final option in GrowthCalculatorQuickTarget.values)
                  PopupMenuItem(
                    key: ValueKey('calculator-quick-target-${option.name}'),
                    value: option,
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        color: studentSortAccentColor,
                        fontSize: studentSortMenuFontSize,
                      ),
                    ),
                  ),
              ],
              child: bounds.width < 26
                  ? const SizedBox.expand()
                  : Padding(
                      padding: EdgeInsets.only(
                        left: math.min(11, bounds.width * 0.16),
                        right: math.min(20, bounds.width * 0.28),
                      ),
                      child: const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '빠른 목표',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: studentSortAccentColor,
                            fontSize: studentSortCompactFontSize,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentSortDropdownBorderPainter extends CustomPainter {
  const _StudentSortDropdownBorderPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = studentSortAccentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (size.width < 26 || size.height < 6) return;
    final arrowWidth = math.min(9.0, size.width * 0.16);
    final arrowHeight = math.min(6.0, size.height * 0.32);
    final right = size.width - math.min(7.0, size.width * 0.1);
    final top = (size.height - arrowHeight) / 2;
    canvas.drawPath(
      Path()
        ..moveTo(right - arrowWidth, top)
        ..lineTo(right, top)
        ..lineTo(right - arrowWidth / 2, top + arrowHeight)
        ..close(),
      Paint()..color = studentSortAccentColor,
    );
  }

  @override
  bool shouldRepaint(_StudentSortDropdownBorderPainter oldDelegate) =>
      oldDelegate.path.getBounds() != path.getBounds();
}

class _StudentViewModeButtons extends StatelessWidget {
  const _StudentViewModeButtons({
    required this.canvasSize,
    required this.value,
    required this.onChanged,
  });

  final Size canvasSize;
  final StudentSection2View value;
  final ValueChanged<StudentSection2View> onChanged;

  @override
  Widget build(BuildContext context) {
    final paths = studentViewTogglePaths(canvasSize);
    return Stack(
      children: [
        _StudentViewModeButton(
          path: paths[0],
          buttonKey: const ValueKey('student-list-view-button'),
          tooltip: '리스트 보기',
          icon: Icons.view_agenda_outlined,
          selected: value == StudentSection2View.list,
          onTap: () => onChanged(StudentSection2View.list),
        ),
        _StudentViewModeButton(
          path: paths[1],
          buttonKey: const ValueKey('student-grid-view-button'),
          tooltip: '그리드 보기',
          icon: Icons.grid_view_rounded,
          selected: value == StudentSection2View.grid,
          onTap: () => onChanged(StudentSection2View.grid),
        ),
      ],
    );
  }
}

class _StudentViewModeButton extends StatelessWidget {
  const _StudentViewModeButton({
    required this.path,
    required this.buttonKey,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final Path path;
  final Key buttonKey;
  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      rect: bounds,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: CustomPaint(
            painter: _StudentViewModeButtonPainter(localPath, selected),
            child: ClipPath(
              clipper: _LocalPathClipper(localPath),
              child: Material(
                key: buttonKey,
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Icon(
                    icon,
                    size: math.min(18, bounds.shortestSide * 0.52),
                    color: selected ? studentSortAccentColor : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentViewModeButtonPainter extends CustomPainter {
  const _StudentViewModeButtonPainter(this.path, this.selected);

  final Path path;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(_studentActionTexture).paint(canvas, size);
    if (selected) {
      canvas.drawPath(
        path,
        Paint()..color = studentSortAccentColor.withValues(alpha: 0.13),
      );
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = selected
            ? studentSortAccentColor
            : AppColors.outline.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.4 : 0.8,
    );
  }

  @override
  bool shouldRepaint(_StudentViewModeButtonPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.selected != selected;
}

Offset studentActionIconCenter(Rect bounds) {
  final y = bounds.height / 2;
  final cutAtY = diagonalCutDepth(y);
  final horizontalLength = math.max(0.0, bounds.width - cutAtY);
  return Offset(horizontalLength / 2, y);
}

enum StudentContainerTextureRole { none, status, action, section2Background }

StudentContainerTextureRole studentContainerTextureRole(
  StudioContainerElement container,
) {
  if (container.id == 'container-12') {
    return StudentContainerTextureRole.section2Background;
  }
  if (container.parentSectionId == 'element-1') {
    return StudentContainerTextureRole.action;
  }
  if (container.triangleTexture || container.id == 'container-2') {
    return StudentContainerTextureRole.status;
  }
  return StudentContainerTextureRole.none;
}

bool studentContainerShowsOutline(StudioContainerElement container) => true;

class _StudentStatusIndicators extends StatelessWidget {
  const _StudentStatusIndicators({
    required this.canvasSize,
    required this.student,
    required this.values,
    this.bondTarget,
  });

  final Size canvasSize;
  final StudentCatalogEntry? student;
  final Map<String, dynamic>? values;
  final int? bondTarget;

  int? _integer(String key) => values?[key] as int?;
  String? _text(String key) => values?[key] as String?;

  Widget _containerWithPath(String id, Widget Function(Path) childBuilder) {
    final path = studentContainerPath(canvasSize, id)!;
    final bounds = path.getBounds();
    final localPath = path.shift(-bounds.topLeft);
    return Positioned.fromRect(
      rect: bounds,
      child: ClipPath(
        clipper: _LocalPathClipper(localPath),
        child: childBuilder(localPath),
      ),
    );
  }

  Widget _container(String id, Widget child) =>
      _containerWithPath(id, (_) => child);

  Widget _feature(String id, Widget child) {
    final path = studentFeaturePath(canvasSize, id)!;
    final bounds = path.getBounds();
    return Positioned.fromRect(
      rect: bounds,
      child: ClipPath(
        clipper: _LocalPathClipper(path.shift(-bounds.topLeft)),
        child: child,
      ),
    );
  }

  bool get _hasWeapon {
    final state = _text('weapon_state');
    if (state == null ||
        const {
          'weapon_locked',
          'no_system',
          'locked',
          'none',
        }.contains(state)) {
      return false;
    }
    return (_integer('weapon_star') ?? 0) > 0 ||
        (_integer('weapon_level') ?? 0) > 0 ||
        const {
          'weapon_unlocked',
          'weapon_unlocked_not_equipped',
          'weapon_equipped',
          'equipped',
        }.contains(state);
  }

  String _skillValue(String key, int maximum) {
    final value = _integer(key);
    if (value == null) return '-';
    return value >= maximum ? 'M' : '$value';
  }

  String _favoriteItemValue() => switch (_text('equip4')) {
    'T1' => 'T1',
    'T2' => 'T2',
    null || '' || 'empty' || 'unknown' || 'none' || 'no_system' => '-',
    _ => '',
  };

  bool get _favoriteItemLocked =>
      const {'love_locked', 'level_locked', 'locked'}.contains(_text('equip4'));

  @override
  Widget build(BuildContext context) {
    final level = _integer('level');
    final weaponLevel = _integer('weapon_level');
    final bondRank = _integer('bond_rank');
    final metadataBounds = [
      for (final id in const ['feature-3', 'feature-4', 'feature-5'])
        studentFeaturePath(canvasSize, id)!.getBounds(),
    ];
    final metadataValueLeft = metadataBounds
        .map((bounds) => bounds.left + bounds.width * 0.58)
        .reduce(math.max);
    return Stack(
      fit: StackFit.expand,
      children: [
        _feature(
          'feature-2',
          StudentLevelStatus(
            level: level,
            schoolLogoAsset: studentSchoolLogoAsset(student?.school),
          ),
        ),
        _feature(
          'feature-3',
          _StudentMetadataValue(
            key: const ValueKey('student-detail-position'),
            label: 'Position',
            value: _titleCase(student?.position),
            valueLeftInset: metadataValueLeft - metadataBounds[0].left,
          ),
        ),
        _feature(
          'feature-4',
          _StudentMetadataValue(
            key: const ValueKey('student-detail-combat-class'),
            label: 'Class',
            value: _titleCase(student?.combatClass),
            valueLeftInset: metadataValueLeft - metadataBounds[1].left,
          ),
        ),
        _feature(
          'feature-5',
          _StudentMetadataValue(
            key: const ValueKey('student-detail-weapon-level'),
            label: 'Weapon',
            value: 'Lv. ${_hasWeapon ? weaponLevel ?? '--' : '--'}',
            valueLeftInset: metadataValueLeft - metadataBounds[2].left,
          ),
        ),
        _container(
          'container-5',
          StudentSkillStatus(
            values: [
              _skillValue('ex_skill', 5),
              _skillValue('skill1', 10),
              _skillValue('skill2', 10),
              _skillValue('skill3', 10),
            ],
          ),
        ),
        _container(
          'container-6',
          StudentEquipmentStatus(
            student: student,
            tiers: [_text('equip1'), _text('equip2'), _text('equip3')],
            levels: [
              _integer('equip1_level'),
              _integer('equip2_level'),
              _integer('equip3_level'),
            ],
            favoriteItem: _favoriteItemValue(),
            favoriteItemLocked: _favoriteItemLocked,
          ),
        ),
        _container(
          'container-7',
          StudentAbilityStatus(
            hp: _integer('stat_hp'),
            atk: _integer('stat_atk'),
            heal: _integer('stat_heal'),
          ),
        ),
        _container('container-9', const StudentPotentialStatus()),
        _container(
          'container-4',
          _StudentCombatStatus(
            values: {
              'HP': _integer('combat_hp'),
              'ATK': _integer('combat_atk'),
              'DEF': _integer('combat_def'),
              'HEAL': _integer('combat_heal'),
            },
          ),
        ),
        _containerWithPath(
          'container-10',
          (outerPath) => StudentBondStatus(
            bondRank: bondRank,
            outerPath: outerPath,
            targetRank: bondTarget,
            solidFill: true,
          ),
        ),
      ],
    );
  }

  String _titleCase(String? value) {
    if (value == null || value.isEmpty) return '-';
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }
}

String? studentSchoolLogoAsset(String? school) {
  final assetName = switch (school?.trim().toLowerCase()) {
    'abydos' => 'ABYDOS',
    'arius' => 'Arius',
    'gehenna' => 'GEHENNA',
    'highlander' => 'HIGHLANDER',
    'hyakkiyako' => 'HYAKKIYAKO',
    'millennium' => 'MILLENNIUM',
    'red winter' => 'REDWINTER',
    'sakugawa' => 'SAKUGAWA',
    'shanhaijing' => 'SHANHAIJING',
    'srt' => 'SRT',
    'tokiwadai' => 'Tokiwadai',
    'trinity' => 'TRINITY',
    'valkyrie' => 'VALKYRIE',
    'wild hunt' => 'WILDHUNT',
    'etc' => 'ETC',
    _ => null,
  };
  return assetName == null ? null : GameAssets.schoolLogo(assetName);
}

class StudentLevelStatus extends StatelessWidget {
  const StudentLevelStatus({
    super.key,
    required this.level,
    required this.schoolLogoAsset,
    this.showSchool = true,
  });

  final int? level;
  final String? schoolLogoAsset;
  final bool showSchool;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final railInset = diagonalCutDepth(size.height);
      return CustomPaint(
        key: ValueKey(
          showSchool
              ? 'student-detail-level-split'
              : 'student-detail-level-only',
        ),
        painter: _StudentLevelSplitPainter(showSchool: showSchool),
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: showSchool
                  ? studentLevelValueRegion(size)
                  : Offset.zero & size,
              child: Padding(
                key: const ValueKey('student-detail-level-region'),
                padding: EdgeInsets.fromLTRB(railInset + 12, 6, 5, 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'LEVEL',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontFamily: 'GyeonggiTitle',
                          fontFamilyFallback: AppFonts.fallback,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Lv. ${level ?? '--'}',
                          key: const ValueKey('student-detail-level'),
                          style: const TextStyle(
                            color: AppColors.text,
                            fontFamily: 'GyeonggiTitle',
                            fontFamilyFallback: AppFonts.fallback,
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showSchool)
              Positioned.fromRect(
                rect: studentLevelSchoolRegion(size),
                child: Padding(
                  key: const ValueKey('student-detail-school-region'),
                  padding: const EdgeInsets.fromLTRB(5, 13, 7, 2),
                  child: schoolLogoAsset == null
                      ? const SizedBox.shrink()
                      : ColorFiltered(
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(
                            schoolLogoAsset!,
                            key: const ValueKey('student-detail-school-logo'),
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
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

class _StudentLevelSplitPainter extends CustomPainter {
  const _StudentLevelSplitPainter({required this.showSchool});

  final bool showSchool;

  @override
  void paint(Canvas canvas, Size size) {
    if (!showSchool) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = AppColors.indicatorSurface,
      );
      return;
    }
    final endpoints = studentLevelSplitEndpoints(size);
    final splitTop = endpoints.first.dx;
    final splitBottom = endpoints.last.dx;
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(splitTop, 0)
      ..lineTo(splitBottom, size.height)
      ..lineTo(0, size.height)
      ..close();
    final school = Path()
      ..moveTo(splitTop, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(splitBottom, size.height)
      ..close();
    canvas.drawPath(left, Paint()..color = AppColors.indicatorSurface);
    canvas.drawPath(school, Paint()..color = const Color(0xff28445a));
    canvas.drawLine(
      Offset(splitTop, 0),
      Offset(splitBottom, size.height),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.55)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_StudentLevelSplitPainter oldDelegate) =>
      oldDelegate.showSchool != showSchool;
}

List<Offset> studentLevelSplitEndpoints(Size size) {
  final splitTop = size.width * 0.73;
  final run = diagonalCutDepth(size.height);
  return [Offset(splitTop, 0), Offset(splitTop - run, size.height)];
}

Rect studentLevelValueRegion(Size size) {
  final splitBottom = studentLevelSplitEndpoints(size).last.dx;
  return Rect.fromLTRB(0, 0, math.max(0, splitBottom), size.height);
}

Rect studentLevelSchoolRegion(Size size) {
  final splitTop = studentLevelSplitEndpoints(size).first.dx;
  return Rect.fromLTRB(
    math.min(size.width, math.max(0, splitTop)),
    0,
    size.width,
    size.height,
  );
}

class _StudentMetadataValue extends StatelessWidget {
  const _StudentMetadataValue({
    super.key,
    required this.label,
    required this.value,
    required this.valueLeftInset,
  });

  final String label;
  final String value;
  final double valueLeftInset;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Positioned(
        left: 9,
        top: 2,
        bottom: 2,
        width: math.max(1, valueLeftInset - 16),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              color: studentSortAccentColor,
              fontFamily: 'GyeonggiTitle',
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
      Positioned(
        left: valueLeftInset,
        right: 9,
        top: 2,
        bottom: 2,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            key: ValueKey('student-detail-metadata-value-$label'),
            style: const TextStyle(
              color: AppColors.text,
              fontFamily: 'GyeonggiTitle',
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
      ),
    ],
  );
}

class StudentSkillStatus extends StatelessWidget {
  const StudentSkillStatus({super.key, required this.values});

  static const _labels = ['EX', 'Normal', 'Passive', 'Sub-skill'];
  final List<String> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: EdgeInsets.fromLTRB(
        diagonalCutDepth(constraints.maxHeight) + 9,
        7,
        diagonalCutDepth(constraints.maxHeight) + 9,
        4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StudentSectionHeader(
            key: ValueKey('student-detail-skills-title'),
            text: 'SKILL SUMMARY',
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < _labels.length; index++) ...[
                  if (index > 0)
                    _StudentDiagonalDivider(
                      key: ValueKey('student-detail-skill-divider-$index'),
                    ),
                  Expanded(
                    child: _StudentSkillColumn(
                      label: _labels[index],
                      value: values[index],
                      index: index,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StudentSectionTitle extends StatelessWidget {
  const _StudentSectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.text,
            fontFamily: 'GyeonggiTitle',
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

class _StudentSectionHeader extends StatelessWidget {
  const _StudentSectionHeader({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _StudentSectionTitle(text: text),
      const SizedBox(height: 3),
      Container(
        key: const ValueKey('student-detail-section-header-line'),
        width: double.infinity,
        height: 1,
        color: AppColors.primary.withValues(alpha: 0.42),
      ),
    ],
  );
}

class _StudentSkillColumn extends StatelessWidget {
  const _StudentSkillColumn({
    required this.label,
    required this.value,
    required this.index,
  });

  final String label;
  final String value;
  final int index;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: FittedBox(
      key: ValueKey('student-detail-skill-column-$index'),
      fit: BoxFit.scaleDown,
      alignment: const Alignment(0, -0.5),
      child: SizedBox(
        width: 74,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: 'GyeonggiTitle',
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              key: ValueKey('student-detail-skill-$index'),
              style: const TextStyle(
                color: AppColors.text,
                fontFamily: 'GyeonggiTitle',
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 31.5,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StudentDiagonalDivider extends StatelessWidget {
  const _StudentDiagonalDivider({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 16,
    child: OverflowBox(
      minWidth: 32,
      maxWidth: 32,
      child: CustomPaint(painter: _StudentDiagonalDividerPainter()),
    ),
  );
}

List<Offset> studentDiagonalDividerEndpoints(Size size) {
  final top = math.min(2.0, size.height);
  final bottom = math.max(top, size.height - 2);
  final run = diagonalCutDepth(bottom - top);
  return [
    Offset((size.width + run) / 2, top),
    Offset((size.width - run) / 2, bottom),
  ];
}

class _StudentDiagonalDividerPainter extends CustomPainter {
  const _StudentDiagonalDividerPainter();

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
  bool shouldRepaint(_StudentDiagonalDividerPainter oldDelegate) => false;
}

class StudentAbilityStatus extends StatelessWidget {
  const StudentAbilityStatus({
    super.key,
    required this.hp,
    required this.atk,
    required this.heal,
  });

  final int? hp;
  final int? atk;
  final int? heal;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final railInset = diagonalCutDepth(constraints.maxHeight);
      final contentWidth = math.max(0.0, constraints.maxWidth - railInset - 18);
      final titleWidth = math.min(90.0, contentWidth * 0.36);
      final titleGap = math.min(12.0, contentWidth * 0.06);
      return Padding(
        padding: EdgeInsets.fromLTRB(railInset + 9, 0, 9, 0),
        child: Row(
          key: const ValueKey('student-detail-ability'),
          children: [
            SizedBox(
              width: titleWidth,
              child: const _StudentSectionTitle(text: 'Ability Release'),
            ),
            SizedBox(width: titleGap),
            Expanded(
              key: const ValueKey('student-detail-ability-values-region'),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'HP ${hp ?? '-'}  |  ATK ${atk ?? '-'}  |  '
                    'HEAL ${heal ?? '-'}',
                    key: const ValueKey('student-detail-ability-values'),
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontFamily: 'GyeonggiTitle',
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
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

class StudentEquipmentStatus extends StatelessWidget {
  const StudentEquipmentStatus({
    super.key,
    required this.student,
    required this.tiers,
    required this.levels,
    required this.favoriteItem,
    required this.favoriteItemLocked,
    this.equipmentTypes,
  });

  final StudentCatalogEntry? student;
  final List<String?> tiers;
  final List<int?> levels;
  final String favoriteItem;
  final bool favoriteItemLocked;
  final List<String?>? equipmentTypes;

  String? _assetPath(int index) {
    final equipmentType =
        equipmentTypes != null && index < equipmentTypes!.length
        ? equipmentTypes![index]
        : switch (index) {
            0 => student?.equipmentSlot1,
            1 => student?.equipmentSlot2,
            _ => student?.equipmentSlot3,
          };
    final match = RegExp(r'^T(\d+)$').firstMatch(tiers[index] ?? '');
    final tier = int.tryParse(match?.group(1) ?? '');
    if (equipmentType == null || tier == null || tier < 1 || tier > 10) {
      return null;
    }
    return GameAssets.equipmentIcon(equipmentType, tier);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final railInset = diagonalCutDepth(constraints.maxHeight);
      return Padding(
        padding: EdgeInsets.fromLTRB(railInset + 9, 7, railInset + 9, 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StudentSectionHeader(
              key: ValueKey('student-detail-equipment-title'),
              text: 'EQUIPMENT',
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < 3; index++) ...[
                    if (index > 0)
                      _StudentDiagonalDivider(
                        key: ValueKey(
                          'student-detail-equipment-divider-$index',
                        ),
                      ),
                    Expanded(
                      child: _StudentEquipmentSlot(
                        key: ValueKey('student-detail-equipment-$index'),
                        tier: tiers[index] ?? '-',
                        level: levels[index],
                        assetPath: _assetPath(index),
                        edgeShift: railInset * 0.22,
                      ),
                    ),
                  ],
                  const _StudentDiagonalDivider(
                    key: ValueKey('student-detail-equipment-divider-3'),
                  ),
                  Expanded(
                    child: _StudentFavoriteItemSlot(
                      value: favoriteItem,
                      locked: favoriteItemLocked,
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

class _StudentEquipmentSlot extends StatelessWidget {
  const _StudentEquipmentSlot({
    super.key,
    required this.tier,
    required this.level,
    required this.assetPath,
    required this.edgeShift,
  });

  final String tier;
  final int? level;
  final String? assetPath;
  final double edgeShift;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        flex: 2,
        child: Transform.translate(
          offset: Offset(edgeShift, 0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              tier,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontFamily: 'GyeonggiTitle',
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 13.5,
                height: 1,
              ),
            ),
          ),
        ),
      ),
      Expanded(
        flex: 6,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Image.asset(
              defaultStudentPortraitBackgroundAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
            if (assetPath != null)
              FractionallySizedBox(
                widthFactor: 0.96,
                heightFactor: 0.96,
                child: Image.asset(
                  assetPath!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
          ],
        ),
      ),
      Expanded(
        flex: 2,
        child: Transform.translate(
          offset: Offset(-edgeShift, 0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              level == null ? '-' : 'Lv. $level',
              style: const TextStyle(
                color: AppColors.text,
                fontFamily: 'GyeonggiTitle',
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 13.5,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _StudentFavoriteItemSlot extends StatelessWidget {
  const _StudentFavoriteItemSlot({required this.value, required this.locked});

  final String value;
  final bool locked;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '애장품',
          style: TextStyle(
            color: AppColors.textMuted,
            fontFamily: 'GyeonggiTitle',
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 8,
            height: 1,
          ),
        ),
      ),
      const SizedBox(height: 2),
      if (locked)
        const Icon(
          Icons.lock_rounded,
          key: ValueKey('student-detail-favorite-locked'),
          color: AppColors.textMuted,
          size: 17,
        )
      else
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            key: const ValueKey('student-detail-favorite-value'),
            style: const TextStyle(
              color: AppColors.text,
              fontFamily: 'GyeonggiTitle',
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
    ],
  );
}

class StudentPotentialStatus extends StatelessWidget {
  const StudentPotentialStatus({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(
        key: const ValueKey('student-detail-potential-overlay'),
        color: Colors.black.withValues(alpha: 0.38),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.canvas.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.textMuted.withValues(alpha: 0.55),
                  ),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  key: ValueKey('student-detail-potential-locked'),
                  color: AppColors.text,
                  size: 21,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                '심상개화',
                style: TextStyle(
                  color: AppColors.text,
                  fontFamily: 'GyeonggiTitle',
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 18.5,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

double studentCombatRowOffset({
  required double height,
  required int index,
  int itemCount = 4,
}) {
  if (height <= 0 || itemCount <= 0) return 0;
  final railRun = diagonalCutDepth(height);
  final normalizedCenter = (index + 0.5) / itemCount;
  return -railRun * normalizedCenter;
}

double studentCombatDividerOffset({
  required double height,
  required int index,
  int itemCount = 4,
}) {
  if (height <= 0 || itemCount <= 0) return 0;
  final railRun = diagonalCutDepth(height);
  final normalizedBoundary = (index + 1) / itemCount;
  return -railRun * normalizedBoundary;
}

class _StudentCombatStatus extends StatelessWidget {
  const _StudentCombatStatus({required this.values});

  final Map<String, int?> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final entries = values.entries.toList(growable: false);
      final railRun = diagonalCutDepth(constraints.maxHeight);
      return Padding(
        padding: EdgeInsets.fromLTRB(railRun + 9, 9, 9, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StudentSectionHeader(
              key: ValueKey('student-detail-stats-title'),
              text: 'STATS',
            ),
            const SizedBox(height: 4),
            for (var index = 0; index < entries.length; index++) ...[
              Expanded(
                child: Transform.translate(
                  key: ValueKey('student-detail-combat-row-$index'),
                  offset: Offset(
                    studentCombatRowOffset(
                      height: constraints.maxHeight,
                      index: index,
                      itemCount: entries.length,
                    ),
                    0,
                  ),
                  child: _StudentCombatValue(entry: entries[index]),
                ),
              ),
              if (index < entries.length - 1)
                Transform.translate(
                  key: ValueKey('student-detail-stat-row-divider-$index'),
                  offset: Offset(
                    studentCombatDividerOffset(
                      height: constraints.maxHeight,
                      index: index,
                      itemCount: entries.length,
                    ),
                    0,
                  ),
                  child: Container(
                    height: 1,
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _StudentCombatValue extends StatelessWidget {
  const _StudentCombatValue({required this.entry});

  final MapEntry<String, int?> entry;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StudentCombatIcon(stat: entry.key),
        const SizedBox(width: 5),
        Text(
          entry.value?.toString() ?? '-',
          key: ValueKey('student-detail-combat-${entry.key.toLowerCase()}'),
          maxLines: 1,
          style: const TextStyle(
            color: AppColors.text,
            fontFamily: 'GyeonggiTitle',
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

class _StudentCombatIcon extends StatelessWidget {
  const _StudentCombatIcon({required this.stat});

  final String stat;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey('student-detail-combat-icon-${stat.toLowerCase()}');
    if (stat == 'ATK') {
      return SizedBox(
        key: key,
        width: 19,
        height: 19,
        child: const CustomPaint(painter: _StudentSwordPainter()),
      );
    }
    final icon = switch (stat) {
      'HP' => Icons.favorite_border_rounded,
      'DEF' => Icons.shield_outlined,
      _ => Icons.healing_rounded,
    };
    return Icon(icon, key: key, color: AppColors.primary, size: 19);
  }
}

class _StudentSwordPainter extends CustomPainter {
  const _StudentSwordPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final blade = Path()
      ..moveTo(size.width * 0.27, size.height * 0.73)
      ..lineTo(size.width * 0.72, size.height * 0.28)
      ..lineTo(size.width * 0.82, size.height * 0.18)
      ..lineTo(size.width * 0.73, size.height * 0.36)
      ..lineTo(size.width * 0.36, size.height * 0.73);
    canvas.drawPath(blade, paint);
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.58),
      Offset(size.width * 0.43, size.height * 0.79),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.78),
      size.shortestSide * 0.055,
      paint,
    );
  }

  @override
  bool shouldRepaint(_StudentSwordPainter oldDelegate) => false;
}

/// 인연 랭크 삼각형 게이지(학생 S3 container-10, 계획 요소 초상 옆).
///
/// [targetRank]가 있으면 W-Bond-Variants B안(FE3-b, FD-049~051)처럼 그린다: 현재 랭크 채움은
/// 그대로(rank/100), 현재 위 목표까지는 빗금, 목표 높이에 점선, 점선 위 오른쪽에 `→N`.
/// 목표가 없거나 현재 이하이면 목표 표시를 하지 않는다([studentBondVisibleTarget]).
class StudentBondStatus extends StatelessWidget {
  const StudentBondStatus({
    super.key,
    required this.bondRank,
    required this.outerPath,
    this.inverted = false,
    this.fillFromBottom = true,
    this.targetRank,
    this.solidFill = false,
  });

  final int? bondRank;
  final Path outerPath;
  final bool inverted;
  final bool fillFromBottom;

  /// 활성 계획 문서의 인연 목표(FD-049). 그대로 넘기고, 보일지는 위젯이 정한다.
  final int? targetRank;

  /// B안의 현재 채움(불투명 #e9b0ee). false면 이전 채움(@.78)이다. 학생 S3는 true,
  /// 계획 요소 초상(inverted)은 계획 화면을 B안으로 바꾸는 slice까지 false다.
  final bool solidFill;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final rankRect = studentBondRankRect(
        size,
        outerPath: outerPath,
        inverted: inverted,
      );
      final target = studentBondVisibleTarget(
        current: bondRank,
        target: targetRank,
      );
      final targetLine = target == null
          ? null
          : studentBondTargetLine(
              size,
              outerPath,
              target,
              inverted: inverted,
              fillFromBottom: fillFromBottom,
            );
      return Stack(
        children: [
          CustomPaint(
            key: const ValueKey('student-detail-bond-gauge'),
            size: size,
            painter: _StudentTriangleBondGaugePainter(
              rank: bondRank,
              outerPath: outerPath,
              inverted: inverted,
              fillFromBottom: fillFromBottom,
              target: target,
              solidFill: solidFill,
            ),
          ),
          if (target != null && targetLine != null)
            Positioned(
              key: const ValueKey('student-detail-bond-target'),
              right:
                  size.width - targetLine.right + studentBondTargetLabelInset,
              bottom:
                  size.height - targetLine.y + studentBondTargetLabelGap - 2,
              child: Text(
                studentBondTargetLabel(target),
                maxLines: 1,
                style: studentBondTargetLabelStyle,
              ),
            ),
          Positioned.fromRect(
            rect: rankRect,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${bondRank ?? '-'}',
                key: const ValueKey('student-detail-bond-rank'),
                style: const TextStyle(
                  color: AppColors.text,
                  fontFamily: 'GyeonggiTitle',
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 43.2,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

// --- 인연 목표 겹침(B안) ------------------------------------------------------
// 시안 W-Bond-Variants B · W-Student-Detail: 빗금 pattern 6×6 rotate(−35°), 바탕
// rgba(233,176,238,.16) + 폭 2.4 줄 .55. 점선 #e9b0ee 1.6, dash 3 2, 바깥 삼각형 왼쪽 변에서
// 오른쪽 끝까지. `→N`은 경기천년제목 10 w800 #e9b0ee, 오른쪽 끝 − 3에 오른쪽 정렬, 점선 5 위가 글자 바닥.

const studentBondTargetHatchStyle = HatchStyle(
  background: Color.fromRGBO(233, 176, 238, 0.16),
  line: Color.fromRGBO(233, 176, 238, 0.55),
  lineWidth: 2.4,
  spacing: 6,
  angleDegrees: -35,
);
const studentBondTargetLineColor = studentSortAccentColor;
const studentBondTargetLineWidth = 1.6;
const studentBondTargetDash = 3.0;
const studentBondTargetDashGap = 2.0;
const studentBondTargetLabelInset = 3.0;
const studentBondTargetLabelGap = 5.0;
const studentBondTargetLabelStyle = TextStyle(
  color: studentSortAccentColor,
  fontFamily: 'GyeonggiTitle',
  fontFamilyFallback: AppFonts.fallback,
  fontSize: 10,
  fontWeight: FontWeight.w800,
  height: 1,
);

String studentBondTargetLabel(int target) => '→$target';

/// 목표 높이의 점선 위치: y와 바깥 삼각형의 그 높이 가로 범위.
({double y, double left, double right}) studentBondTargetLine(
  Size size,
  Path outerPath,
  int target, {
  bool inverted = false,
  bool fillFromBottom = true,
}) {
  final bounds = studentBondGaugeHostPath(
    size,
    outerPath,
    inverted: inverted,
  ).getBounds();
  final edge = studentBondGaugeFillRect(
    bounds,
    target / 100,
    fillFromBottom: fillFromBottom,
  );
  final y = fillFromBottom ? edge.top : edge.bottom;
  final span = _studentPathHorizontalSpan(outerPath, y);
  return (y: y, left: span.left, right: span.right);
}

List<Offset> studentBondOuterTrianglePoints(Size size) {
  final source = studentStudioDocument.containers.firstWhere(
    (item) => item.id == 'container-10',
  );
  return buildAttachedSectionPolygon(
    size,
    source.spec,
    gridSize: sectionTemplateDetailGridSize,
  );
}

Rect studentBondRankRect(Size size, {Path? outerPath, bool inverted = false}) {
  final outerBounds = outerPath?.getBounds() ?? (Offset.zero & size);
  final edgeGap = math.max(7.0, size.height * 0.035);
  final height = math.min(46.0, size.height * 0.16);
  final span = outerPath == null
      ? () {
          final points = studentBondOuterTrianglePoints(size);
          final pointsBottom = points.map((point) => point.dy).reduce(math.max);
          final bottomPoints = points
              .where((point) => (point.dy - pointsBottom).abs() < 0.001)
              .toList(growable: false);
          return (
            left: bottomPoints.map((point) => point.dx).reduce(math.min),
            right: bottomPoints.map((point) => point.dx).reduce(math.max),
          );
        }()
      : _studentPathHorizontalSpan(
          outerPath,
          inverted
              ? outerBounds.top + edgeGap + height / 2
              : outerBounds.bottom - edgeGap - height / 2,
        );
  final left = span.left;
  final right = span.right;
  final horizontalInset = math.min(8.0, (right - left) * 0.12);
  return Rect.fromLTWH(
    left + horizontalInset,
    inverted
        ? outerBounds.top + edgeGap
        : outerBounds.bottom - edgeGap - height,
    math.max(1, right - left - horizontalInset * 2),
    height,
  );
}

double studentBondGaugeEdgeGap(Size size) =>
    math.max(3.0, math.min(6.0, size.width * 0.06));

double studentBondGaugeRankGap(Size size) =>
    math.max(3.0, math.min(4.0, size.height * 0.015));

double studentBondGaugeBottomRadius(Size size) =>
    10.0 + studentBondGaugeEdgeGap(size) + 0.5;

({double left, double right}) _studentPathHorizontalSpan(Path path, double y) {
  final bounds = path.getBounds();
  const sampleCount = 128;
  final sampleY = y.clamp(bounds.top + 0.001, bounds.bottom - 0.001);
  var firstInside = -1;
  var lastInside = -1;
  for (var index = 0; index <= sampleCount; index++) {
    final x = bounds.left + bounds.width * index / sampleCount;
    if (path.contains(Offset(x, sampleY))) {
      firstInside = firstInside < 0 ? index : firstInside;
      lastInside = index;
    }
  }
  if (firstInside < 0) return (left: bounds.left, right: bounds.right);

  double refine(int outsideIndex, int insideIndex) {
    var outside = bounds.left + bounds.width * outsideIndex / sampleCount;
    var inside = bounds.left + bounds.width * insideIndex / sampleCount;
    for (var iteration = 0; iteration < 16; iteration++) {
      final middle = (outside + inside) / 2;
      final isInside = path.contains(Offset(middle, sampleY));
      if (isInside) {
        inside = middle;
      } else {
        outside = middle;
      }
    }
    return inside;
  }

  final left = firstInside == 0
      ? bounds.left
      : refine(firstInside - 1, firstInside);
  final right = lastInside == sampleCount
      ? bounds.right
      : refine(lastInside + 1, lastInside);
  return (left: left, right: right);
}

Path studentBondGaugeHostPath(
  Size size,
  Path outerPath, {
  bool inverted = false,
}) {
  final rankRect = studentBondRankRect(
    size,
    outerPath: outerPath,
    inverted: inverted,
  );
  final outerBounds = outerPath.getBounds();
  final gaugeEdge = inverted
      ? rankRect.bottom + studentBondGaugeRankGap(size)
      : rankRect.top - studentBondGaugeRankGap(size);
  final span = _studentPathHorizontalSpan(
    outerPath,
    gaugeEdge + (inverted ? 0.01 : -0.01),
  );
  final radius = math.min(
    studentBondGaugeBottomRadius(size),
    math.max(0.0, (span.right - span.left) / 2),
  );
  final roundedGaugeMask = Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(
          span.left,
          inverted ? gaugeEdge : outerBounds.top,
          span.right,
          inverted ? outerBounds.bottom : gaugeEdge,
        ),
        topLeft: inverted ? Radius.circular(radius) : Radius.zero,
        topRight: inverted ? Radius.circular(radius) : Radius.zero,
        bottomLeft: inverted ? Radius.zero : Radius.circular(radius),
        bottomRight: inverted ? Radius.zero : Radius.circular(radius),
      ),
    );
  return Path.combine(PathOperation.intersect, outerPath, roundedGaugeMask);
}

class _StudentTriangleBondGaugePainter extends CustomPainter {
  const _StudentTriangleBondGaugePainter({
    required this.rank,
    required this.outerPath,
    required this.inverted,
    required this.fillFromBottom,
    this.target,
    this.solidFill = false,
  });

  final int? rank;
  final Path outerPath;
  final bool inverted;
  final bool fillFromBottom;

  /// 보이는 목표([studentBondVisibleTarget] 결과). null이면 목표 표시 없음.
  final int? target;
  final bool solidFill;

  void _drawInsetPath(
    Canvas canvas,
    Size size,
    Path path,
    Color color,
    double inset,
  ) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = inset * 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gauge = studentBondGaugeHostPath(size, outerPath, inverted: inverted);
    final bounds = gauge.getBounds();
    final inset = studentBondGaugeEdgeGap(size);
    _drawInsetPath(
      canvas,
      size,
      gauge,
      AppColors.outline.withValues(alpha: 0.78),
      math.max(0, inset - 0.5),
    );
    _drawInsetPath(
      canvas,
      size,
      gauge,
      const Color(0xff111f2c).withValues(alpha: 0.94),
      inset + 0.5,
    );
    final target = this.target;
    if (target != null) {
      // 목표까지 빗금. 현재 채움이 그 위를 덮으므로 현재 ~ 목표 구간만 남는다.
      canvas.save();
      canvas.clipRect(
        studentBondGaugeFillRect(
          bounds,
          target / 100,
          fillFromBottom: fillFromBottom,
        ),
      );
      canvas.saveLayer(Offset.zero & size, Paint());
      paintHatch(canvas, gauge, style: studentBondTargetHatchStyle);
      _clearInsetBorder(canvas, gauge, inset + 0.5);
      canvas.restore();
      canvas.restore();
    }
    final progress = ((rank ?? 0) / 100).clamp(0.0, 1.0);
    if (progress > 0) {
      canvas.save();
      canvas.clipRect(
        studentBondGaugeFillRect(
          bounds,
          progress,
          fillFromBottom: fillFromBottom,
        ),
      );
      _drawInsetPath(
        canvas,
        size,
        gauge,
        solidFill
            ? studentSortAccentColor
            : studentSortAccentColor.withValues(alpha: 0.78),
        inset + 0.5,
      );
      canvas.restore();
    }
    if (target != null) {
      final line = studentBondTargetLine(
        size,
        outerPath,
        target,
        inverted: inverted,
        fillFromBottom: fillFromBottom,
      );
      final paint = Paint()
        ..color = studentBondTargetLineColor
        ..strokeWidth = studentBondTargetLineWidth;
      for (
        var x = line.left;
        x < line.right;
        x += studentBondTargetDash + studentBondTargetDashGap
      ) {
        canvas.drawLine(
          Offset(x, line.y),
          Offset(math.min(line.right, x + studentBondTargetDash), line.y),
          paint,
        );
      }
    }
  }

  void _clearInsetBorder(Canvas canvas, Path path, double inset) {
    canvas.drawPath(
      path,
      Paint()
        ..blendMode = BlendMode.clear
        ..style = PaintingStyle.stroke
        ..strokeWidth = inset * 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StudentTriangleBondGaugePainter oldDelegate) =>
      oldDelegate.rank != rank ||
      oldDelegate.outerPath != outerPath ||
      oldDelegate.inverted != inverted ||
      oldDelegate.fillFromBottom != fillFromBottom ||
      oldDelegate.target != target ||
      oldDelegate.solidFill != solidFill;
}

Rect studentBondGaugeFillRect(
  Rect bounds,
  double progress, {
  required bool fillFromBottom,
}) {
  final normalized = progress.clamp(0.0, 1.0).toDouble();
  return Rect.fromLTRB(
    bounds.left,
    fillFromBottom ? bounds.bottom - bounds.height * normalized : bounds.top,
    bounds.right,
    fillFromBottom ? bounds.bottom : bounds.top + bounds.height * normalized,
  );
}

class _StudentSectionFoundationPainter extends CustomPainter {
  const _StudentSectionFoundationPainter({
    required this.selectedValues,
    required this.sectionIds,
    this.bare = false,
  });

  final Map<String, dynamic>? selectedValues;
  final Set<String> sectionIds;

  /// 섹션 바탕만 그리고 안쪽 container·feature는 그리지 않는다(계산기 S2, FE3-f2a).
  final bool bare;

  @override
  void paint(Canvas canvas, Size size) {
    final document = studentStudioDocument;
    final sectionOrder = [
      document.elements.firstWhere((item) => item.id == 'element-2'),
      document.elements.firstWhere((item) => item.id == 'element-4'),
      document.elements.firstWhere((item) => item.id == 'element-3'),
      document.elements.firstWhere((item) => item.id == 'element-1'),
    ];
    for (final section in sectionOrder.where(
      (section) => sectionIds.contains(section.id),
    )) {
      final path = studentSectionPath(size, section.id);
      paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
      var fillPath = path;
      for (final container in studentRuntimeContainers(size)) {
        if (bare ||
            container.parentSectionId != section.id ||
            container.id == 'container-1' ||
            container.id == 'container-3') {
          continue;
        }
        final childPath = studentContainerPath(size, container.id);
        if (childPath != null) {
          fillPath = Path.combine(
            PathOperation.difference,
            fillPath,
            childPath,
          );
        }
      }
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = AppColors.surface.withValues(alpha: studentSectionOpacity)
          ..style = PaintingStyle.fill,
      );
    }

    if (bare) return;
    for (final container in studentRuntimeContainers(size)) {
      if (!sectionIds.contains(container.parentSectionId)) continue;
      if (container.id == 'container-1' || container.id == 'container-3') {
        continue;
      }
      final path = studentContainerPath(size, container.id);
      if (path == null) continue;
      final textureRole = studentContainerTextureRole(container);
      if (textureRole == StudentContainerTextureRole.section2Background) {
        canvas.drawPath(path, Paint()..color = studentSection2ContainerColor);
      } else if (textureRole != StudentContainerTextureRole.none) {
        canvas.save();
        canvas.clipPath(path, doAntiAlias: true);
        BATriangleTexturePainter(
          textureRole == StudentContainerTextureRole.action
              ? _studentActionTexture
              : _studentTexture,
        ).paint(canvas, size);
        canvas.restore();
      } else {
        canvas.drawPath(
          path,
          Paint()..color = AppColors.surfaceRaised.withValues(alpha: 0.9),
        );
      }
      if (studentContainerShowsOutline(container)) {
        canvas.drawPath(
          path,
          Paint()
            ..color = AppColors.outline.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9,
        );
      }
    }

    // Container 2's four internal features intentionally stay flat-color.
    for (final feature in document.features) {
      final parentContainer = document.containers.firstWhere(
        (container) => container.id == feature.parentContainerId,
      );
      if (!sectionIds.contains(parentContainer.parentSectionId)) continue;
      final path = studentFeaturePath(size, feature.id);
      if (path == null) continue;
      canvas.drawPath(
        path,
        Paint()..color = AppColors.indicatorSurface.withValues(alpha: 0.98),
      );
    }

    if (sectionIds.contains('element-3')) {
      _paintStarIndicator(canvas, size);
    }
  }

  void _paintStarIndicator(Canvas canvas, Size size) {
    final bounds = studentContainerPath(size, 'container-3')!.getBounds();
    final studentStars = selectedValues?['student_star'] as int? ?? 0;
    final weaponStars = selectedValues?['weapon_star'] as int? ?? 0;
    paintStudentStarStatus(
      canvas,
      bounds,
      studentStars: studentStars,
      weaponStars: weaponStars,
    );
  }

  @override
  bool shouldRepaint(_StudentSectionFoundationPainter oldDelegate) =>
      oldDelegate.selectedValues != selectedValues ||
      oldDelegate.sectionIds != sectionIds ||
      oldDelegate.bare != bare;
}

({bool showTop, bool showBottom}) studentViewportFogVisibility({
  required double minScrollExtent,
  required double maxScrollExtent,
  required double pixels,
  double tolerance = 0.5,
}) {
  return scrollViewportFogVisibility(
    minScrollExtent: minScrollExtent,
    maxScrollExtent: maxScrollExtent,
    pixels: pixels,
    tolerance: tolerance,
  );
}

class StudentViewportFog extends StatelessWidget {
  const StudentViewportFog({
    super.key,
    required this.showTop,
    required this.showBottom,
    this.color,
  });

  final bool showTop;
  final bool showBottom;
  final Color? color;

  @override
  Widget build(BuildContext context) => ScrollViewportFog(
    keyPrefix: 'student-viewport-fog',
    showTop: showTop,
    showBottom: showBottom,
    color: color ?? const Color(0xff263d52),
  );
}

class StudentDiagonalFilterList extends StatefulWidget {
  const StudentDiagonalFilterList({
    super.key,
    required this.students,
    required this.selected,
    required this.onToggle,
    this.definitions,
    this.fogColor,
  });

  final List<StudentCatalogEntry> students;
  final Map<String, Set<String>> selected;
  final void Function(String key, String value) onToggle;
  final List<StudentFilterDefinition>? definitions;
  final Color? fogColor;

  @override
  State<StudentDiagonalFilterList> createState() =>
      _StudentDiagonalFilterListState();
}

class _StudentDiagonalFilterListState extends State<StudentDiagonalFilterList> {
  static const _inset = 8.0;
  static const _gap = 8.0;
  static const _checkboxHeight = 27.0;
  static const _titleHeight = 28.0;
  static const _scrollbarReserve = 14.0;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<(StudentFilterDefinition, List<String>)> _groups() => [
    for (final definition in widget.definitions ?? studentFilterDefinitions)
      () {
        final values = widget.students
            .map(definition.read)
            .whereType<String>()
            .where(
              (value) =>
                  definition.key != 'school' ||
                  (value != 'Sakugawa' && value != 'Tokiwadai'),
            )
            .toSet()
            .toList();
        if (definition.key == 'rarity') {
          values.sort(
            (a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0),
          );
        } else {
          values.sort(
            (a, b) => studentFilterValueLabel(
              definition.key,
              a,
            ).compareTo(studentFilterValueLabel(definition.key, b)),
          );
        }
        return (definition, values);
      }(),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final groups = _groups().where((group) => group.$2.isNotEmpty).toList();
      final heights = [
        for (final group in groups)
          _titleHeight + ((group.$2.length + 1) ~/ 2) * _checkboxHeight + 10,
      ];
      final contentHeight =
          _inset * 2 +
          heights.fold<double>(0, (sum, item) => sum + item) +
          _gap * math.max(0, groups.length - 1);

      return _StudentDiagonalScrollbar(
        controller: _controller,
        keyPrefix: 'student-filter',
        fogColor: widget.fogColor,
        child: SingleChildScrollView(
          key: const ValueKey('student-diagonal-filter-scroll'),
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
              var top = _inset;
              final children = <Widget>[];
              for (var index = 0; index < groups.length; index++) {
                final group = groups[index];
                final height = heights[index];
                final horizontalOffset = studentDiagonalRowHorizontalOffset(
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: height,
                  scrollOffset: scroll,
                );
                final width = studentDiagonalFilterRowWidth(
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                  rowHeight: height,
                  horizontalInset: _inset,
                  scrollbarReserve: _scrollbarReserve,
                );
                children.add(
                  Positioned(
                    key: ValueKey('student-filter-group-${group.$1.key}'),
                    left: _inset + horizontalOffset,
                    top: top,
                    width: width,
                    height: height,
                    child: _StudentFilterGroupCard(
                      definition: group.$1,
                      values: group.$2,
                      selected: widget.selected[group.$1.key] ?? const {},
                      onToggle: widget.onToggle,
                    ),
                  ),
                );
                top += height + _gap;
              }
              return SizedBox(
                height: contentHeight,
                width: constraints.maxWidth,
                child: Stack(clipBehavior: Clip.none, children: children),
              );
            },
          ),
        ),
      );
    },
  );
}

class _StudentFilterGroupCard extends StatelessWidget {
  const _StudentFilterGroupCard({
    required this.definition,
    required this.values,
    required this.selected,
    required this.onToggle,
  });

  final StudentFilterDefinition definition;
  final List<String> values;
  final Set<String> selected;
  final void Function(String key, String value) onToggle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final safeHorizontalInset = studentFilterGroupContentInset(
        constraints.maxHeight,
      );
      return CustomPaint(
        painter: const _StudentFilterGroupPainter(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            safeHorizontalInset,
            7,
            safeHorizontalInset,
            5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                definition.label,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Wrap(
                  children: [
                    for (final value in values)
                      FractionallySizedBox(
                        widthFactor: 0.5,
                        child: InkWell(
                          key: ValueKey(
                            'student-filter-${definition.key}-$value',
                          ),
                          onTap: () => onToggle(definition.key, value),
                          child: SizedBox(
                            height:
                                _StudentDiagonalFilterListState._checkboxHeight,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Transform.scale(
                                    scale: 0.68,
                                    child: IgnorePointer(
                                      child: Checkbox(
                                        value: selected.contains(value),
                                        onChanged: (_) {},
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    studentFilterValueLabel(
                                      definition.key,
                                      value,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _StudentFilterGroupPainter extends CustomPainter {
  const _StudentFilterGroupPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final depth = diagonalCutDepth(size.height);
    final path = buildRoundedSectionPolygon([
      Offset(depth, 0),
      Offset(size.width, 0),
      Offset(size.width - depth, size.height),
      Offset(0, size.height),
    ], radius: 7);
    canvas.drawPath(path, Paint()..color = const Color(0xc735526b));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_StudentFilterGroupPainter oldDelegate) => false;
}

const studentListItemHeight = 97.5;
const studentListItemExtent = 101.5;

class StudentDiagonalList extends StatefulWidget {
  const StudentDiagonalList({
    super.key,
    required this.students,
    required this.ownedIds,
    required this.studentValuesById,
    required this.selectedId,
    required this.onSelected,
  });

  final List<StudentCatalogEntry> students;
  final Set<String> ownedIds;
  final Map<String, Map<String, dynamic>> studentValuesById;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<StudentDiagonalList> createState() => _StudentDiagonalListState();
}

class _StudentDiagonalListState extends State<StudentDiagonalList> {
  static const _inset = 8.0;
  static const _scrollbarReserve = 14.0;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (widget.students.isEmpty) {
        return const Center(
          child: Text(
            '표시할 학생이 없습니다.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        );
      }
      final tangent = diagonalTan80;
      final trajectoryDepth = constraints.maxHeight / tangent;
      final rowWidth = math.max(
        116.0,
        constraints.maxWidth -
            _inset * 2 -
            _scrollbarReserve -
            (constraints.maxHeight - studentListItemHeight) / tangent,
      );
      final contentHeight =
          _inset * 2 +
          studentListItemHeight +
          studentListItemExtent * math.max(0, widget.students.length - 1);
      return _StudentDiagonalScrollbar(
        controller: _controller,
        keyPrefix: 'student-list',
        child: SingleChildScrollView(
          key: const ValueKey('student-diagonal-list-scroll'),
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var index = 0; index < widget.students.length; index++)
                      () {
                        final student = widget.students[index];
                        final owned = widget.ownedIds.contains(
                          student.studentId,
                        );
                        final top = _inset + index * studentListItemExtent;
                        final bottomViewportY =
                            top + studentListItemHeight - scroll;
                        final offset =
                            (constraints.maxHeight - bottomViewportY) / tangent;
                        return Positioned(
                          left: _inset + offset,
                          top: top,
                          width: math.max(
                            1.0,
                            math.min(
                              rowWidth,
                              constraints.maxWidth -
                                  _inset -
                                  offset -
                                  trajectoryDepth * 0.02,
                            ),
                          ),
                          height: studentListItemHeight,
                          child: PlanStudentStepTile(
                            key: ValueKey('student-list-${student.studentId}'),
                            order: index + 1,
                            step: studentListStepPreview(
                              student,
                              widget.studentValuesById[student.studentId] ??
                                  const {},
                              owned: owned,
                            ),
                            owned: owned,
                            currentStudentState: true,
                            jpOnly: student.jpOnly,
                            highlighted: student.studentId == widget.selectedId,
                            onTap: () => widget.onSelected(student.studentId),
                          ),
                        );
                      }(),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class StudentDiagonalGrid extends StatefulWidget {
  const StudentDiagonalGrid({
    super.key,
    required this.students,
    required this.ownedIds,
    required this.studentValuesById,
    this.plannedIds = const {},
    required this.selectedId,
    this.selectedIds = const {},
    required this.onSelected,
    this.showAttributes = true,
    this.showNames = true,
    this.columns = 8,
    this.revealStudentId,
    this.revealRequest = 0,
  });

  final List<StudentCatalogEntry> students;
  final Set<String> ownedIds;
  final Map<String, Map<String, dynamic>> studentValuesById;
  final Set<String> plannedIds;
  final String? selectedId;
  final Set<String> selectedIds;
  final ValueChanged<String> onSelected;
  final bool showAttributes;
  final bool showNames;
  final int columns;

  /// [revealRequest]가 바뀌면 이 학생의 행이 보이도록 스크롤한다(최근 본 학생, FD-061).
  final String? revealStudentId;
  final int revealRequest;

  @override
  State<StudentDiagonalGrid> createState() => _StudentDiagonalGridState();
}

class _StudentDiagonalGridState extends State<StudentDiagonalGrid> {
  static const _rowBuffer = 1;
  static const _gridGap = 4.8;
  static const _gridInset = 8.0;
  static const _scrollbarReserve = 14.0;
  final ScrollController _controller = ScrollController();
  ({StudentGridRowGeometry geometry, int columns, double viewport})? _layout;

  @override
  void didUpdateWidget(StudentDiagonalGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final studentId = widget.revealStudentId;
    if (studentId != null && oldWidget.revealRequest != widget.revealRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(studentId));
    }
  }

  void _reveal(String studentId) {
    final layout = _layout;
    if (!mounted || layout == null || !_controller.hasClients) return;
    final index = widget.students.indexWhere(
      (student) => student.studentId == studentId,
    );
    if (index < 0) return;
    final offset = studentGridRevealOffset(
      row: index ~/ layout.columns,
      geometry: layout.geometry,
      contentTop: _gridInset,
      viewportHeight: layout.viewport,
      maxScrollExtent: _controller.position.maxScrollExtent,
    );
    if ((offset - _controller.offset).abs() < 0.5) return;
    _controller.animateTo(
      offset,
      duration: AppMotion.header,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = math.max(1, widget.columns);
      final rows = math.max(1, (widget.students.length / columns).ceil());
      final trajectoryDepth = constraints.maxHeight / diagonalTan80;
      final cardWidth = math.max(
        1.0,
        (constraints.maxWidth -
                _gridInset * 2 -
                trajectoryDepth -
                _scrollbarReserve -
                _gridGap * (columns - 1)) /
            columns,
      );
      // DE 그리드(FD-045): 셀 = 카드(252:204)이고 그 아래에 카드 밖 이름 줄이 붙는다.
      // 이미지·overlay·hit target은 모두 이 기하를 쓰며 행 간격은 "이름 줄 + 3.84"다.
      final geometry = studentGridRowGeometry(
        cardWidth: cardWidth,
        showNames: widget.showNames,
      );
      _layout = (
        geometry: geometry,
        columns: columns,
        viewport: constraints.maxHeight,
      );
      final contentHeight =
          _gridInset * 2 +
          rows * geometry.cardHeight +
          geometry.imageRowGap * math.max(0, rows - 1) +
          geometry.nameExtent;
      return _StudentDiagonalScrollbar(
        controller: _controller,
        keyPrefix: 'student-grid',
        child: SingleChildScrollView(
          key: const ValueKey('student-diagonal-grid-scroll'),
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
              final activeRows = studentGridActiveRowRange(
                rowCount: rows,
                scrollOffset: scroll,
                viewportHeight: constraints.maxHeight,
                cellHeight: geometry.cardHeight,
                rowGap: geometry.imageRowGap,
                contentTop: _gridInset,
                bufferRows: _rowBuffer,
              );
              final firstStudentIndex = activeRows.start * columns;
              final lastStudentIndex = math.min(
                widget.students.length,
                activeRows.end * columns,
              );
              final offsets = List<double>.generate(
                rows,
                (row) => studentGridRowHorizontalOffset(
                  viewportHeight: constraints.maxHeight,
                  contentTop: _gridInset,
                  row: row,
                  geometry: geometry,
                  scrollOffset: scroll,
                ),
                growable: false,
              );
              final padding = EdgeInsets.fromLTRB(
                _gridInset,
                _gridInset,
                _gridInset + trajectoryDepth + _scrollbarReserve,
                _gridInset + geometry.nameExtent,
              );
              // 보이는 행(+ 버퍼)에 다중 폼 학생이 있는가. 스크롤 위치가 줄어든 목록보다 뒤면 범위가 비어 있다.
              var hasMultiForm = false;
              for (
                var index = firstStudentIndex;
                index < lastStudentIndex;
                index++
              ) {
                if (widget.students[index].isMultiForm) {
                  hasMultiForm = true;
                  break;
                }
              }
              return SizedBox(
                height: contentHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      // 보이는 행에 다중 폼 학생이 있을 때만 공용 시계를 듣는다(FD-064).
                      child: StudentFormCycleBuilder(
                        active: hasMultiForm,
                        builder: (context, formStep) => AssetImageGrid(
                          key: const ValueKey('student-image-grid'),
                          items: [
                            for (
                              var index = firstStudentIndex;
                              index < lastStudentIndex;
                              index++
                            ) ...[
                              AssetImageGridItem(
                                asset: bondRankPortraitBackgroundAsset(
                                  widget.studentValuesById[widget
                                          .students[index]
                                          .studentId]?['bond_rank']
                                      as int?,
                                ),
                                column: index % columns,
                                row: index ~/ columns,
                                scale: 1,
                                edgeCropFraction: 0.11,
                                clipPathBuilder: studentGridCardPath,
                              ),
                              AssetImageGridItem(
                                asset: studentPortraitAssetAt(
                                  widget.students[index],
                                  formStep,
                                ),
                                column: index % columns,
                                row: index ~/ columns,
                                scale: 0.98,
                                clipRadiusFraction: 0.12,
                                alphaThreshold: 0.04,
                              ),
                            ],
                          ],
                          columns: columns,
                          rows: rows,
                          columnGap: _gridGap,
                          rowGap: geometry.imageRowGap,
                          rowHorizontalOffsets: offsets,
                          contentPadding: padding,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          key: const ValueKey('student-card-overlay-grid'),
                          painter: StudentGridCardOverlayPainter(
                            students: widget.students,
                            ownedIds: widget.ownedIds,
                            columns: columns,
                            rows: rows,
                            columnGap: _gridGap,
                            rowGap: geometry.imageRowGap,
                            rowHorizontalOffsets: offsets,
                            contentPadding: padding,
                            showAttributes: widget.showAttributes,
                            showNames: widget.showNames,
                            plannedIds: widget.plannedIds,
                            firstRow: activeRows.start,
                            lastRow: activeRows.end,
                            selectedIndex: widget.selectedId == null
                                ? null
                                : widget.students.indexWhere(
                                    (item) =>
                                        item.studentId == widget.selectedId,
                                  ),
                            selectedIndices: {
                              for (
                                var index = 0;
                                index < widget.students.length;
                                index++
                              )
                                if (widget.selectedIds.contains(
                                  widget.students[index].studentId,
                                ))
                                  index,
                            },
                          ),
                        ),
                      ),
                    ),
                    ..._hitTargets(
                      constraints.maxWidth,
                      contentHeight,
                      columns,
                      rows,
                      _gridGap,
                      geometry.imageRowGap,
                      padding,
                      offsets,
                      activeRows.start,
                      activeRows.end,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );

  List<Widget> _hitTargets(
    double width,
    double height,
    int columns,
    int rows,
    double columnGap,
    double rowGap,
    EdgeInsets padding,
    List<double> offsets,
    int firstRow,
    int lastRow,
  ) {
    final contentWidth = width - padding.horizontal;
    final cellWidth = (contentWidth - columnGap * (columns - 1)) / columns;
    final cellHeight =
        (height - padding.vertical - rowGap * math.max(0, rows - 1)) / rows;
    return [
      for (
        var index = firstRow * columns;
        index < math.min(widget.students.length, lastRow * columns);
        index++
      )
        Positioned(
          key: ValueKey('student-${widget.students[index].studentId}'),
          left:
              padding.left +
              offsets[index ~/ columns] +
              (index % columns) * (cellWidth + columnGap),
          top: padding.top + (index ~/ columns) * (cellHeight + rowGap),
          width: cellWidth,
          height: cellHeight,
          child: Semantics(
            button: true,
            selected:
                widget.students[index].studentId == widget.selectedId ||
                widget.selectedIds.contains(widget.students[index].studentId),
            label: widget.students[index].displayName,
            child: ClipPath(
              clipper: const _StudentGridCardHitClipper(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    widget.onSelected(widget.students[index].studentId),
              ),
            ),
          ),
        ),
    ];
  }
}

/// [row]행 카드가 viewport 가운데에 오는 스크롤 위치(0 ~ [maxScrollExtent]로 자름).
double studentGridRevealOffset({
  required int row,
  required StudentGridRowGeometry geometry,
  required double contentTop,
  required double viewportHeight,
  required double maxScrollExtent,
}) {
  final cardCenter =
      contentTop + row * geometry.rowPitch + geometry.cardHeight / 2;
  return (cardCenter - viewportHeight / 2).clamp(
    0.0,
    math.max(0.0, maxScrollExtent),
  );
}

({int start, int end}) studentGridActiveRowRange({
  required int rowCount,
  required double scrollOffset,
  required double viewportHeight,
  required double cellHeight,
  required double rowGap,
  required double contentTop,
  int bufferRows = 1,
}) {
  if (rowCount <= 0) return (start: 0, end: 0);
  final stride = math.max(1.0, cellHeight + rowGap);
  final buffer = math.max(0, bufferRows);
  final firstVisible = ((scrollOffset - contentTop) / stride).floor();
  final lastVisible = ((scrollOffset + viewportHeight - contentTop) / stride)
      .floor();
  return (
    start: math.min(rowCount, math.max(0, firstVisible - buffer)),
    end: math.min(rowCount, math.max(0, lastVisible + buffer + 1)),
  );
}

const studentGridCardSourceSize = Size(252, 204);
const studentGridCardOutlineColor = Colors.white;
const studentGridCardSelectionColor = Color(0xffff72b6);
const studentGridCardOutlineWidthFraction = 0.01;
const studentGridCardSelectionWidthFraction = 0.02;

// --- DE 카드: 카드 밖 이름 줄(FD-043, FD-045, FD-046) ------------------------
// 시안 Student·W-Card-States·W-Card-Grid-DE: 이름 span은 카드 아래 3px에서 높이 16,
// 폭 = 카드 하단 변 길이(카드 폭 − 80° 깊이), Pretendard 13 w700, 보유 #f4f8fb · 미보유 #9eb0c2.
// 행 피치 = 카드 + 이름 줄 20 + 행 간격 3.84(카드 폭 206.87 → 167.47 + 23.84 = 191.31).

/// 카드 아래 이름 줄이 차지하는 세로 길이(카드 아래 3 + 글자 줄 16 + 1).
const studentGridNameLineExtent = 20.0;

/// 카드 밑변과 이름 글자 줄 사이 간격.
const studentGridNameTopGap = 3.0;

/// 이름 글자 줄 높이.
const studentGridNameHeight = 16.0;
const studentGridNameFontSize = AppType.bodySize;
const studentGridOwnedNameColor = AppColors.text;

/// 미보유 학생 이름은 흐리게(FD-043).
const studentGridUnownedNameColor = AppColors.textMuted;

/// 행 사이 간격(이름 줄 아래). 열 간격은 4.8이다.
const studentGridRowGap = 3.84;

/// DE 그리드 한 행의 기하.
@immutable
class StudentGridRowGeometry {
  const StudentGridRowGeometry({
    required this.cardWidth,
    required this.cardHeight,
    required this.nameExtent,
  });

  final double cardWidth;
  final double cardHeight;

  /// 이름 줄 높이. "학생 이름 표시"를 끄면 0이다(FD-046 (a)).
  final double nameExtent;

  /// 이미지 셀(= 카드) 사이 세로 간격: 이름 줄 + [studentGridRowGap].
  double get imageRowGap => nameExtent + studentGridRowGap;

  /// 한 행의 세로 피치.
  double get rowPitch => cardHeight + imageRowGap;
}

StudentGridRowGeometry studentGridRowGeometry({
  required double cardWidth,
  required bool showNames,
}) => StudentGridRowGeometry(
  cardWidth: cardWidth,
  cardHeight:
      cardWidth *
      studentGridCardSourceSize.height /
      studentGridCardSourceSize.width,
  nameExtent: showNames ? studentGridNameLineExtent : 0,
);

/// [row]행의 가로 이동: 카드 중심 높이에서 viewport 밑변까지의 80° 레일 거리(FD-045).
double studentGridRowHorizontalOffset({
  required double viewportHeight,
  required double contentTop,
  required int row,
  required StudentGridRowGeometry geometry,
  double scrollOffset = 0,
}) {
  final cardCenterY =
      contentTop +
      row * geometry.rowPitch +
      geometry.cardHeight / 2 -
      scrollOffset;
  return (viewportHeight - cardCenterY) / diagonalTan80;
}

/// 카드 밖 이름 글자 줄 rect. 왼쪽은 카드 왼쪽, 폭은 카드 하단 변 길이다.
Rect studentGridNameRect(Rect card) => Rect.fromLTWH(
  card.left,
  card.bottom + studentGridNameTopGap,
  math.max(0.0, card.width - studentGridCardCutDepth(card)),
  studentGridNameHeight,
);

/// 카드 평행사변형의 80° 가로 깊이.
double studentGridCardCutDepth(Rect card) =>
    math.min(card.width * 0.25, diagonalCutDepth(card.height));

// --- 상태 배지: 왼쪽 80° 변 채워 쌓기(FD-044) --------------------------------

enum StudentGridStatusBadge {
  unowned('UNOWNED'),
  plan('PLAN'),
  jp('JP');

  const StudentGridStatusBadge(this.label);
  final String label;
}

typedef StudentGridStatusBadgePlacement = ({
  StudentGridStatusBadge badge,
  Rect rect,
});

/// 있는 배지만 UNOWNED → PLAN → JP 순서로 왼쪽 80° 변을 따라 위에서부터 쌓는다.
///
/// 첫 칸은 카드 왼쪽 위 꼭짓점(깊이만큼 들어간 자리), 다음 칸은 (배지 높이 + 간격)만큼
/// 아래로, 그 높이의 80° 깊이만큼 왼쪽으로 간다. 크기는 기존 계약 그대로다
/// (높이 = 카드 높이 14%, 폭 UNOWNED 42% · PLAN 28% · JP 18%).
List<StudentGridStatusBadgePlacement> studentGridStatusBadgeStack(
  Rect card, {
  required bool owned,
  required bool planned,
  required bool jpOnly,
}) {
  final badges = [
    if (!owned) StudentGridStatusBadge.unowned,
    if (planned) StudentGridStatusBadge.plan,
    if (jpOnly) StudentGridStatusBadge.jp,
  ];
  return [
    for (var slot = 0; slot < badges.length; slot++)
      (
        badge: badges[slot],
        rect: studentGridStatusBadgeSlotRect(card, slot, badges[slot]),
      ),
  ];
}

/// [slot]번째(0부터) 배지 칸.
Rect studentGridStatusBadgeSlotRect(
  Rect card,
  int slot,
  StudentGridStatusBadge badge,
) {
  final badgeHeight = (card.height * 0.14).clamp(14.0, 28.0);
  final width = switch (badge) {
    StudentGridStatusBadge.unowned => (card.width * 0.42).clamp(32.0, 92.0),
    StudentGridStatusBadge.plan => (card.width * 0.28).clamp(28.0, 64.0),
    StudentGridStatusBadge.jp => (card.width * 0.18).clamp(24.0, 44.0),
  };
  final gap = card.shortestSide * studentGridCardOutlineWidthFraction;
  final step = badgeHeight + gap;
  return Rect.fromLTWH(
    card.left + studentGridCardCutDepth(card) - slot * diagonalCutDepth(step),
    card.top + gap * 0.5 + slot * step,
    width,
    badgeHeight,
  );
}

// --- 속성 글자 칩: 오른쪽 위, 80° 계단(D안, FD-043·FD-047) --------------------
// 시안 값: 칩 높이 max(14, 카드 높이 × .11), 위 4, 칩 사이 3, 글자 = 높이 × .55 w800 흰색,
// 좌우 안쪽 여백 = 높이 × .45, r3, skewX(−10°), 그림자 0 1 2 rgba(0,0,0,.4).
// 칩 상자 오른쪽 끝은 칩 밑변 높이에서 카드 오른쪽 80° 변보다 6px 안쪽이다
// (카드 높이 161.9 → right 9.8 / 13.5, 167.47 → 10.0 / 13.7).

const studentAttributeChipTop = 4.0;
const studentAttributeChipGap = 3.0;
const studentAttributeChipEdgeInset = 6.0;
const studentAttributeChipRadius = 3.0;
const studentAttributeChipHeightFraction = 0.11;
const studentAttributeChipMinHeight = 14.0;
const studentAttributeChipFontFraction = 0.55;
const studentAttributeChipPaddingFraction = 0.45;
const studentAttributeChipShadowColor = Color(0x66000000);

/// 카드 칩용 공격 타입 축약 라벨(FD-047).
const Map<String, String> studentAttackChipLabels = {
  'Explosive': '폭발',
  'Piercing': '관통',
  'Mystic': '신비',
  'Sonic': '진동',
  'Chemical': '화학',
};

/// 카드 칩용 방어 타입 축약 라벨(FD-047). 필터 팝업은 전체 라벨(`studentFilterValueLabels`)을 쓴다.
const Map<String, String> studentDefenseChipLabels = {
  'Light': '경장',
  'Heavy': '중장',
  'Special': '특수',
  'Elastic': '탄력',
  'Composite': '복합',
};

String? studentAttackChipLabel(String? attackType) =>
    studentAttackChipLabels[attackType];

String? studentDefenseChipLabel(String? defenseType) =>
    studentDefenseChipLabels[defenseType];

double studentAttributeChipHeight(Rect card) => math.max(
  studentAttributeChipMinHeight,
  card.height * studentAttributeChipHeightFraction,
);

/// [slot]번째 칩 상자(기울이기 전). 오른쪽 끝이 카드 오른쪽 80° 변을 따라 계단을 이룬다.
Rect studentAttributeChipBox(Rect card, int slot, double width) {
  final height = studentAttributeChipHeight(card);
  final top =
      studentAttributeChipTop + slot * (height + studentAttributeChipGap);
  final right =
      card.right -
      studentAttributeChipEdgeInset -
      diagonalCutDepth(top + height);
  return Rect.fromLTRB(
    right - width,
    card.top + top,
    right,
    card.top + top + height,
  );
}

/// 칩에 들어가는 (라벨, 색) 목록. 라벨을 모르는 타입은 칩을 그리지 않고 다음 칩이 올라온다.
List<({String label, Color color})> studentAttributeChips(
  StudentCatalogEntry student,
) => [
  if (studentAttackChipLabel(student.attackType) case final label?)
    (label: label, color: studentAttackTypeColor(student.attackType)),
  if (studentDefenseChipLabel(student.defenseType) case final label?)
    (label: label, color: studentDefenseTypeColor(student.defenseType)),
];

Path studentGridCardPath(Rect rect) {
  final depth = studentGridCardCutDepth(rect);
  return buildRoundedSectionPolygon([
    Offset(rect.left + depth, rect.top),
    Offset(rect.right, rect.top),
    Offset(rect.right - depth, rect.bottom),
    Offset(rect.left, rect.bottom),
  ], radius: math.min(12, rect.shortestSide * 0.1));
}

Rect studentGridCardFittedRect(Rect cell) => Alignment.center.inscribe(
  applyBoxFit(BoxFit.contain, studentGridCardSourceSize, cell.size).destination,
  cell,
);

Path studentGridCardHitPath(Rect rect) {
  final depth = studentGridCardCutDepth(rect);
  return Path()
    ..moveTo(rect.left + depth, rect.top)
    ..lineTo(rect.right, rect.top)
    ..lineTo(rect.right - depth, rect.bottom)
    ..lineTo(rect.left, rect.bottom)
    ..close();
}

class _StudentGridCardHitClipper extends CustomClipper<Path> {
  const _StudentGridCardHitClipper();

  @override
  Path getClip(Size size) =>
      studentGridCardHitPath(studentGridCardFittedRect(Offset.zero & size));

  @override
  bool shouldReclip(_StudentGridCardHitClipper oldClipper) => false;
}

/// 공격 타입 색(FD-024). 타입 색은 [AppColors] 토큰만 쓴다.
Color studentAttackTypeColor(String? attackType) => switch (attackType) {
  'Explosive' => AppColors.typeExplosive,
  'Piercing' => AppColors.typePiercing,
  'Mystic' => AppColors.typeMystic,
  'Sonic' => AppColors.typeSonic,
  'Break' ||
  'Demolition' ||
  'Disassembly' ||
  'Composite' => AppColors.typeComposite,
  _ => AppColors.outline,
};

/// 방어 타입 색. 경장=폭발, 중장=관통, 특수=신비, 탄력=진동, 복합=composite.
Color studentDefenseTypeColor(String? defenseType) => switch (defenseType) {
  'Light' => AppColors.typeExplosive,
  'Heavy' => AppColors.typePiercing,
  'Special' => AppColors.typeMystic,
  'Elastic' => AppColors.typeSonic,
  'Composite' => AppColors.typeComposite,
  _ => AppColors.outline,
};

/// 학생 카드 overlay(DE). 셀마다 카드(252:204 contain)를 잡고 그 위에
/// 속성 글자 칩(오른쪽 위), 미보유 암전, 흰 외곽선·선택 외곽선, 왼쪽 변 배지 스택을,
/// 카드 아래에는 이름 줄을 그린다. 그리드는 셀을 카드와 같게 잡고 이름 줄만큼 행 간격을 둔다.
class StudentGridCardOverlayPainter extends CustomPainter {
  const StudentGridCardOverlayPainter({
    required this.students,
    required this.ownedIds,
    required this.columns,
    required this.rows,
    required this.columnGap,
    required this.rowGap,
    required this.rowHorizontalOffsets,
    required this.contentPadding,
    required this.showAttributes,
    required this.showNames,
    required this.selectedIndex,
    this.selectedIndices = const {},
    required this.plannedIds,
    this.firstRow = 0,
    this.lastRow,
    this.outlineColor = studentGridCardOutlineColor,
    this.selectionColor = studentGridCardSelectionColor,
    this.outlineWidthFraction = studentGridCardOutlineWidthFraction,
    this.selectionWidthFraction = studentGridCardSelectionWidthFraction,
  });

  final List<StudentCatalogEntry> students;
  final Set<String> ownedIds;
  final int columns;
  final int rows;
  final double columnGap;
  final double rowGap;
  final List<double> rowHorizontalOffsets;
  final EdgeInsets contentPadding;
  final bool showAttributes;

  /// 카드 밖 이름 줄. 켜면 카드 밑변 아래 [studentGridNameRect]에 그린다.
  final bool showNames;
  final int? selectedIndex;
  final Set<int> selectedIndices;
  final Set<String> plannedIds;
  final int firstRow;
  final int? lastRow;
  final Color outlineColor;
  final Color selectionColor;
  final double outlineWidthFraction;
  final double selectionWidthFraction;

  /// [index] 학생의 카드 rect(그리기와 같은 계산). 범위를 벗어나면 null.
  Rect? cardRectAt(Size size, int index) {
    if (index < 0 || index >= students.length) return null;
    final row = index ~/ columns;
    if (row >= rows) return null;
    final content = contentPadding.deflateRect(Offset.zero & size);
    final cellWidth = (content.width - columnGap * (columns - 1)) / columns;
    final cellHeight = (content.height - rowGap * (rows - 1)) / rows;
    final cell = Rect.fromLTWH(
      content.left +
          _rowOffset(row) +
          (index % columns) * (cellWidth + columnGap),
      content.top + row * (cellHeight + rowGap),
      cellWidth,
      cellHeight,
    );
    return studentGridCardFittedRect(cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final content = contentPadding.deflateRect(Offset.zero & size);
    final cellWidth = (content.width - columnGap * (columns - 1)) / columns;
    final cellHeight = (content.height - rowGap * (rows - 1)) / rows;
    // 외곽선 두께 기준은 셀의 짧은 변이다. DE 그리드는 셀 = 카드라서 카드 높이의 1%·2%가
    // 되고(시안 1.67 / 3.35), 1×1 초상 슬롯은 기존 두께를 유지한다.
    final strokeBase = math.min(cellWidth, cellHeight);
    final cards = <int, Rect>{};
    final visibleLastRow = math.min(rows, lastRow ?? rows);
    final firstIndex = math.min(
      students.length,
      math.max(0, firstRow) * columns,
    );
    final lastIndex = math.min(students.length, visibleLastRow * columns);
    for (var index = firstIndex; index < lastIndex; index++) {
      final fitted = cardRectAt(size, index);
      if (fitted == null) break;
      cards[index] = fitted;
      _paintCardOverlay(canvas, fitted, students[index]);
    }
    final outlinePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.0, strokeBase * outlineWidthFraction)
      ..color = outlineColor;
    for (final card in cards.values) {
      canvas.drawPath(studentGridCardPath(card), outlinePaint);
    }
    final selections = {...selectedIndices, ?selectedIndex};
    for (final selected in selections) {
      final selectedCard = cards[selected];
      if (selectedCard == null) continue;
      canvas.drawPath(
        studentGridCardPath(selectedCard),
        Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = math.max(1.0, strokeBase * selectionWidthFraction)
          ..color = selectionColor,
      );
    }
    for (final entry in cards.entries) {
      final student = students[entry.key];
      final owned = ownedIds.contains(student.studentId);
      for (final placement in studentGridStatusBadgeStack(
        entry.value,
        owned: owned,
        planned: plannedIds.contains(student.studentId),
        jpOnly: student.jpOnly,
      )) {
        paintStudentPortraitStatusBadge(
          canvas,
          placement.rect,
          placement.badge.label,
        );
      }
      if (showNames) {
        paintStudentGridName(
          canvas,
          entry.value,
          student.displayName,
          owned: owned,
        );
      }
    }
  }

  double _rowOffset(int row) =>
      row < rowHorizontalOffsets.length ? rowHorizontalOffsets[row] : 0;

  void _paintCardOverlay(
    Canvas canvas,
    Rect card,
    StudentCatalogEntry student,
  ) {
    canvas.save();
    canvas.clipPath(studentGridCardPath(card), doAntiAlias: true);
    if (showAttributes) {
      paintStudentAttributeChips(canvas, card, studentAttributeChips(student));
    }
    if (!ownedIds.contains(student.studentId)) {
      paintUnownedStudentPortraitStatus(canvas, card, showBadge: false);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(StudentGridCardOverlayPainter oldDelegate) =>
      oldDelegate.students != students ||
      oldDelegate.ownedIds != ownedIds ||
      oldDelegate.columns != columns ||
      oldDelegate.rows != rows ||
      oldDelegate.columnGap != columnGap ||
      oldDelegate.rowGap != rowGap ||
      oldDelegate.rowHorizontalOffsets != rowHorizontalOffsets ||
      oldDelegate.contentPadding != contentPadding ||
      oldDelegate.showAttributes != showAttributes ||
      oldDelegate.showNames != showNames ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.selectedIndices != selectedIndices ||
      oldDelegate.plannedIds != plannedIds ||
      oldDelegate.firstRow != firstRow ||
      oldDelegate.lastRow != lastRow ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.selectionColor != selectionColor ||
      oldDelegate.outlineWidthFraction != outlineWidthFraction ||
      oldDelegate.selectionWidthFraction != selectionWidthFraction;
}

/// 속성 글자 칩 글자 스타일(카드 높이에 따라 크기만 바뀐다).
TextStyle studentAttributeChipTextStyle(double chipHeight) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  color: Colors.white,
  fontSize: chipHeight * studentAttributeChipFontFraction,
  fontWeight: FontWeight.w800,
  height: 1,
);

/// 칩 [chips]를 카드 오른쪽 위에 계단으로 그린다. 카드 clip 안에서 부른다.
/// 그린 칩 상자(기울이기 전)를 돌려준다.
List<Rect> paintStudentAttributeChips(
  Canvas canvas,
  Rect card,
  List<({String label, Color color})> chips,
) {
  final height = studentAttributeChipHeight(card);
  final padding = height * studentAttributeChipPaddingFraction;
  final boxes = <Rect>[];
  for (var slot = 0; slot < chips.length; slot++) {
    final chip = chips[slot];
    final text = TextPainter(
      text: TextSpan(
        text: chip.label,
        style: studentAttributeChipTextStyle(height),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final box = studentAttributeChipBox(card, slot, text.width + padding * 2);
    final path = skewBoxPath(
      box.size,
      radius: studentAttributeChipRadius,
    ).shift(box.topLeft);
    canvas.drawPath(
      path.shift(const Offset(0, 1)),
      Paint()
        ..color = studentAttributeChipShadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
    );
    canvas.drawPath(path, Paint()..color = chip.color);
    text.paint(
      canvas,
      Offset(
        box.center.dx - text.width / 2,
        box.center.dy - text.height / 2,
      ),
    );
    boxes.add(box);
  }
  return boxes;
}

/// 이름 글자 스타일. 미보유는 흐리게(FD-043).
TextStyle studentGridNameTextStyle({required bool owned}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  color: owned ? studentGridOwnedNameColor : studentGridUnownedNameColor,
  fontSize: studentGridNameFontSize,
  fontWeight: FontWeight.w700,
  height: 1,
);

/// 카드 밖 이름 줄을 [studentGridNameRect]의 가운데에 그린다(넘치면 말줄임).
void paintStudentGridName(
  Canvas canvas,
  Rect card,
  String name, {
  required bool owned,
}) {
  final rect = studentGridNameRect(card);
  if (rect.width <= 0) return;
  final painter = TextPainter(
    text: TextSpan(text: name, style: studentGridNameTextStyle(owned: owned)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: rect.width);
  painter.paint(
    canvas,
    Offset(
      rect.left + (rect.width - painter.width) / 2,
      rect.top + (rect.height - painter.height) / 2,
    ),
  );
}

/// 학생 화면의 사선 스크롤바: 공용 [DiagonalScrollbar](FE2-a)에 학생 화면 값을 넘긴다.
///
/// 포그는 [StudentViewportFog](키 `<keyPrefix>-fog`), 드래그는 레일 띠다.
class _StudentDiagonalScrollbar extends StatelessWidget {
  const _StudentDiagonalScrollbar({
    required this.controller,
    required this.keyPrefix,
    required this.child,
    this.fogColor,
  });

  final ScrollController controller;
  final String keyPrefix;
  final Widget child;
  final Color? fogColor;

  @override
  Widget build(BuildContext context) => DiagonalScrollbar(
    keyPrefix: keyPrefix,
    controller: controller,
    drag: DiagonalScrollbarDrag.rail,
    fogBuilder: (context, visibility) => StudentViewportFog(
      key: ValueKey('$keyPrefix-fog'),
      showTop: visibility.showTop,
      showBottom: visibility.showBottom,
      color: fogColor,
    ),
    child: child,
  );
}

/// 학생 스크롤바 레일 점. 공용 [diagonalScrollbarTrackPoint]와 같은 식이다.
Offset studentScrollbarTrackPoint(
  Size size,
  double y, {
  double trackInset = 10,
}) => diagonalScrollbarTrackPoint(size, y, trackInset: trackInset);

/// 학생 스크롤바 드래그 띠. 공용 [diagonalScrollbarDragPath]와 같다.
Path studentScrollbarDragPath(
  Size size, {
  double trackInset = 10,
  double hitSlop = 8,
}) => diagonalScrollbarDragPath(
  size,
  trackInset: trackInset,
  hitSlop: hitSlop,
);

class _ContainerBoundsClipper extends CustomClipper<Path> {
  _ContainerBoundsClipper(this.id, this.canvasSize);

  final String id;
  final Size canvasSize;

  @override
  Path getClip(Size size) {
    final path = studentContainerPath(canvasSize, id)!;
    return path.shift(-path.getBounds().topLeft);
  }

  @override
  bool shouldReclip(_ContainerBoundsClipper oldClipper) =>
      oldClipper.id != id || oldClipper.canvasSize != canvasSize;
}

class _LocalPathClipper extends CustomClipper<Path> {
  const _LocalPathClipper(this.path);
  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_LocalPathClipper oldClipper) => oldClipper.path != path;
}
