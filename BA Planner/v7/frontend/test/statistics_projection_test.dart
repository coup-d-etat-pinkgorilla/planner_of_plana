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
          school: null,
          family: null,
          tier: null,
        ),
        const InventoryCatalogEntry(
          resourceKey: 'a',
          itemId: 'a',
          displayName: 'A',
          category: 'notes',
          profileId: 'p',
          orderIndex: 0,
          zeroFillAllowed: true,
          school: null,
          family: null,
          tier: null,
        ),
        const InventoryCatalogEntry(
          resourceKey: 'absent',
          itemId: 'absent',
          displayName: 'Absent',
          category: 'notes',
          profileId: 'p',
          orderIndex: 2,
          zeroFillAllowed: true,
          school: null,
          family: null,
          tier: null,
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
    'inventory projection keeps catalog-only currencies out of item coverage',
    () {
      // FB-3: credits·엘리그마 행과 재화 snapshot 항목은 아이템 보유 범위 집계에 들어가지 않는다.
      InventoryCatalogEntry row(
        String key,
        String? itemId,
        String category,
        String profileId,
        int order,
      ) => InventoryCatalogEntry(
        resourceKey: key,
        itemId: itemId,
        displayName: key,
        category: category,
        profileId: profileId,
        orderIndex: order,
        zeroFillAllowed: profileId != 'currencies',
        school: null,
        family: null,
        tier: null,
      );
      final catalog = [
        row('a', 'a', 'notes', 'p', 0),
        row('absent', 'absent', 'notes', 'p', 1),
        row('credits', null, 'credits', 'currencies', 0),
        row(
          'Item_Icon_SecretStone',
          'Item_Icon_SecretStone',
          'eligma',
          'currencies',
          1,
        ),
      ];
      expect(
        catalog
            .where((item) => item.isReadOnlyCurrency)
            .map((item) => item.resourceKey)
            .toSet(),
        inventoryReadOnlyCurrencyKeys,
      );
      final projection = buildInventoryStatistics(
        catalog,
        state(
          inventory: [
            {'key': 'a', 'item_id': 'a', 'quantity': '0'},
            {'key': 'credits', 'item_id': null, 'quantity': '1000'},
            {
              'key': 'Item_Icon_SecretStone',
              'item_id': 'Item_Icon_SecretStone',
              'quantity': null,
            },
          ],
        ).inventory,
      );
      expect(projection.catalogCount, 2);
      expect(projection.snapshotCount, 1);
      expect(projection.knownCount, 1);
      expect(projection.unknownCount, 0);
      expect(projection.absentCount, 1);
      expect(projection.zeroCount, 1);
      expect(projection.positiveCount, 0);
      expect(projection.missingCatalogIds, isEmpty);
      expect(projection.categories.map((item) => item.category), ['notes']);
      expect(projection.categories.single.identities, ['a', 'absent']);
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

  test(
    'shortage categories average per-resource fill instead of summing quantities',
    () {
      InventoryShortageRow row(
        String key,
        String category,
        int required,
        int? owned,
      ) => InventoryShortageRow(
        resourceKey: key,
        itemId: key,
        displayName: key,
        category: category,
        requiredAmount: required,
        owned: owned,
        shortage: owned == null ? null : (required - owned).clamp(0, required),
        affectedStudentIds: const ['s0'],
        resolved: true,
      );
      final projection = buildPlanStatistics(1, const {}, InventoryShortageResult([
        // 기술 노트 두 종: 1/2(50%)와 900/1000(90%). 수량을 더하면 901/1002 = 89.9%지만 FD-032는 70%다.
        row('note-a', 'tech_notes', 2, 1),
        row('note-b', 'tech_notes', 1000, 900),
        row('note-c', 'tech_notes', 10, null),
        row('bd-a', 'tactical_bd', 10, 20),
        row('eleph-a', 'student_eleph', 5, null),
        row('credits', 'credits', 100, 10),
      ], const []));
      final categories = {
        for (final item in projection.shortageCategories) item.category: item,
      };
      // 재화(크레딧)는 카테고리 막대가 아니다. 순서는 B1 순서(기술 노트 · 전술 BD · 엘레프).
      expect(projection.shortageCategories.map((item) => item.category), [
        'tech_notes',
        'tactical_bd',
        'student_eleph',
      ]);
      expect(categories['tech_notes']!.fulfillment, closeTo(0.7, 1e-12));
      expect(categories['tech_notes']!.plannedKinds, 3);
      expect(categories['tech_notes']!.unknownKinds, 1);
      // 넘치는 보유는 100%로 자른다.
      expect(categories['tactical_bd']!.fulfillment, 1);
      // 모두 모르면 0이 아니라 null이다(FD-033).
      expect(categories['student_eleph']!.fulfillment, isNull);
      expect(categories['student_eleph']!.unknownKinds, 1);
    },
  );
}
