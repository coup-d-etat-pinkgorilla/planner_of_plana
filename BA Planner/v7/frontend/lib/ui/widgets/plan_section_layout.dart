import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../studio/plan_studio_layout.dart';
import 'animated_section_stack.dart';
import 'ba_triangle_background.dart';
import 'diagonal_media_list_item.dart';
import 'lifted_path_shadow.dart';
import 'scroll_viewport_fog.dart';
import 'section_template_surface.dart';

const planSectionOpacity = 0.76;
const planPhaseItemHeight = 65.0;
const planPhaseItemExtent = 69.0;
const planPhaseHeaderHeight = 38.0;
const planPhaseFlowGap = 20.0;
const planResourceTabHeight = 44.0;
const planResourceHeaderHeight = 94.0;
const planSection1Motion = SectionMotionSpec(intro: 0, outro: 180);
const planSection2Motion = SectionMotionSpec(intro: 80, outro: 260);
const planSection3Motion = SectionMotionSpec(intro: 80, outro: 260);
const planSection4Motion = SectionMotionSpec(intro: 180, outro: 0);
const planSection5Motion = SectionMotionSpec(intro: 260, outro: 80);

const Map<String, SectionMotionSpec> planSectionMotions = {
  'element-1': planSection1Motion,
  'element-2': planSection2Motion,
  'element-3': planSection3Motion,
  'element-4': planSection4Motion,
  'element-5': planSection5Motion,
};

enum PlanResourceView { bottleneck, byPhase, overall }

const planPrimaryBottleneckOwned = 42;
const planPrimaryBottleneckRequired = 60;
const planPrimaryBottleneckStudentCount = 3;
const planPrimaryBottleneckItemId = 'Item_Icon_Material_Nebra_2';
const planPrimaryBottleneckItemName = '네브라 디스크 T3';
const planPrimaryBottleneckIconAsset =
    'assets/item_icons/ooparts/Item_Icon_Material_Nebra_2.png';
const planPrimaryBottleneckBackgroundAsset =
    'assets/item_backgrounds/square_yellow.png';
const planPrimaryBottleneckStudentIds = {'azusa', 'nonomi', 'haruka'};
const planPhaseShortageOwned = 42;
const planPhaseShortageRequired = 60;
const planPhaseShortageNumber = 3;
const planPhaseShortageStudentCount = 4;
const planPhaseShortageCompletableCount = 1;

@immutable
class PlanStudentStepPreview {
  const PlanStudentStepPreview({
    required this.studentId,
    required this.displayName,
    required this.step,
    required this.target,
    this.bondRank,
  });

  final String studentId;
  final String displayName;
  final int step;
  final String target;
  final int? bondRank;
}

@immutable
class PlanPhasePreview {
  const PlanPhasePreview({
    required this.id,
    required this.name,
    required this.steps,
  });

  final String id;
  final String name;
  final List<PlanStudentStepPreview> steps;
}

const dummyPlanPhases = <PlanPhasePreview>[
  PlanPhasePreview(
    id: 'phase-1',
    name: '기초 전력 확보',
    steps: [
      PlanStudentStepPreview(
        studentId: 'shiroko',
        displayName: '시로코',
        step: 1,
        target: 'Lv.50 · ★3',
      ),
      PlanStudentStepPreview(
        studentId: 'hoshino',
        displayName: '호시노',
        step: 1,
        target: 'Lv.50 · EX 3',
      ),
      PlanStudentStepPreview(
        studentId: 'serika',
        displayName: '세리카',
        step: 1,
        target: 'Lv.45 · 장비 T4',
      ),
      PlanStudentStepPreview(
        studentId: 'haruka',
        displayName: '하루카',
        step: 1,
        target: 'Lv.50 · 방어 장비 T4',
        bondRank: 35,
      ),
    ],
  ),
  PlanPhasePreview(
    id: 'phase-2',
    name: '핵심 학생 육성',
    steps: [
      PlanStudentStepPreview(
        studentId: 'shiroko',
        displayName: '시로코',
        step: 2,
        target: 'Lv.70 · ★4',
      ),
      PlanStudentStepPreview(
        studentId: 'nonomi',
        displayName: '노노미',
        step: 1,
        target: 'Lv.65 · 스킬 4/4/4',
      ),
      PlanStudentStepPreview(
        studentId: 'hoshino',
        displayName: '호시노',
        step: 2,
        target: 'Lv.70 · EX 5',
      ),
      PlanStudentStepPreview(
        studentId: 'yuuka',
        displayName: '유우카',
        step: 2,
        target: 'Lv.75 · 장비 T6',
        bondRank: 50,
      ),
    ],
  ),
  PlanPhasePreview(
    id: 'phase-3',
    name: '주력 완성',
    steps: [
      PlanStudentStepPreview(
        studentId: 'shiroko',
        displayName: '시로코',
        step: 3,
        target: 'Lv.90 · ★5 · 전무 1',
      ),
      PlanStudentStepPreview(
        studentId: 'serika',
        displayName: '세리카',
        step: 2,
        target: 'Lv.85 · 장비 T8',
      ),
      PlanStudentStepPreview(
        studentId: 'nonomi',
        displayName: '노노미',
        step: 2,
        target: 'Lv.90 · EX 5',
      ),
      PlanStudentStepPreview(
        studentId: 'azusa',
        displayName: '아즈사',
        step: 3,
        target: 'Lv.90 · ★5 · 전무 2',
        bondRank: 100,
      ),
    ],
  ),
  PlanPhasePreview(
    id: 'phase-4',
    name: '후속 보강',
    steps: [
      PlanStudentStepPreview(
        studentId: 'aru',
        displayName: '아루',
        step: 1,
        target: 'Lv.80 · ★5',
      ),
      PlanStudentStepPreview(
        studentId: 'ayane',
        displayName: '아야네',
        step: 1,
        target: 'Lv.70 · 스킬 4/7/7',
      ),
      PlanStudentStepPreview(
        studentId: 'hina',
        displayName: '히나',
        step: 2,
        target: 'Lv.85 · EX 5',
        bondRank: 50,
      ),
      PlanStudentStepPreview(
        studentId: 'ako',
        displayName: '아코',
        step: 3,
        target: 'Lv.90 · 스킬 MAX',
        bondRank: 100,
      ),
    ],
  ),
];

Path planSectionPath(Size size, String id) {
  final section = planStudioDocument.elements.firstWhere(
    (element) => element.id == id,
  );
  return buildSectionCanvasElementPath(size, section);
}

(double, double) planResourceHorizontalInterval(Size size, double y) {
  final bounds = planSectionPath(size, 'element-5').getBounds();
  final localY = (y - bounds.top).clamp(0.0, bounds.height).toDouble();
  final depth = bounds.height / math.tan(80 * math.pi / 180);
  return (
    bounds.left + depth * (1 - localY / bounds.height),
    bounds.right - depth * localY / bounds.height,
  );
}

Rect planResourceTabShelfRect(Size size) {
  final bounds = planSectionPath(size, 'element-5').getBounds();
  final top = bounds.top + (bounds.height * 0.04).clamp(2.0, 6.0).toDouble();
  final height = math.min(
    planResourceTabHeight,
    math.max(26, bounds.height * 0.34),
  );
  final centerY = top + height / 2;
  final (left, right) = planResourceHorizontalInterval(size, centerY);
  return Rect.fromLTRB(
    left + 10,
    top,
    math.max(left + 11, right - 10),
    top + height,
  );
}

Path planResourceHeaderPath(Size size) {
  final bounds = planSectionPath(size, 'element-5').getBounds();
  final tabs = planResourceTabShelfRect(size);
  final top = tabs.bottom + 3;
  final bottom = math.min(bounds.bottom - 3, top + planResourceHeaderHeight);
  final (topLeft, topRight) = planResourceHorizontalInterval(size, top);
  final (bottomLeft, bottomRight) = planResourceHorizontalInterval(
    size,
    bottom,
  );
  return buildRoundedSectionPolygon([
    Offset(topLeft + 10, top),
    Offset(topRight - 10, top),
    Offset(bottomRight - 10, bottom),
    Offset(bottomLeft + 10, bottom),
  ], radius: 12);
}

Rect planResourceHeaderContentRect(Size size) {
  final pathBounds = planResourceHeaderPath(size).getBounds();
  final top = pathBounds.top;
  final bottom = pathBounds.bottom;
  final verticalInset = (pathBounds.height * 0.06).clamp(2.0, 6.0);
  final (topLeft, _) = planResourceHorizontalInterval(size, top);
  final (_, bottomRight) = planResourceHorizontalInterval(size, bottom);
  return Rect.fromLTRB(
    topLeft + 30,
    top + verticalInset,
    math.max(topLeft + 31, bottomRight - 30),
    bottom - verticalInset,
  );
}

Path planPhaseContainerPath(Size size) {
  final sectionPath = planSectionPath(size, 'element-2');
  final sectionBounds = sectionPath.getBounds();
  final rect = Rect.fromLTRB(
    sectionBounds.left + 10,
    sectionBounds.top + 10,
    sectionBounds.right - 10,
    sectionBounds.bottom - 10,
  );
  final depth = rect.height / math.tan(80 * math.pi / 180);
  final raw = buildRoundedSectionPolygon([
    Offset(rect.left + depth, rect.top),
    rect.topRight,
    Offset(rect.right - depth, rect.bottom),
    rect.bottomLeft,
  ], radius: 10);
  return Path.combine(PathOperation.intersect, raw, sectionPath);
}

double planPhaseRowHorizontalOffset({
  required double viewportHeight,
  required double rowTop,
  required double rowHeight,
  required double scrollOffset,
}) {
  final bottomViewportY = rowTop + rowHeight - scrollOffset;
  return (viewportHeight - bottomViewportY) / math.tan(80 * math.pi / 180);
}

double planPhaseRowWidth({
  required double viewportWidth,
  required double viewportHeight,
  required double rowHeight,
}) {
  const horizontalInset = 8.0;
  const scrollbarReserve = 14.0;
  return math.max(
    116,
    viewportWidth -
        horizontalInset * 2 -
        scrollbarReserve -
        (viewportHeight - rowHeight) / math.tan(80 * math.pi / 180),
  );
}

class PlanSectionLayout extends StatefulWidget {
  const PlanSectionLayout({super.key, this.active = true});

  final bool active;

  @override
  State<PlanSectionLayout> createState() => _PlanSectionLayoutState();
}

class _PlanSectionLayoutState extends State<PlanSectionLayout>
    with TickerProviderStateMixin {
  static const _motionDuration = Duration(milliseconds: 360);
  bool _highlightBottleneckStudents = false;
  late final Map<String, AnimationController> _controllers = {
    for (final id in planSectionMotions.keys)
      id: AnimationController(
        vsync: this,
        duration: _motionDuration,
        reverseDuration: _motionDuration,
      ),
  };

  @override
  void initState() {
    super.initState();
    if (widget.active) _setActive(true);
  }

  @override
  void didUpdateWidget(PlanSectionLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _setActive(widget.active);
  }

  void _setActive(bool active) {
    for (final controller in _controllers.values) {
      if (active) {
        controller.forward(from: 0);
      } else {
        controller.reverse(from: 1);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth,
        constraints.maxHeight.isFinite ? constraints.maxHeight : 660,
      );
      Widget sectionLayer(String id) {
        if (id == 'element-5') {
          return Stack(
            fit: StackFit.expand,
            children: [
              IgnorePointer(
                child: CustomPaint(
                  key: ValueKey('plan-$id-foundation'),
                  painter: PlanSectionFoundationPainter(id),
                ),
              ),
              PlanResourceHeader(
                bottleneckHighlighted: _highlightBottleneckStudents,
                onBottleneckHighlightChanged: (highlighted) =>
                    setState(() => _highlightBottleneckStudents = highlighted),
              ),
            ],
          );
        }
        if (id != 'element-2') {
          return IgnorePointer(
            child: CustomPaint(
              key: ValueKey('plan-$id-foundation'),
              painter: PlanSectionFoundationPainter(id),
            ),
          );
        }
        final containerPath = planPhaseContainerPath(size);
        final containerBounds = containerPath.getBounds();
        final localPath = containerPath.shift(-containerBounds.topLeft);
        return Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: CustomPaint(
                key: ValueKey('plan-$id-foundation'),
                painter: PlanSectionFoundationPainter(id),
              ),
            ),
            IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('plan-phase-container-foundation'),
                painter: PlanPhaseContainerPainter(containerPath),
              ),
            ),
            Positioned.fromRect(
              rect: containerBounds,
              child: ClipPath(
                clipper: _PlanLocalPathClipper(localPath),
                child: PlanPhaseDiagonalList(
                  phases: dummyPlanPhases,
                  highlightBottleneckStudents: _highlightBottleneckStudents,
                ),
              ),
            ),
          ],
        );
      }

      return SizedBox.fromSize(
        size: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final id in const [
              'element-2',
              'element-3',
              'element-4',
              'element-1',
              'element-5',
            ])
              Positioned.fill(
                child: PlanSectionMotion(
                  key: ValueKey('plan-$id-motion'),
                  animation: _controllers[id]!,
                  introDegrees: planSectionMotions[id]!.intro,
                  outroDegrees: planSectionMotions[id]!.outro,
                  child: sectionLayer(id),
                ),
              ),
          ],
        ),
      );
    },
  );
}

const _planResourceHeaderTexture = BATriangleTextureConfig(
  baseColor: Color(0xff263747),
  panelColor: AppColors.surfaceRaised,
  softColor: Color(0xff8295a6),
  accentColor: AppColors.primaryMuted,
  triangleSize: 82,
  tessellationContrast: 0.055,
  randomSeed: 6197,
  macroTriangleChance: 0.09,
  macroTriangleScale: 2.6,
  macroTriangleContrast: 0.035,
  lightStrength: 0.12,
  edgeVignetteStrength: 0.12,
  fogDirectionDegrees: 12,
  fogStrength: 0.07,
);

class PlanResourceHeader extends StatefulWidget {
  const PlanResourceHeader({
    super.key,
    required this.bottleneckHighlighted,
    required this.onBottleneckHighlightChanged,
  });

  final bool bottleneckHighlighted;
  final ValueChanged<bool> onBottleneckHighlightChanged;

  @override
  State<PlanResourceHeader> createState() => _PlanResourceHeaderState();
}

class _PlanResourceHeaderState extends State<PlanResourceHeader> {
  PlanResourceView _selected = PlanResourceView.bottleneck;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final tabs = planResourceTabShelfRect(size);
      final headerPath = planResourceHeaderPath(size);
      final content = planResourceHeaderContentRect(size);

      return Stack(
        key: const ValueKey('plan-resource-header'),
        fit: StackFit.expand,
        children: [
          Positioned.fromRect(
            rect: tabs,
            child: _PlanResourceTabs(
              selected: _selected,
              onSelected: (value) {
                setState(() => _selected = value);
                if (value != PlanResourceView.bottleneck) {
                  widget.onBottleneckHighlightChanged(false);
                }
              },
            ),
          ),
          Positioned(
            left: tabs.left,
            top: tabs.bottom,
            width: tabs.width,
            height: 1,
            child: DecoratedBox(
              key: const ValueKey('plan-resource-header-divider'),
              decoration: BoxDecoration(
                color: AppColors.outline.withValues(alpha: 0.55),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('plan-resource-header-surface'),
                painter: PlanResourceHeaderPainter(headerPath),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: content,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.025, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey('plan-resource-header-content-${_selected.name}'),
                child: switch (_selected) {
                  PlanResourceView.bottleneck => PlanPrimaryBottleneckSummary(
                    highlighted: widget.bottleneckHighlighted,
                    onTap: () => widget.onBottleneckHighlightChanged(
                      !widget.bottleneckHighlighted,
                    ),
                  ),
                  PlanResourceView.byPhase => const PlanPhaseResourceSummary(),
                  PlanResourceView.overall => const SizedBox.shrink(),
                },
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PlanResourceTabs extends StatelessWidget {
  const _PlanResourceTabs({required this.selected, required this.onSelected});

  final PlanResourceView selected;
  final ValueChanged<PlanResourceView> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('plan-resource-tabs'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final view in PlanResourceView.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _PlanResourceTab(
              view: view,
              selected: view == selected,
              onTap: () => onSelected(view),
            ),
          ),
        ),
    ],
  );
}

class _PlanResourceTab extends StatelessWidget {
  const _PlanResourceTab({
    required this.view,
    required this.selected,
    required this.onTap,
  });

  final PlanResourceView view;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, icon) = switch (view) {
      PlanResourceView.bottleneck => ('병목', Icons.warning_amber_rounded),
      PlanResourceView.byPhase => ('페이즈별', Icons.layers_outlined),
      PlanResourceView.overall => ('전체', Icons.inventory_2_outlined),
    };
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        key: ValueKey('plan-resource-tab-${view.name}'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: double.infinity,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryMuted.withValues(alpha: 0.34)
                  : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.text : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlanPrimaryBottleneckSummary extends StatelessWidget {
  const PlanPrimaryBottleneckSummary({
    super.key,
    required this.highlighted,
    required this.onTap,
  });

  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PlanResourceItemSummary(
    keyPrefix: 'plan-primary-bottleneck',
    semanticsLabel: '가장 심한 병목 요소, $planPrimaryBottleneckItemName',
    kicker: '가장 심한 병목 요소',
    quantity:
        '보유량 : $planPrimaryBottleneckOwned / '
        '필요량 : $planPrimaryBottleneckRequired',
    detail:
        '확보 시 학생 $planPrimaryBottleneckStudentCount명의 '
        '목표 단계가 가능해집니다',
    backgroundAsset: planPrimaryBottleneckBackgroundAsset,
    iconAsset: planPrimaryBottleneckIconAsset,
    highlighted: highlighted,
    onTap: onTap,
  );
}

class PlanPhaseResourceSummary extends StatelessWidget {
  const PlanPhaseResourceSummary({super.key});

  @override
  Widget build(BuildContext context) => const PlanResourceItemSummary(
    keyPrefix: 'plan-phase-shortage',
    semanticsLabel: '가장 부족한 재화, $planPrimaryBottleneckItemName',
    kicker: '가장 부족한 재화',
    quantity:
        '보유량 : $planPhaseShortageOwned / '
        '필요량 : $planPhaseShortageRequired',
    detail:
        '$planPhaseShortageNumber단계에서 '
        '$planPhaseShortageStudentCount명 중 '
        '$planPhaseShortageCompletableCount명만 완료 가능',
    backgroundAsset: planPrimaryBottleneckBackgroundAsset,
    iconAsset: planPrimaryBottleneckIconAsset,
  );
}

class PlanResourceItemSummary extends StatelessWidget {
  const PlanResourceItemSummary({
    super.key,
    required this.keyPrefix,
    required this.semanticsLabel,
    required this.kicker,
    required this.quantity,
    required this.detail,
    required this.backgroundAsset,
    required this.iconAsset,
    this.highlighted = false,
    this.onTap,
  });

  final String keyPrefix;
  final String semanticsLabel;
  final String kicker;
  final String quantity;
  final String detail;
  final String backgroundAsset;
  final String iconAsset;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 52;
      final iconHeight = constraints.maxHeight * 0.85;
      final iconWidth = iconHeight * 256 / 204;
      final content = Row(
        children: [
          SizedBox(
            width: iconWidth,
            height: iconHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    backgroundAsset,
                    key: ValueKey('$keyPrefix-square'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 227 / 234,
                  heightFactor: 181 / 190,
                  child: Image.asset(
                    iconAsset,
                    key: ValueKey('$keyPrefix-icon'),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 8 : 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kicker,
                  key: ValueKey('$keyPrefix-kicker'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: diagonalMediaHighlightColor,
                    fontSize: compact ? 7 : 12,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: compact ? 1.5 : 4.5),
                Text(
                  quantity,
                  key: ValueKey('$keyPrefix-quantity'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: compact ? 9 : 15,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: compact ? 1.5 : 6),
                Text(
                  detail,
                  key: ValueKey('$keyPrefix-impact'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: compact ? 6.5 : 11,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      return Semantics(
        label: semanticsLabel,
        button: onTap != null,
        selected: onTap == null ? null : highlighted,
        child: Material(
          key: ValueKey('$keyPrefix-summary'),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? content
              : InkWell(
                  key: ValueKey('$keyPrefix-action'),
                  onTap: onTap,
                  child: content,
                ),
        ),
      );
    },
  );
}

class PlanResourceHeaderPainter extends CustomPainter {
  const PlanResourceHeaderPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(_planResourceHeaderTexture).paint(canvas, size);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(PlanResourceHeaderPainter oldDelegate) =>
      oldDelegate.path != path;
}

class PlanSectionMotion extends StatelessWidget {
  const PlanSectionMotion({
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
          builder: (context, child) => Transform.translate(
            key: key == null ? null : ValueKey('$key-transform'),
            offset: planSectionMotionTranslation(
              size: size,
              introDegrees: introDegrees,
              outroDegrees: outroDegrees,
              progress: animation.value,
              exiting: animation.status == AnimationStatus.reverse,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

Offset planSectionMotionTranslation({
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

class PlanSectionFoundationPainter extends CustomPainter {
  const PlanSectionFoundationPainter(this.sectionId);

  final String sectionId;

  @override
  void paint(Canvas canvas, Size size) {
    final path = planSectionPath(size, sectionId);
    paintLiftedPathShadow(canvas, path, defaultLiftedSectionShadow);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.surface.withValues(alpha: planSectionOpacity)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(PlanSectionFoundationPainter oldDelegate) =>
      oldDelegate.sectionId != sectionId;
}

const _planPhaseTexture = BATriangleTextureConfig(
  baseColor: Color(0x8a29435b),
  panelColor: Color(0x8a355a75),
  softColor: Color(0x8a47738d),
  accentColor: Color(0x916291ad),
  triangleSize: 104,
  tessellationContrast: 0.026,
  randomSeed: 404,
  macroTriangleChance: 0.06,
  macroTriangleContrast: 0.018,
  lightStrength: 0.12,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

class PlanPhaseContainerPainter extends CustomPainter {
  const PlanPhaseContainerPainter(this.path);

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    BATriangleTexturePainter(_planPhaseTexture).paint(canvas, size);
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  @override
  bool shouldRepaint(PlanPhaseContainerPainter oldDelegate) =>
      oldDelegate.path != path;
}

class PlanPhaseDiagonalList extends StatefulWidget {
  const PlanPhaseDiagonalList({
    super.key,
    required this.phases,
    required this.highlightBottleneckStudents,
  });

  final List<PlanPhasePreview> phases;
  final bool highlightBottleneckStudents;

  @override
  State<PlanPhaseDiagonalList> createState() => _PlanPhaseDiagonalListState();
}

class _PlanPhaseDiagonalListState extends State<PlanPhaseDiagonalList> {
  static const _inset = 8.0;
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heights = [
        for (final phase in widget.phases)
          planPhaseHeaderHeight + phase.steps.length * planPhaseItemExtent + 12,
      ];
      final contentHeight =
          _inset * 2 +
          heights.fold<double>(0, (sum, height) => sum + height) +
          planPhaseFlowGap * math.max(0, widget.phases.length - 1);
      return PlanDiagonalScrollbar(
        controller: _controller,
        contentExtent: contentHeight,
        child: SingleChildScrollView(
          key: const ValueKey('plan-phase-scroll'),
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scroll = _controller.hasClients ? _controller.offset : 0.0;
              var top = _inset;
              final children = <Widget>[];
              for (var index = 0; index < widget.phases.length; index++) {
                final phase = widget.phases[index];
                final height = heights[index];
                final offset = planPhaseRowHorizontalOffset(
                  viewportHeight: constraints.maxHeight,
                  rowTop: top,
                  rowHeight: height,
                  scrollOffset: scroll,
                );
                final width = planPhaseRowWidth(
                  viewportWidth: constraints.maxWidth,
                  viewportHeight: constraints.maxHeight,
                  rowHeight: height,
                );
                children.add(
                  Positioned(
                    key: ValueKey('plan-phase-${phase.id}'),
                    left: _inset + offset,
                    top: top,
                    width: width,
                    height: height,
                    child: PlanPhaseCard(
                      number: index + 1,
                      phase: phase,
                      highlightBottleneckStudents:
                          widget.highlightBottleneckStudents,
                    ),
                  ),
                );
                if (index < widget.phases.length - 1) {
                  children.add(
                    Positioned(
                      key: ValueKey('plan-phase-flow-${phase.id}'),
                      left: _inset + offset,
                      top: top + height + 2,
                      width: width,
                      height: planPhaseFlowGap - 4,
                      child: const _PlanPhaseFlowIndicator(),
                    ),
                  );
                }
                top += height + planPhaseFlowGap;
              }
              return SizedBox(
                width: constraints.maxWidth,
                height: contentHeight,
                child: Stack(clipBehavior: Clip.none, children: children),
              );
            },
          ),
        ),
      );
    },
  );
}

class PlanPhaseCard extends StatelessWidget {
  const PlanPhaseCard({
    super.key,
    required this.number,
    required this.phase,
    required this.highlightBottleneckStudents,
  });

  final int number;
  final PlanPhasePreview phase;
  final bool highlightBottleneckStudents;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final headerCenterY = 19.0;
      final headerLeft = planPhaseLeftBoundary(size, headerCenterY) + 9;
      final headerRight = planPhaseRightBoundary(size, headerCenterY) - 9;
      return CustomPaint(
        painter: const _PlanPhaseCardPainter(),
        child: Stack(
          children: [
            Positioned(
              left: headerLeft,
              top: 8,
              width: math.max(1, headerRight - headerLeft),
              height: 23,
              child: Row(
                children: [
                  Text(
                    '$number',
                    style: const TextStyle(
                      color: Color(0xfff2b3ef),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      phase.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < phase.steps.length; index++)
              Positioned.fromRect(
                rect: planPhaseItemRect(size, index),
                child: PlanStudentStepTile(
                  key: ValueKey(
                    'plan-step-${phase.id}-${phase.steps[index].studentId}-${phase.steps[index].step}',
                  ),
                  order: index + 1,
                  step: phase.steps[index],
                  highlighted:
                      highlightBottleneckStudents &&
                      planPrimaryBottleneckStudentIds.contains(
                        phase.steps[index].studentId,
                      ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

double planPhaseLeftBoundary(Size size, double y) {
  final depth = size.height / math.tan(80 * math.pi / 180);
  return depth * (1 - y / size.height);
}

double planPhaseRightBoundary(Size size, double y) {
  final depth = size.height / math.tan(80 * math.pi / 180);
  return size.width - depth * y / size.height;
}

Rect planPhaseItemRect(Size size, int index) {
  final top = planPhaseHeaderHeight + index * planPhaseItemExtent;
  final bottom = top + planPhaseItemHeight;
  const inset = 9.0;
  final left = planPhaseLeftBoundary(size, bottom) + inset;
  final right = planPhaseRightBoundary(size, top) - inset;
  return Rect.fromLTRB(left, top, math.max(left + 1, right), bottom);
}

class _PlanPhaseFlowIndicator extends StatelessWidget {
  const _PlanPhaseFlowIndicator();

  @override
  Widget build(BuildContext context) => const Center(
    child: CustomPaint(
      key: ValueKey('plan-phase-flow-triangle'),
      size: Size(16, 10),
      painter: _PlanPhaseFlowIndicatorPainter(),
    ),
  );
}

class _PlanPhaseFlowIndicatorPainter extends CustomPainter {
  const _PlanPhaseFlowIndicatorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = const Color(0xfff2b3ef).withValues(alpha: 0.88),
    );
  }

  @override
  bool shouldRepaint(_PlanPhaseFlowIndicatorPainter oldDelegate) => false;
}

class PlanStudentStepTile extends StatelessWidget {
  const PlanStudentStepTile({
    super.key,
    required this.order,
    required this.step,
    this.highlighted = false,
  });

  final int order;
  final PlanStudentStepPreview step;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final stage = step.step;
    final bondRank = step.bondRank ?? 10 + stage * 5;
    return DiagonalMediaListItem(
      highlighted: highlighted,
      data: DiagonalMediaListItemData(
        order: order,
        mediaAssetPath: 'assets/student_portraits/${step.studentId}.png',
        title: '${step.displayName} · ${step.step}단계',
        studentStars: math.min(5, 2 + stage),
        weaponStars: math.min(4, stage),
        studentStarDelta: 1,
        weaponStarDelta: stage == 1 ? null : 1,
        studentLevel: DiagonalMediaValue(
          'Lv.${40 + stage * 15}',
          delta: 10 + stage * 5,
        ),
        weaponLevel: DiagonalMediaValue('Lv.${20 + stage * 10}', delta: 10),
        skills: DiagonalMediaValue(
          '${stage + 2}/${stage + 3}/${stage + 3}/${stage + 3}',
          componentDeltas: [null, null, null, stage + 1],
        ),
        equipment: [
          DiagonalMediaEquipment(
            assetPath: 'assets/equipment_icons/hat_t10.png',
            tier: DiagonalMediaValue(
              'T${stage + 4}',
              delta: stage == 1 ? null : 1,
            ),
            level: DiagonalMediaValue(
              'Lv.${20 + stage * 5}',
              delta: stage == 1 ? null : 5,
            ),
          ),
          DiagonalMediaEquipment(
            assetPath: 'assets/equipment_icons/hairpin_t10.png',
            tier: DiagonalMediaValue(
              'T${stage + 3}',
              delta: stage == 1 ? null : 1,
            ),
            level: DiagonalMediaValue(
              'Lv.${15 + stage * 5}',
              delta: stage == 1 ? null : 5,
            ),
          ),
          DiagonalMediaEquipment(
            assetPath: 'assets/equipment_icons/watch_t10.png',
            tier: DiagonalMediaValue(
              'T${stage + 2}',
              delta: stage == 1 ? -1 : 1,
            ),
            level: DiagonalMediaValue(
              'Lv.${10 + stage * 5}',
              delta: stage == 1 ? null : 5,
            ),
          ),
        ],
        favoriteItem: DiagonalMediaValue(
          'T${math.min(2, stage)}',
          delta: stage == 1 ? null : 1,
        ),
        bondRank: DiagonalMediaValue(
          '$bondRank',
          delta: bondRank >= 100 ? null : 2,
        ),
        stats: DiagonalMediaValue(
          '${20 + stage * 5}/${18 + stage * 4}/${15 + stage * 3}',
          componentDeltas: [null, stage, stage * 2],
        ),
      ),
    );
  }
}

class _PlanPhaseCardPainter extends CustomPainter {
  const _PlanPhaseCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final depth = size.height / math.tan(80 * math.pi / 180);
    final path = buildRoundedSectionPolygon([
      Offset(depth, 0),
      Offset(size.width, 0),
      Offset(size.width - depth, size.height),
      Offset(0, size.height),
    ], radius: 8);
    canvas.drawPath(path, Paint()..color = const Color(0xd635526b));
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.outline.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(_PlanPhaseCardPainter oldDelegate) => false;
}

class PlanDiagonalScrollbar extends StatelessWidget {
  const PlanDiagonalScrollbar({
    super.key,
    required this.controller,
    required this.contentExtent,
    required this.child,
  });

  final ScrollController controller;
  final double contentExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final size = constraints.biggest;
        final hasClients = controller.hasClients;
        final maxScroll = hasClients
            ? controller.position.maxScrollExtent
            : math.max(0.0, contentExtent - size.height);
        final viewport = hasClients
            ? controller.position.viewportDimension
            : size.height;
        final offset = hasClients ? controller.offset : 0.0;
        final fogVisibility = scrollViewportFogVisibility(
          minScrollExtent: hasClients
              ? controller.position.minScrollExtent
              : 0.0,
          maxScrollExtent: maxScroll,
          pixels: offset,
        );
        const trackInset = 10.0;
        final trackHeight = math.max(1.0, size.height - trackInset * 2);
        final handleHeight = maxScroll <= 0
            ? trackHeight
            : math.max(28.0, trackHeight * viewport / (viewport + maxScroll));
        final travel = math.max(1.0, trackHeight - handleHeight);
        final handleTop =
            trackInset +
            travel *
                (maxScroll <= 0 ? 0 : (offset / maxScroll).clamp(0.0, 1.0));
        final handleCenter = planScrollbarTrackPoint(
          size,
          handleTop + handleHeight / 2,
          trackInset: trackInset,
        );
        final trajectoryDepth = size.height / math.tan(80 * math.pi / 180);
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned.fill(
              child: ScrollViewportFog(
                key: const ValueKey('plan-phase-fog'),
                keyPrefix: 'plan-phase-viewport-fog',
                showTop: fogVisibility.showTop,
                showBottom: fogVisibility.showBottom,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('plan-phase-diagonal-scrollbar'),
                  painter: _PlanDiagonalScrollbarPainter(
                    offset: offset,
                    maxScrollExtent: maxScroll,
                    handleHeight: handleHeight,
                    trackInset: trackInset,
                  ),
                ),
              ),
            ),
            Positioned(
              key: const ValueKey('plan-phase-scrollbar-handle-center'),
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
                  key: const ValueKey('plan-phase-scrollbar-drag'),
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
  );
}

Offset planScrollbarTrackPoint(Size size, double y, {double trackInset = 10}) {
  final depth = size.height / math.tan(80 * math.pi / 180);
  final clampedY = y.clamp(0.0, size.height);
  return Offset(
    size.width -
        trackInset -
        depth +
        (size.height - clampedY) / math.tan(80 * math.pi / 180),
    clampedY,
  );
}

class _PlanDiagonalScrollbarPainter extends CustomPainter {
  const _PlanDiagonalScrollbarPainter({
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
    final start = planScrollbarTrackPoint(size, top, trackInset: trackInset);
    final end = planScrollbarTrackPoint(size, bottom, trackInset: trackInset);
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
  bool shouldRepaint(_PlanDiagonalScrollbarPainter oldDelegate) =>
      oldDelegate.offset != offset ||
      oldDelegate.maxScrollExtent != maxScrollExtent ||
      oldDelegate.handleHeight != handleHeight ||
      oldDelegate.trackInset != trackInset;
}

class _PlanLocalPathClipper extends CustomClipper<Path> {
  const _PlanLocalPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PlanLocalPathClipper oldClipper) =>
      oldClipper.path != path;
}
