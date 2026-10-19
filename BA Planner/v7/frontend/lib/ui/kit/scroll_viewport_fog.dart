// 스크롤 포그 공용 위젯 (FE2-a, FD-018 (a)).
//
// 스크롤 영역의 위·아래 끝을 패널색 그라데이션으로 덮어 "더 있다"를 알린다.
// 시안에는 세 가지가 있고, 모두 이 위젯의 파라미터로 만든다(H §6.2).
// - A 정적: 36px #263d52, 스크롤 범위가 있으면 바로 보인다. 기존 화면 전부가 이 값이다.
// - B 패널색: 44px 패널색(#141e2b 등), 시작 60px 동안 위 포그가 나타나고 끝 60px 동안 아래 포그가 사라진다(rs-*).
// - C 통계: 56px rgba(25,36,50,.96), 페이드 80px(sv-*).
//
// 원래 `ui/widgets/scroll_viewport_fog.dart`에 있었다. 그 파일은 이 파일을 다시 내보내므로 기존 import는 그대로 쓴다.
import 'package:flutter/material.dart';

/// 포그 A의 높이(기존 기본값).
const scrollViewportFogExtent = 36.0;

/// 포그 A의 색(기존 기본값).
const scrollViewportFogColor = Color(0xff263d52);

/// 스크롤 위치로 위·아래 포그를 보일지 정한다. 범위가 [tolerance] 이하이면 둘 다 숨긴다.
({bool showTop, bool showBottom}) scrollViewportFogVisibility({
  required double minScrollExtent,
  required double maxScrollExtent,
  required double pixels,
  double tolerance = 0.5,
}) {
  final hasScrollRange = maxScrollExtent - minScrollExtent > tolerance;
  return (
    showTop: hasScrollRange && pixels > minScrollExtent + tolerance,
    showBottom: hasScrollRange && pixels < maxScrollExtent - tolerance,
  );
}

/// 페이드 범위가 있는 포그(B·C)의 불투명도.
///
/// 위 포그는 스크롤이 시작점에서 [fadeRange]만큼 내려오는 동안 0 → 1, 아래 포그는 끝점까지
/// [fadeRange] 남았을 때부터 1 → 0이 된다. [fadeRange]가 0 이하이면 [scrollViewportFogVisibility]의
/// 결과를 1/0으로 돌려준다(포그 A와 같다).
({double top, double bottom}) scrollViewportFogOpacity({
  required double minScrollExtent,
  required double maxScrollExtent,
  required double pixels,
  double fadeRange = 0,
  double tolerance = 0.5,
}) {
  final visibility = scrollViewportFogVisibility(
    minScrollExtent: minScrollExtent,
    maxScrollExtent: maxScrollExtent,
    pixels: pixels,
    tolerance: tolerance,
  );
  if (fadeRange <= 0) {
    return (
      top: visibility.showTop ? 1.0 : 0.0,
      bottom: visibility.showBottom ? 1.0 : 0.0,
    );
  }
  if (maxScrollExtent - minScrollExtent <= tolerance) {
    return (top: 0.0, bottom: 0.0);
  }
  return (
    top: ((pixels - minScrollExtent) / fadeRange).clamp(0.0, 1.0).toDouble(),
    bottom: ((maxScrollExtent - pixels) / fadeRange).clamp(0.0, 1.0).toDouble(),
  );
}

/// 포그 한 벌의 사양: 높이·색·페이드 범위.
@immutable
class ScrollFogSpec {
  const ScrollFogSpec({
    this.extent = scrollViewportFogExtent,
    this.color = scrollViewportFogColor,
    this.fadeRange = 0,
  });

  /// 포그 B(rs-* 목록): 44px 패널색, 페이드 60px. [color]는 목록이 놓인 패널색이다.
  const ScrollFogSpec.panel({required Color color})
    : this(extent: 44, color: color, fadeRange: 60);

  /// 포그 A(기존 기본값).
  static const standard = ScrollFogSpec();

  /// 포그 C(통계 sv-*): 56px rgba(25,36,50,.96), 페이드 80px.
  static const statistics = ScrollFogSpec(
    extent: 56,
    color: Color.fromRGBO(25, 36, 50, 0.96),
    fadeRange: 80,
  );

  final double extent;
  final Color color;

  /// 0이면 페이드 없이 보이거나 숨는다.
  final double fadeRange;

  @override
  bool operator ==(Object other) =>
      other is ScrollFogSpec &&
      other.extent == extent &&
      other.color == color &&
      other.fadeRange == fadeRange;

  @override
  int get hashCode => Object.hash(extent, color, fadeRange);
}

/// 스크롤 영역 위에 겹치는 포그. 포인터를 받지 않는다.
///
/// [topOpacity]·[bottomOpacity]는 페이드 포그(B·C)에서만 1보다 작다. 1이면 기존과 같은
/// 위젯 트리를 만든다(Opacity를 끼우지 않는다).
class ScrollViewportFog extends StatelessWidget {
  const ScrollViewportFog({
    super.key,
    required this.keyPrefix,
    required this.showTop,
    required this.showBottom,
    this.color = scrollViewportFogColor,
    this.extent = scrollViewportFogExtent,
    this.topOpacity = 1.0,
    this.bottomOpacity = 1.0,
  });

  /// [spec]과 스크롤 위치로 포그를 만든다. 페이드가 없는 사양이면 기본 생성자와 같은 결과다.
  factory ScrollViewportFog.fromScroll({
    Key? key,
    required String keyPrefix,
    required ScrollFogSpec spec,
    required double minScrollExtent,
    required double maxScrollExtent,
    required double pixels,
  }) {
    final opacity = scrollViewportFogOpacity(
      minScrollExtent: minScrollExtent,
      maxScrollExtent: maxScrollExtent,
      pixels: pixels,
      fadeRange: spec.fadeRange,
    );
    return ScrollViewportFog(
      key: key,
      keyPrefix: keyPrefix,
      showTop: opacity.top > 0,
      showBottom: opacity.bottom > 0,
      color: spec.color,
      extent: spec.extent,
      topOpacity: opacity.top,
      bottomOpacity: opacity.bottom,
    );
  }

  final String keyPrefix;
  final bool showTop;
  final bool showBottom;
  final Color color;
  final double extent;
  final double topOpacity;
  final double bottomOpacity;

  Widget _faded(double opacity, Widget child) =>
      opacity >= 1.0 ? child : Opacity(opacity: opacity, child: child);

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (showTop)
          Align(
            key: ValueKey('$keyPrefix-top'),
            alignment: Alignment.topCenter,
            child: _faded(
              topOpacity,
              Container(
                height: extent,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        if (showBottom)
          Align(
            key: ValueKey('$keyPrefix-bottom'),
            alignment: Alignment.bottomCenter,
            child: _faded(
              bottomOpacity,
              Container(
                height: extent,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withValues(alpha: 0), color],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
