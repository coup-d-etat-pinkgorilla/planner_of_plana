// FE9-e: 족보 전체 보기 팝업(시안 Tactical-Analysis-All, G 보고서 §3).
//
// - "전체 보기 (n)" 버튼에 꼬리를 단 앵커 팝업 모달: 공용 [BaModal] 스크림 `anchored`(rgba(6,10,16,.35)) + [BaModalPanel.dialog]
//   (#0d151f r12, 안쪽 16 18 14) + 키트 꼬리([KitOverlayTail]). 자리는 키트 [layoutKitOverlay]의 아래 · 오른쪽 맞춤 규칙을 쓴다:
//   버튼 아래 12, 패널 오른쪽 = 버튼 오른쪽 + 16(시안 left 941 · 폭 940), 꼬리는 패널 오른쪽에서 120. 화면 밖으로 나가지 않게
//   가장자리 8 안으로 밀고, 아래 공간에 들어가는 줄만 놓는다(넘치면 "족보 n개 중 k개" 한 줄).
// - 머리: 분홍 막대 · "족보 전체 · n개" · "상대 방어 덱: …"(고른 족보의 방어 덱), 정렬 seg 4(성공률 · 채택률 · 독립 재현 · 최근 성공 —
//   채택률 · 독립 재현은 FD-127로 꺼짐 + 툴팁), 닫기.
// - 줄(`JokboRankRow`): 순위 · 이름(지금 보는 족보는 " · 보는 중" + 분홍 외곽) · 덱 40×32 · 관측 성공률 · 채택률 '—' · 독립 재현 '—' ·
//   최근 성공 · "표본 적음"(FD-134, 흐림 .62) · "공격 기록에 복사". 줄을 누르면 S2 족보가 바뀐다(팝업은 열린 채).
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../kit/ba_chip.dart';
import '../kit/ba_modal.dart';
import '../kit/buttons.dart';
import '../kit/kit_glyph.dart';
import '../kit/kit_overlay.dart';
import '../kit/kit_pressable.dart';
import '../kit/skew_controls.dart';
import '../studio/tactical_studio_layout.dart';
import 'tactical_analysis_view.dart';
import 'tactical_deck_widgets.dart';
import 'tactical_jokbo_view.dart';
import 'tactical_records_view.dart';

/// 각주(시안 문구 — 흐림 기준만 이 화면 규칙(관측 기록 5건 미만, FD-134)으로 바꿨다).
const tacticalJokboAllFootnote =
    '관측 기록 5건 미만은 흐리게 표시합니다 · 줄을 누르면 그 족보로 바뀝니다 · 결과(승패 · 시도 횟수)만으로 계산';

/// 꺼진 정렬 툴팁.
const tacticalJokboSortUnavailableText = '공유 자료가 없어 이 값으로 정렬할 수 없습니다.';

const _muted = AppColors.textMuted;

/// 줄 높이(안쪽 8 + 이름 13px 한 줄 · 간격 5 · 덱 32 + 안쪽 8)와 간격.
const _rowHeight = 70.0;
const _rowGap = 6.0;

/// 머리(28) + 줄 목록 위 12 + 각주 위 8 · 각주(14) + 패널 안쪽(16 + 14) + 여유 4.
const _chromeHeight = 28.0 + 12 + 8 + 14 + 30 + 4;

/// "족보 n개 중 k개" 줄(간격 6 + 글자 14 + 여유 4).
const _moreHeight = 24.0;

/// 팝업 자리: 버튼([anchor], 오버레이 좌표) 아래 · 오른쪽 맞춤(키트 규칙). [bounds]는 오버레이에서 여백을 뺀 영역.
({Rect panel, Offset tail, double maxHeight}) tacticalJokboAllPlacement({
  required Rect anchor,
  required Rect bounds,
}) {
  final width = TacticalAnalysisMetrics.allPanelWidth.clamp(0.0, bounds.width);
  final layout = layoutKitOverlay(
    placement: const KitOverlayPlacement.below(
      align: KitOverlayAlign.end,
      gap: TacticalAnalysisMetrics.allPanelGap,
      outset: TacticalAnalysisMetrics.allPanelOutset,
      tailInset: TacticalAnalysisMetrics.allPanelTailInset,
    ),
    trigger: anchor,
    bounds: bounds,
    panel: Size(width.toDouble(), 0),
  );
  return (
    panel: layout.panel,
    tail: layout.tail,
    maxHeight: (bounds.bottom - layout.panel.top).clamp(0.0, bounds.height),
  );
}

/// 팝업(오버레이 전체에 놓고 [anchor] 버튼에 붙인다).
class TacticalJokboAllPopup extends StatelessWidget {
  const TacticalJokboAllPopup({
    super.key,
    required this.anchor,
    required this.analyses,
    required this.selectedId,
    required this.sort,
    required this.deckText,
    required this.now,
    required this.onSort,
    required this.onSelect,
    required this.onCopy,
    required this.copyHint,
    required this.onClose,
  });

  /// "전체 보기" 버튼 자리(오버레이 좌표). null이면 오버레이 가운데 위.
  final Rect? anchor;
  final List<TacticalJokboAnalysis> analyses;
  final String? selectedId;
  final TacticalJokboSort sort;

  /// "상대 방어 덱: …" 뒤 글자.
  final String deckText;
  final DateTime now;
  final ValueChanged<TacticalJokboSort> onSort;
  final ValueChanged<String> onSelect;

  /// null이면 복사 버튼이 꺼진다(이유는 [copyHint]).
  final ValueChanged<TacticalJokboCard>? onCopy;
  final String copyHint;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final bounds = (Offset.zero & size).deflate(
        TacticalAnalysisMetrics.allPanelMargin,
      );
      final anchor =
          this.anchor ??
          Rect.fromCenter(
            center: Offset(size.width / 2 + 470 - 16, bounds.top + 40),
            width: 1,
            height: 1,
          );
      final placement = tacticalJokboAllPlacement(
        anchor: anchor,
        bounds: bounds,
      );
      final rows = tacticalJokboRanking(analyses, sort);
      final room = placement.maxHeight - _chromeHeight + _rowGap;
      final fit = (room / (_rowHeight + _rowGap)).floor().clamp(0, rows.length);
      final shown = fit >= rows.length
          ? rows.length
          : ((room - _moreHeight) / (_rowHeight + _rowGap)).floor().clamp(
              0,
              rows.length,
            );
      final panel = placement.panel;
      final tail = placement.tail;
      return Stack(
        children: [
          Positioned(
            left: panel.left,
            top: panel.top,
            width: panel.width,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: placement.maxHeight),
              child: BaModalPanel.dialog(
                key: const ValueKey('tactical-jokbo-all'),
                width: panel.width,
                child: _content(rows, shown),
              ),
            ),
          ),
          Positioned(
            key: const ValueKey('tactical-jokbo-all-tail'),
            left: tail.dx,
            top: tail.dy,
            width: kitOverlayTailSize,
            height: kitOverlayTailSize,
            child: const KitOverlayTail(side: KitOverlaySide.below),
          ),
        ],
      );
    },
  );

  Widget _content(List<TacticalJokboAnalysis> rows, int shown) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _header(),
      const SizedBox(height: 8 + 4),
      for (var index = 0; index < shown; index++) ...[
        if (index > 0) const SizedBox(height: _rowGap),
        _RankRow(
          rank: index + 1,
          analysis: rows[index],
          viewing: rows[index].card.id == selectedId,
          now: now,
          onSelect: () => onSelect(rows[index].card.id),
          onCopy: onCopy == null ? null : () => onCopy!(rows[index].card),
          copyHint: copyHint,
        ),
      ],
      if (shown < rows.length) ...[
        const SizedBox(height: _rowGap),
        Text(
          '족보 ${rows.length}개 중 $shown개를 보입니다.',
          key: const ValueKey('tactical-jokbo-all-more'),
          style: const TextStyle(fontSize: AppType.captionSize, color: _muted),
        ),
      ],
      const SizedBox(height: 8),
      const Text(
        tacticalJokboAllFootnote,
        key: ValueKey('tactical-jokbo-all-footnote'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: AppType.captionSize,
          height: 1.25,
          color: _muted,
        ),
      ),
    ],
  );

  Widget _header() => SizedBox(
    height: 28,
    child: Row(
      children: [
        Transform(
          transform: Matrix4.skewX(-0.176),
          alignment: Alignment.center,
          child: Container(
            width: 6,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '족보 전체 · ${analyses.length}개',
          key: const ValueKey('tactical-jokbo-all-title'),
          style: const TextStyle(
            fontFamily: AppFonts.display,
            fontFamilyFallback: AppFonts.fallback,
            fontSize: 17,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '상대 방어 덱: $deckText',
            key: const ValueKey('tactical-jokbo-all-deck'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: AppType.bodySmallSize,
              height: 1.25,
              color: _muted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        for (final item in TacticalJokboSort.values) _sortSegment(item),
        const SizedBox(width: 4),
        KitPressable(
          key: const ValueKey('tactical-jokbo-all-close'),
          onPressed: onClose,
          semanticLabel: '닫기',
          builder: (context, state) => Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: state.hovered || state.focused
                  ? const Color(0xff455866)
                  : const Color(0xff3a4b58),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: SizedBox.square(
                dimension: 14,
                child: CustomPaint(
                  painter: KitGlyphPainter(
                    glyph: KitGlyph.close,
                    color: Color(0xffd6e4f0),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sortSegment(TacticalJokboSort item) {
    final seg = SkewSegmented<TacticalJokboSort>(
      key: ValueKey('tactical-jokbo-sort-${item.name}'),
      height: 26,
      fontSize: AppType.captionSize,
      horizontalPadding: 12,
      segments: [SkewSegment(value: item, label: item.label)],
      selected: item == sort ? item : null,
      onChanged: item.available ? onSort : null,
    );
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: item.available
          ? seg
          : Tooltip(message: tacticalJokboSortUnavailableText, child: seg),
    );
  }
}

/// 순위 줄 하나.
class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.analysis,
    required this.viewing,
    required this.now,
    required this.onSelect,
    required this.onCopy,
    required this.copyHint,
  });

  final int rank;
  final TacticalJokboAnalysis analysis;
  final bool viewing;
  final DateTime now;
  final VoidCallback onSelect;
  final VoidCallback? onCopy;
  final String copyHint;

  @override
  Widget build(BuildContext context) {
    final card = analysis.card;
    Widget metric(double width, String label, Widget value) => Flexible(
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 10,
                height: 1.2,
                fontWeight: AppType.semiBold,
                color: _muted,
              ),
            ),
            const SizedBox(height: 2),
            value,
          ],
        ),
      ),
    );

    TextStyle bold(Color color) => TextStyle(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: 15,
      height: 1.2,
      fontWeight: AppType.bold,
      color: color,
    );

    final rate = card.observedWinRate;
    final row = KitPressable(
      key: ValueKey('tactical-jokbo-all-row-${card.id}'),
      onPressed: onSelect,
      semanticLabel: '${card.name} 보기',
      builder: (context, state) => Container(
        height: _rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: viewing
              ? const Color.fromRGBO(107, 62, 108, 0.28)
              : state.hovered || state.focused
              ? const Color.fromRGBO(255, 255, 255, 0.07)
              : const Color.fromRGBO(255, 255, 255, 0.035),
          borderRadius: BorderRadius.circular(8),
        ),
        // 시안 inset 0 0 0 1.5px — 안쪽 링이라 내용 자리를 줄이지 않는다.
        foregroundDecoration: viewing
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color.fromRGBO(242, 179, 239, 0.75),
                  width: 1.5,
                ),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: rank == 1 ? AppColors.accent : _muted,
                ),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 350,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewing ? '${card.name} · 보는 중' : card.name,
                    key: ValueKey('tactical-jokbo-all-row-${card.id}-name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: AppType.bold,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 5),
                  _deck(card),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  metric(
                    70,
                    '관측 성공률',
                    Text(
                      card.rateText,
                      key: ValueKey('tactical-jokbo-all-row-${card.id}-rate'),
                      style: bold(rate == null ? _muted : AppColors.success),
                    ),
                  ),
                  const SizedBox(width: 18),
                  metric(56, '채택률', Text('—', style: bold(_muted))),
                  const SizedBox(width: 18),
                  metric(62, '독립 재현', Text('—', style: bold(_muted))),
                  const SizedBox(width: 18),
                  metric(
                    64,
                    '최근 성공',
                    Text(
                      tacticalAgoText(analysis.lastSuccessAt, now),
                      key: ValueKey('tactical-jokbo-all-row-${card.id}-recent'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontFamilyFallback: AppFonts.fallback,
                        fontSize: 12,
                        height: 1.25,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (analysis.lowSample) ...[
              BaChip(
                key: ValueKey('tactical-jokbo-all-row-${card.id}-low'),
                label: '표본 적음',
                tone: AppTones.gray,
              ),
              const SizedBox(width: 14),
            ],
            Tooltip(
              message: copyHint,
              child: TonalButton(
                key: ValueKey('tactical-jokbo-all-row-${card.id}-copy'),
                label: '공격 기록에 복사',
                icon: Icons.copy_outlined,
                height: 30,
                horizontalPadding: 10,
                fontSize: AppType.captionSize,
                onPressed: onCopy,
              ),
            ),
          ],
        ),
      ),
    );
    return analysis.lowSample ? Opacity(opacity: 0.62, child: row) : row;
  }

  Widget _deck(TacticalJokboCard card) {
    final slots = tacticalDeckSlots(card.jokbo.attackDeck);
    final size = Size(
      TacticalAnalysisMetrics.allRowPortrait.width,
      TacticalAnalysisMetrics.allRowPortrait.height,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 6; index++) ...[
          if (index > 0) const SizedBox(width: 4),
          if (index == 4) ...[
            Container(
              width: 1,
              height: 26,
              color: const Color.fromRGBO(158, 176, 194, 0.3),
            ),
            const SizedBox(width: 4),
          ],
          TacticalSlotPortrait(slot: slots[index], size: size),
        ],
      ],
    );
  }
}
