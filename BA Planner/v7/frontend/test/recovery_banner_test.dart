import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/widgets/recovery_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('global recovery shows only valid owner actions', (tester) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    service.setConnection(BackendConnection.disconnected);
    var settings = 0, scan = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecoveryBanner(
            service: service,
            onOpenSettings: () => settings++,
            onOpenScan: () => scan++,
          ),
        ),
      ),
    );
    expect(find.text('재연결'), findsOneWidget);
    expect(find.text('Backend 재시작'), findsOneWidget);
    await tester.tap(find.text('설정 열기'));
    await tester.pump();
    expect(settings, 1);
    expect(scan, 0);
  });

  testWidgets('scan failure routes to scan without mutating candidate', (
    tester,
  ) async {
    final initial = const AppServiceState(
      connection: BackendConnection.connected,
      scanPhase: ScanPhase.failed,
      imageLoadState: ImageLoadState.loaded,
      studentCount: 0,
      inventoryItemCount: 0,
      hasData: false,
      scanAvailable: true,
      useLongNames: false,
      hasMissingMetadata: false,
    );
    final service = MockAppService(initialState: initial);
    addTearDown(service.dispose);
    var scan = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecoveryBanner(
            service: service,
            onOpenSettings: () {},
            onOpenScan: () => scan++,
          ),
        ),
      ),
    );
    expect(find.text('스캔 열기'), findsOneWidget);
    await tester.tap(find.text('스캔 열기'));
    await tester.pump();
    expect(scan, 1);
    expect(service.state.value.scanPhase, ScanPhase.failed);
  });
}
