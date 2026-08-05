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
}
