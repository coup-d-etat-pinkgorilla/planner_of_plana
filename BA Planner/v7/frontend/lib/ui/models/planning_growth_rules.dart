import 'dart:math' as math;

const planElementTargetMaximums = <String, int>{
  'level': 90,
  'bond_rank': 100,
  'student_star': 5,
  'weapon_level': 60,
  'weapon_star': 4,
  'ex_skill': 5,
  'skill1': 10,
  'skill2': 10,
  'skill3': 10,
  'equip1_tier': 10,
  'equip2_tier': 10,
  'equip3_tier': 10,
  'equip1_level': 70,
  'equip2_level': 70,
  'equip3_level': 70,
  'equip4_tier': 2,
  'stat_hp': 25,
  'stat_atk': 25,
  'stat_heal': 25,
};

const planElementTargetMinimums = <String, int>{
  'level': 1,
  'bond_rank': 1,
  'student_star': 1,
  'weapon_level': 0,
  'weapon_star': 0,
  'ex_skill': 1,
  'skill1': 1,
  'skill2': 0,
  'skill3': 0,
  'equip1_tier': 0,
  'equip2_tier': 0,
  'equip3_tier': 0,
  'equip1_level': 0,
  'equip2_level': 0,
  'equip3_level': 0,
  'equip4_tier': 0,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
};

const equipmentTierMaximumLevels = <int, int>{
  0: 0,
  1: 10,
  2: 20,
  3: 30,
  4: 40,
  5: 45,
  6: 50,
  7: 55,
  8: 60,
  9: 65,
  10: 70,
};

const weaponStarMaximumLevels = <int, int>{0: 0, 1: 30, 2: 40, 3: 50, 4: 60};
const studentStarMaximumBondRanks = <int, int>{
  1: 10,
  2: 10,
  3: 20,
  4: 20,
  5: 100,
};

const equipmentSlotUnlockLevels = <int, int>{2: 10, 3: 20};
const favoriteItemUnlockBondRanks = <int, int>{1: 20, 2: 25};

int minimumEquipmentTierForLevel(int level) {
  final normalized = math.max(0, level);
  for (final entry in equipmentTierMaximumLevels.entries) {
    if (normalized <= entry.value) return entry.key;
  }
  return 10;
}

int minimumWeaponStarForLevel(int level) {
  final normalized = math.max(0, level);
  for (final entry in weaponStarMaximumLevels.entries) {
    if (normalized <= entry.value) return entry.key;
  }
  return 4;
}

int minimumStudentStarForBondRank(int bondRank) {
  final normalized = math.max(1, bondRank);
  for (final entry in studentStarMaximumBondRanks.entries) {
    if (normalized <= entry.value) return entry.key;
  }
  return 5;
}

Map<String, int> normalizePlanningGrowthTargets(
  Map<String, int> source, {
  Set<String> changedKeys = const {},
  bool hasFavoriteItem = true,
}) {
  final result = <String, int>{};
  for (final key in planElementTargetMaximums.keys) {
    final minimum = planElementTargetMinimums[key] ?? 0;
    final maximum = planElementTargetMaximums[key]!;
    result[key] = (source[key] ?? minimum).clamp(minimum, maximum);
  }

  for (var slot = 1; slot <= 3; slot++) {
    final tierKey = 'equip${slot}_tier';
    final levelKey = 'equip${slot}_level';
    var tier = result[tierKey]!;
    var level = result[levelKey]!;
    final levelChanged = changedKeys.contains(levelKey);
    final tierChanged = changedKeys.contains(tierKey);
    if (levelChanged && !tierChanged) {
      tier = math.max(tier, minimumEquipmentTierForLevel(level));
    } else {
      level = math.min(level, equipmentTierMaximumLevels[tier]!);
    }
    result[tierKey] = tier;
    result[levelKey] = level;
  }

  var weaponStar = result['weapon_star']!;
  var weaponLevel = result['weapon_level']!;
  if (changedKeys.contains('weapon_level') &&
      !changedKeys.contains('weapon_star')) {
    weaponStar = math.max(weaponStar, minimumWeaponStarForLevel(weaponLevel));
  } else {
    weaponLevel = math.min(weaponLevel, weaponStarMaximumLevels[weaponStar]!);
  }
  result['weapon_star'] = weaponStar;
  result['weapon_level'] = weaponLevel;

  if (!hasFavoriteItem) {
    result['equip4_tier'] = 0;
  } else if (changedKeys.contains('equip4_tier') &&
      !changedKeys.contains('bond_rank')) {
    result['bond_rank'] = math.max(
      result['bond_rank']!,
      favoriteItemUnlockBondRanks[result['equip4_tier']] ?? 1,
    );
  }

  final studentStarChanged = changedKeys.contains('student_star');
  final studentLevelChanged = changedKeys.contains('level');
  final bondTargetChanged =
      changedKeys.contains('bond_rank') ||
      hasFavoriteItem &&
          changedKeys.contains('equip4_tier') &&
          !changedKeys.contains('bond_rank');
  if (bondTargetChanged && !studentStarChanged) {
    result['student_star'] = math.max(
      result['student_star']!,
      minimumStudentStarForBondRank(result['bond_rank']!),
    );
  }
  if (!studentStarChanged) {
    if (changedKeys.contains('skill2') && result['skill2']! > 0) {
      result['student_star'] = math.max(result['student_star']!, 2);
    }
    if (changedKeys.contains('skill3') && result['skill3']! > 0) {
      result['student_star'] = math.max(result['student_star']!, 3);
    }
    if ((changedKeys.contains('weapon_star') ||
            changedKeys.contains('weapon_level')) &&
        (weaponStar > 0 || weaponLevel > 0)) {
      result['student_star'] = 5;
    }
  }
  if (!studentLevelChanged) {
    for (final entry in equipmentSlotUnlockLevels.entries) {
      final slot = entry.key;
      if ((changedKeys.contains('equip${slot}_tier') ||
              changedKeys.contains('equip${slot}_level')) &&
          (result['equip${slot}_tier']! > 0 ||
              result['equip${slot}_level']! > 0)) {
        result['level'] = math.max(result['level']!, entry.value);
      }
    }
  }
  final statChanged = const {
    'stat_hp',
    'stat_atk',
    'stat_heal',
  }.any(changedKeys.contains);
  final hasStatTarget = const {
    'stat_hp',
    'stat_atk',
    'stat_heal',
  }.any((key) => result[key]! > 0);
  if (statChanged && hasStatTarget) {
    if (!studentLevelChanged) result['level'] = 90;
    if (!studentStarChanged) result['student_star'] = 5;
  }

  final studentStar = result['student_star']!;
  final studentLevel = result['level']!;
  result['bond_rank'] = math.min(
    result['bond_rank']!,
    studentStarMaximumBondRanks[studentStar]!,
  );
  result['skill2'] = studentStar >= 2 ? math.max(1, result['skill2']!) : 0;
  result['skill3'] = studentStar >= 3 ? math.max(1, result['skill3']!) : 0;
  if (studentStar < 5) {
    result['weapon_star'] = 0;
    result['weapon_level'] = 0;
  }
  for (final entry in equipmentSlotUnlockLevels.entries) {
    if (studentLevel >= entry.value) continue;
    result['equip${entry.key}_tier'] = 0;
    result['equip${entry.key}_level'] = 0;
  }
  if (studentLevel < 90 || studentStar < 5) {
    result['stat_hp'] = 0;
    result['stat_atk'] = 0;
    result['stat_heal'] = 0;
  }
  if (hasFavoriteItem) {
    final bondRank = result['bond_rank']!;
    if (bondRank < favoriteItemUnlockBondRanks[1]!) {
      result['equip4_tier'] = 0;
    } else if (bondRank < favoriteItemUnlockBondRanks[2]!) {
      result['equip4_tier'] = math.min(1, result['equip4_tier']!);
    }
  }
  return Map.unmodifiable(result);
}

String? planningGrowthRuleViolation(Map<String, int> targets) {
  for (var slot = 1; slot <= 3; slot++) {
    final tier = targets['equip${slot}_tier'];
    final level = targets['equip${slot}_level'];
    if (tier == null || level == null) continue;
    final maximum = equipmentTierMaximumLevels[tier];
    if (maximum == null || level > maximum) {
      return 'equip$slot level $level exceeds the T$tier cap';
    }
  }
  final weaponStar = targets['weapon_star'] ?? 0;
  final weaponLevel = targets['weapon_level'] ?? 0;
  if (weaponLevel > (weaponStarMaximumLevels[weaponStar] ?? 0)) {
    return 'weapon level $weaponLevel exceeds the $weaponStar-star cap';
  }
  if ((weaponStar > 0 || weaponLevel > 0) &&
      (targets['student_star'] ?? 0) < 5) {
    return 'weapon targets require a 5-star student';
  }
  final studentStar = targets['student_star'] ?? 0;
  final studentLevel = targets['level'] ?? 0;
  final bondRank = targets['bond_rank'] ?? 1;
  if (bondRank > (studentStarMaximumBondRanks[studentStar] ?? 0)) {
    return 'bond rank $bondRank exceeds the $studentStar-star cap';
  }
  if (studentStar < 2 && (targets['skill2'] ?? 0) > 0 ||
      studentStar >= 2 && (targets['skill2'] ?? 0) < 1) {
    return 'skill2 does not match its 2-star unlock state';
  }
  if (studentStar < 3 && (targets['skill3'] ?? 0) > 0 ||
      studentStar >= 3 && (targets['skill3'] ?? 0) < 1) {
    return 'skill3 does not match its 3-star unlock state';
  }
  for (final entry in equipmentSlotUnlockLevels.entries) {
    if (studentLevel >= entry.value) continue;
    if ((targets['equip${entry.key}_tier'] ?? 0) > 0 ||
        (targets['equip${entry.key}_level'] ?? 0) > 0) {
      return 'equipment slot ${entry.key} requires student level ${entry.value}';
    }
  }
  if (const {
        'stat_hp',
        'stat_atk',
        'stat_heal',
      }.any((key) => (targets[key] ?? 0) > 0) &&
      (studentLevel < 90 || studentStar < 5)) {
    return 'ability release targets require level 90 and 5 stars';
  }
  final favoriteTier = targets['equip4_tier'] ?? 0;
  if (favoriteTier > 0 &&
      bondRank < (favoriteItemUnlockBondRanks[favoriteTier] ?? 100)) {
    return 'favorite item T$favoriteTier requires a higher bond rank';
  }
  return null;
}
