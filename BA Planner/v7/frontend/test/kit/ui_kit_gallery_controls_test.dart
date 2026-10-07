// FE2-b UI Kit 갤러리 구역 테스트: 타일이 모두 그려지고, 견본 컨트롤이 실제로 반응한다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/gallery/ui_kit_gallery_page.dart';
import 'package:ba_planner_v7/ui/kit/skew_box.dart';
import 'package:ba_planner_v7/ui/kit/titles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

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
  testWidgets('FE2-b tiles render without overflow', (tester) async {
    await _pumpGallery(tester);
    for (final tile in [
      'titles',
      'chips',
      'stage-tags',
      'nudge',
      'toggle-chips',
      'type-chips',
      'active-filters',
      'rail-buttons',
      'switch-stepper',
      'filter-button',
      'states',
    ]) {
      await _show(tester, 'kit-gallery-fe2b-$tile');
      expect(
        find.byKey(ValueKey('kit-gallery-fe2b-$tile')),
        findsOneWidget,
        reason: tile,
      );
    }
    // FE2-a 타일 제목도 키트 TileTitle을 쓴다.
    expect(find.widgetWithText(TileTitle, '사다리꼴 안 스크롤'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery controls respond', (tester) async {
    await _pumpGallery(tester);

    await _show(tester, 'kit-gallery-segment');
    await tester.tap(find.text('2주'));
    await tester.pump();
    expect(
      painterAbove<SkewBoxPainter>(tester, find.text('2주')).borderWidth,
      1.5,
    );

    await _show(tester, 'kit-gallery-toggle-게헨나');
    final gehenna = find.byKey(const ValueKey('kit-gallery-toggle-게헨나'));
    expect(
      painterAbove<SkewBoxPainter>(tester, find.text('게헨나')).border,
      isNot(AppColors.accent),
    );
    await tester.tap(gehenna);
    await tester.pump();
    expect(
      painterAbove<SkewBoxPainter>(tester, find.text('게헨나')).border,
      AppColors.accent,
    );

    await _show(tester, 'kit-gallery-active-filter-레벨 70~90');
    expect(
      find.byKey(const ValueKey('kit-gallery-active-filter-레벨 70~90')),
      findsOneWidget,
    );
    await pressWithKeyboard(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('kit-gallery-active-filter-레벨 70~90')),
        matching: find.byType(CustomPaint),
      ).last,
    );
    expect(
      find.byKey(const ValueKey('kit-gallery-active-filter-레벨 70~90')),
      findsNothing,
    );

    await _show(tester, 'kit-gallery-switch');
    await tester.tap(find.byKey(const ValueKey('kit-gallery-switch')));
    await tester.pumpAndSettle();
    final track =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: find.byKey(const ValueKey('kit-gallery-switch')),
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(track.color, isNot(AppColors.accent));

    await _show(tester, 'kit-gallery-nudge');
    expect(find.text('Lv.90'), findsOneWidget);
    // 아래 꺾쇠(낮추기). 90이 최대라 올리기는 비활성이다.
    await tester.tap(
      find
          .descendant(
            of: find.byKey(const ValueKey('kit-gallery-nudge')),
            matching: find.byType(CustomPaint),
          )
          .last,
    );
    await tester.pump();
    expect(find.text('Lv.89'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
