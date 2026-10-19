// FE2-c UI Kit 갤러리 구역 테스트: 시안 `.open` 견본이 열린 채로 그려지고, 프리셋 견본이 열리고,
// 모달 스크림 프리셋을 열어 볼 수 있다.
// OverlayPortal을 쓰는 견본이 있어 견본을 연 뒤에는 pumpAndSettle 대신 pump한다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/ba_modal.dart';
import 'package:ba_planner_v7/ui/kit/gallery/ui_kit_gallery_page.dart';
import 'package:ba_planner_v7/ui/kit/info_popover.dart';
import 'package:ba_planner_v7/ui/kit/kit_overlay.dart';
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

void main() {
  testWidgets('FE2-c tiles render and the .open samples start open', (
    tester,
  ) async {
    await _pumpGallery(tester);
    for (final tile in ['info', 'modal', 'layout', 'presets']) {
      await _show(tester, 'kit-gallery-fe2c-$tile');
      expect(
        find.byKey(ValueKey('kit-gallery-fe2c-$tile')),
        findsOneWidget,
        reason: tile,
      );
    }
    await _show(tester, 'kit-gallery-fe2c-info');
    // 시안 `.open` 견본: (i) 3개 · 부족 재화 · 페이즈.
    expect(find.text('단계 순서 정하는 법'), findsOneWidget);
    expect(find.text('카드를 끌어 칸을 옮깁니다.'), findsOneWidget);
    expect(find.text('넣을 단계'), findsNWidgets(2));
    expect(find.text('위험도'), findsOneWidget);
    expect(find.text('부족 재화 5종'), findsOneWidget);
    expect(find.text('필요 재화'), findsOneWidget);
    // 닫힌 견본은 닫혀 있다.
    expect(find.text('부족 재화 8종'), findsNothing);
    expect(find.byType(KitOverlayPanel), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('closed samples open on tap; outside tap closes them', (
    tester,
  ) async {
    await _pumpGallery(tester);
    await _show(tester, 'kit-gallery-info-closed');
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('kit-gallery-info-closed')),
        matching: find.byType(InfoButton),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('탭에 놓입니다.', findRichText: true),
      findsOneWidget,
    );
    // 바깥을 눌렀으므로 시안 `.open` 견본은 닫혔다.
    expect(find.text('카드를 끌어 칸을 옮깁니다.'), findsNothing);
    expect(find.byType(KitOverlayPanel), findsOneWidget);

    for (final key in [
      'kit-gallery-flyout-scenario',
      'kit-gallery-flyout-stats-dot',
      'kit-gallery-flyout-down',
      'kit-gallery-flyout-down-left',
    ]) {
      await _show(tester, key);
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: key);
    }
    // 마지막으로 연 것만 열려 있다(같은 그룹).
    expect(find.text('A 유저 · 23위 · 최근 방어 덱 5종'), findsOneWidget);
    expect(find.text('밀레니엄 · 계획 학생 5명'), findsNothing);
    expect(find.text('부족 재화 8종'), findsNothing);
  });

  testWidgets('reopen button restores the .open samples', (tester) async {
    await _pumpGallery(tester);
    await _show(tester, 'kit-gallery-fe2c-reopen');
    // 앱 바(누를 것이 없는 자리)를 누르면 열린 견본이 모두 닫힌다.
    await tester.tapAt(const Offset(1280, 28));
    await tester.pump();
    expect(find.byType(KitOverlayPanel), findsNothing);
    await tester.tap(find.byKey(const ValueKey('kit-gallery-fe2c-reopen')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(KitOverlayPanel), findsNWidgets(5));
  });

  testWidgets('modal buttons open each scrim preset', (tester) async {
    await _pumpGallery(tester);
    for (final scrim in BaScrim.values) {
      final button = find.byKey(ValueKey('kit-gallery-modal-${scrim.name}'));
      await _show(tester, 'kit-gallery-modal-${scrim.name}');
      await tester.tap(button);
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<ColoredBox>(find.byKey(BaModal.scrimKey)).color,
        scrim.color,
        reason: scrim.name,
      );
      await tester.tap(
        find.byKey(ValueKey('kit-gallery-modal-close-${scrim.name}')),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(BaModal.scrimKey), findsNothing, reason: scrim.name);
    }
    expect(tester.takeException(), isNull);
  });
}
