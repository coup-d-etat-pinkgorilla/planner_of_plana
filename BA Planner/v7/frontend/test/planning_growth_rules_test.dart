import 'package:ba_planner_v7/ui/models/planning_growth_rules.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, int> _targets() => {
  for (final entry in planElementTargetMinimums.entries) entry.key: entry.value,
};

void main() {
  test('equipment and weapon caps match the v6 growth tables', () {
    expect(equipmentTierMaximumLevels, const {
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
    });
    expect(weaponStarMaximumLevels, const {0: 0, 1: 30, 2: 40, 3: 50, 4: 60});
  });

  test('changing equipment level raises the tier required for that level', () {
    final normalized = normalizePlanningGrowthTargets(
      {..._targets(), 'equip1_tier': 9, 'equip1_level': 70},
      changedKeys: const {'equip1_level'},
    );

    expect(normalized['equip1_tier'], 10);
    expect(normalized['equip1_level'], 70);
  });

  test('an explicit equipment tier clamps an impossible level', () {
    final normalized = normalizePlanningGrowthTargets(
      {..._targets(), 'equip1_tier': 9, 'equip1_level': 70},
      changedKeys: const {'equip1_tier', 'equip1_level'},
    );

    expect(normalized['equip1_tier'], 9);
    expect(normalized['equip1_level'], 65);
  });

  test('weapon level raises weapon and student stars', () {
    final normalized = normalizePlanningGrowthTargets(
      {..._targets(), 'weapon_level': 60},
      changedKeys: const {'weapon_level'},
    );

    expect(normalized['weapon_level'], 60);
    expect(normalized['weapon_star'], 4);
    expect(normalized['student_star'], 5);
  });

  test(
    'explicit weapon star clamps level and still requires student star 5',
    () {
      final normalized = normalizePlanningGrowthTargets(
        {..._targets(), 'weapon_star': 2, 'weapon_level': 60},
        changedKeys: const {'weapon_star', 'weapon_level'},
      );

      expect(normalized['weapon_level'], 40);
      expect(normalized['weapon_star'], 2);
      expect(normalized['student_star'], 5);
    },
  );

  test('favorite equipment is removed for students without that slot', () {
    final normalized = normalizePlanningGrowthTargets({
      ..._targets(),
      'equip4_tier': 2,
    }, hasFavoriteItem: false);

    expect(normalized['equip4_tier'], 0);
  });

  test('semantic validator rejects impossible growth combinations', () {
    expect(
      planningGrowthRuleViolation({
        ..._targets(),
        'equip2_tier': 9,
        'equip2_level': 70,
      }),
      contains('T9'),
    );
    expect(
      planningGrowthRuleViolation({
        ..._targets(),
        'weapon_star': 1,
        'weapon_level': 40,
        'student_star': 5,
      }),
      contains('1-star'),
    );
    expect(
      planningGrowthRuleViolation({
        ..._targets(),
        'weapon_star': 1,
        'weapon_level': 30,
      }),
      contains('5-star student'),
    );
  });

  test('legacy goal projection normalizes level-only equipment targets', () {
    final projected = planningDocumentTargets(
      current: {..._targets(), 'equip1': 'T9', 'equip1_level': 65},
      goal: const {'target_equip1_level': 70},
    );

    expect(projected['equip1_tier'], 10);
    expect(projected['equip1_level'], 70);
  });

  test(
    'legacy goal projection honors an explicit tier by clamping its level',
    () {
      final projected = planningDocumentTargets(
        current: {..._targets(), 'equip1': 'T9', 'equip1_level': 65},
        goal: const {'target_equip1_tier': 9, 'target_equip1_level': 70},
      );

      expect(projected['equip1_tier'], 9);
      expect(projected['equip1_level'], 65);
    },
  );

  test('skill targets raise the student star required to unlock them', () {
    final passive = normalizePlanningGrowthTargets(
      {..._targets(), 'skill2': 5},
      changedKeys: const {'skill2'},
    );
    final sub = normalizePlanningGrowthTargets(
      {..._targets(), 'skill3': 5},
      changedKeys: const {'skill3'},
    );

    expect(passive['student_star'], 2);
    expect(passive['skill2'], 5);
    expect(passive['skill3'], 0);
    expect(sub['student_star'], 3);
    expect(sub['skill2'], 1);
    expect(sub['skill3'], 5);
  });

  test('lowering student star clamps bond, skills, weapon, and stats', () {
    final normalized = normalizePlanningGrowthTargets(
      {
        ..._targets(),
        'level': 90,
        'bond_rank': 100,
        'student_star': 4,
        'weapon_star': 4,
        'weapon_level': 60,
        'skill2': 10,
        'skill3': 10,
        'stat_hp': 25,
      },
      changedKeys: const {'student_star'},
    );

    expect(normalized['bond_rank'], 20);
    expect(normalized['skill2'], 10);
    expect(normalized['skill3'], 10);
    expect(normalized['weapon_star'], 0);
    expect(normalized['weapon_level'], 0);
    expect(normalized['stat_hp'], 0);
  });

  test('equipment slots and ability release raise unlock prerequisites', () {
    final equipment = normalizePlanningGrowthTargets(
      {..._targets(), 'equip3_tier': 1, 'equip3_level': 1},
      changedKeys: const {'equip3_tier', 'equip3_level'},
    );
    final stat = normalizePlanningGrowthTargets(
      {..._targets(), 'stat_atk': 1},
      changedKeys: const {'stat_atk'},
    );

    expect(equipment['level'], 20);
    expect(equipment['equip3_tier'], 1);
    expect(stat['level'], 90);
    expect(stat['student_star'], 5);
    expect(stat['stat_atk'], 1);
  });

  test('bond and favorite item targets enforce star and bond gates', () {
    final bond = normalizePlanningGrowthTargets(
      {..._targets(), 'bond_rank': 21},
      changedKeys: const {'bond_rank'},
    );
    final favorite = normalizePlanningGrowthTargets(
      {..._targets(), 'equip4_tier': 2},
      changedKeys: const {'equip4_tier'},
    );

    expect(bond['student_star'], 5);
    expect(bond['bond_rank'], 21);
    expect(favorite['bond_rank'], 25);
    expect(favorite['student_star'], 5);
    expect(favorite['equip4_tier'], 2);
  });
}
