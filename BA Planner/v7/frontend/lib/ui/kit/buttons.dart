// 버튼: tonal 버튼·레일 버튼(+그룹) (FE2-b, H §6.3).
//
// `.tonal`: r10, padding 0 16, 간격 8, 13px w600, 기본 #3a4b58/#d6e4f0(hover #455866),
//   pri #f2b3ef/#2a1330(hover #f7c9f4), ghost rgba(14,21,31,.45), dng rgba(255,126,138,.12)/#ffa0a8.
//   CSS 순서상 ghost·dng는 hover 때도 색이 그대로다. `.tonal.cur/.done`은 시안에서 쓰지 않는다(FD-014).
// `.btn`(레일 버튼): 왼쪽 수직·오른쪽 80° r8(Q 곡선), 안쪽 왼쪽 16·오른쪽 cut+12. 기본 #2a3d54(hover #33496a),
//   ghost rgba(14,21,31,.45)(hover rgba(36,52,72,.8)), pri #f2b3ef/#2a1330(hover #f7c9f4),
//   sel-pink #6b3e6c→#4a3552 + 왼쪽 3px #f2b3ef, sel-blue #25587b→#2a4a66 + 왼쪽 3px #71c7f4,
//   done rgba(113,199,244,.12)/#a8e0ff, tri #c79ac9/#2a1330(hover #d9b0db). `.btn.dng/.icon`은 쓰지 않는다(FD-014).
//   그룹은 레일을 따라 아래 버튼일수록 폭이 줄어든다(위 버튼과의 세로 거리/tan80).
// 시안에 비활성 규칙은 없다. 키트 공통으로 불투명도 .45, 키보드 포커스는 파랑 테두리다(워커 결정).
// K1: tonal 버튼 간격 · 굵기 · 아이콘 크기 매개변수(기본값은 시안 `.tonal` 8 · 600 · 16, 튜토리얼 그만두기 5 · 700 · 13).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';
import 'diagonal_row.dart';
import 'kit_pressable.dart';

// ---------------------------------------------------------------------------
// TonalButton

/// tonal 버튼 변형.
enum TonalButtonVariant { normal, primary, ghost, danger }

/// 변형별 바탕·hover·글자색.
@immutable
class TonalButtonColors {
  const TonalButtonColors({
    required this.fill,
    required this.hoverFill,
    required this.foreground,
  });

  factory TonalButtonColors.of(TonalButtonVariant variant) => switch (variant) {
    TonalButtonVariant.normal => const TonalButtonColors(
      fill: Color(0xff3a4b58),
      hoverFill: Color(0xff455866),
      foreground: Color(0xffd6e4f0),
    ),
    TonalButtonVariant.primary => const TonalButtonColors(
      fill: AppColors.accent,
      hoverFill: AppColors.accentText,
      foreground: AppColors.onAccent,
    ),
    TonalButtonVariant.ghost => const TonalButtonColors(
      fill: Color.fromRGBO(14, 21, 31, 0.45),
      hoverFill: Color.fromRGBO(14, 21, 31, 0.45),
      foreground: Color(0xffd6e4f0),
    ),
    TonalButtonVariant.danger => const TonalButtonColors(
      fill: Color.fromRGBO(255, 126, 138, 0.12),
      hoverFill: Color.fromRGBO(255, 126, 138, 0.12),
      foreground: Color(0xffffa0a8),
    ),
  };

  final Color fill;
  final Color hoverFill;
  final Color foreground;
}

/// tonal 버튼(`.tonal`). [icon]은 16px 앞 아이콘이다. [leading]은 시안 svg 선 아이콘처럼 Material 아이콘이 아닌 앞 위젯이고
/// (FE6-d, 둘 다 주면 [leading]), [semanticLabel]은 보이는 글자 대신 읽을 의미 라벨이다(시안 `aria-label`).
/// [gap]은 앞 아이콘과 글자 사이, [fontWeight]는 글자 굵기, [iconSize]는 [icon] 크기다(K1).
class TonalButton extends StatelessWidget {
  const TonalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.leading,
    this.semanticLabel,
    this.variant = TonalButtonVariant.normal,
    this.height = AppControlHeights.tonalButton,
    this.horizontalPadding = 16,
    this.fontSize = AppType.bodySize,
    this.gap = 8,
    this.fontWeight = AppType.semiBold,
    this.iconSize = 16,
    this.hovered,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// 앞 위젯(글자 앞 간격 [gap]). 색은 [TonalButtonColors.of]`(variant).foreground`를 쓴다.
  final Widget? leading;

  /// 의미 라벨. 없으면 보이는 글자다.
  final String? semanticLabel;
  final TonalButtonVariant variant;
  final double height;
  final double horizontalPadding;
  final double fontSize;
  final double gap;
  final FontWeight fontWeight;
  final double iconSize;

  /// hover 상태를 고정한다(갤러리 견본용).
  final bool? hovered;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = TonalButtonColors.of(variant);
    final icon = this.icon;
    final leading = this.leading;
    final button = KitPressable(
      onPressed: onPressed,
      hovered: hovered,
      focusNode: focusNode,
      semanticLabel: semanticLabel,
      builder: (context, state) => Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        decoration: BoxDecoration(
          color: state.hovered ? colors.hoverFill : colors.fill,
          borderRadius: const BorderRadius.all(
            Radius.circular(AppRadii.control),
          ),
          boxShadow: state.focused
              ? const [BoxShadow(color: kitFocusColor, spreadRadius: 1.5)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading,
              SizedBox(width: gap),
            ] else if (icon != null) ...[
              Icon(icon, size: iconSize, color: colors.foreground),
              SizedBox(width: gap),
            ],
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontFamilyFallback: AppFonts.fallback,
                fontSize: fontSize,
                height: 1.2,
                fontWeight: fontWeight,
                color: colors.foreground,
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

// ---------------------------------------------------------------------------
// RailButton

/// 레일 버튼 변형(시안 `.btn` 클래스).
enum RailButtonVariant {
  /// `.btn`
  base,

  /// `.btn.ghost`
  ghost,

  /// `.btn.pri`
  primary,

  /// `.btn.sel-pink`
  selectedPink,

  /// `.btn.sel-blue`
  selectedBlue,

  /// `.btn.done`
  done,

  /// `.btn.tri`
  tri,
}

/// 레일 버튼의 바탕·글자.
@immutable
class RailButtonLook {
  const RailButtonLook({
    this.fill,
    this.gradient,
    this.leftBar,
    required this.foreground,
  });

  factory RailButtonLook.of(RailButtonVariant variant, {bool hovered = false}) =>
      switch (variant) {
        RailButtonVariant.base => RailButtonLook(
          fill: hovered ? const Color(0xff33496a) : const Color(0xff2a3d54),
          foreground: AppColors.text,
        ),
        RailButtonVariant.ghost => RailButtonLook(
          fill: hovered
              ? const Color.fromRGBO(36, 52, 72, 0.8)
              : const Color.fromRGBO(14, 21, 31, 0.45),
          foreground: AppColors.text,
        ),
        RailButtonVariant.primary => RailButtonLook(
          fill: hovered ? AppColors.accentText : AppColors.accent,
          foreground: AppColors.onAccent,
        ),
        RailButtonVariant.selectedPink => const RailButtonLook(
          gradient: LinearGradient(
            colors: [Color(0xff6b3e6c), Color(0xff4a3552)],
          ),
          leftBar: AppColors.accent,
          foreground: AppColors.text,
        ),
        RailButtonVariant.selectedBlue => const RailButtonLook(
          gradient: LinearGradient(
            colors: [Color(0xff25587b), Color(0xff2a4a66)],
          ),
          leftBar: AppColors.primary,
          foreground: AppColors.text,
        ),
        RailButtonVariant.done => const RailButtonLook(
          fill: Color.fromRGBO(113, 199, 244, 0.12),
          foreground: Color(0xffa8e0ff),
        ),
        RailButtonVariant.tri => RailButtonLook(
          fill: hovered ? const Color(0xffd9b0db) : const Color(0xffc79ac9),
          foreground: AppColors.onAccent,
        ),
      };

  final Color? fill;
  final Gradient? gradient;

  /// 왼쪽 3px 막대(선택 표시).
  final Color? leftBar;
  final Color foreground;

  @override
  bool operator ==(Object other) =>
      other is RailButtonLook &&
      other.fill == fill &&
      other.gradient == gradient &&
      other.leftBar == leftBar &&
      other.foreground == foreground;

  @override
  int get hashCode => Object.hash(fill, gradient, leftBar, foreground);
}

/// 레일 버튼. 폭은 부모가 정한다(그룹은 [RailButtonGroup]).
///
/// 버튼 모양 path([diagonalRowPath], rail)와 hit test 영역이 같다.
/// [child]에는 기본 글자색·13.5px w600·16px 아이콘색이 적용된다.
class RailButton extends StatelessWidget {
  const RailButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.variant = RailButtonVariant.base,
    this.height = 44,
    this.hovered,
    this.focusNode,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final RailButtonVariant variant;
  final double height;

  /// hover 상태를 고정한다(갤러리 견본용).
  final bool? hovered;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: height,
      child: ClipPath(
        clipper: const DiagonalRowClipper(DiagonalRowVariant.rail),
        child: KitPressable(
          onPressed: onPressed,
          hovered: hovered,
          focusNode: focusNode,
          semanticLabel: semanticLabel,
          selected:
              variant == RailButtonVariant.selectedPink ||
              variant == RailButtonVariant.selectedBlue,
          builder: (context, state) {
            final look = RailButtonLook.of(variant, hovered: state.hovered);
            return CustomPaint(
              painter: RailButtonPainter(look: look, focused: state.focused),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: diagonalCutDepth(height) + 12,
                ),
                child: IconTheme.merge(
                  data: IconThemeData(color: look.foreground, size: 16),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontFamily: AppFonts.body,
                      fontFamilyFallback: AppFonts.fallback,
                      fontSize: AppType.bodyPlusSize,
                      height: 1.2,
                      fontWeight: AppType.semiBold,
                      color: look.foreground,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    return onPressed == null
        ? Opacity(opacity: kitDisabledOpacity, child: button)
        : button;
  }
}

/// 레일 버튼 painter: 바탕·왼쪽 막대·포커스 테두리.
class RailButtonPainter extends CustomPainter {
  const RailButtonPainter({required this.look, this.focused = false});

  final RailButtonLook look;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, DiagonalRowVariant.rail);
    final gradient = look.gradient;
    final fill = look.fill;
    if (gradient != null) {
      canvas.drawPath(
        path,
        Paint()..shader = gradient.createShader(Offset.zero & size),
      );
    } else if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill);
    }
    final leftBar = look.leftBar;
    if (leftBar != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 3, size.height),
        Paint()..color = leftBar,
      );
    }
    if (focused) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = kitFocusColor,
      );
    }
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(RailButtonPainter oldDelegate) =>
      oldDelegate.look != look || oldDelegate.focused != focused;
}

/// 레일 버튼 묶음. 첫 버튼이 부모 폭을 다 쓰고, 아래 버튼은 레일을 따라 폭이 줄어든다.
class RailButtonGroup extends StatelessWidget {
  const RailButtonGroup({super.key, required this.buttons, this.gap = 8});

  final List<RailButton> buttons;
  final double gap;

  /// [index]번째 버튼의 폭: `maxWidth - cutDepth(그 버튼 윗변까지의 세로 거리)`.
  static double widthAt({
    required double maxWidth,
    required List<double> heights,
    required double gap,
    required int index,
  }) {
    var top = 0.0;
    for (var i = 0; i < index; i++) {
      top += heights[i] + gap;
    }
    return math.max(0, maxWidth - diagonalCutDepth(top));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final heights = [for (final button in buttons) button.height];
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < buttons.length; index++)
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : gap),
              child: SizedBox(
                width: widthAt(
                  maxWidth: constraints.maxWidth,
                  heights: heights,
                  gap: gap,
                  index: index,
                ),
                child: buttons[index],
              ),
            ),
        ],
      );
    },
  );
}
