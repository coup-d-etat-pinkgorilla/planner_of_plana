// FE7-c: 통계 인벤토리 현황 · 계획 집계 projection(FD-031 · FD-032 · FD-033 · FD-034 · FD-105, 시안 Stats-Inventory ·
// Stats-Plan). 식은 인벤토리 화면(FE6)과 같은 함수여야 하고, 서로 다른 재화의 수량을 더하지 않는다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_supply_projection.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_growth_fixture.dart';
import 'statistics_supply_fixture.dart';

StatisticsSupply _fixture() => StatisticsSupply.build(
  catalog: statisticsSupplyFixtureCatalog,
  state: statisticsSupplyFixtureState(),
  shortages: statisticsSupplyFixtureShortages(),
  growth: buildStatisticsGrowth(
    state: statisticsSupplyFixtureState(),
    catalog: statisticsGrowthFixtureCatalog(),
  ),
)!;

InventoryShortageRow _row(
  String key,
  String category,
  int required,
  int? owned, {
  int students = 1,
}) => InventoryShortageRow(
  resourceKey: key,
  itemId: key,
  displayName: key,
  category: category,
  requiredAmount: required,
  owned: owned,
  shortage: owned == null ? null : (required - owned).clamp(0, required),
  affectedStudentIds: [for (var index = 0; index < students; index++) 's$index'],
  resolved: true,
);

StatisticsSupply _rows(List<InventoryShortageRow> rows) => StatisticsSupply.build(
  catalog: const [],
  state: null,
  shortages: InventoryShortageResult(rows, const []),
)!;

void main() {
  test('fixture reproduces the Stats-Inventory KPI and B1 numbers', () {
    final supply = _fixture();
    final kpis = supply.kpis;
    expect(statisticsFillText(kpis.fulfillment), '72%');
    expect(kpis.fulfillment, closeTo(0.7205, 0.0005));
    expect(kpis.shortageKinds, 14);
    expect(kpis.excessKinds, 6);
    expect(kpis.unknownKinds, 1);
    expect(supply.unknownLabels, [StatisticsSupplyFixtureExpected.unknownLabel]);
    expect(
      supply.categories.map((fill) => fill.label),
      StatisticsSupplyFixtureExpected.b1Labels,
    );
    expect(
      supply.categories.map((fill) => statisticsFillText(fill.fulfillment)),
      StatisticsSupplyFixtureExpected.b1Percents,
    );
    expect(supply.metCategoryCount, 3);
    expect(supply.categories, hasLength(6));
    expect(supply.planStudentCount, StatisticsSupplyFixtureExpected.planStudents);
  });

  test('fill rates reuse the inventory screen functions (FE6 rule)', () {
    final supply = _fixture();
    final board = InventoryBoard.build(
      catalog: statisticsSupplyFixtureCatalog,
      inventory: statisticsSupplyFixtureState().inventory,
      shortages: statisticsSupplyFixtureShortages(),
    );
    expect(supply.kpis.fulfillment, board.kpis.fulfillment);
    expect(supply.kpis.shortageKinds, board.kpis.shortageKinds);
    expect(supply.kpis.excessKinds, board.kpis.excessKinds);
    for (final fill in supply.categories) {
      final coverage = inventoryCoverageOf(
        board.items.where((view) => view.item.category == fill.category),
      );
      expect(fill.fulfillment, coverage.fulfillment, reason: fill.category);
      expect(fill.coverage.unknownKinds, coverage.unknownKinds);
    }
  });

  test('category fill is the plain mean of per-resource fill, never a quantity sum', () {
    final supply = _rows([
      _row('note-a', 'tech_notes', 2, 1),
      _row('note-b', 'tech_notes', 1000, 900),
      _row('note-c', 'tech_notes', 10, null),
      _row('bd-a', 'tactical_bd', 10, 30),
      _row('eleph', 'student_eleph', 5, null),
      _row('credits', 'credits', 100, 10),
      _row('unused', 'oopart', 0, 3),
    ]);
    final notes = supply.category('tech_notes')!;
    // 수량 합산이면 901 / 1002 = 89.9%다. FD-032는 (50% + 90%) / 2 = 70%, 모름 1종은 뺀다.
    expect(notes.fulfillment, closeTo(0.7, 1e-12));
    expect(notes.coverage.plannedKinds, 3);
    expect(notes.coverage.unknownKinds, 1);
    expect(supply.category('tactical_bd')!.fulfillment, 1);
    expect(supply.category('student_eleph')!.fulfillment, isNull);
    expect(supply.category('student_eleph')!.met, isFalse);
    // 재화는 카테고리 막대가 아니고, 필요 0은 계획 재화가 아니다.
    expect(supply.category('credits'), isNull);
    expect(supply.category('oopart'), isNull);
    expect(supply.categories.map((fill) => fill.category), [
      'tech_notes',
      'tactical_bd',
      'student_eleph',
    ]);
    // 전체 충족률은 크레딧 포함(FD-031): (50 + 90 + 100 + 10) / 4.
    expect(supply.kpis.fulfillment, closeTo(0.625, 1e-12));
    expect(supply.unknownLabels, ['기술 노트', '엘레프']);
  });

  test('C1 sorts by owned / required with unknown last, five rows', () {
    final supply = _fixture();
    expect(supply.c1Rows.map((view) => view.item.displayName), [
      '크레딧',
      '엘리그마',
      '네브라 디스크 T4',
      '님루드 렌즈 T3',
      '기술 노트 (상급)',
    ]);
    final small = _rows([
      _row('unknown', 'tech_notes', 10, null, students: 9),
      _row('over', 'tech_notes', 10, 30),
      _row('met', 'tech_notes', 10, 10),
      _row('half-few', 'tech_notes', 10, 5, students: 1),
      _row('half-many', 'tech_notes', 10, 5, students: 4),
    ]);
    expect(small.c1Rows.map((view) => view.key), [
      'half-many',
      'half-few',
      'met',
      'over',
      'unknown',
    ]);
    expect(statisticsSupplyRatio(small['over']!), 3);
    expect(statisticsSupplyRatio(small['unknown']!), isNull);
  });

  test('C2 plots known resources with the zone rule and axis maximum', () {
    final supply = _fixture();
    final points = supply.c2Points;
    expect(points, hasLength(statisticsSupplyFixtureRows.length - 1));
    expect(supply.c2MaxStudents, 8);
    expect(
      points.where((point) => point.inZone).map((point) => point.view.key),
      unorderedEquals([
        'credits',
        'Item_Icon_SecretStone',
        'Item_Icon_Material_Nebra_3',
        'Item_Icon_Material_Nimrud_2',
      ]),
    );
    // 50% 미만이어도 학생 2명이면 구역 밖, 학생이 많아도 50% 이상이면 구역 밖.
    final notes = points.firstWhere(
      (point) => point.view.key == 'Item_Icon_SkillBook_Abydos_2',
    );
    expect(notes.fulfillment, closeTo(0.48, 1e-12));
    expect(notes.inZone, isFalse);
    final top = points.firstWhere(
      (point) => point.view.key == 'Item_Icon_SkillBook_Abydos_3',
    );
    expect(top.students, 6);
    expect(top.inZone, isFalse);
    // 축 최대는 최소 4(구역 아래 끝 3명이 축 안).
    expect(_rows([_row('a', 'tech_notes', 10, 1)]).c2MaxStudents, 4);
  });

  test('no shortage calculation means no projection; currency-only plan has no B1', () {
    expect(
      StatisticsSupply.build(catalog: const [], state: null, shortages: null),
      isNull,
    );
    final currencies = _rows([_row('credits', 'credits', 100, 50)]);
    expect(currencies.categories, isEmpty);
    expect(currencies.c1Rows, hasLength(1));
    expect(currencies.metCategoryCount, 0);
  });

  test('unplanned low growth counts owned students without goals under 40%', () {
    final growth = buildStatisticsGrowth(
      state: statisticsSupplyFixtureState(),
      catalog: statisticsGrowthFixtureCatalog(),
    )!;
    final expected = growth.students
        .where(
          (student) =>
              !student.planned &&
              student.growth != null &&
              student.growth! < 0.4,
        )
        .length;
    expect(expected, greaterThan(0));
    expect(statisticsUnplannedLowCount(growth), expected);
    expect(_fixture().unplannedLowCount, expected);
    expect(statisticsUnplannedLowCount(null), isNull);
  });

  test('amount text uses M for millions and plain integers below', () {
    expect(statisticsAmountText(98400000), '98.4M');
    expect(statisticsAmountText(261500000), '261.5M');
    expect(statisticsAmountText(2000000), '2M');
    expect(statisticsAmountText(1020), '1020');
    expect(statisticsAmountText(0), '0');
    expect(statisticsAmountText(null), '—');
    expect(statisticsFillText(null), '—');
    expect(statisticsFillText(0.775), '78%');
  });
}
