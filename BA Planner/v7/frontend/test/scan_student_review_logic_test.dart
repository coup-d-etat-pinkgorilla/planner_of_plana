// FE8-f1: 학생 스캔 검토 순수 규칙(예전 ScanStudentReviewWorkspace 안에 있던 계산).
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/scan/scan_student_review_logic.dart';
import 'package:flutter_test/flutter_test.dart';

ScannerCandidate _candidate({
  Map<String, dynamic> values = const {},
  List<ScannerFieldEvidence> evidence = const [],
  bool reviewRequired = false,
}) => ScannerCandidate(
  id: 'c1',
  sessionId: 'session',
  generation: 1,
  revision: 1,
  kind: ScannerKind.student,
  payload: {'version': 1, 'student_id': 'aru', 'values': values},
  evidence: evidence,
  reviewRequired: reviewRequired,
  approved: false,
);

ScannerFieldEvidence _evidence(
  String status, {
  String field = 'level',
  Map<String, dynamic>? details,
}) => ScannerFieldEvidence(
  field: field,
  status: status,
  source: 'fixture',
  details: details,
);

void main() {
  test('status follows errors, deferred, then the evidence priority', () {
    final uncertain = _candidate(
      evidence: [_evidence('uncertain'), _evidence('partial')],
    );
    expect(
      scanStudentCandidateStatus(
        uncertain,
        applyFailed: false,
        invalidEdit: false,
      ),
      'partial',
    );
    expect(
      scanStudentCandidateStatus(
        uncertain,
        applyFailed: false,
        invalidEdit: true,
      ),
      'invalid edit',
    );
    expect(
      scanStudentCandidateStatus(
        uncertain,
        applyFailed: true,
        invalidEdit: true,
      ),
      'apply failed',
    );
    expect(
      scanStudentCandidateStatus(
        _candidate(evidence: [_evidence('deferred'), _evidence('failed')]),
        applyFailed: false,
        invalidEdit: false,
      ),
      '다른 의상 랭크 적용 대기',
    );
    expect(
      scanStudentCandidateStatus(
        _candidate(evidence: [_evidence('region_missing')]),
        applyFailed: false,
        invalidEdit: false,
      ),
      'region missing',
    );
    expect(
      scanStudentCandidateStatus(
        _candidate(reviewRequired: true),
        applyFailed: false,
        invalidEdit: false,
      ),
      'review required',
    );
    expect(
      scanStudentCandidateStatus(
        _candidate(evidence: [_evidence('ok')]),
        applyFailed: false,
        invalidEdit: false,
      ),
      'verified',
    );
  });

  test('only unsafe evidence, review or errors make a problem', () {
    bool problem(ScannerCandidate candidate) => scanStudentCandidateHasProblem(
      candidate,
      applyFailed: false,
      invalidEdit: false,
    );
    expect(problem(_candidate(evidence: [_evidence('shadow')])), isFalse);
    expect(problem(_candidate(evidence: [_evidence('deferred')])), isFalse);
    expect(problem(_candidate(evidence: [_evidence('uncertain')])), isTrue);
    expect(problem(_candidate(reviewRequired: true)), isTrue);
    expect(
      scanStudentCandidateHasProblem(
        _candidate(),
        applyFailed: true,
        invalidEdit: false,
      ),
      isTrue,
    );
  });

  test('comparison fields add potentials and combat stats only when due', () {
    expect(
      scanStudentComparisonFields(
        current: const {'level': 80},
        scanned: const {'level': 90, 'student_star': 4},
        expected: const {},
      ),
      ['level', 'student_star'],
    );
    expect(
      scanStudentComparisonFields(
        current: const {},
        scanned: const {'level': 90, 'student_star': 5},
        expected: const {'MaxHP': 100},
      ),
      [
        'combat_atk',
        'combat_def',
        'combat_heal',
        'combat_hp',
        'level',
        'stat_atk',
        'stat_heal',
        'stat_hp',
        'student_star',
      ],
    );
  });

  test('calculated values and deltas map stat keys to fields', () {
    final candidate = _candidate(
      evidence: [
        _evidence('ok'),
        _evidence(
          'ok',
          field: 'student_stat_validation',
          details: {
            'expected': {'MaxHP': 1200, 'HealPower': 300},
            'delta': {'MaxHP': -4},
            'relationship_contributions': [
              {'kind': 'alternate', 'owned': true, 'schaledb_id': 7},
              'not a row',
            ],
          },
        ),
      ],
    );
    final expected = scanStudentExpectedStats(candidate);
    final delta = scanStudentStatDelta(candidate);
    expect(scanStudentCalculatedValue('combat_hp', expected), 1200);
    expect(scanStudentCalculatedValue('combat_heal', expected), 300);
    expect(scanStudentCalculatedValue('level', expected), isNull);
    expect(scanStudentCalculatedDelta('combat_hp', delta), -4);
    expect(scanStudentCalculatedDelta('combat_atk', delta), isNull);
    final rows = scanStudentRelationshipContributions(candidate);
    expect(rows, hasLength(1));
    expect(scanStudentIsOwnedAlternate(rows.single), isTrue);
    expect(scanStudentExpectedStats(_candidate()), isEmpty);
    expect(scanStudentRelationshipContributions(_candidate()), isEmpty);
  });

  test('integer fields, relationship ranks and confirmed fields', () {
    expect(scanStudentFieldNeedsInteger('level', null), isTrue);
    expect(scanStudentFieldNeedsInteger('stat_hp', null), isTrue);
    expect(scanStudentFieldNeedsInteger('memo', 3), isTrue);
    expect(scanStudentFieldNeedsInteger('equip4', 'T1'), isFalse);

    expect(scanStudentRelationshipRank('1'), 1);
    expect(scanStudentRelationshipRank('100'), 100);
    expect(scanStudentRelationshipRank('0'), isNull);
    expect(scanStudentRelationshipRank('101'), isNull);
    expect(scanStudentRelationshipRank('x'), isNull);

    expect(
      scanStudentConfirmedFields(
        original: const {'level': 90, 'bond_rank': 20},
        draft: const {'level': 91, 'bond_rank': 20},
        checked: const {'weapon_level'},
      ),
      {'weapon_level', 'level'},
    );
    expect(
      scanStudentConfirmedFields(
        original: const {'level': 90},
        draft: const {'level': 90},
      ),
      isEmpty,
    );
    expect(scanStudentValues(_candidate(values: const {'level': 3})), {
      'level': 3,
    });
    expect(scanStudentId(_candidate()), 'aru');
  });
}
