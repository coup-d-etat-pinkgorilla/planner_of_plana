// FE7-c: 통계 인벤토리 현황 · 계획 집계 화면(KPI · B1 · C1 · C2 · 고르기 → 근거, 시안 Stats-Inventory · Stats-Plan).
//
// 시안 숫자 fixture(`statistics_supply_fixture.dart`)를 읽은 통계 페이지로 확인한다. 기준 viewport 콘텐츠 캔버스
// 2560×1208에서 시안 좌표(y − 184)와 비교하고, 섹션 안 요소는 ±2px.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_supply_projection.dart';
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/kpi_tile.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_growth_evidence.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_supply_charts.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_growth_fixture.dart';
import 'statistics_supply_fixture.dart';

const _canvas = Size(2560, 1208);
const _header = 184.0;

class _SupplyService extends MockAppService {
  _SupplyService({this.noGoals = false, this.noHoldings = false});

  final bool noGoals;
  final bool noHoldings;

  @override
  Future<List<RepositoryProfile>> listProfiles() async => const [
    RepositoryProfile(
      id: '0123456789abcdef01234567',
      displayName: 'Main',
      revision: 1,
      selected: true,
    ),
  ];

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async {
    final base = statisticsSupplyFixtureState(profileId: profileId);
    if (!noGoals && !noHoldings) return base;
    return RepositoryState.fromWire({
      'profile_id': profileId,
      'revision': 1,
      'students': statisticsGrowthFixtureStudentsWire(),
      'inventory': noHoldings
          ? {'version': 1, 'entries': <Object>[]}
          : statisticsSupplyFixtureInventoryWire(),
      'goals': noGoals
          ? {'version': 1, 'goals': <Object>[]}
          : statisticsGrowthFixtureGoalsWire(),
    });
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
  }) async {
    final rows = statisticsSupplyFixtureShortages().rows;
    if (!noHoldings) return InventoryShortageResult(rows, const []);
    return InventoryShortageResult([
      for (final row in rows)
        InventoryShortageRow(
          resourceKey: row.resourceKey,
          itemId: row.itemId,
          displayName: row.displayName,
          category: row.category,
          requiredAmount: row.requiredAmount,
          owned: null,
          shortage: null,
          affectedStudentIds: row.affectedStudentIds,
          resolved: true,
        ),
    ], const []);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = _canvas,
  bool noGoals = false,
  bool noHoldings = false,
  StatisticsMode topic = StatisticsMode.inventory,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final service = _SupplyService(noGoals: noGoals, noHoldings: noHoldings);
  addTearDown(service.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatisticsPage(service: service, onOpen: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final key = switch (topic) {
    StatisticsMode.students => 'growth',
    StatisticsMode.inventory => 'inventory',
    StatisticsMode.plan => 'plan',
  };
  await tester.tap(find.byKey(ValueKey('statistics-topic-$key')));
  await tester.pumpAndSettle();
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

/// 차트 설계 좌표 [point]의 화면 좌표.
Offset _chartPoint(
  WidgetTester tester,
  String key,
  Size viewBox,
  Offset point,
) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return rect.topLeft + point * (rect.width / viewBox.width);
}

Future<void> _tapB1(WidgetTester tester, int row, {int rows = 6}) async {
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-b1-chart',
      statisticsB1ViewBox,
      Offset(200, StatisticsB1Geometry.baselineOf(row, rows) - 8),
    ),
  );
  await tester.pumpAndSettle();
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

Future<void> _tapC2(
  WidgetTester tester,
  double fulfillment,
  int students,
) async {
  await tester.tapAt(
    _chartPoint(
      tester,
      'statistics-c2-chart',
      statisticsC2ViewBox,
      Offset(
        StatisticsC2Geometry.xOf(fulfillment),
        StatisticsC2Geometry.yOf(students, 8),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<KpiTile> _kpis(WidgetTester tester, String topic) => [
  for (var index = 0; index < 5; index++)
    tester.widget<KpiTile>(
      find.descendant(
        of: find.byKey(ValueKey('statistics-kpi-$topic-$index')),
        matching: find.byType(KpiTile),
      ),
    ),
];

String? _note(WidgetTester tester) {
  final finder = find.byKey(const ValueKey('statistics-evidence-note'));
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<Text>(finder).data;
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

BaChip _chip(WidgetTester tester) =>
    tester.widget<BaChip>(find.byKey(const ValueKey('statistics-evidence-count')));

T _painter<T extends StatChartPainter>(WidgetTester tester, String key) =>
    tester.widget<StatChartFrame>(find.byKey(ValueKey(key))).painter as T;

int _unplannedLow() => statisticsUnplannedLowCount(
  buildStatisticsGrowth(
    state: statisticsSupplyFixtureState(),
    catalog: statisticsGrowthFixtureCatalog(),
  ),
)!;

void main() {
  test('B1 · C1 · C2 design coordinates follow the artboard SVG', () {
    // B1: 6행 피치 28, 행마다 사선 4.9 왼쪽, 60% 기준선 (284.2, 2) → (255.5, 166).
    expect(StatisticsB1Geometry.baselineOf(1, 6), 51);
    expect(StatisticsB1Geometry.shiftOf(1, 6), closeTo(4.9, 0.05));
    expect(StatisticsB1Geometry.thresholdX(2), closeTo(284.2, 0.5));
    expect(StatisticsB1Geometry.thresholdX(166), closeTo(255.5, 0.5));
    final track = StatisticsB1Geometry.barPath(5, 6).getBounds();
    expect(track.left, closeTo(96.0, 0.1));
    expect(track.bottom, closeTo(163, 0.01));
    // C1: 행 밑변 27 + 32n, 트랙 130 → 325.6, 눈금 287.9.
    expect(StatisticsC1Geometry.baselineOf(4), 155);
    expect(StatisticsC1Geometry.tickX, closeTo(287.9, 0.01));
    // 크레딧 98.4M / 261.5M → 보유 막대 157.9 × 37.6% = 59.4(시안 58.9는 반올림한 견본), 빗금 189.4 → 287.9(눈금까지).
    final owned = StatisticsC1Geometry.ownedPath(0, 98.4 / 261.5).getBounds();
    expect(owned.left, closeTo(130, 0.01));
    expect(owned.width, closeTo(157.9 * 98.4 / 261.5 + 10 * 0.1763, 0.05));
    expect(owned.width - 10 * 0.1763, closeTo(58.9, 0.6));
    final hatch = StatisticsC1Geometry.shortagePath(0, 98.4 / 261.5)!;
    expect(hatch.getBounds().left, closeTo(188.9, 0.6));
    expect(StatisticsC1Geometry.shortagePath(0, 1.28), isNull);
    // 넘치면 트랙 끝(195.6)에서 자른다(시안 384 / 300).
    expect(
      StatisticsC1Geometry.ownedPath(4, 384 / 300).getBounds().width,
      closeTo(195.6 + 10 * 0.1763, 0.2),
    );
    // C2: 시안 점 기술 노트 24% · 6명 (136.9, 58.5), 엘리그마 45% · 4명 (221.6, 107), 구역 (41, 10)–(241.8, 131.2).
    expect(StatisticsC2Geometry.xOf(0.24), closeTo(136.9, 0.1));
    expect(StatisticsC2Geometry.yOf(6, 8), closeTo(58.5, 0.1));
    expect(StatisticsC2Geometry.xOf(0.4543), closeTo(223.4, 0.2));
    expect(StatisticsC2Geometry.yOf(4, 8), closeTo(107, 0.1));
    final zone = StatisticsC2Geometry.zone(8);
    expect(zone.left, 41);
    expect(zone.top, 10);
    expect(zone.right, closeTo(241.8, 0.01));
    expect(zone.bottom, closeTo(131.25, 0.01));
  });

  testWidgets('inventory KPI band, scope and B1 use the artboard fixture numbers', (
    tester,
  ) async {
    await _pump(tester);
    final kpis = _kpis(tester, 'inventory');
    expect(
      [for (final kpi in kpis) kpi.label],
      ['전체 충족률', '부족 재화', '과잉 재화', '충족 카테고리', '스캔 없음'],
    );
    expect(
      [for (final kpi in kpis) kpi.value],
      StatisticsSupplyFixtureExpected.inventoryKpis,
    );
    expect(
      [for (final kpi in kpis) kpi.delta],
      ['—', '—', '—', '—', StatisticsSupplyFixtureExpected.unknownLabel],
    );
    expect(kpis[1].valueColor, AppColors.accent);
    expect(kpis[4].valueColor, AppColors.textMuted);
    expect(kpis[0].valueColor, AppColors.text);
    for (final kpi in kpis) {
      expect(kpi.deltaTone, KpiDeltaTone.unknown);
    }
    expect(find.text('활성 계획 기준 · 인벤토리 스캔 —'), findsOneWidget);
    expect(find.text('인벤토리 · 계획 집계는 항상 전체'), findsOneWidget);
    // B1 타일 (550.9, 393.2) 안쪽 사선 깊이 + 22, 머리 32(칩) + 10 → 차트 571×245(폭에 맞춘 배율).
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-b1-chart')),
      628.1,
      448.2,
      570.7,
      244.8,
      reason: 'B1 chart',
    );
    final painter = _painter<StatisticsCategoryFillPainter>(
      tester,
      'statistics-b1-chart',
    );
    expect(
      [for (final row in painter.rows) row.label],
      StatisticsSupplyFixtureExpected.b1Labels,
    );
    expect(
      [for (final row in painter.rows) statisticsFillText(row.fulfillment)],
      StatisticsSupplyFixtureExpected.b1Percents,
    );
    expect(painter.selectedCategory, isNull);
    // B2(FE7-f) · B3(FE7-h)도 그래프 자리라 인벤토리 주제에 "준비 중"이 없다(FD-106 사용자 결정 10-13).
    expect(find.text('준비 중'), findsNothing);
    expect(_note(tester), statisticsInventoryEvidenceEmptyText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a B1 bar lists the category resources and tapping again clears', (
    tester,
  ) async {
    await _pump(tester);
    await _tapB1(tester, 1);
    expect(
      _painter<StatisticsCategoryFillPainter>(
        tester,
        'statistics-b1-chart',
      ).selectedCategory,
      'tech_notes',
    );
    final title = find.byKey(const ValueKey('statistics-evidence-title'));
    expect(
      find.descendant(of: title, matching: find.text('기술 노트')),
      findsOneWidget,
    );
    expect(_chip(tester).label, '64%');
    expect(_note(tester), 'B1에서 고른 카테고리 · 충족률 낮은 순');
    // 충족률 낮은 순: 상급 48% → 최상급 80%.
    final upper = tester.getRect(
      find.byKey(
        const ValueKey('statistics-evidence-resource-Item_Icon_SkillBook_Abydos_2'),
      ),
    );
    final top = tester.getRect(
      find.byKey(
        const ValueKey('statistics-evidence-resource-Item_Icon_SkillBook_Abydos_3'),
      ),
    );
    expect(upper.top, lessThan(top.top));
    // 근거 행 첫 줄(위 100): 시안 근거 행 규칙(행 아래 높이의 사선에서 24, 섹션 오른쪽에서 22).
    _expectRect(
      tester,
      find.byKey(
        const ValueKey('statistics-evidence-resource-Item_Icon_SkillBook_Abydos_2'),
      ),
      2125.8,
      309.2,
      412.2,
      52,
      reason: 'first resource row',
    );
    expect(find.text('보유 12 / 필요 25'), findsOneWidget);
    expect(_text(tester, 'statistics-evidence-summary-planned-value'), '2종');
    expect(_text(tester, 'statistics-evidence-summary-short-value'), '2종');
    expect(_text(tester, 'statistics-evidence-summary-unknown-value'), '0종');
    await _tapB1(tester, 5);
    expect(_chip(tester).label, '모름');
    expect(_text(tester, 'statistics-evidence-summary-unknown-value'), '1종');
    expect(find.text('보유 — / 필요 120'), findsOneWidget);
    await _tapB1(tester, 5);
    expect(_note(tester), statisticsInventoryEvidenceEmptyText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('plan KPI band, scope chip, C1 seg and chart boxes', (
    tester,
  ) async {
    await _pump(tester, topic: StatisticsMode.plan);
    final kpis = _kpis(tester, 'plan');
    expect(
      [for (final kpi in kpis) kpi.label],
      ['계획 충족률', '부족 재화', '첫 부족', '막힌 학생', '미계획 · 40% 미만'],
    );
    // 첫 부족 · 막힌 학생(FD-034)은 활성 문서 계산이 있어야 한다(FE7-g). 이 서비스는 활성 계획을 주지 않아(Mock에 없는
    // 계정 → plan.get 실패) '—'다. 문서 계산이 있는 경우는 `statistics_plan_view_test.dart`.
    expect(
      [for (final kpi in kpis) kpi.value],
      ['72%', '14종', '—', '—', '${_unplannedLow()}명'],
    );
    expect(kpis[1].valueColor, AppColors.accent);
    expect(find.text('활성 계획 · 9명 · 페이즈 —'), findsOneWidget);
    final seg = tester.widget<SkewSegmented<int>>(
      find.byKey(const ValueKey('statistics-tile-C1-seg')),
    );
    expect(seg.onChanged, isNotNull);
    expect(seg.selected, 0);
    expect([for (final item in seg.segments) item.enabled], [true, false]);
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-c1-chart')),
      628.1,
      471.7,
      579.6,
      244.8,
      reason: 'C1 chart',
    );
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-c2-chart')),
      1334.8,
      448.3,
      579.6,
      289.8,
      reason: 'C2 chart',
    );
    final c1 = _painter<StatisticsBulletPainter>(tester, 'statistics-c1-chart');
    expect(c1.rows, hasLength(5));
    expect(
      [
        for (final row in c1.rows.take(2))
          '${statisticsAmountText(row.owned)} / '
              '${statisticsAmountText(row.requiredAmount)}',
      ],
      StatisticsSupplyFixtureExpected.c1FirstRows,
    );
    final c2 = _painter<StatisticsBottleneckPainter>(
      tester,
      'statistics-c2-chart',
    );
    expect(c2.maxStudents, 8);
    expect(c2.unknownKinds, 1);
    expect(c2.dots.where((dot) => dot.inZone), hasLength(4));
    // "준비 중" 타일은 없다(C4는 FE7-f, C5는 FE7-i 그래프), C3(FE7-g)은 활성 계획을 읽지 못한 안내를 타일 안에 둔다.
    expect(find.text('준비 중'), findsNothing);
    expect(
      _text(tester, 'statistics-tile-C3-empty'),
      startsWith('활성 계획을 읽지 못했습니다'),
    );
    expect(_note(tester), statisticsPlanEvidenceEmptyText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('C1 rows and C2 points select a resource and list its students', (
    tester,
  ) async {
    await _pump(tester, topic: StatisticsMode.plan);
    await _tapC1(tester, 0);
    expect(
      _painter<StatisticsBulletPainter>(tester, 'statistics-c1-chart').selectedKey,
      'credits',
    );
    final title = find.byKey(const ValueKey('statistics-evidence-title'));
    expect(find.descendant(of: title, matching: find.text('크레딧')), findsOneWidget);
    expect(_chip(tester).label, '−62%');
    // 재화 근거는 부제를 아이콘 행 안에 둔다(부제 줄 없음).
    expect(_note(tester), isNull);
    expect(
      _text(tester, 'statistics-evidence-header-subtitle'),
      'C1에서 고른 행 · 필요량 대비',
    );
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-evidence-header')),
      2153.3,
      283.2,
      362.7,
      70,
      reason: 'resource header',
    );
    expect(_text(tester, 'statistics-evidence-fact-owned-value'), '98.4M');
    expect(_text(tester, 'statistics-evidence-fact-required-value'), '261.5M');
    expect(_text(tester, 'statistics-evidence-fact-shortage-value'), '163.1M');
    _expectRect(
      tester,
      find.byKey(const ValueKey('statistics-evidence-fact-owned')),
      2116.2 + 0,
      363.2,
      421.8,
      52,
      tolerance: 24,
      reason: 'first fact row',
    );
    expect(
      _text(tester, 'statistics-evidence-users-title-caption'),
      '7명',
    );
    expect(find.byType(StatisticsEvidenceStudentRow), findsNWidgets(7));
    final credits = statisticsSupplyFixtureShortages().rows.firstWhere(
      (row) => row.resourceKey == 'credits',
    );
    _expectRect(
      tester,
      find.byKey(
        ValueKey('statistics-evidence-row-${credits.affectedStudentIds.first}'),
      ),
      2077.5,
      583.2,
      460.5,
      52,
      reason: 'first student row',
    );
    // C2에서 네브라 디스크 T4(46% · 6명)를 고르면 C1 선택이 풀린다.
    await _tapC2(tester, 0.46, 6);
    expect(
      _painter<StatisticsBulletPainter>(tester, 'statistics-c1-chart').selectedKey,
      isNull,
    );
    expect(
      _painter<StatisticsBottleneckPainter>(
        tester,
        'statistics-c2-chart',
      ).selectedKey,
      'Item_Icon_Material_Nebra_3',
    );
    expect(
      _text(tester, 'statistics-evidence-header-subtitle'),
      'C2에서 고른 병목 · 충족률 46% · 학생 6명',
    );
    expect(_chip(tester).label, '−54%');
    expect(find.byType(StatisticsEvidenceStudentRow), findsNWidgets(6));
    await _tapC2(tester, 0.46, 6);
    expect(_note(tester), statisticsPlanEvidenceEmptyText);
    expect(tester.takeException(), isNull);
  });

  testWidgets('topic switch clears the selection', (tester) async {
    await _pump(tester, topic: StatisticsMode.plan);
    await _tapC1(tester, 2);
    expect(_note(tester), isNull);
    await tester.tap(find.byKey(const ValueKey('statistics-topic-inventory')));
    await tester.pumpAndSettle();
    expect(_note(tester), statisticsInventoryEvidenceEmptyText);
    await tester.tap(find.byKey(const ValueKey('statistics-topic-plan')));
    await tester.pumpAndSettle();
    expect(_note(tester), statisticsPlanEvidenceEmptyText);
  });

  testWidgets('KPI press scrolls to the target graph row', (tester) async {
    // 낮은 창(폭 그대로)이라 타일 높이는 시안 그대로이고 스크롤 범위가 넓다.
    await _pump(tester, size: const Size(2560, 700), topic: StatisticsMode.plan);
    ScrollPosition position() => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const ValueKey('statistics-viewport-plan')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;
    expect(position().pixels, 0);
    // 계획 충족률 → C1 줄 위(KPI 띠 위 6 + 84 + 줄 사이 22).
    await tester.tap(find.byKey(const ValueKey('statistics-kpi-plan-0')));
    await tester.pumpAndSettle();
    expect(position().pixels, closeTo(112, 0.01));
    // KPI 띠도 함께 스크롤되므로 위로 돌린 뒤 누른다. 첫 부족 → C3 줄(C1 줄 높이 + 22 아래).
    position().jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statistics-kpi-plan-2')));
    await tester.pumpAndSettle();
    final c3 = position().pixels;
    expect(c3, greaterThan(112 + 300));
    // 미계획 → C5 줄(범위 밖이면 끝까지).
    position().jumpTo(0);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statistics-kpi-plan-4')));
    await tester.pumpAndSettle();
    expect(position().pixels, greaterThan(c3));
    expect(
      position().pixels,
      lessThanOrEqualTo(position().maxScrollExtent + 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no saved plan shows the empty text inside B1, C1 and C2', (
    tester,
  ) async {
    await _pump(tester, noGoals: true);
    expect(
      _text(tester, 'statistics-tile-B1-empty'),
      statisticsSupplyNoPlanText,
    );
    expect([for (final kpi in _kpis(tester, 'inventory')) kpi.value], [
      '—',
      '—',
      '—',
      '—',
      '—',
    ]);
    await tester.tap(find.byKey(const ValueKey('statistics-topic-plan')));
    await tester.pumpAndSettle();
    for (final id in ['C1', 'C2', 'C3']) {
      expect(
        _text(tester, 'statistics-tile-$id-empty'),
        statisticsSupplyNoPlanText,
      );
    }
    expect(find.text('활성 계획 · 0명 · 페이즈 —'), findsOneWidget);
    // C1 seg는 자료가 없으면 비활성 자리 그대로다.
    expect(
      tester
          .widget<SkewSegmented<int>>(
            find.byKey(const ValueKey('statistics-tile-C1-seg')),
          )
          .onChanged,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown holdings: B1 hatches every bar and C2 shows its empty text', (
    tester,
  ) async {
    await _pump(tester, noHoldings: true);
    final b1 = _painter<StatisticsCategoryFillPainter>(
      tester,
      'statistics-b1-chart',
    );
    expect([for (final row in b1.rows) row.fulfillment], everyElement(isNull));
    expect(
      [for (final kpi in _kpis(tester, 'inventory')) kpi.value],
      ['—', '0종', '0종', '0 / 6', '24종'],
    );
    expect(_kpis(tester, 'inventory')[4].delta, '장비 설계도 외 7');
    await tester.tap(find.byKey(const ValueKey('statistics-topic-plan')));
    await tester.pumpAndSettle();
    expect(
      _text(tester, 'statistics-tile-C2-empty'),
      statisticsSupplyNoKnownText,
    );
    final c1 = _painter<StatisticsBulletPainter>(tester, 'statistics-c1-chart');
    expect([for (final row in c1.rows) row.ratio], everyElement(isNull));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(1280, 720), Size(800, 600)]) {
    testWidgets(
      'inventory and plan with selections fit ${size.width}x${size.height}',
      (tester) async {
        await _pump(tester, size: size);
        await _tapB1(tester, 0);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('statistics-topic-plan')));
        await tester.pumpAndSettle();
        await _tapC1(tester, 0);
        expect(tester.takeException(), isNull);
        await _tapC2(tester, 0.46, 6);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
