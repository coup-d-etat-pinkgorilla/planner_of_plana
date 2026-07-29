import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/app_section.dart';
import 'package:ba_planner_v7/ui/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _subject(
  MockAppService service, {
  ValueChanged<AppSection>? onOpen,
  Animation<double> entranceAnimation = const AlwaysStoppedAnimation(1),
}) => MaterialApp(
  home: Scaffold(
    body: HomePage(
      service: service,
      onOpen: onOpen ?? (_) {},
      entranceAnimation: entranceAnimation,
    ),
  ),
);

void main() {
  testWidgets('home contains only the menu section', (tester) async {
    final service = MockAppService();
    addTearDown(service.dispose);

    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-review-needed')), findsNothing);
    expect(find.byKey(const ValueKey('home-profile-summary')), findsNothing);
    expect(find.byKey(const ValueKey('home-quick-launchers')), findsNothing);
    expect(find.byKey(const ValueKey('home-recent-scans')), findsNothing);
  });

  testWidgets('menu cards route to every primary destination', (tester) async {
    final opened = <AppSection>[];
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, onOpen: opened.add));
    await tester.pumpAndSettle();

    for (final section in const [
      AppSection.scan,
      AppSection.students,
      AppSection.plan,
      AppSection.inventory,
      AppSection.pvp,
      AppSection.statistics,
      AppSection.settings,
    ]) {
      await tester.tap(find.byKey(ValueKey('home-menu-${section.name}')));
    }

    expect(opened, [
      AppSection.scan,
      AppSection.students,
      AppSection.plan,
      AppSection.inventory,
      AppSection.pvp,
      AppSection.statistics,
      AppSection.settings,
    ]);
  });

  for (final size in const [
    Size(1280, 720),
    Size(1440, 900),
    Size(1280, 960),
  ]) {
    testWidgets('menu remains scrollable at ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService();
      addTearDown(service.dispose);

      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  }
}
