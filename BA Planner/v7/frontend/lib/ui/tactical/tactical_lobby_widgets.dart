// FE9-c: 전술대항전 기록 화면 S2 로비 스캔 부품(시안 Tactical S2 · `.fly.dl` 방어 이력 플라이아웃, G 보고서 §1.2).
//
// - 제목 줄(시안 `.plain` 36): "로비 스캔" dsp 19 · 상태 글자(`.cap` 12 w600, 기본은 "인식된 상대 3명 · 공개 슬롯 자동 기록") ·
//   "지금 스캔"(`.tonal.pri` 34, 스캔 아이콘). 막혔으면 흐림 + 이유 툴팁.
// - 카드(시안 `.row` 356.5×104, 안쪽 28.3): 이름 · 순위(b 14), 공개 칸 1번 | SP1 SP2(초상 44×36, 구분선 1×30 · 좌우 7, 간격 4),
//   족보 줄(`.mut` 11). 오른쪽은 "내 전적" + 칩(시안 "방어 승률 · 30일" 수치 · 막대는 FD-127로 뺐다). 올리거나 포커스하면 시안
//   `.po`(분홍 채움 .05 · 선 1.5)와 플라이아웃, 고르면 선택 행(`.srow.sel`).
// - 플라이아웃(시안 `.fly.dl`): 바탕 #0d151f · 링 rgba(113,199,244,.38) · 그림자 0 12 30 .6, 반경 10, 꼬리 11×11 45°. 머리(b 14 ·
//   범례 11), 줄(`.fr` 바탕 흰 .035 · r7 · 안쪽 6/8 · 간격 12, 현재 구간은 왼쪽 3px 분홍 + "현재" 칩, 기간 칸 84, 초상 36×29
//   간격 3 · 모르는 칸 "?" · 구분선 1×23, 오른쪽 전적 칩), 아래 줄("변경 주기 평균 n일" · "상대 카드 열기 →").
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../services/tactical_v2_service.dart';
import '../app_section.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/diagonal_row.dart';
import '../kit/kit_pressable.dart';
import '../studio/tactical_studio_layout.dart';
import 'tactical_deck_widgets.dart';
import 'tactical_lobby_view.dart';
import 'tactical_records_view.dart';

const _muted = AppColors.textMuted;
const _divider = Color.fromRGBO(158, 176, 194, 0.35);
const _flyoutDivider = Color.fromRGBO(158, 176, 194, 0.3);
const _flyoutRing = Color.fromRGBO(113, 199, 244, 0.38);

/// S2 값(화면이 만든다).
class TacticalLobbyPanel {
  const TacticalLobbyPanel({
    required this.caption,
    this.captionTone = TacticalLobbyTone.muted,
    required this.onScan,
    required this.scanHint,
    this.cards = const [],
    this.selectedId,
    this.onSelect,
    this.hoveredIndex,
    this.onHover,
    this.history,
    this.onOpenOpponent,
    this.message,
    this.connectPanel,
  });

  /// 로비 저장 서비스가 없을 때(화면 단독 · Mock): 빈 상태, "지금 스캔" 흐림.
  const TacticalLobbyPanel.unavailable()
    : caption = tacticalLobbyCaption,
      captionTone = TacticalLobbyTone.muted,
      onScan = null,
      scanHint = tacticalLobbyNoServiceText,
      cards = const [],
      selectedId = null,
      onSelect = null,
      hoveredIndex = null,
      onHover = null,
      history = null,
      onOpenOpponent = null,
      message = tacticalLobbyEmptyText,
      connectPanel = null;

  /// 제목 줄 글자(상태 문구가 있으면 그것).
  final String caption;
  final TacticalLobbyTone captionTone;

  /// "지금 스캔". null이면 흐림 + [scanHint] 툴팁.
  final VoidCallback? onScan;
  final String scanHint;
  final List<TacticalLobbyCard> cards;
  final String? selectedId;

  /// 카드를 누르면(null이면 누를 수 없다 — 읽기 · 쓰기 중).
  final ValueChanged<TacticalLobbyCard>? onSelect;

  /// 플라이아웃을 보일 카드(올림 · 포커스). [onHover]는 카드 · 플라이아웃에 들어가면 그 번호, 나가면 null.
  final int? hoveredIndex;
  final ValueChanged<int?>? onHover;

  /// [hoveredIndex] 카드의 방어 이력.
  final TacticalLobbyHistory? history;

  /// 플라이아웃 "상대 카드 열기 →"(분석 화면). null이면 글자를 보이지 않는다.
  final VoidCallback? onOpenOpponent;

  /// 카드가 없을 때 카드 자리 글자.
  final String? message;

  /// 미연결에서 "지금 스캔"을 누르면 S4 자리에 붙는 창 선택 패널(FD-155).
  final Widget? connectPanel;
}

Color tacticalLobbyToneColor(TacticalLobbyTone tone) => switch (tone) {
  TacticalLobbyTone.muted => _muted,
  TacticalLobbyTone.hint => const Color(0xffc3cfdb),
  TacticalLobbyTone.ok => const Color(0xff7fe3bd),
  TacticalLobbyTone.warn => const Color(0xffffd08a),
  TacticalLobbyTone.error => const Color(0xffffa0a8),
};

AppTone _recordTone(TacticalLobbyRecordTone tone) => switch (tone) {
  TacticalLobbyRecordTone.none => AppTones.gray,
  TacticalLobbyRecordTone.ok => AppTones.ok,
  TacticalLobbyRecordTone.danger => AppTones.danger,
  TacticalLobbyRecordTone.info => AppTones.info,
};

/// 제목 줄(시안 `.plain`, 안쪽 16.3, 간격 10).
class TacticalLobbyTitleRow extends StatelessWidget {
  const TacticalLobbyTitleRow({super.key, required this.panel});

  final TacticalLobbyPanel panel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '로비 스캔',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AppFonts.display,
              fontFamilyFallback: AppFonts.fallback,
              fontSize: 19,
              height: 1.2,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.19,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          flex: 3,
          child: Tooltip(
            message: panel.caption,
            child: Text(
              panel.caption,
              key: const ValueKey('tactical-lobby-caption'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: AppType.bodySmallSize,
                height: 1.2,
                fontWeight: AppType.semiBold,
                color: tacticalLobbyToneColor(panel.captionTone),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Tooltip(
          message: panel.scanHint,
          child: TonalButton(
            key: const ValueKey('tactical-lobby-scan'),
            label: tacticalLobbyScanLabel,
            icon: AppSection.scan.icon,
            variant: TonalButtonVariant.primary,
            height: 34,
            horizontalPadding: 12,
            fontSize: AppType.bodySmallSize,
            onPressed: panel.onScan,
          ),
        ),
      ],
    ),
  );
}

/// 카드 자리 글자(카드가 없을 때).
class TacticalLobbyMessage extends StatelessWidget {
  const TacticalLobbyMessage({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28.3),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        key: const ValueKey('tactical-lobby-message'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: AppFonts.body,
          fontFamilyFallback: AppFonts.fallback,
          fontSize: AppType.bodySmallSize,
          height: 1.35,
          color: _muted,
        ),
      ),
    ),
  );
}

/// 로비 상대 카드 하나(시안 `.row` + `.flyw.lc`).
class TacticalLobbyCardTile extends StatelessWidget {
  const TacticalLobbyCardTile({
    super.key,
    required this.card,
    required this.selected,
    required this.hovered,
    required this.onPressed,
    required this.onHover,
    required this.studentName,
  });

  final TacticalLobbyCard card;
  final bool selected;

  /// 플라이아웃이 열려 있다(카드 · 플라이아웃 위).
  final bool hovered;
  final VoidCallback? onPressed;
  final ValueChanged<bool>? onHover;
  final String Function(String id) studentName;

  @override
  Widget build(BuildContext context) {
    final hover = onHover;
    return MouseRegion(
      onEnter: hover == null ? null : (_) => hover(true),
      onExit: hover == null ? null : (_) => hover(false),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: hover,
        child: KitPressable(
          onPressed: onPressed,
          semanticLabel: card.semanticLabel,
          selected: selected,
          builder: (context, state) => CustomPaint(
            foregroundPainter: hovered || state.focused
                ? const _CardHoverPainter()
                : null,
            child: DiagonalRow(
              variant: selected
                  ? DiagonalRowVariant.srow
                  : DiagonalRowVariant.row,
              mark: selected ? DiagonalRowMark.selected : DiagonalRowMark.none,
              padding: const EdgeInsets.symmetric(
                horizontal: TacticalMetrics.lobbyCardPadding,
              ),
              child: _CardContent(card: card, studentName: studentName),
            ),
          ),
        ),
      ),
    );
  }
}

/// 시안 `.po`: 카드 모양 분홍 채움 .05 + 선 #f2b3ef 1.5.
class _CardHoverPainter extends CustomPainter {
  const _CardHoverPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.row);
    canvas
      ..drawPath(
        path,
        Paint()..color = AppColors.accent.withValues(alpha: 0.05),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.accent,
      );
  }

  @override
  bool shouldRepaint(_CardHoverPainter oldDelegate) => false;
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.card, required this.studentName});

  final TacticalLobbyCard card;
  final String Function(String id) studentName;

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(card.deck);
    final portrait = Size(
      TacticalMetrics.lobbyCardPortrait.width,
      TacticalMetrics.lobbyCardPortrait.height,
    );
    Widget slot(int index) => Tooltip(
      message: tacticalSlotName(slots[index], studentName),
      child: TacticalSlotPortrait(slot: slots[index], size: portrait),
    );
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                card.title,
                key: ValueKey('tactical-lobby-card-title-${card.displayIndex}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: AppType.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  slot(0),
                  Container(
                    width: 1,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    color: _divider,
                  ),
                  slot(4),
                  const SizedBox(width: 4),
                  slot(5),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                card.jokboText,
                key: ValueKey('tactical-lobby-card-jokbo-${card.displayIndex}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.body,
                  fontFamilyFallback: AppFonts.fallback,
                  fontSize: AppType.captionSize,
                  height: 1.2,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '내 전적',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: 10,
                height: 1.2,
                color: _muted,
              ),
            ),
            const SizedBox(width: 5),
            BaChip(
              key: ValueKey('tactical-lobby-card-record-${card.displayIndex}'),
              label: card.recordText,
              tone: _recordTone(card.recordTone),
            ),
          ],
        ),
      ],
    );
  }
}

/// 방어 이력 플라이아웃(시안 `.fly.dl`). [arrowLeft]는 꼬리 왼쪽(설계 px — 플라이아웃이 화면 안으로 밀리면 카드 쪽으로 옮긴다).
class TacticalLobbyFlyout extends StatelessWidget {
  const TacticalLobbyFlyout({
    super.key,
    required this.history,
    required this.arrowLeft,
    required this.studentName,
    this.onOpenOpponent,
  });

  final TacticalLobbyHistory history;
  final double arrowLeft;
  final String Function(String id) studentName;
  final VoidCallback? onOpenOpponent;

  @override
  Widget build(BuildContext context) {
    final open = onOpenOpponent;
    return Semantics(
      container: true,
      label: history.title,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.popover,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: _flyoutRing, spreadRadius: 1),
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.6),
                    offset: Offset(0, 12),
                    blurRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: arrowLeft,
            top: -6,
            child: Transform.rotate(
              angle: 0.785398,
              child: Container(
                width: 11,
                height: 11,
                decoration: const BoxDecoration(
                  color: AppColors.popover,
                  boxShadow: [
                    BoxShadow(color: _flyoutRing, offset: Offset(-1, -1)),
                  ],
                ),
              ),
            ),
          ),
          // 꼬리 아래 이음매를 바탕색으로 덮는다(시안 `:before`가 패널 위에 겹쳐 그려지는 모양).
          Positioned(
            left: arrowLeft - 2,
            top: 0,
            child: Container(width: 15, height: 6, color: AppColors.popover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TacticalMetrics.lobbyFlyoutPaddingX,
              TacticalMetrics.lobbyFlyoutPaddingTop,
              TacticalMetrics.lobbyFlyoutPaddingX,
              TacticalMetrics.lobbyFlyoutPaddingBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: TacticalMetrics.lobbyFlyoutHeaderHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          history.title,
                          key: const ValueKey('tactical-lobby-flyout-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontFamilyFallback: AppFonts.fallback,
                            fontSize: 14,
                            height: 1.2,
                            fontWeight: AppType.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        tacticalLobbyHistoryLegend,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontFamilyFallback: AppFonts.fallback,
                          fontSize: AppType.captionSize,
                          height: 1.2,
                          color: _muted,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final (index, row) in history.rows.indexed) ...[
                  const SizedBox(height: TacticalMetrics.lobbyFlyoutSpacing),
                  _HistoryRow(
                    key: ValueKey('tactical-lobby-flyout-row-$index'),
                    row: row,
                    studentName: studentName,
                  ),
                ],
                const SizedBox(height: TacticalMetrics.lobbyFlyoutSpacing),
                SizedBox(
                  height: TacticalMetrics.lobbyFlyoutFooterHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            history.cycleText,
                            key: const ValueKey('tactical-lobby-flyout-cycle'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontFamilyFallback: AppFonts.fallback,
                              fontSize: AppType.bodySmallSize,
                              height: 1.2,
                              color: _muted,
                            ),
                          ),
                        ),
                        if (open != null)
                          KitPressable(
                            key: const ValueKey('tactical-lobby-flyout-open'),
                            onPressed: open,
                            builder: (context, state) => Text(
                              '상대 카드 열기 →',
                              style: TextStyle(
                                fontFamily: AppFonts.body,
                                fontFamilyFallback: AppFonts.fallback,
                                fontSize: AppType.bodySmallSize,
                                height: 1.2,
                                fontWeight: AppType.bold,
                                color: AppColors.accentText,
                                decoration: state.hovered || state.focused
                                    ? TextDecoration.underline
                                    : null,
                                decorationColor: AppColors.accentText,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({super.key, required this.row, required this.studentName});

  final TacticalLobbyHistoryRow row;
  final String Function(String id) studentName;

  @override
  Widget build(BuildContext context) {
    final slots = tacticalDeckSlots(row.deck);
    final portrait = Size(
      TacticalMetrics.lobbyFlyoutPortrait.width,
      TacticalMetrics.lobbyFlyoutPortrait.height,
    );
    Widget slot(TacticalSlotObservation value) {
      final studentId = value.studentId;
      // 확인된 빈칸은 빈 상자, 모르는 칸(비공개)은 "?"(시안).
      if (studentId == null &&
          tacticalSlotFill(value) == TacticalSlotFill.unknown) {
        return SizedBox.fromSize(
          size: portrait,
          child: const Center(
            child: Text(
              '?',
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: AppType.bodySmallSize,
                height: 1.2,
                fontWeight: AppType.bold,
                color: _muted,
              ),
            ),
          ),
        );
      }
      if (studentId == null) {
        return TacticalSlotPortrait(slot: value, size: portrait);
      }
      return Tooltip(
        message: studentName(studentId),
        child: TacticalSlotPortrait(slot: value, size: portrait),
      );
    }

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontFamilyFallback: AppFonts.fallback,
                    fontSize: AppType.bodySmallSize,
                    height: 1.2,
                    fontWeight: AppType.bold,
                    color: AppColors.text,
                  ),
                ),
                if (row.current) ...[
                  const SizedBox(height: 3),
                  const BaChip(label: '현재', tone: AppTones.pink),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          for (var index = 0; index < 6; index++) ...[
            if (index > 0) const SizedBox(width: 3),
            if (index == 4) ...[
              Container(width: 1, height: 23, color: _flyoutDivider),
              const SizedBox(width: 3),
            ],
            slot(slots[index]),
          ],
          const Spacer(),
          BaChip(label: row.recordText, tone: _recordTone(row.recordTone)),
        ],
      ),
    );
    // 시안 `.fr` 바탕 흰 .035 · r7, 현재 구간은 안쪽 왼쪽 3px 분홍(inset box-shadow).
    return SizedBox(
      height: row.current
          ? TacticalMetrics.lobbyFlyoutCurrentRowHeight
          : TacticalMetrics.lobbyFlyoutRowHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.035),
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (row.current)
                const Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: ColoredBox(color: AppColors.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
