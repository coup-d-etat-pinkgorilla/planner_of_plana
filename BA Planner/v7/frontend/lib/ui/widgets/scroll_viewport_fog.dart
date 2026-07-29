import 'package:flutter/material.dart';

const scrollViewportFogExtent = 36.0;

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

class ScrollViewportFog extends StatelessWidget {
  const ScrollViewportFog({
    super.key,
    required this.keyPrefix,
    required this.showTop,
    required this.showBottom,
  });

  static const _fogColor = Color(0xff263d52);
  final String keyPrefix;
  final bool showTop;
  final bool showBottom;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (showTop)
          Align(
            key: ValueKey('$keyPrefix-top'),
            alignment: Alignment.topCenter,
            child: Container(
              height: scrollViewportFogExtent,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_fogColor, Color(0x00263d52)],
                ),
              ),
            ),
          ),
        if (showBottom)
          Align(
            key: ValueKey('$keyPrefix-bottom'),
            alignment: Alignment.bottomCenter,
            child: Container(
              height: scrollViewportFogExtent,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00263d52), _fogColor],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
