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
  'skill2': 1,
  'skill3': 1,
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
  if (weaponStar > 0 || weaponLevel > 0) result['student_star'] = 5;
  if (!hasFavoriteItem) result['equip4_tier'] = 0;
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
  return null;
}
