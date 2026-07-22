import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/pages/planning_page.dart';
import 'package:ba_planner_v7/ui/pages/student_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _subject(
  MockAppService service,
  ValueChanged<PlanningStudentSeed> onPlan,
) => MaterialApp(
  theme: BAPlannerTheme.dark(),
  home: Scaffold(
    body: StudentPage(service: service, onAddToPlan: onPlan),
  ),
);

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  final page = find.byKey(const ValueKey('student-page'));
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
    'catalog search, repository save, and plan handoff use services',
    (tester) async {
      final service = MockAppService();
      PlanningStudentSeed? seed;
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
        await service.dispose();
      });

      await tester.pumpWidget(_subject(service, (value) => seed = value));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('student-page')), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('student-search')),
        'ayane',
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('student-ayane')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('student-ayane')));
      await tester.pump();

      await _reveal(tester, find.byKey(const ValueKey('student-save')));
      await tester.tap(find.byKey(const ValueKey('student-save')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Saved at repository revision'),
        findsOneWidget,
      );

      await _reveal(tester, find.byKey(const ValueKey('student-add-to-plan')));
      await tester.tap(find.byKey(const ValueKey('student-add-to-plan')));
      expect(seed?.studentId, 'ayane');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disconnected state is explicit and retryable', (tester) async {
    final service = MockAppService();
    service.setConnection(BackendConnection.disconnected);
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, (_) {}));
    await tester.pumpAndSettle();
    expect(find.textContaining('disconnected'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'review-required candidate is unchanged on hold and committed after approval',
    (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final session = ScannerSession(
        id: 'session-1',
        generation: 1,
        kind: ScannerKind.student,
      );
      final candidate = ScannerCandidate(
        id: 'candidate-1',
        sessionId: session.id,
        generation: 1,
        revision: 1,
        kind: ScannerKind.student,
        payload: const {
          'version': 1,
          'student_id': 'aru',
          'values': {'level': 20},
        },
        evidence: const [
          ScannerFieldEvidence(
            field: 'level',
            status: 'matched',
            source: 'ocr',
            confidence: 0.8,
          ),
        ],
        reviewRequired: true,
        approved: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: BAPlannerTheme.dark(),
          home: Scaffold(
            body: StudentPage(
              service: service,
              onAddToPlan: (_) {},
              candidateContext: StudentCandidateContext(
                session: session,
                candidate: candidate,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.byKey(const ValueKey('candidate-hold')));
      await tester.tap(find.byKey(const ValueKey('candidate-hold')));
      await tester.pump();
      expect(
        (await service.loadRepositoryState(
          '000000000000000000000001',
        )).students,
        isEmpty,
      );

      await tester.tap(find.byKey(const ValueKey('candidate-approve')));
      await tester.pumpAndSettle();
      final state = await service.loadRepositoryState(
        '000000000000000000000001',
      );
      expect(state.students.single.studentId, 'aru');
      expect(state.students.single.values['level'], 20);
    },
  );

  testWidgets('long names and missing metadata remain searchable', (
    tester,
  ) async {
    final service = MockAppService();
    service.setLongNames(true);
    service.setMissingMetadata(true);
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, (_) {}));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('student-search')),
      'missing-student',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('student-missing-student')),
      findsOneWidget,
    );
    expect(find.textContaining('metadata unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and error catalog states are explicit', (tester) async {
    final empty = _EmptyCatalogService();
    addTearDown(empty.dispose);
    await tester.pumpWidget(_subject(empty, (_) {}));
    await tester.pumpAndSettle();
    expect(find.textContaining('No students'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final failed = _ErrorCatalogService();
    addTearDown(failed.dispose);
    await tester.pumpWidget(_subject(failed, (_) {}));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not load students'), findsOneWidget);
  });

  testWidgets('revision conflict keeps the current editor draft', (
    tester,
  ) async {
    final service = _ConflictService();
    addTearDown(service.dispose);
    await tester.pumpWidget(_subject(service, (_) {}));
    await tester.pumpAndSettle();
    final level = find.byKey(const ValueKey('student-field-level'));
    await tester.ensureVisible(level);
    await tester.enterText(level, '42');
    await tester.ensureVisible(find.byKey(const ValueKey('student-save')));
    await tester.tap(find.byKey(const ValueKey('student-save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('draft was kept'), findsOneWidget);
    expect((tester.widget<TextField>(level).controller?.text), '42');
    expect(
      find.byKey(const ValueKey('student-reload-profile')),
      findsOneWidget,
    );
  });

  for (final size in const [
    Size(1280, 720),
    Size(1440, 900),
    Size(1280, 960),
  ]) {
    testWidgets(
      'student page has no overflow at ${size.width}x${size.height}',
      (tester) async {
        final service = MockAppService();
        await tester.binding.setSurfaceSize(size);
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
          await service.dispose();
        });
        await tester.pumpWidget(_subject(service, (_) {}));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('student-page')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _EmptyCatalogService extends MockAppService {
  @override
  Future<List<StudentCatalogEntry>> listStudents() async => const [];
}

class _ErrorCatalogService extends MockAppService {
  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      throw StateError('catalog failure');
}

class _ConflictService extends MockAppService {
  @override
  Future<int> saveRepositoryStudents(
    String profileId,
    List<ConfirmedStudentState> students,
    int expectedRevision,
    String idempotencyKey,
  ) async => throw BackendRemoteException(
    code: 'revision_conflict',
    message: 'stale revision',
  );
}
