// FE2-b 스테퍼·MAX 배지·스텝 버튼·미세 조절 테스트.
//
// BaStepper·MaxBadge·StepButton은 요소 빌더에서 옮긴 것이다. 기본 모양이 그대로인지는 golden 17장이 판정하고,
// 여기서는 키·콜백·시안 변형을 본다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/kit_glyph.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/kit/stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'kit_test_utils.dart';

Widget _stepper({
  required int value,
  required ValueChanged<int> onChanged,
  BaStepperLayout layout = BaStepperLayout.inline,
  bool propagated = false,
  bool unsupported = false,
}) => BaStepper(
  key: const ValueKey('lv'),
  label: 'Lv',
  value: value,
  minimum: 1,
  maximum: 90,
  propagated: propagated,
  unsupported: unsupported,
  valueFontSize: AppType.stepperValueSize,
  layout: layout,
  onChanged: onChanged,
);

void main() {
  testWidgets('stepper keeps the element builder keys and callbacks', (
    tester,
  ) async {
    final changes = <int>[];
    await pumpKit(tester, _stepper(value: 80, onChanged: changes.add));
    for (final suffix in ['decrease', 'label', 'value', 'increase', 'max']) {
      expect(find.byKey(ValueKey('lv-$suffix')), findsOneWidget, reason: suffix);
    }
    expect(find.text('80'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lv-increase')));
    await tester.tap(find.byKey(const ValueKey('lv-decrease')));
    await tester.tap(find.byKey(const ValueKey('lv-max')));
    await tester.pump();
    expect(changes, [81, 79, 90]);

    // 최소·최대에서는 해당 버튼이 반응하지 않는다.
    changes.clear();
    await pumpKit(tester, _stepper(value: 1, onChanged: changes.add));
    await tester.tap(find.byKey(const ValueKey('lv-decrease')));
    await tester.pump();
    expect(changes, isEmpty);
    await pumpKit(tester, _stepper(value: 90, onChanged: changes.add));
    await tester.tap(find.byKey(const ValueKey('lv-increase')));
    await tester.tap(find.byKey(const ValueKey('lv-max')));
    await tester.pump();
    expect(changes, isEmpty);
  });

  testWidgets('stepper marks unsupported values and propagated targets', (
    tester,
  ) async {
    await pumpKit(
      tester,
      _stepper(value: 5, onChanged: (_) {}, unsupported: true, propagated: true),
    );
    expect(find.text('5*'), findsOneWidget);
    final box =
        tester.widget<AnimatedContainer>(find.byType(AnimatedContainer)).decoration!
            as BoxDecoration;
    expect(box.color, AppColors.primary.withValues(alpha: 0.22));
  });

  testWidgets('MAX badge matches the prototype colors', (tester) async {
    await pumpKit(
      tester,
      const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MaxBadge(controlKey: 'on', enabled: true, onTap: _noop),
          MaxBadge(controlKey: 'off', enabled: false, onTap: _noop),
        ],
      ),
    );
    BoxDecoration decorationOf(String key) =>
        tester
                .widget<Container>(
                  find.descendant(
                    of: find.byKey(ValueKey('$key-max')),
                    matching: find.byType(Container),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(
      decorationOf('on').color,
      AppColors.primary.withValues(alpha: 0.3),
    );
    expect(
      decorationOf('off').color,
      AppColors.surfaceRaised.withValues(alpha: 0.3),
    );
    expect(AppColors.surfaceRaised, const Color.fromRGBO(36, 52, 72, 1));
    expect(find.text('MAX'), findsNWidgets(2));
  });

  testWidgets('prototype layout puts the label above the value', (
    tester,
  ) async {
    final changes = <int>[];
    await pumpKit(
      tester,
      _stepper(
        value: 70,
        onChanged: changes.add,
        layout: BaStepperLayout.labelAbove,
      ),
    );
    final label = tester.getRect(find.byKey(const ValueKey('lv-label')));
    final value = tester.getRect(find.byKey(const ValueKey('lv-value')));
    expect(label.bottom, lessThanOrEqualTo(value.top + 0.01));
    expect(value.width, greaterThanOrEqualTo(40 - 0.01));
    expect(
      tester
          .widgetList<StepButton>(find.byType(StepButton))
          .every((button) => button.look == StepButtonLook.prototype),
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('lv-increase')));
    await tester.pump();
    expect(changes, [71]);
  });

  testWidgets('prototype step button: muted, white with a circle on hover', (
    tester,
  ) async {
    Future<(Color?, Color?)> look({bool? hovered}) async {
      await pumpKit(
        tester,
        StepButton(
          text: '+',
          enabled: true,
          look: StepButtonLook.prototype,
          hovered: hovered,
          onTap: _noop,
        ),
      );
      final box =
          tester
                  .widget<Container>(
                    find.descendant(
                      of: find.byType(StepButton),
                      matching: find.byType(Container),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      return (box.color, tester.widget<Text>(find.text('+')).style!.color);
    }

    final idle = await look();
    expect(idle.$1, Colors.transparent);
    expect(idle.$2, AppColors.textMuted);
    final hover = await look(hovered: true);
    expect(hover.$1, Colors.white.withValues(alpha: 0.08));
    expect(hover.$2, AppColors.text);
    expect(tester.getSize(find.byType(StepButton)), const Size(22, 24));
  });

  testWidgets('nudge buttons call back, show hover and disable', (
    tester,
  ) async {
    var up = 0;
    var down = 0;
    await pumpKit(
      tester,
      NudgeButtons(onIncrease: () => up++, onDecrease: () => down++),
    );
    final glyphs = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is KitGlyphPainter,
    );
    expect(glyphs, findsNWidgets(2));
    final upGlyph = tester.widget<CustomPaint>(glyphs.first).painter!
        as KitGlyphPainter;
    expect(upGlyph.glyph, KitGlyph.chevronUp);
    expect(upGlyph.color, AppColors.textMuted);
    await tester.tap(glyphs.first);
    await tester.tap(glyphs.last);
    await tester.pump();
    expect((up, down), (1, 1));
    await pressWithKeyboard(tester, glyphs.first);
    expect(up, 2);

    await pumpKit(
      tester,
      NudgeButtons(onIncrease: () {}, onDecrease: null, hovered: true),
    );
    final hovered = tester.widget<CustomPaint>(glyphs.first).painter!
        as KitGlyphPainter;
    expect(hovered.color, AppColors.accent);
    final opacities = tester
        .widgetList<Opacity>(find.byType(Opacity))
        .map((opacity) => opacity.opacity)
        .toList();
    expect(opacities, [1, kitDisabledOpacity]);
    final firstBox = tester.getSize(
      find.ancestor(of: glyphs.first, matching: find.byType(Container)).first,
    );
    expect(firstBox, const Size(18, 13));
  });
}

void _noop() {}
