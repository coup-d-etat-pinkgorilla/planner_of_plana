// FE3-d1 UI Kit 갤러리: W-Filter 둘째 줄 범위 슬라이더 · 성급 범위 타일.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/gallery/ui_kit_gallery_page.dart';
import 'package:ba_planner_v7/ui/kit/range_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpGallery(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: BAPlannerTheme.dark(), home: const UiKitGalleryPage()),
  );
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('범위 슬라이더 · 성급 범위 타일이 시안 크기로 그려진다', (tester) async {
    await _pumpGallery(tester);
    for (final (tile, width) in const [
      ('range-slider', 980.5),
      ('star-range', 980.5),
    ]) {
      await _show(tester, 'kit-gallery-fe2b-$tile');
      final rect = tester.getRect(find.byKey(ValueKey('kit-gallery-fe2b-$tile')));
      expect(rect.width, closeTo(width, 0.01), reason: tile);
      expect(rect.height, closeTo(250, 0.01), reason: tile);
    }
    final slider = tester.getRect(
      find.byKey(const ValueKey('kit-gallery-fe2b-range-slider')),
    );
    final star = tester.getRect(
      find.byKey(const ValueKey('kit-gallery-fe2b-star-range')),
    );
    // 시안 x: 40 / 1000.4 → 갤러리 x − 40.
    expect(star.left - slider.left, closeTo(960.4, 0.01));
    expect(star.top, closeTo(slider.top, 0.01));

    expect(find.byType(RangeSliderRow), findsNWidgets(3));
    expect(find.byType(StarRangeBar), findsNWidgets(2));
    expect(
      tester
          .widget<RangeSliderRow>(
            find.byKey(const ValueKey('kit-gallery-range-level')),
          )
          .narrowed,
      isTrue,
    );
    expect(
      tester
          .widget<RangeSliderRow>(
            find.byKey(const ValueKey('kit-gallery-range-ex')),
          )
          .narrowed,
      isFalse,
    );
    expect(find.text('M'), findsOneWidget);
    expect(find.text('T10'), findsOneWidget);
    expect(find.text('3칸 중 가장 낮은 칸'), findsOneWidget);
    expect(find.text('무기★1'), findsOneWidget);
    expect(find.text('무기★4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('견본 슬라이더가 움직인다', (tester) async {
    await _pumpGallery(tester);
    await _show(tester, 'kit-gallery-range-ex');
    final track = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('kit-gallery-range-ex')),
        matching: find.byType(RangeSliderTrack),
      ),
    );
    // 4 자리(최대 5에 더 가깝다)를 누르면 최대 핸들이 온다.
    final inner = track.width - rangeTrackInset * 2;
    await tester.tapAt(Offset(track.left + 10 + inner * 0.75, track.center.dy));
    await tester.pump();
    final ex = tester.widget<RangeSliderRow>(
      find.byKey(const ValueKey('kit-gallery-range-ex')),
    );
    expect((ex.low, ex.high), (1, 4));
    expect(ex.narrowed, isTrue);
  });
}
