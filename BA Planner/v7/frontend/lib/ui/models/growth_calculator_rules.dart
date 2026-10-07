// 성장 계산기 목표 행과 계산기 전용 정규화 (FE3-f1, FD-166·FD-167·FD-169).
//
// 계산기 목표는 13행이다. 시안 Calc-Student의 12행에 애장품 행을 더했다(FD-166 (c)).
// 행 하나가 계획 목표 key(`planningDocumentTargetKeys`) 하나 이상을 함께 움직인다.
// - 장비 행은 티어로 움직인다. 티어를 현재보다 올리면 장비 레벨 목표는 그 티어의 최대 레벨이다.
//   스테퍼로 티어를 현재 티어로 되돌리면 장비 레벨 목표도 현재 레벨이다. 빠른 목표 "완전 육성"처럼
//   레벨 목표를 직접 정하면(현재 티어 그대로 Lv만 MAX) 현재 레벨~그 티어 최대 사이에서 그 값을 둔다.
// - 전용무기 행은 ★로 움직인다. ★를 현재보다 올리면 Lv 목표는 그 ★의 최대값이다.
//   ★를 현재로 되돌리면 Lv 목표도 현재 Lv이다(직접 정한 값은 장비와 같은 규칙).
// - 능력 개방 행은 HP/ATK/HEAL 세 값을 한 행으로 다룬다(값은 각각 바꾼다).
// - 애장품 행(`equip4_tier`)도 계산에 넣는다. 애장품이 없는 학생은 이 행을 쓰지 않는다(MAX 0).
// - 목표는 현재값보다 낮아지지 않고 MAX를 넘지 않는다.
// 계획 쪽 [normalizePlanningGrowthTargets]는 바꾸지 않는다. 학생 간 성장 규칙(성급·레벨·인연 조건)은
// 그 함수에 맡기고, 이 파일은 그 앞뒤에 계산기 규칙만 더한다([normalizeGrowthCalculatorTargets]).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show immutable;

import 'planning_growth_rules.dart';

/// 계산기 목표 행(시안 순서 + 애장품). [keys]는 이 행이 움직이는 계획 목표 key다.
enum GrowthCalculatorRow {
  level('레벨', ['level']),
  studentStar('성급', ['student_star']),
  weapon('전용무기', ['weapon_star', 'weapon_level']),
  exSkill('EX 스킬', ['ex_skill']),
  normalSkill('일반 스킬', ['skill1']),
  enhancedSkill('강화 스킬', ['skill2']),
  subSkill('서브 스킬', ['skill3']),
  equipment1('장비 1', ['equip1_tier', 'equip1_level']),
  equipment2('장비 2', ['equip2_tier', 'equip2_level']),
  equipment3('장비 3', ['equip3_tier', 'equip3_level']),
  favoriteItem('애장품', ['equip4_tier']),
  bond('인연', ['bond_rank']),
  abilityRelease('능력 개방', ['stat_hp', 'stat_atk', 'stat_heal']);

  const GrowthCalculatorRow(this.label, this.keys);

  /// 행 이름. 장비 행의 부위 이름(모자 등)은 학생 메타데이터에서 화면이 붙인다.
  final String label;

  /// 이 행이 움직이는 계획 목표 key.
  final List<String> keys;

  /// 스테퍼가 움직이는 key(장비는 티어, 전용무기는 ★). 능력 개방은 [GrowthCalculatorAbility]로 따로 움직인다.
  String get primaryKey => keys.first;

  /// 장비 행이면 슬롯 번호(1~3), 아니면 null.
  int? get equipmentSlot => switch (this) {
    GrowthCalculatorRow.equipment1 => 1,
    GrowthCalculatorRow.equipment2 => 2,
    GrowthCalculatorRow.equipment3 => 3,
    _ => null,
  };
}

/// 능력 개방 행의 세 값.
enum GrowthCalculatorAbility {
  hp('stat_hp', 'HP'),
  atk('stat_atk', 'ATK'),
  heal('stat_heal', 'HEAL');

  const GrowthCalculatorAbility(this.key, this.label);

  final String key;
  final String label;
}

/// 빠른 목표(FD-169 (a)). 고른 행은 MAX로, 나머지 행은 현재값으로 둔다. 행 사이 조건(스킬 → 성급 등)은
/// 정규화가 맞춘다. 단계 프리셋 연결은 FD-074 저장소(FE4-b·c) 전까지 보류한다.
enum GrowthCalculatorQuickTarget {
  fullGrowth('완전 육성'),
  levelAndEquipment('레벨·장비만 MAX'),
  skills('스킬만 MAX');

  const GrowthCalculatorQuickTarget(this.label);

  final String label;

  /// MAX로 올리는 행.
  List<GrowthCalculatorRow> get rows => switch (this) {
    GrowthCalculatorQuickTarget.fullGrowth => GrowthCalculatorRow.values,
    GrowthCalculatorQuickTarget.levelAndEquipment => const [
      GrowthCalculatorRow.level,
      GrowthCalculatorRow.equipment1,
      GrowthCalculatorRow.equipment2,
      GrowthCalculatorRow.equipment3,
    ],
    GrowthCalculatorQuickTarget.skills => const [
      GrowthCalculatorRow.exSkill,
      GrowthCalculatorRow.normalSkill,
      GrowthCalculatorRow.enhancedSkill,
      GrowthCalculatorRow.subSkill,
    ],
  };
}

/// 계산기 목표의 MAX. 애장품이 없는 학생은 `equip4_tier`가 0이다.
Map<String, int> growthCalculatorTargetMaximums({
  required bool hasFavoriteItem,
}) {
  final result = Map<String, int>.of(planElementTargetMaximums);
  if (!hasFavoriteItem) result['equip4_tier'] = 0;
  return Map.unmodifiable(result);
}

/// 이 학생에게 쓰는 행인가. 애장품이 없는 학생은 애장품 행을 쓰지 않는다.
bool growthCalculatorRowAvailable(
  GrowthCalculatorRow row, {
  required bool hasFavoriteItem,
}) => row != GrowthCalculatorRow.favoriteItem || hasFavoriteItem;

/// 이 학생에게 쓰는 행(순서 유지).
List<GrowthCalculatorRow> growthCalculatorRows({
  required bool hasFavoriteItem,
}) => [
  for (final row in GrowthCalculatorRow.values)
    if (growthCalculatorRowAvailable(row, hasFavoriteItem: hasFavoriteItem))
      row,
];

/// 현재값(19 key)을 계획 성장 규칙에 맞춘다. 이미 맞는 값은 그대로다.
Map<String, int> growthCalculatorCurrent(
  Map<String, int> source, {
  required bool hasFavoriteItem,
}) => normalizePlanningGrowthTargets(source, hasFavoriteItem: hasFavoriteItem);

Map<String, int> _bounded(
  Map<String, int> targets,
  Map<String, int> current,
  Map<String, int> maximums,
) => {
  for (final entry in maximums.entries)
    entry.key: (targets[entry.key] ?? current[entry.key]!).clamp(
      math.min(current[entry.key]!, entry.value),
      entry.value,
    ),
};

// 장비 레벨·전용무기 Lv을 행 규칙대로 다시 정한다(위 머리말).
Map<String, int> _withDerivedLevels(
  Map<String, int> targets,
  Map<String, int> current,
) {
  final result = Map<String, int>.of(targets);
  for (var slot = 1; slot <= 3; slot++) {
    final tierKey = 'equip${slot}_tier';
    final levelKey = 'equip${slot}_level';
    final tier = result[tierKey]!;
    final maximum = equipmentTierMaximumLevels[tier]!;
    result[levelKey] = tier > current[tierKey]!
        ? maximum
        : result[levelKey]!.clamp(
            math.min(current[levelKey]!, maximum),
            maximum,
          );
  }
  final weaponStar = result['weapon_star']!;
  final weaponMaximum = weaponStarMaximumLevels[weaponStar]!;
  result['weapon_level'] = weaponStar > current['weapon_star']!
      ? weaponMaximum
      : result['weapon_level']!.clamp(
          math.min(current['weapon_level']!, weaponMaximum),
          weaponMaximum,
        );
  return result;
}

// 스테퍼 한 칸: 장비 티어·전용무기 ★를 [value]로 두고, 레벨은 행 규칙(올리면 그 단계 최대, 아니면 현재).
Map<String, int> _withRowStep(
  Map<String, int> targets,
  Map<String, int> current,
  GrowthCalculatorRow row,
  int value,
  Map<String, int> maximums,
) {
  final result = {...targets, row.primaryKey: value};
  final slot = row.equipmentSlot;
  if (slot != null) {
    final tierKey = 'equip${slot}_tier';
    final levelKey = 'equip${slot}_level';
    final tier = value.clamp(current[tierKey]!, maximums[tierKey]!);
    result[levelKey] = tier > current[tierKey]!
        ? equipmentTierMaximumLevels[tier]!
        : current[levelKey]!;
  } else if (row == GrowthCalculatorRow.weapon) {
    final star = value.clamp(current['weapon_star']!, maximums['weapon_star']!);
    result['weapon_level'] = star > current['weapon_star']!
        ? weaponStarMaximumLevels[star]!
        : current['weapon_level']!;
  }
  return result;
}

/// 계산기 목표 정규화(FD-166 (c)). [current]는 [growthCalculatorCurrent]로 맞춘 현재값이다.
///
/// 순서: ① 현재값~MAX로 자르기 ② 장비 레벨·전용무기 Lv 맞추기(티어·★를 올렸으면 그 단계 최대,
/// 아니면 현재값~그 단계 최대 사이) ③ 계획 성장 규칙
/// [normalizePlanningGrowthTargets]([changedKeys]를 그대로 넘긴다) ④ 다시 현재값~MAX로 자르기
/// ⑤ 다시 ②. 현재값과 ③의 결과가 둘 다 성장 규칙에 맞으면 key마다 큰 값을 고른 결과도 맞는다.
/// 그래서 ④·⑤ 뒤에도 [planningGrowthRuleViolation]이 없다(테스트가 확인한다).
Map<String, int> normalizeGrowthCalculatorTargets({
  required Map<String, int> current,
  required Map<String, int> targets,
  Set<String> changedKeys = const {},
  required bool hasFavoriteItem,
}) {
  final maximums = growthCalculatorTargetMaximums(
    hasFavoriteItem: hasFavoriteItem,
  );
  var result = _withDerivedLevels(
    _bounded(targets, current, maximums),
    current,
  );
  result = Map.of(
    normalizePlanningGrowthTargets(
      result,
      changedKeys: changedKeys,
      hasFavoriteItem: hasFavoriteItem,
    ),
  );
  result = _withDerivedLevels(_bounded(result, current, maximums), current);
  assert(planningGrowthRuleViolation(result) == null);
  return Map.unmodifiable(result);
}

/// [row]의 스테퍼 값(장비는 티어, 전용무기는 ★). 능력 개방 행은 세 값의 합이다.
int growthCalculatorRowValue(Map<String, int> values, GrowthCalculatorRow row) {
  if (row == GrowthCalculatorRow.abilityRelease) {
    return row.keys.fold(0, (sum, key) => sum + values[key]!);
  }
  return values[row.primaryKey]!;
}

/// [targets]의 [row] 스테퍼 값을 [value]로 바꾼 정규화 결과. 능력 개방 행은
/// [growthCalculatorWithAbility]를 쓴다.
Map<String, int> growthCalculatorWithRow({
  required Map<String, int> current,
  required Map<String, int> targets,
  required GrowthCalculatorRow row,
  required int value,
  required bool hasFavoriteItem,
}) {
  if (row == GrowthCalculatorRow.abilityRelease) {
    throw ArgumentError.value(row, 'row', 'use growthCalculatorWithAbility');
  }
  return normalizeGrowthCalculatorTargets(
    current: current,
    targets: _withRowStep(
      targets,
      current,
      row,
      value,
      growthCalculatorTargetMaximums(hasFavoriteItem: hasFavoriteItem),
    ),
    changedKeys: row.keys.toSet(),
    hasFavoriteItem: hasFavoriteItem,
  );
}

/// [targets]의 능력 개방 [ability] 값을 [value]로 바꾼 정규화 결과.
Map<String, int> growthCalculatorWithAbility({
  required Map<String, int> current,
  required Map<String, int> targets,
  required GrowthCalculatorAbility ability,
  required int value,
  required bool hasFavoriteItem,
}) => normalizeGrowthCalculatorTargets(
  current: current,
  targets: {...targets, ability.key: value},
  changedKeys: {ability.key},
  hasFavoriteItem: hasFavoriteItem,
);

/// [targets]에서 [row]의 key를 [values]로 바꾼 정규화 결과(되돌리기·토글).
Map<String, int> growthCalculatorWithRowValues({
  required Map<String, int> current,
  required Map<String, int> targets,
  required GrowthCalculatorRow row,
  required Map<String, int> values,
  required bool hasFavoriteItem,
}) => normalizeGrowthCalculatorTargets(
  current: current,
  targets: {
    ...targets,
    for (final key in row.keys) key: values[key]!,
  },
  changedKeys: row.keys.toSet(),
  hasFavoriteItem: hasFavoriteItem,
);

/// 빠른 목표를 고른 결과(FD-169). 고른 행은 MAX, 나머지 행은 현재값에서 시작한다.
Map<String, int> growthCalculatorQuickTargets({
  required Map<String, int> current,
  required GrowthCalculatorQuickTarget quickTarget,
  required bool hasFavoriteItem,
}) {
  final maximums = growthCalculatorTargetMaximums(
    hasFavoriteItem: hasFavoriteItem,
  );
  final keys = {for (final row in quickTarget.rows) ...row.keys};
  return normalizeGrowthCalculatorTargets(
    current: current,
    targets: {
      ...current,
      for (final key in keys) key: maximums[key]!,
    },
    changedKeys: keys,
    hasFavoriteItem: hasFavoriteItem,
  );
}

/// [row]가 현재값과 다른가(S3에서 분홍으로 그리는 칸).
bool growthCalculatorRowChanged(
  Map<String, int> current,
  Map<String, int> targets,
  GrowthCalculatorRow row,
) => row.keys.any((key) => targets[key] != current[key]);

/// "바뀌는 칸 n · 그대로 m"(FD-167). 이 학생에게 쓰는 행만 센다.
@immutable
class GrowthCalculatorCellCounts {
  const GrowthCalculatorCellCounts({
    required this.changing,
    required this.unchanged,
  });

  final int changing;
  final int unchanged;

  @override
  bool operator ==(Object other) =>
      other is GrowthCalculatorCellCounts &&
      other.changing == changing &&
      other.unchanged == unchanged;

  @override
  int get hashCode => Object.hash(changing, unchanged);

  @override
  String toString() => '바뀌는 칸 $changing · 그대로 $unchanged';
}

GrowthCalculatorCellCounts growthCalculatorCellCounts(
  Map<String, int> current,
  Map<String, int> targets, {
  required bool hasFavoriteItem,
}) {
  final rows = growthCalculatorRows(hasFavoriteItem: hasFavoriteItem);
  final changing = rows
      .where((row) => growthCalculatorRowChanged(current, targets, row))
      .length;
  return GrowthCalculatorCellCounts(
    changing: changing,
    unchanged: rows.length - changing,
  );
}

/// "바뀐 목표" 목록의 한 행: 현재값과 목표가 다른 행.
@immutable
class GrowthCalculatorChange {
  GrowthCalculatorChange({
    required this.row,
    required Map<String, int> current,
    required Map<String, int> target,
  }) : current = Map.unmodifiable(current),
       target = Map.unmodifiable(target);

  final GrowthCalculatorRow row;

  /// 이 행 key의 현재값.
  final Map<String, int> current;

  /// 이 행 key의 목표.
  final Map<String, int> target;

  /// 스테퍼 값 차이(장비는 티어, 전용무기는 ★, 능력 개방은 세 값 합).
  int get delta =>
      growthCalculatorRowValue(target, row) -
      growthCalculatorRowValue(current, row);
}

/// 바뀐 행 목록(행 순서). 이 학생에게 쓰는 행만 본다.
List<GrowthCalculatorChange> growthCalculatorChanges(
  Map<String, int> current,
  Map<String, int> targets, {
  required bool hasFavoriteItem,
}) => List.unmodifiable([
  for (final row in growthCalculatorRows(hasFavoriteItem: hasFavoriteItem))
    if (growthCalculatorRowChanged(current, targets, row))
      GrowthCalculatorChange(
        row: row,
        current: {for (final key in row.keys) key: current[key]!},
        target: {for (final key in row.keys) key: targets[key]!},
      ),
]);

/// "바뀐 목표" 칩 묶음. 시안 칩: 레벨 +20 · 성급 +2 · 전용무기 ★1 · Lv.30 · 스킬 +17단계 ·
/// 장비 +10티어 · 인연 +8. 시안에 없는 애장품·능력 개방 칩은 같은 말투로 더했다.
enum GrowthCalculatorChangeGroup {
  level,
  studentStar,
  weapon,
  skills,
  equipment,
  favoriteItem,
  bond,
  abilityRelease,
}

@immutable
class GrowthCalculatorChangeChip {
  const GrowthCalculatorChangeChip({required this.group, required this.label});

  final GrowthCalculatorChangeGroup group;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is GrowthCalculatorChangeChip &&
      other.group == group &&
      other.label == label;

  @override
  int get hashCode => Object.hash(group, label);

  @override
  String toString() => label;
}

/// 바뀐 행을 칩으로 묶는다(묶음 순서 = [GrowthCalculatorChangeGroup] 순서).
List<GrowthCalculatorChangeChip> growthCalculatorChangeChips(
  Map<String, int> current,
  Map<String, int> targets, {
  required bool hasFavoriteItem,
}) {
  int delta(Iterable<String> keys) =>
      keys.fold(0, (sum, key) => sum + targets[key]! - current[key]!);
  bool changed(Iterable<String> keys) =>
      keys.any((key) => targets[key] != current[key]);
  const skillKeys = ['ex_skill', 'skill1', 'skill2', 'skill3'];
  const tierKeys = ['equip1_tier', 'equip2_tier', 'equip3_tier'];
  final abilityKeys = GrowthCalculatorRow.abilityRelease.keys;
  return List.unmodifiable([
    if (changed(const ['level']))
      GrowthCalculatorChangeChip(
        group: GrowthCalculatorChangeGroup.level,
        label: '레벨 +${delta(const ['level'])}',
      ),
    if (changed(const ['student_star']))
      GrowthCalculatorChangeChip(
        group: GrowthCalculatorChangeGroup.studentStar,
        label: '성급 +${delta(const ['student_star'])}',
      ),
    if (changed(GrowthCalculatorRow.weapon.keys))
      GrowthCalculatorChangeChip(
        group: GrowthCalculatorChangeGroup.weapon,
        label:
            '전용무기 ★${targets['weapon_star']} · Lv.${targets['weapon_level']}',
      ),
    if (changed(skillKeys))
      GrowthCalculatorChangeChip(
        group: GrowthCalculatorChangeGroup.skills,
        label: '스킬 +${delta(skillKeys)}단계',
      ),
    if (changed(tierKeys))
      GrowthCalculatorChangeChip(
        group: GrowthCalculatorChangeGroup.equipment,
        label: '장비 +${delta(tierKeys)}티어',
      ),
    if (hasFavoriteItem && changed(const ['equip4_tier']))
      GrowthCalculatorChangeChip(
        group: GrowthCalculatorChangeGroup.favoriteItem,
        label: '애장품 T${targets['equip4_tier']}',
      ),
    if (changed(const ['bond_rank']))
      GrowthCalculatorChangeChip(
        group: GrowthCalculatorChangeGroup.bond,
        label: '인연 +${delta(const ['bond_rank'])}',
      ),
    if (changed(abilityKeys))
      GrowthCalculatorChangeChip(
        group: GrowthCalculatorChangeGroup.abilityRelease,
        label: '능력 개방 +${delta(abilityKeys)}',
      ),
  ]);
}
