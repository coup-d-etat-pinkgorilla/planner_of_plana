// 계획 만들기 A 진행 레일(FE4-a1, 시안 Flow-1-Students·Flow-4-Save의 A 섹션, C 보고서 §0-1).
//
// 위에서부터: 제목 "계획 만들기" + (i), 스텝 버튼 4개(80° 레일을 따라 아래로 갈수록 좁아짐, 사이 2×12 연결선),
// "지금까지 만든 것" 요약 4행(학생·단계·필요 크레딧·부족 재화, 마지막 행은 부족 재화 플라이아웃), 아래 끝에
// 다음(primary)·이전/그만두기(ghost).
// 좌표는 시안(섹션 위 y=209.2 기준)의 값이다. 버튼 폭은 그 높이의 레일 오른쪽 x에서 왼쪽 14 + 오른쪽 22를 뺀다.
// 창이 낮으면 세로 값만 같은 비율로 줄이고(글자는 칸 안에서 scaleDown), 섹션 rect는 Studio 문서를 따른다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/game_assets.dart';
import '../kit/info_popover.dart';
import '../kit/shortage_flyout.dart';
import '../kit/titles.dart';
import '../models/plan_flow_draft.dart';
import '../models/planning_resource_assets.dart';
import '../studio/plan_flow_studio_layout.dart';
import 'growth_calculator_section.dart' show growthCalculatorCompactNumber;
import 'section_surface.dart';
import 'section_template_surface.dart';
import '../tutorial/tutorial_script.dart';
import '../tutorial_targets/tutorial_hooks.dart';

/// [id] 섹션의 둥근 path(콘텐츠 캔버스 [size] 좌표). Studio와 같은 함수로 만든다.
Path planFlowSectionPath(Size size, String id) =>
    buildSectionCanvasElementPath(size, planFlowSection(id));

/// [id] 섹션의 둥글리기 전 꼭짓점(콘텐츠 캔버스 좌표, 시계 방향). 시안 대조와 레일 계산에 쓴다.
List<Offset> planFlowSectionPolygon(Size size, String id) {
  final section = planFlowSection(id);
  final rect = sectionCanvasElementRect(size, section);
  return [
    for (final point in buildAttachedSectionPolygon(rect.size, section.spec))
      point + rect.topLeft,
  ];
}

/// A 레일 오른쪽 사선 위 [y]에서의 x.
double planFlowRailRightAt(Size size, double y) {
  final points = planFlowSectionPolygon(size, planFlowRailSectionId);
  final topRight = points[1];
  final bottomRight = points[2];
  final span = bottomRight.dy - topRight.dy;
  if (span <= 0) return topRight.dx;
  final progress = ((y - topRight.dy) / span).clamp(0.0, 1.0).toDouble();
  return topRight.dx + (bottomRight.dx - topRight.dx) * progress;
}

/// 섹션 하나의 표면(공용 [paintSectionSurface]).
class PlanFlowSectionPainter extends CustomPainter {
  const PlanFlowSectionPainter(this.sectionId);

  final String sectionId;

  @override
  void paint(Canvas canvas, Size size) {
    paintSectionSurface(canvas, planFlowSectionPath(size, sectionId));
  }

  @override
  bool shouldRepaint(PlanFlowSectionPainter oldDelegate) =>
      oldDelegate.sectionId != sectionId;
}

/// 시안 레일 높이(1182.8)를 기준으로 한 세로 값. 왼쪽 안쪽 14, 오른쪽 레일 여백 22.
abstract final class PlanFlowRailMetrics {
  static const referenceHeight = 1208 * 94 / 96;
  static const left = 14.0;
  static const rightMargin = 22.0;
  static const titleTop = 22.0;
  static const stepTop = 78.0;
  static const stepHeight = 84.0;
  static const stepPitch = 96.0;
  static const connectorLeft = 34.0;
  static const connectorHeight = 12.0;
  static const captionTop = 478.0;
  static const summaryTop = 504.0;
  static const summaryHeight = 40.0;
  static const summaryPitch = 46.0;

  /// 아래 끝에서 primary 윗변까지(1392 − 1260).
  static const primaryFromBottom = 132.0;
  static const primaryHeight = 56.0;

  /// 아래 끝에서 secondary 윗변까지(1392 − 1324).
  static const secondaryFromBottom = 68.0;
  static const secondaryHeight = 48.0;

  /// 낮은 창에서 세로 값을 줄이는 비율(0.4~1).
  static double scaleFor(double railHeight) =>
      (railHeight / referenceHeight).clamp(0.4, 1.0).toDouble();
}

/// 연결선 색 rgba(56,81,107,.9).
const planFlowRailConnectorColor = Color.fromRGBO(56, 81, 107, 0.9);

/// 스텝 버튼 부제(시안 `3명 · 여러 명 모드`, `3명 중 2명 완료`, `단계 7개 · 순서 3칸`, 나중에 칸이 있으면
/// `· 나중에 n개`).
///
/// 4단계 부제는 고른 저장 위치([saveLabel], FE4-e)이고, 없으면 "시나리오로 저장"이다.
///
/// 한 명만 골랐으면(FE4-b2 한 명 모드, 시안 Flow-1-Students-One) 1단계는 `1명 · 한 명 모드`, 2단계는 학생 이름과 상태
/// (`리오(무장) · 설정 중`)다. 상태는 3단계 이후에 그 학생 단계가 있으면 `완료`, 그 전(1 · 2단계)은 `설정 중`이다(시안
/// 1단계 장면이 단계가 있는데도 "설정 중"이다 — 2단계 학생 탭의 "설정 중"과 같은 말).
String planFlowStepSubtitle(
  PlanFlowController flow,
  PlanFlowStep step, {
  String? saveLabel,
}) {
  final draft = flow.draft;
  final one = draft.studentCount == 1 ? draft.studentOrder.single : null;
  switch (step) {
    case PlanFlowStep.students:
      final count = draft.studentCount;
      if (count == 0) return '아직 고르지 않았습니다';
      return one != null ? '1명 · 한 명 모드' : '$count명 · 여러 명 모드';
    case PlanFlowStep.goals:
      if (one != null) {
        final done =
            flow.step.index > PlanFlowStep.goals.index &&
            draft.completedStudentCount == 1;
        return '${flow.context.displayName(one)} · ${done ? '완료' : '설정 중'}';
      }
      return draft.studentCount == 0
          ? '고른 학생이 없습니다'
          : '${draft.studentCount}명 중 ${draft.completedStudentCount}명 완료';
    case PlanFlowStep.order:
      final lanes = draft.phases.where((phase) => phase.stageIds.isNotEmpty);
      final deferred = draft.deferredStageIds.length;
      return '단계 ${draft.stageCount}개 · 순서 ${lanes.length}칸'
          '${deferred > 0 ? ' · 나중에 $deferred개' : ''}';
    case PlanFlowStep.save:
      return saveLabel ?? '시나리오로 저장';
  }
}

/// primary 버튼 글자.
String planFlowNextLabel(PlanFlowStep step) => switch (step.next) {
  final next? => '다음 · ${next.title}',
  null => '저장하고 닫기',
};

/// secondary 버튼 글자.
String planFlowPreviousLabel(PlanFlowStep step) => switch (step.previous) {
  final previous? => '이전 · ${previous.title}',
  null => '그만두기',
};

/// 필요 크레딧 요약 값.
String planFlowCreditsLabel(PlanFlowController flow) {
  final credits = flow.draft.hasStages ? flow.calculation?.credits : null;
  return credits == null ? '—' : growthCalculatorCompactNumber(credits);
}

/// 부족 재화 요약 값.
String planFlowShortageLabel(PlanFlowController flow) {
  final kinds = flow.draft.hasStages ? flow.calculation?.shortageKinds : null;
  return kinds == null ? '—' : '$kinds종';
}

/// 플라이아웃 행([ShortageItem])으로 옮긴다.
List<ShortageItem> planFlowShortageItems(PlanFlowCalculation calculation) => [
  for (final shortage in calculation.shortages)
    ShortageItem(
      name: shortage.name,
      shortage: shortage.shortage,
      owned: shortage.owned,
      needed: shortage.needed,
      iconAsset: planningResourceIconAsset(
        category: shortage.category,
        itemId: shortage.itemId,
      ),
      iconBackground: ItemBackground.basic,
      uses: [
        for (final use in shortage.uses)
          ShortageUse(
            student: use.displayName,
            stage: use.step,
            studentId: use.studentId,
          ),
      ],
    ),
];

/// A 진행 레일. 콘텐츠 캔버스 전체를 채우고 레일 섹션 안에만 그린다.
class PlanFlowRail extends StatelessWidget {
  const PlanFlowRail({
    super.key,
    required this.flow,
    required this.onSelectStep,
    required this.onNext,
    required this.onPrevious,
    this.saveLabel,
    this.saveEnabled,
  });

  final PlanFlowController flow;

  /// 스텝 버튼. [PlanFlowController.canEnter]가 false인 스텝은 누를 수 없다.
  final ValueChanged<PlanFlowStep> onSelectStep;

  /// 다음(4단계에서는 저장하고 닫기).
  final VoidCallback onNext;

  /// 이전(1단계에서는 그만두기).
  final VoidCallback onPrevious;

  /// 4단계 primary 글자(C에서 고른 저장 위치, FD-079). 없으면 "저장하고 닫기"다. 4단계 스텝 버튼 부제도 이 글자다.
  final String? saveLabel;

  /// 4단계 primary를 누를 수 있는가(C 저장 버튼과 같다). 없으면 [PlanFlowController.canGoNext]다.
  final bool? saveEnabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final points = planFlowSectionPolygon(size, planFlowRailSectionId);
      final railTop = points.first.dy;
      final railBottom = points[2].dy;
      final scale = PlanFlowRailMetrics.scaleFor(railBottom - railTop);
      double width(double top) => math.max(0.0,
        planFlowRailRightAt(size, top) -
            PlanFlowRailMetrics.left -
            PlanFlowRailMetrics.rightMargin,
      );
      Rect row(double top, double height) => Rect.fromLTWH(
        PlanFlowRailMetrics.left,
        top,
        width(top),
        height,
      );

      final step = flow.step;
      final children = <Widget>[
        const IgnorePointer(
          child: CustomPaint(
            key: ValueKey('plan-flow-rail-surface'),
            painter: PlanFlowSectionPainter(planFlowRailSectionId),
          ),
        ),
        Positioned(
          left: 20,
          top: railTop + PlanFlowRailMetrics.titleTop * scale,
          width: math.max(0.0, width(railTop) - 6),
          height: 32 * scale,
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _PlanFlowRailTitle(),
          ),
        ),
      ];

      for (final target in PlanFlowStep.values) {
        final top =
            railTop +
            (PlanFlowRailMetrics.stepTop +
                    PlanFlowRailMetrics.stepPitch * target.index) *
                scale;
        final height = PlanFlowRailMetrics.stepHeight * scale;
        children.add(
          Positioned.fromRect(
            rect: row(top, height),
            // F3c-2: 단계 목록 4줄을 한 대상의 조각으로(묶음 위젯이 따로 없다).
            child: TutorialTarget(
              id: TutorialTargets.planStepList,
              group: true,
              child: _PlanFlowStepButton(
                key: ValueKey('plan-flow-step-${target.number}'),
                step: target,
                state: flow.stateOf(target),
                subtitle: planFlowStepSubtitle(
                  flow,
                  target,
                  saveLabel: saveLabel,
                ),
                height: height,
                onPressed: target == step || !flow.canEnter(target)
                    ? null
                    : () => onSelectStep(target),
              ),
            ),
          ),
        );
        if (target.next != null) {
          children.add(
            Positioned(
              left: PlanFlowRailMetrics.connectorLeft,
              top: top + height,
              width: 2,
              height: PlanFlowRailMetrics.connectorHeight * scale,
              child: const ColoredBox(color: planFlowRailConnectorColor),
            ),
          );
        }
      }

      children.add(
        Positioned(
          left: 20,
          top: railTop + PlanFlowRailMetrics.captionTop * scale,
          height: 20 * scale,
          width: math.max(0.0, width(railTop) - 6),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('지금까지 만든 것', style: _captionStyle),
          ),
        ),
      );
      final calculation = flow.draft.hasStages ? flow.calculation : null;
      final shortageKinds = calculation?.shortageKinds;
      final summary = [
        ('students', '학생', '${flow.draft.studentCount}명', AppColors.text),
        ('stages', '단계', '${flow.draft.stageCount}개', AppColors.text),
        ('credits', '필요 크레딧', planFlowCreditsLabel(flow), AppColors.text),
        (
          'shortage',
          '부족 재화',
          planFlowShortageLabel(flow),
          (shortageKinds ?? 0) > 0 ? AppColors.warning : AppColors.text,
        ),
      ];
      for (final (index, (key, label, value, color)) in summary.indexed) {
        final top =
            railTop +
            (PlanFlowRailMetrics.summaryTop +
                    PlanFlowRailMetrics.summaryPitch * index) *
                scale;
        final rect = row(top, PlanFlowRailMetrics.summaryHeight * scale);
        final flyout =
            key == 'shortage' && (calculation?.shortages.isNotEmpty ?? false)
            ? calculation
            : null;
        final summaryRow = _PlanFlowSummaryRow(
          key: ValueKey('plan-flow-summary-$key'),
          label: label,
          value: value,
          valueColor: color,
          chevron: flyout != null,
        );
        children.add(
          Positioned.fromRect(
            rect: rect,
            child: flyout != null
                ? ShortageBreakdownFlyout(
                    key: const ValueKey('plan-flow-shortage-flyout'),
                    semanticLabel: '부족 재화 자세히 보기',
                    title: '부족 재화 ${flyout.shortages.length}종',
                    items: planFlowShortageItems(flyout),
                    child: SizedBox.fromSize(
                      size: rect.size,
                      child: summaryRow,
                    ),
                  )
                : summaryRow,
          ),
        );
      }
      if (flow.calculationError != null && flow.draft.hasStages) {
        final top =
            railTop +
            (PlanFlowRailMetrics.summaryTop +
                    PlanFlowRailMetrics.summaryPitch * 4) *
                scale;
        children.add(
          Positioned(
            left: 20,
            top: top,
            width: math.max(0.0, width(top) - 6),
            height: 20 * scale,
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '계산하지 못했습니다',
                key: ValueKey('plan-flow-calculation-error'),
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySmallSize,
                  fontWeight: AppType.semiBold,
                  color: AppColors.danger,
                ),
              ),
            ),
          ),
        );
      }

      final saving = step.next == null;
      final primaryLabel = saving
          ? saveLabel ?? planFlowNextLabel(step)
          : planFlowNextLabel(step);
      final primaryEnabled = saving
          ? saveEnabled ?? flow.canGoNext
          : flow.canGoNext;
      final primaryTop =
          railBottom - PlanFlowRailMetrics.primaryFromBottom * scale;
      final primaryHeight = PlanFlowRailMetrics.primaryHeight * scale;
      children.add(
        Positioned.fromRect(
          rect: row(primaryTop, primaryHeight),
          child: TutorialTarget(
            // "다음 · 목표 정하기"일 때만(7-1).
            id: step == PlanFlowStep.students
                ? TutorialTargets.planNextToGoals
                : null,
            child: RailButton(
              key: const ValueKey('plan-flow-next'),
              variant: RailButtonVariant.primary,
              height: primaryHeight,
              semanticLabel: primaryLabel,
              onPressed: primaryEnabled ? onNext : null,
              child: _ButtonLabel(
                label: primaryLabel,
                fontSize: AppType.bodyLargeSize,
                trailing: step.next == null
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
              ),
            ),
          ),
        ),
      );
      final secondaryTop =
          railBottom - PlanFlowRailMetrics.secondaryFromBottom * scale;
      final secondaryHeight = PlanFlowRailMetrics.secondaryHeight * scale;
      children.add(
        Positioned.fromRect(
          rect: row(secondaryTop, secondaryHeight),
          child: RailButton(
            key: const ValueKey('plan-flow-previous'),
            variant: RailButtonVariant.ghost,
            height: secondaryHeight,
            semanticLabel: planFlowPreviousLabel(step),
            onPressed: onPrevious,
            child: _ButtonLabel(
              label: planFlowPreviousLabel(step),
              fontSize: AppType.titleSmallSize,
              leading: step.previous == null
                  ? Icons.close_rounded
                  : Icons.arrow_back_rounded,
            ),
          ),
        ),
      );

      return Stack(
        key: const ValueKey('plan-flow-rail'),
        fit: StackFit.expand,
        children: children,
      );
    },
  );
}

const _captionStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  fontWeight: AppType.semiBold,
  color: AppColors.textMuted,
);

class _PlanFlowRailTitle extends StatelessWidget {
  const _PlanFlowRailTitle();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('계획 만들기', style: kitDisplayStyle(AppType.headlineSmallSize)),
      const SizedBox(width: 8),
      InfoPopover(
        key: const ValueKey('plan-flow-info'),
        label: '계획 만들기',
        title: '계획 만들기',
        width: 310,
        children: [
          const InfoPopoverText.plain('아래 네 단계는 순서와 상관없이 언제든 눌러서 이동할 수 있습니다.'),
          for (final (place, action, target) in const [
            ('학생 탭', '이 학생 목표 정하기', '2단계'),
            ('계획 탭 페이즈', '순서 바꾸기', '3단계'),
            ('시나리오', '이걸로 새로 만들기', '1단계'),
          ])
            InfoPopoverText([
              TextSpan(text: '• $place '),
              InfoPopoverText.em(action),
              TextSpan(text: ' → $target'),
            ]),
        ],
      ),
    ],
  );
}

/// 스텝 버튼(시안 `a.btn` 84px: 번호 `.dsp` 30 · 제목 15 굵게 · 부제 12 · 상태 칩).
///
/// 갈 수 없는 스텝은 키트 공통 비활성(불투명도 .45)이다. 지금 스텝은 눌러도 그대로다.
class _PlanFlowStepButton extends StatelessWidget {
  const _PlanFlowStepButton({
    super.key,
    required this.step,
    required this.state,
    required this.subtitle,
    required this.height,
    required this.onPressed,
  });

  final PlanFlowStep step;
  final PlanFlowStepState state;
  final String subtitle;
  final double height;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final (variant, chip, tone) = switch (state) {
      PlanFlowStepState.current => (
        RailButtonVariant.selectedPink,
        '지금',
        AppTones.pink,
      ),
      PlanFlowStepState.done => (RailButtonVariant.done, '완료', AppTones.ok),
      PlanFlowStepState.remaining => (
        RailButtonVariant.ghost,
        '남음',
        AppTones.gray,
      ),
    };
    final current = state == PlanFlowStepState.current;
    return Semantics(
      container: true,
      value: '$chip, $subtitle',
      hint: current
          ? '지금 단계입니다'
          : onPressed == null
          ? '앞 단계를 먼저 마칩니다'
          : '이 단계로 갑니다',
      child: RailButton(
        variant: variant,
        height: height,
        semanticLabel: '${step.number}단계 ${step.title}',
        onPressed: current ? () {} : onPressed,
        child: ExcludeSemantics(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 420,
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${step.number}',
                      style: kitDisplayStyle(
                        AppType.displayMediumSize,
                        color: current ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppType.bodyLargeSize,
                            fontWeight: AppType.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          key: ValueKey(
                            'plan-flow-step-${step.number}-subtitle',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: AppType.bodySmallSize,
                            fontWeight: AppType.medium,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  BaChip(
                    key: ValueKey('plan-flow-step-${step.number}-state'),
                    label: chip,
                    tone: tone,
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

/// 요약 행(시안 `button.btn.ghost` 40px: 이름 `.mut` 13 · 값 `.dsp` 18).
class _PlanFlowSummaryRow extends StatelessWidget {
  const _PlanFlowSummaryRow({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.chevron,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool chevron;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    value: value,
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return CustomPaint(
            painter: RailButtonPainter(
              look: RailButtonLook.of(RailButtonVariant.ghost),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: diagonalCutDepth(height) + 12,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 380,
                  height: 24,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontFamilyFallback: AppFonts.fallback,
                            fontSize: AppType.bodySize,
                            fontWeight: AppType.medium,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Text(
                        value,
                        maxLines: 1,
                        style: kitDisplayStyle(
                          AppType.titleLargeSize,
                          color: valueColor,
                        ),
                      ),
                      if (chevron) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.label,
    required this.fontSize,
    this.leading,
    this.trailing,
  });

  final String label;
  final double fontSize;
  final IconData? leading;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading != null) ...[Icon(leading), const SizedBox(width: 8)],
        Text(
          label,
          maxLines: 1,
          style: TextStyle(fontSize: fontSize, fontWeight: AppType.bold),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), Icon(trailing)],
      ],
    ),
  );
}
