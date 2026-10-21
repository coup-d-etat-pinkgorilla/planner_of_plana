import 'package:ba_planner_v7/app/app.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures/f3d_seeded_account.dart';

void main() {
  testWidgets('AppShell keeps a held student candidate in the scan review', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = F3dScannedMockAppService(
      scannerScenario: MockScannerScenario.reviewRequired,
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(BAPlannerApp(service: service));
    await tester.pumpAndSettle();

    // 스캔 탭(FE8-g1): 미연결이면 창 선택 패널에서 창을 고르고, `지금 화면 1명`을 골라 시작한다.
    await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('home-connect-panel-row-mock-window')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('home-connect-panel-use')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('scan-pick-student-single')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scan-pick-start')));
    await tester.pump(const Duration(milliseconds: 35));
    await tester.pump();
    // 끝난 학생 결과는 학생 결과 검토 보드(FE8-g4b): 확인 필요 행의 `보류`.
    expect(find.byKey(const ValueKey('scan-review')), findsOneWidget);
    final hold = find.byKey(
      const ValueKey('scan-review-hold-mock-candidate-1'),
    );
    expect(hold, findsOneWidget);
    await tester.tap(hold);
    await tester.pump();
    expect(find.textContaining('보류했습니다'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('top-tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-menu-section')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-pending-student')), findsNothing);

    // 학생 탭으로 후보를 넘기는 길은 없다(FE8-g5b, I-scan §9.1 인계 제거): 보류한 후보는 스캔 탭 보드에 그대로 남는다.
    await tester.tap(find.byKey(const ValueKey('top-tab-students')));
    await tester.pumpAndSettle();
    expect(find.text('Delivered scan candidate'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('top-tab-scan')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('scan-review')), findsOneWidget);
    expect(hold, findsOneWidget);
  });
}
