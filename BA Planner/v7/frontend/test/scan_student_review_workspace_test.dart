import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/widgets/scan_student_review_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

StudentCatalogEntry _catalog(String id, String group) => StudentCatalogEntry(
  studentId: id,
  displayName: id,
  templateName: '$id.png',
  group: group,
  variant: null,
  school: null,
  rarity: null,
  attackType: null,
  defenseType: null,
  combatClass: null,
  role: null,
  position: null,
  searchTags: const [],
  krSearchTags: const [],
);

ScannerCandidate _candidate(String id, String studentId) => ScannerCandidate(
  id: id,
  sessionId: 'session',
  generation: 1,
  revision: 1,
  kind: ScannerKind.student,
  payload: {
    'version': 1,
    'student_id': studentId,
    'values': const <String, dynamic>{},
  },
  evidence: const [],
  reviewRequired: false,
  approved: false,
);

void main() {
  testWidgets(
    'review confirms edits and checked fields without learning other values',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final candidate = ScannerCandidate(
        id: 'safety',
        sessionId: 'session',
        generation: 1,
        revision: 1,
        kind: ScannerKind.student,
        payload: {
          'version': 1,
          'student_id': 'aru',
          'values': {'level': 90, 'bond_rank': 20, 'weapon_level': 60},
        },
        evidence: const [
          ScannerFieldEvidence(
            field: 'bond_rank',
            status: 'uncertain',
            source: 'fixture',
          ),
        ],
        reviewRequired: true,
        approved: false,
      );
      Set<String>? fields;
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScanStudentReviewWorkspace(
              candidates: [candidate],
              currentStudents: const {},
              catalog: {'aru': _catalog('aru', 'aru')},
              busyCandidateIds: const {},
              candidateErrors: const {},
              singleScan: true,
              onRevalidate: (_, payload, _, confirmed) async {
                sent = payload;
                fields = confirmed;
              },
              onHold: (_) async {},
              onDiscard: (_) async {},
              onApply: (_) async {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('scan-student-edit-safety')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('scan-student-field-bond_rank')),
        'bad',
      );
      await tester.tap(
        find.byKey(const ValueKey('scan-student-revalidate-safety')),
      );
      await tester.pump();
      expect(fields, isNull);
      await tester.enterText(
        find.byKey(const ValueKey('scan-student-field-bond_rank')),
        '26',
      );
      await tester.tap(
        find.byKey(const ValueKey('scan-student-confirm-level')),
      );
      await tester.tap(
        find.byKey(const ValueKey('scan-student-revalidate-safety')),
      );
      await tester.pump();
      expect(fields, {'bond_rank', 'level'});
      expect(sent!['values']['bond_rank'], 26);
      expect(fields, isNot(contains('weapon_level')));
    },
  );

  testWidgets(
    'review resets draft, checked fields and errors when the same candidate gets a new revision',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      ScannerCandidate candidateAt(int revision, int level) => ScannerCandidate(
        id: 'safety',
        sessionId: 'session',
        generation: 1,
        revision: revision,
        kind: ScannerKind.student,
        payload: {
          'version': 1,
          'student_id': 'aru',
          'values': {'level': level, 'bond_rank': 20, 'weapon_level': 60},
        },
        evidence: const [
          ScannerFieldEvidence(
            field: 'bond_rank',
            status: 'uncertain',
            source: 'fixture',
          ),
        ],
        reviewRequired: true,
        approved: false,
      );
      Set<String>? fields;
      Map<String, dynamic>? sent;
      Widget workspace(ScannerCandidate candidate) => MaterialApp(
        home: Scaffold(
          body: ScanStudentReviewWorkspace(
            candidates: [candidate],
            currentStudents: const {},
            catalog: {'aru': _catalog('aru', 'aru')},
            busyCandidateIds: const {},
            candidateErrors: const {},
            singleScan: true,
            onRevalidate: (_, payload, _, confirmed) async {
              sent = payload;
              fields = confirmed;
            },
            onHold: (_) async {},
            onDiscard: (_) async {},
            onApply: (_) async {},
          ),
        ),
      );
      bool checked(String field) => tester
          .widget<Checkbox>(
            find.byKey(ValueKey('scan-student-confirm-$field')),
          )
          .value!;

      await tester.pumpWidget(workspace(candidateAt(1, 90)));
      await tester.tap(find.byKey(const ValueKey('scan-student-edit-safety')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('scan-student-field-level')),
        '91',
      );
      await tester.tap(
        find.byKey(const ValueKey('scan-student-confirm-weapon_level')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('scan-student-field-bond_rank')),
        'bad',
      );
      await tester.pump();
      expect(find.text('bond_rank 값은 정수여야 합니다.'), findsOneWidget);
      expect(checked('weapon_level'), isTrue);

      await tester.pumpWidget(workspace(candidateAt(2, 80)));
      await tester.pump();
      expect(find.text('bond_rank 값은 정수여야 합니다.'), findsNothing);
      expect(checked('weapon_level'), isFalse);
      await tester.tap(
        find.byKey(const ValueKey('scan-student-revalidate-safety')),
      );
      await tester.pump();
      expect(fields, isEmpty);
      expect(sent!['values'], {
        'level': 80,
        'bond_rank': 20,
        'weapon_level': 60,
      });
    },
  );

  test('full scan keeps every outfit of one character vertically adjacent', () {
    final ordered = orderScanResultCandidatesByGroup(
      [
        _candidate('aru', 'aru'),
        _candidate('hoshino', 'hoshino'),
        _candidate('aru-dress', 'aru_dress'),
        _candidate('hoshino-swimsuit', 'hoshino_swimsuit'),
      ],
      {
        'aru': _catalog('aru', 'aru'),
        'aru_dress': _catalog('aru_dress', 'aru'),
        'hoshino': _catalog('hoshino', 'hoshino'),
        'hoshino_swimsuit': _catalog('hoshino_swimsuit', 'hoshino'),
      },
    );

    expect(ordered.map((candidate) => candidate.id), [
      'aru',
      'aru-dress',
      'hoshino',
      'hoshino-swimsuit',
    ]);
  });

  testWidgets(
    'new eligible student exposes missing potential fields for review',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final candidate = ScannerCandidate(
        id: 'new-student',
        sessionId: 'session',
        generation: 1,
        revision: 1,
        kind: ScannerKind.student,
        payload: {
          'version': 1,
          'student_id': 'aru',
          'values': {'level': 90, 'student_star': 5},
        },
        evidence: const [
          ScannerFieldEvidence(
            field: 'student_stat_validation',
            status: 'dependency_missing',
            source: 'student_stats_v1',
          ),
        ],
        reviewRequired: true,
        approved: false,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: ScanStudentReviewWorkspace(
                candidates: [candidate],
                currentStudents: const <String, ConfirmedStudentState>{},
                catalog: {'aru': _catalog('aru', 'aru')},
                busyCandidateIds: const {},
                candidateErrors: const {},
                singleScan: true,
                onRevalidate: (_, _, _, _) async {},
                onHold: (_) async {},
                onDiscard: (_) async {},
                onApply: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('scan-student-edit-new-student')),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('scan-student-field-stat_hp')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('scan-student-field-stat_atk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('scan-student-field-stat_heal')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shadow-only evidence remains an applicable result', (
    tester,
  ) async {
    final candidate = ScannerCandidate(
      id: 'shadow-only',
      sessionId: 'session',
      generation: 1,
      revision: 1,
      kind: ScannerKind.student,
      payload: {
        'version': 1,
        'student_id': 'aru',
        'values': {'level': 1},
      },
      evidence: const [
        ScannerFieldEvidence(
          field: 'equip1_level',
          status: 'shadow',
          source: 'equipment_binary_shadow',
        ),
      ],
      reviewRequired: false,
      approved: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanStudentReviewWorkspace(
            candidates: [candidate],
            currentStudents: const <String, ConfirmedStudentState>{},
            catalog: {'aru': _catalog('aru', 'aru')},
            busyCandidateIds: const {},
            candidateErrors: const {},
            singleScan: true,
            onRevalidate: (_, _, _, _) async {},
            onHold: (_) async {},
            onDiscard: (_) async {},
            onApply: (_) async {},
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('scan-student-apply-shadow-only')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('scan-student-edit-shadow-only')),
      findsNothing,
    );
  });
}
