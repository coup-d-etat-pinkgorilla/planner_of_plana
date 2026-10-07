// FE3-d1 필터 선택 값·성장 범위 모델 테스트(FD-053·054·055·056·057·059·063).
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/ui/kit/range_controls.dart';
import 'package:ba_planner_v7/ui/models/student_filter_selection.dart';
import 'package:flutter_test/flutter_test.dart';

StudentCatalogEntry _student(
  String id, {
  String? school,
  String? attackType = 'Explosive',
  String? role,
  String? rarity,
  bool jpOnly = false,
}) => StudentCatalogEntry(
  studentId: id,
  displayName: id,
  templateName: '$id.png',
  group: id,
  variant: null,
  school: school,
  rarity: rarity,
  attackType: attackType,
  defenseType: 'Light',
  combatClass: null,
  role: role,
  position: null,
  jpOnly: jpOnly,
  searchTags: const [],
  krSearchTags: const [],
);

StudentFilterCandidate _candidate(
  String id, {
  String? school,
  String? attackType = 'Explosive',
  String? role,
  bool owned = true,
  bool jpOnly = false,
  Map<String, int> growth = const {},
}) => StudentFilterCandidate(
  student: _student(
    id,
    school: school,
    attackType: attackType,
    role: role,
    jpOnly: jpOnly,
  ),
  owned: owned,
  growth: growth,
);

StudentGrowthRangeRow _row(String key) => studentGrowthRangeRow(key)!;

void main() {
  group('성장 범위 행(FD-053·055·059·063)', () {
    test('그룹과 행이 시안 순서이고 행 목록을 늘릴 수 있는 구조다', () {
      expect(studentGrowthRangeGroups.map((group) => group.label), [
        '기본',
        '스킬',
        '장비 · 능력치',
      ]);
      expect(studentGrowthRangeRows.map((row) => row.label), [
        '학생 레벨',
        '성급',
        '전용무기 레벨',
        '인연 랭크',
        'EX',
        '기본',
        '강화',
        '서브',
        '장비 티어',
        '장비 레벨',
        '애장품',
        '추가 능력치',
      ]);
      // 그룹은 행 목록을 가진 값이라 FE7-d 육성도 행은 "기본" 앞에 더하면 된다.
      final basic = studentGrowthRangeGroups.first;
      expect(basic.rows.first.key, 'level');
      expect(studentGrowthRangeRow('missing'), isNull);
    });

    test('범위와 표시: 스킬 최대 M · 0은 –, 티어 T, 성급 9단계', () {
      expect((_row('level').min, _row('level').max), (1, 90));
      expect((_row('star').min, _row('star').max), (1, 9));
      expect((_row('weapon_level').min, _row('weapon_level').max), (0, 60));
      expect((_row('bond_rank').min, _row('bond_rank').max), (1, 100));
      expect((_row('ex_skill').min, _row('ex_skill').max), (1, 5));
      expect((_row('skill2').min, _row('skill2').max), (0, 10));
      expect((_row('equip_tier').min, _row('equip_tier').max), (0, 10));
      expect((_row('equip_level').min, _row('equip_level').max), (0, 70));
      expect((_row('equip4_tier').min, _row('equip4_tier').max), (0, 2));
      // FD-055 (a): 합이라 0~75.
      expect((_row('stat_sum').min, _row('stat_sum').max), (0, 75));
      expect(_row('stat_sum').caption, 'HP · ATK · HEAL 합');
      expect(_row('equip_tier').caption, '3칸 중 가장 낮은 칸');
      expect(_row('equip_level').caption, '3칸 중 가장 낮은 칸');
      expect(_row('star').caption, '학생 ★ + 전용무기 ★');

      expect(_row('ex_skill').formatValue(5), 'M');
      expect(_row('ex_skill').formatValue(3), '3');
      expect(_row('skill1').formatValue(10), 'M');
      expect(_row('skill2').formatValue(0), '–');
      expect(_row('skill3').formatValue(0), '–');
      expect(_row('equip_tier').formatValue(10), 'T10');
      expect(_row('equip4_tier').formatValue(0), 'T0');
      expect(_row('level').formatValue(70), '70');
      expect(_row('star').formatValue(3), '★3');
      expect(_row('star').formatValue(6), '무기★1');
      expect(_row('star').formatValue(9), '무기★4');
      // 칩 문구(시안 머리 칩 "레벨 70~90", "EX 3~5").
      expect(_row('level').chipText(70, 90), '레벨 70~90');
      expect(_row('ex_skill').chipText(3, 5), 'EX 3~5');
      expect(_row('star').chipText(3, 6), '성급 ★3~무기★1');
      expect(_row('equip_tier').chipText(2, 7), '장비 티어 T2~T7');
      expect(_row('skill2').chipText(0, 5), '강화 –~5');
    });

    test('성급 9단계: 학생★ 5 미만은 학생★, 5면 5 + 전용무기★', () {
      expect(studentStarStep(studentStar: 1, weaponStar: 0), 1);
      expect(studentStarStep(studentStar: 4, weaponStar: 3), 4);
      expect(studentStarStep(studentStar: 5, weaponStar: 0), 5);
      expect(studentStarStep(studentStar: 5, weaponStar: 1), 6);
      expect(studentStarStep(studentStar: 5, weaponStar: 4), 9);
      expect(
        _row('star').read(const {'student_star': 5, 'weapon_star': 2}),
        7,
      );
      expect(starRangeStepCount, 9);
    });

    test('장비 티어·레벨은 3칸 중 가장 낮은 칸, 추가 능력치는 합', () {
      const growth = {
        'equip1_tier': 9,
        'equip2_tier': 4,
        'equip3_tier': 7,
        'equip1_level': 65,
        'equip2_level': 40,
        'equip3_level': 55,
        'stat_hp': 25,
        'stat_atk': 20,
        'stat_heal': 3,
      };
      expect(_row('equip_tier').read(growth), 4);
      expect(_row('equip_level').read(growth), 40);
      expect(_row('stat_sum').read(growth), 48);
      // 상한 판정이 칸별(현행)과 다르다: 최저 칸 4 ≤ 5면 통과한다.
      final ranges = StudentGrowthRanges.none.withBounds(
        _row('equip_tier'),
        0,
        5,
      );
      expect(ranges.matches(growth), isTrue);
      expect(
        StudentGrowthRanges.none
            .withBounds(_row('equip_tier'), 5, 10)
            .matches(growth),
        isFalse,
      );
      // 합 48은 0~25 범위 밖이다(FD-055: 25는 각 능력치 최대일 뿐).
      expect(
        StudentGrowthRanges.none
            .withBounds(_row('stat_sum'), 30, 75)
            .matches(growth),
        isTrue,
      );
    });
  });

  group('좁힌 범위', () {
    test('자르기·순서 바로잡기·전체면 조건 없음', () {
      final level = _row('level');
      var ranges = StudentGrowthRanges.none.withBounds(level, 95, 70);
      expect(ranges.bounds(level), (70, 90));
      expect(ranges.isNarrowed('level'), isTrue);
      expect(ranges.narrowedKeys, ['level']);
      ranges = ranges.withBounds(level, 1, 90);
      expect(ranges.isEmpty, isTrue);
      expect(ranges, StudentGrowthRanges.none);
      expect(ranges.bounds(level), (1, 90));

      final a = StudentGrowthRanges.none
          .withBounds(_row('ex_skill'), 3, 5)
          .withBounds(level, 70, 90);
      final b = StudentGrowthRanges.none
          .withBounds(level, 70, 90)
          .withBounds(_row('ex_skill'), 3, 5);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      // 행 순서(그룹 → 행)로 나온다.
      expect(a.narrowedKeys, ['level', 'ex_skill']);
      expect(a.without('level').narrowedKeys, ['ex_skill']);
    });

    test('행마다 최소~최대를 모두 만족해야 한다', () {
      final ranges = StudentGrowthRanges.none
          .withBounds(_row('level'), 70, 90)
          .withBounds(_row('ex_skill'), 3, 5);
      expect(ranges.matches(const {'level': 80, 'ex_skill': 4}), isTrue);
      expect(ranges.matches(const {'level': 69, 'ex_skill': 4}), isFalse);
      expect(ranges.matches(const {'level': 80, 'ex_skill': 2}), isFalse);
      // 값이 없으면 행 최소값으로 본다.
      expect(ranges.matches(const {'ex_skill': 4}), isFalse);
    });
  });

  group('선택 값(FD-056·057)', () {
    final groups = studentCatalogFilterGroups;
    final candidates = [
      _candidate('g1', school: 'Gehenna', role: 'dealer'),
      _candidate('g2', school: 'Gehenna', role: 'tanker', owned: false),
      _candidate('m1', school: 'Millennium', role: 'dealer', jpOnly: true),
      _candidate('m2', school: 'Millennium', role: 'dealer', attackType: 'Mystic'),
      _candidate('t1', school: 'Trinity', role: 'healer', growth: const {'level': 90}),
    ];

    test('같은 그룹 = 또는, 그룹끼리 = 그리고', () {
      final selection = StudentFilterSelection.empty
          .toggle('school', 'Gehenna')
          .toggle('school', 'Millennium')
          .toggle('role', 'dealer');
      final matched = [
        for (final candidate in candidates)
          if (selection.matches(candidate, groups)) candidate.student.studentId,
      ];
      expect(matched, ['g1', 'm1', 'm2']);
      expect(selection.countMatching(candidates, groups), 3);
      // 다시 누르면 빠진다. 빈 그룹은 남기지 않는다.
      final cleared = selection.toggle('role', 'dealer');
      expect(cleared.catalog.containsKey('role'), isFalse);
    });

    test('칩 옆 학생 수: 같은 그룹 조건은 빼고 다른 그룹 조건만 반영한다', () {
      final selection = StudentFilterSelection.empty
          .toggle('school', 'Gehenna')
          .toggle('role', 'dealer');
      // 학교 칩: 학교 조건은 빼고 역할(딜러)만 반영.
      expect(selection.chipCount(candidates, groups, 'school', 'Gehenna'), 1);
      expect(selection.chipCount(candidates, groups, 'school', 'Millennium'), 2);
      expect(selection.chipCount(candidates, groups, 'school', 'Trinity'), 0);
      // 역할 칩: 역할 조건은 빼고 학교(게헨나)만 반영.
      expect(selection.chipCount(candidates, groups, 'role', 'dealer'), 1);
      expect(selection.chipCount(candidates, groups, 'role', 'tanker'), 1);
      // 보유 · 서버 칩도 같은 규칙이다.
      expect(
        selection.chipCount(
          candidates,
          groups,
          studentOwnershipGroupKey,
          studentOwnedValue,
        ),
        1,
      );
      final jp = StudentFilterSelection.empty.toggle('role', 'dealer');
      expect(
        jp.chipCount(
          candidates,
          groups,
          studentOwnershipGroupKey,
          studentExcludeJpOnlyValue,
        ),
        2,
      );
    });

    test('범위도 다른 그룹 조건이다', () {
      final selection = StudentFilterSelection.empty.withRange(
        _row('level'),
        80,
        90,
      );
      expect(selection.countMatching(candidates, groups), 1);
      expect(selection.chipCount(candidates, groups, 'school', 'Trinity'), 1);
      expect(selection.chipCount(candidates, groups, 'school', 'Gehenna'), 0);
    });

    test('보유 · 서버 = S4 토글(FD-057)', () {
      var selection = StudentFilterSelection.empty;
      expect(selection.hidesUnowned, isFalse);
      selection = selection.withHideUnowned(true);
      expect(selection.ownership, {studentOwnedValue});
      expect(selection.hidesUnowned, isTrue);
      expect(
        selection.isSelected(studentOwnershipGroupKey, studentOwnedValue),
        isTrue,
      );
      expect(
        [
          for (final candidate in candidates)
            if (selection.matches(candidate, groups))
              candidate.student.studentId,
        ],
        isNot(contains('g2')),
      );
      // 팝업에서 미보유도 켜면 "미보유 숨김"이 아니다.
      selection = selection.toggle(studentOwnershipGroupKey, studentUnownedValue);
      expect(selection.hidesUnowned, isFalse);
      expect(selection.countMatching(candidates, groups), candidates.length);
      selection = selection.withHideUnowned(true).withHideUnowned(false);
      expect(selection.ownership, isEmpty);

      selection = selection.toggle(
        studentOwnershipGroupKey,
        studentExcludeJpOnlyValue,
      );
      expect(selection.hidesJpOnly, isTrue);
      expect(selection.excludeJpOnly, isTrue);
      expect(selection.withHideJpOnly(false).excludeJpOnly, isFalse);
      expect(selection.countMatching(candidates, groups), 4);
    });

    test('적용 칩 목록·×·지우기', () {
      final selection = StudentFilterSelection.empty
          .toggle('school', 'Millennium')
          .toggle('school', 'Gehenna')
          .toggle('attack_type', 'Explosive')
          .toggle('rarity', '3')
          .withHideJpOnly(true)
          .withRange(_row('ex_skill'), 3, 5)
          .withRange(_row('level'), 70, 90);
      final chips = selection.chips(groups);
      expect(chips.map((chip) => chip.label), [
        '게헨나',
        '밀레니엄',
        '★3',
        '폭발',
        '일본 서버 전용 제외',
        '레벨 70~90',
        'EX 3~5',
      ]);
      expect(selection.activeCount(groups), 7);
      expect(chips.last.isRange, isTrue);
      expect(chips.first.id, 'school-Gehenna');

      final withoutLevel = selection.without(chips[5]);
      expect(withoutLevel.ranges.isNarrowed('level'), isFalse);
      final withoutGehenna = selection.without(chips.first);
      expect(withoutGehenna.catalog['school'], {'Millennium'});
      final withoutJp = selection.without(chips[4]);
      expect(withoutJp.excludeJpOnly, isFalse);

      final kept = selection.withHideUnowned(true).clearedKeepingOwnership();
      expect(kept.catalog, isEmpty);
      expect(kept.ranges.isEmpty, isTrue);
      expect(kept.hidesUnowned, isTrue);
      expect(kept.excludeJpOnly, isTrue);
      expect(selection.clearedRanges().ranges.isEmpty, isTrue);
      expect(selection.clearedRanges().catalog, selection.catalog);
    });

    test('값 비교는 내용으로 한다', () {
      final a = StudentFilterSelection.empty
          .toggle('school', 'Gehenna')
          .withRange(_row('level'), 70, 90);
      final b = StudentFilterSelection(
        catalog: const {
          'school': {'Gehenna'},
          'role': <String>{},
        },
      ).withRange(_row('level'), 70, 90);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == StudentFilterSelection.empty, isFalse);
      expect(StudentFilterSelection.empty.isEmpty, isTrue);
    });
  });

  group('속성 칩 값(FD-059)', () {
    test('시안 순서, catalog에 있는 값만, 화학은 있으면 보인다', () {
      final attack = studentCatalogFilterGroups.firstWhere(
        (group) => group.key == 'attack_type',
      );
      final values = attack.valuesIn([
        _candidate('a', attackType: 'Sonic'),
        _candidate('b', attackType: 'Explosive'),
        _candidate('c', attackType: 'Chemical'),
        _candidate('d', attackType: 'Piercing'),
      ]);
      expect(values, ['Explosive', 'Piercing', 'Sonic', 'Chemical']);
      final school = studentCatalogFilterGroups.firstWhere(
        (group) => group.key == 'school',
      );
      expect(
        school.valuesIn([
          _candidate('a', school: 'Trinity'),
          _candidate('b', school: 'Sakugawa'),
          _candidate('c', school: 'Gehenna'),
        ]),
        ['Gehenna', 'Trinity'],
      );
      expect(studentFilterChipLabel('rarity', '2'), '★2');
      expect(studentFilterChipLabel('attack_type', 'Chemical'), '화학');
    });

    test('심상개화는 비활성 자리로만 있다(FD-054)', () {
      expect(studentPotentialFilterLabel, '심상개화');
      expect(studentPotentialFilterChoices, ['상관없음', '개방', '미개방']);
      expect(studentGrowthRangeRow('potential'), isNull);
    });
  });

  test('현재 값에서 성장 값을 만든다(미보유는 초기 값)', () {
    final student = _student('s', rarity: '3');
    final owned = StudentFilterCandidate.fromValues(
      student: student,
      owned: true,
      currentValues: const {
        'level': 80,
        'student_star': 5,
        'weapon_star': 2,
        'weapon_level': 40,
        'equip1': 'T7',
        'equip2': 'T6',
        'equip3': 'T7',
        'equip1_level': 55,
        'equip2_level': 50,
        'equip3_level': 55,
      },
    );
    expect(_row('level').read(owned.growth), 80);
    expect(_row('star').read(owned.growth), 7);
    expect(_row('equip_tier').read(owned.growth), 6);
    expect(_row('equip_level').read(owned.growth), 50);
    final unowned = StudentFilterCandidate.fromValues(
      student: student,
      owned: false,
      currentValues: const {'level': 80},
    );
    expect(_row('level').read(unowned.growth), 1);
    expect(_row('star').read(unowned.growth), 3);
  });
}
