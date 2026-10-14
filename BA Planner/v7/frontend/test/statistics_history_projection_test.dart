// FE7-h 통계 이력 projection(기준 데이터 · KPI 증감 · A6 · B3) 단위 테스트.
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/statistics/statistics_growth_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_history_projection.dart';
import 'package:ba_planner_v7/statistics/statistics_supply_projection.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_history.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_growth_fixture.dart';
import 'statistics_history_fixture.dart';
import 'statistics_supply_fixture.dart';

const _profile = '0123456789abcdef01234567';

/// 순수 Mock 질의로 이력을 읽어 색인을 만든다(통계 페이지 `_loadHistory`와 같은 읽기).
StatisticsHistory _build(
  RepositoryState state,
  RepositoryCurrentHistory? history, {
  DateTime? now,
}) {
  final pages = <RepositoryHistoryEventsResult>[];
  var request = RepositoryHistoryEventsRequest(
    profileId: state.profileId,
    limit: inventoryHistoryPageLimit,
  );
  while (true) {
    final page = repositoryHistoryEvents(state, history, request);
    pages.add(page);
    final cursor = page.nextCursor;
    if (cursor == null) break;
    request = request.withCursor(cursor);
  }
  final students = repositoryHistoryScanLatest(
    state.profileId,
    state.revision,
    history,
    RepositoryHistoryScanLatestRequest(
      profileId: state.profileId,
      studentIds: [for (final student in state.students) student.studentId],
    ),
  );
  final resources = repositoryHistoryScanLatest(
    state.profileId,
    state.revision,
    history,
    RepositoryHistoryScanLatestRequest(
      profileId: state.profileId,
      resourceKeys: [
        for (final item in statisticsSupplyFixtureCatalog) item.resourceKey,
      ],
    ),
  );
  return StatisticsHistory.build(
    StatisticsHistoryInput(
      now: now ?? statisticsHistoryFixtureNow,
      state: state,
      pages: pages,
      students: statisticsHistoryFixtureCatalog(),
      lastStudentScanAt: statisticsLastStudentScanAt([students]),
      lastInventoryScanAt: inventoryLastScanAt([resources]),
    ),
  );
}

StatisticsSupply _supply(RepositoryState state) => StatisticsSupply.build(
  catalog: statisticsSupplyFixtureCatalog,
  state: state,
  shortages: statisticsSupplyFixtureShortages(),
  growth: buildStatisticsGrowth(
    state: state,
    catalog: statisticsHistoryFixtureCatalog(),
  ),
)!;

StatisticsGrowth _growth(RepositoryState state) => buildStatisticsGrowth(
  state: state,
  catalog: statisticsHistoryFixtureCatalog(),
)!;

/// [state]를 revision · 인벤토리만 바꿔 다시 만든다(목표는 fixture 그대로).
RepositoryState _restate(
  RepositoryState state,
  int revision, {
  List<Map<String, dynamic>>? entries,
}) => RepositoryState.fromWire({
  'profile_id': state.profileId,
  'revision': revision,
  'students': [for (final student in state.students) student.toWire()],
  'inventory': entries == null
      ? state.inventory.toWire()
      : {'version': 1, 'entries': entries},
  'goals': statisticsGrowthFixtureGoalsWire(),
});

/// 지금 상태 위에 학생 스캔 하나(바뀐 값 없음)만 있는 이력.
RepositoryCurrentHistory _singleStudentScan(
  RepositoryState state,
  DateTime at,
) {
  final before = _restate(state, state.revision - 1);
  return RepositoryCurrentHistory.empty(legacy: before).appendScan(
    before,
    state,
    at,
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

void main() {
  final state = statisticsHistoryFixtureState();
  final history = statisticsHistoryFixtureHistory();

  test('fixture history ends at the fixture state (12 scan applications)', () {
    validateRepositoryHistoryCurrent(history, state);
    expect(history.events, hasLength(12));
    expect(history.events.map((event) => event.source).toSet(), {'scan'});
  });

  test(
    'base data: student / inventory scan time, snapshot count and range',
    () {
      final built = _build(state, history);
      expect(built.snapshotTimes, hasLength(12));
      expect(
        statisticsSnapshotRangeText(built.snapshotTimes),
        StatisticsHistoryFixtureExpected.snapshots,
      );
      expect(
        built.lastStudentScanAt,
        statisticsHistoryStudentScans.last.toUtc(),
      );
      expect(
        built.lastInventoryScanAt,
        statisticsHistoryInventoryScans.last.toUtc(),
      );
      expect(built.inventorySnapshotTimes, [
        for (final at in statisticsHistoryInventoryScans) at.toUtc(),
      ]);
      expect(
        inventoryDaysAgo(built.lastInventoryScanAt!, built.now),
        3,
        reason: '인벤토리 범위 글자 "인벤토리 스캔 3일 전"',
      );
    },
  );

  test('student snapshots are re-derived states with the FD-028 average', () {
    final built = _build(state, history);
    final snapshots = built.studentSnapshots;
    expect(snapshots.map((item) => item.at), [
      for (final at in statisticsHistoryStudentScans) at.toUtc(),
    ]);
    expect([
      for (final item in snapshots) (item.averageGrowth! * 1000).round(),
    ], statisticsHistoryAverageTenths);
    expect(snapshots.map((item) => item.ownedCount), [
      126,
      126,
      126,
      126,
      126,
      128,
    ]);
    // 마지막 스냅샷 = 지금 상태로 센 성장 projection.
    final now = _growth(state);
    expect(snapshots.last.averageGrowth, now.averageGrowth);
    expect(snapshots.last.maxLevelCount, now.maxLevelCount);
    expect(snapshots.last.fullGrowthCount, now.fullGrowthCount);
  });

  test('growth KPI deltas compare with the previous student snapshot', () {
    final deltas = statisticsGrowthDeltas(
      _build(state, history),
      _growth(state),
    );
    expect(deltas.owned, 2);
    expect(deltas.averageTenths, 12);
    expect(deltas.maxLevel, 4);
    expect(deltas.fullGrowth, 1);
  });

  test('supply KPI deltas follow the FE6-f per-resource last scan', () {
    final built = _build(state, history);
    final supply = _supply(state);
    final deltas = statisticsSupplyDeltas(
      built,
      supply,
      catalog: statisticsSupplyFixtureCatalog,
      state: state,
      shortages: statisticsSupplyFixtureShortages(),
    );
    expect(deltas.fulfillment, 6);
    expect(deltas.shortageKinds, -2);
    expect(deltas.excessKinds, 1);
    expect(deltas.metCategories, 1);
    // 부족 · 과잉 종 수 증감은 인벤토리 탭(FE6-f)과 같은 함수 · 같은 4주 색인이다.
    final fe6f = inventoryKpiDeltas(built.inventoryWindow, supply.board);
    expect(fe6f.shortage, deltas.shortageKinds);
    expect(fe6f.excess, deltas.excessKinds);
  });

  test('A6: six points, highlight from the first snapshot within 14 days', () {
    final trend = statisticsGrowthTrend(_build(state, history))!;
    expect(trend.drawable, isTrue);
    expect(
      trend.points.map((point) => statisticsDateText(point.at)),
      StatisticsHistoryFixtureExpected.a6Labels,
    );
    expect(trend.highlightStart, 3);
    expect(trend.highlightText, StatisticsHistoryFixtureExpected.a6Highlight);
  });

  test('B3: currencies first, then planned resources by |net| / required', () {
    final built = _build(state, history);
    final board = _supply(state).board;
    final recent = statisticsResourceTrends(
      built,
      board,
      StatisticsB3Range.recent,
    )!;
    expect(
      recent.panels.map((panel) => panel.name),
      StatisticsHistoryFixtureExpected.b3Panels,
    );
    expect([
      for (final panel in recent.panels)
        statisticsSignedAmount(panel.netChange!),
    ], StatisticsHistoryFixtureExpected.b3Changes);
    expect(recent.panels.first.points, hasLength(6));
    expect(recent.panels.first.current, 98400000);
    expect(recent.panels[2].required, 300);
    // 4주: 지금 − 28일(9/08 12:00) 뒤 점 5개, 전체: 6개.
    final weeks = statisticsResourceTrends(
      built,
      board,
      StatisticsB3Range.weeks4,
    )!;
    expect(weeks.panels.first.points, hasLength(5));
    expect(weeks.panels.first.netChange, 98400000 - 130000000);
    final all = statisticsResourceTrends(built, board, StatisticsB3Range.all)!;
    expect(all.panels.first.points, hasLength(6));
  });

  test('B3 keeps at most the 6 most recent points per resource', () {
    // 같은 재화를 7번 더 스캔한다(점 13개 → 최근 6개).
    var history2 = history;
    var before = state;
    for (var index = 0; index < 7; index++) {
      final entries = [
        for (final entry in before.inventory.entries)
          entry['key'] == 'credits'
              ? {...entry, 'quantity': '${98400000 + index + 1}'}
              : entry,
      ];
      final after = _restate(before, before.revision + 1, entries: entries);
      history2 = history2.appendScan(
        before,
        after,
        DateTime(2026, 10, 6, 8, index),
        rawScanKind: 'inventory',
        rawInventoryScanProfile: 'currencies',
        scanContext: {
          'session_id': 'more-$index',
          'generation': 1,
          'candidate_id': 'more-candidate-$index',
          'candidate_revision': 0,
        },
        studentIds: const [],
        resourceKeys: const ['credits'],
      );
      before = after;
    }
    final built = _build(before, history2);
    final trends = statisticsResourceTrends(
      built,
      _supply(before).board,
      StatisticsB3Range.recent,
    )!;
    final credits = trends.panels.first;
    expect(credits.points, hasLength(statisticsHistoryRecentSnapshots));
    expect(credits.points.last.value, 98400007);
    expect(credits.netChange, 5);
    final all = statisticsResourceTrends(
      built,
      _supply(before).board,
      StatisticsB3Range.all,
    )!;
    expect(all.panels.first.points, hasLength(13));
  });

  test('manual edits after the last scan stay in B3 as a hollow now point', () {
    final entries = [
      for (final entry in state.inventory.entries)
        entry['key'] == 'Item_Icon_SecretStone'
            ? {...entry, 'quantity': '1100'}
            : entry,
    ];
    final edited = _restate(state, state.revision + 1, entries: entries);
    final history2 = history.appendManual(
      state,
      edited,
      'inventory',
      DateTime(2026, 10, 6, 9),
    );
    final built = _build(edited, history2);
    final eligma = statisticsResourceTrends(
      built,
      _supply(edited).board,
      StatisticsB3Range.recent,
    )!.panels[1];
    expect(eligma.points, hasLength(7));
    expect(eligma.points.last.scan, isFalse);
    expect(eligma.points.last.value, 1100);
    expect(eligma.netChange, 1100 - 760);
  });

  test(
    'one student snapshot: A6 shows the more-scans note, deltas unknown',
    () {
      final at = DateTime(2026, 9, 22, 21, 40);
      final one = _singleStudentScan(state, at);
      final built = _build(state, one);
      final trend = statisticsGrowthTrend(built)!;
      expect(trend.drawable, isFalse);
      expect(trend.note, '스냅샷 1회 · 9/22 21:40');
      expect(statisticsSnapshotRangeText(built.snapshotTimes), '1회 · 9/22');
      final deltas = statisticsGrowthDeltas(built, _growth(state));
      expect(deltas.owned, isNull);
      expect(deltas.averageTenths, isNull);
      // 재화 스냅샷이 없어 B3도 문구다.
      final b3 = statisticsResourceTrends(
        built,
        _supply(state).board,
        StatisticsB3Range.recent,
      )!;
      expect(b3.drawable, isFalse);
      expect(b3.note, '스냅샷 0회');
      final supply = statisticsSupplyDeltas(
        built,
        _supply(state),
        catalog: statisticsSupplyFixtureCatalog,
        state: state,
        shortages: statisticsSupplyFixtureShortages(),
      );
      expect(supply.fulfillment, isNull);
      expect(supply.shortageKinds, isNull);
      expect(supply.metCategories, isNull);
    },
  );

  test('no recorded history: everything is unknown, never zero', () {
    final built = _build(state, null);
    expect(statisticsSnapshotRangeText(built.snapshotTimes), '—');
    expect(built.lastStudentScanAt, isNull);
    expect(built.lastInventoryScanAt, isNull);
    final trend = statisticsGrowthTrend(built)!;
    expect(trend.drawable, isFalse);
    expect(trend.note, '스냅샷 0회');
    expect(statisticsGrowthDeltas(built, _growth(state)).owned, isNull);
    expect(statisticsGrowthDeltas(null, _growth(state)).owned, isNull);
  });

  test('clock rollback: no deltas and no trends (FE6-f rule)', () {
    // 마지막 학생 스캔보다 앞선 시각의 학생 스캔을 더한다.
    final before = state;
    final after = _restate(state, state.revision + 1);
    final rolled = history.appendScan(
      before,
      after,
      DateTime(2026, 9, 1, 8),
      rawScanKind: 'student',
      rawInventoryScanProfile: null,
      scanContext: const {
        'session_id': 'rolled',
        'generation': 1,
        'candidate_id': 'rolled-candidate',
        'candidate_revision': 0,
      },
      studentIds: [for (final student in state.students) student.studentId],
      resourceKeys: const [],
    );
    final built = _build(after, rolled);
    expect(built.timestampsMonotonic, isFalse);
    expect(statisticsGrowthTrend(built), isNull);
    expect(
      statisticsResourceTrends(
        built,
        _supply(after).board,
        StatisticsB3Range.recent,
      ),
      isNull,
    );
    expect(statisticsGrowthDeltas(built, _growth(after)).owned, isNull);
  });

  test('B3 without a plan still draws currencies (no required line)', () {
    final built = _build(state, history);
    final board = InventoryBoard.build(
      catalog: statisticsSupplyFixtureCatalog,
      inventory: state.inventory,
      shortages: null,
    );
    final trends = statisticsResourceTrends(
      built,
      board,
      StatisticsB3Range.recent,
    )!;
    expect(trends.panels.map((panel) => panel.name), ['크레딧', '엘리그마']);
    expect(trends.panels.every((panel) => panel.required == null), isTrue);
  });

  test('display helpers', () {
    expect(statisticsSignedTenths(12), '+1.2');
    expect(statisticsSignedTenths(-4), '−0.4');
    expect(statisticsSignedTenths(0), '0.0');
    expect(statisticsSignedAmount(-43600000), '−43.6M');
    expect(statisticsSignedAmount(260), '+260');
    expect(statisticsSignedAmount(0), '0');
    expect(statisticsDateText(DateTime(2026, 9, 2, 21, 40)), '9/02');
    expect(statisticsDateTimeText(DateTime(2026, 9, 22, 21, 40)), '9/22 21:40');
    expect(statisticsSnapshotRangeText(const []), '—');
    expect(statisticsSnapshotNoteText(0, null), '스냅샷 0회');
  });

  test('growth fixture expectations stay as FE7-b', () {
    final growth = _growth(state);
    expect(growth.ownedCount, StatisticsGrowthFixtureExpected.ownedCount);
    expect(
      statisticsPercentText(growth.averageGrowth!, decimals: 1),
      StatisticsGrowthFixtureExpected.averageGrowthText,
    );
    expect(state.profileId, _profile);
  });
}
