// 앵커 플라이아웃 (FE2-c, H §6.5, FD-021 (a)).
//
// 트리거(요약 줄·사선 행·점)를 누르거나 마우스를 올리거나 키보드로 포커스하면 옆/아래로 패널을 연다.
// - 기본 `.flyw/.flyt/.fly`: 트리거 r8 안쪽 1.5px 링 rgba(242,179,239,.7). 패널 #0d151f r10, 안쪽 14 16 12,
//   세로 간격 8, 링 1px + 0 12px 30px rgba(0,0,0,.6). 꼬리 11×11.
//   방향: r(오른쪽 14, 위 −12, 폭 420, 꼬리 위 26) · dn(아래 12, 오른쪽 −10, 폭 380, 꼬리 right 26)
//   · dl(아래 12, 왼쪽 0, 폭 540, 꼬리 left 36) · l(왼쪽 12, 위 −12, 폭 420, 워커 재량).
// - 사선 path 트리거 `.flyw.lc`: 링 대신 사선 외곽(#f2b3ef 1.5 + 채움 @.05).
// - 프리셋: 페이즈 `.phw/.php`(아래 10, 오른쪽 −40 안쪽, 폭 470, 꼬리 right 40, 외곽 @.75 2px)
//   · 시나리오 `.shw/.shp`(아래 12, 왼쪽 −20, 폭 500, 세로 간격 7, 꼬리 left 90, 외곽 @.8 2px)
//   · 통계 점 `.sdot/.spop`(26px 원, 바깥 2px 링 @.85, 패널 왼쪽 12 · 위 −18, 안쪽 12 14, 꼬리 없음).
// - 행 `.fr`·`.pr`: 간격 10, 안쪽 6 8, r7, rgba(255,255,255,.035). 시나리오 `.sr_`는 안쪽 5 8.
// 패널 안에 버튼이 있으므로 눌러 열면 포커스를 패널로 옮기고, 닫으면 트리거로 돌려준다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import 'kit_overlay.dart';

/// 플라이아웃 방향(시안 `.fly` 기본·`.l`·`.dn`·`.dl`).
enum FlyoutDirection { right, left, down, downLeft }

/// 트리거 외곽 모양.
enum FlyoutTriggerShape { rounded, parallelogram, circle }

/// 트리거 강조(hover·focus·열림) 모양.
@immutable
class FlyoutTriggerRing {
  /// `.flyt`: r8 안쪽 1.5px rgba(242,179,239,.7).
  const FlyoutTriggerRing.rounded({this.radius = 8})
    : shape = FlyoutTriggerShape.rounded,
      color = _roundedColor,
      width = 1.5,
      fill = null;

  /// 사선(80° 평행사변형, 모서리 [radius]) 외곽.
  const FlyoutTriggerRing.parallelogram({
    required this.color,
    required this.width,
    this.fill,
    this.radius = 8,
  }) : shape = FlyoutTriggerShape.parallelogram;

  /// `.sdot`: 원 바깥 2px rgba(242,179,239,.85).
  const FlyoutTriggerRing.circle()
    : shape = FlyoutTriggerShape.circle,
      color = _circleColor,
      width = 2,
      fill = null,
      radius = 0;

  static const _roundedColor = Color.fromRGBO(242, 179, 239, 0.7);
  static const _circleColor = Color.fromRGBO(242, 179, 239, 0.85);

  /// `.flyw.lc .po`: #f2b3ef 1.5 + 채움 rgba(242,179,239,.05).
  static const lineCard = FlyoutTriggerRing.parallelogram(
    color: AppColors.accent,
    width: 1.5,
    fill: Color.fromRGBO(242, 179, 239, 0.05),
  );

  /// `.phw .pho`: rgba(242,179,239,.75) 2px.
  static const phase = FlyoutTriggerRing.parallelogram(
    color: Color.fromRGBO(242, 179, 239, 0.75),
    width: 2,
  );

  /// `.shw .sho`: rgba(242,179,239,.8) 2px.
  static const scenario = FlyoutTriggerRing.parallelogram(
    color: Color.fromRGBO(242, 179, 239, 0.8),
    width: 2,
  );

  final FlyoutTriggerShape shape;
  final Color color;
  final double width;
  final Color? fill;
  final double radius;

  @override
  bool operator ==(Object other) =>
      other is FlyoutTriggerRing &&
      other.shape == shape &&
      other.color == color &&
      other.width == width &&
      other.fill == fill &&
      other.radius == radius;

  @override
  int get hashCode => Object.hash(shape, color, width, fill, radius);
}

/// 80° 평행사변형(왼쪽 아래·오른쪽 위로 기운 변, 모서리 r[radius]).
Path flyoutParallelogramPath(Size size, {double radius = 8}) {
  final cut = diagonalCutDepth(size.height);
  return diagonalRoundedPolygon(
    [
      Offset(cut, 0),
      Offset(size.width, 0),
      Offset(size.width - cut, size.height),
      Offset(0, size.height),
    ],
    radius: radius,
    corner: DiagonalCornerStyle.quadratic,
  );
}

/// 플라이아웃 프리셋: 위치·폭·패널 안쪽·트리거 링.
@immutable
class FlyoutPreset {
  const FlyoutPreset({
    required this.placement,
    this.width,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 12),
    this.gap = 8,
    this.tail = true,
    this.ring = const FlyoutTriggerRing.rounded(),
  });

  final KitOverlayPlacement placement;

  /// 없으면 내용 폭(`.spop`).
  final double? width;
  final EdgeInsets padding;

  /// 패널 안 세로 간격.
  final double gap;
  final bool tail;
  final FlyoutTriggerRing ring;

  /// `.fly`: 오른쪽으로 열림.
  static const right = FlyoutPreset(
    placement: KitOverlayPlacement.right(gap: 14, crossOffset: -12),
    width: 420,
  );

  /// 왼쪽으로 열림(시안에 `.fly.l`이 없어 `.fly`를 좌우로 뒤집었다).
  static const left = FlyoutPreset(
    placement: KitOverlayPlacement.left(gap: 14, crossOffset: -12),
    width: 420,
  );

  /// `.fly.dn`: 아래로, 오른쪽 맞춤.
  static const down = FlyoutPreset(
    placement: KitOverlayPlacement.below(
      align: KitOverlayAlign.end,
      gap: 12,
      outset: 10,
      tailInset: 26,
    ),
    width: 380,
  );

  /// `.fly.dl`: 아래로, 왼쪽 맞춤.
  static const downLeft = FlyoutPreset(
    placement: KitOverlayPlacement.below(gap: 12, outset: 0, tailInset: 36),
    width: 540,
  );

  /// `.phw/.php`: 페이즈 사선 행 아래, 폭 470.
  static const phase = FlyoutPreset(
    placement: KitOverlayPlacement.below(
      align: KitOverlayAlign.end,
      gap: 10,
      outset: -40,
      tailInset: 40,
    ),
    width: 470,
    ring: FlyoutTriggerRing.phase,
  );

  /// `.shw/.shp`: 시나리오 카드 아래, 폭 500, 꼬리 left 90.
  static const scenario = FlyoutPreset(
    placement: KitOverlayPlacement.below(gap: 12, outset: 20, tailInset: 90),
    width: 500,
    gap: 7,
    ring: FlyoutTriggerRing.scenario,
  );

  /// `.sdot/.spop`: 통계 점 왼쪽, 내용 폭, 꼬리 없음.
  static const statsDot = FlyoutPreset(
    placement: KitOverlayPlacement.left(gap: 12, crossOffset: -18),
    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    tail: false,
    ring: FlyoutTriggerRing.circle(),
  );

  /// 방향별 기본 프리셋.
  static FlyoutPreset of(FlyoutDirection direction) => switch (direction) {
    FlyoutDirection.right => right,
    FlyoutDirection.left => left,
    FlyoutDirection.down => down,
    FlyoutDirection.downLeft => downLeft,
  };

  /// 같은 위치에 트리거 링만 바꾼다(예: [FlyoutTriggerRing.lineCard]).
  FlyoutPreset withRing(FlyoutTriggerRing ring) => FlyoutPreset(
    placement: placement,
    width: width,
    padding: padding,
    gap: gap,
    tail: tail,
    ring: ring,
  );
}

/// 트리거 + 플라이아웃 패널.
///
/// [child]는 트리거 내용이다(요약 줄·사선 행 등, 크기는 [child]가 정한다). [children]은 패널 안 내용이며
/// [FlyoutPreset.gap] 간격으로 쌓는다.
class AnchoredFlyout extends StatelessWidget {
  const AnchoredFlyout({
    super.key,
    required this.semanticLabel,
    required this.child,
    required this.children,
    this.preset = FlyoutPreset.right,
    this.panelLabel,
    this.group,
    this.initiallyOpen = false,
    this.onOpenChanged,
  });

  /// 트리거 접근성 이름(시안 `aria-label`, 예: "부족 재화 자세히 보기").
  final String semanticLabel;
  final Widget child;
  final List<Widget> children;
  final FlyoutPreset preset;

  /// 패널 접근성 이름(시안 패널 `aria-label`).
  final String? panelLabel;
  final KitOverlayGroup? group;
  final bool initiallyOpen;
  final ValueChanged<bool>? onOpenChanged;

  @override
  Widget build(BuildContext context) => KitOverlayAnchor(
    placement: preset.placement,
    semanticLabel: semanticLabel,
    panelLabel: panelLabel,
    tail: preset.tail,
    group: group,
    initiallyOpen: initiallyOpen,
    onOpenChanged: onOpenChanged,
    moveFocusIntoPanel: true,
    triggerBuilder: (context, state) => CustomPaint(
      foregroundPainter: FlyoutTriggerRingPainter(
        ring: preset.ring,
        active: state.active,
      ),
      child: preset.ring.shape == FlyoutTriggerShape.parallelogram
          ? ClipPath(
              clipper: _ParallelogramClipper(radius: preset.ring.radius),
              child: child,
            )
          : child,
    ),
    panelBuilder: (context) {
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(height: preset.gap),
            children[index],
          ],
        ],
      );
      return KitOverlayPanel(
        width: preset.width,
        padding: preset.padding,
        // 폭이 없으면(`.spop`) 내용 폭에 맞춘다.
        child: preset.width == null ? IntrinsicWidth(child: column) : column,
      );
    },
  );
}

/// 트리거 강조를 그린다. [active]가 아니면 아무것도 그리지 않는다.
class FlyoutTriggerRingPainter extends CustomPainter {
  const FlyoutTriggerRingPainter({required this.ring, required this.active});

  final FlyoutTriggerRing ring;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    if (!active) return;
    final stroke = Paint()
      ..color = ring.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ring.width;
    switch (ring.shape) {
      case FlyoutTriggerShape.rounded:
        // CSS `inset 0 0 0 1.5px`: 선이 상자 안쪽에 놓인다.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(ring.width / 2),
            Radius.circular(ring.radius - ring.width / 2),
          ),
          stroke,
        );
      case FlyoutTriggerShape.parallelogram:
        final path = flyoutParallelogramPath(size, radius: ring.radius);
        final fill = ring.fill;
        if (fill != null) canvas.drawPath(path, Paint()..color = fill);
        canvas.drawPath(path, stroke);
      case FlyoutTriggerShape.circle:
        // CSS `0 0 0 2px`: 원 바깥에 놓인다.
        canvas.drawCircle(
          size.center(Offset.zero),
          size.shortestSide / 2 + ring.width / 2,
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(FlyoutTriggerRingPainter oldDelegate) =>
      oldDelegate.ring != ring || oldDelegate.active != active;
}

class _ParallelogramClipper extends CustomClipper<Path> {
  const _ParallelogramClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) => flyoutParallelogramPath(size, radius: radius);

  @override
  bool shouldReclip(_ParallelogramClipper oldClipper) =>
      oldClipper.radius != radius;
}

/// 통계 점 트리거 `.sdot`: 26px 투명 원(누르는 자리). 점 그림은 차트가 그린다.
class FlyoutDot extends StatelessWidget {
  const FlyoutDot({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: 26);
}

/// 플라이아웃 행 `.fr`·`.pr`(시나리오 `.sr_`는 [padding]을 5 8로).
class FlyoutRow extends StatelessWidget {
  const FlyoutRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    this.gap = 10,
    this.leftBar,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;

  /// 왼쪽 3px 막대 색(시안 `box-shadow: inset 3px 0 0`).
  final Color? leftBar;

  static const fill = Color.fromRGBO(255, 255, 255, 0.035);

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: padding,
      decoration: const BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.all(Radius.circular(7)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(width: gap),
            children[index],
          ],
        ],
      ),
    );
    final leftBar = this.leftBar;
    if (leftBar == null) return row;
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(7)),
      child: CustomPaint(
        foregroundPainter: _LeftBarPainter(leftBar),
        child: row,
      ),
    );
  }
}

class _LeftBarPainter extends CustomPainter {
  const _LeftBarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRect(
    Rect.fromLTWH(0, 0, 3, size.height),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_LeftBarPainter oldDelegate) => oldDelegate.color != color;
}

/// 플라이아웃 머리 줄: 제목(14px 굵게) + 오른쪽 설명 [note](11px, 남는 폭에서 줄임) + [trailing].
class FlyoutHeader extends StatelessWidget {
  const FlyoutHeader(
    this.title, {
    super.key,
    this.leading,
    this.note,
    this.noteSpans,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final String? note;

  /// [note] 뒤에 붙는 색 글자(예: `BD` 파랑 · `노트` 핑크).
  final List<InlineSpan>? noteSpans;
  final Widget? trailing;

  static const titleStyle = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppType.titleSmallSize,
    height: 1.3,
    fontWeight: AppType.bold,
    color: AppColors.text,
  );

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final hasNote = note != null || noteSpans != null;
    final trailing = this.trailing;
    return Row(
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 8)],
        if (!hasNote)
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          )
        else ...[
          Text(title, maxLines: 1, style: titleStyle),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(text: note, children: noteSpans),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: FlyoutFooter.textStyle,
            ),
          ),
        ],
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }
}

/// 플라이아웃 아래 줄: 설명(11px #9eb0c2) + 오른쪽 [trailing](tonal 버튼·링크).
class FlyoutFooter extends StatelessWidget {
  const FlyoutFooter({super.key, this.text, this.trailing});

  final String? text;
  final Widget? trailing;

  static const textStyle = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.fallback,
    fontSize: AppType.captionSize,
    height: 1.4,
    color: AppColors.textMuted,
  );

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    final trailing = this.trailing;
    return Row(
      children: [
        Expanded(
          child: text == null ? const SizedBox() : Text(text, style: textStyle),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }
}

/// 아래 줄 링크 글자(`계획에서 보기 →`: 12px w700 #f7c9f4).
class FlyoutLink extends StatelessWidget {
  const FlyoutLink(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontFamily: AppFonts.body,
      fontFamilyFallback: AppFonts.fallback,
      fontSize: AppType.bodySmallSize,
      height: 1.4,
      fontWeight: AppType.bold,
      color: AppColors.accentText,
    ),
  );
}
