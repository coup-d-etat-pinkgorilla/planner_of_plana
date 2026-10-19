// 섹션 표면 공용 위젯·painter (FE1-c, FD-006·FD-007).
//
// 시안의 모든 실화면 섹션은 같은 표면이다: `AppColors.surface`@.76, 블러 없음, 테두리 없음,
// 그 아래 lifted path shadow 4층(`paintLiftedPathShadow` + `defaultLiftedSectionShadow`).
// 섹션을 그리는 곳은 이 파일의 [SectionSurface] 위젯이나 [paintSectionSurface] 함수만 쓴다.
// 기존 `DiagonalSection`은 이 위젯의 래퍼다.
//
// 범위: 섹션 바탕만. 섹션 안의 행·타일·칩·스크롤바·포그(FE2)와 삼각 무늬 텍스처(FD-015)는 다루지 않는다.
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'lifted_path_shadow.dart';

/// 섹션 표면 알파(시안 `rgba(29,42,58,.76)`).
const sectionSurfaceOpacity = 0.76;

/// 섹션 표면 채우기 색: `AppColors.surface`@[sectionSurfaceOpacity].
final Color sectionSurfaceColor = AppColors.surface.withValues(
  alpha: sectionSurfaceOpacity,
);

/// 섹션 하나를 그린다: [shadow]가 있으면 [path]에 lifted shadow를 먼저 그리고, 그 위에 표면을 채운다.
///
/// [fillPath]는 표면을 채울 path다. 자식 표면(텍스처 버튼·목록 컨테이너)을 차감한 path를 넘기면
/// 반투명 색이 겹쳐 합성되지 않는다. 그림자는 차감 전 [path]를 쓴다(section-template-studio 규칙).
void paintSectionSurface(
  Canvas canvas,
  Path path, {
  Path? fillPath,
  Color? fill,
  LiftedPathShadowSpec? shadow = defaultLiftedSectionShadow,
}) {
  if (shadow != null) paintLiftedPathShadow(canvas, path, shadow);
  canvas.drawPath(
    fillPath ?? path,
    Paint()
      ..color = fill ?? sectionSurfaceColor
      ..style = PaintingStyle.fill,
  );
}

/// [clipper] 모양의 섹션 표면 위에 [child]를 올린다.
///
/// 블러(`BackdropFilter`)와 테두리를 쓰지 않는다. 그림자는 표면과 같은 painter에서 그리므로
/// 섹션 motion을 따라 함께 움직인다. [child]는 같은 모양으로 잘린다.
class SectionSurface extends StatelessWidget {
  const SectionSurface({
    super.key,
    required this.clipper,
    required this.child,
    this.fill,
    this.shadow = defaultLiftedSectionShadow,
  });

  final CustomClipper<Path> clipper;
  final Widget child;

  /// 기본은 [sectionSurfaceColor]. Studio 편집기의 선택 표시처럼 시안 밖 상태에서만 바꾼다.
  final Color? fill;

  /// `null`이면 그림자를 그리지 않는다(이미 따로 `LiftedPathShadow`를 그리는 화면용).
  final LiftedPathShadowSpec? shadow;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: SectionSurfacePainter(
      clipper: clipper,
      fill: fill ?? sectionSurfaceColor,
      shadow: shadow,
    ),
    child: ClipPath(
      clipper: clipper,
      clipBehavior: Clip.antiAlias,
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
}

/// [SectionSurface]의 painter. 표면만 필요하고 자식이 없는 자리에서도 쓴다.
class SectionSurfacePainter extends CustomPainter {
  const SectionSurfacePainter({
    required this.clipper,
    required this.fill,
    this.shadow = defaultLiftedSectionShadow,
  });

  final CustomClipper<Path> clipper;
  final Color fill;
  final LiftedPathShadowSpec? shadow;

  @override
  void paint(Canvas canvas, Size size) => paintSectionSurface(
    canvas,
    clipper.getClip(size),
    fill: fill,
    shadow: shadow,
  );

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(SectionSurfacePainter oldDelegate) =>
      oldDelegate.fill != fill ||
      oldDelegate.shadow != shadow ||
      oldDelegate.clipper.runtimeType != clipper.runtimeType ||
      clipper.shouldReclip(oldDelegate.clipper);
}

/// 고정된 [path]를 그대로 돌려주는 clipper. 이미 계산된 섹션 path를 [SectionSurface]에 넘길 때 쓴다.
class SectionPathClipper extends CustomClipper<Path> {
  const SectionPathClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(SectionPathClipper oldClipper) => oldClipper.path != path;
}
