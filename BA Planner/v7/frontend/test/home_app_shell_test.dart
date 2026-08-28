import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/pages/student_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _reveal(
  WidgetTester tester,
  Finder scrollable,
  Finder target,
) async {
  final scrollableState = tester.state<ScrollableState>(
    find.descendant(of: scrollable, matching: find.byType(Scrollable)).first,
  );
  for (var attempt = 0; target.evaluate().isEmpty && attempt < 4; attempt++) {
    scrollableState.position.jumpTo(scrollableState.position.maxScrollExtent);
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
}

void main() {
  testWidgets('AppShell keeps a held student candidate in the scan workspace', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MockAppService(
      scannerScenario: MockScannerScenario.reviewRequired,
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-target')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('mock-window').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump(const Duration(milliseconds: 35));
    final hold = find.byKey(
      const ValueKey('scan-student-hold-mock-candidate-1'),
    );
    await _reveal(tester, find.byKey(const ValueKey('scan-page')), hold);
    await tester.tap(hold);
    await tester.pump();
    expect(find.textContaining('보류했습니다'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('top-tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-pending-student')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('top-tab-students')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<StudentPage>(find.byType(StudentPage)).candidateContext,
      isNull,
    );
  });
}
