// FE2-d UI Kit 갤러리 구역 테스트: 타일이 넘침 없이 그려지고, 차트 원자 견본이 눌러서 고르기에 반응한다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/gallery/ui_kit_data_section.dart';
import 'package:ba_planner_v7/ui/kit/gallery/ui_kit_gallery_page.dart';
import 'package:ba_planner_v7/ui/kit/item_icon_tile.dart';
import 'package:ba_planner_v7/ui/kit/kpi_tile.dart';
import 'package:ba_planner_v7/ui/kit/portrait_strip.dart';
import 'package:ba_planner_v7/ui/kit/skew_bar.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpGallery(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(theme: BAPlannerTheme.dark(), home: const UiKitGalleryPage()),
  );
  await tester.pump();
}

Future<void> _show(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pump();
}

SampleBarChartPainter _chartPainter(WidgetTester tester) =>
    tester
            .widget<StatChartFrame>(
              find.byKey(const ValueKey('kit-gallery-chart-frame')),
            )
            .painter
        as SampleBarChartPainter;

void main() {
  testWidgets('FE2-d tiles render without overflow', (tester) async {
    await _pumpGallery(tester);
    for (final tile in [
      'kpi',
      'resources',
      'item-tiles',
      'ratio-bars',
      'chart-atoms',
      'image-atoms',
    ]) {
      await _show(tester, 'kit-gallery-fe2d-$tile');
      expect(
        find.byKey(ValueKey('kit-gallery-fe2d-$tile')),
        findsOneWidget,
        reason: tile,
      );
    }
    expect(find.byType(KpiTile), findsNWidgets(6));
    expect(find.byType(ItemTile), findsNWidgets(4));
    // 계획 무관 타일만 막대가 없다.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('kit-gallery-item-tile-unrelated')),
        matching: find.byType(SkewBar),
      ),
      findsNothing,
    );
    expect(
      tester
          .widget<SkewBar>(
            find.descendant(
              of: find.byKey(const ValueKey('kit-gallery-item-tile-excess')),
              matching: find.byType(SkewBar),
            ),
          )
          .color,
      CoverageTone.excess.color,
    );
    expect(find.text('…+2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('kit-gallery-portraits-7')),
      findsOneWidget,
    );
    expect(find.byType(PortraitStrip), findsWidgets);
    // 모름 막대는 빗금(fraction null), 0 막대는 빈 트랙(fraction 0).
    expect(
      tester
          .widget<SkewBar>(find.byKey(const ValueKey('kit-gallery-skew-bar-모름')))
          .fraction,
      isNull,
    );
    expect(
      tester
          .widget<SkewBar>(find.byKey(const ValueKey('kit-gallery-skew-bar-0')))
          .fraction,
      0,
    );
    // 비율 막대 행은 아래로 갈수록 80° 레일만큼 왼쪽으로 나온다.
    final first = tester.getRect(
      find.byKey(const ValueKey('kit-gallery-ratio-row-0')),
    );
    final last = tester.getRect(
      find.byKey(const ValueKey('kit-gallery-ratio-row-4')),
    );
    expect(first.left, closeTo(last.left, 0.01));
    final firstName = tester.getRect(find.text('밀레니엄').last);
    final lastName = tester.getRect(find.text('산해경'));
    expect(firstName.left - lastName.left, closeTo(28.2, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart atom sample selects the tapped bar', (tester) async {
    await _pumpGallery(tester);
    await _show(tester, 'kit-gallery-chart-frame');
    expect(_chartPainter(tester).selected, 5);
    final frame = find.byKey(const ValueKey('kit-gallery-chart-frame'));
    final slot = SampleBarChartPainter.slotRect(1);
    // 설계 좌표 → 화면: 1.25배.
    await tester.tapAt(
      tester.getTopLeft(frame) +
          Offset(slot.center.dx, slot.bottom - 4) * statChartScale,
    );
    await tester.pump();
    expect(_chartPainter(tester).selected, 1);
    expect(tester.takeException(), isNull);
  });
}
