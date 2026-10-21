// 평행사변형 패널 버튼 (K1, 계정 추가 모달 `_PathButton` · `_cancelTexture` 승격 — 시안 `Title-Accounts-New`, FD-113).
//
// 모달 패널 안 버튼: 오른쪽 위로 기운 80° 평행사변형(모서리 둥글기 [ParallelogramPanelButton.radius]), 채움(색 또는 절차
// 삼각 텍스처) + 외곽선(위에 그림, 누르기를 받지 않음) + InkWell 누르기. 누르는 범위도 평행사변형이다. 내용은 안쪽 3px
// 안에서 가운데, 자리보다 크면 줄이기만 한다. 부모가 준 크기를 다 쓴다(모달은 `Positioned.fromRect`로 자리를 준다).
// [kitPanelCancelTexture]는 모달 '취소' · 튜토리얼 그만두기 확인 '그만두기'의 연분홍 삼각 텍스처다.
import 'package:flutter/material.dart';

import '../geometry/diagonal_geometry.dart';
import '../widgets/ba_triangle_background.dart';

/// 오른쪽 위로 기운 80° 평행사변형(왼쪽 위 꼭짓점이 높이/tan80°만큼 오른쪽). [radius]로 둥글린다(원호 모서리 —
/// `accountCreateParallelogram`과 같은 path).
Path kitParallelogramPath(Rect rect, double radius) {
  final cut = diagonalCutDepth(rect.height);
  return diagonalRoundedPolygon(
    [
      Offset(rect.left + cut, rect.top),
      Offset(rect.right, rect.top),
      Offset(rect.right - cut, rect.bottom),
      Offset(rect.left, rect.bottom),
    ],
    radius: radius,
    corner: DiagonalCornerStyle.arc,
  );
}

/// 패널 '취소' 버튼 텍스처(연분홍 삼각, 시드 7411).
const kitPanelCancelTexture = BATriangleTextureConfig(
  baseColor: BATrianglePalette.softTitlePinkBase,
  panelColor: BATrianglePalette.softTitlePinkPanel,
  softColor: BATrianglePalette.softTitlePinkSoft,
  accentColor: BATrianglePalette.softTitlePinkAccent,
  triangleSize: 30,
  tessellationContrast: 0.09,
  randomSeed: 7411,
  macroTriangleChance: 0.14,
  macroTriangleScale: 2.1,
  macroTriangleContrast: 0.06,
  lightStrength: 0.22,
  edgeVignetteStrength: 0.12,
  fogStrength: 0.08,
);

/// 평행사변형 패널 버튼. [texture]가 있으면 텍스처, 없으면 [fill](없으면 투명)로 채운다. [onTap]이 null이면 누르기를
/// 받지 않는다(흐리게 하는 것은 [child] 몫 — 모달 '만들기'처럼). [semanticLabel]이 있으면 그 이름의 버튼으로 읽힌다.
class ParallelogramPanelButton extends StatelessWidget {
  const ParallelogramPanelButton({
    super.key,
    required this.radius,
    required this.outline,
    required this.outlineWidth,
    required this.onTap,
    required this.child,
    this.fill,
    this.texture,
    this.semanticLabel,
  });

  final double radius;
  final Color? fill;
  final BATriangleTextureConfig? texture;
  final Color outline;
  final double outlineWidth;
  final String? semanticLabel;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final texture = this.texture;
    final button = ClipPath(
      clipper: _ParallelogramClipper(radius),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (texture != null)
            BATriangleBackground(config: texture)
          else
            ColoredBox(color: fill ?? Colors.transparent),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: FittedBox(fit: BoxFit.scaleDown, child: child),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        semanticLabel == null
            ? button
            : Semantics(button: true, label: semanticLabel, child: button),
        IgnorePointer(
          child: CustomPaint(
            painter: ParallelogramOutlinePainter(
              radius: radius,
              color: outline,
              strokeWidth: outlineWidth,
            ),
          ),
        ),
      ],
    );
  }
}

class _ParallelogramClipper extends CustomClipper<Path> {
  const _ParallelogramClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => kitParallelogramPath(Offset.zero & size, radius);

  @override
  bool shouldReclip(_ParallelogramClipper oldClipper) =>
      oldClipper.radius != radius;
}

/// 평행사변형 외곽선([kitParallelogramPath], 칠하는 크기 전체).
class ParallelogramOutlinePainter extends CustomPainter {
  const ParallelogramOutlinePainter({
    required this.radius,
    required this.color,
    required this.strokeWidth,
  });

  final double radius;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    kitParallelogramPath(Offset.zero & size, radius),
    Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..color = color,
  );

  @override
  bool shouldRepaint(ParallelogramOutlinePainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
