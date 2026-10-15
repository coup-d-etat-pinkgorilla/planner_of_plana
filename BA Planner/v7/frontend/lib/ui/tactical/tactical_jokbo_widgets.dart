// FE9-d: S4 "이 시그니처의 족보" 부품(시안 Tactical S4 · 드래그 상태, G 보고서 §0 · §1.2).
//
// - 대상 방어 덱 줄(`.row` 64): "대상 방어 덱" + 상대 이름, 덱 6칸 40×32(빗금 = 빈칸), 빈칸 안내(시안 문구).
// - KPI 줄(`.row` 84, `.kv` 4칸): 방어 유저 · 연결 족보 · 최신 검증 · 숨은 편성 다양성(값 26px, 모르면 '—').
// - 족보 카드(`.row` 128, `JokboRow`): 끌기 손잡이 점 6개, 이름 14px + 마지막 관측 11px, 공격 덱 44×36, 관측 승/패 · 관측 성공률.
//   FD-127 (a): 시안의 채택률 · 독립 재현 · 첫 시도 · 평균 자리는 그리지 않는다. 기록이 0인 자동 족보는 흐리게 + "기록 없음".
//   카드는 끌 수 있고(`Draggable`), 누르면 고른다(S3 "족보에서 가져오기"가 고른 카드를 쓴다).
// - 끌기 고스트(448×104, −2.5° 회전, 분홍 테두리)와 놓기 힌트 알약("놓으면 … 덱으로 복사 · 위치 포함", 분홍 skew),
//   놓을 자리 강조(내 덱 줄을 6씩 넓힌 사선 행). 고스트는 화면 밖으로 나가지 않게 그릴 때 화면 안으로 민다.
// 키트 승격 후보(Lane A): [TacticalDeckStrip](덱 6칸 가로 줄), [TacticalDropPill], [TacticalDragGhostFrame].
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/theme.dart';
import '../../services/tactical_v2_service.dart';
import '../kit/ba_chip.dart';
import '../kit/diagonal_row.dart';
import '../kit/kit_pressable.dart';
import '../kit/section_frame.dart';
import '../studio/tactical_studio_layout.dart';
import 'tactical_deck_widgets.dart';
import 'tactical_jokbo_view.dart';
import 'tactical_records_view.dart';

/// 끌기 안내(시안 그대로).
const tacticalJokboDragHint = '족보를 끌어 내 공격 덱에 놓으면 6명과 위치가 그대로 복사됩니다';

/// 대상 덱 빈칸 안내(시안 그대로, 두 줄).
const tacticalJokboBlankHelp = '빈칸은 아무 학생이나 일치로\n보고 족보를 찾았습니다';

/// 놓기 힌트(시안 "놓으면 족보 D 덱으로 복사 · 위치 포함").
String tacticalDropHintText(String name) => '놓으면 $name 덱으로 복사 · 위치 포함';

const _muted = AppColors.textMuted;
const _diversityColor = Color(0xffffd08a);
const _dividerColor = Color.fromRGBO(158, 176, 194, 0.3);

const _capStyle = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.25,
  fontWeight: AppType.semiBold,
  color: _muted,
);

const _mutedSmall = TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: AppType.captionSize,
  height: 1.25,
  color: _muted,
);

/// 덱 6칸 가로 줄(초상 · 빗금 · 빈 상자, 4번과 SP1 사이 구분선). 이름 · 위치 라벨 없이 초상만.
class TacticalDeckStrip extends StatelessWidget {
  const TacticalDeckStrip({
    super.key,
    required this.deck,
    required this.portrait,
    this.gap = 4,
  });

  final TacticalDeckV2 deck;
  final Size portrait;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(deck);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 6; index++) ...[
          if (index > 0) SizedBox(width: gap),
          if (index == 4) ...[
            Container(
              width: 1,
              height: portrait.height - 6,
              color: _dividerColor,
            ),
            SizedBox(width: gap),
          ],
          TacticalSlotPortrait(slot: slots[index], size: portrait),
        ],
      ],
    );
  }
}

/// 대상 방어 덱 줄 내용(시안 `.row` 64, 안쪽 23.3).
class TacticalJokboTargetRow extends StatelessWidget {
  const TacticalJokboTargetRow({
    super.key,
    required this.caption,
    required this.name,
    required this.deck,
  });

  /// "대상 방어 덱"(방어 기록이면 "상대 공격 덱").
  final String caption;
  final String name;
  final TacticalDeckV2 deck;

  @override
  Widget build(BuildContext context) => DiagonalRow(
    variant: DiagonalRowVariant.row,
    padding: const EdgeInsets.only(left: 23.3, right: 14),
    child: Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$caption\n$name',
            key: const ValueKey('tactical-jokbo-target-name'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _capStyle,
          ),
        ),
        const SizedBox(width: 10),
        TacticalDeckStrip(
          deck: deck,
          portrait: Size(
            TacticalMetrics.jokboSmallPortrait.width,
            TacticalMetrics.jokboSmallPortrait.height,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tacticalBlankSlotText(deck),
                key: const ValueKey('tactical-jokbo-target-blank'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 13,
                  height: 1.25,
                  fontWeight: AppType.bold,
                  color: AppColors.text,
                ),
              ),
              const Text(
                tacticalJokboBlankHelp,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: _mutedSmall,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// KPI 줄 내용(시안 `.row` 84, `.kv` 4칸, 안쪽 26.8).
class TacticalJokboKpiRow extends StatelessWidget {
  const TacticalJokboKpiRow({super.key, required this.kpis});

  final TacticalJokboKpis kpis;

  @override
  Widget build(BuildContext context) {
    Widget tile(
      String key,
      String label,
      String value,
      Color color, {
      String? detail,
    }) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: _capStyle,
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  key: ValueKey('tactical-jokbo-kpi-$key'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.display,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: AppType.displaySmallSize,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                    color: value == '—' ? _muted : color,
                  ),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(width: 6),
                Text(
                  detail,
                  key: ValueKey('tactical-jokbo-kpi-$key-detail'),
                  maxLines: 1,
                  style: _mutedSmall,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return DiagonalRow(
      variant: DiagonalRowVariant.row,
      padding: const EdgeInsets.only(left: 26.8, right: 14),
      child: Row(
        children: [
          tile('defenders', '방어 유저', kpis.defenders, AppColors.text),
          tile('linked', '연결 족보', kpis.linked, AppColors.text),
          tile('verified', '최신 검증', kpis.verified, AppColors.success),
          tile(
            'diversity',
            '숨은 편성 다양성',
            kpis.diversity,
            _diversityColor,
            detail: kpis.diversityDetail,
          ),
        ],
      ),
    );
  }
}

/// 끌기 안내 줄(시안 `.plain` 22, 안쪽 15.9). [error]가 있으면 그 문구(빨강)와 "다시 읽기".
class TacticalJokboHintRow extends StatelessWidget {
  const TacticalJokboHintRow({super.key, this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final onRetry = this.onRetry;
    return Padding(
      padding: const EdgeInsets.only(left: 15.9, right: 14),
      child: Row(
        children: [
          if (error == null) ...[
            const TacticalDragGlyph(color: _muted),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              error ?? tacticalJokboDragHint,
              key: const ValueKey('tactical-jokbo-hint'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: error == null
                  ? _mutedSmall
                  : _mutedSmall.copyWith(color: AppColors.danger),
            ),
          ),
          if (error != null && onRetry != null) ...[
            const SizedBox(width: 8),
            KitPressable(
              key: const ValueKey('tactical-jokbo-retry'),
              onPressed: onRetry,
              semanticLabel: '다시 읽기',
              builder: (context, state) => Text(
                '다시 읽기',
                style: _mutedSmall.copyWith(
                  fontWeight: AppType.bold,
                  color: state.hovered || state.focused
                      ? AppColors.accent
                      : AppColors.accentText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 끌기 아이콘(시안 안내 · 힌트 알약의 작은 카드 + 화살표).
class TacticalDragGlyph extends StatelessWidget {
  const TacticalDragGlyph({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 16,
    height: 10,
    child: CustomPaint(painter: _DragGlyphPainter(color)),
  );
}

class _DragGlyphPainter extends CustomPainter {
  const _DragGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0.7, 1, size.width * 0.45, size.height - 2),
        const Radius.circular(1.5),
      ),
      paint,
    );
    final y = size.height / 2;
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.6, y)
        ..lineTo(size.width - 1, y)
        ..moveTo(size.width - 4, y - 3)
        ..lineTo(size.width - 1, y)
        ..lineTo(size.width - 4, y + 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DragGlyphPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// 족보 카드 내용(손잡이 · 이름 · 마지막 관측 · 공격 덱 · 관측 값).
class TacticalJokboCardContent extends StatelessWidget {
  const TacticalJokboCardContent({super.key, required this.card});

  final TacticalJokboCard card;

  @override
  Widget build(BuildContext context) {
    final imported = card.importedText;
    const bold = TextStyle(fontWeight: AppType.bold, color: AppColors.text);
    return Opacity(
      opacity: card.noRecords ? 0.5 : 1,
      child: Row(
        children: [
          const _GripDots(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        card.name,
                        key: ValueKey('tactical-jokbo-card-${card.id}-name'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontFamilyFallback: AppFonts.fallback,
                          fontSize: 14,
                          height: 1.25,
                          fontWeight: AppType.bold,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '마지막 관측 ${card.lastObserved}',
                      key: ValueKey('tactical-jokbo-card-${card.id}-seen'),
                      maxLines: 1,
                      style: _mutedSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TacticalDeckStrip(
                  deck: card.jokbo.attackDeck,
                  portrait: Size(
                    TacticalMetrics.jokboCardPortrait.width,
                    TacticalMetrics.jokboCardPortrait.height,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: '관측 '),
                            TextSpan(text: card.recordText, style: bold),
                            const TextSpan(text: '    관측 성공률 '),
                            TextSpan(
                              text: card.rateText,
                              style: bold.copyWith(
                                color: card.observedWinRate == null
                                    ? _muted
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        key: ValueKey('tactical-jokbo-card-${card.id}-record'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _mutedSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (imported != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        imported,
                        key: ValueKey(
                          'tactical-jokbo-card-${card.id}-imported',
                        ),
                        maxLines: 1,
                        style: _mutedSmall.copyWith(fontSize: 10),
                      ),
                    ],
                    if (card.noRecords) ...[
                      const SizedBox(width: 8),
                      BaChip(
                        key: ValueKey('tactical-jokbo-card-${card.id}-empty'),
                        label: '기록 없음',
                        tone: AppTones.gray,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 끌기 손잡이(시안 4×4 점 6개, #c3cfdb).
class _GripDots extends StatelessWidget {
  const _GripDots();

  @override
  Widget build(BuildContext context) {
    Widget dot() => Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: AppColors.textSecondary,
        shape: BoxShape.circle,
      ),
    );
    Widget column() => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(),
        const SizedBox(height: 3),
        dot(),
        const SizedBox(height: 3),
        dot(),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [column(), const SizedBox(width: 3), column()],
    );
  }
}

/// 족보 카드: 누르면 고르고, 끌어 내 덱 줄에 놓으면 복사한다. [scale]은 섹션 축소 비율(고스트 크기)이다.
class TacticalJokboCardTile extends StatelessWidget {
  const TacticalJokboCardTile({
    super.key,
    required this.card,
    required this.selected,
    required this.onSelect,
    required this.scale,
  });

  final TacticalJokboCard card;
  final bool selected;
  final VoidCallback? onSelect;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final tile = KitPressable(
      onPressed: onSelect,
      semanticLabel: card.semanticLabel,
      selected: selected,
      builder: (context, state) => DiagonalRow(
        variant: DiagonalRowVariant.srow,
        mark: selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
        hovered: state.hovered || state.focused,
        padding: const EdgeInsets.only(
          left: TacticalMetrics.jokboCardPadding,
          right: 14,
        ),
        child: TacticalJokboCardContent(card: card),
      ),
    );
    return Draggable<TacticalJokboCard>(
      data: card,
      dragAnchorStrategy: (draggable, context, position) => Offset(
        TacticalMetrics.jokboGhostAnchor.dx * scale,
        TacticalMetrics.jokboGhostAnchor.dy * scale,
      ),
      feedback: TacticalJokboGhost(card: card, scale: scale),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: tile),
    );
  }
}

/// 끌기 고스트(시안 448×104, −2.5°, 채움 rgba(36,52,72,.94), 분홍 테두리). 화면 밖으로 나가지 않는다.
class TacticalJokboGhost extends StatelessWidget {
  const TacticalJokboGhost({
    super.key,
    required this.card,
    required this.scale,
  });

  final TacticalJokboCard card;
  final double scale;

  @override
  Widget build(BuildContext context) => TacticalDragGhostFrame(
    viewSize: MediaQuery.sizeOf(context),
    child: SizedBox(
      key: const ValueKey('tactical-jokbo-ghost'),
      width: TacticalMetrics.jokboGhostWidth * scale,
      height: TacticalMetrics.jokboGhostHeight * scale,
      child: SectionScaledBox(
        scale: scale,
        child: Transform.rotate(
          angle: TacticalMetrics.jokboGhostTurns * 2 * math.pi,
          child: CustomPaint(
            painter: const _GhostPainter(),
            child: Padding(
              padding: const EdgeInsets.only(left: 30, top: 12, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 14,
                      height: 1.25,
                      fontWeight: AppType.bold,
                      color: AppColors.text,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TacticalDeckStrip(
                    deck: card.jokbo.attackDeck,
                    portrait: Size(
                      TacticalMetrics.jokboSmallPortrait.width,
                      TacticalMetrics.jokboSmallPortrait.height,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _GhostPainter extends CustomPainter {
  const _GhostPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.row);
    canvas.drawShadow(path, const Color(0xff050911), 10, false);
    canvas.drawPath(
      path,
      Paint()..color = const Color.fromRGBO(36, 52, 72, 0.94),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_GhostPainter oldDelegate) => false;
}

/// 끌기 고스트 틀: 그릴 때 화면([viewSize]) 안으로 민다(회전 여유 [margin]).
class TacticalDragGhostFrame extends SingleChildRenderObjectWidget {
  const TacticalDragGhostFrame({
    super.key,
    required this.viewSize,
    this.margin = 8,
    super.child,
  });

  final Size viewSize;
  final double margin;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGhostFrame(viewSize, margin);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderGhostFrame)
      ..viewSize = viewSize
      ..margin = margin;
  }
}

class _RenderGhostFrame extends RenderProxyBox {
  _RenderGhostFrame(this._viewSize, this._margin);

  Size _viewSize;
  double _margin;

  set viewSize(Size value) {
    if (value == _viewSize) return;
    _viewSize = value;
    markNeedsPaint();
  }

  set margin(double value) {
    if (value == _margin) return;
    _margin = value;
    markNeedsPaint();
  }

  /// 화면 안으로 밀 양(전역 좌표). 화면보다 크면 왼쪽 · 위를 맞춘다.
  Offset shiftFor(Offset global) {
    double clamp(double value, double extent, double view) {
      final low = _margin;
      final high = math.max(low, view - extent - _margin);
      return value.clamp(low, high).toDouble();
    }

    final x = clamp(global.dx, size.width, _viewSize.width);
    final y = clamp(global.dy, size.height, _viewSize.height);
    return Offset(x - global.dx, y - global.dy);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    context.paintChild(child, offset + shiftFor(localToGlobal(Offset.zero)));
  }
}

/// 놓기 힌트 알약(시안 높이 26, skewX −10°, 분홍 #f2b3ef · 글자 #2a1330 12px w800). [accepted]가 false면 놓을 수 없는 이유(회색).
class TacticalDropPill extends StatelessWidget {
  const TacticalDropPill({
    super.key,
    required this.text,
    required this.accepted,
  });

  final String text;
  final bool accepted;

  @override
  Widget build(BuildContext context) {
    final background = accepted ? AppColors.accent : _muted;
    final foreground = accepted ? AppColors.onAccent : AppColors.rowSurface;
    return Transform(
      transform: Matrix4.skewX(-10 * math.pi / 180),
      alignment: Alignment.center,
      child: Container(
        height: TacticalMetrics.dropPillHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Transform(
          transform: Matrix4.skewX(10 * math.pi / 180),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TacticalDragGlyph(color: foreground),
              const SizedBox(width: 6),
              Text(
                text,
                key: const ValueKey('tactical-drop-hint'),
                maxLines: 1,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.bodySmallSize,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: foreground,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 놓을 자리 강조(내 덱 줄 사선 행을 넓힌 모양, 분홍 테두리 · 옅은 채움). 놓을 수 없으면 회색.
class TacticalDropHighlightPainter extends CustomPainter {
  const TacticalDropHighlightPainter({required this.accepted});

  final bool accepted;

  @override
  void paint(Canvas canvas, Size size) {
    final color = accepted ? AppColors.accent : _muted;
    final path = diagonalRowPath(size, DiagonalRowVariant.row);
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.08));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(TacticalDropHighlightPainter oldDelegate) =>
      oldDelegate.accepted != accepted;
}

/// 섹션 안 안내 문구(빈 상태 · 읽는 중).
class TacticalJokboMessage extends StatelessWidget {
  const TacticalJokboMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 23.3, right: 14),
    child: Align(
      alignment: Alignment.topLeft,
      child: Text(
        text,
        key: const ValueKey('tactical-jokbo-message'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: AppType.bodySmallSize,
          height: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    ),
  );
}
