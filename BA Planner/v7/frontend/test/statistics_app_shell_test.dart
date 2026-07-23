// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('statistics tab is service-backed and reloads on re-entry', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.tap(find.byKey(const ValueKey('top-tab-statistics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('statistics-page')), findsOneWidget);
    expect(find.text('Profile statistics'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('top-tab-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-tab-statistics')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('statistics-page')), findsOneWidget);
  });
}
