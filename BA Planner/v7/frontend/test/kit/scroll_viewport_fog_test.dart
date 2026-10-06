// FE2-a 스크롤 포그 파라미터 테스트: 기본값은 기존 포그 A와 같고, 페이드 포그(B·C)는 범위만큼 서서히 바뀐다.
import 'package:ba_planner_v7/ui/kit/scroll_viewport_fog.dart';
import 'package:ba_planner_v7/ui/widgets/scroll_viewport_fog.dart' as legacy;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults equal the former fixed fog', () {
    expect(scrollViewportFogExtent, 36);
    expect(scrollViewportFogColor, const Color(0xff263d52));
    const fog = ScrollViewportFog(
      keyPrefix: 'fog',
      showTop: true,
      showBottom: true,
    );
    expect(fog.extent, 36);
    expect(fog.color, const Color(0xff263d52));
    expect(fog.topOpacity, 1);
    expect(fog.bottomOpacity, 1);
    expect(ScrollFogSpec.standard.extent, 36);
    expect(ScrollFogSpec.standard.color, const Color(0xff263d52));
    expect(ScrollFogSpec.standard.fadeRange, 0);
    // 옛 경로는 같은 선언을 다시 내보낸다.
    expect(legacy.scrollViewportFogExtent, scrollViewportFogExtent);
  });

  test('prototype fog presets B and C', () {
    const panel = ScrollFogSpec.panel(color: Color(0xff141e2b));
    expect(panel.extent, 44);
    expect(panel.fadeRange, 60);
    expect(panel.color, const Color(0xff141e2b));
    expect(ScrollFogSpec.statistics.extent, 56);
    expect(ScrollFogSpec.statistics.fadeRange, 80);
    expect(
      ScrollFogSpec.statistics.color,
      const Color.fromRGBO(25, 36, 50, 0.96),
    );
  });

  test('opacity without fade range matches the visibility switch', () {
    for (final pixels in [0.0, 0.4, 0.6, 150.0, 299.6, 300.0]) {
      final visibility = scrollViewportFogVisibility(
        minScrollExtent: 0,
        maxScrollExtent: 300,
        pixels: pixels,
      );
      final opacity = scrollViewportFogOpacity(
        minScrollExtent: 0,
        maxScrollExtent: 300,
        pixels: pixels,
      );
      expect(opacity.top, visibility.showTop ? 1.0 : 0.0);
      expect(opacity.bottom, visibility.showBottom ? 1.0 : 0.0);
    }
  });

  test('fade range ramps the top in and the bottom out', () {
    ({double top, double bottom}) at(double pixels) => scrollViewportFogOpacity(
      minScrollExtent: 0,
      maxScrollExtent: 300,
      pixels: pixels,
      fadeRange: 60,
    );
    expect(at(0).top, 0);
    expect(at(30).top, closeTo(0.5, 1e-12));
    expect(at(60).top, 1);
    expect(at(100).bottom, 1);
    expect(at(270).bottom, closeTo(0.5, 1e-12));
    expect(at(300).bottom, 0);
    final empty = scrollViewportFogOpacity(
      minScrollExtent: 0,
      maxScrollExtent: 0.2,
      pixels: 0.1,
      fadeRange: 60,
    );
    expect(empty.top, 0);
    expect(empty.bottom, 0);
  });

  testWidgets('full opacity keeps the former widget tree', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ScrollViewportFog(
          keyPrefix: 'tree',
          showTop: true,
          showBottom: true,
        ),
      ),
    );
    expect(find.byType(Opacity), findsNothing);
    final top = tester.getRect(find.byKey(const ValueKey('tree-top')));
    expect(tester.getSize(find.byType(Container).first).height, 36);
    expect(top.top, 0);
    expect(find.byKey(const ValueKey('tree-bottom')), findsOneWidget);
  });

  testWidgets('fromScroll fades with the spec', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScrollViewportFog.fromScroll(
          keyPrefix: 'fade',
          spec: const ScrollFogSpec.panel(color: Color(0xff141e2b)),
          minScrollExtent: 0,
          maxScrollExtent: 400,
          pixels: 15,
        ),
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(const ValueKey('fade-top')),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, closeTo(0.25, 1e-12));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('fade-bottom')),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
    expect(tester.getSize(find.byType(Container).first).height, 44);
  });
}
