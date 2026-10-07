// FE2-b 사선 세그먼트·토글 칩·타입 칩·필터 버튼·스위치 테스트.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/kit/skew_box.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

const _segments = [
  SkewSegment(value: '1주', label: '1주'),
  SkewSegment(value: '2주', label: '2주'),
  SkewSegment(value: '4주', label: '4주'),
];

void main() {
  testWidgets('segmented: pink border on the selected value, tap and keys', (
    tester,
  ) async {
    final changes = <String>[];
    await pumpKit(
      tester,
      SkewSegmented<String>(
        segments: _segments,
        selected: '1주',
        onChanged: changes.add,
      ),
    );
    final on = painterAbove<SkewBoxPainter>(tester, find.text('1주'));
    expect(on.fill, SkewSegmented.selectedFill);
    expect(on.border, AppColors.accent);
    expect(on.borderWidth, 1.5);
    final off = painterAbove<SkewBoxPainter>(tester, find.text('2주'));
    expect(off.fill, SkewSegmented.idleFill);
    expect(off.border, SkewSegmented.idleBorder);
    expect(off.borderWidth, 1);
    expect(
      tester.widget<Text>(find.text('1주')).style!.color,
      AppColors.accentText,
    );
    expect(
      tester.widget<Text>(find.text('2주')).style!.color,
      AppColors.textSecondary,
    );
    expect(
      tester.getSize(find.ancestor(of: find.text('2주'), matching: find.byType(SizedBox)).first).height,
      closeTo(AppControlHeights.segmented, 0.01),
    );

    await tester.tap(find.text('2주'));
    await tester.pump();
    expect(changes, ['2주']);
    await pressWithKeyboard(tester, find.text('4주'));
    expect(changes, ['2주', '4주']);
  });

  testWidgets('segmented without onChanged is dimmed and inert', (
    tester,
  ) async {
    await pumpKit(
      tester,
      const SkewSegmented<String>(
        segments: _segments,
        selected: '1주',
        onChanged: null,
      ),
    );
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      kitDisabledOpacity,
    );
    await tester.tap(find.text('2주'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('toggle chip switches, shows the count and the on look', (
    tester,
  ) async {
    bool? next;
    await pumpKit(
      tester,
      SkewToggleChip(
        label: '게헨나',
        count: 28,
        selected: false,
        onChanged: (value) => next = value,
      ),
    );
    var box = painterAbove<SkewBoxPainter>(tester, find.text('게헨나'));
    expect(box.fill, SkewToggleChip.idleFill);
    expect(box.border, SkewToggleChip.idleBorder);
    expect(find.text('28'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('게헨나')).style!.fontWeight,
      AppType.medium,
    );
    expect(
      tester.getSize(find.byType(SkewToggleChip)).height,
      closeTo(AppControlHeights.toggleChip, 0.01),
    );
    await tester.tap(find.text('게헨나'));
    await tester.pump();
    expect(next, isTrue);

    await pumpKit(
      tester,
      SkewToggleChip(
        label: '게헨나',
        selected: true,
        onChanged: (value) => next = value,
      ),
    );
    box = painterAbove<SkewBoxPainter>(tester, find.text('게헨나'));
    expect(box.fill, AppColors.accent.withValues(alpha: 0.2));
    expect(box.border, AppColors.accent);
    expect(box.borderWidth, 1.5);
    final label = tester.widget<Text>(find.text('게헨나')).style!;
    expect(label.fontWeight, AppType.bold);
    expect(label.color, AppColors.accentText);
    await pressWithKeyboard(tester, find.text('게헨나'));
    expect(next, isFalse);
  });

  testWidgets('type chip puts the type color bar in front', (tester) async {
    await pumpKit(
      tester,
      TypeChip(
        label: '복합장갑',
        color: AppColors.typeComposite,
        selected: false,
        onChanged: (_) {},
      ),
    );
    expect(
      tester.widget<TypeColorBar>(find.byType(TypeColorBar)).color,
      AppColors.typeComposite,
    );
    final bar = tester.getRect(find.byType(TypeColorBar));
    final label = tester.getRect(find.text('복합장갑'));
    expect(bar.right, lessThan(label.left));
    expect(find.text('복합장갑'), findsOneWidget);
  });

  testWidgets('filter button shows the applied count in pink', (
    tester,
  ) async {
    var pressed = 0;
    await pumpKit(
      tester,
      FilterButton(activeCount: 0, onPressed: () => pressed++),
    );
    expect(find.text('필터'), findsOneWidget);
    var box = painterAbove<SkewBoxPainter>(tester, find.text('필터'));
    expect(box.border, FilterButton.idleBorder);
    expect(box.borderWidth, 1);
    await tester.tap(find.text('필터'));
    await tester.pump();
    expect(pressed, 1);

    await pumpKit(
      tester,
      FilterButton(activeCount: 3, onPressed: () => pressed++),
    );
    expect(find.text('필터 · 3'), findsOneWidget);
    box = painterAbove<SkewBoxPainter>(tester, find.text('필터 · 3'));
    expect(box.fill, FilterButton.activeFill);
    expect(box.border, AppColors.accent);
    expect(box.borderWidth, 1.5);
    expect(
      tester.widget<Text>(find.text('필터 · 3')).style!.color,
      AppColors.accentText,
    );
    await pressWithKeyboard(tester, find.text('필터 · 3'));
    expect(pressed, 2);
  });

  testWidgets('switch is 40x22 and moves the knob when turned on', (
    tester,
  ) async {
    var value = false;
    await pumpKit(
      tester,
      StatefulBuilder(
        builder: (context, setState) => BaSwitch(
          key: const ValueKey('switch'),
          value: value,
          onChanged: (next) => setState(() => value = next),
        ),
      ),
    );
    final track = find.descendant(
      of: find.byKey(const ValueKey('switch')),
      matching: find.byType(AnimatedContainer),
    );
    expect(tester.getSize(track).width, closeTo(40, 0.01));
    expect(tester.getSize(track).height, closeTo(22, 0.01));
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
      Alignment.centerLeft,
    );

    await tester.tap(find.byKey(const ValueKey('switch')));
    await tester.pumpAndSettle();
    expect(value, isTrue);
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment,
      Alignment.centerRight,
    );
    final decoration =
        tester.widget<AnimatedContainer>(track).decoration! as BoxDecoration;
    expect(decoration.color, AppColors.accent);
    final knob = tester.getRect(
      find.descendant(
        of: find.byType(AnimatedAlign),
        matching: find.byType(DecoratedBox),
      ),
    );
    final trackRect = tester.getRect(track);
    expect(knob.left - trackRect.left, closeTo(21, 0.01));
    expect(knob.width, closeTo(16, 0.01));

    await pressWithKeyboard(tester, find.byType(AnimatedAlign));
    await tester.pumpAndSettle();
    expect(value, isFalse);
  });

  testWidgets('disabled switch does not toggle', (tester) async {
    await pumpKit(
      tester,
      const BaSwitch(key: ValueKey('switch'), value: true, onChanged: null),
    );
    await tester.tap(find.byKey(const ValueKey('switch')));
    await tester.pump();
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      kitDisabledOpacity,
    );
  });
}
