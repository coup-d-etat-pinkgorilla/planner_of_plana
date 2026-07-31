/// Canonical students owned by the default mock profile.
///
/// Keep this list explicit so UI snapshots and sorting tests do not change when
/// the bundled catalog is reordered.
const mockOwnedStudentIds = <String>[
  'aru',
  'ayane',
  'airi',
  'akane',
  'akari',
  'ako',
  'aris',
  'asuna',
  'azusa',
  'chise',
  'eimi',
  'fuuka',
  'hanae',
  'hanako',
  'hare',
  'haruka',
  'hasumi',
  'hibiki',
  'hifumi',
  'hina',
  'hinata',
  'himari',
  'hiyori',
  'hoshino',
  'iori',
  'izuna',
  'junko',
  'kayoko',
  'kirino',
  'kotama',
  'maki',
  'mari',
  'mutsuki',
  'nonomi',
  'serika',
  'serina',
  'shiroko',
  'sumire',
  'tsubaki',
  'ui',
  'wakamo',
  'yuuka',
];

/// Builds deterministic mock current-state data with broad, even coverage.
///
/// Levels span 1-90, every star rank appears eight or nine times, and each
/// unique-weapon rank appears among the 5-star students. The modular offsets
/// keep level, star, bond, skill, equipment, and stat progression from moving
/// in lockstep, which makes sorting and display regressions easier to notice.
List<Map<String, dynamic>> buildMockOwnedStudents() {
  final lastIndex = mockOwnedStudentIds.length - 1;
  int spread(int index, int minimum, int maximum) =>
      minimum + (index * (maximum - minimum) / lastIndex).round();

  return List<Map<String, dynamic>>.unmodifiable([
    for (var index = 0; index < mockOwnedStudentIds.length; index++)
      _mockStudent(mockOwnedStudentIds[index], index, spread: spread),
  ]);
}

Map<String, dynamic> _mockStudent(
  String studentId,
  int index, {
  required int Function(int index, int minimum, int maximum) spread,
}) {
  final star = 1 + (index * 3) % 5;
  final weaponUnlocked = star == 5;
  final equipment1Level = spread(index, 1, 70);
  final equipment2Level = spread(
    (index * 11) % mockOwnedStudentIds.length,
    1,
    70,
  );
  final equipment3Level = spread(
    (index * 23) % mockOwnedStudentIds.length,
    1,
    70,
  );

  String equipmentTier(int level) => 'T${1 + (level - 1) ~/ 10}';

  return {
    'version': 1,
    'student_id': studentId,
    'values': {
      'level': spread(index, 1, 90),
      'bond_rank': 1 + (index * 23) % 100,
      'student_star': star,
      'weapon_state': weaponUnlocked ? 'weapon_unlocked' : 'weapon_locked',
      'weapon_star': weaponUnlocked ? 1 + (index ~/ 5) % 4 : 0,
      'weapon_level': weaponUnlocked ? spread(index, 1, 60) : 0,
      'ex_skill': 1 + index % 5,
      'skill1': 1 + (index * 3) % 10,
      'skill2': 1 + (index * 7) % 10,
      'skill3': 1 + (index * 9) % 10,
      'equip1': equipmentTier(equipment1Level),
      'equip2': equipmentTier(equipment2Level),
      'equip3': equipmentTier(equipment3Level),
      'equip4': switch (index % 4) {
        0 => null,
        1 => 'T1',
        2 => 'T2',
        _ => 'love_locked',
      },
      'equip1_level': equipment1Level,
      'equip2_level': equipment2Level,
      'equip3_level': equipment3Level,
      'combat_hp': spread(index, 12000, 999999),
      'combat_atk': spread(
        (index * 5) % mockOwnedStudentIds.length,
        900,
        260000,
      ),
      'combat_def': spread(
        (index * 11) % mockOwnedStudentIds.length,
        100,
        120000,
      ),
      'combat_heal': spread(
        (index * 13) % mockOwnedStudentIds.length,
        700,
        180000,
      ),
      'stat_hp': spread((index * 5) % mockOwnedStudentIds.length, 0, 25),
      'stat_atk': spread((index * 13) % mockOwnedStudentIds.length, 0, 25),
      'stat_heal': spread((index * 19) % mockOwnedStudentIds.length, 0, 25),
    },
  };
}
