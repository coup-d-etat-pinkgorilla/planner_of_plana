// 계획 만들기 4단계 저장(FE4-e, 시안 Flow-4-Save, FD-031·FD-079·FD-080·FD-088).
//
// - B 본문: "이렇게 만들어집니다" + 페이즈·단계 수, 페이즈 행 P1~Pn(학생 초상·단계 태그·상태 칩, 마우스를 올리면
//   필요 재화 팝오버 "앞 페이즈에서 쓰고 남은 양 기준"), "지금 활성 계획과 비교" 타일(충족률 FD-031 (a) · 부족 재화 ·
//   필요 크레딧 · 학생), "가장 크게 늘어나는 재화" 3줄.
// - C 보조: "어디에 넣으시겠습니까" 3지선다, 패널 안 이름 입력(다이얼로그 아님), "저장한 뒤" 토글 2개(설명 입력 없음,
//   FD-079), 저장 버튼(A 레일 primary와 같은 동작·같은 글자).
// 상태와 저장은 [PlanFlowSaveController]가 맡는다. 좌표는 시안(2560×1392, 헤더 184 아래)을 캔버스로 옮긴 값이다.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/anchored_flyout.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/diagonal_scroll_viewport.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_overlay.dart';
import '../kit/portrait_strip.dart';
import '../kit/skew_bar.dart';
import '../kit/skew_controls.dart';
import '../kit/titles.dart';
import '../models/plan_flow_draft.dart';
import '../models/plan_flow_save.dart';
import '../models/planning_resource_assets.dart';
import '../studio/plan_flow_studio_layout.dart';
import 'growth_calculator_section.dart' show growthCalculatorCompactNumber;
import 'plan_flow_rail.dart' show planFlowSectionPolygon;
import 'plan_flow_student_step.dart' show planFlowAsideLeftAt, planFlowProtoRect;

const _mutedStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySmallSize,
  fontWeight: AppType.medium,
  color: AppColors.textMuted,
);

const _bodyStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.bodySize,
  fontWeight: AppType.semiBold,
  color: AppColors.text,
);

const _captionStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.35,
  fontWeight: AppType.semiBold,
  color: AppColors.textMuted,
);

/// 시안 페이즈 행 `.srow` 높이·간격.
const planFlowSavePhaseRowHeight = 92.0;
const planFlowSavePhaseRowGap = 12.0;

/// 한 번에 보이는 페이즈 행 수(넘으면 목록이 스크롤된다).
const planFlowSaveVisiblePhaseRows = 3;

/// 페이즈 팝오버에 보이는 재화 줄 수.
const planFlowSavePopoverRows = 6;

/// 섹션 [sectionId] 다각형의 캔버스 [y]에서의 왼쪽·오른쪽 x.
({double left, double right}) planFlowSectionSpanAt(
  Size size,
  String sectionId,
  double y,
) {
  final points = planFlowSectionPolygon(size, sectionId);
  final top = points.map((point) => point.dy).reduce(math.min);
  final bottom = points.map((point) => point.dy).reduce(math.max);
  final at = y.clamp(top, bottom).toDouble();
  var left = double.infinity;
  var right = double.negativeInfinity;
  for (var index = 0; index < points.length; index++) {
    final a = points[index];
    final b = points[(index + 1) % points.length];
    if (a.dy == b.dy) continue;
    if ((a.dy - at) * (b.dy - at) > 0) continue;
    final x = a.dx + (b.dx - a.dx) * (at - a.dy) / (b.dy - a.dy);
    left = math.min(left, x);
    right = math.max(right, x);
  }
  if (!left.isFinite || !right.isFinite) {
    final xs = points.map((point) => point.dx);
    return (left: xs.reduce(math.min), right: xs.reduce(math.max));
  }
  return (left: left, right: right);
}

/// 퍼센트 글자(충족률). 모르면 "—".
String planFlowSavePercent(double? rate) =>
    rate == null ? '—' : '${(rate * 100).round()}%';

/// 비교 값 "A → B".
String planFlowSaveDelta(Object? a, Object? b, {String unit = ''}) =>
    '${a ?? '—'} → ${b ?? '—'}$unit';

/// "가장 크게 늘어나는 재화" 오른쪽 글자(시안 "+96 · 부족 −12 → −30", "+48.2M · 여유 있음").
String planFlowSaveIncreaseText(PlanFlowSaveIncrease increase) {
  final delta = '+${growthCalculatorCompactNumber(increase.delta)}';
  final shortageB = increase.shortageB;
  if (shortageB == null) return '$delta · 보유 모름';
  if (shortageB == 0) return '$delta · 여유 있음';
  String amount(int? value) => value == null
      ? '—'
      : value == 0
      ? '0'
      : '−${growthCalculatorCompactNumber(value)}';
  return '$delta · 부족 ${amount(increase.shortageA)} → ${amount(shortageB)}';
}

/// 페이즈 팝오버·상태 칩이 쓰는 그 페이즈의 재화.
///
/// 비교가 있으면 후보 문서의 `phase_results`(페이즈로 추가는 활성 페이즈 뒤 병합 문서 기준), 없으면 초안 계산의
/// `phase_results`다. 페이즈로 추가에서는 초안만의 값으로 바꾸지 않는다(남은 양 기준이 달라서).
List<PlanFlowStageResource>? planFlowSavePhaseResources(
  PlanFlowSaveController save,
  PlanFlowPhase phase,
) {
  final append = save.target == PlanFlowSaveTarget.appendPhases;
  final comparison = save.comparison;
  if (comparison != null) {
    final id = append ? save.merged?.phaseIds[phase.id] : phase.id;
    final resources = id == null ? null : comparison.phaseResourcesB[id];
    if (resources != null) return resources;
  }
  if (append) return null;
  return save.flow.calculation?.phaseResources[phase.id];
}

/// 4단계 B 본문.
class PlanFlowSaveBody extends StatefulWidget {
  const PlanFlowSaveBody({super.key, required this.flow, required this.save});

  final PlanFlowController flow;
  final PlanFlowSaveController save;

  @override
  State<PlanFlowSaveBody> createState() => _PlanFlowSaveBodyState();
}

class _PlanFlowSaveBodyState extends State<PlanFlowSaveBody> {
  final _phaseGroup = KitOverlayGroup(debugLabel: 'plan flow save phases');

  PlanFlowController get flow => widget.flow;
  PlanFlowSaveController get save => widget.save;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([flow, save]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => _build(constraints.biggest),
    ),
  );

  Widget _build(Size size) {
    final sx = size.width / 2560;
    final sy = size.height / 1208;
    final bounds = planFlowSectionPolygon(size, planFlowBodySectionId);
    final sectionTop = bounds.map((point) => point.dy).reduce(math.min);
    final sectionBottom = bounds.map((point) => point.dy).reduce(math.max);
    final limit = sectionBottom - 12;
    double y(double protoTop) => (protoTop - 184) * sy;
    Rect row(double top, double height, double width, {double inset = 26}) {
      final span = planFlowSectionSpanAt(size, planFlowBodySectionId, top + height);
      final left = span.left + inset * sx;
      final right = math.min(span.right - 10 * sx, left + width * sx);
      return Rect.fromLTRB(left, top, math.max(left, right), top + height);
    }

    final draft = flow.draft;
    final phases = [
      for (final phase in draft.phases)
        if (phase.stageIds.isNotEmpty) phase,
    ];
    final children = <Widget>[];

    // 제목 줄.
    final titleTop = math.max(sectionTop + 8, y(229.2));
    final title = row(titleTop, 40, 1425.3, inset: 36);
    children.add(
      Positioned.fromRect(
        rect: title,
        child: Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '이렇게 만들어집니다',
                  style: kitDisplayStyle(AppType.headlineSize),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Row(
              key: const ValueKey('plan-flow-save-counts'),
              mainAxisSize: MainAxisSize.min,
              children: [
                BaChip(label: '페이즈 ${phases.length}개', tone: AppTones.gray),
                const SizedBox(width: 6),
                BaChip(label: '단계 ${draft.stageCount}개', tone: AppTones.gray),
              ],
            ),
          ],
        ),
      ),
    );

    // 세로 자리 나누기: 페이즈 목록 → 비교 → 늘어나는 재화. 모자라면 늘어나는 재화 줄, 그다음 페이즈 행을 줄인다.
    final comparison = save.comparison;
    final increases = comparison?.increases ?? const <PlanFlowSaveIncrease>[];
    const compareBlock = 26.0 + 24 + 8 + 110;
    double increaseBlock(int count) => count == 0 ? 0.0 : 38.0 + count * 64.0;
    final listTop = title.bottom + 16 * sy;
    double listHeight(int rows) =>
        rows * planFlowSavePhaseRowHeight +
        math.max(0, rows - 1) * planFlowSavePhaseRowGap;
    var phaseRows = math.min(
      math.max(phases.length, 1),
      planFlowSaveVisiblePhaseRows,
    );
    var increaseRows = math.max(increases.length, 1);
    double needed() =>
        listHeight(phaseRows) + compareBlock + increaseBlock(increaseRows);
    while (listTop + needed() > limit && increaseRows > 0) {
      increaseRows -= 1;
    }
    while (listTop + needed() > limit && phaseRows > 1) {
      phaseRows -= 1;
    }

    // 페이즈 행(80° 레일을 따라 미는 사선 스크롤 목록).
    final viewportHeight = listHeight(phaseRows);
    final viewportBottom = listTop + viewportHeight;
    final rowWidth = 1457.6 * sx;
    final span = planFlowSectionSpanAt(
      size,
      planFlowBodySectionId,
      viewportBottom,
    );
    const horizontalInset = 8.0;
    const scrollbarReserve = 14.0;
    final reduction = diagonalRowResizeReduction(
      viewportHeight: viewportHeight,
      rowHeight: planFlowSavePhaseRowHeight,
    );
    final viewportLeft = span.left + 26 * sx - horizontalInset;
    final viewportRight = math.min(
      span.right,
      viewportLeft +
          rowWidth +
          horizontalInset * 2 +
          scrollbarReserve +
          reduction,
    );
    final append = save.target == PlanFlowSaveTarget.appendPhases;
    final offset = append ? (save.snapshot?.activePhaseCount ?? 0) : 0;
    final statuses = planFlowStageStatuses(draft, flow.calculation);
    children.add(
      Positioned(
        left: viewportLeft,
        top: listTop,
        width: math.max(0.0, viewportRight - viewportLeft),
        height: viewportHeight,
        child: KeyedSubtree(
          key: const ValueKey('plan-flow-save-phases'),
          child: phases.isEmpty
              ? const Center(
                  child: Text('만들어질 페이즈가 없습니다', style: _mutedStyle),
                )
              : DiagonalScrollViewport(
                  keyPrefix: 'plan-flow-save-phase',
                  itemCount: phases.length,
                  itemHeight: (_) => planFlowSavePhaseRowHeight,
                  itemGap: planFlowSavePhaseRowGap,
                  verticalInset: 0,
                  horizontalInset: horizontalInset,
                  scrollbarReserve: scrollbarReserve,
                  itemBuilder: (context, index) => _PhaseRow(
                    key: ValueKey('plan-flow-save-phase-${phases[index].id}'),
                    flow: flow,
                    phase: phases[index],
                    number: offset + index + 1,
                    resources: planFlowSavePhaseResources(save, phases[index]),
                    calculating: flow.calculating || save.comparing,
                    blocked: phases[index].stageIds.any(
                      (id) => statuses[id] == PlanFlowStageStatus.blocked,
                    ),
                    group: _phaseGroup,
                  ),
                ),
        ),
      ),
    );

    // 지금 활성 계획과 비교.
    var top = viewportBottom + 26;
    final compareCaption = row(top, 24, 1445.6);
    children.add(
      Positioned.fromRect(
        rect: compareCaption,
        child: Padding(
          padding: EdgeInsets.only(left: 14.2 * sx),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text('지금 활성 계획과 비교', style: _captionStyle),
          ),
        ),
      ),
    );
    top = compareCaption.bottom + 8;
    final tile = row(top, 110, 1460.7);
    children.add(
      Positioned.fromRect(
        rect: tile,
        child: DiagonalRow(
          key: const ValueKey('plan-flow-save-compare'),
          variant: DiagonalRowVariant.tile,
          padding: EdgeInsets.symmetric(horizontal: 29.4 * sx + 12),
          child: _CompareTile(save: save),
        ),
      ),
    );
    top = tile.bottom;

    // 가장 크게 늘어나는 재화.
    if (increaseRows > 0) {
      top += 14;
      final caption = row(top, 24, 1445.6);
      children.add(
        Positioned.fromRect(
          rect: caption,
          child: Padding(
            padding: EdgeInsets.only(left: 14.2 * sx),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text('가장 크게 늘어나는 재화', style: _captionStyle),
            ),
          ),
        ),
      );
      top = caption.bottom + 8;
      if (increases.isEmpty) {
        final rect = row(top, 56, 1451.2);
        children.add(
          Positioned.fromRect(
            rect: rect,
            child: DiagonalRow(
              key: const ValueKey('plan-flow-save-increase-empty'),
              variant: DiagonalRowVariant.row,
              padding: EdgeInsets.symmetric(horizontal: 19.9 * sx + 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _increaseEmptyText(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle,
                ),
              ),
            ),
          ),
        );
      } else {
        for (final increase in increases.take(increaseRows)) {
          final rect = row(top, 56, 1451.2);
          children.add(
            Positioned.fromRect(
              rect: rect,
              child: _IncreaseRow(
                key: ValueKey(
                  'plan-flow-save-increase-${increase.resourceKey}',
                ),
                increase: increase,
                padding: 19.9 * sx + 12,
              ),
            ),
          );
          top = rect.bottom + 8;
        }
      }
    }

    return Stack(
      key: const ValueKey('plan-flow-save-body'),
      clipBehavior: Clip.none,
      children: children,
    );
  }

  String _increaseEmptyText() {
    if (save.comparing || save.loading) return '비교하고 있습니다';
    if (save.snapshot?.activeDocument == null) {
      return '활성 계획을 읽지 못해 비교할 수 없습니다';
    }
    if (save.comparisonError != null) return '비교하지 못했습니다';
    return '활성 계획보다 늘어나는 재화가 없습니다';
  }
}

/// 페이즈 행(시안 `.srow` 92) + 필요 재화 팝오버(`.phw/.php`).
class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    super.key,
    required this.flow,
    required this.phase,
    required this.number,
    required this.resources,
    required this.calculating,
    required this.blocked,
    required this.group,
  });

  final PlanFlowController flow;
  final PlanFlowPhase phase;

  /// P 번호(페이즈로 추가는 활성 페이즈 뒤 번호).
  final int number;
  final List<PlanFlowStageResource>? resources;
  final bool calculating;

  /// 이 페이즈에 막힌 단계(FD-035)가 있다.
  final bool blocked;
  final KitOverlayGroup group;

  int? get _shortageKinds {
    final resources = this.resources;
    if (resources == null ||
        !resources.any((resource) => resource.shortageAtEntry != null)) {
      return null;
    }
    return resources
        .where((resource) => (resource.shortageAtEntry ?? 0) > 0)
        .length;
  }

  Widget _statusChip() {
    final kinds = _shortageKinds;
    if (resources == null) {
      return BaChip(
        label: calculating ? '계산 중' : '—',
        tone: AppTones.gray,
      );
    }
    if (kinds == null) return const BaChip(label: '보유 모름', tone: AppTones.gray);
    if (kinds == 0) {
      return const BaChip(label: '모두 지금 가능', tone: AppTones.ok);
    }
    return BaChip(
      label: '부족 $kinds종',
      tone: blocked ? AppTones.danger : AppTones.warn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stages = [
      for (final id in phase.stageIds) ?flow.draft.stageById(id),
    ];
    final trigger = DiagonalRow(
      variant: DiagonalRowVariant.srow,
      padding: const EdgeInsets.symmetric(horizontal: 26.2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'P$number',
                style: kitDisplayStyle(
                  AppType.displaySmallSize,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '페이즈 $number',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle.copyWith(
                    fontSize: AppType.bodyLargeSize,
                    fontWeight: AppType.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${phase.name} 칸에서',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 칩 n개 폭 = n × 150 + (n − 1) × 8. 다 못 넣으면 "+n명" 자리(48)를 남긴다.
                const chipWidth = 150.0;
                const gap = 8.0;
                const moreWidth = 48.0;
                int fitting(double width) =>
                    math.max(0, ((width + gap) / (chipWidth + gap)).floor());
                final overflow = stages.length > fitting(constraints.maxWidth);
                final shown = overflow
                    ? fitting(constraints.maxWidth - moreWidth - gap)
                    : stages.length;
                return ClipRect(
                  child: Row(
                    children: [
                      for (final (index, stage) in stages.take(shown).indexed) ...[
                        if (index > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: chipWidth,
                          child: _StudentChip(
                            studentId: stage.studentId,
                            name: flow.context.displayName(stage.studentId),
                            step: stage.step,
                          ),
                        ),
                      ],
                      if (overflow) ...[
                        if (shown > 0) const SizedBox(width: gap),
                        SizedBox(
                          width: moreWidth,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '+${stages.length - shown}명',
                              style: _mutedStyle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          _statusChip(),
          const SizedBox(width: 12),
          const Icon(
            Icons.inventory_2_outlined,
            size: 15,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 4),
          const Text('재화', style: _mutedStyle),
          const Icon(
            Icons.chevron_right_rounded,
            size: 16,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
    return AnchoredFlyout(
      semanticLabel: '페이즈 $number 필요 재화 보기',
      panelLabel: '페이즈 $number 필요 재화',
      preset: FlyoutPreset.phase,
      group: group,
      children: _panel(),
      child: SizedBox.expand(child: trigger),
    );
  }

  List<Widget> _panel() {
    final resources = this.resources;
    final kinds = _shortageKinds;
    final header = FlyoutHeader(
      '필요 재화',
      leading: Text(
        'P$number',
        style: kitDisplayStyle(AppType.titleLargeSize, color: AppColors.accent),
      ),
      trailing: kinds == null
          ? null
          : kinds == 0
          ? const BaChip(label: '부족 없음', tone: AppTones.ok)
          : BaChip(label: '부족 $kinds종', tone: AppTones.warn),
    );
    const footer = FlyoutFooter(text: '앞 페이즈에서 쓰고 남은 양 기준입니다');
    if (resources == null || resources.isEmpty) {
      return [
        header,
        FlyoutRow(
          children: [
            Expanded(
              child: Text(
                resources != null
                    ? '이 페이즈에 드는 재화가 없습니다'
                    : calculating
                    ? '필요 재화를 계산하고 있습니다'
                    : '필요 재화를 계산하지 못했습니다',
                style: _mutedStyle,
              ),
            ),
          ],
        ),
        footer,
      ];
    }
    final sorted = [...resources]
      ..sort((a, b) {
        final byShortage = (b.shortageAtEntry ?? 0).compareTo(
          a.shortageAtEntry ?? 0,
        );
        return byShortage != 0 ? byShortage : b.required.compareTo(a.required);
      });
    return [
      header,
      for (final resource in sorted.take(planFlowSavePopoverRows))
        FlyoutRow(
          key: ValueKey(
            'plan-flow-save-phase-${phase.id}-resource-${resource.resourceKey}',
          ),
          children: [
            ItemIconTile(
              iconAsset: planningResourceIconAsset(
                category: resource.category,
                itemId: resource.itemId,
              ),
              size: ItemIconSizes.s42,
            ),
            Expanded(
              child: Text(
                resource.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle.copyWith(fontWeight: AppType.bold),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                '필요 ${growthCalculatorCompactNumber(resource.required)}',
                maxLines: 1,
                textAlign: TextAlign.right,
                style: _mutedStyle,
              ),
            ),
            _resourceChip(resource),
          ],
        ),
      if (sorted.length > planFlowSavePopoverRows)
        Text(
          '외 ${sorted.length - planFlowSavePopoverRows}종',
          style: _mutedStyle,
        ),
      footer,
    ];
  }

  static Widget _resourceChip(PlanFlowStageResource resource) {
    final shortage = resource.shortageAtEntry;
    final owned = resource.ownedAtEntry;
    if (shortage == null) {
      return const BaChip(label: '보유 모름', tone: AppTones.gray);
    }
    if (shortage > 0) {
      return BaChip(
        label: '−${growthCalculatorCompactNumber(shortage)}',
        tone: owned == 0 ? AppTones.danger : AppTones.warn,
      );
    }
    if (resource.isCredits && owned != null) {
      return BaChip(
        label:
            '여유 ${growthCalculatorCompactNumber(owned - resource.required)}',
        tone: AppTones.ok,
      );
    }
    return const BaChip(label: '충분', tone: AppTones.ok);
  }
}

/// 페이즈 행의 학생 칩: 초상 42×34 · 이름 · 단계 태그.
class _StudentChip extends StatelessWidget {
  const _StudentChip({
    required this.studentId,
    required this.name,
    required this.step,
  });

  final String studentId;
  final String name;
  final int step;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Color.fromRGBO(255, 255, 255, 0.04),
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          PortraitStrip(
            studentIds: [studentId],
            maxVisible: 1,
            portraitSize: const Size(42, 34),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle.copyWith(
                    fontSize: AppType.bodySmallSize,
                    fontWeight: AppType.bold,
                  ),
                ),
                const SizedBox(height: 2),
                StageTag(stage: step),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 비교 타일 4칸(시안 `.tile` 110: 계획 충족률 · 부족 재화 · 필요 크레딧 · 학생).
class _CompareTile extends StatelessWidget {
  const _CompareTile({required this.save});

  final PlanFlowSaveController save;

  @override
  Widget build(BuildContext context) {
    final comparison = save.comparison;
    if (comparison == null) {
      final text = save.loading || save.comparing
          ? '활성 계획과 비교하고 있습니다'
          : save.snapshot != null && save.snapshot!.activeDocument == null
          ? '활성 계획을 읽지 못해 비교할 수 없습니다'
          : save.comparisonError != null || save.loadError != null
          ? '활성 계획과 비교하지 못했습니다'
          : '활성 계획과 비교하고 있습니다';
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          key: const ValueKey('plan-flow-save-compare-status'),
          style: _mutedStyle,
        ),
      );
    }
    final a = comparison.fulfillmentA;
    final b = comparison.fulfillmentB;
    final rateA = a.rate;
    final rateB = b.rate;
    final shortageA = comparison.shortageKindsA;
    final shortageB = comparison.shortageKindsB;
    String credits(int? value) =>
        value == null ? '—' : growthCalculatorCompactNumber(value);
    final cells = [
      (
        'fulfillment',
        b.unknown > 0 ? '계획 충족률 · ${b.unknown}종 모름' : '계획 충족률',
        '${planFlowSavePercent(rateA)} → ${planFlowSavePercent(rateB)}',
        rateA != null && rateB != null && rateB < rateA
            ? AppColors.warning
            : AppColors.text,
      ),
      (
        'shortage',
        '부족 재화',
        planFlowSaveDelta(shortageA, shortageB, unit: '종'),
        shortageA != null && shortageB != null && shortageB > shortageA
            ? AppColors.warning
            : AppColors.text,
      ),
      (
        'credits',
        '필요 크레딧',
        '${credits(comparison.creditsA)} → ${credits(comparison.creditsB)}',
        AppColors.text,
      ),
      (
        'students',
        '학생',
        planFlowSaveDelta(
          comparison.studentsA,
          comparison.studentsB,
          unit: '명',
        ),
        AppColors.text,
      ),
    ];
    return Row(
      children: [
        for (final (index, (key, label, value, color)) in cells.indexed) ...[
          if (index > 0) const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: KV(
                key: ValueKey('plan-flow-save-compare-$key'),
                label: label,
                value: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: kitDisplayStyle(
                      AppType.displaySmallSize,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "가장 크게 늘어나는 재화" 한 줄(시안 `.srow` 56).
class _IncreaseRow extends StatelessWidget {
  const _IncreaseRow({
    super.key,
    required this.increase,
    required this.padding,
  });

  final PlanFlowSaveIncrease increase;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final shortage = increase.shortageB;
    return DiagonalRow(
      variant: DiagonalRowVariant.srow,
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        children: [
          ItemIconTile(
            iconAsset: planningResourceIconAsset(
              category: increase.category,
              itemId: increase.itemId,
            ),
            size: ItemIconSizes.s52,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: Text(
              increase.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _bodyStyle.copyWith(fontSize: AppType.titleSmallSize),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SkewBar.tone(
              fraction: increase.coverage,
              tone: shortage != null && shortage > 0
                  ? CoverageTone.shortage
                  : CoverageTone.enough,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 190,
            child: Text(
              planFlowSaveIncreaseText(increase),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _mutedStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 4단계 C 보조: 저장 위치 3지선다 · 이름 · 저장한 뒤 · 저장 버튼.
class PlanFlowSaveAside extends StatelessWidget {
  const PlanFlowSaveAside({
    super.key,
    required this.flow,
    required this.save,
    required this.onSave,
  });

  final PlanFlowController flow;
  final PlanFlowSaveController save;

  /// 저장(A 레일 primary와 같은 동작, FD-079).
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([flow, save]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => _build(constraints.biggest),
    ),
  );

  Widget _build(Size size) {
    final sx = size.width / 2560;
    final sy = size.height / 1208;
    final right = planFlowProtoRect(size, 2538, 0, 0, 0).left;
    double y(double protoTop) => (protoTop - 184) * sy;
    Rect row(double top, double height, double inset) {
      final left = planFlowAsideLeftAt(size, top) + inset * sx;
      return Rect.fromLTRB(left, top, math.max(left, right), top + height);
    }

    Widget caption(String text) => Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _captionStyle,
      ),
    );

    final children = <Widget>[];
    var top = y(231.2);
    final title = row(top, 36, 30);
    children.add(
      Positioned.fromRect(
        rect: title,
        child: Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '어디에 넣으시겠습니까',
                  key: const ValueKey('plan-flow-save-aside-title'),
                  style: kitDisplayStyle(AppType.panelTitleSize),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const InfoPopover(
              label: '저장 도움말',
              title: '저장',
              width: 300,
              align: KitOverlayAlign.end,
              children: [
                InfoPopoverText.plain(
                  '어느 쪽을 골라도 학생·목표·단계는 한 묶음으로 남아서, 나중에 1~3단계 어디로든 돌아와 고칠 수 '
                  '있습니다.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
    top = title.bottom + 14 * sy;

    final phaseCount = [
      for (final phase in flow.draft.phases)
        if (phase.stageIds.isNotEmpty) phase,
    ].length;
    for (final target in PlanFlowSaveTarget.values) {
      final rect = row(top, 72, 11.4);
      final available = save.isAvailable(target);
      final selected = save.target == target;
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: Opacity(
            opacity: available ? 1 : 0.45,
            child: Semantics(
              selected: selected,
              inMutuallyExclusiveGroup: true,
              child: DiagonalRow(
                key: ValueKey('plan-flow-save-target-${target.name}'),
                variant: DiagonalRowVariant.srow,
                mark: selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
                onTap: available && !save.saving
                    ? () => save.selectTarget(target)
                    : null,
                padding: const EdgeInsets.only(left: 24.7, right: 14),
                child: Row(
                  children: [
                    _Radio(selected: selected),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            target.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _bodyStyle.copyWith(
                              fontSize: AppType.titleSmallSize,
                              fontWeight: AppType.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            planFlowSaveTargetSubtitle(
                              target,
                              save: save,
                              newPhaseCount: phaseCount,
                            ),
                            key: ValueKey(
                              'plan-flow-save-target-${target.name}-subtitle',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _mutedStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      top = rect.bottom + 8 * sy;
    }
    top += 10 * sy;

    // 이름(패널 안 입력, 다이얼로그 아님).
    final activeEmpty = (save.snapshot?.activePhaseCount ?? 1) == 0;
    final nameCaption = row(top, 24, 19.9);
    children.add(
      Positioned.fromRect(
        rect: nameCaption,
        child: caption(switch (save.target) {
          PlanFlowSaveTarget.scenario => '시나리오 이름',
          PlanFlowSaveTarget.appendPhases => '활성 계획',
          PlanFlowSaveTarget.replace => '옮겨 둘 기존 계획 이름',
        }),
      ),
    );
    top = nameCaption.bottom + 6 * sy;
    final nameRow = row(top, 48, 15.5);
    final Widget nameContent = switch (save.target) {
      PlanFlowSaveTarget.scenario => _NameField(
        key: const ValueKey('plan-flow-save-name-field'),
        value: save.scenarioName,
        hint: '시나리오 이름',
        enabled: !save.saving,
        onChanged: (value) => save.scenarioName = value,
      ),
      PlanFlowSaveTarget.replace when !activeEmpty => _NameField(
        key: const ValueKey('plan-flow-save-archive-field'),
        value: save.archiveName,
        hint: '옮겨 둘 기존 계획 이름',
        enabled: !save.saving,
        onChanged: (value) => save.archiveName = value,
      ),
      PlanFlowSaveTarget.replace => const Text(
        '기존 활성 계획이 비어 있어 옮겨 둘 것이 없습니다',
        key: ValueKey('plan-flow-save-archive-empty'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _mutedStyle,
      ),
      PlanFlowSaveTarget.appendPhases => const Text(
        '활성 계획 이름은 그대로 두고 페이즈만 붙입니다',
        key: ValueKey('plan-flow-save-append-name'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _mutedStyle,
      ),
    };
    children.add(
      Positioned.fromRect(
        rect: nameRow,
        child: DiagonalRow(
          variant: DiagonalRowVariant.row,
          padding: const EdgeInsets.only(left: 20.5, right: 14),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: nameContent,
                ),
              ),
              if (nameContent is _NameField) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
    top = nameRow.bottom + 12 * sy;

    // 저장한 뒤(독립 토글 2개, FD-079).
    final afterCaption = row(top, 24, 19.9);
    children.add(
      Positioned.fromRect(rect: afterCaption, child: caption('저장한 뒤')),
    );
    top = afterCaption.bottom + 6 * sy;
    final toggles = [
      (
        'plan-flow-save-open-scenarios',
        '시나리오 보기로 이동',
        save.openScenarioList,
        (bool value) => save.openScenarioList = value,
      ),
      (
        'plan-flow-save-keep-order',
        '단계 순서는 페이즈 편집에서 다시 바꿀 수 있게 유지',
        save.keepOrderEditable,
        (bool value) => save.keepOrderEditable = value,
      ),
    ];
    for (final (key, label, value, onChanged) in toggles) {
      final rect = row(top, 46, 15.9);
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: DiagonalRow(
            variant: DiagonalRowVariant.plain,
            padding: const EdgeInsets.only(left: 20.1, right: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle,
                  ),
                ),
                const SizedBox(width: 10),
                BaSwitch(
                  key: ValueKey(key),
                  value: value,
                  semanticLabel: label,
                  onChanged: save.saving ? null : onChanged,
                ),
              ],
            ),
          ),
        ),
      );
      top = rect.bottom + 4 * sy;
    }
    top += 16 * sy;

    // 저장 버튼(A primary와 같은 동작·같은 글자).
    final button = row(top, 58, 13.8);
    children.add(
      Positioned.fromRect(
        rect: button,
        child: RailButton(
          key: const ValueKey('plan-flow-save-confirm'),
          variant: RailButtonVariant.primary,
          height: 58,
          semanticLabel: save.target.label,
          onPressed: save.canSave ? onSave : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  save.saving ? '저장하고 있습니다' : save.target.label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: AppType.bodyLargeSize,
                    fontWeight: AppType.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.check_rounded),
              ],
            ),
          ),
        ),
      ),
    );
    top = button.bottom + 12 * sy;

    // 안내(저장 실패·다시 읽음·읽기 실패) + 다시 읽기.
    final message =
        save.message ??
        (save.loadError != null ? '저장 직전 상태를 읽지 못했습니다' : null);
    if (message != null) {
      final rect = row(top, 64, 19.9);
      final error = save.messageIsError || save.loadError != null;
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  message,
                  key: const ValueKey('plan-flow-save-message'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle.copyWith(
                    color: error ? AppColors.danger : AppColors.textMuted,
                  ),
                ),
              ),
              if (error) ...[
                const SizedBox(width: 8),
                TonalButton(
                  key: const ValueKey('plan-flow-save-reload'),
                  label: '다시 읽기',
                  icon: Icons.refresh_rounded,
                  onPressed: save.loading || save.saving
                      ? null
                      : () => save.reload(),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Stack(
      key: const ValueKey('plan-flow-save-aside'),
      clipBehavior: Clip.none,
      children: children,
    );
  }
}

/// 3지선다 동그라미(시안 20px, 고르면 가운데 10px 핑크 점).
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? AppColors.accent : AppColors.textMuted,
        width: 1.5,
      ),
    ),
    alignment: Alignment.center,
    child: selected
        ? const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
            child: SizedBox.square(dimension: 10),
          )
        : null,
  );
}

/// 패널 안 이름 입력.
class _NameField extends StatefulWidget {
  const _NameField({
    super.key,
    required this.value,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_NameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    enabled: widget.enabled,
    maxLines: 1,
    textInputAction: TextInputAction.done,
    onChanged: widget.onChanged,
    style: _bodyStyle.copyWith(fontSize: AppType.titleSmallSize),
    decoration: InputDecoration.collapsed(
      hintText: widget.hint,
      hintStyle: _mutedStyle,
    ),
  );
}
