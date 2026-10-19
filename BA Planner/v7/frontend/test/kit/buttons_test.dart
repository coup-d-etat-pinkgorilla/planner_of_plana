// FE2-b tonal 버튼·레일 버튼(+그룹) 테스트. FE6-d: tonal 버튼 앞 위젯 슬롯 · 의미 라벨.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/geometry/diagonal_geometry.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

BoxDecoration _tonalDecoration(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(
                of: find.byType(TonalButton),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as BoxDecoration;

void main() {
  test('tonal colors follow the prototype', () {
    final normal = TonalButtonColors.of(TonalButtonVariant.normal);
    expect(normal.fill, const Color(0xff3a4b58));
    expect(normal.hoverFill, const Color(0xff455866));
    expect(normal.foreground, const Color(0xffd6e4f0));
    final primary = TonalButtonColors.of(TonalButtonVariant.primary);
    expect(primary.fill, AppColors.accent);
    expect(primary.hoverFill, AppColors.accentText);
    expect(primary.foreground, AppColors.onAccent);
    final ghost = TonalButtonColors.of(TonalButtonVariant.ghost);
    expect(ghost.hoverFill, ghost.fill);
    final danger = TonalButtonColors.of(TonalButtonVariant.danger);
    expect(danger.foreground, const Color(0xffffa0a8));
  });

  testWidgets('tonal button: size, hover, tap, keyboard, disabled', (
    tester,
  ) async {
    var pressed = 0;
    await pumpKit(
      tester,
      TonalButton(
        label: '주 버튼',
        icon: Icons.layers_outlined,
        variant: TonalButtonVariant.primary,
        onPressed: () => pressed++,
      ),
    );
    expect(_tonalDecoration(tester).color, AppColors.accent);
    expect(
      _tonalDecoration(tester).borderRadius,
      const BorderRadius.all(Radius.circular(AppRadii.control)),
    );
    expect(
      tester.getSize(find.byType(TonalButton)).height,
      closeTo(AppControlHeights.tonalButton, 0.01),
    );
    expect(
      tester.widget<Text>(find.text('주 버튼')).style!.color,
      AppColors.onAccent,
    );
    expect(tester.widget<Icon>(find.byType(Icon)).size, 16);
    await tester.tap(find.text('주 버튼'));
    await tester.pump();
    expect(pressed, 1);
    await pressWithKeyboard(tester, find.text('주 버튼'));
    expect(pressed, 2);

    await pumpKit(
      tester,
      TonalButton(label: '보조 버튼', hovered: true, onPressed: () {}),
    );
    expect(_tonalDecoration(tester).color, const Color(0xff455866));

    await pumpKit(tester, const TonalButton(label: '보조 버튼', onPressed: null));
    expect(
      tester.widget<Opacity>(find.byType(Opacity)).opacity,
      kitDisabledOpacity,
    );
  });

  testWidgets('tonal button: widget leading slot and semantic label (FE6-d)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    // 앞 위젯은 Material 아이콘 자리(16 + 간격 8)에 같은 크기로 들어간다.
    var pressed = 0;
    await pumpKit(
      tester,
      TonalButton(
        label: '축소',
        leading: const SizedBox(
          key: ValueKey('tonal-leading'),
          width: 14,
          height: 14,
        ),
        icon: Icons.layers_outlined,
        semanticLabel: '패널 축소',
        onPressed: () => pressed++,
      ),
    );
    expect(find.byKey(const ValueKey('tonal-leading')), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    final leading = tester.getTopRight(find.byKey(const ValueKey('tonal-leading')));
    expect(tester.getTopLeft(find.text('축소')).dx - leading.dx, closeTo(8, 0.01));
    expect(find.bySemanticsLabel(RegExp('패널 축소')), findsOneWidget);
    await tester.tap(find.text('축소'));
    await tester.pump();
    expect(pressed, 1);

    // 슬롯을 주지 않으면 지금과 같다(아이콘 · 의미 라벨 없음).
    await pumpKit(
      tester,
      TonalButton(label: '확장', icon: Icons.layers_outlined, onPressed: () {}),
    );
    expect(find.byType(Icon), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('패널')), findsNothing);
    semantics.dispose();
  });

  test('rail button looks follow the prototype classes', () {
    expect(
      RailButtonLook.of(RailButtonVariant.base).fill,
      const Color(0xff2a3d54),
    );
    expect(
      RailButtonLook.of(RailButtonVariant.base, hovered: true).fill,
      const Color(0xff33496a),
    );
    expect(
      RailButtonLook.of(RailButtonVariant.ghost, hovered: true).fill,
      const Color.fromRGBO(36, 52, 72, 0.8),
    );
    final pink = RailButtonLook.of(RailButtonVariant.selectedPink);
    expect(pink.leftBar, AppColors.accent);
    expect(pink.gradient, isNotNull);
    expect(
      RailButtonLook.of(RailButtonVariant.selectedPink, hovered: true),
      pink,
    );
    expect(
      RailButtonLook.of(RailButtonVariant.selectedBlue).leftBar,
      AppColors.primary,
    );
    expect(
      RailButtonLook.of(RailButtonVariant.primary).foreground,
      AppColors.onAccent,
    );
    expect(
      RailButtonLook.of(RailButtonVariant.done).foreground,
      const Color(0xffa8e0ff),
    );
  });

  testWidgets('rail button hit test follows the 80 degree edge', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: RailButton(
                onPressed: () => pressed++,
                child: const Text('활성 계획으로'),
              ),
            ),
          ),
        ),
      ),
    );
    final cut = diagonalCutDepth(44);
    // 오른쪽 아래 삼각형(사선 바깥)은 누르지 않는다.
    await tester.tapAt(Offset(300 - cut / 2 + 1, 40));
    await tester.pump();
    expect(pressed, 0);
    await tester.tapAt(const Offset(150, 22));
    await tester.pump();
    expect(pressed, 1);
    // 글자 영역은 오른쪽 cut + 12를 비운다.
    final padding = tester.widget<Padding>(
      find
          .ancestor(
            of: find.text('활성 계획으로'),
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(
      padding.padding,
      EdgeInsets.only(left: 16, right: cut + 12),
    );
  });

  testWidgets('rail button group narrows along the rail', (tester) async {
    await pumpKit(
      tester,
      SizedBox(
        width: 340,
        child: RailButtonGroup(
          buttons: [
            RailButton(
              key: const ValueKey('b0'),
              height: 58,
              variant: RailButtonVariant.selectedPink,
              onPressed: () {},
              child: const Text('시나리오 목록'),
            ),
            RailButton(
              key: const ValueKey('b1'),
              variant: RailButtonVariant.ghost,
              onPressed: () {},
              child: const Text('활성 계획으로'),
            ),
            RailButton(
              key: const ValueKey('b2'),
              variant: RailButtonVariant.primary,
              onPressed: () {},
              child: const Text('새 시나리오'),
            ),
          ],
        ),
      ),
    );
    final widths = [
      for (final key in ['b0', 'b1', 'b2'])
        tester.getSize(find.byKey(ValueKey(key))).width,
    ];
    expect(widths[0], closeTo(340, 1e-6));
    expect(widths[1], closeTo(340 - (58 + 8) / diagonalTan80, 1e-6));
    expect(widths[2], closeTo(340 - (58 + 8 + 44 + 8) / diagonalTan80, 1e-6));
    expect(
      RailButtonGroup.widthAt(
        maxWidth: 340,
        heights: const [58, 44, 44],
        gap: 8,
        index: 1,
      ),
      closeTo(widths[1], 1e-6),
    );
    // 시안 Scenario-List: 347.1 → 334.7(세로 70, 간격 12).
    expect(
      RailButtonGroup.widthAt(
        maxWidth: 347.1,
        heights: const [58, 44, 44],
        gap: 12,
        index: 1,
      ),
      closeTo(334.7, 0.1),
    );
  });
}
