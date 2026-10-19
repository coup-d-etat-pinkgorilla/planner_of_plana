// FE2-b 제목·텍스트 테스트(패널 제목·타일 제목·소제목·키-값).
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/titles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

Widget _wide(Widget child) => SizedBox(width: 450, child: child);

void main() {
  testWidgets('panel title: 7x22 bar, display 19, rule cap 46, trailing chip', (
    tester,
  ) async {
    await pumpKit(
      tester,
      _wide(
        const PanelTitle(
          '패널 제목',
          trailing: BaChip(label: '보조 칩', tone: AppTones.gray),
        ),
      ),
    );
    final bar = tester.widget<TitleBar>(find.byType(TitleBar));
    expect((bar.width, bar.height), (7.0, 22.0));
    final style = tester.widget<Text>(find.text('패널 제목')).style!;
    expect(style.fontFamily, AppFonts.display);
    expect(style.fontSize, AppType.panelTitleSize);
    expect(tester.widget<TitleRule>(find.byType(TitleRule)).capWidth, 46);
    expect(find.text('보조 칩'), findsOneWidget);
    final rule = tester.getRect(find.byType(TitleRule));
    expect(rule.width, closeTo(450, 0.01));
    expect(rule.height, closeTo(1, 0.01));
    final row = tester.getRect(find.text('패널 제목'));
    expect(rule.top - row.bottom, greaterThanOrEqualTo(6 - 0.01));
  });

  testWidgets('tile title: 6x18 bar, display 16, rule cap 40', (tester) async {
    await pumpKit(
      tester,
      _wide(
        const TileTitle(
          '타일 안 제목',
          trailing: BaChip(label: '1주', tone: AppTones.pink),
        ),
      ),
    );
    final bar = tester.widget<TitleBar>(find.byType(TitleBar));
    expect((bar.width, bar.height), (6.0, 18.0));
    expect(
      tester.widget<Text>(find.text('타일 안 제목')).style!.fontSize,
      AppType.titleSize,
    );
    expect(tester.widget<TitleRule>(find.byType(TitleRule)).capWidth, 40);
    // 칩은 오른쪽 끝에 붙는다.
    expect(
      tester.getRect(find.byType(BaChip)).right,
      closeTo(tester.getRect(find.byType(TileTitle)).right, 0.01),
    );
    expect(TitleRule.gradient.colors.first, const Color.fromRGBO(113, 199, 244, 0.65));
    expect(TitleRule.gradient.stops, [0, 0.45, 1]);
  });

  testWidgets('sub header: blue 5x5 dot and display text', (tester) async {
    await pumpKit(tester, const SubHeader('LEVEL', fontSize: 9));
    final dot = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SubHeader),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((dot.decoration as BoxDecoration).color, AppColors.primary);
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(SubHeader),
              matching: find.byType(DecoratedBox),
            ),
          ),
      const Size(5, 5),
    );
    final style = tester.widget<Text>(find.text('LEVEL')).style!;
    expect(style.fontFamily, AppFonts.display);
    expect(style.fontSize, 9);
    expect(
      const SubHeader('x').fontSize,
      AppType.indicatorHeaderSize,
    );
  });

  testWidgets('key-value: cap label 11px above the value, gap 3', (
    tester,
  ) async {
    await pumpKit(tester, const KV(label: '필요 크레딧', value: Text('48.2M')));
    final label = tester.widget<Text>(find.text('필요 크레딧')).style!;
    expect(label.fontSize, AppType.captionSize);
    expect(label.fontWeight, AppType.semiBold);
    expect(label.color, AppColors.textMuted);
    final top = tester.getRect(find.text('필요 크레딧'));
    final bottom = tester.getRect(find.text('48.2M'));
    expect(bottom.top - top.bottom, closeTo(3, 0.01));
  });
}
