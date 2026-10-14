// 섹션 틀 공용 위젯(tidy2, FE9-a 키트 승격 후보).
//
// Studio 문서의 섹션 하나를 그리는 화면(통계 FE7 · 전술 FE9)이 각자 같은 코드를 사본으로 갖고 있었다:
// - [SectionFrame]: 섹션 표면(`paintSectionSurface`, lifted shadow 포함)을 그리고, 그 위에 내용을 섹션 모양으로 자른다.
//   통계 `_SectionFrame` · 전술 `_SectionFrame`(+ 각자의 `_SectionPainter` · `_SectionClipper`)였다.
// - [SectionScaledBox]: 작은 창에서 요소를 시안 크기로 배치한 뒤 같은 비율로 줄인다(화면 전체 축소가 아니라 섹션 안 요소 하나).
//   통계 `_ScaledBox` · `StatisticsScaledBox` · 전술 `_Scaled`였다.
// 그리는 순서 · 자르기 · 배율 식은 사본과 같다(golden 변화 0).
import 'package:flutter/widgets.dart';

import '../studio/section_template.dart';
import '../widgets/section_surface.dart';
import '../widgets/section_template_surface.dart';

/// [section] 표면 + [section] 모양으로 자른 [children](`Stack`, 자르기 안에서는 넘침 허용).
///
/// 표면 `CustomPaint`는 [surfaceKey]를 받는다(테스트 · golden이 찾는 key). 표면은 누르기를 받지 않는다.
class SectionFrame extends StatelessWidget {
  const SectionFrame({
    super.key,
    required this.section,
    required this.surfaceKey,
    required this.children,
  });

  final SectionCanvasElement section;
  final Key surfaceKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: surfaceKey,
            painter: SectionSurfacePainter(section),
          ),
        ),
      ),
      Positioned.fill(
        child: ClipPath(
          clipper: SectionShapeClipper(section),
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ),
    ],
  );
}

/// [section] 표면 painter(그림자 → 표면, `paintSectionSurface`).
class SectionSurfacePainter extends CustomPainter {
  const SectionSurfacePainter(this.section);

  final SectionCanvasElement section;

  @override
  void paint(Canvas canvas, Size size) =>
      paintSectionSurface(canvas, buildSectionCanvasElementPath(size, section));

  @override
  bool shouldRepaint(SectionSurfacePainter oldDelegate) =>
      !_sameSection(oldDelegate.section, section);
}

/// [section] 모양 clipper.
class SectionShapeClipper extends CustomClipper<Path> {
  const SectionShapeClipper(this.section);

  final SectionCanvasElement section;

  @override
  Path getClip(Size size) => buildSectionCanvasElementPath(size, section);

  @override
  bool shouldReclip(SectionShapeClipper oldClipper) =>
      !_sameSection(oldClipper.section, section);
}

/// 같은 Studio 문서 element면 같은 섹션이다(사본은 섹션 id로 비교했다 — 문서 element는 id마다 한 인스턴스라 결과가 같다).
/// `copyWith`로 rect · spec만 바꾼 element는 다른 섹션으로 본다(rect · spec은 `==`가 없어 인스턴스로 비교).
bool _sameSection(SectionCanvasElement a, SectionCanvasElement b) =>
    identical(a, b) ||
    (a.id == b.id && identical(a.rect, b.rect) && identical(a.spec, b.spec));

/// [scale]이 1보다 작으면 [child]를 시안 크기(자리 ÷ scale)로 배치한 뒤 같은 비율로 줄인다. 1 이상이거나 자리가 한쪽이라도
/// 무한이면 [child]를 그대로 둔다.
class SectionScaledBox extends StatelessWidget {
  const SectionScaledBox({super.key, required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale >= 1) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return child;
        }
        return FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: constraints.maxWidth / scale,
            height: constraints.maxHeight / scale,
            child: child,
          ),
        );
      },
    );
  }
}
