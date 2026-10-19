// FE7-h: 통계 이력 화면(기준 데이터 · KPI 증감 · A6 성장 추이 · B3 주요 재화 변화 · 스냅샷 1회 문구, 시안 Stats-Growth ·
// Stats-Inventory · Stats-Growth-Filter).
//
// 시안 숫자 이력 fixture(`statistics_history_fixture.dart`)를 서비스가 FB-2 질의(순수 Mock 질의 함수)로 답한다. 시계는
// fixture 고정 시각(`AppClockSource`)이다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/app_clock.dart';
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_history_projection.dart';
import 'package:ba_planner_v7/ui/kit/ba_chip.dart';
import 'package:ba_planner_v7/ui/kit/kpi_tile.dart';
import 'package:ba_planner_v7/ui/kit/stat_chart.dart';
import 'package:ba_planner_v7/ui/pages/statistics_page.dart';
import 'package:ba_planner_v7/ui/statistics/statistics_history_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_history_fixture.dart';
import 'statistics_supply_fixture.dart';

const _profile = '0123456789abcdef01234567';

/// 이력 fixture를 답하는 서비스. [history]가 null이면 기록 없는 계정이다.
class _HistoryService extends MockAppService implements AppClockSource {
  _HistoryService({
    RepositoryCurrentHistory? history,
    bool recorded = true,
    this.staleEvents = false,
  }) : _history = recorded
           ? history ?? statisticsHistoryFixtureHistory()
           : null;

  RepositoryCurrentHistory? _history;
  RepositoryState _state = statisticsHistoryFixtureState();

  /// events가 다른 revision을 답한다(읽는 사이에 저장된 경우).
  final bool staleEvents;
  int profileCalls = 0, eventsCalls = 0, summaryCalls = 0, latestCalls = 0;

  /// 다른 탭의 저장을 흉내 낸다(상태 revision만 오른다).
  void bumpRevision() {
    _state = RepositoryState.fromWire({
      'profile_id': _state.profileId,
      'revision': _state.revision + 1,
      'students': [for (final student in _state.students) student.toWire()],
      'inventory': _state.inventory.toWire(),
      'goals': {
        'version': 1,
        'goals': [for (final goal in _state.goals) goal.values],
      },
    });
    _history = null;
  }

  @override
  DateTime get clockNow => statisticsHistoryFixtureNow;

  @override
  Future<List<RepositoryProfile>> listProfiles() async {
    profileCalls++;
    return const [
      RepositoryProfile(
        id: _profile,
        displayName: 'Main',
        revision: 1,
        selected: true,
      ),
    ];
  }

  @override
  Future<RepositoryState> loadRepositoryState(String profileId) async => _state;

  @override
  Future<List<StudentCatalogEntry>> listStudents() async =>
      statisticsHistoryFixtureCatalog();

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
  ) async {
    summaryCalls++;
    return RepositoryHistorySummaryResult.fromWire({
      'profiles': [
        for (final id in profileIds)
          (_history?.summarize(id, _state.revision) ??
                  RepositoryHistorySummary.unrecorded(id, _state.revision))
              .toWire(),
      ],
    });
  }

  @override
  Future<RepositoryHistoryEventsResult> loadRepositoryHistoryEvents(
    RepositoryHistoryEventsRequest request,
  ) async {
    eventsCalls++;
    final state = staleEvents
        ? RepositoryState.fromWire({
            'profile_id': _state.profileId,
            'revision': _state.revision + 1,
            'students': [
              for (final student in _state.students) student.toWire(),
            ],
            'inventory': _state.inventory.toWire(),
            'goals': {'version': 1, 'goals': <Object>[]},
          })
        : _state;
    return repositoryHistoryEvents(state, _history, request);
  }

  @override
  Future<RepositoryHistoryScanLatestResult> loadRepositoryHistoryScanLatest(
    RepositoryHistoryScanLatestRequest request,
  ) async {
    latestCalls++;
    return repositoryHistoryScanLatest(
      request.profileId,
      _state.revision,
      _history,
      request,
    );
  }
}

/// 지금 상태 위에 9/22 21:40 학생 스캔 하나(바뀐 값 없음)만 있는 이력(시안 Stats-Growth-Filter "스냅샷 1회").
RepositoryCurrentHistory _oneStudentScan() {
  final state = statisticsHistoryFixtureState();
  final before = statisticsHistoryFixtureState(revision: state.revision - 1);
  return RepositoryCurrentHistory.empty(legacy: before).appendScan(
    before,
    state,
    DateTime(2026, 9, 22, 21, 40),
    rawScanKind: 'student',
    rawInventoryScanProfile: null,
    scanContext: const {
      'session_id': 'one',
      'generation': 1,
      'candidate_id': 'one-candidate',
      'candidate_revision': 0,
    },
    studentIds: [for (final student in state.students) student.studentId],
    resourceKeys: const [],
  );
}

Widget _subject(AppService service, {bool visible = true}) => MaterialApp(
  home: Scaffold(
    body: TickerMode(
      enabled: visible,
      child: StatisticsPage(service: service, onOpen: (_) {}),
    ),
  ),
);

Future<_HistoryService> _pump(
  WidgetTester tester, {
  _HistoryService? service,
  Size size = const Size(2560, 1208),
  String topic = 'growth',
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final subject = service ?? _HistoryService();
  addTearDown(subject.dispose);
  await tester.pumpWidget(_subject(subject));
  await tester.pumpAndSettle();
  if (topic != 'growth') {
    await tester.tap(find.byKey(ValueKey('statistics-topic-$topic')));
    await tester.pumpAndSettle();
  }
  return subject;
}

BaChip _base(WidgetTester tester, String key) =>
    tester.widget<BaChip>(find.byKey(ValueKey('statistics-base-$key-value')));

KpiTile _kpi(WidgetTester tester, String topic, int index) =>
    tester.widget<KpiTile>(
      find.descendant(
        of: find.byKey(ValueKey('statistics-kpi-$topic-$index')),
        matching: find.byType(KpiTile),
      ),
    );

List<String?> _deltas(WidgetTester tester, String topic) => [
  for (var index = 0; index < 5; index++) _kpi(tester, topic, index).delta,
];

T _painter<T>(WidgetTester tester, String key) =>
    tester.widget<StatChartFrame>(find.byKey(ValueKey(key))).painter as T;

void main() {
  testWidgets('base data chips read the scan history (artboard numbers)', (
    tester,
  ) async {
    await _pump(tester);
    final student = _base(tester, 'student-scan');
    expect(student.label, StatisticsHistoryFixtureExpected.studentScan);
    expect(student.tone, AppTones.ok);
    final inventory = _base(tester, 'inventory-scan');
    expect(inventory.label, StatisticsHistoryFixtureExpected.inventoryScan);
    expect(inventory.tone, AppTones.warn);
    final snapshots = _base(tester, 'snapshots');
    expect(snapshots.label, StatisticsHistoryFixtureExpected.snapshots);
    expect(snapshots.tone, AppTones.gray);
  });

  testWidgets('growth KPI deltas compare with the previous student snapshot', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      _deltas(tester, 'growth'),
      StatisticsHistoryFixtureExpected.growthDeltas,
    );
    for (final index in [1, 2, 3]) {
      expect(_kpi(tester, 'growth', index).deltaTone, KpiDeltaTone.gain);
    }
    // 계획 등록: 목표는 이력에 없다.
    expect(_kpi(tester, 'growth', 4).deltaTone, KpiDeltaTone.unknown);
  });

  testWidgets('A6 draws six snapshots with the 14-day highlight', (
    tester,
  ) async {
    await _pump(tester);
    final painter = _painter<StatisticsGrowthTrendPainter>(
      tester,
      'statistics-a6-chart',
    );
    expect(
      painter.points.map((point) => point.label),
      StatisticsHistoryFixtureExpected.a6Labels,
    );
    expect(painter.points.map((point) => point.percent), [
      58.1,
      59.0,
      60.2,
      61.4,
      62.2,
      63.4,
    ]);
    expect(painter.highlightStart, 3);
    expect(painter.highlightText, StatisticsHistoryFixtureExpected.a6Highlight);
    // 그래프가 있으면 A4 · A6 줄은 원래 높이(368)다.
    expect(
      tester.getSize(find.byKey(const ValueKey('statistics-tile-A6'))).height,
      closeTo(368, 0.5),
    );
    // "준비 중" 타일은 없다(A3 · A4는 FE7-f, A5는 FE7-i 그래프).
    expect(find.text('준비 중'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory: KPI deltas, scope scan time and B3 panels', (
    tester,
  ) async {
    await _pump(tester, topic: 'inventory');
    expect(
      _deltas(tester, 'inventory').take(4),
      StatisticsHistoryFixtureExpected.inventoryDeltas,
    );
    // 스캔 없음 칸의 증감 자리는 카테고리 이름 그대로다.
    expect(
      _kpi(tester, 'inventory', 4).delta,
      StatisticsSupplyFixtureExpected.unknownLabel,
    );
    expect(find.text('활성 계획 기준 · 인벤토리 스캔 3일 전'), findsOneWidget);
    final painter = _painter<StatisticsResourceTrendPainter>(
      tester,
      'statistics-b3-chart',
    );
    expect(
      painter.panels.map((panel) => panel.name),
      StatisticsHistoryFixtureExpected.b3Panels,
    );
    expect([
      for (final panel in painter.panels)
        statisticsSignedAmount(panel.netChange!),
    ], StatisticsHistoryFixtureExpected.b3Changes);
    expect(painter.panels.map((panel) => panel.required), [
      261500000,
      2245,
      300,
    ]);
    expect(painter.panels.first.points, hasLength(6));
    // B2도 FE7-f 그래프라 인벤토리 주제에 "준비 중"이 없다.
    expect(find.text('준비 중'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('B3 seg switches between 6 snapshots, 4 weeks and all', (
    tester,
  ) async {
    await _pump(tester, topic: 'inventory');
    Future<int> points(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('statistics-tile-B3-seg')),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
      return _painter<StatisticsResourceTrendPainter>(
        tester,
        'statistics-b3-chart',
      ).panels.first.points.length;
    }

    expect(await points('4주'), 5);
    expect(await points('전체'), 6);
    expect(await points('스냅샷 6회'), 6);
  });

  testWidgets('plan KPI deltas share the inventory comparison', (tester) async {
    await _pump(tester, topic: 'plan');
    final deltas = _deltas(tester, 'plan');
    expect(deltas[0], '+6');
    expect(deltas[1], '−2');
    // 막힌 학생(문서 계산) · 미계획(목표)은 이력으로 비교하지 않는다.
    expect(deltas[3], '—');
    expect(deltas[4], '—');
  });

  testWidgets(
    'one snapshot: Stats-Growth-Filter note, deltas — and a lower row',
    (tester) async {
      await _pump(tester, service: _HistoryService(history: _oneStudentScan()));
      expect(find.text(statisticsHistoryMoreScansText), findsNWidgets(1));
      expect(find.text('스냅샷 1회 · 9/22 21:40'), findsOneWidget);
      expect(_base(tester, 'snapshots').label, '1회 · 9/22');
      expect(_deltas(tester, 'growth'), ['/ 170 · —', '—', '—', '—', '—']);
      for (final index in [1, 2, 3, 4]) {
        expect(_kpi(tester, 'growth', index).deltaTone, KpiDeltaTone.unknown);
      }
      // FD-109: 빈 카드 줄은 시안대로 낮다(368 → 328).
      for (final id in ['A4', 'A6']) {
        expect(
          tester.getSize(find.byKey(ValueKey('statistics-tile-$id'))).height,
          closeTo(328, 0.5),
          reason: id,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('no recorded history: — everywhere and the zero-snapshot note', (
    tester,
  ) async {
    await _pump(tester, service: _HistoryService(recorded: false));
    for (final key in ['student-scan', 'inventory-scan', 'snapshots']) {
      expect(_base(tester, key).label, '—', reason: key);
      expect(_base(tester, key).tone, AppTones.gray, reason: key);
    }
    expect(find.text('스냅샷 0회'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('statistics-topic-inventory')));
    await tester.pumpAndSettle();
    expect(find.text('스냅샷 0회'), findsOneWidget);
    expect(find.text('활성 계획 기준 · 인벤토리 스캔 —'), findsOneWidget);
    expect(_deltas(tester, 'inventory').take(4), ['—', '—', '—', '—']);
  });

  testWidgets('a history read across a save is not mixed in', (tester) async {
    await _pump(tester, service: _HistoryService(staleEvents: true));
    expect(find.text(statisticsHistoryMismatchText), findsOneWidget);
    expect(_base(tester, 'snapshots').label, '—');
    expect(_deltas(tester, 'growth')[1], '—');
  });

  testWidgets('showing again re-reads only when the revision changed', (
    tester,
  ) async {
    final service = _HistoryService();
    addTearDown(service.dispose);
    await tester.binding.setSurfaceSize(const Size(2560, 1208));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_subject(service, visible: false));
    await tester.pumpAndSettle();
    expect(service.profileCalls, 0);
    expect(service.eventsCalls, 0);
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(service.profileCalls, 1);
    expect(service.eventsCalls, 1);
    expect(service.latestCalls, 2, reason: '보유 학생 128명 · 카탈로그 23종: 한 번씩');
    expect(service.summaryCalls, 0);
    // 같은 revision: summary만 본다.
    await tester.pumpWidget(_subject(service, visible: false));
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(service.summaryCalls, 1);
    expect(service.profileCalls, 1);
    expect(service.eventsCalls, 1);
    // 다른 탭에서 저장: revision이 바뀌어 다시 읽는다.
    service.bumpRevision();
    await tester.pumpWidget(_subject(service, visible: false));
    await tester.pumpWidget(_subject(service));
    await tester.pumpAndSettle();
    expect(service.summaryCalls, 2);
    expect(service.profileCalls, 2);
    expect(service.eventsCalls, 2);
    expect(_base(tester, 'snapshots').label, '—');
  });

  for (final size in const [Size(1280, 720), Size(1440, 900)]) {
    testWidgets('history widgets fit ${size.width}x${size.height}', (
      tester,
    ) async {
      final service = await _pump(tester, size: size);
      expect(find.byKey(const ValueKey('statistics-a6-chart')), findsOneWidget);
      for (final topic in ['inventory', 'plan', 'growth']) {
        await tester.tap(find.byKey(ValueKey('statistics-topic-$topic')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: topic);
      }
      expect(service.eventsCalls, 1);
    });

    testWidgets('one-snapshot note fits ${size.width}x${size.height}', (
      tester,
    ) async {
      await _pump(
        tester,
        size: size,
        service: _HistoryService(history: _oneStudentScan()),
      );
      expect(
        find.byKey(const ValueKey('statistics-tile-A6-short')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
