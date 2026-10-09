// 계획 만들기 3단계 단계 순서(FE4-d1, 시안 Flow-3-Order, FD-035·FD-069·FD-070·FD-071).
//
// - B 본문: 칸(= 페이즈) 보드. 칸은 80° 레일을 따라 한 칸(228)마다 40.2씩 왼쪽으로 놓이고(스크롤하면 보이는 높이에
//   맞춰 다시 놓는다), 카드는 칸마다 한 줄에 셋, 넘치면 다음 줄로 접힌다. 카드를 끌어 칸 사이·칸 안에서 옮긴다.
//   같은 학생 단계는 회색 실선 화살표로 이어지고, 선행보다 앞 칸에 놓으면 거부하고 이유를 보인다. 같은 칸은 허용하고
//   선행 → 후행 순서로 다시 놓는다(FD-069). 카드 상태 배지는 가능·부족·막힘(FD-035, 초안 계산 결과).
// - 칸 머리 이름은 바로 고친다(기본 "n순위"), 마지막 칸 아래 "칸 추가", 빈 칸은 저장 때 빠진다(FD-071).
// - C 보조: 고른 카드 상세(포함한 목표 · 먼저 끝나야 하는 단계 · 이 칸에서 부족한 재화) + 자동 정렬 3종.
// - 직접 선행(분홍 점선)과 "나중에" 칸은 FE4-f, 단계가 많을 때 작게 보기는 FE4-d2에서 더한다.
// 좌표는 시안(2560×1392, 헤더 184 아래가 캔버스)의 값이다([planFlowProtoRect]).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/diagonal_row.dart';
import '../kit/info_popover.dart';
import '../kit/item_icon_tile.dart';
import '../kit/portrait_strip.dart';
import '../kit/titles.dart';
import '../models/plan_flow_draft.dart';
import '../models/plan_flow_order_editor.dart';
import '../models/planning_resource_assets.dart';
import 'plan_flow_goal_step.dart' show planFlowGoalAmount, planFlowGoalCostLine;
import 'plan_flow_student_step.dart' show planFlowAsideLeftAt, planFlowProtoRect;

/// tan 10°: 80° 레일에서 세로 1당 가로 이동.
const _railSlope = 0.17632698070846498;

/// 카드 시안 크기(`.srow` 398.4×150).
const planFlowOrderCardSize = Size(398.4, 150);

/// 칸 안 카드 간격(시안 x 610.3 → 1022.3 → 1434.3).
const planFlowOrderCardPitch = 412.0;

/// 칸 한 줄의 카드 수.
const planFlowOrderCardsPerRow = 3;

/// 칸 타일 폭(시안 `.tile` 1479.1).
const planFlowOrderLaneWidth = 1479.1;

/// 카드 한 줄인 칸의 높이(시안 214)와 줄이 늘 때 더하는 높이.
const _laneBaseHeight = 214.0;
const _rowPitch = 164.0;
const _laneGap = 14.0;

/// 칸 위에서 첫 카드 줄까지(시안 285.2 → 333.2).
const _cardTop = 48.0;

/// 카드 왼쪽은 그 높이의 레일 선보다 2.3 왼쪽이다(시안 610.3).
const _cardInset = -2.3;

/// 칸 머리는 레일 선보다 14.9 오른쪽이다(시안 636).
const _headerInset = 14.9;

/// "칸 추가" 버튼 높이·폭.
const _addHeight = 56.0;
const _addWidth = 360.0;

/// 보드 자리(시안 x 400, y 285.2, 폭 1701.9, 범례 위까지).
const _boardLeft = 400.0;
const _boardTop = 285.2;
const _boardSize = Size(1701.9, 1050.8);

/// 보드 안 레일 선(칸 타일 윗변 왼쪽 꼭짓점이 놓이는 선): x = [_laneLineX] − y·tan10.
const _laneLineX = 183.4 + _laneBaseHeight * _railSlope;

/// 같은 학생 자동 연결 화살표(시안 stroke rgba(195,207,219,.55)).
const planFlowOrderArrowColor = Color.fromRGBO(195, 207, 219, 0.55);
const _dropText = Color(0xff9eb0c2);

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

/// 시안 크기 [design]로 그린 [child]를 [rect]에 같은 비율로 맞춘다.
Widget _designBox(
  Rect rect,
  Size design,
  Widget child, {
  Alignment alignment = Alignment.topLeft,
}) => Positioned.fromRect(
  rect: rect,
  child: FittedBox(
    fit: BoxFit.contain,
    alignment: alignment,
    child: SizedBox.fromSize(size: design, child: child),
  ),
);

String _shortName(String name) {
  final parts = name.split(' · ');
  return parts.length > 1 ? parts.last : name;
}

/// 카드 상태 배지(FD-035). 미보유 학생은 "모집 필요"(FD-076).
({String label, AppTone tone}) planFlowOrderStatusChip(
  PlanFlowStageStatus? status, {
  required bool owned,
  required bool calculating,
}) {
  if (!owned) return (label: '모집 필요', tone: AppTones.warn);
  return switch (status) {
    null => (label: calculating ? '계산 중' : '—', tone: AppTones.gray),
    PlanFlowStageStatus.possible => (label: '가능', tone: AppTones.ok),
    PlanFlowStageStatus.short => (label: '부족', tone: AppTones.warn),
    PlanFlowStageStatus.blocked => (label: '막힘', tone: AppTones.danger),
  };
}

/// 칸 머리 상태 칩(시안 `모두 지금 가능`·`부족 n종`). 빈 칸이거나 계산 전이면 null.
({String label, AppTone tone})? planFlowOrderLaneChip(
  PlanFlowPhase phase,
  Map<String, PlanFlowStageStatus> statuses,
  List<PlanFlowLaneShortage>? shortages, {
  required bool calculating,
}) {
  if (phase.stageIds.isEmpty) return null;
  if (shortages == null) {
    return calculating ? (label: '계산 중', tone: AppTones.gray) : null;
  }
  final blocked = phase.stageIds.any(
    (id) => statuses[id] == PlanFlowStageStatus.blocked,
  );
  if (shortages.isNotEmpty) {
    return (
      label: '부족 ${shortages.length}종',
      tone: blocked ? AppTones.danger : AppTones.warn,
    );
  }
  if (blocked) return (label: '막힘', tone: AppTones.danger);
  return (label: '모두 지금 가능', tone: AppTones.ok);
}

/// 카드 비용 한 줄: 모자라는 재화가 있으면 가장 많이 모자란 재화와 종류 수, 없으면 크레딧 + 많이 드는 재화.
String planFlowOrderCostLine(
  PlanFlowStageCost? cost, {
  required bool owned,
  required bool calculating,
}) {
  if (!owned) return '모집 비용은 계산하지 않습니다';
  if (cost == null) return calculating ? '비용을 계산하고 있습니다' : '비용 —';
  final short = [
    for (final resource in cost.resources)
      if ((resource.shortageAtEntry ?? 0) > 0) resource,
  ]..sort((a, b) => (b.shortageAtEntry ?? 0).compareTo(a.shortageAtEntry ?? 0));
  if (short.isEmpty) return planFlowGoalCostLine(cost);
  final top = short.first;
  final amount = planFlowGoalAmount(top.shortageAtEntry ?? 0);
  final more = short.length > 1 ? ' · 부족 ${short.length}종' : '';
  return '${_shortName(top.name)} −$amount$more';
}

/// 카드 목표 요약(시안 `Lv.90 · 장비 T9 ×3`, 미보유 `모집 · Lv.80`).
String planFlowOrderGoalSummary(
  List<PlanFlowGoalChange> changes, {
  required bool owned,
}) {
  final parts = [
    if (!owned) '모집',
    for (final change in changes.take(owned ? 2 : 1)) change.short,
  ];
  if (changes.isEmpty) return owned ? '올린 목표가 없습니다' : '모집';
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// 보드 배치

/// 칸 하나의 배치(보드 시안 좌표, 보드 왼쪽 위가 원점).
@immutable
class _LaneLayout {
  const _LaneLayout({
    required this.phase,
    required this.tile,
    required this.cards,
  });

  final PlanFlowPhase phase;

  /// 칸 타일 상자(평행사변형의 바깥 상자).
  final Rect tile;

  /// 단계 id → 카드 상자(보드 좌표).
  final Map<String, Rect> cards;

  int get rows => math.max(
    1,
    (phase.stageIds.length + planFlowOrderCardsPerRow - 1) ~/
        planFlowOrderCardsPerRow,
  );
}

@immutable
class _BoardLayout {
  const _BoardLayout({
    required this.lanes,
    required this.add,
    required this.height,
  });

  /// [phases]를 칸 순서대로 놓는다. [scroll]만큼 올라간 보드에서 보이는 높이로 레일 선의 x를 정한다.
  factory _BoardLayout.of(List<PlanFlowPhase> phases, {double scroll = 0}) {
    double lineX(double y) => _laneLineX - (y - scroll) * _railSlope;
    final lanes = <_LaneLayout>[];
    var top = 0.0;
    for (final phase in phases) {
      final count = phase.stageIds.length;
      final rows = math.max(
        1,
        (count + planFlowOrderCardsPerRow - 1) ~/ planFlowOrderCardsPerRow,
      );
      final height = _laneBaseHeight + _rowPitch * (rows - 1);
      final tile = Rect.fromLTWH(
        lineX(top) - height * _railSlope,
        top,
        planFlowOrderLaneWidth,
        height,
      );
      final cards = <String, Rect>{};
      for (final (position, id) in phase.stageIds.indexed) {
        final row = position ~/ planFlowOrderCardsPerRow;
        final column = position % planFlowOrderCardsPerRow;
        final cardTop = top + _cardTop + _rowPitch * row;
        cards[id] = Rect.fromLTWH(
          lineX(cardTop) + _cardInset + planFlowOrderCardPitch * column,
          cardTop,
          planFlowOrderCardSize.width,
          planFlowOrderCardSize.height,
        );
      }
      lanes.add(_LaneLayout(phase: phase, tile: tile, cards: cards));
      top += height + _laneGap;
    }
    final add = Rect.fromLTWH(
      lineX(top) - _addHeight * _railSlope,
      top,
      _addWidth,
      _addHeight,
    );
    return _BoardLayout(
      lanes: lanes,
      add: add,
      height: add.bottom + 24,
    );
  }

  final List<_LaneLayout> lanes;
  final Rect add;
  final double height;

  Rect? cardOf(String stageId) {
    for (final lane in lanes) {
      final card = lane.cards[stageId];
      if (card != null) return card;
    }
    return null;
  }
}

/// 같은 학생 단계 사이 화살표 하나(보드 좌표).
@immutable
class PlanFlowOrderArrow {
  const PlanFlowOrderArrow(this.from, this.to);

  final Offset from;
  final Offset to;
}

/// [from] 카드에서 [to] 카드로 가는 화살표. 같은 줄이면 옆으로, 아니면 아래 카드 위로 간다.
PlanFlowOrderArrow planFlowOrderArrowBetween(Rect from, Rect to) {
  final sameRow = (from.top - to.top).abs() < 1;
  if (sameRow) {
    final cut = diagonalCutDepth(from.height);
    final y = from.center.dy;
    return PlanFlowOrderArrow(
      Offset(from.right - cut / 2 + 2, y),
      Offset(to.left + cut / 2 - 3, y),
    );
  }
  return PlanFlowOrderArrow(
    Offset(from.left + 186, from.bottom),
    Offset(to.left + 212.5, to.top - 6),
  );
}

// ---------------------------------------------------------------------------
// B 본문

/// 3단계 B 본문. 콘텐츠 캔버스 전체를 받는다. 처음 그린 뒤 칸에 없는 단계를 칸에 넣는다.
class PlanFlowOrderBody extends StatefulWidget {
  const PlanFlowOrderBody({
    super.key,
    required this.flow,
    required this.editor,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;

  @override
  State<PlanFlowOrderBody> createState() => _PlanFlowOrderBodyState();
}

class _PlanFlowOrderBodyState extends State<PlanFlowOrderBody> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.editor.ensurePlaced();
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.flow, widget.editor]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => _build(constraints.biggest),
    ),
  );

  Widget _build(Size size) {
    final flow = widget.flow;
    final editor = widget.editor;
    final draft = flow.draft;
    final message = editor.message;
    return Stack(
      key: const ValueKey('plan-flow-order-body'),
      children: [
        _designBox(
          planFlowProtoRect(size, 635.5, 229.2, 1425.3, 40),
          const Size(1425.3, 40),
          Row(
            children: [
              Text('단계 순서 정하기', style: kitDisplayStyle(AppType.headlineSize)),
              const SizedBox(width: 10),
              const InfoPopover(
                key: ValueKey('plan-flow-order-info'),
                label: '단계 순서 정하는 법',
                title: '단계 순서 정하는 법',
                width: 360,
                children: [
                  InfoPopoverList([
                    '카드를 끌어 칸을 옮깁니다. 칸 안에서도 끌어 순서를 바꿉니다.',
                    '같은 학생의 단계는 자동으로 이어지고, 선행 단계보다 앞 칸에는 놓을 수 없습니다.',
                    '칸 이름을 눌러 바꿉니다. 칸이 그대로 계획의 페이즈가 되고, 빈 칸은 저장할 때 빠집니다.',
                  ]),
                ],
              ),
              const SizedBox(width: 12),
              BaChip(
                key: const ValueKey('plan-flow-order-count'),
                label: '단계 ${draft.stageCount}개',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: message == null
                    ? const SizedBox.shrink()
                    : Semantics(
                        liveRegion: true,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.block_rounded,
                              size: 18,
                              color: AppColors.danger,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                message,
                                key: const ValueKey('plan-flow-order-message'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _bodyStyle.copyWith(
                                  color: AppTones.danger.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
        ),
        if (!draft.hasStages)
          Positioned.fromRect(
            rect: planFlowProtoRect(size, 622.2, 285.2, 1400, 120),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '2단계에서 목표 단계를 만들면 여기서 순서를 정합니다.',
                key: ValueKey('plan-flow-order-empty'),
                style: _bodyStyle,
              ),
            ),
          )
        else
          _designBox(
            planFlowProtoRect(
              size,
              _boardLeft,
              _boardTop,
              _boardSize.width,
              _boardSize.height,
            ),
            _boardSize,
            _OrderBoard(flow: flow, editor: editor),
          ),
        _designBox(
          planFlowProtoRect(size, 442, 1342, 600, 24),
          const Size(600, 24),
          const Row(
            key: ValueKey('plan-flow-order-legend'),
            children: [
              SizedBox(
                width: 28,
                height: 2,
                child: ColoredBox(color: planFlowOrderArrowColor),
              ),
              SizedBox(width: 8),
              Text(
                '같은 학생 · 자동',
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySmallSize,
                  fontWeight: AppType.medium,
                  color: _dropText,
                ),
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
        ),
      ],
    );
  }
}

/// 칸 보드(시안 1701.9×1050.8, 세로 스크롤).
class _OrderBoard extends StatefulWidget {
  const _OrderBoard({required this.flow, required this.editor});

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;

  @override
  State<_OrderBoard> createState() => _OrderBoardState();
}

class _OrderBoardState extends State<_OrderBoard> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const ValueKey('plan-flow-order-scroll'),
    controller: _scroll,
    child: ListenableBuilder(
      listenable: _scroll,
      builder: (context, _) => _content(
        _scroll.hasClients ? _scroll.offset : 0.0,
      ),
    ),
  );

  Widget _content(double scroll) {
    final flow = widget.flow;
    final editor = widget.editor;
    final draft = flow.draft;
    final layout = _BoardLayout.of(draft.phases, scroll: scroll);
    final statuses = editor.statuses;
    final selected = editor.selectedStageId;
    final arrows = <PlanFlowOrderArrow>[];
    final byStudent = <String, List<PlanFlowStage>>{};
    for (final stage in draft.stages) {
      byStudent.putIfAbsent(stage.studentId, () => []).add(stage);
    }
    for (final stages in byStudent.values) {
      for (var index = 1; index < stages.length; index++) {
        final from = layout.cardOf(stages[index - 1].id);
        final to = layout.cardOf(stages[index].id);
        if (from != null && to != null) {
          arrows.add(planFlowOrderArrowBetween(from, to));
        }
      }
    }
    return SizedBox(
      width: _boardSize.width,
      height: math.max(layout.height, _boardSize.height),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final lane in layout.lanes)
            Positioned.fromRect(
              key: ValueKey('plan-flow-order-lane-${lane.phase.id}'),
              rect: lane.tile,
              child: _Lane(
                flow: flow,
                editor: editor,
                lane: lane,
                statuses: statuses,
                selectedStageId: selected,
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('plan-flow-order-arrows'),
                painter: PlanFlowOrderArrowPainter(arrows),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: layout.add,
            child: DiagonalRow(
              key: const ValueKey('plan-flow-order-add-lane'),
              variant: DiagonalRowVariant.tile,
              onTap: editor.addPhase,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: const Row(
                children: [
                  Icon(Icons.add_rounded, size: 20, color: AppColors.text),
                  SizedBox(width: 8),
                  Text('칸 추가', style: _bodyStyle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 같은 학생 자동 연결 화살표(회색 실선, 끝에 꺾쇠).
class PlanFlowOrderArrowPainter extends CustomPainter {
  const PlanFlowOrderArrowPainter(this.arrows);

  final List<PlanFlowOrderArrow> arrows;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = planFlowOrderArrowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final arrow in arrows) {
      final delta = arrow.to - arrow.from;
      final length = delta.distance;
      if (length < 1) continue;
      final direction = delta / length;
      final normal = Offset(-direction.dy, direction.dx);
      canvas.drawLine(arrow.from, arrow.to, paint);
      final back = arrow.to - direction * 6;
      canvas.drawPath(
        Path()
          ..moveTo(back.dx + normal.dx * 5, back.dy + normal.dy * 5)
          ..lineTo(arrow.to.dx, arrow.to.dy)
          ..lineTo(back.dx - normal.dx * 5, back.dy - normal.dy * 5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(PlanFlowOrderArrowPainter oldDelegate) {
    if (oldDelegate.arrows.length != arrows.length) return true;
    for (var index = 0; index < arrows.length; index++) {
      if (oldDelegate.arrows[index].from != arrows[index].from ||
          oldDelegate.arrows[index].to != arrows[index].to) {
        return true;
      }
    }
    return false;
  }
}

/// 칸 하나(타일 · 머리 · 카드). 칸 전체가 끌어 놓는 자리다.
class _Lane extends StatelessWidget {
  const _Lane({
    required this.flow,
    required this.editor,
    required this.lane,
    required this.statuses,
    required this.selectedStageId,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;
  final _LaneLayout lane;
  final Map<String, PlanFlowStageStatus> statuses;
  final String? selectedStageId;

  /// 칸 안 [local] 위치에 놓을 때의 자리(지금 보이는 카드 목록 기준).
  int _insertIndex(Offset local) {
    final ids = lane.phase.stageIds;
    if (ids.isEmpty) return 0;
    final rawRow = ((local.dy - _cardTop + _laneGap / 2) / _rowPitch).floor();
    final row = math.max(0, math.min(rawRow, lane.rows - 1));
    var index = row * planFlowOrderCardsPerRow;
    for (var column = 0; column < planFlowOrderCardsPerRow; column++) {
      final position = row * planFlowOrderCardsPerRow + column;
      if (position >= ids.length) break;
      final card = lane.cards[ids[position]];
      if (card == null) continue;
      if (local.dx > card.center.dx - lane.tile.left) index = position + 1;
    }
    return math.min(index, ids.length);
  }

  @override
  Widget build(BuildContext context) {
    final phase = lane.phase;
    final calculating = flow.calculating;
    final chip = planFlowOrderLaneChip(
      phase,
      statuses,
      editor.laneShortages(phase),
      calculating: calculating,
    );
    final origin = lane.tile.topLeft;
    // 머리는 타일 윗변 왼쪽 꼭짓점(타일 상자 왼쪽 + 높이·tan10)에서 [_headerInset]만큼 오른쪽이다.
    final headerLeft = lane.tile.height * _railSlope + _headerInset;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final box = context.findRenderObject();
        final index = box is RenderBox
            ? _insertIndex(box.globalToLocal(details.offset))
            : null;
        editor.move(details.data, phaseId: phase.id, index: index);
      },
      builder: (context, candidates, rejected) {
        final candidate = candidates.whereType<String>().firstOrNull;
        final violation = candidate == null
            ? null
            : editor.violationFor(candidate, phase.id);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: DiagonalRow(variant: DiagonalRowVariant.tile),
            ),
            if (candidate != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: ValueKey('plan-flow-order-lane-${phase.id}-hover'),
                    painter: _LaneOutlinePainter(
                      violation == null ? AppColors.accent : AppColors.danger,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: headerLeft,
              top: 11.8,
              width: 900,
              height: 26,
              child: Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: _LaneNameField(
                      key: ValueKey('plan-flow-order-lane-${phase.id}-name'),
                      name: phase.name,
                      onSubmitted: (name) => editor.renamePhase(phase.id, name),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (chip != null)
                    BaChip(
                      key: ValueKey('plan-flow-order-lane-${phase.id}-status'),
                      label: chip.label,
                      tone: chip.tone,
                    ),
                ],
              ),
            ),
            if (phase.stageIds.isEmpty)
              Positioned(
                // 빈 칸은 한 줄 높이라 첫 카드 자리는 타일 상자 왼쪽에서 (214 − 48)·tan10 − 2.3이다.
                left: (_laneBaseHeight - _cardTop) * _railSlope + _cardInset,
                top: _cardTop,
                width: planFlowOrderCardSize.width,
                height: planFlowOrderCardSize.height,
                child: const _DropHint(),
              ),
            for (final id in phase.stageIds)
              if (lane.cards[id] case final card?)
                if (flow.draft.stageById(id) case final stage?)
                  Positioned.fromRect(
                    key: ValueKey('plan-flow-order-card-$id'),
                    rect: card.shift(-origin),
                    child: _OrderCard(
                      flow: flow,
                      editor: editor,
                      stage: stage,
                      status: statuses[id],
                      selected: id == selectedStageId,
                    ),
                  ),
          ],
        );
      },
    );
  }
}

class _LaneOutlinePainter extends CustomPainter {
  const _LaneOutlinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.tile);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LaneOutlinePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 빈 칸 안내(시안 "여기로 끌어다 놓기").
class _DropHint extends StatelessWidget {
  const _DropHint();

  @override
  Widget build(BuildContext context) => const CustomPaint(
    painter: _DropHintPainter(),
    child: Center(
      child: Text(
        '여기로 끌어다 놓기',
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: AppType.bodySmallSize,
          fontWeight: AppType.medium,
          color: _dropText,
        ),
      ),
    ),
  );
}

class _DropHintPainter extends CustomPainter {
  const _DropHintPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.srow);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..color = _dropText.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DropHintPainter oldDelegate) => false;
}

/// 칸 머리 이름(인라인 편집, FD-071). 비우면 기본 이름으로 돌아간다.
class _LaneNameField extends StatefulWidget {
  const _LaneNameField({
    super.key,
    required this.name,
    required this.onSubmitted,
  });

  final String name;
  final ValueChanged<String> onSubmitted;

  @override
  State<_LaneNameField> createState() => _LaneNameFieldState();
}

class _LaneNameFieldState extends State<_LaneNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.name,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(_LaneNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.name != _controller.text && !_focus.hasFocus) {
      _controller.text = widget.name;
    }
  }

  void _focusChanged() {
    if (!_focus.hasFocus) {
      if (_controller.text != widget.name) widget.onSubmitted(_controller.text);
      if (_controller.text.trim().isEmpty) _controller.text = widget.name;
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_focusChanged);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    maxLines: 1,
    textInputAction: TextInputAction.done,
    onSubmitted: widget.onSubmitted,
    style: kitDisplayStyle(AppType.titleLargeSize),
    decoration: const InputDecoration.collapsed(
      hintText: '칸 이름',
      hintStyle: _mutedStyle,
    ),
  );
}

/// 단계 카드(시안 `.srow` 398.4×150: 초상 138×112 · 이름 16 · 단계 태그 · 목표 14 · 비용 12 · 상태 칩).
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.flow,
    required this.editor,
    required this.stage,
    required this.status,
    required this.selected,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;
  final PlanFlowStage stage;
  final PlanFlowStageStatus? status;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final stageId = stage.id;
    final name = flow.context.displayName(stage.studentId);
    final owned = editor.isOwned(stage.studentId);
    final chip = planFlowOrderStatusChip(
      status,
      owned: owned,
      calculating: flow.calculating,
    );
    final summary = planFlowOrderGoalSummary(
      editor.changesOf(stage),
      owned: owned,
    );
    final cost = planFlowOrderCostLine(
      flow.calculation?.stageCosts[stageId],
      owned: owned,
      calculating: flow.calculating,
    );
    Widget card({required bool dragging}) => Semantics(
      container: true,
      label: '$name ${stage.step}단계',
      value: '${chip.label}, $summary',
      child: DiagonalRow(
        variant: DiagonalRowVariant.srow,
        mark: selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
        onTap: dragging ? null : () => editor.select(stageId),
        padding: const EdgeInsets.symmetric(horizontal: 36.4),
        child: ExcludeSemantics(
          child: Row(
            children: [
              PortraitStrip(
                studentIds: [stage.studentId],
                maxVisible: 1,
                portraitSize: const Size(138, 112),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _bodyStyle.copyWith(
                              fontSize: AppType.titleSize,
                              fontWeight: AppType.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StageTag(stage: stage.step),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary,
                      key: ValueKey('plan-flow-order-card-$stageId-goals'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _bodyStyle.copyWith(
                        fontSize: AppType.titleSmallSize,
                        fontWeight: AppType.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cost,
                            key: ValueKey('plan-flow-order-card-$stageId-cost'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _mutedStyle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        BaChip(
                          key: ValueKey(
                            'plan-flow-order-card-$stageId-status',
                          ),
                          label: chip.label,
                          tone: chip.tone,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Draggable<String>(
      data: stageId,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(
        name: name,
        step: stage.step,
        studentId: stage.studentId,
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card(dragging: true)),
      child: card(dragging: false),
    );
  }
}

/// 끌고 있는 카드(포인터 가운데에 작은 행).
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({
    required this.name,
    required this.step,
    required this.studentId,
  });

  final String name;
  final int step;
  final String studentId;

  static const size = Size(280, 60);

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(-size.width / 2, -size.height / 2),
    child: Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: DiagonalRow(
          variant: DiagonalRowVariant.srow,
          mark: DiagonalRowMark.selected,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              PortraitStrip(
                studentIds: [studentId],
                maxVisible: 1,
                portraitSize: const Size(49, 40),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle.copyWith(fontWeight: AppType.bold),
                ),
              ),
              const SizedBox(width: 8),
              StageTag(stage: step),
            ],
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// C 보조

/// 자동 정렬 행 글자.
({String title, String subtitle}) planFlowOrderArrangeText(
  PlanFlowAutoArrange mode,
  List<String> studentNames,
) => switch (mode) {
  PlanFlowAutoArrange.fewestShortages => (
    title: '부족이 적은 단계부터',
    subtitle: '지금 가능한 단계를 앞 칸으로',
  ),
  PlanFlowAutoArrange.studentOrder => (
    title: '고른 학생 순서대로',
    subtitle: studentNames.isEmpty ? '학생마다 한 칸' : studentNames.join(' → '),
  ),
  PlanFlowAutoArrange.stageStep => (
    title: '학생마다 한 단계씩',
    subtitle: '모두 1단계 → 모두 2단계',
  ),
};

/// 3단계 C 보조(고른 카드 상세 · 자동 정렬). 캔버스 전체를 받는다.
class PlanFlowOrderAside extends StatelessWidget {
  const PlanFlowOrderAside({
    super.key,
    required this.flow,
    required this.editor,
  });

  final PlanFlowController flow;
  final PlanFlowOrderEditor editor;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([flow, editor]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) => _build(constraints.biggest),
    ),
  );

  Widget _build(Size size) {
    final sy = size.height / 1208;
    final right = planFlowProtoRect(size, 2538, 0, 0, 0).left;
    double y(double protoTop) => (protoTop - 184) * sy;
    Rect row(double top, double height, double inset) {
      final left = planFlowAsideLeftAt(size, top) + inset * size.width / 2560;
      return Rect.fromLTRB(left, top, math.max(left, right), top + height);
    }

    final children = <Widget>[];
    Widget caption(String text, {Key? key}) => Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        key: key,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: KV.labelStyle,
      ),
    );

    final stage = editor.selectedStage;
    var top = y(231.2);
    if (stage == null) {
      children.add(
        Positioned.fromRect(
          rect: row(top, 36, 18.3),
          child: const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '고른 단계가 없습니다',
              key: ValueKey('plan-flow-order-aside-title'),
              style: _bodyStyle,
            ),
          ),
        ),
      );
      top += 36 + 14 * sy;
    } else {
      final name = flow.context.displayName(stage.studentId);
      final owned = editor.isOwned(stage.studentId);
      final header = row(top, 36, 18.3);
      children.add(
        Positioned.fromRect(
          rect: header,
          child: Row(
            children: [
              PortraitStrip(
                studentIds: [stage.studentId],
                maxVisible: 1,
                portraitSize: const Size(42, 34),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '$name ${stage.step}단계',
                  key: const ValueKey('plan-flow-order-aside-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kitDisplayStyle(AppType.panelTitleSize),
                ),
              ),
              const SizedBox(width: 8),
              StageTag(stage: stage.step, selected: true),
            ],
          ),
        ),
      );
      top = header.bottom + 14 * sy;

      // 포함한 목표.
      final goalsCaption = row(top, 24, 16.2);
      children.add(
        Positioned.fromRect(rect: goalsCaption, child: caption('포함한 목표')),
      );
      top = goalsCaption.bottom + 6 * sy;
      final changes = editor.changesOf(stage);
      final goals = row(top, 50, 6);
      children.add(
        Positioned.fromRect(
          rect: goals,
          child: DiagonalRow(
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.only(left: 20.8, right: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  if (!owned) '모집',
                  for (final change in changes) change.detail,
                ].join(' · ').ifEmpty('앞 단계보다 올린 목표가 없습니다'),
                key: const ValueKey('plan-flow-order-aside-goals'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _bodyStyle,
              ),
            ),
          ),
        ),
      );
      top = goals.bottom + 12 * sy;

      // 먼저 끝나야 하는 단계(같은 학생 앞 단계, 자동). 직접 선행은 FE4-f.
      final predecessorCaption = row(top, 24, 16.2);
      children.add(
        Positioned.fromRect(
          rect: predecessorCaption,
          child: caption('먼저 끝나야 하는 단계'),
        ),
      );
      top = predecessorCaption.bottom + 6 * sy;
      final predecessor = editor.predecessorOf(stage);
      final predecessorRow = row(top, 50, 6);
      children.add(
        Positioned.fromRect(
          rect: predecessorRow,
          child: DiagonalRow(
            key: const ValueKey('plan-flow-order-aside-predecessor'),
            variant: DiagonalRowVariant.row,
            padding: const EdgeInsets.only(left: 20.8, right: 14),
            child: predecessor == null
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '이 학생의 첫 단계라 먼저 끝나야 하는 단계가 없습니다',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _mutedStyle,
                    ),
                  )
                : Row(
                    children: [
                      const Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${flow.context.displayName(predecessor.studentId)} '
                          '${predecessor.step}단계',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const BaChip(label: '자동', tone: AppTones.gray),
                    ],
                  ),
          ),
        ),
      );
      top = predecessorRow.bottom + 14 * sy;

      // 이 칸에서 부족한 재화.
      final phase = editor.phaseOf(stage.id);
      if (phase != null) {
        final shortageCaption = row(top, 24, 16.2);
        children.add(
          Positioned.fromRect(
            rect: shortageCaption,
            child: caption(
              '이 칸(${phase.name})에서 부족한 재화',
              key: const ValueKey('plan-flow-order-aside-lane-caption'),
            ),
          ),
        );
        top = shortageCaption.bottom + 6 * sy;
        final shortages = editor.laneShortages(phase);
        if (shortages == null || shortages.isEmpty) {
          final rect = row(top, 50, 6);
          children.add(
            Positioned.fromRect(
              rect: rect,
              child: DiagonalRow(
                key: const ValueKey('plan-flow-order-aside-lane-empty'),
                variant: DiagonalRowVariant.row,
                padding: const EdgeInsets.only(left: 20.8, right: 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    shortages != null
                        ? '이 칸에서 모자라는 재화가 없습니다'
                        : flow.calculating
                        ? '재화를 계산하고 있습니다'
                        : '재화를 계산할 수 없습니다',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _mutedStyle,
                  ),
                ),
              ),
            ),
          );
          top = rect.bottom + 6 * sy;
        } else {
          for (final shortage in shortages.take(3)) {
            final rect = row(top, 54, 6);
            children.add(
              Positioned.fromRect(
                rect: rect,
                child: DiagonalRow(
                  key: ValueKey(
                    'plan-flow-order-aside-shortage-${shortage.resourceKey}',
                  ),
                  variant: DiagonalRowVariant.row,
                  padding: const EdgeInsets.only(left: 21.5, right: 14),
                  child: Row(
                    children: [
                      ItemIconTile(
                        iconAsset: planningResourceIconAsset(
                          category: shortage.category,
                          itemId: shortage.itemId,
                        ),
                        size: const Size(49, 40),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          shortage.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _bodyStyle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '−${planFlowGoalAmount(shortage.shortage)}',
                        style: kitDisplayStyle(
                          AppType.titleLargeSize,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
            top = rect.bottom + 6 * sy;
          }
          if (shortages.length > 3) {
            final rest = row(top, 20, 20);
            children.add(
              Positioned.fromRect(
                rect: rest,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '외 ${shortages.length - 3}종',
                    style: _mutedStyle,
                  ),
                ),
              ),
            );
            top = rest.bottom + 4 * sy;
          }
        }
        top += 10 * sy;
      }
    }

    // 자동으로 정렬.
    final arrangeCaption = row(top, 24, 16.2);
    children.add(
      Positioned.fromRect(rect: arrangeCaption, child: caption('자동으로 정렬')),
    );
    top = arrangeCaption.bottom + 6 * sy;
    final names = [
      for (final studentId in flow.draft.studentIds)
        flow.context.displayName(studentId),
    ];
    for (final mode in PlanFlowAutoArrange.values) {
      final text = planFlowOrderArrangeText(mode, names);
      final rect = row(top, 52, 6);
      children.add(
        Positioned.fromRect(
          rect: rect,
          child: DiagonalRow(
            key: ValueKey('plan-flow-order-arrange-${mode.name}'),
            variant: DiagonalRowVariant.srow,
            onTap: flow.draft.hasStages ? () => editor.autoArrange(mode) : null,
            padding: const EdgeInsets.only(left: 21.2, right: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _bodyStyle.copyWith(fontWeight: AppType.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _mutedStyle.copyWith(
                          fontSize: AppType.captionSize,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.sort_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
      top = rect.bottom + 6 * sy;
    }

    return Stack(
      key: const ValueKey('plan-flow-order-aside'),
      children: children,
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
