import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../../services/repository_service.dart';
import '../models/planning_models.dart';
import '../studio/section_template.dart';
import 'animated_section_stack.dart';
import 'ba_triangle_background.dart';
import 'lifted_path_shadow.dart';
import 'section_template_surface.dart';
import 'student_range_condition_section.dart';
import 'student_section_layout.dart';

const planStudentSelectorGridColumns = 4;
const planStudentSelectorGridWidthFraction = 0.36;
const planStudentSelectorSectionGap = 24.0;
const planStudentSelectorFilterWidthScale = 0.5;
const planStudentSelectorInnerInset = 10.0;
const planStudentSelectorFilterButtonHeight = 40.0;
const planStudentSelectorFilterControlGap = 8.0;
const planStudentSelectorFilterContentInset = 12.0;
const planStudentSelectorMotionDuration = Duration(milliseconds: 360);
const planStudentSelectorIntroDegrees = 80.0;
const planStudentSelectorOutroDegrees = 260.0;
const planStudentSelectorMotion = SectionMotionSpec(
  intro: planStudentSelectorIntroDegrees,
  outro: planStudentSelectorOutroDegrees,
);
const planStudentSelectorSectionOpacity = 0.76;
const planStudentSelectorSelectionWidth = 280.0;
const planStudentSelectorSelectionHeight = 112.0;
const planStudentSelectorConfirmTexture = titlePrimaryActionTexture;

Rect planStudentSelectorSelectionSectionRect(
  Size size, {
  required Rect section1Bounds,
}) {
  const outerInset = 16.0;
  final width = math.min(
    planStudentSelectorSelectionWidth,
    math.max(180.0, size.width * 0.22),
  );
  final height = math.min(
    planStudentSelectorSelectionHeight,
    section1Bounds.height,
  );
  return Rect.fromLTWH(
    size.width - outerInset - width,
    section1Bounds.bottom - height,
    width,
    height,
  );
}

Path planStudentSelectorSelectionSectionPath(Size size) {
  final depth = math.min(
    size.width * 0.32,
    size.height / math.tan(80 * math.pi / 180),
  );
  return buildRoundedSectionPolygon([
    Offset(depth, 0),
    Offset(size.width, 0),
    Offset(size.width, size.height),
    Offset(0, size.height),
  ], radius: 10);
}

({Rect grid, Rect filter, Rect condition}) planStudentSelectorSectionRects(
  Size size, {
  required Rect section1Bounds,
  required double section1RightAtReference,
}) {
  final top = section1Bounds.top;
  final bottom = section1Bounds.bottom;
  final depth = sectionTemplateCutDepth(bottom - top);
  final left =
      section1RightAtReference + planStudentSelectorSectionGap - depth / 2;
  final gridWidth = size.width * planStudentSelectorGridWidthFraction;
  final grid = Rect.fromLTRB(left, top, left + gridWidth, bottom);
  final filterLeft = grid.right + planStudentSelectorSectionGap - depth;
  final previousFilterRight = size.width * 0.985;
  final filterWidth =
      (previousFilterRight - filterLeft) * planStudentSelectorFilterWidthScale;
  final filter = Rect.fromLTRB(
    filterLeft,
    top,
    filterLeft + filterWidth,
    bottom,
  );
  final conditionLeft = filter.right + studentRangeConditionSectionGap - depth;
  return (
    grid: grid,
    filter: filter,
    condition: Rect.fromLTRB(conditionLeft, top, previousFilterRight, bottom),
  );
}

double planStudentSelectorReferenceY(Rect section1Bounds) =>
    section1Bounds.center.dy;

Path planStudentSelectorInnerPath(Size size) {
  final depth = planStudentSelectorDiagonalDepth(size);
  return buildRoundedSectionPolygon([
    Offset(depth, 0),
    Offset(size.width, 0),
    Offset(size.width - depth, size.height),
    Offset(0, size.height),
  ], radius: 10);
}

double planStudentSelectorDiagonalDepth(Size size) =>
    math.min(size.width * 0.42, size.height / math.tan(80 * math.pi / 180));

(double, double) planStudentSelectorOuterHorizontalInterval(
  Size size,
  double y,
) {
  final depth = sectionTemplateCutDepth(size.height);
  final progress = (y / size.height).clamp(0.0, 1.0).toDouble();
  return (depth * (1 - progress), size.width - depth * progress);
}

Rect planStudentSelectorFilterSearchRect(Size size) {
  const top = planStudentSelectorInnerInset;
  const bottom = top + planStudentSelectorFilterButtonHeight;
  final (left, right) = planStudentSelectorOuterHorizontalInterval(
    size,
    (top + bottom) / 2,
  );
  return Rect.fromLTRB(left + 12, top, right - 12, bottom);
}

Rect planStudentSelectorFilterResetRect(Size size) {
  final bottom = size.height - planStudentSelectorInnerInset;
  final top = bottom - planStudentSelectorFilterButtonHeight;
  final (left, right) = planStudentSelectorOuterHorizontalInterval(
    size,
    (top + bottom) / 2,
  );
  return Rect.fromLTRB(left + 12, top, right - 12, bottom);
}

Path planStudentSelectorFilterContainerPath(Size size) {
  final search = planStudentSelectorFilterSearchRect(size);
  final reset = planStudentSelectorFilterResetRect(size);
  final top = search.bottom + planStudentSelectorFilterControlGap;
  final bottom = reset.top - planStudentSelectorFilterControlGap;
  final (topLeft, topRight) = planStudentSelectorOuterHorizontalInterval(
    size,
    top,
  );
  final (bottomLeft, bottomRight) = planStudentSelectorOuterHorizontalInterval(
    size,
    bottom,
  );
  return buildRoundedSectionPolygon([
    Offset(topLeft + planStudentSelectorInnerInset, top),
    Offset(topRight - planStudentSelectorInnerInset, top),
    Offset(bottomRight - planStudentSelectorInnerInset, bottom),
    Offset(bottomLeft + planStudentSelectorInnerInset, bottom),
  ], radius: 10);
}

class PlanStudentSelector extends StatefulWidget {
  const PlanStudentSelector({
    super.key,
    required this.service,
    required this.plannedIds,
    required this.onConfirmed,
    required this.section1Bounds,
    required this.section1RightAtReference,
    required this.active,
  });

  final AppService service;
  final Set<String> plannedIds;
  final ValueChanged<List<PlanningStudentSeed>> onConfirmed;
  final Rect section1Bounds;
  final double section1RightAtReference;
  final bool active;

  @override
  State<PlanStudentSelector> createState() => _PlanStudentSelectorState();
}

class _PlanStudentSelectorState extends State<PlanStudentSelector>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final Map<String, Set<String>> _selectedFilters = {
    'ownership': <String>{},
    'plan_status': <String>{},
    for (final definition in studentFilterDefinitions)
      definition.key: <String>{},
  };
  late final AnimationController _gridController = _createMotionController();
  late final AnimationController _filterController = _createMotionController();
  List<StudentCatalogEntry> _students = const [];
  RepositoryState? _repositoryState;
  bool _loading = true;
  String? _error;
  StudentRangeConditions _rangeConditions = StudentRangeConditions.initial();
  final List<String> _selectedStudentIds = [];

  RepositoryService? get _repository => widget.service is RepositoryService
      ? widget.service as RepositoryService
      : null;

  AnimationController _createMotionController() => AnimationController(
    vsync: this,
    duration: planStudentSelectorMotionDuration,
    reverseDuration: planStudentSelectorMotionDuration,
  );

  Set<String> get _ownedIds => {
    for (final student
        in _repositoryState?.students ?? const <ConfirmedStudentState>[])
      student.studentId,
  };

  Map<String, Map<String, dynamic>> get _studentValuesById => {
    for (final student
        in _repositoryState?.students ?? const <ConfirmedStudentState>[])
      student.studentId: student.values,
  };

  List<StudentFilterDefinition> get _filterDefinitions => [
    StudentFilterDefinition(
      key: 'ownership',
      label: '보유 상태',
      read: (student) =>
          _ownedIds.contains(student.studentId) ? 'owned' : 'unowned',
    ),
    StudentFilterDefinition(
      key: 'plan_status',
      label: '계획 상태',
      read: (student) => widget.plannedIds.contains(student.studentId)
          ? 'planned'
          : 'unplanned',
    ),
    ...studentFilterDefinitions,
  ];

  @override
  void initState() {
    super.initState();
    if (widget.active) _setActive(true);
    _load();
  }

  @override
  void didUpdateWidget(PlanStudentSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _setActive(widget.active);
  }

  void _setActive(bool active) {
    for (final controller in [_gridController, _filterController]) {
      if (active) {
        controller.forward(from: controller.value);
      } else {
        controller.reverse(from: controller.value);
      }
    }
  }

  @override
  void dispose() {
    _gridController.dispose();
    _filterController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final students = await widget.service.listStudents();
      RepositoryState? repositoryState;
      final repository = _repository;
      if (repository != null) {
        final profiles = await repository.listProfiles();
        if (profiles.isNotEmpty) {
          final profile = profiles.firstWhere(
            (item) => item.selected,
            orElse: () => profiles.first,
          );
          repositoryState = await repository.loadRepositoryState(profile.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _students = students;
        _repositoryState = repositoryState;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '학생 목록을 불러오지 못했습니다: $error';
      });
    }
  }

  bool _matchesFilters(StudentCatalogEntry student) {
    for (final definition in _filterDefinitions) {
      final selected = _selectedFilters[definition.key];
      if (selected == null || selected.isEmpty) continue;
      final value = definition.read(student);
      if (value == null || !selected.contains(value)) return false;
    }
    return true;
  }

  bool _matchesRangeConditions(StudentCatalogEntry student) =>
      _rangeConditions.matchesStudent(
        student: student,
        currentValues: _studentValuesById[student.studentId] ?? const {},
        owned: _ownedIds.contains(student.studentId),
      );

  void _toggleFilter(String key, String value) {
    setState(() {
      final selected = _selectedFilters[key]!;
      selected.contains(value) ? selected.remove(value) : selected.add(value);
    });
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      for (final selected in _selectedFilters.values) {
        selected.clear();
      }
    });
  }

  void _toggleStudent(String studentId) {
    setState(() {
      if (_selectedStudentIds.contains(studentId)) {
        _selectedStudentIds.remove(studentId);
      } else {
        _selectedStudentIds.add(studentId);
      }
    });
  }

  void _confirmSelection() {
    if (_selectedStudentIds.isEmpty) return;
    widget.onConfirmed([
      for (final studentId in _selectedStudentIds)
        () {
          final student = _students.firstWhere(
            (entry) => entry.studentId == studentId,
          );
          final currentValues = _studentValuesById[studentId] ?? const {};
          return PlanningStudentSeed(
            handoffId:
                'plan-selector-$studentId-${DateTime.now().microsecondsSinceEpoch}',
            studentId: studentId,
            metadata: student.metadata,
            currentValues: currentValues,
            owned: _ownedIds.contains(studentId),
          );
        }(),
    ]);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final sections = planStudentSelectorSectionRects(
        size,
        section1Bounds: widget.section1Bounds,
        section1RightAtReference: widget.section1RightAtReference,
      );
      final gridRect = sections.grid;
      final filterRect = sections.filter;
      final conditionRect = sections.condition;
      final selectionRect = planStudentSelectorSelectionSectionRect(
        size,
        section1Bounds: widget.section1Bounds,
      );
      final visible = sortStudentGridEntries(
        _students.where(
          (student) =>
              student.matches(_searchController.text) &&
              _matchesFilters(student) &&
              _matchesRangeConditions(student),
        ),
        StudentGridSort.nameAscending,
        _studentValuesById,
      );

      return Stack(
        key: const ValueKey('plan-student-selector'),
        children: [
          Positioned.fromRect(
            rect: gridRect,
            child: PlanStudentSelectorMotion(
              key: const ValueKey('plan-student-selector-grid-motion'),
              animation: _gridController,
              child: _PlanStudentSelectorSectionSurface(
                key: const ValueKey('plan-student-selector-grid-section'),
                child: Padding(
                  padding: const EdgeInsets.all(planStudentSelectorInnerInset),
                  child: _PlanStudentSelectorInnerContainer(
                    key: const ValueKey('plan-student-selector-grid-container'),
                    child: _buildGridBody(visible),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: selectionRect,
            child: PlanStudentSelectorMotion(
              key: const ValueKey('plan-student-selector-selection-motion'),
              animation: _filterController,
              child: _PlanStudentSelectionSection(
                selectedCount: _selectedStudentIds.length,
                onConfirm: _selectedStudentIds.isEmpty
                    ? null
                    : _confirmSelection,
              ),
            ),
          ),
          Positioned.fromRect(
            rect: filterRect,
            child: PlanStudentSelectorMotion(
              key: const ValueKey('plan-student-selector-filter-motion'),
              animation: _filterController,
              child: _PlanStudentSelectorSectionSurface(
                key: const ValueKey('plan-student-selector-filter-section'),
                child: _buildFilterSectionContent(),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: conditionRect,
            child: PlanStudentSelectorMotion(
              key: const ValueKey('plan-student-selector-condition-motion'),
              animation: _filterController,
              child: StudentRangeConditionSection(
                key: const ValueKey('plan-range-condition-section'),
                keyPrefix: 'plan-range-condition',
                conditions: _rangeConditions,
                onChanged: (conditions) =>
                    setState(() => _rangeConditions = conditions),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _buildFilterSectionContent() => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final searchRect = planStudentSelectorFilterSearchRect(size);
      final resetRect = planStudentSelectorFilterResetRect(size);
      final containerPath = planStudentSelectorFilterContainerPath(size);
      final containerBounds = containerPath.getBounds();
      return Stack(
        children: [
          Positioned.fromRect(
            rect: searchRect,
            child: TextField(
              key: const ValueKey('plan-student-selector-search'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 19),
                hintText: '학생 이름 검색',
              ),
            ),
          ),
          Positioned.fromRect(
            rect: containerBounds,
            child: _PlanStudentSelectorInnerContainer(
              key: const ValueKey('plan-student-selector-filter-container'),
              path: containerPath.shift(-containerBounds.topLeft),
              child: Padding(
                key: const ValueKey(
                  'plan-student-selector-filter-content-padding',
                ),
                padding: const EdgeInsets.all(
                  planStudentSelectorFilterContentInset,
                ),
                child: StudentDiagonalFilterList(
                  key: const ValueKey('plan-student-selector-filter-list'),
                  students: _students,
                  definitions: _filterDefinitions,
                  selected: _selectedFilters,
                  onToggle: _toggleFilter,
                  fogColor: studentSection2ContainerColor,
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: resetRect,
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('plan-student-selector-filter-reset'),
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('검색·필터 초기화'),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _buildGridBody(List<StudentCatalogEntry> visible) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
          ],
        ),
      );
    }
    if (visible.isEmpty) {
      return const Center(
        child: Text(
          '조건에 맞는 학생이 없습니다.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return StudentDiagonalGrid(
      key: const ValueKey('plan-student-selector-grid'),
      students: visible,
      ownedIds: _ownedIds,
      studentValuesById: _studentValuesById,
      plannedIds: widget.plannedIds,
      selectedId: null,
      selectedIds: _selectedStudentIds.toSet(),
      onSelected: _toggleStudent,
      columns: planStudentSelectorGridColumns,
    );
  }
}

class _PlanStudentSelectionSection extends StatelessWidget {
  const _PlanStudentSelectionSection({
    required this.selectedCount,
    required this.onConfirm,
  });

  final int selectedCount;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final path = planStudentSelectorSelectionSectionPath(constraints.biggest);
      final enabled = onConfirm != null;
      return Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            key: const ValueKey('plan-student-selector-selection-foundation'),
            painter: _PlanStudentSelectionSectionPainter(path),
          ),
          ClipPath(
            clipper: _PlanStudentSelectorPathClipper(path),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                constraints.maxHeight / math.tan(80 * math.pi / 180) + 14,
                12,
                12,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '선택된 학생 $selectedCount명',
                    key: const ValueKey('plan-student-selector-selected-count'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _PlanStudentSelectionConfirmButton(
                      enabled: enabled,
                      onPressed: onConfirm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PlanStudentSelectionConfirmButton extends StatelessWidget {
  const _PlanStudentSelectionConfirmButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final path = planStudentSelectorSelectionSectionPath(constraints.biggest);
      return Semantics(
        button: true,
        enabled: enabled,
        label: '선택된 학생 추가',
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _PlanStudentSelectionButtonPainter(
                path: path,
                enabled: enabled,
              ),
            ),
            ClipPath(
              clipper: _PlanStudentSelectorPathClipper(path),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey(
                    'plan-student-selector-confirm-selection',
                  ),
                  onTap: onPressed,
                  child: Center(
                    child: Text(
                      '선택된 학생 추가',
                      style: TextStyle(
                        color: enabled ? AppColors.text : AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
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

class _PlanStudentSelectionSectionPainter extends CustomPainter {
  const _PlanStudentSelectionSectionPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.drawPath(
      path,
      Paint()..color = AppColors.surface.withValues(alpha: 0.84),
    );
  }

  @override
  bool? hitTest(Offset position) => path.contains(position);

  @override
  bool shouldRepaint(_PlanStudentSelectionSectionPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _PlanStudentSelectionButtonPainter extends CustomPainter {
  const _PlanStudentSelectionButtonPainter({
    required this.path,
    required this.enabled,
  });

  final Path path;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(
      planStudentSelectorConfirmTexture,
    ).paint(canvas, size);
    if (!enabled) {
      canvas.drawColor(Colors.black.withValues(alpha: 0.28), BlendMode.srcOver);
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = enabled
            ? BATrianglePalette.softTitlePinkAccent
            : AppColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool? hitTest(Offset position) => path.contains(position);

  @override
  bool shouldRepaint(_PlanStudentSelectionButtonPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.enabled != enabled;
}

class PlanStudentSelectorMotion extends StatelessWidget {
  const PlanStudentSelectorMotion({
    super.key,
    required this.animation,
    required this.child,
    this.introDegrees = planStudentSelectorIntroDegrees,
    this.outroDegrees = planStudentSelectorOutroDegrees,
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
      builder: (context, constraints) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final curved = Curves.easeInOutCubic.transform(
            animation.value.clamp(0.0, 1.0).toDouble(),
          );
          final exiting = animation.status == AnimationStatus.reverse;
          final direction = sectionMotionOffset(
            constraints.biggest,
            exiting ? outroDegrees : introDegrees,
          );
          return Transform.translate(
            key: key == null ? null : ValueKey('$key-transform'),
            offset: direction * (exiting ? 1 - curved : -(1 - curved)),
            child: child,
          );
        },
      ),
    );
  }
}

class _PlanStudentSelectorSectionSurface extends StatelessWidget {
  const _PlanStudentSelectorSectionSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final path = buildSectionTemplatePath(
        constraints.biggest,
        SectionShape.bilateral,
      );
      return CustomPaint(
        key: ValueKey('$key-foundation'),
        painter: PlanStudentSelectorSectionPainter(path),
        child: ClipPath(
          key: ValueKey('$key-clip'),
          clipper: _PlanStudentSelectorPathClipper(path),
          clipBehavior: Clip.antiAlias,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      );
    },
  );
}

class PlanStudentSelectorSectionPainter extends CustomPainter {
  const PlanStudentSelectorSectionPainter(
    this.path, {
    this.shadow = defaultLiftedSectionShadow,
  });

  final Path path;
  final LiftedPathShadowSpec shadow;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, shadow);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.surface.withValues(
          alpha: planStudentSelectorSectionOpacity,
        )
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool? hitTest(Offset position) => path.contains(position);

  @override
  bool shouldRepaint(PlanStudentSelectorSectionPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.shadow != shadow;
}

class _PlanStudentSelectorInnerContainer extends StatelessWidget {
  const _PlanStudentSelectorInnerContainer({
    super.key,
    required this.child,
    this.path,
  });

  final Widget child;
  final Path? path;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final effectivePath =
          path ?? planStudentSelectorInnerPath(constraints.biggest);
      return CustomPaint(
        key: ValueKey('$key-foundation'),
        painter: _PlanStudentSelectorInnerPainter(effectivePath),
        child: ClipPath(
          key: ValueKey('$key-clip'),
          clipper: _PlanStudentSelectorPathClipper(effectivePath),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );
    },
  );
}

class _PlanStudentSelectorInnerPainter extends CustomPainter {
  const _PlanStudentSelectorInnerPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..color = studentSection2ContainerColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.68)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(_PlanStudentSelectorInnerPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _PlanStudentSelectorPathClipper extends CustomClipper<Path> {
  const _PlanStudentSelectorPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PlanStudentSelectorPathClipper oldClipper) =>
      oldClipper.path != path;
}
