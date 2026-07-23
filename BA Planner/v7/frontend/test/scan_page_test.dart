import 'dart:async';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _subject(
  MockAppService service, {
  void Function(ScannerSession, ScannerCandidate)? onHandoff,
  ValueChanged<List<ScannerRecentSummary>>? onRecentChanged,
}) => MaterialApp(
  home: Scaffold(
    body: ScanPage(
      service: service,
      onCandidateHandoff: onHandoff ?? (_, _) {},
      onRecentChanged: onRecentChanged,
    ),
  ),
);

Future<void> _selectTarget(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(const ValueKey('scan-target')));
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('· $id').last);
  await tester.pumpAndSettle();
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final page = find.byKey(const ValueKey('scan-page'));
  for (
    var attempt = 0;
    finder.evaluate().isEmpty && attempt < 30;
    attempt += 1
  ) {
    await tester.drag(page, const Offset(0, -300));
    await tester.pump();
  }
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
}

void main() {
  testWidgets('loading, empty, error, disconnected and refresh are distinct', (
    tester,
  ) async {
    final defaults = MockAppService();
    final service = _RefreshErrorService(
      initialState: defaults.state.value.copyWith(
        connection: BackendConnection.disconnected,
      ),
    );
    await defaults.dispose();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('Backend disconnected'), findsOneWidget);
    expect(find.textContaining('No game windows were found'), findsOneWidget);

    service.fail = true;
    await tester.tap(find.byKey(const ValueKey('scan-refresh')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Readiness failed'), findsOneWidget);
    expect(find.textContaining('Target list failed'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start scan'),
    );
    expect(start.onPressed, isNull);
  });

  testWidgets('preparation keeps stable target IDs and blocks non-ready target', (
    tester,
  ) async {
    final service = MockAppService(
      scannerTargets: const [
        ScannerTarget(
          id: 'same-minimized',
          title: 'Same title',
          status: ScannerTargetStatus.minimized,
        ),
        ScannerTarget(
          id: 'same-ready',
          title: 'Same title',
          status: ScannerTargetStatus.ready,
          foreground: true,
        ),
      ],
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('scan-page')), findsOneWidget);
    expect(find.textContaining('Manifest 1'), findsOneWidget);
    await _selectTarget(tester, 'same-minimized');
    var start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start scan'),
    );
    expect(start.onPressed, isNull);
    expect(find.textContaining('choose a ready target'), findsOneWidget);

    await _selectTarget(tester, 'same-ready');
    start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start scan'),
    );
    expect(start.onPressed, isNotNull);
    expect(find.textContaining('foreground'), findsOneWidget);
  });

  testWidgets('projects deterministic candidate and hands it to the data owner', (
    tester,
  ) async {
    final service = MockAppService(
      scannerScenario: MockScannerScenario.reviewRequired,
    );
    addTearDown(service.dispose);
    ScannerCandidate? handedOff;
    await tester.pumpWidget(
      _subject(service, onHandoff: (_, candidate) => handedOff = candidate),
    );
    await tester.pumpAndSettle();
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump(const Duration(milliseconds: 35));

    expect(find.textContaining('Outcome: completed'), findsOneWidget);
    expect(find.text('Review required'), findsOneWidget);
    expect(find.textContaining('62.0%'), findsOneWidget);
    final review = find.byKey(const ValueKey('scan-review-mock-candidate-1'));
    await _reveal(tester, review);
    await tester.tap(review);
    expect(handedOff?.kind, ScannerKind.student);
    expect(handedOff?.payload['student_id'], 'aru');
  });

  testWidgets('publishes an immutable typed terminal recent projection', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    List<ScannerRecentSummary>? recent;
    await tester.pumpWidget(
      _subject(service, onRecentChanged: (value) => recent = value),
    );
    await tester.pumpAndSettle();
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump(const Duration(milliseconds: 35));

    expect(recent, isNotNull);
    expect(recent, hasLength(1));
    expect(recent!.single.kind, ScannerKind.student);
    expect(recent!.single.outcome, 'completed');
    expect(recent!.single.candidateCount, 1);
    expect(
      () => recent!.add(recent!.single),
      throwsUnsupportedError,
    );
  });

  testWidgets('cancel acknowledgement remains cancelling until terminal and retry is new', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scan-cancel')));
    await tester.pump();
    expect(find.text('Cancelling…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.textContaining('Outcome: cancelled'), findsOneWidget);

    final retry = find.byKey(const ValueKey('scan-retry'));
    await _reveal(tester, retry);
    await tester.tap(retry);
    await tester.pump();
    expect(find.textContaining('generation 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 35));
  });

  testWidgets('stream error recovers authoritative snapshot without direct commit', (
    tester,
  ) async {
    final service = _SnapshotMockService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump();
    service.emitGap();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Outcome: completed'), findsOneWidget);
    await _reveal(tester, find.textContaining('Recent sessions in this app run'));
    await _reveal(tester, find.textContaining('Candidate snapshot-candidate'));
  });

  testWidgets('candidate kind and payload mismatch is not handed off', (
    tester,
  ) async {
    final service = _SnapshotMockService(mismatch: true);
    addTearDown(service.dispose);
    var handoffCount = 0;
    await tester.pumpWidget(
      _subject(service, onHandoff: (_, _) => handoffCount += 1),
    );
    await tester.pumpAndSettle();
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump();
    service.emitGap();
    await tester.pump();
    await tester.pump();
    final review = find.byKey(const ValueKey('scan-review-snapshot-candidate'));
    await _reveal(tester, review);
    await tester.tap(review);
    await tester.pump();
    expect(handoffCount, 0);
    expect(find.textContaining('Candidate kind or payload mismatch'), findsOneWidget);
  });

  for (final size in const [Size(1280, 720), Size(1440, 900), Size(1280, 960)]) {
    testWidgets('scan controls remain reachable at ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = MockAppService(
        scannerTargets: const [
          ScannerTarget(
            id: 'long-ready-target',
            title:
                'Blue Archive window with a deliberately very long target title for layout verification',
            status: ScannerTargetStatus.ready,
          ),
        ],
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(_subject(service));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('scan-start')), findsOneWidget);
      expect(find.byKey(const ValueKey('scan-refresh')), findsOneWidget);
    });
  }
}

class _SnapshotMockService extends MockAppService {
  _SnapshotMockService({this.mismatch = false});

  final bool mismatch;
  final StreamController<ScannerEvent> _events = StreamController.broadcast();

  @override
  Stream<ScannerEvent> get scannerEvents => _events.stream;

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId,
  ) async {
    return ScannerSession(id: 'snapshot-session', generation: 1, kind: kind);
  }

  void emitGap() => _events.addError(StateError('sequence gap'));

  @override
  Future<ScannerSessionSnapshot> scannerSnapshot(ScannerSession session) async {
    final candidateKind = mismatch ? ScannerKind.inventory : session.kind;
    final candidate = ScannerCandidate(
      id: 'snapshot-candidate',
      sessionId: session.id,
      generation: session.generation,
      revision: 1,
      kind: candidateKind,
      payload: mismatch
          ? const {'version': 1, 'entries': <dynamic>[]}
          : const {
              'version': 1,
              'student_id': 'aru',
              'values': {'level': 90},
            },
      evidence: const [
        ScannerFieldEvidence(
          field: 'level',
          status: 'ok',
          source: 'snapshot',
          confidence: 0.99,
        ),
      ],
      reviewRequired: false,
      approved: false,
    );
    ScannerEvent event(
      int sequence,
      ScannerEventKind kind,
      Map<String, dynamic> payload,
    ) => ScannerEvent(
      sessionId: session.id,
      generation: session.generation,
      sequence: sequence,
      kind: session.kind,
      eventKind: kind,
      payload: {
        'session_id': session.id,
        'generation': session.generation,
        'sequence': sequence,
        'scan_kind': session.kind.name,
        'event_kind': kind.name,
        ...payload,
      },
    );
    return ScannerSessionSnapshot(
      sessionId: session.id,
      generation: session.generation,
      kind: session.kind,
      lastSequence: 3,
      terminal: 'completed',
      events: [
        event(1, ScannerEventKind.phase, {'phase': 'capturing'}),
        event(2, ScannerEventKind.candidate, {'candidate': _wire(candidate)}),
        event(3, ScannerEventKind.terminal, {'outcome': 'completed'}),
      ],
      candidates: [candidate],
    );
  }

  Map<String, dynamic> _wire(ScannerCandidate candidate) => {
    'candidate_id': candidate.id,
    'session_id': candidate.sessionId,
    'generation': candidate.generation,
    'revision': candidate.revision,
    'scan_kind': candidate.kind.name,
    'payload': candidate.payload,
    'evidence': [
      for (final item in candidate.evidence)
        {
          'field': item.field,
          'status': item.status,
          'source': item.source,
          'confidence': item.confidence,
          'note': item.note,
        },
    ],
    'review_required': candidate.reviewRequired,
    'approved': candidate.approved,
    'audit': <dynamic>[],
  };

  @override
  Future<void> dispose() async {
    await _events.close();
    await super.dispose();
  }
}

class _RefreshErrorService extends MockAppService {
  _RefreshErrorService({required AppServiceState initialState})
    : super(initialState: initialState, scannerTargets: const []);

  bool fail = false;

  @override
  Future<List<ScannerTarget>> listScannerTargets() async {
    if (fail) throw StateError('target refresh failed');
    return const [];
  }

  @override
  Future<Map<String, dynamic>> scannerReadiness() async {
    if (fail) throw StateError('readiness refresh failed');
    return super.scannerReadiness();
  }
}
