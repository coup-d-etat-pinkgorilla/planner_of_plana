// FE7-f: 통계 2차 타일 A3 · A4 · B2 · C4(시안 Stats-Growth · Stats-Inventory · Stats-Plan · Stats-Growth-Filter).
//
// projection(성작 · 전용무기 분포, 학교 · 역할 보유율 · 평균 육성도, B2 부족 · 과잉 행, C4 목표 육성도 · 남은 폭, B2 근거
// 최근 변화)과 화면(차트 · seg · A4 hover 팝오버 · 고른 것 → 근거 → 원본 탭 이동 · 작은 창)을 본다. 학생 목록은 golden과
// 같이 번들 학생 목록에서 fixture id를 고른다(학교 · 역할 · 편성이 실제 값). 시계는 이력 fixture 고정 시각이다.
import 'dart:convert';

import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_breakdown_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_goal_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_filter.dart'
    show statisticsA4SingleGroupText;
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_supply_projection.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_history.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:ba_planner_v7/ui/kit/skew_controls.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:ba_planner_v7/ui/navigation/app_navigation_intent.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_balance_charts.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_breakdown_charts.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_supply_evidence.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_workspace.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_growth_fixture.dart';
import 'statistics_history_fixture.dart';
import 'statistics_plan_fixture.dart';
import 'statistics_supply_fixture.dart';

const _canvas = Size(2560, 1208);
const _profileId = '0123456789abcdef01234567';

/// 번들 학생 목록에서 고른 fixture 학생(golden 학생 목록과 같다).
late List<StudentCatalogEntry> _catalog;

Future<List<StudentCatalogEntry>> _loadCatalog() async {
  final data = await rootBundle.load('assets/student_catalog.json');
  final byId = {
    for (final item
        in jsonDecode(utf8.decode(data.buffer.asUint8List())) as List)
      (item as Map)['student_id'] as String: StudentCatalogEntry.fromWire(
        Map<String, dynamic>.from(item),
      ),
  };
  return [for (final id in statisticsGrowthFixtureCatalogIds) byId[id]!];
}

/// 성장 · 재화 · 활성 문서 · 이력 fixture를 모두 주는 서비스(golden 인벤토리 · 계획 장면과 같은 숫자).
class _Service extends MockAppService implements AppClockSource {
  final RepositoryCurrentHistory _history = statisticsHistoryFixtureHistory();

  @override
  DateTime get clockNow => statisticsHistoryFixtureNow;

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
      statisticsSupplyFixtureState(
        profileId: profileId,
        revision: statisticsHistoryFixtureRevision,
      );

  @override
  Future<RepositoryPlanState> loadRepositoryPlan(String profileId) async =>
      statisticsPlanFixturePlan(profileId: profileId);

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async => statisticsPlanFixtureProjection();

  @override
  Future<List<StudentCatalogEntry>> listStudents() async => _catalog;

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

  @override
  Future<RepositoryHistorySummaryResult> loadRepositoryHistorySummary(
    List<String> profileIds,
  ) async => RepositoryHistorySummaryResult.fromWire({
    'profiles': [
      for (final id in profileIds)
        _history.summarize(id, statisticsHistoryFixtureRevision).toWire(),
    ],
  });

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) async => repositoryHistoryEvents(
    await loadRepositoryState(request.profileId),
    _history,
    request,
  );

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async => repositoryHistoryScanLatest(
    request.profileId,
    statisticsHistoryFixtureRevision,
    _history,
    request,
  );
}

Future<List<AppNavigationIntent>> _pump(
  WidgetTester tester, {
  Size size = _canvas,
  String topic = 'growth',
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final service = _Service();
  addTearDown(service.dispose);
  final intents = <AppNavigationIntent>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatisticsPage(
          service: service,
          onOpen: (_) {},
          onNavigate: intents.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (topic != 'growth') {
    await tester.tap(find.byKey(ValueKey('statistics-topic-$topic')));
    await tester.pumpAndSettle();
  }
  return intents;
}

/// 보유 학생 성장(번들 학생 목록).
StatisticsGrowth _growth() => buildStatisticsGrowth(
  state: statisticsGrowthFixtureState(),
  catalog: _catalog,
)!;

T _painter<T extends StatChartPainter>(WidgetTester tester, String key) =>
    tester
            .widget<StatChartFrame>(
              find.descendant(
                of: find.byKey(ValueKey(key)),
                matching: find.byType(StatChartFrame),
                matchRoot: true,
              ),
            )
            .painter
        as T;

Offset _chartPoint(
  WidgetTester tester,
  String key,
  Size viewBox,
  Offset point,
) {
  final rect = tester.getRect(find.byKey(ValueKey(key)));
  return rect.topLeft + point * (rect.width / viewBox.width);
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Finder _inside(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

/// 재화 하나의 스캔 4회(3주 전 · 2주 전 · 1주 전 · 지금) 이력 색인(FE6-f 상세 fixture 31 · 24 · 18 · 12).
InventoryHistory _depletingHistory(String key) {
  final now = DateTime(2026, 10, 6, 12);
  const values = [31, 24, 18, 12];
  final events = <InventoryHistoryEvent>[];
  final points = <InventoryScanPoint>[];
  for (final (index, value) in values.indexed) {
    final at = now.subtract(Duration(days: 21 - index * 7));
    events.add(
      InventoryHistoryEvent(
        sequence: index + 1,
        recordedAt: at,
        source: 'scan',
        sessionId: 's$index',
        resourceKeys: [key],
        changes: {
          key: (
            index == 0
                ? const InventoryHistoryValue.absent()
                : InventoryHistoryValue.of('${values[index - 1]}'),
            InventoryHistoryValue.of('$value'),
          ),
        },
      ),
    );
    points.add(
      InventoryScanPoint(
        sessionId: 's$index',
        sequence: index + 1,
        recordedAt: at,
      ),
    );
  }
  return InventoryHistory.build(
    InventoryHistoryInput(
      now: now,
      current: {key: const InventoryHistoryValue.of('12')},
      events: events,
      scanPoints: points,
      coverage: const InventoryHistoryCoverage(origin: 'empty'),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _catalog = await _loadCatalog();
  });

  group('projection', () {
    test('A3 counts every owned star / weapon step and the class mix', () {
      final growth = _growth();
      final stars = StatisticsStarDistribution.of(growth);
      final byId = {for (final entry in _catalog) entry.studentId: entry};
      final expectedStars = List.filled(5, 0);
      final expectedWeapons = List.filled(5, 0);
      final mix = {
        for (final value in statisticsA3CombatClasses) value: List.filled(5, 0),
      };
      for (final row in statisticsGrowthFixtureOwned) {
        expectedStars[row.$11 - 1]++;
        expectedWeapons[row.$12]++;
        mix[byId[row.$1]!.combatClass]?[row.$11 - 1]++;
      }
      expect([for (final list in stars.stars) list.length], expectedStars);
      expect([for (final list in stars.weapons) list.length], expectedWeapons);
      expect(stars.classMix, mix);
      expect(stars.unknownStars, 0);
      expect(stars.unknownWeapons, 0);
      expect(expectedStars.fold<int>(0, (a, b) => a + b), 128);
      expect(
        stars.maxCount,
        [...expectedStars, ...expectedWeapons].reduce((a, b) => a > b ? a : b),
      );
      // 단계 근거는 낮은 항목 순이다(A1 구간과 같은 비교).
      for (final list in [...stars.stars, ...stars.weapons]) {
        expect([...list]..sort(statisticsCompareLowItem), list);
      }
      expect(StatisticsStarKind.weapon.stepLabel(0), '없음');
      expect(StatisticsStarKind.weapon.titleOf(2), '전용무기 ★2');
      expect(StatisticsStarKind.star.titleOf(2), '성작 ★3');
    });

    test(
      'A4 owned ratio = owned / catalog per group, means over the plotted groups',
      () {
        final growth = _growth();
        final comparison = StatisticsGroupComparison.of(
          growth,
          _catalog,
          StatisticsA4Group.school,
        );
        final catalogBySchool = <String, int>{};
        for (final entry in _catalog) {
          final school = entry.school;
          if (school == null || statisticsA4ExcludedSchools.contains(school)) {
            continue;
          }
          catalogBySchool[school] = (catalogBySchool[school] ?? 0) + 1;
        }
        var owned = 0, total = 0;
        for (final point in comparison.groups) {
          expect(point.catalogCount, catalogBySchool[point.value]);
          expect(point.ownedRatio, point.ownedCount / point.catalogCount);
          expect(point.students.every((s) => s.school == point.value), isTrue);
          if (point.plotted) {
            owned += point.ownedCount;
            total += point.catalogCount;
          }
        }
        expect(comparison.points, isNotEmpty);
        expect(comparison.meanRatio, owned / total);
        // 그룹 값이 있는 보유 학생 + 모르는 학생 = 보유 128명.
        expect(
          comparison.groups.fold<int>(0, (sum, p) => sum + p.ownedCount) +
              comparison.unknownCount,
          128,
        );
        if (comparison.unknownCount == 0) {
          expect(comparison.meanGrowth, closeTo(growth.averageGrowth!, 1e-9));
        }
        // 강조 = 평균 육성도 아래 그룹 중 대상 학생이 가장 많은 그룹.
        final mean = comparison.meanGrowth!;
        final below = [
          for (final point in comparison.points)
            if (point.averageGrowth! < mean) point,
        ];
        final emphasized = comparison.emphasized;
        if (below.isEmpty) {
          expect(emphasized, isNull);
        } else {
          expect(
            emphasized!.ownedCount,
            below.map((p) => p.ownedCount).reduce((a, b) => a > b ? a : b),
          );
        }
        final roles = StatisticsGroupComparison.of(
          growth,
          _catalog,
          StatisticsA4Group.role,
        );
        expect(roles.valueCount, greaterThan(1));
        expect(
          roles.groups.every((p) => p.students.every((s) => s.role == p.value)),
          isTrue,
        );
      },
    );

    test('A4 axis range rounds to 10 and keeps a span', () {
      expect(statisticsA4Range([45, 100]), (min: 40.0, max: 100.0));
      expect(statisticsA4Range([39, 74]), (min: 30.0, max: 80.0));
      expect(statisticsA4Range([50, 50]), (min: 50.0, max: 60.0));
      expect(statisticsA4Range([100]), (min: 90.0, max: 100.0));
      expect(statisticsA4Range(const []), (min: 0.0, max: 100.0));
    });

    test(
      'C4 target values: raise with the goal, keep unset items, never go down',
      () {
        final current = <String, dynamic>{
          'level': 70,
          'ex_skill': 3,
          'skill1': 5,
          'equip1': 'T5',
          'student_star': 4,
        };
        final target = statisticsGoalTargetValues(current, {
          'student_id': 'x',
          'target_level': 90,
          'target_ex_skill': 2,
          'target_equip1_tier': 8,
          'target_bond_rank': 50,
        });
        expect(target['level'], 90);
        expect(target['ex_skill'], 3, reason: '이미 넘은 목표는 지금 값');
        expect(target['equip1'], 8);
        expect(target['skill1'], 5, reason: '목표가 없는 항목은 지금 값');
        expect(target['student_star'], 4);
        expect(
          statisticsGoalTargetValues(const {}, {'target_level': 80})['level'],
          80,
        );
      },
    );

    test(
      'C4 rows: FD-028 on current and target, largest remaining first, unknown last',
      () {
        final growthState = statisticsGrowthFixtureState();
        final owned = growthState.students.first;
        final state = RepositoryState.fromWire({
          'profile_id': _profileId,
          'revision': 1,
          'students': [owned.toWire()],
          'inventory': {'version': 1, 'entries': <Object>[]},
          'goals': {
            'version': 1,
            'goals': [
              {
                'student_id': owned.studentId,
                'target_level': 90,
                'target_skill1': 10,
              },
              {'student_id': 'not_owned_student', 'target_level': 90},
            ],
          },
        });
        final set = StatisticsGoalProgressSet.of(
          state: state,
          catalog: _catalog,
        );
        expect(set.rows, hasLength(2));
        final row = set.rows.first;
        expect(row.studentId, owned.studentId);
        final byId = {for (final entry in _catalog) entry.studentId: entry};
        final current = statisticsStudentGrowth(
          owned,
          catalog: byId[owned.studentId],
        );
        expect(row.currentGrowth, closeTo(current.growth!, 1e-9));
        final target = statisticsGrowthOfValues(
          owned.studentId,
          statisticsGoalTargetValues(owned.values, state.goals.first.values),
          catalog: byId[owned.studentId],
        );
        expect(row.targetGrowth, closeTo(target.growth!, 1e-9));
        expect(row.remaining, greaterThanOrEqualTo(0));
        // 보유하지 않은 계획 학생은 지금 값을 몰라 '—'(뒤).
        expect(set.rows.last.studentId, 'not_owned_student');
        expect(set.rows.last.remaining, isNull);
        expect(StatisticsC4Row.of(set.rows.last).text, '—');

        final fixture = StatisticsGoalProgressSet.of(
          state: statisticsGrowthFixtureState(),
          catalog: _catalog,
        );
        expect(
          fixture.rows,
          hasLength(statisticsGrowthFixturePlannedIds.length),
        );
        final known = [
          for (final r in fixture.rows)
            if (r.known) r.remaining!,
        ];
        expect(known, [...known]..sort((a, b) => b.compareTo(a)));
        expect(fixture.visible, hasLength(statisticsC4RowCount));
      },
    );

    test('B2 rows: known shortages and FD-040 excess only, per seg order', () {
      final supply = StatisticsSupply.build(
        catalog: statisticsSupplyFixtureCatalog,
        state: statisticsSupplyFixtureState(),
        shortages: statisticsSupplyFixtureShortages(),
      )!;
      final shortage = statisticsB2Rows(supply, StatisticsB2Order.shortage);
      expect(
        [for (final row in shortage) row.view.item.displayName],
        [
          '크레딧',
          '엘리그마',
          '네브라 디스크 T4',
          '님루드 렌즈 T3',
          '기술 노트 (상급)',
          '전술 교육 BD (최상급)',
        ],
      );
      expect(StatisticsB2Bar.of(shortage.first).text, '−62%');
      final excess = statisticsB2Rows(supply, StatisticsB2Order.excess);
      expect(
        [for (final row in excess) row.view.item.displayName],
        [
          '설계도 · 목걸이 T3',
          '초급 활동 보고서',
          '일반 활동 보고서 (이벤트)',
          '일반 활동 보고서',
          '설계도 · 헤어핀 T5',
          '설계도 · 부적 T4',
        ],
      );
      expect(StatisticsB2Bar.of(excess.first).text, '+125%');
      // 과잉은 인벤토리 탭과 같은 판정이다(보유 ≥ 필요 × 1.5).
      for (final row in excess) {
        expect(row.view.excess, isTrue);
        expect(row.excess, isTrue);
      }
      // 1~1.5배(상급 활동 보고서 384 / 300)는 부족도 과잉도 아니다.
      final all = [
        ...statisticsB2Rows(supply, StatisticsB2Order.shortage),
        ...statisticsB2Rows(supply, StatisticsB2Order.excess),
      ];
      expect(
        all.where((row) => row.view.key == 'Item_Icon_ExpItem_2'),
        isEmpty,
      );
      // 과잉 종 수는 인벤토리 KPI와 같다(재화 제외).
      expect(
        supply.planned.where((view) => view.excess && !view.isCurrency).length,
        supply.kpis.excessKinds,
      );
    });

    test(
      'B2 recent change: last-but-one scan and the FE6-f depletion forecast',
      () {
        const key = 'Item_Icon_SkillBook_Abydos_3';
        final view = InventoryItemView(
          item: statisticsSupplyFixtureCatalog.firstWhere(
            (e) => e.resourceKey == key,
          ),
          order: 0,
          present: true,
          quantity: '12',
        );
        final recent = statisticsRecentChange(_depletingHistory(key), view);
        expect(recent.scanCount, 4);
        expect(recent.sinceLastScan, -6);
        expect(recent.depletionWeeks, 2);
        final unknown = statisticsRecentChange(null, view);
        expect(unknown.scanCount, isNull);
        expect(unknown.sinceLastScan, isNull);
        expect(unknown.depletionWeeks, isNull);
      },
    );
  });

  group('growth A3 · A4', () {
    testWidgets('A3 draws both step groups and a step opens its students', (
      tester,
    ) async {
      final intents = await _pump(tester);
      expect(find.byKey(const ValueKey('statistics-a3-chart')), findsOneWidget);
      final painter = _painter<StatisticsStarDistributionPainter>(
        tester,
        'statistics-a3-chart',
      );
      final stars = StatisticsStarDistribution.of(_growth());
      expect(painter.stars, [for (final list in stars.stars) list.length]);
      expect(painter.weapons, [for (final list in stars.weapons) list.length]);
      // 가장 많은 성작 단계를 누른다.
      final index = painter.stars.indexOf(
        painter.stars.reduce((a, b) => a > b ? a : b),
      );
      await tester.tapAt(
        _chartPoint(
          tester,
          'statistics-a3-chart',
          statisticsA3ViewBox,
          Offset(
            StatisticsA3Geometry.barLeft(StatisticsStarKind.star, index) + 12,
            StatisticsA3Geometry.baseline - 4,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = StatisticsStarKind.star.titleOf(index);
      expect(_inside('statistics-evidence-title', title), findsOneWidget);
      expect(
        _inside('statistics-evidence-count', '${painter.stars[index]}명'),
        findsOneWidget,
      );
      expect(find.text('A3에서 고른 단계 · 낮은 항목 순'), findsOneWidget);
      expect(find.text('단계 요약'), findsOneWidget);
      expect(find.text('필터: $title'), findsOneWidget);
      await _tapKey(tester, 'statistics-evidence-secondary');
      final intent = intents.single as StudentsNavigationIntent;
      expect(intent.studentIds, [
        for (final student in stars.stars[index]) student.studentId,
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('A4 hover shows the artboard popover, tap opens the school', (
      tester,
    ) async {
      final intents = await _pump(tester);
      final comparison = StatisticsGroupComparison.of(
        _growth(),
        _catalog,
        StatisticsA4Group.school,
      );
      final point = comparison.points.reduce(
        (a, b) => a.ownedCount >= b.ownedCount ? a : b,
      );
      final dot = find.byKey(ValueKey('statistics-a4-dot-${point.value}'));
      expect(dot, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'statistics-a4-dot-',
              ),
        ),
        findsNWidgets(comparison.points.length),
      );
      final label = statisticsGroupLabel(StatisticsA4Group.school, point.value);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(dot));
      await tester.pump();
      final popover = find.byKey(
        ValueKey('statistics-a4-popover-${point.value}'),
      );
      expect(popover, findsOneWidget);
      expect(
        find.descendant(
          of: popover,
          matching: find.text(statisticsGroupSummaryText(point)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: popover,
          matching: find.text('누르면 오른쪽 목록 · 학생 탭(학교 필터)으로 이어집니다'),
        ),
        findsOneWidget,
      );
      expect(
        statisticsGroupSummaryText(point),
        '보유 ${point.ownedCount}명 · 보유율 ${statisticsPercentText(point.ownedRatio!)} · '
        '평균 육성도 ${statisticsPercentText(point.averageGrowth!)}',
      );
      // 팝오버는 점 왼쪽이고 화면 안이다.
      final rect = tester.getRect(popover);
      expect(rect.right, lessThanOrEqualTo(tester.getRect(dot).left));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(_canvas.height));
      await gesture.moveTo(Offset.zero);
      await tester.pump();
      expect(popover, findsNothing);

      await tester.tap(dot);
      await tester.pumpAndSettle();
      expect(_inside('statistics-evidence-title', label), findsOneWidget);
      expect(find.text('A4에서 고른 학교 · 낮은 항목 순'), findsOneWidget);
      expect(find.text('학교 요약'), findsOneWidget);
      expect(
        _text(tester, 'statistics-evidence-summary-ratio-value'),
        '${statisticsPercentText(point.ownedRatio!)} · '
        '${point.ownedCount} / ${point.catalogCount}명',
      );
      final painter = _painter<StatisticsGroupComparisonPainter>(
        tester,
        'statistics-a4-chart',
      );
      expect(painter.emphasized, point.value, reason: '고른 점이 분홍 강조');
      await _tapKey(tester, 'statistics-evidence-secondary');
      final intent = intents.single as StudentsNavigationIntent;
      expect(intent.studentIds, [for (final s in point.students) s.studentId]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('A4 seg switches to roles and drops a school selection', (
      tester,
    ) async {
      await _pump(tester);
      final schools = StatisticsGroupComparison.of(
        _growth(),
        _catalog,
        StatisticsA4Group.school,
      );
      await _tapKey(tester, 'statistics-a4-dot-${schools.points.first.value}');
      expect(find.text('학교 요약'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('statistics-tile-A4-seg')),
          matching: find.text('역할'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SkewSegmented<int>>(
              find.byKey(const ValueKey('statistics-tile-A4-seg')),
            )
            .selected,
        1,
      );
      expect(find.text('학교 요약'), findsNothing);
      expect(find.text(statisticsEvidenceEmptyText), findsOneWidget);
      final roles = StatisticsGroupComparison.of(
        _growth(),
        _catalog,
        StatisticsA4Group.role,
      );
      final painter = _painter<StatisticsGroupComparisonPainter>(
        tester,
        'statistics-a4-chart',
      );
      expect(
        painter.dots.map((dot) => dot.value),
        roles.points.map((p) => p.value),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('filtered A4 empty state follows the chosen seg (FE7-e 발견 3)', (
      tester,
    ) async {
      await _pump(tester);
      await _tapKey(tester, 'statistics-filter');
      await _tapKey(tester, 'student-filter-chip-school-Millennium');
      await _tapKey(tester, 'student-filter-apply');
      expect(
        find.byKey(const ValueKey('statistics-tile-A4-single')),
        findsOneWidget,
      );
      expect(find.text(statisticsA4SingleGroupText), findsOneWidget);
      // 밀레니엄 대상 학생의 역할은 여럿이라 "역할" seg에서는 비교한다.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('statistics-tile-A4-seg')),
          matching: find.text('역할'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('statistics-tile-A4-single')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('statistics-a4-chart')), findsOneWidget);
      // A4가 그래프면 A4 · A6 줄은 원래 높이(FD-109).
      expect(
        tester.getSize(find.byKey(const ValueKey('statistics-tile-A4'))).height,
        closeTo(368, 0.5),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('inventory B2', () {
    testWidgets('B2 rows, seg and the Stats-Inventory evidence frame', (
      tester,
    ) async {
      final intents = await _pump(tester, topic: 'inventory');
      final painter = _painter<StatisticsBalancePainter>(
        tester,
        'statistics-b2-chart',
      );
      expect(painter.bars.map((bar) => bar.label).take(2), ['크레딧', '엘리그마']);
      expect(painter.unknownKinds, 1, reason: '엘레프 스캔 없음');
      await tester.tapAt(
        _chartPoint(
          tester,
          'statistics-b2-chart',
          statisticsB2ViewBox,
          Offset(200, StatisticsB2Geometry.baselineOf(0) - 6),
        ),
      );
      await tester.pumpAndSettle();
      expect(_inside('statistics-evidence-title', '크레딧'), findsOneWidget);
      expect(_inside('statistics-evidence-count', '−62%'), findsOneWidget);
      expect(
        _text(tester, 'statistics-evidence-header-subtitle'),
        'B2에서 고른 행 · 필요량 대비',
      );
      expect(_text(tester, 'statistics-evidence-fact-owned-value'), '98.4M');
      expect(
        _text(tester, 'statistics-evidence-fact-required-value'),
        '261.5M',
      );
      expect(find.text('필요량 순'), findsOneWidget);
      // 최근 변화: 지금 − 28일 색인의 스캔 묶음 5회(9/08 ~ 10/03), 지난 스캔(9/29 104.0M) 대비.
      expect(find.text('최근 변화'), findsOneWidget);
      expect(find.text('스캔 5회'), findsOneWidget);
      expect(_text(tester, 'statistics-evidence-recent-since-value'), '−5.6M');
      // 크레딧은 4주 안에 소진되지 않아 예측 줄이 없다(FD-042).
      expect(
        find.byKey(const ValueKey('statistics-evidence-recent-forecast')),
        findsNothing,
      );
      await _tapKey(tester, 'statistics-evidence-primary');
      final row = intents.single as InventoryNavigationIntent;
      expect(row.target, InventoryNavigationTarget.row);
      expect(row.resourceKey, 'credits');
      // 크레딧은 티어 표가 없어 ghost는 비활성이다.
      await _tapKey(tester, 'statistics-evidence-secondary');
      expect(intents, hasLength(1));

      // "과잉 순"으로 바꾸면 고른 행을 풀고 큰 과잉부터다.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('statistics-tile-B2-seg')),
          matching: find.text('과잉 순'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(statisticsInventoryEvidenceEmptyText), findsOneWidget);
      final excess = _painter<StatisticsBalancePainter>(
        tester,
        'statistics-b2-chart',
      );
      expect(excess.bars.first.label, '설계도 · 목걸이 T3');
      expect(excess.bars.first.text, '+125%');
      expect(tester.takeException(), isNull);
    });

    testWidgets('B2 users read the active document stage requirement', (
      tester,
    ) async {
      await _pump(tester, topic: 'inventory');
      await tester.tapAt(
        _chartPoint(
          tester,
          'statistics-b2-chart',
          statisticsB2ViewBox,
          Offset(200, StatisticsB2Geometry.baselineOf(1) - 6),
        ),
      );
      await tester.pumpAndSettle();
      expect(_inside('statistics-evidence-title', '엘리그마'), findsOneWidget);
      final uses = inventoryStageUses(
        statisticsPlanFixtureProjection(),
        statisticsPlanFixturePlan(profileId: _profileId).document,
      )['Item_Icon_SecretStone'];
      if (uses != null && uses.isNotEmpty) {
        final totals = <String, int>{};
        for (final use in uses) {
          totals[use.studentId] =
              (totals[use.studentId] ?? 0) + use.requiredAmount;
        }
        final top = totals.entries.reduce((a, b) => a.value >= b.value ? a : b);
        expect(
          find.byKey(ValueKey('statistics-evidence-row-${top.key}')),
          findsOneWidget,
        );
        expect(find.text('${top.value}'), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('plan C4', () {
    testWidgets('C4 dumbbells sort by remaining and a row opens goals', (
      tester,
    ) async {
      final intents = await _pump(tester, topic: 'plan');
      final painter = _painter<StatisticsGoalProgressPainter>(
        tester,
        'statistics-c4-chart',
      );
      final expected = StatisticsGoalProgressSet.of(
        state: statisticsSupplyFixtureState(),
        catalog: _catalog,
      );
      expect(painter.rows.map((row) => row.studentId), [
        for (final row in expected.visible) row.studentId,
      ]);
      final first = expected.rows.first;
      await tester.tapAt(
        _chartPoint(
          tester,
          'statistics-c4-chart',
          statisticsC4ViewBox,
          Offset(200, StatisticsC4Geometry.yOf(0)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _inside('statistics-evidence-title', first.displayName),
        findsOneWidget,
      );
      expect(
        _inside(
          'statistics-evidence-count',
          '남은 ${statisticsPercentPoints(first.remaining!)}',
        ),
        findsOneWidget,
      );
      expect(
        _text(tester, 'statistics-evidence-header-subtitle'),
        'C4에서 고른 학생 · 현재 → 목표',
      );
      expect(
        _text(tester, 'statistics-evidence-fact-current-value'),
        statisticsPercentText(first.currentGrowth!),
      );
      expect(
        _text(tester, 'statistics-evidence-fact-target-value'),
        statisticsPercentText(first.targetGrowth!),
      );
      expect(
        find.byKey(const ValueKey('statistics-evidence-item-level')),
        findsOneWidget,
      );
      expect(find.text(statisticsGoalActionLabel), findsOneWidget);
      await _tapKey(tester, 'statistics-evidence-primary');
      final intent = intents.single as PlanNavigationIntent;
      expect(intent.target, PlanNavigationTarget.goals);
      expect(intent.studentIds, [first.studentId]);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('A4 popover, B2 and C4 evidence fit 1280x720', (tester) async {
    const size = Size(1280, 720 - 88);
    await _pump(tester, size: size);
    final comparison = StatisticsGroupComparison.of(
      _growth(),
      _catalog,
      StatisticsA4Group.school,
    );
    // A4 줄로 스크롤한 뒤 가장 오른쪽 점에 마우스를 올린다.
    await tester.drag(
      find.byKey(const ValueKey('statistics-tile-A1')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    final right = comparison.points.reduce(
      (a, b) => a.ownedRatio! >= b.ownedRatio! ? a : b,
    );
    final dot = find.byKey(ValueKey('statistics-a4-dot-${right.value}'));
    if (dot.evaluate().isNotEmpty) {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(dot));
      await tester.pump();
      final popover = find.byKey(
        ValueKey('statistics-a4-popover-${right.value}'),
      );
      expect(popover, findsOneWidget);
      final rect = tester.getRect(popover);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
      await gesture.moveTo(Offset.zero);
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    await _tapKey(tester, 'statistics-topic-inventory');
    await tester.tapAt(
      _chartPoint(
        tester,
        'statistics-b2-chart',
        statisticsB2ViewBox,
        Offset(200, StatisticsB2Geometry.baselineOf(0) - 6),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('최근 변화'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tapKey(tester, 'statistics-topic-plan');
    await tester.drag(
      find.byKey(const ValueKey('statistics-tile-C1')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      _chartPoint(
        tester,
        'statistics-c4-chart',
        statisticsC4ViewBox,
        Offset(200, StatisticsC4Geometry.yOf(0)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('C4에서 고른 학생 · 현재 → 목표'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
