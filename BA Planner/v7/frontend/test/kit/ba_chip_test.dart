// FE2-b 칩·단계 태그 테스트.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/kit_glyph.dart';
import 'package:ba_planner_v7/ui/kit/skew_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

void main() {
  testWidgets('chip uses the six fixed tones and the prototype size', (
    tester,
  ) async {
    for (final tone in AppTones.all) {
      await pumpKit(
        tester,
        BaChip(key: const ValueKey('chip'), label: '정보', tone: tone),
      );
      final chip = find.byKey(const ValueKey('chip'));
      final box = tester.widget<Container>(
        find.descendant(of: chip, matching: find.byType(Container)).first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, tone.background);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(AppRadii.chip)),
      );
      expect(tester.widget<Text>(find.text('정보')).style!.color, tone.foreground);
      expect(tester.getSize(chip).height, closeTo(24, 0.01));
    }
    expect(AppTones.pink.background, AppColors.accent.withValues(alpha: 0.2));
    expect(AppTones.gray.foreground, AppColors.textSecondary);
  });

  testWidgets('removable chip calls back from the x by tap and keyboard', (
    tester,
  ) async {
    var removed = 0;
    await pumpKit(
      tester,
      BaChip(
        key: const ValueKey('chip'),
        label: '밀레니엄',
        tone: AppTones.pink,
        onRemove: () => removed++,
      ),
    );
    final close = find.descendant(
      of: find.byKey(const ValueKey('chip')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is KitGlyphPainter,
      ),
    );
    expect(close, findsOneWidget);
    expect(tester.getSize(close), const Size(11, 11));
    await tester.tap(close);
    await tester.pump();
    expect(removed, 1);

    await pressWithKeyboard(tester, close);
    expect(removed, 2);
  });

  testWidgets('chip without onRemove has no x', (tester) async {
    await pumpKit(tester, const BaChip(label: '보조', tone: AppTones.gray));
    expect(
      paintersUnder<KitGlyphPainter>(tester, find.byType(BaChip)),
      isEmpty,
    );
  });

  testWidgets('stage tags: 1 blue, 2 pink, 3 yellow, selected = solid', (
    tester,
  ) async {
    for (final (stage, color) in const [
      (1, AppColors.primary),
      (2, AppColors.accent),
      (3, AppColors.warning),
    ]) {
      expect(StageTag.colorOf(stage), color);
      await pumpKit(tester, StageTag(stage: stage));
      var box = paintersUnder<SkewBoxPainter>(
        tester,
        find.byType(StageTag),
      ).single;
      expect(box.fill, color.withValues(alpha: 0.16));
      expect(box.border, color.withValues(alpha: 0.55));
      expect(box.borderWidth, 1);
      expect(tester.widget<Text>(find.text('$stage단계')).style!.color, color);

      await pumpKit(tester, StageTag(stage: stage, selected: true));
      box = paintersUnder<SkewBoxPainter>(tester, find.byType(StageTag)).single;
      expect(box.fill, color);
      expect(
        tester.widget<Text>(find.text('$stage단계')).style!.color,
        StageTag.selectedText,
      );
      expect(tester.getSize(find.byType(StageTag)).height, closeTo(24, 0.01));
    }
  });
}
