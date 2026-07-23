import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget subject(
  MockAppService service, {
  VoidCallback? onScan,
  VoidCallback? onDiagnostics,
  VoidCallback? onProfileChanged,
}) => MaterialApp(
  home: Scaffold(
    body: SettingsPage(
      service: service,
      onOpenScan: onScan ?? () {},
      onOpenDiagnostics: onDiagnostics ?? () {},
      onProfileChanged: onProfileChanged ?? () {},
      onRecoveryCompleted: () {},
    ),
  ),
);

void main() {
  for (final size in const [
    Size(1280, 720),
    Size(1440, 900),
    Size(1280, 960),
  ]) {
    testWidgets('settings populated layout fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MockAppService();
      addTearDown(service.dispose);
      await tester.pumpWidget(subject(service));
      await tester.pumpAndSettle();
      expect(find.text('프로필과 연결'), findsOneWidget);
      expect(find.text('Main'), findsOneWidget);
      expect(find.text('스캔 탭 열기'), findsOneWidget);
      expect(find.text('Adaptive-Sync'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'settings disconnected long-text layout fits ${size.width}x${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = MockAppService();
        addTearDown(service.dispose);
        final profile = (await service.listProfiles()).single;
        const longName =
            'A deliberately long profile name for disconnected recovery layout verification';
        await service.renameProfile(
          profile.id,
          longName,
          profile.revision,
          'settings-long-profile',
        );
        await tester.pumpWidget(subject(service));
        await tester.pumpAndSettle();
        service.setConnection(BackendConnection.disconnected);
        await tester.pump();
        expect(find.text(longName), findsOneWidget);
        expect(find.text('재연결'), findsOneWidget);
        expect(find.text('Backend 재시작'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('create select rename and revision failure reload safely', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    var changes = 0;
    await tester.pumpWidget(
      subject(service, onProfileChanged: () => changes++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 프로필'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Second');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    expect(changes, 1);
    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Renamed');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('Renamed'), findsOneWidget);
    service.failNextProfileMutation = true;
    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Conflict');
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('revision_conflict'), findsOneWidget);
    expect(find.text('Renamed'), findsOneWidget);
  });

  testWidgets(
    'scanner and Adaptive-Sync are deep links and do not start scan',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      var scan = 0, diagnostics = 0;
      await tester.pumpWidget(
        subject(
          service,
          onScan: () => scan++,
          onDiagnostics: () => diagnostics++,
        ),
      );
      await tester.pumpAndSettle();
      final settingsScroll = find.byKey(const ValueKey('settings-scroll'));
      final openScan = find.text('스캔 탭 열기');
      await tester.drag(settingsScroll, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(openScan);
      await tester.pump();
      final openAdaptiveSync = find.text('Adaptive-Sync');
      await tester.drag(settingsScroll, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(openAdaptiveSync);
      await tester.pump();
      expect(scan, 1);
      expect(diagnostics, 1);
      expect(service.state.value.scanPhase, ScanPhase.idle);
    },
  );

  testWidgets('disconnected recovery failure remains actionable', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    service.setConnection(BackendConnection.disconnected);
    service.failNextReconnect = true;
    await tester.pumpWidget(subject(service));
    await tester.pump();
    await tester.tap(find.text('재연결'));
    await tester.pumpAndSettle();
    expect(find.textContaining('mock reconnect failed'), findsOneWidget);
    expect(find.text('재연결'), findsOneWidget);
  });
}
