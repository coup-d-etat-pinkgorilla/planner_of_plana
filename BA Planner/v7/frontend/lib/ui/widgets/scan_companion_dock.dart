// 아이템 진행 창(FE8-g3, 시안 Scan-Item-Run, FD-141 (a) · FD-142 (a) · FD-143 (a)).
//
// 아이템 스캔은 포그라운드다: 시작하면 플래너 창이 게임 창 옆 1:2 진행 창으로 줄고(`dockBeside`), 이 위젯이 그 창 전체를
// 덮는다. 끝나면 플래너가 원래 크기로 돌아온다(`restore`). 창이 작아지면 설계 크기 375×750을 같은 비율로 줄인다(시안 각주).
// 상태는 진행 · 일시정지 · 끝 세 가지(+ 종류 사이 시작 중 · 중지 요청 중)이고, 값은 컨트롤러가 FB-10 고정 범위만으로 만든
// [ScanCompanionState]다. 정확한 전체 분모 · % · 남은 시간 · 실시간 아이템 수량은 고정 형식 밖이라 '—' · 숨김이다
// (XB 2026-10-18 01:30 선언: inventory progress current = 인식한 entry 누계, total = null).
// Esc는 이 창에서도 중지다(시안 `Esc 중지`).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import '../kit/ba_chip.dart';
import '../kit/buttons.dart';
import '../kit/item_icon_tile.dart';
import '../kit/kit_pressable.dart';
import '../kit/skew_bar.dart';
import '../kit/titles.dart';
import '../studio/scan_studio_layout.dart';

/// 진행 창 단계. [starting]은 종류 사이(다음 세션 시작 응답 전)도 포함한다.
enum ScanCompanionPhase {
  starting,
  running,
  pauseRequested,
  paused,
  cancelling,
  ended,
}

/// 종류 한 줄(시안 그림 · 이름 · 칩).
@immutable
class ScanCompanionKind {
  const ScanCompanionKind({
    required this.id,
    required this.label,
    required this.chipLabel,
    required this.chipTone,
    this.iconAsset,
  });

  /// key에 쓰는 종류 wire 이름.
  final String id;
  final String label;
  final String chipLabel;
  final AppTone chipTone;
  final String? iconAsset;
}

/// `최근 기록` 한 줄(점 색 + 글자).
@immutable
class ScanCompanionLogLine {
  const ScanCompanionLogLine({required this.text, required this.tone});

  final String text;
  final AppTone tone;
}

/// 일시정지 · 끝 카드(NOW READING 자리).
@immutable
class ScanCompanionCard {
  const ScanCompanionCard({
    required this.title,
    required this.body,
    required this.tone,
  });

  final String title;
  final String body;
  final AppTone tone;
}

/// 진행 창이 그리는 값 한 벌. 글자 · 색은 컨트롤러 쪽 규칙(`scanCompanionStateFor`)이 정한다.
@immutable
class ScanCompanionState {
  const ScanCompanionState({
    required this.phase,
    required this.names,
    required this.chipLabel,
    required this.chipTone,
    required this.countText,
    required this.countCaption,
    required this.fraction,
    required this.barColor,
    required this.kinds,
    this.reading,
    this.card,
    this.log = const [],
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onOpenReview,
  });

  final ScanCompanionPhase phase;

  /// 고른 종류 이름(`기술 노트 · 전술 교육 BD`).
  final String names;
  final String chipLabel;
  final AppTone chipTone;

  /// 큰 수치(지금까지 인식한 칸 누계, 모르면 '—'). 시안의 `69%` 자리 — 전체 분모를 몰라 비율 대신 누계다.
  final String countText;

  /// 큰 수치 옆 글자(`칸 · 1번째 / 2종류`).
  final String countCaption;

  /// 막대 비율. 모르면 null(빗금).
  final double? fraction;
  final Color barColor;
  final List<ScanCompanionKind> kinds;

  /// NOW READING 카드의 지금 종류. [card]가 있으면 그 자리를 카드가 쓴다.
  final ScanCompanionKind? reading;
  final ScanCompanionCard? card;

  /// `최근 기록`(최근 먼저).
  final List<ScanCompanionLogLine> log;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;

  /// 끝 카드의 `결과 검토 열기`.
  final VoidCallback? onOpenReview;

  bool get paused => phase == ScanCompanionPhase.paused;
  bool get ended => phase == ScanCompanionPhase.ended;

  /// 첫 버튼 글자(시안 `일시정지` / `이어서`, 요청을 받은 뒤 `멈추는 중…`).
  String get pauseLabel => switch (phase) {
    ScanCompanionPhase.paused => '이어서',
    ScanCompanionPhase.pauseRequested => '멈추는 중…',
    _ => '일시정지',
  };

  String get cancelLabel =>
      phase == ScanCompanionPhase.cancelling ? '중지하는 중…' : '중지';
}

const _windowTop = Color(0xff152232);
const _windowBottom = Color(0xff101a26);
const _windowBorder = Color.fromRGBO(56, 81, 107, 0.9);
const _headerFill = Color(0xff0d151f);
const _headerLine = Color.fromRGBO(56, 81, 107, 0.8);
const _cardFill = Color(0xff1b2a3a);
const _tileFill = Color.fromRGBO(16, 24, 35, 0.72);
const _tileLine = Color.fromRGBO(56, 81, 107, 0.6);
const _barTrack = Color.fromRGBO(255, 255, 255, 0.06);
const _muted = AppColors.textMuted;

TextStyle _body(
  double size, {
  FontWeight weight = AppType.regular,
  Color color = AppColors.text,
}) => TextStyle(
  fontFamily: AppFonts.body,
  fontFamilyFallback: AppFonts.fallback,
  fontSize: size,
  height: 1.25,
  fontWeight: weight,
  color: color,
);

/// 진행 창. 부모(셸 전체 덮개 · 시험 상자)가 정한 크기 안에 설계 크기를 같은 비율로 맞춰 가운데 둔다.
class ScanCompanionDock extends StatelessWidget {
  const ScanCompanionDock({super.key, required this.state});

  final ScanCompanionState state;

  @override
  Widget build(BuildContext context) {
    final onCancel = state.onCancel;
    return Material(
      key: const ValueKey('scan-dock'),
      color: _windowBottom,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              onCancel?.call(),
        },
        child: Focus(
          autofocus: true,
          child: Center(
            // 시안 각주: 게임 창이 작아지면 진행 창도 같은 비율로 줄어든다(설계 크기 통째 비례).
            child: FittedBox(
              child: SizedBox(
                width: ScanDockMetrics.width,
                height: ScanDockMetrics.height,
                child: _DockCanvas(state: state),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockCanvas extends StatelessWidget {
  const _DockCanvas({required this.state});

  final ScanCompanionState state;

  @override
  Widget build(BuildContext context) {
    final layout = ScanDockLayout.of(state.kinds.length);
    const left = ScanDockMetrics.inset;
    const width = ScanDockMetrics.contentWidth;
    Widget at(double top, double height, Widget child, {Key? key}) =>
        Positioned(
          key: key,
          left: left,
          top: top,
          width: width,
          height: height,
          child: child,
        );
    final card = state.card;
    final reading = state.reading;
    final logRows = state.log.take(layout.logRows).toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_windowTop, _windowBottom],
        ),
        border: Border.all(color: _windowBorder),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned(
            left: 0,
            top: 0,
            width: ScanDockMetrics.width,
            height: ScanDockMetrics.headerHeight,
            child: _DockHeader(),
          ),
          at(
            ScanDockMetrics.namesTop,
            ScanDockMetrics.namesHeight,
            _NamesRow(state: state),
          ),
          at(
            ScanDockMetrics.numbersTop,
            ScanDockMetrics.numbersHeight,
            _CountRow(state: state),
          ),
          at(
            ScanDockMetrics.barTop,
            ScanDockMetrics.barHeight,
            SkewBar(
              key: const ValueKey('scan-dock-bar'),
              fraction: state.fraction,
              color: state.barColor,
              height: ScanDockMetrics.barHeight,
              style: const SkewBarStyle(trackColor: _barTrack),
            ),
          ),
          for (final (index, kind) in state.kinds.indexed)
            at(
              ScanDockMetrics.kindsTop + layout.kindPitch * index,
              layout.kindIconHeight,
              _KindRow(kind: kind, layout: layout),
              key: ValueKey('scan-dock-kind-${kind.id}'),
            ),
          at(
            layout.cardTop,
            ScanDockMetrics.cardHeight,
            card != null
                ? _MessageCard(card: card)
                : _ReadingCard(kind: reading),
          ),
          for (final (index, label) in const ['바뀐 수량', '확인 필요', '그대로'].indexed)
            Positioned(
              key: ValueKey('scan-dock-kpi-$index'),
              left: left + ScanDockMetrics.tilePitch * index,
              top: layout.tilesTop,
              width: ScanDockMetrics.tileWidth,
              height: ScanDockMetrics.tileHeight,
              child: _KpiTile(label: label),
            ),
          if (logRows.isNotEmpty) ...[
            at(
              layout.logHeaderTop,
              12,
              Text(
                '최근 기록',
                maxLines: 1,
                style: kitDisplayStyle(AppType.microDenseSize),
              ),
            ),
            for (final (index, line) in logRows.indexed)
              at(
                layout.logTop + ScanDockMetrics.logPitch * index,
                ScanDockMetrics.logRowHeight,
                _LogRow(line: line),
                key: ValueKey('scan-dock-log-$index'),
              ),
          ],
          if (!state.ended && !state.paused)
            at(
              ScanDockMetrics.warningTop,
              ScanDockMetrics.warningHeight,
              const _Warning(),
            ),
          at(
            ScanDockMetrics.buttonsTop,
            ScanDockMetrics.buttonHeight,
            _Buttons(state: state),
          ),
        ],
      ),
    );
  }
}

/// 머리 띠: 분홍 표지 · `Plan A · 아이템 스캔` · 항상 위 표시.
class _DockHeader extends StatelessWidget {
  const _DockHeader();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: _headerFill,
      border: Border(bottom: BorderSide(color: _headerLine)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ScanDockMetrics.headerPadding,
      ),
      child: Row(
        children: [
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.skewX(-0.17633),
            child: Container(
              width: ScanDockMetrics.headerMark,
              height: ScanDockMetrics.headerMark,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Plan A · 아이템 스캔',
              key: const ValueKey('scan-dock-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.bodySmallSize, weight: AppType.bold),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.flag_outlined,
            size: 13,
            color: AppColors.accent,
            semanticLabel: '항상 위',
          ),
        ],
      ),
    ),
  );
}

/// 종류 이름(`기술 노트 · 전술 교육 BD`) + 상태 칩.
class _NamesRow extends StatelessWidget {
  const _NamesRow({required this.state});

  final ScanCompanionState state;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          state.names,
          key: const ValueKey('scan-dock-names'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(
            AppType.captionSize,
            weight: AppType.bold,
            color: _muted,
          ),
        ),
      ),
      const SizedBox(width: 8),
      BaChip(
        key: const ValueKey('scan-dock-chip'),
        label: state.chipLabel,
        tone: state.chipTone,
      ),
    ],
  );
}

/// 큰 수치(누계) + `칸 · 1번째 / 2종류`.
class _CountRow extends StatelessWidget {
  const _CountRow({required this.state});

  final ScanCompanionState state;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        state.countText,
        key: const ValueKey('scan-dock-count'),
        maxLines: 1,
        style: kitDisplayStyle(
          ScanDockMetrics.numberSize,
        ).copyWith(height: 1, fontWeight: AppType.bold),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          state.countCaption,
          key: const ValueKey('scan-dock-count-caption'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(AppType.bodySmallSize, color: _muted),
        ),
      ),
    ],
  );
}

/// 종류 한 줄: 대표 그림 · 이름 · 칩(`완료 · 28칸` · `12칸` · `대기` …).
class _KindRow extends StatelessWidget {
  const _KindRow({required this.kind, required this.layout});

  final ScanCompanionKind kind;
  final ScanDockLayout layout;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ItemIconTile(
        iconAsset: kind.iconAsset,
        size: Size(layout.kindIconWidth, layout.kindIconHeight),
        label: kind.iconAsset == null ? _short(kind.label) : null,
        semanticLabel: kind.label,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          kind.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(12.5, weight: AppType.bold),
        ),
      ),
      const SizedBox(width: 8),
      BaChip(
        key: ValueKey('scan-dock-kind-chip-${kind.id}'),
        label: kind.chipLabel,
        tone: kind.chipTone,
      ),
    ],
  );
}

String _short(String label) =>
    label.length <= 4 ? label : label.substring(0, 4);

/// 사선 카드 · 타일 모양(시안 clip-path: 왼쪽 위 · 오른쪽 아래가 80° 사선, r3).
class _SkewPanelPainter extends CustomPainter {
  const _SkewPanelPainter({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final cut = diagonalCutDepth(size.height);
    final path = diagonalRoundedPolygon(
      [
        Offset(cut, 0),
        Offset(size.width, 0),
        Offset(size.width - cut, size.height),
        Offset(0, size.height),
      ],
      radius: 3,
      corner: DiagonalCornerStyle.quadratic,
    );
    canvas.drawPath(path, Paint()..color = fill);
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkewPanelPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border;
}

/// NOW READING: 지금 종류 이름 · 대표 그림. 아이템 이름 · 수량 비교는 고정 형식 밖이라 '—'.
class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.kind});

  final ScanCompanionKind? kind;

  @override
  Widget build(BuildContext context) {
    final kind = this.kind;
    return CustomPaint(
      key: const ValueKey('scan-dock-reading'),
      painter: _SkewPanelPainter(
        fill: _cardFill,
        border: AppColors.accent.withValues(alpha: 0.6),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ScanDockMetrics.cardPaddingLeft,
          ScanDockMetrics.cardPadding,
          ScanDockMetrics.cardPadding,
          ScanDockMetrics.cardPadding,
        ),
        child: Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOW READING',
                  maxLines: 1,
                  style: kitDisplayStyle(AppType.microDenseSize),
                ),
                const SizedBox(height: 6),
                ItemIconTile(
                  iconAsset: kind?.iconAsset,
                  size: const Size(
                    ScanDockMetrics.cardIconWidth,
                    ScanDockMetrics.cardIconHeight,
                  ),
                  label: kind == null || kind.iconAsset != null
                      ? null
                      : _short(kind.label),
                  semanticLabel: kind?.label,
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kind?.label ?? '—',
                    key: const ValueKey('scan-dock-reading-kind'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _body(AppType.bodySize, weight: AppType.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '—',
                    key: const ValueKey('scan-dock-reading-item'),
                    maxLines: 1,
                    style: _body(AppType.captionPlusSize, color: _muted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '—',
                    key: const ValueKey('scan-dock-reading-quantity'),
                    maxLines: 1,
                    style: kitDisplayStyle(
                      19.95,
                      color: _muted,
                    ).copyWith(height: 1, fontWeight: AppType.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 일시정지 · 끝 카드(시안 `마우스 입력이 감지되어 멈췄습니다` · `스캔을 마쳤습니다`).
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.card});

  final ScanCompanionCard card;

  @override
  Widget build(BuildContext context) => CustomPaint(
    key: const ValueKey('scan-dock-card'),
    painter: _SkewPanelPainter(
      fill: _cardFill,
      border: card.tone.base.withValues(alpha: 0.72),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        ScanDockMetrics.cardPaddingLeft,
        ScanDockMetrics.cardPadding,
        ScanDockMetrics.cardPadding,
        ScanDockMetrics.cardPadding,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            key: const ValueKey('scan-dock-card-title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _body(
              AppType.bodySize,
              weight: AppType.bold,
              color: card.tone.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.body,
            key: const ValueKey('scan-dock-card-body'),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: _body(AppType.captionPlusSize, color: _muted),
          ),
        ],
      ),
    ),
  );
}

/// KPI 타일. 바뀐 수량 · 확인 필요 · 그대로는 진행 중 후보가 있어야 셀 수 있어 '—'(FD-156, 고정 형식 밖).
class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _SkewPanelPainter(fill: _tileFill, border: _tileLine),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(11, 0, 9, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(AppType.microSize, color: _muted),
            ),
          ),
          Text(
            '—',
            maxLines: 1,
            style: kitDisplayStyle(
              19.95,
              color: _muted,
            ).copyWith(height: 1, fontWeight: AppType.bold),
          ),
        ],
      ),
    ),
  );
}

/// `최근 기록` 한 줄: 6px 점 · 11.5px 글자.
class _LogRow extends StatelessWidget {
  const _LogRow({required this.line});

  final ScanCompanionLogLine line;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: line.tone.foreground,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          line.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(AppType.captionPlusSize, color: _muted),
        ),
      ),
    ],
  );
}

/// 경고 줄(진행 중에만).
class _Warning extends StatelessWidget {
  const _Warning();

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('scan-dock-warning'),
    children: [
      Icon(
        Icons.warning_amber_rounded,
        size: 12,
        color: AppTones.warn.foreground,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          '마우스 · 키보드를 쓰면 일시정지합니다 · Esc 중지',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _body(AppType.captionSize, color: AppTones.warn.foreground),
        ),
      ),
    ],
  );
}

/// 버튼 줄: 진행 `일시정지` · `중지`, 일시정지 `이어서` · `중지`, 끝 `결과 검토 열기`.
class _Buttons extends StatelessWidget {
  const _Buttons({required this.state});

  final ScanCompanionState state;

  @override
  Widget build(BuildContext context) {
    if (state.ended) {
      return _DockButton(
        key: const ValueKey('scan-dock-open-review'),
        label: '결과 검토 열기',
        icon: Icons.arrow_forward_rounded,
        variant: TonalButtonVariant.primary,
        onPressed: state.onOpenReview,
      );
    }
    final paused = state.paused;
    return Row(
      children: [
        Expanded(
          child: _DockButton(
            key: ValueKey(paused ? 'scan-dock-resume' : 'scan-dock-pause'),
            label: state.pauseLabel,
            icon: paused ? Icons.play_arrow_rounded : Icons.schedule_rounded,
            variant: paused
                ? TonalButtonVariant.primary
                : TonalButtonVariant.normal,
            onPressed: paused ? state.onResume : state.onPause,
          ),
        ),
        const SizedBox(width: ScanDockMetrics.buttonGap),
        Expanded(
          child: _DockButton(
            key: const ValueKey('scan-dock-cancel'),
            label: state.cancelLabel,
            icon: Icons.stop_rounded,
            variant: TonalButtonVariant.danger,
            onPressed: state.onCancel,
          ),
        ),
      ],
    );
  }
}

/// 시안 `.tonal`(flex:1 · 가운데 정렬 · h44 · 13px). 키트 [TonalButton]은 글자를 왼쪽에 두므로 같은 색 · 누름 규칙으로
/// 폭을 채우고 가운데에 둔다.
class _DockButton extends StatelessWidget {
  const _DockButton({
    super.key,
    required this.label,
    required this.icon,
    required this.variant,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final TonalButtonVariant variant;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = TonalButtonColors.of(variant);
    final button = KitPressable(
      onPressed: onPressed,
      semanticLabel: label,
      builder: (context, pressable) => Container(
        height: ScanDockMetrics.buttonHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: pressable.hovered ? colors.hoverFill : colors.fill,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadii.control),
          ),
          boxShadow: pressable.focused
              ? const [BoxShadow(color: kitFocusColor, spreadRadius: 1.5)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(
                  AppType.bodySize,
                  weight: AppType.semiBold,
                  color: colors.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: kitDisabledOpacity, child: button)
        : button;
  }
}
