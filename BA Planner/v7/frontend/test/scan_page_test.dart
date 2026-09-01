import 'dart:async';
import 'dart:convert';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/student_scan_diagnostic.dart';
import 'package:ba_planner_v7/services/window_dock_service.dart';
import 'package:ba_planner_v7/ui/widgets/scan_companion_dock.dart';
import 'package:ba_planner_v7/ui/pages/scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _subject(
  MockAppService service, {
  void Function(ScannerSession, ScannerCandidate)? onHandoff,
  ValueChanged<List<ScannerRecentSummary>>? onRecentChanged,
  ValueChanged<ScanCompanionState?>? onCompanionChanged,
  WindowDockService windowDockService = const WindowsWindowDockService(),
  StudentScanDiagnosticFileService studentScanDiagnosticFileService =
      const NativeStudentScanDiagnosticFileService(),
  DateTime Function() now = DateTime.now,
}) => MaterialApp(
  home: Scaffold(
    body: ScanPage(
      service: service,
      onCandidateHandoff: onHandoff ?? (_, _) {},
      onRecentChanged: onRecentChanged,
      onCompanionChanged: onCompanionChanged,
      windowDockService: windowDockService,
      studentScanDiagnosticFileService: studentScanDiagnosticFileService,
      now: now,
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
  testWidgets(
    'completed student scan exports a privacy-limited diagnostic JSON',
    (tester) async {
      final service = MockAppService();
      final files = _RecordingStudentScanDiagnosticFileService();
      addTearDown(service.dispose);
      await tester.pumpWidget(
        _subject(
          service,
          studentScanDiagnosticFileService: files,
          now: () => DateTime.utc(2026, 8, 28, 12, 34, 56),
        ),
      );
      await tester.pumpAndSettle();
      await _selectTarget(tester, 'mock-window');
      await tester.tap(find.byKey(const ValueKey('scan-start')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      final export = find.byKey(
        const ValueKey('scan-export-student-diagnostic'),
      );
      await _reveal(tester, export);
      expect(tester.widget<OutlinedButton>(export).onPressed, isNotNull);
      await tester.tap(export);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(files.suggestedName, contains('2026-08-28T12-34-56.000Z-single'));
      final document = jsonDecode(files.contents!) as Map<String, dynamic>;
      expect(document['format'], studentScanDiagnosticFormat);
      expect(document['privacy'], {
        'account_name_included': false,
        'window_title_included': false,
        'images_included': false,
      });
      expect(document['candidates'], isNotEmpty);
      expect(files.contents, isNot(contains('Mock Blue Archive')));
      expect(files.contents, isNot(contains('"Main"')));
    },
  );

  testWidgets('full student scan docks before start and restores on terminal', (
    tester,
  ) async {
    final service = MockAppService();
    final dock = _RecordingWindowDockService();
    final companions = <ScanCompanionState?>[];
    addTearDown(service.dispose);
    await tester.pumpWidget(
      _subject(
        service,
        windowDockService: dock,
        onCompanionChanged: companions.add,
      ),
    );
    await tester.pumpAndSettle();
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.text('전체'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump();

    expect(dock.dockedTargets, ['mock-window']);
    expect(dock.restoreCalls, 0);
    expect(companions.whereType<ScanCompanionState>(), isNotEmpty);

    await tester.pump(const Duration(milliseconds: 35));
    expect(dock.restoreCalls, 1);
    expect(companions.last, isNull);
  });

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

  testWidgets(
    'preparation keeps stable target IDs and blocks non-ready target',
    (tester) async {
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
    },
  );

  testWidgets(
    'student problem result stays in scan workspace and revalidates green',
    (tester) async {
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
      final revalidate = find.byKey(
        const ValueKey('scan-student-revalidate-mock-candidate-1'),
      );
      await _reveal(tester, revalidate);
      expect(
        tester.getTopLeft(revalidate).dy,
        lessThan(tester.getTopLeft(find.text('현재 확정값 / 스캔값 / 계산값 / 차이')).dy),
      );
      await tester.tap(find.text('상세 증거'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('다른 의상 인연 보너스 검증'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('relationship-contribution-10000')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('relationship-contribution-10031')),
        findsOneWidget,
      );
      expect(find.text('인연 20'), findsOneWidget);
      expect(find.text('인연 10'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '문제 있는 스캔 결과',
        ),
        findsWidgets,
      );
      expect(find.text('수정'), findsOneWidget);
      expect(find.text('재검증'), findsOneWidget);
      expect(find.text('보류'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('scan-student-apply-mock-candidate-1')),
        findsNothing,
      );
      await tester.tap(revalidate);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '문제 없는 스캔 결과',
        ),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('scan-student-apply-mock-candidate-1')),
        findsOneWidget,
      );
      expect(handedOff, isNull);
    },
  );

  testWidgets('green result applies in scan tab and discard is confirmed', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump(const Duration(milliseconds: 35));

    final apply = find.byKey(
      const ValueKey('scan-student-apply-mock-candidate-1'),
    );
    await _reveal(tester, apply);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '문제 없는 스캔 결과',
      ),
      findsWidgets,
    );
    await tester.tap(apply);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('repository revision'), findsOneWidget);
    expect(apply, findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('scan-retry')));
    await tester.pump(const Duration(milliseconds: 35));
    final more = find.byKey(
      const ValueKey('scan-student-more-mock-candidate-2'),
    );
    await _reveal(tester, more);
    final overflow = tester.widget<PopupMenuButton<String>>(more);
    overflow.onSelected!('discard');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('확정된 현재값은 변경되지 않습니다'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('scan-student-discard-confirm')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('후보를 폐기했습니다'), findsOneWidget);
  });

  testWidgets('apply conflict returns red and recovers through revalidation', (
    tester,
  ) async {
    final service = MockAppService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    final profile = (await service.listProfiles()).single;
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump(const Duration(milliseconds: 35));

    await service.saveRepositoryGoals(
      profile.id,
      const {'version': 1, 'goals': <dynamic>[]},
      0,
      'concurrent-scan-test-update',
    );
    final apply = find.byKey(
      const ValueKey('scan-student-apply-mock-candidate-1'),
    );
    await _reveal(tester, apply);
    await tester.tap(apply);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('적용 실패'), findsWidgets);
    expect(apply, findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '문제 있는 스캔 결과',
      ),
      findsWidgets,
    );

    final revalidate = find.byKey(
      const ValueKey('scan-student-revalidate-mock-candidate-1'),
    );
    await tester.tap(revalidate);
    await tester.pump(const Duration(milliseconds: 100));
    expect(apply, findsOneWidget);
    await tester.tap(apply);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('repository revision 2'), findsOneWidget);
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
    expect(() => recent!.add(recent!.single), throwsUnsupportedError);
  });

  testWidgets(
    'cancel acknowledgement remains cancelling until terminal and retry is new',
    (tester) async {
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
    },
  );

  testWidgets(
    'stream error recovers authoritative snapshot without direct commit',
    (tester) async {
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
      await _reveal(
        tester,
        find.textContaining('Recent sessions in this app run'),
      );
      await _reveal(
        tester,
        find.textContaining('Candidate snapshot-candidate'),
      );
    },
  );

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
    expect(
      find.textContaining('Candidate kind or payload mismatch'),
      findsOneWidget,
    );
  });

  testWidgets('single scan requires owned alternate rank before green', (
    tester,
  ) async {
    final service = _SnapshotMockService(deferred: true);
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    await _selectTarget(tester, 'mock-window');
    await tester.tap(find.byKey(const ValueKey('scan-start')));
    await tester.pump();
    service.emitGap();
    await tester.pump();
    await tester.pump();

    final input = find.byKey(
      const ValueKey('alternate-rank-snapshot-candidate-10098'),
    );
    await _reveal(tester, input);
    expect(find.text('dependency missing'), findsWidgets);
    await tester.enterText(input, '24');
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey(
                'scan-result-row-host-snapshot-candidate-relationship-10098',
              ),
            ),
          )
          .dy,
      greaterThan(
        tester
            .getTopLeft(
              find.byKey(
                const ValueKey('scan-result-row-host-snapshot-candidate'),
              ),
            )
            .dy,
      ),
    );
    final revalidate = find.byKey(
      const ValueKey('scan-student-revalidate-snapshot-candidate'),
    );
    await _reveal(tester, revalidate);
    tester.widget<FilledButton>(revalidate).onPressed!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final apply = find.byKey(
      const ValueKey('scan-student-apply-snapshot-candidate'),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '문제 없는 스캔 결과',
      ),
      findsWidgets,
    );
    expect(apply, findsOneWidget);
  });

  for (final size in const [
    Size(800, 720),
    Size(1280, 720),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'scan workspace remains reachable at ${size.width}x${size.height}',
      (tester) async {
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
        final profile = (await service.listProfiles()).single;
        final repository = await service.loadRepositoryState(profile.id);
        await service.saveRepositoryStudents(
          profile.id,
          [
            ConfirmedStudentState.fromValues('aru', const {
              'level': 90,
              'bond_rank': 20,
              'student_star': 5,
              'weapon_state': 'weapon_equipped',
              'weapon_star': 3,
              'weapon_level': 50,
              'ex_skill': 5,
              'skill1': 10,
              'skill2': 10,
              'skill3': 10,
              'equip1': 'T10',
              'equip1_level': 70,
              'equip2': 'T10',
              'equip2_level': 70,
              'equip3': 'T10',
              'equip3_level': 70,
              'combat_hp': 42191,
              'combat_atk': 6785,
              'combat_def': 437,
              'combat_heal': 7211,
            }),
          ],
          repository.revision,
          'scan-viewport-long-result-${size.width}',
        );
        await tester.pumpWidget(_subject(service));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('scan-start')), findsOneWidget);
        expect(find.byKey(const ValueKey('scan-refresh')), findsOneWidget);
        await _selectTarget(tester, 'long-ready-target');
        await tester.tap(find.byKey(const ValueKey('scan-start')));
        await tester.pump(const Duration(milliseconds: 35));
        final apply = find.byKey(
          const ValueKey('scan-student-apply-mock-candidate-1'),
        );
        await _reveal(tester, apply);
        expect(tester.takeException(), isNull);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == '문제 없는 스캔 결과',
          ),
          findsWidgets,
        );
        expect(apply, findsOneWidget);
        if (size.width >= 920) {
          final detailScroll = find.byKey(
            const ValueKey('scan-student-detail-scroll-mock-candidate-1'),
          );
          expect(detailScroll, findsOneWidget);
          final singleChild = find.descendant(
            of: detailScroll,
            matching: find.byType(SingleChildScrollView),
          );
          final position = tester
              .widget<SingleChildScrollView>(singleChild.first)
              .controller!
              .position;
          final before = position.pixels;
          await tester.drag(detailScroll, const Offset(0, -260));
          await tester.pump();
          expect(position.pixels, greaterThan(before));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}

class _RecordingWindowDockService implements WindowDockService {
  final List<String> dockedTargets = [];
  int restoreCalls = 0;

  @override
  Future<ScanDockPlacement> dockBeside(String targetId) async {
    dockedTargets.add(targetId);
    return const ScanDockPlacement(
      side: 'right',
      width: 270,
      height: 720,
      gameResized: false,
    );
  }

  @override
  Future<void> restore() async {
    restoreCalls += 1;
  }
}

class _RecordingStudentScanDiagnosticFileService
    implements StudentScanDiagnosticFileService {
  String? suggestedName;
  String? contents;

  @override
  Future<String?> save({
    required String suggestedName,
    required String contents,
  }) async {
    this.suggestedName = suggestedName;
    this.contents = contents;
    return 'C:/fake/$suggestedName';
  }
}

class _SnapshotMockService extends MockAppService {
  _SnapshotMockService({this.mismatch = false, this.deferred = false});

  final bool mismatch;
  final bool deferred;
  final StreamController<ScannerEvent> _events = StreamController.broadcast();

  @override
  Stream<ScannerEvent> get scannerEvents => _events.stream;

  @override
  Future<ScannerSession> startScannerSession(
    ScannerKind kind,
    String targetId, {
    String? profileId,
    StudentScanMode studentScanMode = StudentScanMode.single,
    InventoryScanProfile? inventoryScanProfile,
  }) async {
    return ScannerSession(
      id: 'snapshot-session',
      generation: 1,
      kind: kind,
      studentScanMode: studentScanMode,
    );
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
      evidence: deferred
          ? const [
              ScannerFieldEvidence(
                field: 'student_stat_validation',
                status: 'dependency_missing',
                source: 'student_stats_v1',
                details: {
                  'suggestion': {
                    'action': 'provide_alternate_relationship_ranks',
                  },
                  'relationship_contributions': [
                    {
                      'kind': 'current',
                      'student_id': 'aru',
                      'schaledb_id': 10000,
                      'rank': 20,
                      'owned': true,
                      'applied': true,
                    },
                    {
                      'kind': 'alternate',
                      'student_id': 'aru_newyear',
                      'schaledb_id': 10098,
                      'rank': null,
                      'owned': true,
                      'applied': false,
                    },
                  ],
                },
              ),
            ]
          : const [
              ScannerFieldEvidence(
                field: 'level',
                status: 'ok',
                source: 'snapshot',
                confidence: 0.99,
              ),
            ],
      reviewRequired: deferred,
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
