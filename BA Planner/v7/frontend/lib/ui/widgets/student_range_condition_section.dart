import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/app_service.dart';
import '../models/planning_growth_rules.dart';
import '../models/planning_models.dart';
import 'lifted_path_shadow.dart';
import 'plan_element_builder.dart';
import 'section_template_surface.dart';

const studentRangeConditionSectionGap = 24.0;
const studentRangeConditionSectionInset = 12.0;
const studentRangeConditionArrowHeight = 34.0;
const studentRangeConditionCardGap = 8.0;
const studentRangeConditionCardDesignWidth = 680.0;

@immutable
class StudentRangeConditions {
  StudentRangeConditions({
    required this.lowerEnabled,
    required this.upperEnabled,
    required Map<String, int> lowerTargets,
    required Map<String, int> upperTargets,
  }) : lowerTargets = Map.unmodifiable(lowerTargets),
       upperTargets = Map.unmodifiable(upperTargets);

  factory StudentRangeConditions.initial() => StudentRangeConditions(
    lowerEnabled: false,
    upperEnabled: false,
    lowerTargets: planElementTargetMinimums,
    upperTargets: planElementTargetMaximums,
  );

  final bool lowerEnabled;
  final bool upperEnabled;
  final Map<String, int> lowerTargets;
  final Map<String, int> upperTargets;

  StudentRangeConditions copyWith({
    bool? lowerEnabled,
    bool? upperEnabled,
    Map<String, int>? lowerTargets,
    Map<String, int>? upperTargets,
  }) => StudentRangeConditions(
    lowerEnabled: lowerEnabled ?? this.lowerEnabled,
    upperEnabled: upperEnabled ?? this.upperEnabled,
    lowerTargets: lowerTargets ?? this.lowerTargets,
    upperTargets: upperTargets ?? this.upperTargets,
  );

  bool matchesStudent({
    required StudentCatalogEntry student,
    required Map<String, dynamic> currentValues,
    required bool owned,
  }) {
    if (!lowerEnabled && !upperEnabled) return true;
    final current = planElementCurrentTargets(
      PlanningStudentSeed(
        handoffId: 'range-condition-${student.studentId}',
        studentId: student.studentId,
        metadata: student.metadata,
        currentValues: currentValues,
        owned: owned,
      ),
    );
    for (final key in planElementTargetMinimums.keys) {
      final value = current[key] ?? planElementTargetMinimums[key]!;
      if (lowerEnabled && value < lowerTargets[key]!) return false;
      if (upperEnabled && value > upperTargets[key]!) return false;
    }
    return true;
  }
}

class StudentRangeConditionSection extends StatelessWidget {
  const StudentRangeConditionSection({
    super.key,
    required this.keyPrefix,
    required this.conditions,
    required this.onChanged,
  });

  final String keyPrefix;
  final StudentRangeConditions conditions;
  final ValueChanged<StudentRangeConditions> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final geometry = studentRangeConditionGeometry(size);
      return Stack(
        children: [
          Positioned.fromRect(
            rect: geometry.sectionBounds,
            child: CustomPaint(
              key: ValueKey('$keyPrefix-foundation'),
              painter: StudentRangeConditionSectionPainter(
                geometry.sectionPath,
              ),
              child: ClipPath(
                clipper: _RangeConditionPathClipper(geometry.sectionPath),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fromRect(
                      rect: geometry.lowerCardRect,
                      child: _conditionCard(
                        label: '이상 조건',
                        kind: 'lower',
                        enabled: conditions.lowerEnabled,
                        targets: conditions.lowerTargets,
                        defaults: planElementTargetMinimums,
                      ),
                    ),
                    Positioned.fromRect(
                      rect: geometry.arrowRect,
                      child: Icon(
                        Icons.swap_vert_rounded,
                        key: ValueKey('$keyPrefix-range-arrow'),
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    Positioned.fromRect(
                      rect: geometry.upperCardRect,
                      child: _conditionCard(
                        label: '이하 조건',
                        kind: 'upper',
                        enabled: conditions.upperEnabled,
                        targets: conditions.upperTargets,
                        defaults: planElementTargetMaximums,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _conditionCard({
    required String label,
    required String kind,
    required bool enabled,
    required Map<String, int> targets,
    required Map<String, int> defaults,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      const cardWidth = studentRangeConditionCardDesignWidth;
      final cardHeight = planPresetListCardHeight(
        cardWidth,
        layout: PlanPresetElementLayout.condition,
      );
      return Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: cardWidth,
            height: cardHeight,
            child: PlanPresetElementCard(
              key: ValueKey('$keyPrefix-$kind-card'),
              stage: PlanElementStageDraft(
                id: '$keyPrefix-$kind-condition',
                name: label,
                targets: targets,
              ),
              startTargets: targets,
              stageNumber: kind == 'lower' ? 1 : 2,
              selected: enabled,
              propagatedFields: const {},
              equipmentTypes: const [null, null, null],
              hasFavoriteItem: true,
              showStageNumber: false,
              layout: PlanPresetElementLayout.condition,
              headerLeading: _ConditionEnabledControl(
                key: ValueKey('$keyPrefix-$kind-enabled-control'),
                label: label,
                value: enabled,
                onChanged: (value) => onChanged(
                  kind == 'lower'
                      ? conditions.copyWith(lowerEnabled: value)
                      : conditions.copyWith(upperEnabled: value),
                ),
              ),
              headerTrailing: _ConditionResetButton(
                key: ValueKey('$keyPrefix-$kind-reset'),
                onPressed: () => onChanged(
                  kind == 'lower'
                      ? conditions.copyWith(lowerTargets: defaults)
                      : conditions.copyWith(upperTargets: defaults),
                ),
              ),
              // The explicit header checkbox owns condition activation. Keeping
              // card selection inert prevents nested checkbox/reset gestures from
              // toggling the condition a second time.
              onSelected: () {},
              onChanged: (field, value) {
                final minimum = planElementTargetMinimums[field] ?? 0;
                final maximum = planElementTargetMaximums[field] ?? value;
                final changed = normalizePlanningGrowthTargets(
                  {...targets, field: value.clamp(minimum, maximum).toInt()},
                  changedKeys: {field},
                  hasFavoriteItem: true,
                );
                onChanged(
                  kind == 'lower'
                      ? conditions.copyWith(lowerTargets: changed)
                      : conditions.copyWith(upperTargets: changed),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

@immutable
class StudentRangeConditionGeometry {
  const StudentRangeConditionGeometry({
    required this.sectionBounds,
    required this.sectionPath,
    required this.lowerCardRect,
    required this.arrowRect,
    required this.upperCardRect,
  });

  final Rect sectionBounds;
  final Path sectionPath;
  final Rect lowerCardRect;
  final Rect arrowRect;
  final Rect upperCardRect;
}

StudentRangeConditionGeometry studentRangeConditionGeometry(Size size) {
  final contentHeight =
      size.height -
      studentRangeConditionSectionInset * 2 -
      studentRangeConditionArrowHeight -
      studentRangeConditionCardGap * 2;
  final slotHeight = contentHeight / 2;
  final lowerSlot = Rect.fromLTWH(
    0,
    studentRangeConditionSectionInset,
    size.width,
    slotHeight,
  );
  final arrowTop = lowerSlot.bottom + studentRangeConditionCardGap;
  final upperSlot = Rect.fromLTWH(
    0,
    arrowTop + studentRangeConditionArrowHeight + studentRangeConditionCardGap,
    size.width,
    slotHeight,
  );
  final designSize = studentRangeConditionCardDesignSize();
  final rawLowerCard = studentRangeConditionFittedCardRect(
    sectionSize: size,
    verticalSlot: lowerSlot,
    designSize: designSize,
  );
  final rawUpperCard = studentRangeConditionFittedCardRect(
    sectionSize: size,
    verticalSlot: upperSlot,
    designSize: designSize,
  );
  final arrowInterval = studentRangeConditionHorizontalInterval(
    size,
    arrowTop + studentRangeConditionArrowHeight / 2,
  );
  final arrowCenterX = (arrowInterval.$1 + arrowInterval.$2) / 2;
  final rawArrow = Rect.fromLTWH(
    arrowCenterX - studentRangeConditionArrowHeight / 2,
    arrowTop,
    studentRangeConditionArrowHeight,
    studentRangeConditionArrowHeight,
  );

  final tangent = math.tan(80 * math.pi / 180);
  final sine = math.sin(80 * math.pi / 180);
  final normalRailInset = studentRangeConditionSectionInset / sine;
  final rawTop = rawLowerCard.top - studentRangeConditionSectionInset;
  final rawBottom = rawUpperCard.bottom + studentRangeConditionSectionInset;
  final childLeftRail = rawLowerCard.left + rawLowerCard.bottom / tangent;
  final childRightRail = rawLowerCard.right + rawLowerCard.top / tangent;
  final outerLeftRail = childLeftRail - normalRailInset;
  final outerRightRail = childRightRail + normalRailInset;
  double leftAt(double y) => outerLeftRail - y / tangent;
  double rightAt(double y) => outerRightRail - y / tangent;

  final rawPath = buildRoundedSectionPolygon([
    Offset(leftAt(rawTop), rawTop),
    Offset(rightAt(rawTop), rawTop),
    Offset(rightAt(rawBottom), rawBottom),
    Offset(leftAt(rawBottom), rawBottom),
  ]);

  // Preserve the old full-height left rail so reducing the painted shell does
  // not change the 24 px seam from the adjacent filter section.
  final dy = -rawTop;
  final fullHeightLeftRail = size.height / tangent;
  final dx = fullHeightLeftRail - outerLeftRail - dy / tangent;
  final translatedPath = rawPath.shift(Offset(dx, dy));
  final translatedBounds = Rect.fromLTRB(
    leftAt(rawBottom) + dx,
    rawTop + dy,
    rightAt(rawTop) + dx,
    rawBottom + dy,
  );
  final localShift = -translatedBounds.topLeft;
  final contentShift = Offset(dx, dy) + localShift;

  return StudentRangeConditionGeometry(
    sectionBounds: translatedBounds,
    sectionPath: translatedPath.shift(localShift),
    lowerCardRect: rawLowerCard.shift(contentShift),
    arrowRect: rawArrow.shift(contentShift),
    upperCardRect: rawUpperCard.shift(contentShift),
  );
}

Size studentRangeConditionCardDesignSize() => Size(
  studentRangeConditionCardDesignWidth,
  planPresetListCardHeight(
    studentRangeConditionCardDesignWidth,
    layout: PlanPresetElementLayout.condition,
  ),
);

(double, double) studentRangeConditionHorizontalInterval(
  Size sectionSize,
  double y, {
  double normalInset = 0,
}) {
  final clampedY = y.clamp(0.0, sectionSize.height).toDouble();
  final progress = sectionSize.height <= 0
      ? 0.0
      : clampedY / sectionSize.height;
  final depth = sectionTemplateCutDepth(sectionSize.height);
  final railInset = normalInset / math.sin(80 * math.pi / 180);
  return (
    depth * (1 - progress) + railInset,
    sectionSize.width - depth * progress - railInset,
  );
}

Rect studentRangeConditionFittedCardRect({
  required Size sectionSize,
  required Rect verticalSlot,
  required Size designSize,
  double normalInset = studentRangeConditionSectionInset,
}) {
  final tangent = math.tan(80 * math.pi / 180);
  final sine = math.sin(80 * math.pi / 180);
  final sectionDepth = sectionSize.height / tangent;
  final railInset = normalInset / sine;
  final availableRailLength = math.max(
    0.0,
    sectionSize.width - sectionDepth - railInset * 2,
  );
  final designRailLength = math.max(
    1.0,
    designSize.width - designSize.height / tangent,
  );
  final scale = math.min(
    verticalSlot.height / designSize.height,
    availableRailLength / designRailLength,
  );
  final width = designSize.width * scale;
  final height = designSize.height * scale;
  final top = verticalSlot.center.dy - height / 2;
  final bottom = top + height;
  final leftAtBottom = studentRangeConditionHorizontalInterval(
    sectionSize,
    bottom,
    normalInset: normalInset,
  ).$1;
  final rightAtTop = studentRangeConditionHorizontalInterval(
    sectionSize,
    top,
    normalInset: normalInset,
  ).$2;
  final residualWidth = math.max(0.0, rightAtTop - leftAtBottom - width);
  return Rect.fromLTWH(leftAtBottom + residualWidth / 2, top, width, height);
}

double studentRangeConditionCardWidth(Size slotSize) {
  var low = 1.0;
  var high = slotSize.width;
  for (var iteration = 0; iteration < 24; iteration++) {
    final middle = (low + high) / 2;
    if (planPresetListCardHeight(middle) <= slotSize.height) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return low.clamp(1.0, slotSize.width).toDouble();
}

class _ConditionEnabledControl extends StatelessWidget {
  const _ConditionEnabledControl({
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
    color: const Color(0xd9101b27),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConditionResetButton extends StatelessWidget {
  const _ConditionResetButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xd9101b27),
    shape: const CircleBorder(),
    child: IconButton(
      tooltip: '조건 초기화',
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.restart_alt_rounded, size: 18),
    ),
  );
}

class StudentRangeConditionSectionPainter extends CustomPainter {
  const StudentRangeConditionSectionPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.surface.withValues(alpha: 0.76)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(StudentRangeConditionSectionPainter oldDelegate) =>
      oldDelegate.path != path;
}

class _RangeConditionPathClipper extends CustomClipper<Path> {
  const _RangeConditionPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_RangeConditionPathClipper oldClipper) =>
      oldClipper.path != path;
}
