// FE2-c 모달 테스트: 스크림 프리셋 알파(FD-013), 열고 닫기(Esc·스크림), 포커스 이동·복귀, 패널 모양.
// OverlayPortal을 쓰므로 pumpAndSettle 대신 필요한 만큼만 pump한다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/ba_modal.dart';
import 'package:ba_planner_v7/ui/kit/kit_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BaModalController> _pumpModal(
  WidgetTester tester, {
  BaScrim scrim = BaScrim.anchored,
  bool barrierDismissible = true,
}) async {
  final controller = BaModalController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: Center(
          child: BaModal(
            controller: controller,
            scrim: scrim,
            label: '족보 전체',
            barrierDismissible: barrierDismissible,
            builder: (context) => BaModalPanel.dialog(
              width: 400,
              child: TextButton(
                onPressed: controller.close,
                child: const Text('닫기'),
              ),
            ),
            child: ElevatedButton(
              onPressed: controller.open,
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

ColoredBox _scrim(WidgetTester tester) =>
    tester.widget<ColoredBox>(find.byKey(BaModal.scrimKey));

void main() {
  test('scrim presets keep the four prototype values', () {
    void expectScrim(BaScrim scrim, (int, int, int) rgb, double alpha, double blur) {
      final color = scrim.color;
      expect((color.r * 255).round(), rgb.$1, reason: scrim.name);
      expect((color.g * 255).round(), rgb.$2, reason: scrim.name);
      expect((color.b * 255).round(), rgb.$3, reason: scrim.name);
      expect(color.a, closeTo(alpha, 0.005), reason: scrim.name);
      expect(scrim.blur, blur, reason: scrim.name);
    }

    expectScrim(BaScrim.filter, (6, 10, 16), 0.8, 2);
    expectScrim(BaScrim.scan, (6, 10, 16), 0.72, 2);
    expectScrim(BaScrim.excel, (5, 9, 14), 0.62, 0);
    expectScrim(BaScrim.anchored, (6, 10, 16), 0.35, 0);
    // 통일하지 않는다.
    expect(BaScrim.values.map((scrim) => scrim.color).toSet(), hasLength(4));
  });

  testWidgets('opens with the preset scrim; blur only where the preset has it', (
    tester,
  ) async {
    for (final scrim in BaScrim.values) {
      final controller = await _pumpModal(tester, scrim: scrim);
      expect(find.byKey(BaModal.scrimKey), findsNothing);
      controller.open();
      await tester.pump();
      expect(_scrim(tester).color, scrim.color, reason: scrim.name);
      expect(
        find.ancestor(
          of: find.byKey(BaModal.scrimKey),
          matching: find.byType(BackdropFilter),
        ),
        scrim.blur > 0 ? findsOneWidget : findsNothing,
        reason: scrim.name,
      );
      controller.close();
      await tester.pump();
      expect(find.byKey(BaModal.scrimKey), findsNothing);
    }
  });

  testWidgets('scrim tap and Esc close; focus moves in and back', (
    tester,
  ) async {
    final controller = await _pumpModal(tester);
    // 연 버튼에 포커스를 두고 연다.
    Focus.of(tester.element(find.text('열기'))).requestFocus();
    await tester.pump();
    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump();
    expect(controller.isOpen, isTrue);
    final scope = tester.widget<FocusScope>(
      find
          .ancestor(
            of: find.byType(BaModalPanel),
            matching: find.byType(FocusScope),
          )
          .first,
    );
    expect(scope.focusNode!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();
    expect(controller.isOpen, isFalse);
    expect(find.text('닫기'), findsNothing);
    expect(KitOverlayEscape.hasEntries, isFalse);
    expect(Focus.of(tester.element(find.text('열기'))).hasPrimaryFocus, isTrue);

    controller.open();
    await tester.pump();
    // 패널 안을 누르면 닫지 않고, 스크림을 누르면 닫는다.
    await tester.tapAt(
      tester.getTopLeft(find.byType(BaModalPanel)) + const Offset(4, 4),
    );
    await tester.pump();
    expect(controller.isOpen, isTrue);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(controller.isOpen, isFalse);
  });

  testWidgets('barrierDismissible false keeps it open on scrim tap', (
    tester,
  ) async {
    final controller = await _pumpModal(tester, barrierDismissible: false);
    controller.open();
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(controller.isOpen, isTrue);
    await tester.tap(find.text('닫기'));
    await tester.pump();
    expect(controller.isOpen, isFalse);
  });

  testWidgets('panel presets follow the prototype dialogs', (tester) async {
    final controller = await _pumpModal(tester);
    controller.open();
    await tester.pump();
    final panel = tester.widget<KitOverlayPanel>(find.byType(KitOverlayPanel));
    expect(panel.color, AppColors.popover);
    expect(panel.radius, 12);
    expect(panel.padding, const EdgeInsets.fromLTRB(18, 16, 18, 14));
    expect(panel.shadows!.first.color, kitOverlayRingColor);
    final offCenter =
        tester.getCenter(find.byType(KitOverlayPanel)) -
        tester.getCenter(find.byType(Scaffold));
    expect(offCenter.distance, lessThan(0.01));

    const sheet = BaModalPanel.sheet(child: SizedBox());
    expect(sheet.color, const Color(0xff0f1822));
    expect(sheet.radius, 14);
    expect(sheet.padding, const EdgeInsets.symmetric(horizontal: 28, vertical: 24));
  });
}
