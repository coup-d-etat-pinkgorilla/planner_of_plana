import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../studio/section_template.dart';
import '../studio/student_studio_layout.dart';
import 'animated_section_stack.dart';
import 'asset_image_grid.dart';
import 'ba_triangle_background.dart';
import 'bond_rank_portrait.dart';
import 'lifted_path_shadow.dart';
import 'scroll_viewport_fog.dart';
import 'section_template_surface.dart';

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
const studentSectionOpacity = 0.76;
const studentViewportFogExtent = scrollViewportFogExtent;
const studentFilterResetButtonSize = 44.0;
const studentSortAccentColor = Color(0xffe9b0ee);
const studentSortCompactFontSize = 15.0;
const studentSortMenuFontSize = 18.0;
const studentGridDisplayToggleFontSize = 16.5;
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

bool studentMatchesCatalogFilters(
  StudentCatalogEntry student,
  Map<String, Set<String>> selected,
) {
  for (final definition in studentFilterDefinitions) {
    final values = selected[definition.key];
    if (values == null || values.isEmpty) continue;
    final value = definition.read(student);
    if (value == null || !values.contains(value)) return false;
  }
  return true;
}

double studentStarSegmentDepth(Rect rect) =>
    math.min(rect.width * 0.45, rect.height / math.tan(80 * math.pi / 180));

Path studentStarSegmentPath(Rect rect) {
  final depth = studentStarSegmentDepth(rect);
  return buildRoundedSectionPolygon([
    Offset(rect.left + depth, rect.top),
    rect.topRight,
    Offset(rect.right - depth, rect.bottom),
    rect.bottomLeft,
  ], radius: 3);
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
  final tangent = math.tan(80 * math.pi / 180);
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
  final depth = rect.height / math.tan(80 * math.pi / 180);
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

List<Offset> studentFilterSectionPolygon(Size size) {
  final actionSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-1',
  );
  final filterSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-2',
  );
  final actionRect = sectionCanvasElementRect(size, actionSection);
  final rect = sectionCanvasElementRect(size, filterSection);
  final depth = rect.height / math.tan(80 * math.pi / 180);
  final leftTop = actionRect.right + studentSectionBevelGap;
  final originalTopRight = Offset(rect.right + depth, rect.top);
  final bottomLeft = Offset(leftTop - depth, rect.bottom);
  final reducedEdgeLength = (originalTopRight.dx - leftTop) / 2;
  return [
    Offset(leftTop, rect.top),
    Offset(leftTop + reducedEdgeLength, rect.top),
    Offset(bottomLeft.dx + reducedEdgeLength, rect.bottom),
    bottomLeft,
  ];
}

double studentListSectionEdgeLength(Size size) {
  final actionSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-1',
  );
  final listSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-2',
  );
  final actionRect = sectionCanvasElementRect(size, actionSection);
  final rect = sectionCanvasElementRect(size, listSection);
  final depth = rect.height / math.tan(80 * math.pi / 180);
  return rect.right + depth - (actionRect.right + studentSectionBevelGap);
}

Path studentFilterSectionPath(Size size) {
  final raw = buildRoundedSectionPolygon(
    studentFilterSectionPolygon(size),
    radius: 8,
  );
  final canvasBounds = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
    );
  return Path.combine(PathOperation.intersect, raw, canvasBounds);
}

(double, double) studentFilterSectionHorizontalInterval(Size size, double y) {
  final polygon = studentFilterSectionPolygon(size);
  final bottom = polygon[3].dy;
  final clampedY = y.clamp(polygon[0].dy, bottom);
  final shift = (bottom - clampedY) / math.tan(80 * math.pi / 180);
  return (polygon[3].dx + shift, polygon[2].dx + shift);
}

List<Offset> studentFilterContainerPolygon(Size size) {
  final sectionPolygon = studentFilterSectionPolygon(size);
  final sectionTop = sectionPolygon[0].dy;
  final sectionBottom = sectionPolygon[3].dy;
  final sectionHeight = sectionBottom - sectionTop;
  final bottomReserve = studentFilterResetButtonSize + 16;
  final top = sectionTop + 10;
  final bottom = math.max(
    top + 40,
    sectionBottom - math.min(bottomReserve, sectionHeight * 0.22),
  );
  final topInterval = studentFilterSectionHorizontalInterval(size, top);
  final bottomInterval = studentFilterSectionHorizontalInterval(size, bottom);
  return [
    Offset(topInterval.$1 + 10, top),
    Offset(topInterval.$2 - 10, top),
    Offset(bottomInterval.$2 - 10, bottom),
    Offset(bottomInterval.$1 + 10, bottom),
  ];
}

Path studentFilterContainerPath(Size size) {
  return buildRoundedSectionPolygon(
    studentFilterContainerPolygon(size),
    radius: 10,
  );
}

double studentDiagonalRowHorizontalOffset({
  required double viewportHeight,
  required double rowTop,
  required double rowHeight,
  required double scrollOffset,
}) {
  final bottomViewportY = rowTop + rowHeight - scrollOffset;
  return (viewportHeight - bottomViewportY) / math.tan(80 * math.pi / 180);
}

double studentDiagonalFilterRowWidth({
  required double viewportWidth,
  required double viewportHeight,
  required double rowHeight,
  required double horizontalInset,
  required double scrollbarReserve,
}) {
  final tangent = math.tan(80 * math.pi / 180);
  return math.max(
    120.0,
    viewportWidth -
        horizontalInset * 2 -
        scrollbarReserve -
        (viewportHeight - rowHeight) / tangent,
  );
}

double studentFilterGroupContentInset(double height) =>
    height / math.tan(80 * math.pi / 180) + 8;

bool studentFoundationUsesLegacySectionChildren({
  required bool filterSection,
  required String parentSectionId,
}) => !(filterSection && parentSectionId == 'element-2');

Path studentFilterResetPath(Size size) {
  final polygon = studentFilterSectionPolygon(size);
  final section = studentFilterSectionPath(size).getBounds();
  final bottomRight = polygon[2].dx;
  final rect = Rect.fromLTWH(
    bottomRight - studentFilterResetButtonSize - 12,
    section.bottom - studentFilterResetButtonSize - 8,
    studentFilterResetButtonSize,
    studentFilterResetButtonSize,
  );
  final depth = rect.height / math.tan(80 * math.pi / 180);
  return buildRoundedSectionPolygon([
    Offset(rect.left + depth, rect.top),
    rect.topRight,
    Offset(rect.right - depth, rect.bottom),
    rect.bottomLeft,
  ], radius: 7);
}

List<StudioContainerElement> studentRuntimeContainers(Size size) {
  final detailSection = studentStudioDocument.elements.firstWhere(
    (item) => item.id == 'element-3',
  );
  final detailRect = sectionCanvasElementRect(size, detailSection);
  final aspect = detailRect.height / detailRect.width;
  final source = studentStudioDocument.containers;
  final tangent = math.tan(80 * math.pi / 180);
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
      detailGapPixels / (detailRect.width * math.sin(80 * math.pi / 180));
  final c4Left =
      stackRightRail + c4RailGap - c4Source.bottom * aspect / tangent;
  final c4Rect = c4Source.copyWith(
    left: c4Left,
    width: c4Source.right - c4Left,
  );

  const actionInset = 0.06;
  const actionGap = 0.07;
  const actionLeft = 0.12;
  final actionRightInset = actionLeft / math.sin(80 * math.pi / 180);
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
  final actionHeight = (1 - actionInset * 2 - actionGap * 3 - sortHeight) / 3;

  return [
    for (final container in source)
      if (actionIds.contains(container.id))
        () {
          final top =
              actionInset +
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

StudioPlacementRect studentSortDropdownPlacement(Size size) {
  const actionInset = 0.06;
  const actionLeft = 0.12;
  final tangent = math.tan(80 * math.pi / 180);
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
  final top = actionInset;
  final rightInset = actionLeft / math.sin(80 * math.pi / 180);
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
    required this.searchController,
    required this.onSearchChanged,
    required this.onStudentSelected,
    required this.onAddToPlan,
    required this.onOpenScan,
    required this.onOpenFilter,
    this.active = true,
  });

  final List<StudentCatalogEntry> students;
  final Set<String> ownedIds;
  final String? selectedId;
  final StudentCatalogEntry? selectedStudent;
  final Map<String, dynamic>? selectedValues;
  final Map<String, Map<String, dynamic>> studentValuesById;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStudentSelected;
  final VoidCallback? onAddToPlan;
  final VoidCallback? onOpenScan;
  final VoidCallback? onOpenFilter;
  final bool active;

  @override
  State<StudentSectionLayout> createState() => _StudentSectionLayoutState();
}

class _StudentSectionLayoutState extends State<StudentSectionLayout>
    with TickerProviderStateMixin {
  static const _motionDuration = Duration(milliseconds: 360);
  late final AnimationController _section1Controller;
  late final AnimationController _listController;
  late final AnimationController _section3Controller;
  late final AnimationController _section4Controller;
  bool _showFilters = false;
  bool _switchingListSection = false;
  bool _showStudentAttributes = true;
  bool _showStudentNames = true;
  bool _hideUnownedStudents = false;
  bool _hideJpOnlyStudents = false;
  StudentGridSort _gridSort = StudentGridSort.nameAscending;
  final Map<String, Set<String>> _selectedCatalogFilters = {
    for (final definition in studentFilterDefinitions)
      definition.key: <String>{},
  };

  @override
  void initState() {
    super.initState();
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
    if (oldWidget.active != widget.active) {
      _setTabSectionsActive(widget.active);
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
    _section1Controller.dispose();
    _listController.dispose();
    _section3Controller.dispose();
    _section4Controller.dispose();
    super.dispose();
  }

  Future<void> _toggleFilterSection() async {
    if (_switchingListSection) return;
    setState(() => _switchingListSection = true);
    try {
      await _listController.reverse();
      if (!mounted) return;
      setState(() => _showFilters = !_showFilters);
      await _listController.forward();
      widget.onOpenFilter?.call();
    } on TickerCanceled {
      return;
    } finally {
      if (mounted) setState(() => _switchingListSection = false);
    }
  }

  void _toggleCatalogFilter(String key, String value) {
    setState(() {
      final values = _selectedCatalogFilters[key]!;
      values.contains(value) ? values.remove(value) : values.add(value);
    });
  }

  void _resetCatalogFilters() {
    setState(() {
      for (final values in _selectedCatalogFilters.values) {
        values.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.maxHeight.isFinite ? constraints.maxHeight : 660,
      );
      Rect containerBounds(String id) {
        return studentContainerPath(size, id)!.getBounds();
      }

      final listBounds = containerBounds('container-12');
      final filterBounds = studentFilterContainerPath(size).getBounds();
      final resetPath = studentFilterResetPath(size);
      final resetBounds = resetPath.getBounds();
      final portraitBounds = containerBounds('container-1');
      final searchBounds = containerBounds('container-14');
      final filteredGridStudents = widget.students
          .where(
            (student) =>
                (!_hideUnownedStudents ||
                    widget.ownedIds.contains(student.studentId)) &&
                (!_hideJpOnlyStudents || !student.jpOnly),
          )
          .where(
            (student) =>
                studentMatchesCatalogFilters(student, _selectedCatalogFilters),
          )
          .toList(growable: false);
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
                key: ValueKey(
                  _showFilters
                      ? 'student-section-5-motion'
                      : 'student-section-2-motion',
                ),
                animation: _listController,
                introDegrees: 80,
                outroDegrees: 260,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: CustomPaint(
                        key: ValueKey(
                          _showFilters
                              ? 'student-section-5-foundation'
                              : 'student-section-2-foundation',
                        ),
                        painter: _StudentSectionFoundationPainter(
                          selectedValues: widget.selectedValues,
                          sectionIds: const {'element-2'},
                          filterSection: _showFilters,
                        ),
                      ),
                    ),
                    if (_showFilters) ...[
                      Positioned.fromRect(
                        rect: filterBounds,
                        child: ClipPath(
                          clipper: _LocalPathClipper(
                            studentFilterContainerPath(
                              size,
                            ).shift(-filterBounds.topLeft),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              StudentDiagonalFilterList(
                                key: const ValueKey('student-filter-section-5'),
                                students: widget.students,
                                selected: _selectedCatalogFilters,
                                onToggle: _toggleCatalogFilter,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fromRect(
                        rect: resetBounds,
                        child: Tooltip(
                          message: '필터 초기화',
                          child: ClipPath(
                            clipper: _LocalPathClipper(
                              resetPath.shift(-resetBounds.topLeft),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: const ValueKey('student-filter-reset'),
                                onTap: _resetCatalogFilters,
                                child: const Icon(
                                  Icons.restart_alt_rounded,
                                  size: 23,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else
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
                              StudentDiagonalGrid(
                                students: gridStudents,
                                ownedIds: widget.ownedIds,
                                studentValuesById: widget.studentValuesById,
                                selectedId: widget.selectedId,
                                showAttributes: _showStudentAttributes,
                                showNames: _showStudentNames,
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
                            value: _hideUnownedStudents,
                            onChanged: (value) =>
                                setState(() => _hideUnownedStudents = value),
                          ),
                          _StudentGridDisplayToggle(
                            key: const ValueKey('student-toggle-hide-jp-only'),
                            label: '일본 서버 전용 숨김',
                            value: _hideJpOnlyStudents,
                            onChanged: (value) =>
                                setState(() => _hideJpOnlyStudents = value),
                          ),
                        ],
                      ),
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
                      child: ClipPath(
                        clipper: _ContainerBoundsClipper('container-1', size),
                        child: AssetImageGrid(
                          key: const ValueKey('student-focused-portrait'),
                          items: [
                            AssetImageGridItem(
                              asset: bondRankPortraitBackgroundAsset(
                                widget.selectedValues?['bond_rank'] as int?,
                              ),
                              column: 0,
                              row: 0,
                            ),
                            if (widget.selectedId != null)
                              AssetImageGridItem(
                                asset:
                                    'assets/student_portraits/${widget.selectedId}.png',
                                column: 0,
                                row: 0,
                                scale: 0.98,
                                clipRadiusFraction: 0.08,
                              ),
                          ],
                        ),
                      ),
                    ),
                    _StudentStatusIndicators(
                      canvasSize: size,
                      student:
                          widget.selectedStudent ??
                          widget.students
                              .cast<StudentCatalogEntry?>()
                              .firstWhere(
                                (student) =>
                                    student?.studentId == widget.selectedId,
                                orElse: () => null,
                              ),
                      values: widget.selectedValues,
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
                    _StudentActionButton(
                      canvasSize: size,
                      containerId: 'container-16',
                      key: const ValueKey('student-add-to-plan'),
                      tooltip: '포커스 학생으로 계획 열기',
                      icon: Icons.playlist_add_rounded,
                      onPressed: widget.selectedId == null
                          ? null
                          : widget.onAddToPlan,
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
                      tooltip: _showFilters ? '학생 목록 열기' : '필터 열기',
                      icon: _showFilters
                          ? Icons.groups_2_outlined
                          : Icons.tune_rounded,
                      onPressed: _switchingListSection
                          ? null
                          : _toggleFilterSection,
                    ),
                    _StudentSortDropdown(
                      canvasSize: size,
                      value: _gridSort,
                      onChanged: (value) => setState(() => _gridSort = value),
                    ),
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
  final curved = Curves.easeInOutCubic.transform(
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
  });

  final Size canvasSize;
  final String containerId;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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

Offset studentActionIconCenter(Rect bounds) {
  final y = bounds.height / 2;
  final cutAtY = y / math.tan(80 * math.pi / 180);
  final horizontalLength = math.max(0.0, bounds.width - cutAtY);
  return Offset(horizontalLength / 2, y);
}

enum StudentContainerTextureRole { none, status, action }

StudentContainerTextureRole studentContainerTextureRole(
  StudioContainerElement container,
) {
  if (container.parentSectionId == 'element-1') {
    return StudentContainerTextureRole.action;
  }
  if (container.triangleTexture ||
      container.id == 'container-2' ||
      container.id == 'container-12') {
    return StudentContainerTextureRole.status;
  }
  return StudentContainerTextureRole.none;
}

class _StudentStatusIndicators extends StatelessWidget {
  const _StudentStatusIndicators({
    required this.canvasSize,
    required this.student,
    required this.values,
  });

  final Size canvasSize;
  final StudentCatalogEntry? student;
  final Map<String, dynamic>? values;

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
          _StudentLevelStatus(
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
          _StudentSkillStatus(
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
          _StudentEquipmentStatus(
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
          _StudentAbilityStatus(
            hp: _integer('stat_hp'),
            atk: _integer('stat_atk'),
            heal: _integer('stat_heal'),
          ),
        ),
        _container('container-9', const _StudentPotentialStatus()),
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
          (outerPath) =>
              _StudentBondStatus(bondRank: bondRank, outerPath: outerPath),
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
  return assetName == null
      ? null
      : 'assets/item_icons/school_logo/School_Icon_$assetName.png';
}

class _StudentLevelStatus extends StatelessWidget {
  const _StudentLevelStatus({
    required this.level,
    required this.schoolLogoAsset,
  });

  final int? level;
  final String? schoolLogoAsset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final railInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
      return CustomPaint(
        key: const ValueKey('student-detail-level-split'),
        painter: const _StudentLevelSplitPainter(),
        child: Row(
          children: [
            Expanded(
              flex: 7,
              child: Padding(
                padding: EdgeInsets.fromLTRB(railInset + 12, 6, 5, 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LEVEL',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontFamily: 'GyeonggiTitle',
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1,
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
            Expanded(
              flex: 3,
              child: Transform.translate(
                offset: const Offset(0, 5),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 8, 7, 2),
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
            ),
          ],
        ),
      );
    },
  );
}

class _StudentLevelSplitPainter extends CustomPainter {
  const _StudentLevelSplitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final splitTop = size.width * 0.73;
    final splitBottom = size.width * 0.67;
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
    canvas.drawPath(left, Paint()..color = const Color(0xff203243));
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
  bool shouldRepaint(_StudentLevelSplitPainter oldDelegate) => false;
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

class _StudentSkillStatus extends StatelessWidget {
  const _StudentSkillStatus({required this.values});

  static const _labels = ['EX', 'Normal', 'Passive', 'Sub-skill'];
  final List<String> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: EdgeInsets.fromLTRB(
        constraints.maxHeight / math.tan(80 * math.pi / 180) + 9,
        7,
        constraints.maxHeight / math.tan(80 * math.pi / 180) + 9,
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
  final run = (bottom - top) / math.tan(80 * math.pi / 180);
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

class _StudentAbilityStatus extends StatelessWidget {
  const _StudentAbilityStatus({
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
      final railInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
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

class _StudentEquipmentStatus extends StatelessWidget {
  const _StudentEquipmentStatus({
    required this.student,
    required this.tiers,
    required this.levels,
    required this.favoriteItem,
    required this.favoriteItemLocked,
  });

  final StudentCatalogEntry? student;
  final List<String?> tiers;
  final List<int?> levels;
  final String favoriteItem;
  final bool favoriteItemLocked;

  String? _assetPath(int index) {
    final equipmentType = switch (index) {
      0 => student?.equipmentSlot1,
      1 => student?.equipmentSlot2,
      _ => student?.equipmentSlot3,
    };
    final match = RegExp(r'^T(\d+)$').firstMatch(tiers[index] ?? '');
    final tier = int.tryParse(match?.group(1) ?? '');
    if (equipmentType == null || tier == null || tier < 1 || tier > 10) {
      return null;
    }
    return 'assets/item_icons/equipment/'
        'Equipment_Icon_${equipmentType}_Tier$tier.png';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final railInset = constraints.maxHeight / math.tan(80 * math.pi / 180);
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
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
    ],
  );
}

class _StudentPotentialStatus extends StatelessWidget {
  const _StudentPotentialStatus();

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
  final railRun = height / math.tan(80 * math.pi / 180);
  final normalizedCenter = (index + 0.5) / itemCount;
  return -railRun * normalizedCenter;
}

double studentCombatDividerOffset({
  required double height,
  required int index,
  int itemCount = 4,
}) {
  if (height <= 0 || itemCount <= 0) return 0;
  final railRun = height / math.tan(80 * math.pi / 180);
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
      final railRun = constraints.maxHeight / math.tan(80 * math.pi / 180);
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

class _StudentBondStatus extends StatelessWidget {
  const _StudentBondStatus({required this.bondRank, required this.outerPath});

  final int? bondRank;
  final Path outerPath;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final rankRect = studentBondRankRect(size);
      return Stack(
        children: [
          CustomPaint(
            key: const ValueKey('student-detail-bond-gauge'),
            size: size,
            painter: _StudentTriangleBondGaugePainter(
              rank: bondRank,
              outerPath: outerPath,
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

Rect studentBondRankRect(Size size) {
  final points = studentBondOuterTrianglePoints(size);
  final bottomY = points.map((point) => point.dy).reduce(math.max);
  final bottomPoints = points
      .where((point) => (point.dy - bottomY).abs() < 0.001)
      .toList(growable: false);
  final left = bottomPoints.map((point) => point.dx).reduce(math.min);
  final right = bottomPoints.map((point) => point.dx).reduce(math.max);
  final bottomGap = math.max(7.0, size.height * 0.035);
  final height = math.min(46.0, size.height * 0.16);
  final horizontalInset = math.min(8.0, (right - left) * 0.12);
  final leftShift = studentBondRankLeftShift(size);
  return Rect.fromLTWH(
    left + horizontalInset - leftShift,
    bottomY - bottomGap - height,
    math.max(1, right - left - horizontalInset * 2),
    height,
  );
}

double studentBondRankLeftShift(Size size) =>
    math.max(3.0, math.min(8.0, size.width * 0.10));

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

Path studentBondGaugeHostPath(Size size, Path outerPath) {
  final bottom = studentBondRankRect(size).top - studentBondGaugeRankGap(size);
  final outerBounds = outerPath.getBounds();
  final span = _studentPathHorizontalSpan(outerPath, bottom - 0.01);
  final radius = math.min(
    studentBondGaugeBottomRadius(size),
    math.max(0.0, (span.right - span.left) / 2),
  );
  final roundedBottomMask = Path()
    ..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(span.left, outerBounds.top, span.right, bottom),
        bottomLeft: Radius.circular(radius),
        bottomRight: Radius.circular(radius),
      ),
    );
  return Path.combine(PathOperation.intersect, outerPath, roundedBottomMask);
}

class _StudentTriangleBondGaugePainter extends CustomPainter {
  const _StudentTriangleBondGaugePainter({
    required this.rank,
    required this.outerPath,
  });

  final int? rank;
  final Path outerPath;

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
    final gauge = studentBondGaugeHostPath(size, outerPath);
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
    final progress = ((rank ?? 0) / 100).clamp(0.0, 1.0);
    if (progress > 0) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          bounds.left,
          bounds.bottom - bounds.height * progress,
          bounds.right,
          bounds.bottom,
        ),
      );
      _drawInsetPath(
        canvas,
        size,
        gauge,
        studentSortAccentColor.withValues(alpha: 0.78),
        inset + 0.5,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StudentTriangleBondGaugePainter oldDelegate) =>
      oldDelegate.rank != rank || oldDelegate.outerPath != outerPath;
}

class _StudentSectionFoundationPainter extends CustomPainter {
  const _StudentSectionFoundationPainter({
    required this.selectedValues,
    required this.sectionIds,
    this.filterSection = false,
  });

  final Map<String, dynamic>? selectedValues;
  final Set<String> sectionIds;
  final bool filterSection;

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
      final path = filterSection && section.id == 'element-2'
          ? studentFilterSectionPath(size)
          : studentSectionPath(size, section.id);
      paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
      if (filterSection && section.id == 'element-2') {
        final containerPath = studentFilterContainerPath(size);
        canvas.drawPath(
          Path.combine(PathOperation.difference, path, containerPath),
          Paint()
            ..color = AppColors.surface.withValues(alpha: studentSectionOpacity)
            ..style = PaintingStyle.fill,
        );
        canvas.save();
        canvas.clipPath(containerPath, doAntiAlias: true);
        BATriangleTexturePainter(_studentTexture).paint(canvas, size);
        canvas.restore();
        canvas.drawPath(
          containerPath,
          Paint()
            ..color = AppColors.outline.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9,
        );
        final resetPath = studentFilterResetPath(size);
        canvas.save();
        canvas.clipPath(resetPath, doAntiAlias: true);
        BATriangleTexturePainter(_studentActionTexture).paint(canvas, size);
        canvas.restore();
        canvas.drawPath(
          resetPath,
          Paint()
            ..color = AppColors.outline.withValues(alpha: 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9,
        );
        continue;
      }
      var fillPath = path;
      for (final container in studentRuntimeContainers(size)) {
        if (container.parentSectionId != section.id ||
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

    for (final container in studentRuntimeContainers(size)) {
      if (!sectionIds.contains(container.parentSectionId) ||
          !studentFoundationUsesLegacySectionChildren(
            filterSection: filterSection,
            parentSectionId: container.parentSectionId,
          )) {
        continue;
      }
      if (container.id == 'container-1' || container.id == 'container-3') {
        continue;
      }
      final path = studentContainerPath(size, container.id);
      if (path == null) continue;
      final textureRole = studentContainerTextureRole(container);
      if (textureRole != StudentContainerTextureRole.none) {
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
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.outline.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }

    // Container 2's four internal features intentionally stay flat-color.
    for (final feature in document.features) {
      final parentContainer = document.containers.firstWhere(
        (container) => container.id == feature.parentContainerId,
      );
      if (!sectionIds.contains(parentContainer.parentSectionId) ||
          !studentFoundationUsesLegacySectionChildren(
            filterSection: filterSection,
            parentSectionId: parentContainer.parentSectionId,
          )) {
        continue;
      }
      final path = studentFeaturePath(size, feature.id);
      if (path == null) continue;
      canvas.drawPath(
        path,
        Paint()..color = const Color(0xff203243).withValues(alpha: 0.98),
      );
    }

    if (sectionIds.contains('element-3')) {
      _paintStarIndicator(canvas, size);
    }
  }

  void _paintStarIndicator(Canvas canvas, Size size) {
    final bounds = studentContainerPath(size, 'container-3')!.getBounds();
    final gap = math.max(1.2, bounds.width * 0.006);
    final segmentWidth = (bounds.width - gap * 8) / 9;
    final studentStars = selectedValues?['student_star'] as int? ?? 0;
    final weaponStars = selectedValues?['weapon_star'] as int? ?? 0;
    for (var index = 0; index < 9; index++) {
      final left = bounds.left + index * (segmentWidth + gap);
      final rect = Rect.fromLTWH(left, bounds.top, segmentWidth, bounds.height);
      final path = studentStarSegmentPath(rect);
      final active = index < 5 ? index < studentStars : index - 5 < weaponStars;
      final activeColor = index < 5
          ? const Color(0xfff3c96b)
          : AppColors.primary;
      canvas.drawPath(
        path,
        Paint()
          ..color = active
              ? activeColor.withValues(alpha: 0.86)
              : AppColors.outline.withValues(alpha: 0.48),
      );
    }
  }

  @override
  bool shouldRepaint(_StudentSectionFoundationPainter oldDelegate) =>
      oldDelegate.selectedValues != selectedValues ||
      oldDelegate.sectionIds != sectionIds ||
      oldDelegate.filterSection != filterSection;
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
  });

  final bool showTop;
  final bool showBottom;

  @override
  Widget build(BuildContext context) => ScrollViewportFog(
    keyPrefix: 'student-viewport-fog',
    showTop: showTop,
    showBottom: showBottom,
  );
}

class StudentDiagonalFilterList extends StatefulWidget {
  const StudentDiagonalFilterList({
    super.key,
    required this.students,
    required this.selected,
    required this.onToggle,
  });

  final List<StudentCatalogEntry> students;
  final Map<String, Set<String>> selected;
  final void Function(String key, String value) onToggle;

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
    for (final definition in studentFilterDefinitions)
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
    final depth = size.height / math.tan(80 * math.pi / 180);
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

class StudentDiagonalGrid extends StatefulWidget {
  const StudentDiagonalGrid({
    super.key,
    required this.students,
    required this.ownedIds,
    required this.studentValuesById,
    required this.selectedId,
    required this.onSelected,
    this.showAttributes = true,
    this.showNames = true,
  });

  final List<StudentCatalogEntry> students;
  final Set<String> ownedIds;
  final Map<String, Map<String, dynamic>> studentValuesById;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final bool showAttributes;
  final bool showNames;

  @override
  State<StudentDiagonalGrid> createState() => _StudentDiagonalGridState();
}

class _StudentDiagonalGridState extends State<StudentDiagonalGrid> {
  static const _columns = 8;
  static const _gridGap = 4.8;
  static const _rowGap = 3.84;
  static const _gridInset = 8.0;
  static const _scrollbarReserve = 14.0;
  final ScrollController _controller = ScrollController();
  ImageStream? _squareStream;
  ImageStreamListener? _squareListener;
  ui.Image? _squareImage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_squareStream != null) return;
    final stream = const AssetImage(
      'assets/studio_features/square.png',
    ).resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (mounted) setState(() => _squareImage = info.image);
      },
      onError: (_, _) {
        if (mounted && _squareImage != null) {
          setState(() => _squareImage = null);
        }
      },
    );
    _squareStream = stream;
    _squareListener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    final listener = _squareListener;
    if (listener != null) _squareStream?.removeListener(listener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rows = math.max(1, (widget.students.length / _columns).ceil());
      final tangent = math.tan(80 * math.pi / 180);
      final trajectoryDepth = constraints.maxHeight / tangent;
      final cellSize = math.max(
        1.0,
        (constraints.maxWidth -
                _gridInset * 2 -
                trajectoryDepth -
                _scrollbarReserve -
                _gridGap * (_columns - 1)) /
            _columns,
      );
      final contentHeight =
          _gridInset * 2 + rows * cellSize + _rowGap * math.max(0, rows - 1);
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
              final offsets = List<double>.generate(rows, (row) {
                final centerY =
                    _gridInset +
                    row * (cellSize + _rowGap) +
                    cellSize / 2 -
                    scroll;
                return (constraints.maxHeight - centerY) / tangent;
              }, growable: false);
              final padding = EdgeInsets.fromLTRB(
                _gridInset,
                _gridInset,
                _gridInset + trajectoryDepth + _scrollbarReserve,
                _gridInset,
              );
              return SizedBox(
                height: contentHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AssetImageGrid(
                        key: const ValueKey('student-image-grid'),
                        items: [
                          for (
                            var index = 0;
                            index < widget.students.length;
                            index++
                          ) ...[
                            AssetImageGridItem(
                              asset: bondRankPortraitBackgroundAsset(
                                widget.studentValuesById[widget
                                        .students[index]
                                        .studentId]?['bond_rank']
                                    as int?,
                              ),
                              column: index % _columns,
                              row: index ~/ _columns,
                              scale: 1,
                            ),
                            AssetImageGridItem(
                              asset:
                                  'assets/student_portraits/${widget.students[index].studentId}.png',
                              column: index % _columns,
                              row: index ~/ _columns,
                              scale: 0.98,
                              clipRadiusFraction: 0.12,
                            ),
                          ],
                        ],
                        columns: _columns,
                        rows: rows,
                        columnGap: _gridGap,
                        rowGap: _rowGap,
                        rowHorizontalOffsets: offsets,
                        contentPadding: padding,
                        selectedCell: widget.selectedId == null
                            ? null
                            : widget.students.indexWhere(
                                (item) => item.studentId == widget.selectedId,
                              ),
                        selectionShapeAsset:
                            'assets/studio_features/square.png',
                        onCellTap: (index) {
                          if (index < widget.students.length) {
                            widget.onSelected(widget.students[index].studentId);
                          }
                        },
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          key: const ValueKey('student-card-overlay-grid'),
                          painter: StudentGridCardOverlayPainter(
                            students: widget.students,
                            squareImage: _squareImage,
                            columns: _columns,
                            rows: rows,
                            columnGap: _gridGap,
                            rowGap: _rowGap,
                            rowHorizontalOffsets: offsets,
                            contentPadding: padding,
                            showAttributes: widget.showAttributes,
                            showNames: widget.showNames,
                          ),
                        ),
                      ),
                    ),
                    ..._hitTargets(
                      constraints.maxWidth,
                      contentHeight,
                      _columns,
                      rows,
                      _gridGap,
                      _rowGap,
                      padding,
                      offsets,
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
  ) {
    final contentWidth = width - padding.horizontal;
    final cellWidth = (contentWidth - columnGap * (columns - 1)) / columns;
    final cellHeight =
        (height - padding.vertical - rowGap * math.max(0, rows - 1)) / rows;
    return [
      for (var index = 0; index < widget.students.length; index++)
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
            selected: widget.students[index].studentId == widget.selectedId,
            label: widget.students[index].displayName,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => widget.onSelected(widget.students[index].studentId),
            ),
          ),
        ),
    ];
  }
}

const studentCardInfoAreaFraction = 0.16;
const studentCardAttributeAreaFraction = 0.03;

Color studentAttackTypeColor(String? attackType) => switch (attackType) {
  'Explosive' => const Color(0xff920008),
  'Piercing' => const Color(0xffbd8901),
  'Mystic' => const Color(0xff226f9b),
  'Sonic' => const Color(0xff9945a8),
  'Break' ||
  'Demolition' ||
  'Disassembly' ||
  'Composite' => const Color(0xff228b22),
  _ => const Color(0xff5c6ea8),
};

Color studentDefenseTypeColor(String? defenseType) => switch (defenseType) {
  'Light' => studentAttackTypeColor('Explosive'),
  'Heavy' => studentAttackTypeColor('Piercing'),
  'Special' => studentAttackTypeColor('Mystic'),
  'Elastic' => studentAttackTypeColor('Sonic'),
  'Composite' => const Color(0xff228b22),
  _ => AppColors.outline,
};

class StudentGridCardOverlayPainter extends CustomPainter {
  const StudentGridCardOverlayPainter({
    required this.students,
    required this.squareImage,
    required this.columns,
    required this.rows,
    required this.columnGap,
    required this.rowGap,
    required this.rowHorizontalOffsets,
    required this.contentPadding,
    required this.showAttributes,
    required this.showNames,
  });

  final List<StudentCatalogEntry> students;
  final ui.Image? squareImage;
  final int columns;
  final int rows;
  final double columnGap;
  final double rowGap;
  final List<double> rowHorizontalOffsets;
  final EdgeInsets contentPadding;
  final bool showAttributes;
  final bool showNames;

  @override
  void paint(Canvas canvas, Size size) {
    final mask = squareImage;
    if (mask == null || size.isEmpty || (!showAttributes && !showNames)) {
      return;
    }
    final content = contentPadding.deflateRect(Offset.zero & size);
    final cellWidth = (content.width - columnGap * (columns - 1)) / columns;
    final cellHeight = (content.height - rowGap * (rows - 1)) / rows;
    final source = Rect.fromLTWH(
      0,
      0,
      mask.width.toDouble(),
      mask.height.toDouble(),
    );
    for (var index = 0; index < students.length; index++) {
      final column = index % columns;
      final row = index ~/ columns;
      if (row >= rows) break;
      final cell = Rect.fromLTWH(
        content.left + _rowOffset(row) + column * (cellWidth + columnGap),
        content.top + row * (cellHeight + rowGap),
        cellWidth,
        cellHeight,
      );
      final fitted = Alignment.center.inscribe(
        applyBoxFit(
          BoxFit.contain,
          Size(mask.width.toDouble(), mask.height.toDouble()),
          cell.size,
        ).destination,
        cell,
      );
      _paintCardOverlay(canvas, source, fitted, mask, students[index]);
    }
  }

  double _rowOffset(int row) =>
      row < rowHorizontalOffsets.length ? rowHorizontalOffsets[row] : 0;

  void _paintCardOverlay(
    Canvas canvas,
    Rect source,
    Rect card,
    ui.Image mask,
    StudentCatalogEntry student,
  ) {
    final infoTop = card.bottom - card.height * studentCardInfoAreaFraction;
    final attributeBottom =
        infoTop + card.height * studentCardAttributeAreaFraction;
    canvas.saveLayer(card, Paint());

    if (showNames) {
      canvas.drawRect(
        Rect.fromLTRB(card.left, infoTop, card.right, card.bottom),
        Paint()..color = const Color(0xb35b626b),
      );
    }
    if (showAttributes) {
      final topBounds = _rowBounds(card, infoTop);
      final bottomBounds = _rowBounds(card, attributeBottom);
      final topMiddle = (topBounds.$1 + topBounds.$2) / 2;
      final bottomMiddle = (bottomBounds.$1 + bottomBounds.$2) / 2;
      final attackPath = Path()
        ..moveTo(topBounds.$1, infoTop)
        ..lineTo(topMiddle, infoTop)
        ..lineTo(bottomMiddle, attributeBottom)
        ..lineTo(bottomBounds.$1, attributeBottom)
        ..close();
      final defensePath = Path()
        ..moveTo(topMiddle, infoTop)
        ..lineTo(topBounds.$2, infoTop)
        ..lineTo(bottomBounds.$2, attributeBottom)
        ..lineTo(bottomMiddle, attributeBottom)
        ..close();
      canvas.drawPath(
        attackPath,
        Paint()..color = studentAttackTypeColor(student.attackType),
      );
      canvas.drawPath(
        defensePath,
        Paint()..color = studentDefenseTypeColor(student.defenseType),
      );
    }
    if (showNames) {
      _paintName(canvas, card, attributeBottom, student.displayName);
    }

    canvas.drawImageRect(
      mask,
      source,
      card,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high
        ..blendMode = BlendMode.dstIn,
    );
    canvas.restore();
  }

  (double, double) _rowBounds(Rect card, double y) {
    final progress = ((y - card.top) / card.height).clamp(0.0, 1.0);
    final depth = card.height / math.tan(80 * math.pi / 180);
    return (card.left + (1 - progress) * depth, card.right - progress * depth);
  }

  void _paintName(Canvas canvas, Rect card, double top, String name) {
    final bottom = card.bottom;
    final topBounds = _rowBounds(card, top);
    final bottomBounds = _rowBounds(card, bottom);
    final left = math.max(topBounds.$1, bottomBounds.$1) + 1;
    final right = math.min(topBounds.$2, bottomBounds.$2) - 1;
    final height = math.max(1.0, bottom - top);
    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: Colors.white,
          fontSize: studentCardNameFontSize(height),
          fontWeight: FontWeight.w700,
          height: 1,
          shadows: const [
            Shadow(
              color: Color(0xaa000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(1.0, right - left));
    painter.paint(
      canvas,
      Offset(
        left + (right - left - painter.width) / 2,
        top + (height - painter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(StudentGridCardOverlayPainter oldDelegate) =>
      oldDelegate.students != students ||
      oldDelegate.squareImage != squareImage ||
      oldDelegate.columns != columns ||
      oldDelegate.rows != rows ||
      oldDelegate.columnGap != columnGap ||
      oldDelegate.rowGap != rowGap ||
      oldDelegate.rowHorizontalOffsets != rowHorizontalOffsets ||
      oldDelegate.contentPadding != contentPadding ||
      oldDelegate.showAttributes != showAttributes ||
      oldDelegate.showNames != showNames;
}

double studentCardNameFontSize(double nameAreaHeight) =>
    math.max(6.0, math.min(12.0, nameAreaHeight * 0.8));

class _StudentDiagonalScrollbar extends StatelessWidget {
  const _StudentDiagonalScrollbar({
    required this.controller,
    required this.keyPrefix,
    required this.child,
  });

  final ScrollController controller;
  final String keyPrefix;
  final Widget child;

  @override
  Widget build(BuildContext context) => ScrollConfiguration(
    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
    child: LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final size = constraints.biggest;
          final hasClients = controller.hasClients;
          final maxScroll = hasClients
              ? controller.position.maxScrollExtent
              : 0.0;
          final viewport = hasClients
              ? controller.position.viewportDimension
              : size.height;
          final offset = hasClients ? controller.offset : 0.0;
          final fogVisibility = hasClients
              ? studentViewportFogVisibility(
                  minScrollExtent: controller.position.minScrollExtent,
                  maxScrollExtent: controller.position.maxScrollExtent,
                  pixels: controller.position.pixels,
                )
              : (showTop: false, showBottom: false);
          const trackInset = 10.0;
          final trackHeight = math.max(1.0, size.height - trackInset * 2);
          final handleHeight = maxScroll <= 0
              ? trackHeight
              : math.max(28.0, trackHeight * viewport / (viewport + maxScroll));
          final travel = math.max(1.0, trackHeight - handleHeight);
          final trajectoryDepth = size.height / math.tan(80 * math.pi / 180);
          final handleTop =
              trackInset +
              travel *
                  (maxScroll <= 0 ? 0 : (offset / maxScroll).clamp(0.0, 1.0));
          final handleCenter = studentScrollbarTrackPoint(
            size,
            handleTop + handleHeight / 2,
            trackInset: trackInset,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned.fill(
                child: StudentViewportFog(
                  key: ValueKey('$keyPrefix-fog'),
                  showTop: fogVisibility.showTop,
                  showBottom: fogVisibility.showBottom,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: ValueKey('$keyPrefix-diagonal-scrollbar'),
                    painter: _StudentDiagonalScrollbarPainter(
                      offset: offset,
                      maxScrollExtent: maxScroll,
                      handleHeight: handleHeight,
                      trackInset: trackInset,
                    ),
                  ),
                ),
              ),
              Positioned(
                key: ValueKey('$keyPrefix-scrollbar-handle-center'),
                left: handleCenter.dx - 0.5,
                top: handleCenter.dy - 0.5,
                width: 1,
                height: 1,
                child: const IgnorePointer(),
              ),
              if (maxScroll > 0)
                Positioned(
                  left: math.max(0, size.width - trajectoryDepth - 24),
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    key: ValueKey('$keyPrefix-diagonal-scrollbar-drag'),
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) {
                      controller.jumpTo(
                        (controller.offset +
                                details.delta.dy * maxScroll / travel)
                            .clamp(0.0, maxScroll),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

Offset studentScrollbarTrackPoint(
  Size size,
  double y, {
  double trackInset = 10,
}) {
  final tangent = math.tan(80 * math.pi / 180);
  final depth = size.height / tangent;
  final clampedY = y.clamp(0.0, size.height);
  return Offset(
    size.width - trackInset - depth + (size.height - clampedY) / tangent,
    clampedY,
  );
}

class _StudentDiagonalScrollbarPainter extends CustomPainter {
  const _StudentDiagonalScrollbarPainter({
    required this.offset,
    required this.maxScrollExtent,
    required this.handleHeight,
    required this.trackInset,
  });

  final double offset;
  final double maxScrollExtent;
  final double handleHeight;
  final double trackInset;

  Path _segment(Size size, double top, double bottom) {
    final start = studentScrollbarTrackPoint(size, top, trackInset: trackInset);
    final end = studentScrollbarTrackPoint(
      size,
      bottom,
      trackInset: trackInset,
    );
    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trackBottom = size.height - trackInset;
    canvas.drawPath(
      _segment(size, trackInset, trackBottom),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.outline.withValues(alpha: 0.48),
    );
    if (maxScrollExtent <= 0) return;
    final travel = math.max(0.0, trackBottom - trackInset - handleHeight);
    final top =
        trackInset + travel * (offset / maxScrollExtent).clamp(0.0, 1.0);
    canvas.drawPath(
      _segment(size, top, top + handleHeight),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xffe5a0ea),
    );
  }

  @override
  bool shouldRepaint(_StudentDiagonalScrollbarPainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.maxScrollExtent != maxScrollExtent ||
      oldDelegate.handleHeight != handleHeight ||
      oldDelegate.trackInset != trackInset;
}

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
