import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'MockAppService exposes the scanner readiness and terminal flow',
    () async {
      final service = MockAppService();
      final terminal = service.scannerEvents.firstWhere(
        (event) => event.eventKind == ScannerEventKind.terminal,
      );

      expect((await service.scannerReadiness())['ready'], isTrue);
      expect(await service.listScannerTargets(), hasLength(1));
      await service.startScan();

      final event = await terminal;
      expect(event.sequence, 1);
      expect(event.payload['outcome'], 'completed');
      expect(service.state.value.scanPhase, ScanPhase.succeeded);
      await service.dispose();
    },
  );
}
