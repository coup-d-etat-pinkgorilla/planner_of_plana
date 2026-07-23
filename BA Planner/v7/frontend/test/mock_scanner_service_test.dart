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
      expect(event.sequence, 4);
      expect(event.payload['outcome'], 'completed');
      expect(service.state.value.scanPhase, ScanPhase.succeeded);
      await service.dispose();
    },
  );

  test('MockAppService exposes deterministic inventory unknown evidence', () async {
    final service = MockAppService(
      scannerScenario: MockScannerScenario.inventoryUnknown,
    );
    final events = <ScannerEvent>[];
    final subscription = service.scannerEvents.listen(events.add);
    final session = await service.startScannerSession(
      ScannerKind.inventory,
      'mock-window',
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final candidateEvent = events.singleWhere(
      (event) => event.eventKind == ScannerEventKind.candidate,
    );
    final candidate = ScannerCandidate.fromWire(
      Map<String, dynamic>.from(candidateEvent.payload['candidate'] as Map),
    );
    expect(candidate.kind, ScannerKind.inventory);
    expect(candidate.reviewRequired, isTrue);
    expect((candidate.payload['entries'] as List).single['quantity'], isNull);
    final snapshot = await service.scannerSnapshot(session);
    expect(snapshot.terminal, 'completed');
    expect(snapshot.candidates.single.id, candidate.id);
    await subscription.cancel();
    await service.dispose();
  });

  test('MockAppService keeps cancel acknowledgement separate from terminal', () async {
    final service = MockAppService();
    final terminal = service.scannerEvents.firstWhere(
      (event) => event.eventKind == ScannerEventKind.terminal,
    );
    final session = await service.startScannerSession(
      ScannerKind.student,
      'mock-window',
    );
    final acknowledgement = await service.cancelScannerSession(session);
    expect(acknowledgement['accepted'], isTrue);
    expect(acknowledgement['terminal'], isNull);
    expect((await terminal).payload['outcome'], 'cancelled');
    await service.dispose();
  });

  test('MockAppService emits a structured failed terminal', () async {
    final service = MockAppService(scannerScenario: MockScannerScenario.failed);
    final terminal = service.scannerEvents.firstWhere(
      (event) => event.eventKind == ScannerEventKind.terminal,
    );
    await service.startScannerSession(ScannerKind.student, 'mock-window');
    final event = await terminal;
    expect(event.payload['outcome'], 'failed');
    expect((event.payload['error'] as Map)['code'], 'mock_failure');
    await service.dispose();
  });
}
