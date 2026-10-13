// FE7-g: 통계 계획 집계의 활성 문서 계산 projection(첫 부족 · 막힌 학생 · C3 누적 부족 · 막히는 단계 · C1 페이즈 순).
//
// 시안 숫자 fixture(`statistics_plan_fixture.dart`)와, 계획 Detail 화면 projection(`PlanDetailData`)과 같은 값인지 본다.
import 'package:ba_planner_v7/statistics/statistics_plan_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_supply_projection.dart';
import 'package:ba_planner_v7/ui/models/plan_scenario_detail.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_plan_charts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_plan_fixture.dart';
import 'statistics_supply_fixture.dart';

StatisticsPlanning _planning({
  Map<String, int?> owned = statisticsPlanFixtureOwned,
}) => StatisticsPlanning.build(
  document: statisticsPlanFixtureDocument(),
  projection: statisticsPlanFixtureProjection(owned: owned),
)!;

List<int> _percents(StatisticsC3Line line) => [
  for (final value in line.values) (value * 100).round(),
];

void main() {
  test('fixture reproduces the Stats-Plan KPI, scope and C3 numbers', () {
    final planning = _planning();
    expect(planning.phaseCount, StatisticsPlanFixtureExpected.phaseCount);
    expect(planning.phaseNumbers, [1, 2, 3, 4, 5]);
    expect(planning.phasesCalculated, isTrue);
    expect(planning.firstShortagePhase, 2);
    expect(
      planning.firstShortage?.tile.name,
      StatisticsPlanFixtureExpected.firstResource,
    );
    expect(
      planning.blockedStudents,
      StatisticsPlanFixtureExpected.blockedStudents,
    );
    expect(planning.knownResources, 3);
    expect(
      [for (final line in planning.c3Lines) line.resourceKey],
      [for (final item in StatisticsPlanFixtureExpected.c3) item.$1],
    );
    expect(
      [for (final line in planning.c3Lines) _percents(line)],
      [for (final item in StatisticsPlanFixtureExpected.c3) item.$2],
    );
    expect([for (final line in planning.c3Lines) line.firstIndex], [1, 2, 3]);
  });

  test('KPI and blocked students reuse the plan Detail projection', () {
    final document = statisticsPlanFixtureDocument();
    final projection = statisticsPlanFixtureProjection();
    final planning = StatisticsPlanning.build(
      document: document,
      projection: projection,
    )!;
    final detail = PlanDetailData.fromProjection(
      document: document,
      projection: projection,
      format: (amount) => '$amount',
    );
    final states = PlanDetailStageStates.fromProjection(projection)!;
    expect(planning.firstShortage?.phase, detail.phaseSummary?.phase);
    expect(
      planning.firstShortage?.tile.resourceKey,
      detail.phaseSummary?.tile.resourceKey,
    );
    expect(planning.firstShortagePhase, planDetailFirstBottleneck(projection));
    // FD-034 (a): m − n.
    expect(
      planning.blockedStudents,
      states.students.length - states.finishingStudents,
    );
    expect(states.students, hasLength(9));
    expect(states.finishingStudents, 3);
  });

  test('cumulative shortage stays per resource and ends at 1 − fill', () {
    final planning = _planning();
    for (final line in planning.lines) {
      final owned = statisticsPlanFixtureOwned[line.resourceKey]!;
      // 마지막 값 = max(0, 전체 필요 − 보유) / 전체 필요(다른 재화 수량을 더하지 않는다, FD-033).
      expect(line.shortage, line.required - owned);
      expect(line.values.last, closeTo(line.shortage / line.required, 1e-9));
      // 누적이라 줄지 않는다.
      for (var index = 1; index < line.values.length; index++) {
        expect(line.values[index], greaterThanOrEqualTo(line.values[index - 1]));
      }
    }
  });

  test('blocking stages follow document order and sum to the shortage', () {
    final planning = _planning();
    final stages = planning.blockingStages(statisticsPlanFixtureTechNote);
    expect([
      for (final stage in stages) (stage.phase, stage.studentId, stage.shortage),
    ], StatisticsPlanFixtureExpected.techNoteStages);
    expect(stages.first.stageName, '스킬 M');
    expect(
      stages.fold<int>(0, (sum, stage) => sum + stage.shortage),
      StatisticsPlanFixtureExpected.techNoteCumulative,
    );
    expect(planning.firstPhaseOf(statisticsPlanFixtureTechNote), 2);
    expect(planning.firstPhaseOf(statisticsPlanFixtureEligma), 3);
    expect(planning.firstPhaseOf(statisticsPlanFixtureWatch), 4);
    expect(planning.firstPhaseOf('credits'), isNull);
    expect(planning.blockingStages('credits'), isEmpty);
  });

  test('unknown holdings drop the line; no shortage means no line', () {
    final unknown = _planning(
      owned: {...statisticsPlanFixtureOwned, statisticsPlanFixtureTechNote: null},
    );
    expect(unknown.knownResources, 2);
    expect([for (final line in unknown.lines) line.resourceKey], [
      statisticsPlanFixtureEligma,
      statisticsPlanFixtureWatch,
    ]);
    expect(unknown.firstShortagePhase, 3);
    final wealthy = _planning(
      owned: {for (final key in statisticsPlanFixtureOwned.keys) key: 100000},
    );
    expect(wealthy.lines, isEmpty);
    expect(wealthy.knownResources, 3);
    expect(wealthy.firstShortage, isNull);
    expect(wealthy.firstShortagePhase, 0);
    expect(wealthy.blockedStudents, 0);
    expect(
      StatisticsPlanning.build(
        document: null,
        projection: statisticsPlanFixtureProjection(),
      ),
      isNull,
    );
  });

  test('C1 phase order puts first-shortage phases first', () {
    final supply = StatisticsSupply.build(
      catalog: statisticsSupplyFixtureCatalog,
      state: statisticsSupplyFixtureState(),
      shortages: statisticsSupplyFixtureShortages(),
    )!;
    final rows = statisticsC1PhaseRows(supply, _planning());
    expect([for (final row in rows) row.key], [
      statisticsPlanFixtureTechNote,
      statisticsPlanFixtureEligma,
      statisticsPlanFixtureWatch,
      // 문서 계산에서 모자라지 않는 재화는 "부족 큰 순" 그대로 뒤에 온다.
      supply.c1Rows[0].key,
      supply.c1Rows[2].key,
    ]);
  });

  test('C3 design coordinates follow the artboard SVG', () {
    // 시안 x: P1 40 · P2 116 · P3 192.1 · P4 268.1 · P5 344.2, 끝 354.2.
    expect(
      [for (var index = 0; index < 5; index++) StatisticsC3Geometry.xOf(index, 5)],
      [
        closeTo(40, 0.05),
        closeTo(116.05, 0.05),
        closeTo(192.1, 0.05),
        closeTo(268.15, 0.05),
        closeTo(344.2, 0.05),
      ],
    );
    // 시안 축: 가장 큰 값 74% → 80% 축, 40% 점선 95.5, 0 = 177.
    final axis = StatisticsC3Geometry.axisMaxOf(0.74);
    expect(axis, closeTo(0.8, 1e-9));
    expect(StatisticsC3Geometry.yOf(0.4, axis), closeTo(95.5, 0.05));
    // 시안 path 꼭짓점(기술 노트 140.3 · 93.5 · 50.7 · 26.2, 엘리그마 152.6 · 132.2 · 115.9, 설계도 158.7 · 146.4).
    final expected = <List<double>>[
      [177, 140.3, 93.5, 50.7, 26.2],
      [177, 177, 152.6, 132.2, 115.9],
      [177, 177, 177, 158.7, 146.4],
    ];
    for (final (index, line) in _planning().c3Lines.indexed) {
      expect(
        [for (final value in line.values) StatisticsC3Geometry.yOf(value, axis)],
        [for (final y in expected[index]) closeTo(y, 0.3)],
      );
    }
    final bounds = statisticsC3StepPath(_planning().c3Lines.first.values, axis)
        .getBounds();
    expect(bounds.left, closeTo(40, 0.05));
    expect(bounds.right, closeTo(354.2, 0.05));
    expect(bounds.top, closeTo(26.2, 0.1));
    expect(bounds.bottom, closeTo(177, 0.05));
    // 작은 값은 20% 축, 넘쳐도 100%.
    expect(StatisticsC3Geometry.axisMaxOf(0.03), closeTo(0.2, 1e-9));
    expect(StatisticsC3Geometry.axisMaxOf(1), closeTo(1, 1e-9));
    // 이름 글자: 가까우면 12 이상 띄운다.
    expect(statisticsC3LabelBaselines([100, 105, 30]), [104, 116, 34]);
  });
}
