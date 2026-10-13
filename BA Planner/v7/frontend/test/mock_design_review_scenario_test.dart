// mockdemo: mock 검수 시나리오 스위치(`BA_PLANNER_MOCK_SCENARIO`)와 시나리오 서비스 응답.
//
// - 스위치가 없으면 기본 Mock(`MockAppService(fullStudentCatalog: true)`) 그대로, 모르는 이름은 오류다.
// - `design-review`: 계정 `거모이는존재한다 (v7 UI 테스트)`가 선택되고, 통계 · 인벤토리 · 계획 · 계정 메타 서비스 응답이
//   시안 숫자(대표값)를 준다. 숫자는 옮긴 데이터의 기존 기대값(`*_fixture.dart`의 Expected)을 그대로 쓴다.
// - 쓰기는 메모리 안이고, 새 시나리오는 초기값으로 돌아간다.
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_design_review_scenario.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_plan_projection.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_controller.dart';
import 'package:ba_planner_v7/ui/kit/kpi_tile.dart';
import 'package:ba_planner_v7/ui/pages/inventory_page.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/widgets/account_section_cluster.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'inventory_fe6a_fixture.dart';
import 'statistics_growth_fixture.dart';
import 'statistics_plan_fixture.dart';

const _rio = 'Item_Icon_SecretStone_rio_battle';

Future<MockDesignReviewScenario> _pump(
  WidgetTester tester,
  Widget Function(MockDesignReviewScenario) page,
) async {
  await tester.binding.setSurfaceSize(const Size(2560, 1392));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final service = MockDesignReviewScenario();
  addTearDown(service.dispose);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page(service))));
  await tester.pumpAndSettle();
  return service;
}

List<Map<String, dynamic>> _currentStudents(RepositoryState state) => [
  for (final student in state.students)
    {'student_id': student.studentId, ...student.values},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('switch', () {
    test('no scenario keeps the default mock', () async {
      final service = createMockAppService();
      final reference = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);
      addTearDown(reference.dispose);
      expect(service.runtimeType, MockAppService);
      expect(service.fullStudentCatalog, isTrue);
      expect(service, isNot(isA<InventoryClockSource>()));
      expect(createMockAppService(scenario: '  ').runtimeType, MockAppService);

      final profiles = await service.listProfiles();
      expect(
        [for (final p in profiles) (p.id, p.displayName, p.selected)],
        [
          for (final p in await reference.listProfiles())
            (p.id, p.displayName, p.selected),
        ],
      );
      final state = await service.loadRepositoryState(profiles.single.id);
      final expected = await reference.loadRepositoryState(profiles.single.id);
      expect(state.revision, expected.revision);
      expect(
        [for (final student in state.students) student.studentId],
        [for (final student in expected.students) student.studentId],
      );
      expect(state.inventory.toWire(), expected.inventory.toWire());
      expect(state.goals, isEmpty);
      expect(
        (await service.listStudents()).length,
        (await reference.listStudents()).length,
      );
      expect(
        (await service.listInventoryItems()).items.length,
        (await reference.listInventoryItems()).items.length,
      );
    });

    test('design-review selects the scenario and unknown names fail', () {
      final service = createMockAppService(
        scenario: mockDesignReviewScenarioName,
      );
      addTearDown(service.dispose);
      expect(service, isA<MockDesignReviewScenario>());
      expect(
        () => createMockAppService(scenario: 'design_review'),
        throwsArgumentError,
      );
    });
  });

  group('design-review scenario', () {
    late MockDesignReviewScenario service;

    setUp(() {
      service = MockDesignReviewScenario();
      addTearDown(service.dispose);
    });

    test('selects the review account', () async {
      final profiles = await service.listProfiles();
      expect(profiles, hasLength(1));
      final profile = profiles.single;
      expect(profile.id, designReviewProfileId);
      expect(profile.displayName, '거모이는존재한다 (v7 UI 테스트)');
      expect(profile.avatarStudentId, 'airi');
      expect(profile.selected, isTrue);
    });

    test(
      'Stats-Growth: 128 / 170, bins, 63.4%, 64 max level, 9 planned',
      () async {
        final state = await service.loadRepositoryState(designReviewProfileId);
        final catalog = await service.listStudents();
        expect(
          catalog,
          hasLength(StatisticsGrowthFixtureExpected.catalogCount),
        );
        final growth = buildStatisticsGrowth(state: state, catalog: catalog)!;
        expect(growth.ownedCount, StatisticsGrowthFixtureExpected.ownedCount);
        expect(
          growth.catalogCount,
          StatisticsGrowthFixtureExpected.catalogCount,
        );
        expect([
          for (final bin
              in growth.histogram(StatisticsGrowthMetric.growth).bins)
            bin.length,
        ], StatisticsGrowthFixtureExpected.bins);
        expect(
          statisticsPercentText(growth.averageGrowth!, decimals: 1),
          StatisticsGrowthFixtureExpected.averageGrowthText,
        );
        expect(
          growth.maxLevelCount,
          StatisticsGrowthFixtureExpected.maxLevelCount,
        );
        expect(
          growth.plannedCount,
          StatisticsGrowthFixtureExpected.plannedCount,
        );
      },
    );

    test(
      'active plan: 5 phases, first shortage P2 tech note, 6 blocked',
      () async {
        final plan = await service.loadRepositoryPlan(designReviewProfileId);
        expect(plan.document.phases, hasLength(5));
        expect(plan.calculation?.firstBottleneckPhaseNumber, 2);
        final state = await service.loadRepositoryState(designReviewProfileId);
        expect({
          for (final goal in state.goals) goal.studentId,
        }, statisticsGrowthFixturePlannedIds.toSet());
        final projection = await service.calculatePlanningDocument(
          currentStudents: _currentStudents(state),
          inventory: state.inventory.toWire(),
          document: plan.document.toWire(),
        );
        expect(projection['document_id'], plan.document.id);
        final planning = StatisticsPlanning.build(
          document: plan.document,
          projection: projection,
        )!;
        expect(planning.phaseCount, StatisticsPlanFixtureExpected.phaseCount);
        expect(planning.firstShortagePhase, 2);
        expect(
          planning.firstShortage?.tile.name,
          StatisticsPlanFixtureExpected.firstResource,
        );
        expect(
          planning.blockedStudents,
          StatisticsPlanFixtureExpected.blockedStudents,
        );
        expect(
          [
            for (final line in planning.c3Lines)
              [for (final value in line.values) (value * 100).round()],
          ],
          [for (final item in StatisticsPlanFixtureExpected.c3) item.$2],
        );
      },
    );

    test(
      'a changed plan structure falls back to the default mock calculation',
      () async {
        final plan = await service.loadRepositoryPlan(designReviewProfileId);
        final document = plan.document.toWire();
        final phases = List<Object?>.of(document['phases'] as List)
          ..removeLast();
        final projection = await service.calculatePlanningDocument(
          currentStudents: const [],
          inventory: const {'version': 1, 'entries': <Object>[]},
          document: {...document, 'phases': phases},
        );
        expect(projection['bottlenecks'], isEmpty);
      },
    );

    test(
      'inventory: KPI +3 · −1 · 6 decline · 3 days, Rio sparkline',
      () async {
        final controller = InventoryController(service);
        addTearDown(controller.dispose);
        await controller.load();
        expect(controller.historyError, isNull);
        final deltas = controller.kpiDeltas;
        expect(deltas.shortage, 3);
        expect(deltas.excess, -1);
        expect(deltas.decline, 6);
        expect(deltas.lastScanDays, 3);
        final rio = controller.sparklineFor(_rio)!;
        expect([for (final p in rio.points) p.value], [0, 0, 1, 1]);
        expect(rio.summary, '순변화 +1 · 이전 스캔과 이상 없음');
        final rows = (await service.calculateShortages(
          currentStudents: const [],
          plan: const {},
          inventory: (await service.loadRepositoryState(
            designReviewProfileId,
          )).inventory.toWire(),
        )).rows;
        final rioRow = rows.singleWhere((row) => row.resourceKey == _rio);
        expect((rioRow.owned, rioRow.requiredAmount), (1, 450));
      },
    );

    test('account meta: owned / total and last scan yesterday 21:40', () async {
      final summary = (await service.loadRepositoryHistorySummary([
        designReviewProfileId,
      ])).profiles.single;
      final lastScan = accountLastScanText(
        summary.lastScanAt,
        service.inventoryNow,
      );
      expect(lastScan, '어제 21:40');
      final owned = (await service.loadRepositoryState(
        designReviewProfileId,
      )).students.length;
      final total = (await service.listStudents()).length;
      expect(
        accountEditorMetaText(owned: owned, total: total, lastScan: lastScan),
        '보유 128 / 170 · 마지막 스캔 어제 21:40',
      );
    });

    test('writes stay in memory and a new scenario starts over', () async {
      final state = await service.loadRepositoryState(designReviewProfileId);
      await service.saveRepositoryInventory(
        designReviewProfileId,
        RepositoryInventoryState.fromWire({
          'version': 1,
          'entries': [
            for (final entry in state.inventory.entries)
              if ((entry['item_id'] ?? entry['key']) == _rio)
                {...entry, 'quantity': '7'}
              else
                entry,
          ],
        }),
        state.revision,
        'mockdemo-write',
      );
      String? rioQuantity(RepositoryState state) =>
          [
                for (final entry in state.inventory.entries)
                  if ((entry['item_id'] ?? entry['key']) == _rio)
                    entry['quantity'],
              ].single
              as String?;
      expect(
        rioQuantity(await service.loadRepositoryState(designReviewProfileId)),
        '7',
      );
      final fresh = MockDesignReviewScenario();
      addTearDown(fresh.dispose);
      expect(
        rioQuantity(await fresh.loadRepositoryState(designReviewProfileId)),
        inventoryFixtureOwned[_rio],
      );
    });
  });

  group('screens with the scenario service', () {
    testWidgets('statistics growth KPI band shows the Stats-Growth numbers', (
      tester,
    ) async {
      await _pump(
        tester,
        (service) => StatisticsPage(service: service, onOpen: (_) {}),
      );
      final kpis = [
        for (var index = 0; index < 5; index++)
          tester.widget<KpiTile>(
            find.descendant(
              of: find.byKey(ValueKey('statistics-kpi-growth-$index')),
              matching: find.byType(KpiTile),
            ),
          ),
      ];
      expect(
        [for (final kpi in kpis) kpi.value],
        ['128', '63.4%', '64명', '8명', '9명'],
      );
      expect(kpis.first.delta, '/ 170 · —');
      expect(tester.takeException(), isNull);
    });

    testWidgets('inventory KPI strip shows the Inventory numbers', (
      tester,
    ) async {
      await _pump(
        tester,
        (service) => InventoryPage(
          service: service,
          onOpenPlan: () {},
          onOpenScan: () {},
          active: true,
        ),
      );
      String? text(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).data;
      expect(text('inventory-kpi-shortage-delta'), '+3 지난 스캔 대비');
      expect(text('inventory-kpi-excess-delta'), '−1');
      expect(text('inventory-kpi-decline'), '6종');
      expect(text('inventory-kpi-last-scan'), '3일 전');
      expect(tester.takeException(), isNull);
    });
  });
}
