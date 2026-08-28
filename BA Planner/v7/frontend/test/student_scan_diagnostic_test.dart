import 'dart:convert';

import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/services/student_scan_diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'student diagnostic preserves review evidence and limits repository context',
    () {
      const session = ScannerSession(
        id: 'session-1',
        generation: 2,
        kind: ScannerKind.student,
        studentScanMode: StudentScanMode.full,
      );
      final candidate = ScannerCandidate(
        id: 'candidate-1',
        sessionId: session.id,
        generation: session.generation,
        revision: 3,
        kind: ScannerKind.student,
        payload: const {
          'version': 1,
          'student_id': 'hoshino',
          'values': {'level': 90, 'bond_rank': 29},
        },
        evidence: const [
          ScannerFieldEvidence(
            field: 'student_stat_validation',
            status: 'suspicious',
            source: 'student_stats_v1',
            confidence: 0.73,
            details: {
              'expected': {'MaxHP': 100},
              'observed': {'MaxHP': 101},
              'delta': {'MaxHP': 1},
              'dependencies': <dynamic>[],
            },
          ),
        ],
        reviewRequired: true,
        approved: false,
        audit: const [
          {'from_revision': 2, 'source': 'second_pass_revalidation'},
        ],
      );
      final event = ScannerEvent(
        sessionId: session.id,
        generation: session.generation,
        sequence: 1,
        kind: ScannerKind.student,
        eventKind: ScannerEventKind.terminal,
        payload: const {
          'session_id': 'session-1',
          'generation': 2,
          'sequence': 1,
          'scan_kind': 'student',
          'event_kind': 'terminal',
          'outcome': 'completed',
        },
      );
      final snapshot = ScannerSessionSnapshot(
        sessionId: session.id,
        generation: session.generation,
        kind: ScannerKind.student,
        lastSequence: 1,
        terminal: 'completed',
        events: [event],
        candidates: [candidate],
      );
      final repository = RepositoryState.fromWire({
        'profile_id': '0123456789abcdef01234567',
        'revision': 7,
        'students': [
          {
            'version': 1,
            'student_id': 'hoshino',
            'values': {'level': 80, 'bond_rank': 20},
          },
          {
            'version': 1,
            'student_id': 'unrelated',
            'values': {'level': 1},
          },
        ],
        'inventory': {'version': 1, 'entries': <dynamic>[]},
        'goals': {'version': 1, 'goals': <dynamic>[]},
      });

      final document = buildStudentScanDiagnosticDocument(
        session: session,
        snapshot: snapshot,
        repositoryState: repository,
        generatedAt: DateTime.utc(2026, 8, 28, 12, 34, 56),
      );
      final encoded = encodeStudentScanDiagnosticDocument(document);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['format'], studentScanDiagnosticFormat);
      expect(decoded['version'], 1);
      expect(decoded['generated_at'], '2026-08-28T12:34:56.000Z');
      expect(decoded['privacy'], {
        'account_name_included': false,
        'window_title_included': false,
        'images_included': false,
      });
      expect(decoded['summary'], {
        'candidate_count': 1,
        'review_required_count': 1,
        'approved_count': 0,
        'evidence_status_counts': {'suspicious': 1},
      });
      final context = decoded['repository_context'] as Map<String, dynamic>;
      expect(context.containsKey('profile_id'), isFalse);
      expect(context['confirmed_students'], hasLength(1));
      expect(
        (context['confirmed_students'] as List).single['student_id'],
        'hoshino',
      );
      final exportedCandidate = (decoded['candidates'] as List).single as Map;
      expect(exportedCandidate['revision'], 3);
      expect(exportedCandidate['audit'], hasLength(1));
      expect(
        ((exportedCandidate['evidence'] as List).single as Map)['details'],
        containsPair('delta', {'MaxHP': 1}),
      );
      expect(encoded, isNot(contains('unrelated')));
    },
  );

  test('diagnostic rejects incomplete sessions', () {
    const session = ScannerSession(
      id: 'session-1',
      generation: 1,
      kind: ScannerKind.student,
    );
    final repository = RepositoryState.fromWire({
      'profile_id': '0123456789abcdef01234567',
      'revision': 0,
      'students': <dynamic>[],
      'inventory': {'version': 1, 'entries': <dynamic>[]},
      'goals': {'version': 1, 'goals': <dynamic>[]},
    });
    final snapshot = ScannerSessionSnapshot(
      sessionId: session.id,
      generation: session.generation,
      kind: ScannerKind.student,
      lastSequence: 0,
      terminal: 'cancelled',
      events: const [],
      candidates: const [],
    );

    expect(
      () => buildStudentScanDiagnosticDocument(
        session: session,
        snapshot: snapshot,
        repositoryState: repository,
        generatedAt: DateTime.utc(2026),
      ),
      throwsFormatException,
    );
  });
}
