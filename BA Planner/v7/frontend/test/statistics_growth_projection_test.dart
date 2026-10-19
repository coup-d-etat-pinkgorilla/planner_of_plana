// FE7-b: 학생 성장 projection(FD-028 (a) · FD-029)과 시안 숫자 fixture.
//
// 대장 문구를 테스트로 고정한다: 항목 완성도 = (현재 − 최소) / (최대 − 최소), 육성도 = 7항목 단순 평균
// (레벨 · EX · 일반 스킬 skill1~3 평균 · 장비 equip1~3 티어 평균 · 애장품 equip4 · 성작 · 전용무기 ★), 인연 · 추가 능력치
// 제외, 미보유 제외, A1 평균 = A2 막대 평균. 착수 때 사용자 확인: 애장품이 없는 학생은 애장품 "해당 없음"(6항목 평균).
import 'dart:convert';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_growth_fixture.dart';

StudentCatalogEntry _entry(String id, {bool favorite = true}) =>
    StudentCatalogEntry(
      studentId: id,
      displayName: id.toUpperCase(),
      templateName: '$id.png',
      group: id,
      variant: null,
      school: null,
      rarity: null,
      attackType: null,
      defenseType: null,
      combatClass: null,
      role: null,
      position: null,
      hasFavoriteItem: favorite,
      searchTags: const [],
      krSearchTags: const [],
    );

/// 모든 항목을 아는 학생 값(기본은 각 항목 50%, 레벨만 45/89).
Map<String, dynamic> _values({
  int level = 46,
  int ex = 3,
  int skill1 = 1,
  int skill2 = 5,
  int skill3 = 10,
  String equip1 = 'T5',
  String equip2 = 'T5',
  String equip3 = 'T10',
  String? equip4 = 'T1',
  int star = 3,
  int weapon = 2,
}) => {
  'level': level,
  'ex_skill': ex,
  'skill1': skill1,
  'skill2': skill2,
  'skill3': skill3,
  'equip1': equip1,
  'equip2': equip2,
  'equip3': equip3,
  'equip4': ?equip4,
  'student_star': star,
  'weapon_star': weapon,
};

RepositoryState _state(
  Map<String, Map<String, dynamic>> students, {
  List<String> goals = const [],
}) => RepositoryState.fromWire({
  'profile_id': '000000000000000000000001',
  'revision': 1,
  'students': [
    for (final entry in students.entries)
      {'version': 1, 'student_id': entry.key, 'values': entry.value},
  ],
  'inventory': {'version': 1, 'entries': <Object>[]},
  'goals': {
    'version': 1,
    'goals': [
      for (final id in goals) {'student_id': id, 'target_level': 90},
    ],
  },
});

void main() {
  test(
    'FD-028 (a): item completion is (current - min) / (max - min) and growth is the 7-item mean',
    () {
      final growth = statisticsStudentGrowth(
        ConfirmedStudentState.fromValues('aru', _values()),
        catalog: _entry('aru'),
      );
      final items = growth.items;
      expect(items[StatisticsGrowthItem.level], closeTo(45 / 89, 1e-12));
      expect(items[StatisticsGrowthItem.exSkill], 0.5); // (3 − 1) / (5 − 1)
      // 일반 스킬 = skill1 (1−1)/9 · skill2 5/10 · skill3 10/10의 평균.
      expect(
        items[StatisticsGrowthItem.normalSkill],
        closeTo((0 + 0.5 + 1) / 3, 1e-12),
      );
      // 장비 = equip1~3 티어 5/10 · 5/10 · 10/10의 평균.
      expect(
        items[StatisticsGrowthItem.equipment],
        closeTo((0.5 + 0.5 + 1) / 3, 1e-12),
      );
      expect(items[StatisticsGrowthItem.favoriteItem], 0.5); // T1 / 2
      expect(items[StatisticsGrowthItem.studentStar], 0.5); // (3 − 1) / 4
      expect(items[StatisticsGrowthItem.weapon], 0.5); // 2 / 4
      expect(items, hasLength(7));
      final expected = (45 / 89 + 0.5 + 0.5 + 2 / 3 + 0.5 + 0.5 + 0.5) / 7;
      expect(growth.growth, closeTo(expected, 1e-12));
    },
  );

  test(
    'bond, ability release, equipment level and weapon level are not growth items',
    () {
      final base = statisticsStudentGrowth(
        ConfirmedStudentState.fromValues('aru', _values()),
        catalog: _entry('aru'),
      ).growth;
      final extra = statisticsStudentGrowth(
        ConfirmedStudentState.fromValues('aru', {
          ..._values(),
          'bond_rank': 100,
          'stat_hp': 25,
          'stat_atk': 25,
          'stat_heal': 25,
          'equip1_level': 70,
          'weapon_level': 60,
        }),
        catalog: _entry('aru'),
      ).growth;
      expect(extra, base);
      expect(StatisticsGrowthItem.values.map((item) => item.label), [
        '레벨',
        'EX 스킬',
        '일반 스킬',
        '장비',
        '애장품',
        '성작',
        '전용무기',
      ]);
    },
  );

  test(
    'A1 mean equals the mean of A2 bars when every student has all 7 items',
    () {
      final growth = buildStatisticsGrowth(
        state: _state({
          'a': _values(level: 90, ex: 5, star: 5, weapon: 4),
          'b': _values(
            level: 1,
            ex: 1,
            skill1: 1,
            skill2: 0,
            skill3: 0,
            equip1: 'T0',
            equip2: 'T1',
            equip3: 'T2',
            equip4: 'T0',
            star: 1,
            weapon: 0,
          ),
          'c': _values(
            level: 70,
            ex: 4,
            skill1: 7,
            skill2: 7,
            skill3: 6,
            equip1: 'T7',
            equip2: 'T8',
            equip3: 'T6',
            equip4: 'T2',
            star: 4,
            weapon: 0,
          ),
        }),
        catalog: [_entry('a'), _entry('b'), _entry('c')],
      )!;
      final bars = growth.itemAverages.values.map((value) => value!).toList();
      expect(bars, hasLength(7));
      final barMean = bars.reduce((a, b) => a + b) / bars.length;
      expect(growth.averageGrowth, closeTo(barMean, 1e-12));
      expect(
        growth.histogram(StatisticsGrowthMetric.growth).mean,
        growth.averageGrowth,
      );
    },
  );

  test(
    'a student without a favorite item averages the other 6 items (user decision 2026-10-13)',
    () {
      final growth = buildStatisticsGrowth(
        state: _state({
          'with': _values(equip4: 'T2'),
          'without': _values(equip4: 'love_locked'),
        }),
        catalog: [_entry('with'), _entry('without', favorite: false)],
      )!;
      final without = growth.students.firstWhere(
        (s) => s.studentId == 'without',
      );
      expect(
        without.items.containsKey(StatisticsGrowthItem.favoriteItem),
        isFalse,
      );
      expect(without.unknownItems, isEmpty);
      expect(without.items, hasLength(6));
      expect(
        without.growth,
        closeTo((45 / 89 + 0.5 + 0.5 + 2 / 3 + 0.5 + 0.5) / 6, 1e-12),
      );
      // A2 애장품 막대는 애장품이 있는 학생만 센다.
      expect(growth.itemAverages[StatisticsGrowthItem.favoriteItem], 1.0);
      expect(
        growth
            .itemStudents(StatisticsGrowthItem.favoriteItem)
            .map((s) => s.studentId),
        ['with'],
      );
      expect(growth.unknownCount, 0);
    },
  );

  test('unknown values are excluded and counted, never filled with 0', () {
    final growth = buildStatisticsGrowth(
      state: _state({
        'known': _values(),
        'no_level': {..._values()}..remove('level'),
        'no_equip4': _values(equip4: null),
        'no_catalog': _values(),
      }),
      catalog: [_entry('known'), _entry('no_level'), _entry('no_equip4')],
    )!;
    expect(growth.ownedCount, 4);
    expect(growth.known.map((s) => s.studentId), ['known']);
    expect(growth.unknownCount, 3);
    final noLevel = growth.students.firstWhere(
      (s) => s.studentId == 'no_level',
    );
    expect(noLevel.growth, isNull);
    expect(noLevel.unknownItems, {StatisticsGrowthItem.level});
    expect(noLevel.level, isNull);
    // 카탈로그에 없으면 애장품 여부를 몰라 모름이다.
    final noCatalog = growth.students.firstWhere(
      (s) => s.studentId == 'no_catalog',
    );
    expect(noCatalog.unknownItems, {StatisticsGrowthItem.favoriteItem});
    expect(noCatalog.displayName, 'no_catalog');
    final histogram = growth.histogram(StatisticsGrowthMetric.growth);
    expect(histogram.knownCount, 1);
    expect(histogram.unknownCount, 3);
    // 레벨 seg는 레벨을 아는 학생 3명을 센다(no_level만 모름).
    expect(growth.histogram(StatisticsGrowthMetric.level).unknownCount, 1);
    expect(growth.maxLevelCount, 0);
    expect(growth.fullGrowthCount, 0);
  });

  test(
    'missing state yields no projection; no owned students yields unknown KPIs',
    () {
      expect(buildStatisticsGrowth(state: null, catalog: const []), isNull);
      final empty = buildStatisticsGrowth(
        state: _state({}),
        catalog: [_entry('a')],
      )!;
      expect(empty.ownedCount, 0);
      expect(empty.catalogCount, 1);
      expect(empty.averageGrowth, isNull);
      expect(empty.maxLevelCount, isNull);
      expect(empty.fullGrowthCount, isNull);
      expect(empty.plannedCount, 0);
      final noCatalog = buildStatisticsGrowth(
        state: _state({}),
        catalog: null,
      )!;
      expect(noCatalog.catalogCount, isNull);
    },
  );

  test('10% bins put boundaries in the upper bin and 100% in the last bin', () {
    expect(statisticsGrowthBinOf(0), 0);
    expect(statisticsGrowthBinOf(0.0999), 0);
    expect(statisticsGrowthBinOf(0.1), 1);
    expect(statisticsGrowthBinOf(0.7), 7);
    expect(statisticsGrowthBinOf(0.6999), 6);
    expect(statisticsGrowthBinOf(1), 9);
    expect(statisticsGrowthBinLabel(6), '60~70%');
    expect(statisticsPercentText(0.63350028, decimals: 1), '63.4%');
    expect(statisticsPercentText(0.8216), '82%');
  });

  test('FD-029: low flags, full growth, max level and evidence order', () {
    final growth = buildStatisticsGrowth(
      state: _state(
        {
          'full': _values(
            level: 90,
            ex: 5,
            skill1: 10,
            skill2: 10,
            skill3: 10,
            equip1: 'T10',
            equip2: 'T10',
            equip3: 'T10',
            equip4: 'T2',
            star: 5,
            weapon: 4,
          ),
          'low_level': _values(
            level: 20,
            ex: 5,
            skill1: 10,
            skill2: 10,
            skill3: 10,
            equip1: 'T10',
            equip2: 'T10',
            equip3: 'T10',
          ),
          'low_skill': _values(
            level: 90,
            ex: 1,
            skill1: 10,
            skill2: 10,
            skill3: 10,
            equip1: 'T10',
            equip2: 'T10',
            equip3: 'T10',
          ),
          'low_equip': _values(
            level: 90,
            ex: 5,
            skill1: 10,
            skill2: 10,
            skill3: 10,
            equip1: 'T2',
            equip2: 'T2',
            equip3: 'T2',
          ),
          'fine': _values(
            level: 90,
            ex: 5,
            skill1: 10,
            skill2: 10,
            skill3: 10,
            equip1: 'T10',
            equip2: 'T10',
            equip3: 'T10',
            star: 1,
            weapon: 0,
          ),
        },
        goals: ['full', 'fine', 'unowned'],
      ),
      catalog: [
        for (final id in [
          'full',
          'low_level',
          'low_skill',
          'low_equip',
          'fine',
        ])
          _entry(id),
      ],
    )!;
    StatisticsStudentGrowth of(String id) =>
        growth.students.firstWhere((s) => s.studentId == id);
    expect(of('full').growth, 1.0);
    expect(of('full').flag, isNull);
    expect(of('low_level').flag, StatisticsGrowthFlag.level);
    expect(of('low_skill').flag, StatisticsGrowthFlag.skill);
    expect(of('low_equip').flag, StatisticsGrowthFlag.equipment);
    // 성작 · 전용무기가 낮아도 칩은 달지 않는다(육성으로 올리는 항목만).
    expect(of('fine').flag, isNull);
    expect(StatisticsGrowthFlag.values.map((flag) => flag.label), [
      '레벨 낮음',
      '스킬 낮음',
      '장비 뒤처짐',
    ]);
    expect(growth.fullGrowthCount, 1);
    expect(growth.maxLevelCount, 4);
    // 계획 등록은 보유 학생만(미보유 목표 'unowned'는 세지 않는다).
    expect(growth.plannedCount, 2);
    // 근거: 낮은 항목 순 = 칩 항목(레벨 · EX · 일반 · 장비) 중 가장 낮은 값 → 육성도 → id.
    final students = [
      for (var bin = 0; bin < statisticsGrowthBinCount; bin++)
        ...growth.binStudents(StatisticsGrowthMetric.growth, bin),
    ];
    expect(students, hasLength(5));
    final weapon = growth
        .itemStudents(StatisticsGrowthItem.weapon)
        .map((s) => s.studentId);
    expect(weapon.first, 'fine');
    expect(weapon.last, 'full');
    final summary = StatisticsGrowthSummary.of([of('full'), of('low_level')]);
    expect(summary.averageLevel, 55);
    expect(summary.plannedCount, 1);
    expect(summary.lowestItem?.item, isNotNull);
  });

  test(
    'A2 emphasizes items below the 60% line, or the lowest one when none is below',
    () {
      final below = buildStatisticsGrowth(
        state: _state({
          'a': _values(
            level: 90,
            ex: 5,
            skill1: 10,
            skill2: 10,
            skill3: 10,
            equip1: 'T10',
            equip2: 'T10',
            equip3: 'T10',
            equip4: 'T2',
            star: 2,
            weapon: 1,
          ),
        }),
        catalog: [_entry('a')],
      )!;
      expect(below.emphasizedItems, {
        StatisticsGrowthItem.studentStar,
        StatisticsGrowthItem.weapon,
      });
      final none = buildStatisticsGrowth(
        state: _state({
          'a': _values(
            level: 90,
            ex: 5,
            skill1: 10,
            skill2: 10,
            skill3: 10,
            equip1: 'T10',
            equip2: 'T10',
            equip3: 'T10',
            equip4: 'T2',
            star: 5,
            weapon: 3,
          ),
        }),
        catalog: [_entry('a')],
      )!;
      expect(none.emphasizedItems, {StatisticsGrowthItem.weapon});
    },
  );

  test('the review fixture reproduces the Stats-Growth artboard numbers', () {
    final growth = buildStatisticsGrowth(
      state: statisticsGrowthFixtureState(),
      catalog: statisticsGrowthFixtureCatalog(),
    )!;
    expect(growth.ownedCount, StatisticsGrowthFixtureExpected.ownedCount);
    expect(growth.catalogCount, StatisticsGrowthFixtureExpected.catalogCount);
    expect(growth.unknownCount, 0);
    final histogram = growth.histogram(StatisticsGrowthMetric.growth);
    expect([
      for (final bin in histogram.bins) bin.length,
    ], StatisticsGrowthFixtureExpected.bins);
    expect(
      statisticsPercentText(growth.averageGrowth!, decimals: 1),
      StatisticsGrowthFixtureExpected.averageGrowthText,
    );
    expect(growth.maxLevelCount, StatisticsGrowthFixtureExpected.maxLevelCount);
    expect(
      growth.fullGrowthCount,
      StatisticsGrowthFixtureExpected.fullGrowthCount,
    );
    expect(growth.plannedCount, StatisticsGrowthFixtureExpected.plannedCount);
    final selected = growth.binStudents(
      StatisticsGrowthMetric.growth,
      StatisticsGrowthFixtureExpected.selectedBin,
    );
    expect(selected, hasLength(22));
    expect(
      StatisticsGrowthSummary.of(selected).plannedCount,
      StatisticsGrowthFixtureExpected.plannedInSelectedBin,
    );
  });

  testWidgets(
    'fixture ids and favorite items match the bundled student catalog',
    (tester) async {
      // loadString은 큰 자산을 isolate로 디코드해 테스트 시계에서 멈추므로 Mock처럼 bytes를 직접 읽는다.
      final data = await rootBundle.load('assets/student_catalog.json');
      final source = utf8.decode(data.buffer.asUint8List());
      final bundled = [
        for (final item in jsonDecode(source) as List)
          StudentCatalogEntry.fromWire(Map<String, dynamic>.from(item as Map)),
      ]..sort((a, b) => a.studentId.compareTo(b.studentId));
      final first = bundled.take(170).toList();
      expect(
        first.map((entry) => entry.studentId),
        statisticsGrowthFixtureCatalogIds,
      );
      expect({
        for (final entry in first)
          if (entry.hasFavoriteItem) entry.studentId,
      }, statisticsGrowthFixtureFavoriteItemIds.toSet());
    },
  );
}
