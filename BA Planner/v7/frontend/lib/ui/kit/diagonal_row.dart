// 사선 행 공용 위젯 (FE2-a, H §6.2 `.srow`·`.row`·`.plain`·`.tile`).
//
// 시안의 목록 행은 80° 평행사변형(r8 Q 곡선)이고, 배경과 `.bd` 테두리 path로 상태를 나타낸다.
// 공통 CSS(UI-Elements 등):
//   .srow  rgba(16,24,35,.72), 테두리 2px rgba(113,199,244,.16)
//          button.srow:hover rgba(30,45,62,.9)
//          .sel rgba(52,36,58,.85) + 테두리 4px #f2b3ef / .blue 테두리 4px rgba(113,199,244,.65)
//   .row   srow와 같은 배경·테두리(hover·sel·blue 규칙 없음)
//   .plain 투명, 테두리 없음
//   .tile  rgba(16,24,35,.6), 테두리 없음, hover rgba(45,80,105,.8)
// 테두리는 행 모양으로 잘린 path stroke라 안쪽 절반만 보인다(2px → 1px, 4px → 2px).
// `rail`은 W-Layout "사다리꼴 안 스크롤"·전술대항전의 `.rsr-*` 행이다(왼쪽 끝 수직, 오른쪽 끝 80°).
//   기본 rgba(14,21,31,.45), hover rgba(36,52,72,.8), 선택 = 핑크 그라데이션 + 왼쪽 3px #f2b3ef.
// 시안 CSS에 정의만 있고 쓰이지 않는 `.dash` 등은 만들지 않는다(FD-014).
//
// 테두리를 그리는 path([diagonalRowPath])와 hit test·hover 영역이 같다. 행은 그 path로 잘린
// `ClipPath` 안에 있어서, 바깥 삼각형 자리의 포인터는 이 행을 지나 뒤로 간다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../geometry/diagonal_geometry.dart';

/// 행 변형.
enum DiagonalRowVariant {
  /// `.srow`: 선택·파랑 표시와 hover가 있는 사선 행.
  srow,

  /// `.row`: srow와 같은 바탕, 상태 없음.
  row,

  /// `.plain`: 투명 행.
  plain,

  /// `.tile`: 테두리 없는 타일 바탕. 위젯 카드는 [WidgetTile]로 쓴다(FD-022).
  tile,

  /// `.rsr-*`: 왼쪽 끝이 수직이고 오른쪽 끝만 80°인 레일 목록 행(resize 모드 목록).
  rail,
}

/// 행 표시. 시안 CSS에 규칙이 있는 조합만 쓴다: [selected]는 srow·rail, [blue]는 srow.
enum DiagonalRowMark { none, selected, blue }

/// 행 모양 path. 그리기·clip·hit test가 모두 이 path를 쓴다.
///
/// 평행사변형 변형은 `(cut,0) (w,0) (w-cut,h) (0,h)`, rail은 `(0,0) (w,0) (w-cut,h) (0,h)`이다.
/// cut = `diagonalCutDepth(h)`, 모서리는 반경 [radius]의 Q 곡선(시안 path와 같은 방식)이다.
Path diagonalRowPath(
  Size size,
  DiagonalRowVariant variant, {
  double radius = AppRadii.row,
}) {
  final cut = diagonalCutDepth(size.height);
  final topLeft = variant == DiagonalRowVariant.rail
      ? Offset.zero
      : Offset(cut, 0);
  return diagonalRoundedPolygon(
    [
      topLeft,
      Offset(size.width, 0),
      Offset(size.width - cut, size.height),
      Offset(0, size.height),
    ],
    radius: radius,
    corner: DiagonalCornerStyle.quadratic,
  );
}

/// 변형·표시·hover에 따른 바탕과 테두리.
@immutable
class DiagonalRowLook {
  const DiagonalRowLook({
    this.fill,
    this.gradient,
    this.border,
    this.borderWidth = 0,
    this.leftBar,
  });

  /// [variant]·[mark]·[hovered]의 시안 값.
  factory DiagonalRowLook.of(
    DiagonalRowVariant variant, {
    DiagonalRowMark mark = DiagonalRowMark.none,
    bool hovered = false,
  }) {
    switch (variant) {
      case DiagonalRowVariant.srow:
        final fill = hovered
            ? const Color.fromRGBO(30, 45, 62, 0.9)
            : mark == DiagonalRowMark.selected
            ? const Color.fromRGBO(52, 36, 58, 0.85)
            : _rowFill;
        return switch (mark) {
          DiagonalRowMark.selected => DiagonalRowLook(
            fill: fill,
            border: AppColors.accent,
            borderWidth: 4,
          ),
          DiagonalRowMark.blue => DiagonalRowLook(
            fill: fill,
            border: AppColors.primary.withValues(alpha: 0.65),
            borderWidth: 4,
          ),
          DiagonalRowMark.none => DiagonalRowLook(
            fill: fill,
            border: _rowBorder,
            borderWidth: 2,
          ),
        };
      case DiagonalRowVariant.row:
        return DiagonalRowLook(
          fill: _rowFill,
          border: _rowBorder,
          borderWidth: 2,
        );
      case DiagonalRowVariant.plain:
        return const DiagonalRowLook();
      case DiagonalRowVariant.tile:
        return DiagonalRowLook(
          fill: hovered
              ? const Color.fromRGBO(45, 80, 105, 0.8)
              : AppColors.rowSurface.withValues(alpha: 0.6),
        );
      case DiagonalRowVariant.rail:
        if (mark == DiagonalRowMark.selected) {
          return const DiagonalRowLook(
            gradient: LinearGradient(
              colors: [
                Color.fromRGBO(107, 62, 108, 0.62),
                Color.fromRGBO(74, 53, 82, 0.38),
              ],
            ),
            leftBar: AppColors.accent,
          );
        }
        return DiagonalRowLook(
          fill: hovered
              ? const Color.fromRGBO(36, 52, 72, 0.8)
              : const Color.fromRGBO(14, 21, 31, 0.45),
        );
    }
  }

  static final _rowFill = AppColors.rowSurface.withValues(alpha: 0.72);
  static final _rowBorder = AppColors.primary.withValues(alpha: 0.16);

  final Color? fill;
  final Gradient? gradient;
  final Color? border;

  /// path stroke 두께. 행 모양으로 잘리므로 보이는 두께는 절반이다.
  final double borderWidth;

  /// 왼쪽 3px 막대(rail 선택).
  final Color? leftBar;

  @override
  bool operator ==(Object other) =>
      other is DiagonalRowLook &&
      other.fill == fill &&
      other.gradient == gradient &&
      other.border == border &&
      other.borderWidth == borderWidth &&
      other.leftBar == leftBar;

  @override
  int get hashCode => Object.hash(fill, gradient, border, borderWidth, leftBar);
}

/// 사선 행. [child]는 행 상자 전체를 받는다(안쪽 여백은 [padding]).
///
/// [onTap]이 있으면 누를 수 있고, srow·tile·rail은 마우스를 올리면 hover 바탕이 된다.
/// [hovered]를 주면 마우스와 관계없이 그 상태로 그린다(갤러리·검수용).
class DiagonalRow extends StatefulWidget {
  const DiagonalRow({
    super.key,
    this.variant = DiagonalRowVariant.srow,
    this.mark = DiagonalRowMark.none,
    this.onTap,
    this.hovered,
    this.radius = AppRadii.row,
    this.padding = EdgeInsets.zero,
    this.child,
  });

  final DiagonalRowVariant variant;

  /// 시안 규칙이 없는 조합(예: `.row`의 selected, rail의 blue)은 기본 모양으로 그린다.
  final DiagonalRowMark mark;
  final VoidCallback? onTap;
  final bool? hovered;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget? child;

  @override
  State<DiagonalRow> createState() => _DiagonalRowState();
}

class _DiagonalRowState extends State<DiagonalRow> {
  bool _pointerInside = false;

  bool get _hoverable =>
      widget.onTap != null &&
      (widget.variant == DiagonalRowVariant.srow ||
          widget.variant == DiagonalRowVariant.tile ||
          widget.variant == DiagonalRowVariant.rail);

  void _setInside(bool value) {
    if (_pointerInside == value) return;
    setState(() => _pointerInside = value);
  }

  @override
  Widget build(BuildContext context) {
    final hovered = widget.hovered ?? (_hoverable && _pointerInside);
    final look = DiagonalRowLook.of(
      widget.variant,
      mark: widget.mark,
      hovered: hovered,
    );
    Widget content = CustomPaint(
      painter: DiagonalRowPainter(
        variant: widget.variant,
        look: look,
        radius: widget.radius,
      ),
      child: Padding(
        padding: widget.padding,
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
    if (widget.onTap != null) {
      content = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => _setInside(true),
        onExit: (_) => _setInside(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: content,
        ),
      );
    }
    return Semantics(
      button: widget.onTap != null,
      selected: widget.mark == DiagonalRowMark.selected,
      child: ClipPath(
        clipper: DiagonalRowClipper(widget.variant, radius: widget.radius),
        child: content,
      ),
    );
  }
}

/// 행 바탕·테두리 painter. 테두리는 [diagonalRowPath]를 stroke한다.
class DiagonalRowPainter extends CustomPainter {
  const DiagonalRowPainter({
    required this.variant,
    required this.look,
    this.radius = AppRadii.row,
  });

  final DiagonalRowVariant variant;
  final DiagonalRowLook look;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = diagonalRowPath(size, variant, radius: radius);
    final fill = look.fill;
    final gradient = look.gradient;
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
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, 3, size.height),
        Paint()..color = leftBar,
      );
      canvas.restore();
    }
    final border = look.border;
    if (border != null && look.borderWidth > 0) {
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = look.borderWidth
          ..strokeJoin = StrokeJoin.round
          ..color = border,
      );
      canvas.restore();
    }
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(DiagonalRowPainter oldDelegate) =>
      oldDelegate.variant != variant ||
      oldDelegate.look != look ||
      oldDelegate.radius != radius;
}

/// [diagonalRowPath]로 자르는 clipper. `RenderClipPath`는 이 path 밖의 포인터를 받지 않는다.
class DiagonalRowClipper extends CustomClipper<Path> {
  const DiagonalRowClipper(this.variant, {this.radius = AppRadii.row});

  final DiagonalRowVariant variant;
  final double radius;

  @override
  Path getClip(Size size) => diagonalRowPath(size, variant, radius: radius);

  @override
  bool shouldReclip(DiagonalRowClipper oldClipper) =>
      oldClipper.variant != variant || oldClipper.radius != radius;
}

/// 시안 W-* 위젯 카드(`.tile`, FD-022의 `WidgetTile`). 평행사변형 r8, rgba(16,24,35,.6), 테두리 없음.
///
/// 재화 타일(UI-Elements `.tile` 300×107, FD-022의 `ResourceTile`)은 FE2-d에서 따로 만든다.
class WidgetTile extends StatelessWidget {
  const WidgetTile({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DiagonalRow(
    variant: DiagonalRowVariant.tile,
    padding: padding,
    child: child,
  );
}
