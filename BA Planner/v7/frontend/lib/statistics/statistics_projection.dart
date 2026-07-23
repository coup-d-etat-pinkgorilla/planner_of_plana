// ignore_for_file: curly_braces_in_flow_control_structures

import '../services/app_service.dart';
import '../services/repository_service.dart';

class StatisticsRow {
  StatisticsRow({
    required this.key,
    required this.label,
    required this.count,
    required this.denominator,
    required List<String> identities,
  }) : identities = List.unmodifiable(identities);
  final String key;
  final String label;
  final int count;
  final int denominator;
  final List<String> identities;
  double get percent => denominator == 0 ? 0 : count * 100 / denominator;
}

List<StatisticsRow> _sortedRows(Iterable<StatisticsRow> rows) {
  final result = rows.toList();
  result.sort((a, b) {
    final count = b.count.compareTo(a.count);
    if (count != 0) return count;
    final label = a.label.toLowerCase().compareTo(b.label.toLowerCase());
    return label != 0 ? label : a.key.compareTo(b.key);
  });
  return List.unmodifiable(result);
}

class StudentStatistics {
  StudentStatistics({
    required this.catalogCount,
    required this.confirmedCount,
    required this.goalCount,
    required this.orphanGoalCount,
    required this.averageLevel,
    required this.knownLevelCount,
    required this.averageStar,
    required this.knownStarCount,
    required Map<String, List<StatisticsRow>> distributions,
    required List<String> missingCatalogIds,
    required Map<String, String> displayNames,
  }) : distributions = Map.unmodifiable(distributions),
       missingCatalogIds = List.unmodifiable(missingCatalogIds),
       displayNames = Map.unmodifiable(displayNames);
  final int catalogCount, confirmedCount, goalCount, orphanGoalCount;
  final double? averageLevel, averageStar;
  final int knownLevelCount, knownStarCount;
  final Map<String, List<StatisticsRow>> distributions;
  final List<String> missingCatalogIds;
  final Map<String, String> displayNames;
}

StudentStatistics buildStudentStatistics(
  List<StudentCatalogEntry> catalog,
  RepositoryState state,
) {
  final catalogById = <String, StudentCatalogEntry>{};
  for (final item in [
    ...catalog,
  ]..sort((a, b) => a.studentId.compareTo(b.studentId))) {
    catalogById.putIfAbsent(item.studentId, () => item);
  }
  final currentById = {for (final item in state.students) item.studentId: item};
  final goalIds = state.goals.map((item) => item.studentId).toSet();
  final missing =
      currentById.keys.where((id) => !catalogById.containsKey(id)).toList()
        ..sort();
  String metadata(String? value) =>
      value == null || value.trim().isEmpty ? '(Missing)' : value;
  List<StatisticsRow> catalogGroup(String Function(StudentCatalogEntry) value) {
    final ids = <String, List<String>>{};
    for (final item in catalogById.values) {
      final label = value(item);
      ids.putIfAbsent(label, () => []).add(item.studentId);
    }
    return _sortedRows(
      ids.entries.map(
        (entry) => StatisticsRow(
          key: entry.key,
          label: entry.key,
          count: entry.value.length,
          denominator: catalogById.length,
          identities: entry.value..sort(),
        ),
      ),
    );
  }

  List<StatisticsRow> currentGroup(
    String Function(ConfirmedStudentState) value,
  ) {
    final ids = <String, List<String>>{};
    for (final item in currentById.values) {
      final label = value(item);
      ids.putIfAbsent(label, () => []).add(item.studentId);
    }
    return _sortedRows(
      ids.entries.map(
        (entry) => StatisticsRow(
          key: entry.key,
          label: entry.key,
          count: entry.value.length,
          denominator: currentById.length,
          identities: entry.value..sort(),
        ),
      ),
    );
  }

  String level(ConfirmedStudentState item) {
    final value = item.values['level'];
    if (value is! int || value < 1 || value > 90) return 'Unknown';
    if (value <= 20) return '1–20';
    if (value <= 40) return '21–40';
    if (value <= 60) return '41–60';
    if (value <= 80) return '61–80';
    return '81–90';
  }

  String star(ConfirmedStudentState item) {
    final value = item.values['student_star'];
    return value is int && value >= 1 && value <= 5 ? '$value' : 'Unknown';
  }

  final levels = currentById.values
      .map((item) => item.values['level'])
      .whereType<int>()
      .where((value) => value >= 1 && value <= 90)
      .toList();
  final stars = currentById.values
      .map((item) => item.values['student_star'])
      .whereType<int>()
      .where((value) => value >= 1 && value <= 5)
      .toList();
  final owned = catalogById.keys.where(currentById.containsKey).toList()
    ..sort();
  final unowned =
      catalogById.keys.where((id) => !currentById.containsKey(id)).toList()
        ..sort();
  return StudentStatistics(
    catalogCount: catalogById.length,
    confirmedCount: currentById.length,
    goalCount: goalIds.length,
    orphanGoalCount: goalIds.where((id) => !catalogById.containsKey(id)).length,
    averageLevel: levels.isEmpty
        ? null
        : levels.reduce((a, b) => a + b) / levels.length,
    knownLevelCount: levels.length,
    averageStar: stars.isEmpty
        ? null
        : stars.reduce((a, b) => a + b) / stars.length,
    knownStarCount: stars.length,
    missingCatalogIds: missing,
    displayNames: {
      for (final item in catalogById.values) item.studentId: item.displayName,
    },
    distributions: {
      'ownership': [
        StatisticsRow(
          key: 'owned',
          label: 'Owned',
          count: owned.length,
          denominator: catalogById.length,
          identities: owned,
        ),
        StatisticsRow(
          key: 'unowned',
          label: 'Unowned',
          count: unowned.length,
          denominator: catalogById.length,
          identities: unowned,
        ),
      ],
      'level': currentGroup(level),
      'star': currentGroup(star),
      'school': catalogGroup((item) => metadata(item.school)),
      'combat_class': catalogGroup((item) => metadata(item.combatClass)),
      'attack_type': catalogGroup((item) => metadata(item.attackType)),
      'defense_type': catalogGroup((item) => metadata(item.defenseType)),
      'role': catalogGroup((item) => metadata(item.role)),
    },
  );
}

class InventoryCategoryStatistics {
  InventoryCategoryStatistics({
    required this.category,
    required this.catalogCount,
    required this.snapshotCount,
    required this.knownCount,
    required this.unknownCount,
    required this.absentCount,
    required this.zeroCount,
    required this.positiveCount,
    required List<String> identities,
  }) : identities = List.unmodifiable(identities);
  final String category;
  final int catalogCount,
      snapshotCount,
      knownCount,
      unknownCount,
      absentCount,
      zeroCount,
      positiveCount;
  final List<String> identities;
  double get knownPercent {
    final denominator = catalogCount == 0 ? snapshotCount : catalogCount;
    return denominator == 0 ? 0 : knownCount * 100 / denominator;
  }
}

class InventoryStatistics {
  InventoryStatistics({
    required this.catalogCount,
    required this.snapshotCount,
    required this.knownCount,
    required this.unknownCount,
    required this.absentCount,
    required this.zeroCount,
    required this.positiveCount,
    required List<String> missingCatalogIds,
    required List<InventoryCategoryStatistics> categories,
  }) : missingCatalogIds = List.unmodifiable(missingCatalogIds),
       categories = List.unmodifiable(categories);
  final int catalogCount,
      snapshotCount,
      knownCount,
      unknownCount,
      absentCount,
      zeroCount,
      positiveCount;
  final List<String> missingCatalogIds;
  final List<InventoryCategoryStatistics> categories;
}

InventoryStatistics buildInventoryStatistics(
  List<InventoryCatalogEntry> catalog,
  RepositoryInventoryState snapshot,
) {
  final catalogById = <String, InventoryCatalogEntry>{};
  for (final item in catalog)
    catalogById.putIfAbsent(item.itemId ?? item.resourceKey, () => item);
  final snapshotById = <String, Map<String, dynamic>>{};
  for (final item in snapshot.entries)
    snapshotById[item['item_id'] as String? ?? item['key'] as String] = item;
  final groups = <String, Set<String>>{};
  for (final entry in catalogById.entries)
    groups.putIfAbsent(entry.value.category, () => {}).add(entry.key);
  final missing =
      snapshotById.keys.where((id) => !catalogById.containsKey(id)).toList()
        ..sort();
  if (missing.isNotEmpty) groups['(Missing category)'] = missing.toSet();
  int quantity(String id) {
    final raw = snapshotById[id]?['quantity'];
    return raw is String ? int.parse(raw) : -1;
  }

  final categories =
      groups.entries.map((entry) {
        final present = entry.value.where(snapshotById.containsKey).toList();
        final known = present.where((id) => quantity(id) >= 0).length;
        final isMissingCategory = entry.key == '(Missing category)';
        return InventoryCategoryStatistics(
          category: entry.key,
          catalogCount: isMissingCategory ? 0 : entry.value.length,
          snapshotCount: present.length,
          knownCount: known,
          unknownCount: present.length - known,
          absentCount: isMissingCategory
              ? 0
              : entry.value.length - present.length,
          zeroCount: present.where((id) => quantity(id) == 0).length,
          positiveCount: present.where((id) => quantity(id) > 0).length,
          identities: entry.value.toList()..sort(),
        );
      }).toList()..sort((a, b) {
        final count = b.catalogCount.compareTo(a.catalogCount);
        return count != 0 ? count : a.category.compareTo(b.category);
      });
  final quantities = snapshotById.keys.map(quantity).toList();
  final absentCount = catalogById.keys
      .where((id) => !snapshotById.containsKey(id))
      .length;
  return InventoryStatistics(
    catalogCount: catalogById.length,
    snapshotCount: snapshotById.length,
    knownCount: quantities.where((v) => v >= 0).length,
    unknownCount: quantities.where((v) => v < 0).length,
    absentCount: absentCount,
    zeroCount: quantities.where((v) => v == 0).length,
    positiveCount: quantities.where((v) => v > 0).length,
    missingCatalogIds: missing,
    categories: categories,
  );
}

class GrossMaterialRow {
  const GrossMaterialRow(this.category, this.key, this.value);
  final String category, key;
  final int value;
}

class ShortageCategoryStatistics {
  const ShortageCategoryStatistics(
    this.category,
    this.required,
    this.knownOwned,
    this.positiveShortage,
    this.unknownCount,
  );
  final String category;
  final int required, knownOwned, positiveShortage, unknownCount;
}

class PlanStatistics {
  PlanStatistics({
    required this.savedGoalCount,
    required Map<String, int> grossScalars,
    required List<GrossMaterialRow> materials,
    required this.shortageRowCount,
    required this.positiveShortageCount,
    required this.unresolvedCount,
    required this.affectedStudentCount,
    required List<InventoryShortageRow> topShortages,
    required List<ShortageCategoryStatistics> shortageCategories,
  }) : grossScalars = Map.unmodifiable(grossScalars),
       materials = List.unmodifiable(materials),
       topShortages = List.unmodifiable(topShortages),
       shortageCategories = List.unmodifiable(shortageCategories);
  final int savedGoalCount,
      shortageRowCount,
      positiveShortageCount,
      unresolvedCount,
      affectedStudentCount;
  final Map<String, int> grossScalars;
  final List<GrossMaterialRow> materials;
  final List<InventoryShortageRow> topShortages;
  final List<ShortageCategoryStatistics> shortageCategories;
}

PlanStatistics buildPlanStatistics(
  int goalCount,
  Map<String, dynamic>? gross,
  InventoryShortageResult? shortages,
) {
  const scalars = ['credits', 'level_exp', 'equipment_exp', 'weapon_exp'];
  const materialKeys = [
    'star_materials',
    'equipment_materials',
    'level_exp_items',
    'equipment_exp_items',
    'weapon_exp_items',
    'skill_books',
    'ex_ooparts',
    'skill_ooparts',
    'favorite_item_materials',
    'stat_materials',
    'stat_levels',
  ];
  final materials = <GrossMaterialRow>[];
  for (final category in materialKeys) {
    final values = gross?[category];
    if (values is Map) {
      for (final entry in values.entries) {
        if (entry.key is String && entry.value is int)
          materials.add(
            GrossMaterialRow(category, entry.key as String, entry.value as int),
          );
      }
    }
  }
  materials.sort((a, b) {
    final value = b.value.compareTo(a.value);
    if (value != 0) return value;
    final category = a.category.compareTo(b.category);
    return category != 0 ? category : a.key.compareTo(b.key);
  });
  final rows = shortages?.rows ?? const <InventoryShortageRow>[];
  final top =
      rows.where((row) => row.shortage != null && row.shortage! > 0).toList()
        ..sort((a, b) {
          final value = b.shortage!.compareTo(a.shortage!);
          return value != 0 ? value : a.resourceKey.compareTo(b.resourceKey);
        });
  final categoryRows = <String, List<InventoryShortageRow>>{};
  for (final row in rows)
    categoryRows.putIfAbsent(row.category, () => []).add(row);
  final categories =
      categoryRows.entries
          .map(
            (entry) => ShortageCategoryStatistics(
              entry.key,
              entry.value.fold(0, (sum, row) => sum + row.requiredAmount),
              entry.value
                  .where((row) => row.owned != null)
                  .fold(0, (sum, row) => sum + row.owned!),
              entry.value
                  .where((row) => row.shortage != null && row.shortage! > 0)
                  .fold(0, (sum, row) => sum + row.shortage!),
              entry.value
                  .where((row) => row.owned == null || row.shortage == null)
                  .length,
            ),
          )
          .toList()
        ..sort((a, b) {
          final value = b.positiveShortage.compareTo(a.positiveShortage);
          return value != 0 ? value : a.category.compareTo(b.category);
        });
  return PlanStatistics(
    savedGoalCount: goalCount,
    grossScalars: {
      for (final key in scalars)
        if (gross?[key] is int) key: gross![key] as int,
    },
    materials: materials,
    shortageRowCount: rows.length,
    positiveShortageCount: rows
        .where((row) => row.shortage != null && row.shortage! > 0)
        .length,
    unresolvedCount: rows
        .where(
          (row) => !row.resolved || row.owned == null || row.shortage == null,
        )
        .length,
    affectedStudentCount: rows
        .expand((row) => row.affectedStudentIds)
        .toSet()
        .length,
    topShortages: top.take(10).toList(),
    shortageCategories: categories,
  );
}
