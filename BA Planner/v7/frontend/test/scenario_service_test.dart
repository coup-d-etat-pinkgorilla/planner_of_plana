import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scenario record keeps kind and profile staleness typed', () {
    final targets = {
      for (final entry in planningDocumentTargetMaximums.entries)
        entry.key: entry.key == 'bond_rank' ? 1 : 0,
    };
    final record = PlanningScenarioRecord.fromWire({
      'version': 1,
      'scenario_id': 'a' * 24,
      'revision': 0,
      'profile_id': 'b' * 24,
      'name': '후보',
      'description': '',
      'base_profile_revision': 3,
      'document': {
        'version': 1,
        'document_id': 'scenario',
        'name': '후보',
        'kind': 'scenario',
        'phases': [
          {
            'phase_id': 'phase',
            'name': '페이즈',
            'stages': [
              {
                'stage_id': 'stage',
                'student_id': 'ayane',
                'name': '목표',
                'targets': targets,
              },
            ],
          },
        ],
      },
      'created_at': '2026-08-05T00:00:00Z',
      'updated_at': '2026-08-05T00:00:00Z',
    });
    expect(record.document.kind, PlanningDocumentKind.scenario);
    expect(record.isStaleAgainst(3), isFalse);
    expect(record.isStaleAgainst(4), isTrue);
  });
}
