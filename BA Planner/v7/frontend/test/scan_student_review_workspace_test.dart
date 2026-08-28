import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/scanner_service.dart';
import 'package:ba_planner_v7/ui/widgets/scan_student_review_workspace.dart';
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
}
