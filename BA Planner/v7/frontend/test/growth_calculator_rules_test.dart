// FE3-f1 성장 계산기 행 규칙·정규화 테스트(FD-166·FD-167·FD-169).
import 'dart:math' as math;

import 'package:ba_planner_v7/ui/models/growth_calculator_rules.dart';
import 'package:ba_planner_v7/ui/models/planning_growth_rules.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 시안 Calc-Student의 현재값(레벨 70, ★3, 전무 없음, 스킬 2·5·5·4, 장비 T7·T7·T6, 인연 12).
Map<String, int> _sampleCurrent({bool hasFavoriteItem = true}) =>
    growthCalculatorCurrent(const {
      'level': 70,
      'bond_rank': 12,
      'student_star': 3,
      'weapon_level': 0,
      'weapon_star': 0,
      'ex_skill': 2,
      'skill1': 5,
      'skill2': 5,
      'skill3': 4,
      'equip1_tier': 7,
      'equip2_tier': 7,
      'equip3_tier': 6,
      'equip1_level': 52,
      'equip2_level': 55,
      'equip3_level': 50,
      'equip4_tier': 0,
      'stat_hp': 0,
      'stat_atk': 0,
      'stat_heal': 0,
    }, hasFavoriteItem: hasFavoriteItem);

Map<String, int> _row(
  Map<String, int> current,
  Map<String, int> targets,
  GrowthCalculatorRow row,
  int value, {
  bool hasFavoriteItem = true,
}) => growthCalculatorWithRow(
  current: current,
  targets: targets,
  row: row,
  value: value,
  hasFavoriteItem: hasFavoriteItem,
);

void main() {
  test('13행: 시안 12행 순서 + 애장품, 19 key를 한 번씩 덮는다', () {
    expect(GrowthCalculatorRow.values.map((row) => row.label), [
      '레벨',
      '성급',
      '전용무기',
      'EX 스킬',
      '일반 스킬',
      '강화 스킬',
      '서브 스킬',
      '장비 1',
      '장비 2',
      '장비 3',
      '애장품',
      '인연',
      '능력 개방',
    ]);
    final keys = [for (final row in GrowthCalculatorRow.values) ...row.keys];
    expect(keys.toSet(), planningDocumentTargetKeys);
    expect(keys.length, planningDocumentTargetKeys.length);
    expect(growthCalculatorRows(hasFavoriteItem: true).length, 13);
    expect(
      growthCalculatorRows(hasFavoriteItem: false),
      isNot(contains(GrowthCalculatorRow.favoriteItem)),
    );
    expect(GrowthCalculatorRow.equipment2.equipmentSlot, 2);
    expect(GrowthCalculatorRow.weapon.equipmentSlot, isNull);
  });

  test('목표가 현재값과 같으면 정규화해도 그대로다', () {
    final current = _sampleCurrent();
    expect(
      normalizeGrowthCalculatorTargets(
        current: current,
        targets: current,
        hasFavoriteItem: true,
      ),
      current,
    );
  });

  test('장비 티어를 올리면 장비 레벨 목표는 그 티어의 최대 레벨이다', () {
    final current = _sampleCurrent();
    var targets = _row(current, current, GrowthCalculatorRow.equipment1, 10);
    expect(targets['equip1_tier'], 10);
    expect(targets['equip1_level'], 70);
    targets = _row(current, targets, GrowthCalculatorRow.equipment1, 8);
    expect(targets['equip1_level'], equipmentTierMaximumLevels[8]);
    // 현재 티어로 되돌리면 레벨도 현재 레벨이다(T7 Lv.52).
    targets = _row(current, targets, GrowthCalculatorRow.equipment1, 7);
    expect(targets['equip1_tier'], 7);
    expect(targets['equip1_level'], 52);
    expect(
      growthCalculatorRowChanged(
        current,
        targets,
        GrowthCalculatorRow.equipment1,
      ),
      isFalse,
    );
  });

  test('계획 쪽 정규화는 그대로다: 티어만 바꾸면 장비 레벨을 올리지 않는다', () {
    final source = {..._sampleCurrent(), 'equip1_tier': 10};
    final planned = normalizePlanningGrowthTargets(
      source,
      changedKeys: const {'equip1_tier'},
    );
    expect(planned['equip1_tier'], 10);
    expect(planned['equip1_level'], 52);
  });

  test('전용무기 행은 ★ 단위로 움직이고 Lv은 그 ★의 최대값, 학생은 ★5가 된다', () {
    final current = _sampleCurrent();
    var targets = _row(current, current, GrowthCalculatorRow.weapon, 1);
    expect(targets['weapon_star'], 1);
    expect(targets['weapon_level'], 30);
    expect(targets['student_star'], 5);
    targets = _row(current, targets, GrowthCalculatorRow.weapon, 3);
    expect(targets['weapon_level'], 50);
    targets = _row(current, targets, GrowthCalculatorRow.weapon, 0);
    expect(targets['weapon_star'], 0);
    expect(targets['weapon_level'], 0);
    // ★ 단위라 전용무기 행 스테퍼 값은 ★다.
    expect(growthCalculatorRowValue(targets, GrowthCalculatorRow.weapon), 0);
  });

  test('전용무기 ★가 이미 있으면 같은 ★에서는 현재 Lv을 지킨다', () {
    final current = growthCalculatorCurrent({
      ..._sampleCurrent(),
      'student_star': 5,
      'weapon_star': 2,
      'weapon_level': 35,
    }, hasFavoriteItem: true);
    var targets = _row(current, current, GrowthCalculatorRow.weapon, 4);
    expect(targets['weapon_level'], 60);
    targets = _row(current, targets, GrowthCalculatorRow.weapon, 2);
    expect(targets['weapon_level'], 35);
  });

  test('능력 개방은 세 값을 한 행으로 다루고 레벨 90·★5를 함께 요구한다', () {
    final current = _sampleCurrent();
    var targets = growthCalculatorWithAbility(
      current: current,
      targets: current,
      ability: GrowthCalculatorAbility.hp,
      value: 5,
      hasFavoriteItem: true,
    );
    targets = growthCalculatorWithAbility(
      current: current,
      targets: targets,
      ability: GrowthCalculatorAbility.heal,
      value: 3,
      hasFavoriteItem: true,
    );
    expect(targets['stat_hp'], 5);
    expect(targets['stat_atk'], 0);
    expect(targets['stat_heal'], 3);
    expect(targets['level'], 90);
    expect(targets['student_star'], 5);
    expect(
      growthCalculatorRowValue(targets, GrowthCalculatorRow.abilityRelease),
      8,
    );
    expect(
      () => _row(current, targets, GrowthCalculatorRow.abilityRelease, 1),
      throwsArgumentError,
    );
  });

  test('애장품 행도 계산에 넣는다: T2는 인연 20, 인연은 ★3을 요구한다', () {
    final current = growthCalculatorCurrent({
      ..._sampleCurrent(),
      'student_star': 2,
      'skill3': 0,
      'bond_rank': 10,
    }, hasFavoriteItem: true);
    final targets = _row(current, current, GrowthCalculatorRow.favoriteItem, 2);
    expect(targets['equip4_tier'], 2);
    expect(targets['bond_rank'], 20);
    expect(targets['student_star'], 3);
    expect(planningGrowthRuleViolation(targets), isNull);
  });

  test('애장품이 없는 학생은 애장품 MAX가 0이다', () {
    final current = _sampleCurrent(hasFavoriteItem: false);
    final targets = _row(
      current,
      current,
      GrowthCalculatorRow.favoriteItem,
      2,
      hasFavoriteItem: false,
    );
    expect(targets['equip4_tier'], 0);
    expect(growthCalculatorTargetMaximums(hasFavoriteItem: false), {
      ...planElementTargetMaximums,
      'equip4_tier': 0,
    });
  });

  test('하한은 현재값, 상한은 MAX다', () {
    final current = _sampleCurrent();
    final lower = _row(current, current, GrowthCalculatorRow.level, 10);
    expect(lower['level'], 70);
    final lowerSkill = _row(current, current, GrowthCalculatorRow.exSkill, 0);
    expect(lowerSkill['ex_skill'], 2);
    final lowerTier = _row(current, current, GrowthCalculatorRow.equipment3, 2);
    expect(lowerTier['equip3_tier'], 6);
    expect(lowerTier['equip3_level'], 50);
    final upper = _row(current, current, GrowthCalculatorRow.level, 120);
    expect(upper['level'], 90);
    final upperBond = _row(current, current, GrowthCalculatorRow.bond, 140);
    expect(upperBond['bond_rank'], 100);
    expect(upperBond['student_star'], 5);
    final upperTier = _row(current, current, GrowthCalculatorRow.equipment2, 13);
    expect(upperTier['equip2_tier'], 10);
    expect(upperTier['equip2_level'], 70);
  });

  test('임의 조작 뒤에도 성장 규칙·하한·상한·장비 레벨 규칙을 지킨다', () {
    final random = math.Random(7);
    final keys = planElementTargetMaximums.keys.toList();
    for (var trial = 0; trial < 300; trial++) {
      final hasFavoriteItem = random.nextInt(10) < 7;
      final current = growthCalculatorCurrent({
        for (final key in keys)
          key:
              (planElementTargetMinimums[key] ?? 0) +
              random.nextInt(
                planElementTargetMaximums[key]! -
                    (planElementTargetMinimums[key] ?? 0) +
                    1,
              ),
      }, hasFavoriteItem: hasFavoriteItem);
      final maximums = growthCalculatorTargetMaximums(
        hasFavoriteItem: hasFavoriteItem,
      );
      var targets = current;
      for (var step = 0; step < 10; step++) {
        final rows = growthCalculatorRows(hasFavoriteItem: hasFavoriteItem);
        final row = rows[random.nextInt(rows.length)];
        if (row == GrowthCalculatorRow.abilityRelease) {
          final ability = GrowthCalculatorAbility.values[random.nextInt(3)];
          targets = growthCalculatorWithAbility(
            current: current,
            targets: targets,
            ability: ability,
            value: random.nextInt(27),
            hasFavoriteItem: hasFavoriteItem,
          );
        } else {
          final key = row.primaryKey;
          targets = growthCalculatorWithRow(
            current: current,
            targets: targets,
            row: row,
            value: random.nextInt(planElementTargetMaximums[key]! + 2),
            hasFavoriteItem: hasFavoriteItem,
          );
          final slot = row.equipmentSlot;
          if (slot != null) {
            final tier = targets['equip${slot}_tier']!;
            expect(
              targets['equip${slot}_level'],
              tier > current['equip${slot}_tier']!
                  ? equipmentTierMaximumLevels[tier]
                  : current['equip${slot}_level'],
            );
          }
          if (row == GrowthCalculatorRow.weapon) {
            final star = targets['weapon_star']!;
            expect(
              targets['weapon_level'],
              star > current['weapon_star']!
                  ? weaponStarMaximumLevels[star]
                  : current['weapon_level'],
            );
          }
        }
        expect(planningGrowthRuleViolation(targets), isNull);
        for (final key in keys) {
          expect(targets[key], inInclusiveRange(current[key]!, maximums[key]!));
        }
        for (var slot = 1; slot <= 3; slot++) {
          final tier = targets['equip${slot}_tier']!;
          if (tier > current['equip${slot}_tier']!) {
            expect(targets['equip${slot}_level'], equipmentTierMaximumLevels[tier]);
          }
        }
      }
    }
  });

  group('빠른 목표(FD-169)', () {
    test('완전 육성은 전 항목 MAX다(같은 티어의 덜 오른 장비 레벨도)', () {
      final current = growthCalculatorCurrent({
        ..._sampleCurrent(),
        'equip3_tier': 10,
        'equip3_level': 26,
      }, hasFavoriteItem: true);
      expect(
        growthCalculatorQuickTargets(
          current: current,
          quickTarget: GrowthCalculatorQuickTarget.fullGrowth,
          hasFavoriteItem: true,
        ),
        planElementTargetMaximums,
      );
      expect(
        growthCalculatorQuickTargets(
          current: _sampleCurrent(hasFavoriteItem: false),
          quickTarget: GrowthCalculatorQuickTarget.fullGrowth,
          hasFavoriteItem: false,
        ),
        growthCalculatorTargetMaximums(hasFavoriteItem: false),
      );
    });

    test('레벨·장비만 MAX는 레벨과 장비 3칸만 올리고 나머지는 현재값이다', () {
      final current = _sampleCurrent();
      final targets = growthCalculatorQuickTargets(
        current: current,
        quickTarget: GrowthCalculatorQuickTarget.levelAndEquipment,
        hasFavoriteItem: true,
      );
      expect(targets['level'], 90);
      for (var slot = 1; slot <= 3; slot++) {
        expect(targets['equip${slot}_tier'], 10);
        expect(targets['equip${slot}_level'], 70);
      }
      for (final key in [
        'student_star',
        'ex_skill',
        'skill1',
        'skill2',
        'skill3',
        'bond_rank',
        'equip4_tier',
        'weapon_star',
      ]) {
        expect(targets[key], current[key], reason: key);
      }
    });

    test('스킬만 MAX는 스킬 4종만 올리고 나머지는 현재값이다', () {
      final current = _sampleCurrent();
      final targets = growthCalculatorQuickTargets(
        current: current,
        quickTarget: GrowthCalculatorQuickTarget.skills,
        hasFavoriteItem: true,
      );
      expect(targets['ex_skill'], 5);
      expect(targets['skill1'], 10);
      expect(targets['skill2'], 10);
      expect(targets['skill3'], 10);
      for (final key in ['level', 'student_star', 'equip1_tier', 'bond_rank']) {
        expect(targets[key], current[key], reason: key);
      }
    });
  });

  test('바뀐 목표 목록·칩·칸 개수', () {
    final current = _sampleCurrent();
    var targets = current;
    targets = _row(current, targets, GrowthCalculatorRow.level, 90);
    targets = _row(current, targets, GrowthCalculatorRow.weapon, 1);
    targets = _row(current, targets, GrowthCalculatorRow.exSkill, 5);
    targets = _row(current, targets, GrowthCalculatorRow.normalSkill, 10);
    for (final row in [
      GrowthCalculatorRow.equipment1,
      GrowthCalculatorRow.equipment2,
      GrowthCalculatorRow.equipment3,
    ]) {
      targets = _row(current, targets, row, 10);
    }
    targets = _row(current, targets, GrowthCalculatorRow.bond, 20);
    final changes = growthCalculatorChanges(
      current,
      targets,
      hasFavoriteItem: true,
    );
    expect(changes.map((change) => change.row), [
      GrowthCalculatorRow.level,
      GrowthCalculatorRow.studentStar,
      GrowthCalculatorRow.weapon,
      GrowthCalculatorRow.exSkill,
      GrowthCalculatorRow.normalSkill,
      GrowthCalculatorRow.equipment1,
      GrowthCalculatorRow.equipment2,
      GrowthCalculatorRow.equipment3,
      GrowthCalculatorRow.bond,
    ]);
    expect(changes.first.delta, 20);
    expect(changes[2].target, {'weapon_star': 1, 'weapon_level': 30});
    expect(
      growthCalculatorChangeChips(
        current,
        targets,
        hasFavoriteItem: true,
      ).map((chip) => chip.label),
      ['레벨 +20', '성급 +2', '전용무기 ★1 · Lv.30', '스킬 +8단계', '장비 +10티어', '인연 +8'],
    );
    expect(
      growthCalculatorCellCounts(current, targets, hasFavoriteItem: true),
      const GrowthCalculatorCellCounts(changing: 9, unchanged: 4),
    );
    expect(
      growthCalculatorCellCounts(current, targets, hasFavoriteItem: false),
      const GrowthCalculatorCellCounts(changing: 9, unchanged: 3),
    );
    expect(
      growthCalculatorChangeChips(current, current, hasFavoriteItem: true),
      isEmpty,
    );
  });
}
