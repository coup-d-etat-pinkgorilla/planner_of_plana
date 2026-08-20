import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scenario summary keeps calculation and portrait data typed', () {
    final summary = PlanningScenarioSummary.fromWire({
      'scenario_id': 'c' * 24,
      'revision': 2,
      'name': '계산 후보',
      'description': '설명',
      'base_profile_revision': 4,
      'phase_count': 2,
      'stage_count': 3,
      'student_count': 2,
      'student_ids': ['ayane', 'hasumi'],
      'calculation': {
        'credits': 18200000,
        'required_resource_type_count': 7,
        'known_shortage_type_count': 3,
        'inventory_complete': false,
        'first_bottleneck_phase_number': 2,
        'representative_shortage': {
          'resource_key': 'credits',
          'item_id': null,
          'display_name': '크레딧',
          'category': 'credits',
          'shortage': 1200000,
        },
      },
      'created_at': '2026-08-14T00:00:00Z',
      'updated_at': '2026-08-14T01:00:00Z',
    });

    expect(summary.studentIds, ['ayane', 'hasumi']);
    expect(summary.calculation?.credits, 18200000);
    expect(summary.calculation?.inventoryComplete, isFalse);
    expect(summary.calculation?.firstBottleneckPhaseNumber, 2);
    expect(summary.calculation?.representativeShortage?.shortage, 1200000);
  });

  test('scenario record keeps kind and profile staleness typed', () {
    final targets = {
      for (final entry in planningDocumentTargetMaximums.entries)
        entry.key: entry.key == 'bond_rank' ? 1 : 0,
      'level': 1,
      'student_star': 1,
      'ex_skill': 1,
      'skill1': 1,
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
    expect(record.isStaleAgainst(2), isFalse);
  });
}
