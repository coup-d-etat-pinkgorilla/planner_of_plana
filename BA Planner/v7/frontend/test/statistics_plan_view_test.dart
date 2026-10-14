// FE7-g: 통계 계획 집계가 활성 계획 문서 계산을 읽는다(KPI 첫 부족 · 막힌 학생 · 범위 칩 페이즈 수 · C3 · C1 페이즈 순 ·
// 근거 "막히는 단계", 시안 Stats-Plan).
//
// 부족 계산 fixture(`statistics_supply_fixture.dart`, FE7-c) 위에 활성 문서 · 문서 계산 fixture(`statistics_plan_fixture.dart`)를
// 더한 통계 페이지로 확인한다. 기준 viewport 콘텐츠 캔버스 2560×1208에서 시안 좌표(y − 184)와 비교하고, 섹션 안 요소는 ±2px.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_supply_projection.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/kpi_tile.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:ba_planner_v7/ui/kit/titles.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_plan_charts.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_supply_charts.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_growth_fixture.dart';
import 'statistics_plan_fixture.dart';
import 'statistics_supply_fixture.dart';

const _canvas = Size(2560, 1208);
const _header = 184.0;
const _profileId = '0123456789abcdef01234567';

class _PlanService extends MockAppService {
  _PlanService({
    this.planFailure = false,
    this.noCalculation = false,
    this.owned = statisticsPlanFixtureOwned,
  });

  final bool planFailure;
  final bool noCalculation;
  final Map<String, int?> owned;
  int planCalls = 0, documentCalls = 0;
  Map<String, dynamic> lastDocument = const {};

  @override
  Future<List<RepositoryProfile>> listProfiles() async => const [
    RepositoryProfile(
      id: _profileId,
      displayName: 'Main',
      revision: 1,
      selected: true,
    ),
  ];

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async =>
      statisticsSupplyFixtureState(profileId: profileId);

  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async {
    planCalls++;
    if (planFailure) throw StateError('plan fixture failure');
    final plan = statisticsPlanFixturePlan(profileId: profileId);
    if (!noCalculation) return plan;
    return RepositoryPlanState.fromWire({
      'profile_id': profileId,
      'revision': plan.revision,
      'document': plan.document.toWire(),
      'calculation': null,
    });
  }

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    documentCalls++;
    lastDocument = document;
    return statisticsPlanFixtureProjection(owned: owned);
  }

  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      statisticsGrowthFixtureCatalog();

  @override
  Future<InventoryCatalogResult> listInventoryItems() async =>
      InventoryCatalogResult(
        catalogRevision: '0' * 64,
        items: statisticsSupplyFixtureCatalog,
      );

  @override
  Future<InventoryShortageResult> calculateShortages({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> plan,
    required Map<String, dynamic> inventory,
  }) async => statisticsSupplyFixtureShortages();
}

Future<_PlanService> _pump(
  WidgetTester tester, {
  Size size = _canvas,
  _PlanService? service,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final subject = service ?? _PlanService();
  addTearDown(subject.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatisticsPage(service: subject, onOpen: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('statistics-topic-plan')));
  await tester.pumpAndSettle();
  return subject;
}

void _expectRect(
  WidgetTester tester,
  Finder finder,
  double x,
  double y,
  double width,
  double height, {
  double tolerance = 2,
  String? reason,
}) {
  final rect = tester.getRect(finder);
  expect(rect.left, closeTo(x, tolerance), reason: '$reason left');
  expect(rect.top, closeTo(y - _header, tolerance), reason: '$reason top');
  expect(rect.width, closeTo(width, tolerance), reason: '$reason width');
  expect(rect.height, closeTo(height, tolerance), reason: '$reason height');
}

Offset _chartPoint(
  WidgetTester tester,
  String key,
  Size viewBox,
  Offset point,
) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return rect.topLeft + point * (rect.width / viewBox.width);
}

Future<void> _tapC1(WidgetTester tester, int row) async {
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-c1-chart',
      statisticsC1ViewBox,
      Offset(200, StatisticsC1Geometry.baselineOf(row) - 8),
    ),
  );
  await tester.pumpAndSettle();
}

/// C2 기술 노트 (최상급) 점(충족 96 / 120 = 80% · 학생 6명, 세로축 8).
Future<void> _tapTechNote(WidgetTester tester) async {
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-c2-chart',
      statisticsC2ViewBox,
      Offset(StatisticsC2Geometry.xOf(0.8), StatisticsC2Geometry.yOf(6, 8)),
    ),
  );
  await tester.pumpAndSettle();
}

List<KpiTile> _kpis(WidgetTester tester) => [
  for (var index = 0; index < 5; index++)
    tester.widget<KpiTile>(
      find.descendant(
        of: find.byKey(ValueKey('statistics-kpi-plan-$index')),
        matching: find.byType(KpiTile),
      ),
    ),
];

SkewSegmented<int> _seg(WidgetTester tester) => tester.widget<SkewSegmented<int>>(
  find.byKey(const ValueKey('statistics-tile-C1-seg')),
);

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String _title(WidgetTester tester) => tester
    .widget<PanelTitle>(find.byKey(const ValueKey('statistics-evidence-title')))
    .title;

T _painter<T extends StatChartPainter>(WidgetTester tester, String key) =>
    tester.widget<StatChartFrame>(find.byKey(ValueKey(key))).painter as T;

String? _note(WidgetTester tester) {
  final finder = find.byKey(const ValueKey('statistics-evidence-note'));
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).data;
}

int _unplannedLow() => statisticsUnplannedLowCount(
  buildStatisticsGrowth(
    state: statisticsSupplyFixtureState(),
    catalog: statisticsGrowthFixtureCatalog(),
  ),
)!;

void main() {
  testWidgets('plan KPI, scope chip and C3 read the active document calculation', (
    tester,
  ) async {
    final service = await _pump(tester);
    // 활성 계획을 한 번 읽고, 그 문서를 그대로 계산에 보낸다.
    expect(service.planCalls, 1);
    expect(service.documentCalls, 1);
    expect(
      service.lastDocument,
      statisticsPlanFixtureDocument().toWire(),
    );
    final kpis = _kpis(tester);
    expect([for (final kpi in kpis) kpi.value], [
      '72%',
      '14종',
      StatisticsPlanFixtureExpected.firstPhase,
      '${StatisticsPlanFixtureExpected.blockedStudents}명',
      '${_unplannedLow()}명',
    ]);
    // 첫 부족: 분홍 "P2" + 계획 색 재화 이름(시안), 막힌 학생 증감은 FE7-h라 '—'.
    expect(kpis[2].valueColor, AppColors.accent);
    expect(kpis[2].delta, StatisticsPlanFixtureExpected.firstResource);
    expect(kpis[2].deltaTone, KpiDeltaTone.plan);
    expect(kpis[3].delta, '—');
    expect(find.text(StatisticsPlanFixtureExpected.scope), findsOneWidget);
    // C3: 재화별 선 세 줄(첫 부족 재화가 처음), 페이즈 P1~P5.
    final c3 = _painter<StatisticsCumulativeShortagePainter>(
      tester,
      'statistics-c3-chart',
    );
    expect(c3.phases, [1, 2, 3, 4, 5]);
    expect([for (final line in c3.lines) line.key], [
      for (final item in StatisticsPlanFixtureExpected.c3) item.$1,
    ]);
    expect(
      [
        for (final line in c3.lines)
          [for (final value in line.values) (value * 100).round()],
      ],
      [for (final item in StatisticsPlanFixtureExpected.c3) item.$2],
    );
    expect(c3.lines.first.label, StatisticsPlanFixtureExpected.firstResource);
    expect(c3.axisMax, closeTo(0.8, 1e-9));
    // 시안 svg 618×259(viewBox 494×207 × 1.25), 타일 안쪽 왼쪽 (561.2, …).
    final chart = tester.getRect(find.byKey(const ValueKey('statistics-c3-chart')));
    expect(chart.left, closeTo(561.2, 2));
    expect(chart.width, closeTo(617.6, 2));
    expect(chart.height, closeTo(258.8, 2));
    final tile = tester.getRect(find.byKey(const ValueKey('statistics-tile-C3')));
    expect(chart.top, greaterThan(tile.top));
    expect(chart.bottom, lessThan(tile.bottom));
    // C5만 "준비 중"(FD-106, C4는 FE7-f 그래프).
    expect(find.text(statisticsTilePendingText), findsOneWidget);
    expect(_note(tester), statisticsPlanEvidenceEmptyText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('C1 phase order sorts by the first shortage phase', (
    tester,
  ) async {
    await _pump(tester);
    final seg = _seg(tester);
    expect([for (final item in seg.segments) item.enabled], [true, true]);
    expect(seg.selected, 0);
    final before = [
      for (final row in _painter<StatisticsBulletPainter>(
        tester,
        'statistics-c1-chart',
      ).rows)
        row.key,
    ];
    expect(before.first, 'credits');
    await tester.tap(find.text('페이즈 순'));
    await tester.pumpAndSettle();
    expect(_seg(tester).selected, 1);
    final rows = _painter<StatisticsBulletPainter>(
      tester,
      'statistics-c1-chart',
    ).rows;
    expect([for (final row in rows.take(3)) row.key], [
      statisticsPlanFixtureTechNote,
      statisticsPlanFixtureEligma,
      statisticsPlanFixtureWatch,
    ]);
    expect(rows[3].key, 'credits');
    // 고른 C1 행은 순서를 바꾸면 풀린다.
    await _tapC1(tester, 0);
    expect(_title(tester), '기술 노트 (최상급)');
    await tester.tap(find.text('부족 큰 순'));
    await tester.pumpAndSettle();
    expect(_seg(tester).selected, 0);
    expect(_note(tester), statisticsPlanEvidenceEmptyText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short resource opens the Stats-Plan evidence frame', (
    tester,
  ) async {
    await _pump(tester);
    await _tapTechNote(tester);
    expect(_title(tester), '기술 노트 (최상급)');
    final chip = tester.widget<BaChip>(
      find.byKey(const ValueKey('statistics-evidence-count')),
    );
    expect(chip.label, '첫 부족 P2');
    expect(chip.tone, AppTones.pink);
    expect(
      _text(tester, 'statistics-evidence-header-subtitle'),
      'C2에서 고른 병목 · 충족률 80% · 학생 6명',
    );
    // 막히는 단계(시안 (2138.8, 361.2, 381.2×34)) + 단계 행 4(시안 (2108.8, 405.2, 429.2×52) …).
    // 머리 글자 묶음은 34 높이 자리의 세로 가운데에 있다(FE7-c 소제목과 같다).
    final stagesTitle = tester.getRect(
      find.byKey(const ValueKey('statistics-evidence-stages-title')),
    );
    expect(stagesTitle.left, closeTo(2138.8, 2));
    expect(stagesTitle.width, closeTo(381.2, 2));
    expect(stagesTitle.center.dy, closeTo(361.2 + 17 - _header, 2));
    expect(_text(tester, 'statistics-evidence-stages-title-caption'), '단계 순서');
    for (final (index, (phase, student, shortage))
        in StatisticsPlanFixtureExpected.techNoteStages.indexed) {
      final row = find.byKey(ValueKey('statistics-evidence-stage-stage-$student'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text('P$phase')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('−$shortage')),
        findsOneWidget,
      );
      if (index == 0) {
        expect(
          find.descendant(of: row, matching: find.text('$student · 스킬 M')),
          findsOneWidget,
        );
        _expectRect(tester, row, 2108.8, 405.2, 429.2, 52, reason: 'stage 0');
      }
    }
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-evidence-stage-stage-aris')),
      2098.6,
      463.2,
      439.4,
      52,
      reason: 'stage 1',
    );
    // "P2부터 누적 부족 −74"(시안 `.plain` (2071.1, 637.2, 466.9×34)).
    expect(_text(tester, 'statistics-evidence-cumulative-label'), 'P2부터 누적 부족');
    expect(
      _text(tester, 'statistics-evidence-cumulative-value'),
      '−${StatisticsPlanFixtureExpected.techNoteCumulative}',
    );
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-evidence-cumulative')),
      2071.1,
      637.2,
      466.9,
      34,
      reason: 'cumulative',
    );
    // 보유 · 필요 · 부족 줄은 이 틀에 없다. 쓰는 학생은 그 아래.
    expect(find.byKey(const ValueKey('statistics-evidence-fact-owned')), findsNothing);
    expect(
      _text(tester, 'statistics-evidence-users-title-caption'),
      '6명',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a resource without a document shortage keeps the FE7-c frame', (
    tester,
  ) async {
    await _pump(tester);
    await _tapC1(tester, 0);
    expect(_title(tester), '크레딧');
    expect(
      tester
          .widget<BaChip>(find.byKey(const ValueKey('statistics-evidence-count')))
          .label,
      '−62%',
    );
    expect(
      find.byKey(const ValueKey('statistics-evidence-fact-owned')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('statistics-evidence-stages-title')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plan read failure stays inside C3 and disables phase order', (
    tester,
  ) async {
    final service = await _pump(tester, service: _PlanService(planFailure: true));
    expect(service.documentCalls, 0);
    expect(
      _text(tester, 'statistics-tile-C3-empty'),
      startsWith('활성 계획을 읽지 못했습니다'),
    );
    expect([for (final kpi in _kpis(tester)) kpi.value].sublist(2, 4), ['—', '—']);
    expect(find.text('활성 계획 · 9명 · 페이즈 —'), findsOneWidget);
    expect([for (final item in _seg(tester).segments) item.enabled], [true, false]);
    // 다른 주제의 근거 안내는 그대로다.
    expect(_note(tester), statisticsPlanEvidenceEmptyText);
    await tester.tap(find.byKey(const ValueKey('statistics-topic-growth')));
    await tester.pumpAndSettle();
    expect(_note(tester), statisticsEvidenceEmptyText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plan without a calculation summary is not calculated', (
    tester,
  ) async {
    final service = await _pump(
      tester,
      service: _PlanService(noCalculation: true),
    );
    expect(service.documentCalls, 0);
    expect(
      _text(tester, 'statistics-tile-C3-empty'),
      '지금은 활성 계획을 계산할 수 없습니다.',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no shortage: first shortage reads "없음" and C3 shows its text', (
    tester,
  ) async {
    await _pump(
      tester,
      service: _PlanService(
        owned: {for (final key in statisticsPlanFixtureOwned.keys) key: 100000},
      ),
    );
    expect([for (final kpi in _kpis(tester)) kpi.value].sublist(2, 4), [
      '없음',
      '0명',
    ]);
    expect(
      _text(tester, 'statistics-tile-C3-empty'),
      statisticsPlanNoShortageText,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(1280, 720), Size(800, 600)]) {
    testWidgets('plan evidence frame fits ${size.width}x${size.height}', (
      tester,
    ) async {
      await _pump(tester, size: size);
      expect(tester.takeException(), isNull);
      await _tapTechNote(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('statistics-evidence-cumulative')),
        findsOneWidget,
      );
    });
  }
}
