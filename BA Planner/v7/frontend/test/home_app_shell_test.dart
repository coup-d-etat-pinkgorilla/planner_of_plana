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
  testWidgets('AppShell keeps candidate on Hold and clears Home after commit', (
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
    final review = find.byKey(const ValueKey('scan-review-mock-candidate-1'));
    await _reveal(tester, find.byKey(const ValueKey('scan-page')), review);
    await tester.tap(review);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('top-tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-pending-student')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-recent-scans')), findsOneWidget);

    var pending = find.byKey(const ValueKey('home-pending-student'));
    await tester.ensureVisible(pending);
    await tester.pump();
    await tester.tap(pending);
    await tester.pumpAndSettle();
    expect(
      tester.widget<StudentPage>(find.byType(StudentPage)).candidateContext,
      isNotNull,
    );
    final hold = find.byKey(const ValueKey('candidate-hold'));
    await _reveal(tester, find.byKey(const ValueKey('student-page')), hold);
    await tester.tap(hold);
    await tester.tap(find.byKey(const ValueKey('top-tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-pending-student')), findsOneWidget);

    pending = find.byKey(const ValueKey('home-pending-student'));
    await tester.ensureVisible(pending);
    await tester.pump();
    await tester.tap(pending);
    await tester.pumpAndSettle();
    final approve = find.byKey(const ValueKey('candidate-approve'));
    await _reveal(tester, find.byKey(const ValueKey('student-page')), approve);
    await tester.tap(approve);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-pending-student')), findsNothing);
  });
}
