// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_projection.dart';
import 'package:flutter_test/flutter_test.dart';

StudentCatalogEntry student(
  String id, {
  String? school = 'Gehenna',
  String? role = 'Dealer',
}) => StudentCatalogEntry(
  studentId: id,
  displayName: id.toUpperCase(),
  templateName: '$id.png',
  group: 'group',
  variant: null,
  school: school,
  rarity: '3',
  attackType: 'Explosive',
  defenseType: 'Light',
  combatClass: 'Striker',
  role: role,
  position: 'Back',
  searchTags: const [],
  krSearchTags: const [],
);
RepositoryState state({
  List<dynamic> students = const [],
  List<dynamic> inventory = const [],
  List<dynamic> goals = const [],
}) => RepositoryState.fromWire({
  'profile_id': '000000000000000000000001',
  'revision': 3,
  'students': students,
  'inventory': {'version': 1, 'entries': inventory},
  'goals': {'version': 1, 'goals': goals},
});

void main() {
  test(
    'student projection uses stable full-profile denominators and known-only averages',
    () {
      final input = [
        student('b', school: null),
        student('a'),
        student('a', school: 'duplicate'),
      ];
      final projection = buildStudentStatistics(
        input,
        state(
          students: [
            {
              'version': 1,
              'student_id': 'a',
              'values': {'level': 80, 'student_star': 5},
            },
            {
              'version': 1,
              'student_id': 'b',
              'values': {'level': null, 'student_star': null},
            },
            {
              'version': 1,
              'student_id': 'repository-only',
              'values': {'level': 20},
            },
          ],
          goals: [
            {'student_id': 'a', 'target_level': 90},
            {'student_id': 'orphan', 'target_level': 10},
          ],
        ),
      );
      expect(projection.catalogCount, 2);
      expect(projection.confirmedCount, 3);
      expect(projection.averageLevel, 50);
      expect(projection.knownLevelCount, 2);
      expect(projection.averageStar, 5);
      expect(projection.knownStarCount, 1);
      expect(projection.orphanGoalCount, 1);
      expect(projection.missingCatalogIds, ['repository-only']);
      expect(
        projection.distributions['level']!
            .singleWhere((row) => row.key == 'Unknown')
            .count,
        1,
      );
      expect(
        projection.distributions['school']!
            .singleWhere((row) => row.key == '(Missing)')
            .identities,
        ['b'],
      );
      expect(
        projection.distributions['ownership']!.every(
          (row) => row.denominator == 2,
        ),
        isTrue,
      );
      expect(
        () => projection.missingCatalogIds.add('x'),
        throwsUnsupportedError,
      );
      expect(input, hasLength(3));
    },
  );

  test(
    'zero denominator is finite and deterministic sorting uses label tie break',
    () {
      final projection = buildStudentStatistics(const [], state());
      final rows = projection.distributions['ownership']!;
      expect(rows.every((row) => row.percent == 0), isTrue);
      expect(rows.every((row) => row.percent.isFinite), isTrue);
    },
  );

  test('out-of-range student values remain unknown and leave averages', () {
    final projection = buildStudentStatistics(
      [student('low'), student('high')],
      state(
        students: [
          {
            'version': 1,
            'student_id': 'low',
            'values': {'level': 0, 'student_star': 0},
          },
          {
            'version': 1,
            'student_id': 'high',
            'values': {'level': 91, 'student_star': 6},
          },
        ],
      ),
    );

    expect(projection.averageLevel, isNull);
    expect(projection.knownLevelCount, 0);
    expect(projection.averageStar, isNull);
    expect(projection.knownStarCount, 0);
    expect(
      projection.distributions['level']!
          .singleWhere((row) => row.key == 'Unknown')
          .count,
      2,
    );
    expect(
      projection.distributions['star']!
          .singleWhere((row) => row.key == 'Unknown')
          .count,
      2,
    );
  });

  test(
    'inventory projection separates absent unknown zero positive and missing category',
    () {
      final catalog = [
        const InventoryCatalogEntry(
          resourceKey: 'b',
          itemId: 'b',
          displayName: 'B',
          category: 'notes',
          profileId: 'p',
          orderIndex: 1,
          zeroFillAllowed: true,
        ),
        const InventoryCatalogEntry(
          resourceKey: 'a',
          itemId: 'a',
          displayName: 'A',
          category: 'notes',
          profileId: 'p',
          orderIndex: 0,
          zeroFillAllowed: true,
        ),
        const InventoryCatalogEntry(
          resourceKey: 'absent',
          itemId: 'absent',
          displayName: 'Absent',
          category: 'notes',
          profileId: 'p',
          orderIndex: 2,
          zeroFillAllowed: true,
        ),
      ];
      final projection = buildInventoryStatistics(
        catalog,
        state(
          inventory: [
            {'key': 'a', 'item_id': 'a', 'quantity': '0'},
            {'key': 'b', 'item_id': 'b', 'quantity': null},
            {'key': 'missing', 'item_id': 'missing', 'quantity': '7'},
          ],
        ).inventory,
      );
      expect(projection.catalogCount, 3);
      expect(projection.snapshotCount, 3);
      expect(projection.knownCount, 2);
      expect(projection.unknownCount, 1);
      expect(projection.absentCount, 1);
      expect(projection.zeroCount, 1);
      expect(projection.positiveCount, 1);
      expect(projection.missingCatalogIds, ['missing']);
      final notes = projection.categories.singleWhere(
        (row) => row.category == 'notes',
      );
      expect(notes.catalogCount, 3);
      expect(notes.snapshotCount, 2);
      expect(notes.absentCount, 1);
      expect(notes.knownCount, 1);
      expect(notes.unknownCount, 1);
      expect(notes.knownPercent, closeTo(100 / 3, 0.001));
      expect(
        projection.categories.any(
          (row) => row.category == '(Missing category)',
        ),
        isTrue,
      );
    },
  );

  test(
    'plan projection preserves gross maps and bounds positive shortages to ten',
    () {
      final shortageRows = List.generate(
        12,
        (index) => InventoryShortageRow(
          resourceKey: 'r${index.toString().padLeft(2, '0')}',
          itemId: 'r$index',
          displayName: 'R$index',
          category: 'material',
          requiredAmount: 20,
          owned: index == 11 ? null : 0,
          shortage: 12 - index,
          affectedStudentIds: ['s${index % 2}'],
          resolved: index != 11,
        ),
      );
      final projection = buildPlanStatistics(2, {
        'credits': 100,
        'level_exp': 20,
        'equipment_exp': 3,
        'weapon_exp': 4,
        'skill_books': {'book-b': 2, 'book-a': 2},
        'unknown_numeric': 999,
      }, InventoryShortageResult(shortageRows, const []));
      expect(
        projection.grossScalars.keys,
        containsAll(['credits', 'level_exp', 'equipment_exp', 'weapon_exp']),
      );
      expect(projection.grossScalars.containsKey('unknown_numeric'), isFalse);
      expect(projection.materials.map((row) => row.key).toList(), [
        'book-a',
        'book-b',
      ]);
      expect(projection.topShortages, hasLength(10));
      expect(projection.topShortages.first.resourceKey, 'r00');
      expect(projection.unresolvedCount, 1);
      expect(projection.affectedStudentCount, 2);
    },
  );
}
