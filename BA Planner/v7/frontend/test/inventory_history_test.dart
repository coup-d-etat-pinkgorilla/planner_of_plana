// FE6-f 인벤토리 이력 집계(`lib/ui/inventory/inventory_history.dart`) 단위 테스트.
//
// 고정 시계(2026-10-05 12:00 UTC)로 이력 0 · 1 · 2 · 3회, 수동 수정 섞임, 모르는 수량, 기간 경계, 동점 정렬, 예측 규칙
// (FD-042), KPI 증감(FD-041)을 고정한다.
import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_analysis.dart'
    show InventoryChangeWindow;
import 'package:ba_planner_v7/ui/inventory/inventory_history.dart';
import 'package:ba_planner_v7/ui/inventory/inventory_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 5, 12);

DateTime _ago(int days, [int minutes = 0]) =>
    _now.subtract(Duration(days: days)).add(Duration(minutes: minutes));

InventoryHistoryValue _q(String? quantity) => InventoryHistoryValue.of(quantity);

const _absent = InventoryHistoryValue.absent();

/// 지금 수량에서 시작해 차례로 적용을 쌓는 도우미(이력 · 스캔 점 · 지금이 늘 맞는다).
class _Steps {
  _Steps(Map<String, InventoryHistoryValue> start) : _state = Map.of(start);

  final Map<String, InventoryHistoryValue> _state;
  final _events = <InventoryHistoryEvent>[];
  final _points = <String, InventoryScanPoint>{};
  var _sequence = 0;

  void scan(
    DateTime at,
    String session,
    Map<String, InventoryHistoryValue> values,
  ) => _apply(at, 'scan', session, values);

  void manual(DateTime at, Map<String, InventoryHistoryValue> values) =>
      _apply(at, 'manual', null, values);

  void _apply(
    DateTime at,
    String source,
    String? session,
    Map<String, InventoryHistoryValue> values,
  ) {
    final changes = <String, (InventoryHistoryValue, InventoryHistoryValue)>{};
    values.forEach((key, value) {
      final before = _state[key] ?? _absent;
      if (before != value) changes[key] = (before, value);
      if (value.present) {
        _state[key] = value;
      } else {
        _state.remove(key);
      }
    });
    _sequence++;
    _events.add(
      InventoryHistoryEvent(
        sequence: _sequence,
        recordedAt: at,
        source: source,
        sessionId: session,
        resourceKeys: values.keys.toList(),
        changes: changes,
      ),
    );
    if (session != null) {
      _points[session] = InventoryScanPoint(
        sessionId: session,
        sequence: _sequence,
        recordedAt: at,
      );
    }
  }

  /// [window] 안의 적용만 넘긴다(서비스의 from_at 거르기와 같다).
  InventoryHistory build({
    InventoryHistoryCoverage coverage = const InventoryHistoryCoverage(
      origin: 'empty',
    ),
    DateTime? lastScanAt,
    Duration window = inventoryHistoryWindow,
  }) {
    final from = _now.subtract(window);
    bool inside(DateTime at) => !at.isBefore(from);
    return InventoryHistory.build(
      InventoryHistoryInput(
        now: _now,
        current: Map.of(_state),
        events: [
          for (final event in _events)
            if (inside(event.recordedAt)) event,
        ],
        scanPoints: [
          for (final point in _points.values)
            if (inside(point.recordedAt)) point,
        ],
        coverage: coverage,
        lastScanAt: lastScanAt,
      ),
    );
  }
}

InventoryCatalogEntry _item(
  String key,
  String name,
  String category,
  int order,
) => InventoryCatalogEntry(
  resourceKey: key,
  itemId: key,
  displayName: name,
  category: category,
  profileId: category,
  orderIndex: order,
  zeroFillAllowed: true,
  school: null,
  family: null,
  tier: null,
);

final _catalog = [
  _item('A', '기술 노트 (최상급)', 'tech_notes', 0),
  _item('B', '밀레니엄 BD', 'tactical_bd', 1),
  _item('C', '상급 활동 보고서', 'activity_report', 2),
  _item('D', '네브라 디스크', 'oopart', 3),
  _item('credits', '크레딧', 'credits', 4),
];

/// 계획 필요량(A 60 · B 28 · D 40 · 크레딧 1000). C는 계획 밖.
const _required = {'A': 60, 'B': 28, 'D': 40, 'credits': 1000};

InventoryBoard _board(Map<String, String?> owned, {bool plan = true}) =>
    InventoryBoard.build(
      catalog: _catalog,
      inventory: RepositoryInventoryState.fromWire({
        'version': 1,
        'entries': [
          for (final entry in owned.entries)
            {'key': entry.key, 'item_id': entry.key, 'quantity': entry.value},
        ],
      }),
      shortages: plan
          ? InventoryShortageResult([
              for (final entry in _required.entries)
                InventoryShortageRow(
                  resourceKey: entry.key,
                  itemId: entry.key,
                  displayName: entry.key,
                  category: 'x',
                  requiredAmount: entry.value,
                  owned: int.tryParse(owned[entry.key] ?? ''),
                  shortage: null,
                  affectedStudentIds: const ['s'],
                  resolved: true,
                ),
            ], const [])
          : null,
    );

void main() {
  group('display helpers', () {
    test('signed counts use U+2212 and plain zero', () {
      expect(inventorySignedCount(3), '+3');
      expect(inventorySignedCount(-1), '−1');
      expect(inventorySignedCount(0), '0');
    });

    test('days ago is a local calendar difference, never negative', () {
      expect(inventoryDaysAgo(_ago(3), _now), 3);
      expect(inventoryDaysAgo(_now, _now), 0);
      expect(inventoryDaysAgo(_now.add(const Duration(days: 2)), _now), 0);
      expect(inventoryDaysAgoLabel(null), '—');
      expect(inventoryDaysAgoLabel(0), '오늘');
      expect(inventoryDaysAgoLabel(3), '3일 전');
    });

    test('week labels round to the nearest week (시안 3주 전 · 2주 전 · 1주 전 · 지금)', () {
      expect(inventoryWeeksAgoLabel(_ago(24), _now), '3주 전');
      expect(inventoryWeeksAgoLabel(_ago(17), _now), '2주 전');
      expect(inventoryWeeksAgoLabel(_ago(10), _now), '1주 전');
      expect(inventoryWeeksAgoLabel(_ago(3), _now), '지금');
      expect(inventoryWeeksAgoLabel(_now.add(const Duration(hours: 1)), _now), '지금');
    });

    test('topic particle follows the last sound', () {
      expect(inventoryTopicParticle('밀레니엄 BD'), '는');
      expect(inventoryTopicParticle('밀레니엄 BD (상급)'), '은');
      expect(inventoryTopicParticle('네브라 디스크'), '는');
      expect(inventoryTopicParticle('시계 T8'), '은');
      expect(inventoryTopicParticle('보고서 T2'), '는');
      expect(inventoryTopicParticle('Item L'), '은');
    });

    test('S5 captions follow the window', () {
      expect(InventoryChangeWindow.week1.caption, '주간 순증감 상위 (오른쪽 증가 · 왼쪽 감소)');
      expect(InventoryChangeWindow.week2.caption, '2주 순증감 상위 (오른쪽 증가 · 왼쪽 감소)');
      expect(InventoryChangeWindow.week4.span, const Duration(days: 28));
    });
  });

  group('reconstruction', () {
    test('scan points belong only to resources in the session scope', () {
      final steps = _Steps({'A': _q('30'), 'B': _q('10')})
        ..scan(_ago(10), 's1', {'A': _q('20')})
        ..scan(_ago(9), 's2', {'B': _q('12')})
        ..scan(_ago(3), 's3', {'A': _q('15'), 'B': _q('12')});
      final history = steps.build();
      expect([for (final p in history.track('A')) p.value.known], [20, 15]);
      expect([for (final p in history.track('B')) p.value.known], [12, 12]);
      expect(history.track('C'), isEmpty);
      expect(history.scanSessionCount, 3);
      expect(history.current('A'), _q('15'));
      expect(history.current('C'), _absent);
    });

    test('a manual change between scans is part of the next point state', () {
      final steps = _Steps({'A': _q('30')})
        ..scan(_ago(20), 's1', {'A': _q('30')})
        ..manual(_ago(15), {'A': _q('25')})
        ..scan(_ago(10), 's2', {'C': _q('5')})
        ..scan(_ago(5), 's3', {'A': _q('25')});
      final history = steps.build();
      expect([for (final p in history.track('A')) p.value.known], [30, 25]);
      expect([for (final p in history.track('A')) p.sessionId], ['s1', 's3']);
    });

    test('a session with several applications uses its last state and union scope', () {
      final steps = _Steps({'A': _q('1'), 'B': _q('1')})
        ..scan(_ago(6), 's1', {'A': _q('2')})
        ..scan(_ago(6, 1), 's1', {'B': _q('3')});
      final history = steps.build();
      expect([for (final p in history.track('A')) p.value.known], [2]);
      expect([for (final p in history.track('B')) p.value.known], [3]);
    });

    test('window start state: boundary events are undone (state just before)', () {
      final steps = _Steps({'A': _q('10')})
        ..manual(_ago(30), {'A': _q('10')})
        ..scan(_ago(7), 's1', {'A': _q('20')})
        ..scan(_ago(2), 's2', {'A': _q('26')});
      final history = steps.build();
      // 7일 전 정각의 적용은 1주 기간 안이다 → 1주 시작 = 그 앞 10.
      expect(history.startOf('A', InventoryChangeWindow.week1), _q('10'));
      expect(history.startOf('A', InventoryChangeWindow.week2), _q('10'));
      expect(history.startOf('A', InventoryChangeWindow.week4), _q('10'));
      expect(history.startOf('C', InventoryChangeWindow.week1), _absent);
    });

    test('coverage decides whether a window start is known', () {
      Map<String, InventoryHistoryValue> start() => {'A': _q('10')};
      final legacyLate = (_Steps(start())..scan(_ago(10), 's1', {'A': _q('12')}))
          .build(
            coverage: InventoryHistoryCoverage(
              origin: 'legacy',
              firstRetainedAt: _ago(10),
            ),
          );
      expect(legacyLate.knows(InventoryChangeWindow.week1), isTrue);
      expect(legacyLate.knows(InventoryChangeWindow.week2), isFalse);
      expect(legacyLate.startOf('A', InventoryChangeWindow.week2), isNull);

      final compacted = (_Steps(start())..scan(_ago(5), 's1', {'A': _q('12')}))
          .build(
            coverage: InventoryHistoryCoverage(
              origin: 'compacted',
              baselineAt: _ago(20),
              firstRetainedAt: _ago(5),
            ),
          );
      expect(compacted.knows(InventoryChangeWindow.week2), isTrue);
      expect(compacted.knows(InventoryChangeWindow.week4), isFalse);

      final rollback = (_Steps(start())..scan(_ago(5), 's1', {'A': _q('12')}))
          .build(
            coverage: const InventoryHistoryCoverage(
              origin: 'empty',
              timestampsMonotonic: false,
            ),
          );
      expect(rollback.knows(InventoryChangeWindow.week1), isFalse);
      expect(InventoryHistoryCoverage.unrecorded.covers(_now), isFalse);
    });

    test('current bucket: present, unknown quantity and missing rows stay distinct', () {
      final current = inventoryHistoryCurrent(
        RepositoryInventoryState.fromWire({
          'version': 1,
          'entries': [
            {'key': 'A', 'item_id': 'A', 'quantity': '4'},
            {'key': 'B', 'item_id': 'B', 'quantity': null},
          ],
        }),
      );
      expect(current['A'], _q('4'));
      expect(current['B'], _q(null));
      expect(current['B']!.known, isNull);
      expect(current.containsKey('C'), isFalse);
    });
  });

  group('KPI deltas (FD-041)', () {
    test('no history, one scan → unknown (—), last scan days still known', () {
      expect(
        inventoryKpiDeltas(null, _board({'A': '10'})).shortage,
        isNull,
      );
      final one = (_Steps({'A': _q('70'), 'B': _q('30')})
            ..scan(_ago(3), 's1', {'A': _q('10'), 'B': _q('20')}))
          .build(lastScanAt: _ago(3));
      final deltas = inventoryKpiDeltas(one, _board({'A': '10', 'B': '20'}));
      expect(deltas.shortage, isNull);
      expect(deltas.excess, isNull);
      expect(deltas.decline, isNull);
      expect(deltas.lastScanDays, 3);
    });

    test('two scans: shortage/excess flips and declines against the previous scan', () {
      final steps = _Steps({
        'A': _q('70'),
        'B': _q('30'),
        'C': _q('9'),
        'D': _q('62'),
        'credits': _q('5000'),
      })
        ..scan(_ago(10), 's1', {
          'A': _q('70'),
          'B': _q('30'),
          'C': _q('9'),
          'D': _q('62'),
          'credits': _q('5000'),
        })
        // 수동 수정은 지금 수량에 들어간다(기준은 스캔 점).
        ..manual(_ago(5), {'C': _q('7')})
        ..scan(_ago(3), 's2', {
          'A': _q('10'),
          'B': _q('20'),
          'D': _q('3'),
          'credits': _q('1'),
        });
      final history = steps.build(lastScanAt: _ago(3));
      final board = _board({
        'A': '10',
        'B': '20',
        'C': '7',
        'D': '3',
        'credits': '1',
      });
      final deltas = inventoryKpiDeltas(history, board);
      // A 70→10(부족으로), B 30→20(부족으로), D 62→3(과잉에서 부족으로). 크레딧은 세지 않는다.
      expect(deltas.shortage, 3);
      expect(deltas.excess, -1);
      // C는 스캔 점이 1개(s1)뿐이라 비교하지 않는다(수동 9→7은 지난 스캔 비교가 아니다).
      expect(deltas.decline, 3);
      expect(deltas.lastScanDays, 3);
    });

    test('unknown quantities are skipped, never counted as 0', () {
      final steps = _Steps({'A': _q('70'), 'B': _q(null)})
        ..scan(_ago(10), 's1', {'A': _q(null), 'B': _q(null)})
        ..scan(_ago(3), 's2', {'A': _q('10'), 'B': _q('20')});
      final deltas = inventoryKpiDeltas(
        steps.build(),
        _board({'A': '10', 'B': '20'}),
      );
      expect(deltas.shortage, isNull);
      expect(deltas.decline, isNull);
    });

    test('without a plan, decline still counts but shortage/excess are unknown', () {
      final steps = _Steps({'C': _q('9')})
        ..scan(_ago(10), 's1', {'C': _q('9')})
        ..scan(_ago(3), 's2', {'C': _q('4')});
      final deltas = inventoryKpiDeltas(
        steps.build(),
        _board({'C': '4'}, plan: false),
      );
      expect(deltas.shortage, isNull);
      expect(deltas.excess, isNull);
      expect(deltas.decline, 1);
    });

    test('clock rollback suppresses deltas', () {
      final steps = _Steps({'A': _q('70')})
        ..scan(_ago(10), 's1', {'A': _q('70')})
        ..scan(_ago(3), 's2', {'A': _q('10')});
      final deltas = inventoryKpiDeltas(
        steps.build(
          coverage: const InventoryHistoryCoverage(
            origin: 'empty',
            timestampsMonotonic: false,
          ),
          lastScanAt: _ago(3),
        ),
        _board({'A': '10'}),
      );
      expect(deltas.shortage, isNull);
      expect(deltas.decline, isNull);
      expect(deltas.lastScanDays, 3);
    });
  });

  group('sparkline', () {
    test('zero points: empty', () {
      final history = _Steps({'A': _q('1')}).build();
      final spark = inventorySparkline(history, 'A');
      expect(spark.points, isEmpty);
      expect(spark.scanCount, 0);
    });

    test('one point: single note', () {
      final history = (_Steps({'A': _q('1')})..scan(_ago(3), 's1', {'A': _q('1')}))
          .build();
      final spark = inventorySparkline(history, 'A');
      expect(spark.points.single.label, '지금');
      expect(spark.note, InventorySparkNote.single);
      expect(spark.summary, '비교할 이전 스캔이 없습니다');
    });

    test('시안 엘레프: 0 · 0 · 1 · 1 → 순변화 +1 · 이전 스캔과 이상 없음', () {
      final steps = _Steps({'A': _q('0')});
      for (final (day, value) in [(24, '0'), (17, '0'), (10, '1'), (3, '1')]) {
        steps.scan(_ago(day), 's$day', {'A': _q(value)});
      }
      final spark = inventorySparkline(steps.build(), 'A');
      expect([for (final p in spark.points) p.label], ['3주 전', '2주 전', '1주 전', '지금']);
      expect([for (final p in spark.points) p.value], [0, 0, 1, 1]);
      expect(spark.header, '최근 변화 · 스캔 4회');
      expect(spark.summary, '순변화 +1 · 이전 스캔과 이상 없음');
      expect(spark.warning, isFalse);
    });

    test('two points that differ: 이전 스캔 대비', () {
      final steps = _Steps({'A': _q('5')})
        ..scan(_ago(10), 's1', {'A': _q('5')})
        ..scan(_ago(3), 's2', {'A': _q('8')});
      final spark = inventorySparkline(steps.build(), 'A');
      expect(spark.summary, '순변화 +3 · 이전 스캔 대비 +3');
    });

    test('three falling points: 소진 예상 within 4 weeks (FD-042)', () {
      final steps = _Steps({'A': _q('31')});
      for (final (day, value) in [(24, '31'), (17, '24'), (10, '18'), (3, '12')]) {
        steps.scan(_ago(day), 's$day', {'A': _q(value)});
      }
      final spark = inventorySparkline(steps.build(), 'A');
      expect(spark.note, InventorySparkNote.depletion);
      expect(spark.noteValue, 2);
      expect(spark.summary, '순변화 −19 · 2주 뒤 소진 예상');
      expect(spark.warning, isTrue);
    });

    test('two falling points never predict (fewer than 3 scans)', () {
      final steps = _Steps({'A': _q('30')})
        ..scan(_ago(10), 's1', {'A': _q('30')})
        ..scan(_ago(3), 's2', {'A': _q('2')});
      expect(inventorySparkline(steps.build(), 'A').note, InventorySparkNote.changed);
    });

    test('a manual change after the last scan adds a hollow 지금 point', () {
      final steps = _Steps({'A': _q('20')})
        ..scan(_ago(10), 's1', {'A': _q('20')})
        ..scan(_ago(3), 's2', {'A': _q('20')})
        ..manual(_ago(1), {'A': _q('15')});
      final spark = inventorySparkline(steps.build(), 'A');
      expect([for (final p in spark.points) p.value], [20, 20, 15]);
      expect([for (final p in spark.points) p.scan], [true, true, false]);
      // 같은 라벨(지금 · 지금)은 마지막 점에만.
      expect([for (final p in spark.points) p.label], ['1주 전', '', '지금']);
      expect(spark.scanCount, 2);
      expect(spark.summary, '순변화 −5 · 이전 스캔 대비 −5');
    });

    test('unknown quantity breaks the line and the net change', () {
      final steps = _Steps({'A': _q('20')})
        ..scan(_ago(10), 's1', {'A': _q(null)})
        ..scan(_ago(3), 's2', {'A': _q('22')});
      final spark = inventorySparkline(steps.build(), 'A');
      expect([for (final p in spark.points) p.value], [null, 22]);
      expect(spark.netChange, isNull);
      expect(spark.note, InventorySparkNote.none);
      expect(spark.summary, '순변화 —');
    });
  });

  group('trend', () {
    test('needs three known points; least squares slope per day', () {
      final points = [
        for (final (day, value) in [(24, 65), (17, 57), (10, 50), (3, 43)])
          InventoryHistoryPoint(
            at: _ago(day),
            value: _q('$value'),
            sessionId: 's$day',
          ),
      ];
      final trend = inventoryTrend(points, _now)!;
      expect(trend.points, 4);
      expect(trend.slopePerDay, closeTo(-255.5 / 245, 1e-9));
      expect(inventoryTrend(points.sublist(2), _now), isNull);
      final unknown = [
        ...points.sublist(0, 2),
        InventoryHistoryPoint(at: _ago(1), value: _q(null), sessionId: 'x'),
      ];
      expect(inventoryTrend(unknown, _now), isNull);
      final sameTime = [
        for (final value in [1, 2, 3])
          InventoryHistoryPoint(at: _ago(1), value: _q('$value'), sessionId: 's'),
      ];
      expect(inventoryTrend(sameTime, _now), isNull);
    });
  });

  group('net changes (S5)', () {
    _Steps steps() => _Steps({
      'A': _q('71'),
      'B': _q('16'),
      'C': _q('520'),
      'D': _q('50'),
      'credits': _q('100'),
    })
      ..manual(_ago(31), {'A': _q('71')})
      ..scan(_ago(10), 's1', {
        'A': _q('71'),
        'B': _q('16'),
        'C': _q('520'),
        'D': _q('50'),
        'credits': _q('100'),
      })
      ..scan(_ago(3), 's2', {
        'A': _q('57'),
        'B': _q('40'),
        'C': _q('640'),
        'D': _q('26'),
        'credits': _q('999999'),
      });

    test('rows sort by delta, currencies and zero/unknown are left out', () {
      final history = steps().build();
      final board = _board({
        'A': '57',
        'B': '40',
        'C': '640',
        'D': '26',
        'credits': '999999',
      });
      final changes = inventoryNetChanges(history, board, InventoryChangeWindow.week1);
      expect(changes.known, isTrue);
      expect([for (final row in changes.rows) (row.view.key, row.delta)], [
        ('C', 120),
        ('B', 24),
        ('A', -14),
        ('D', -24),
      ]);
      expect(changes.maxMagnitude, 120);
    });

    test('limit keeps the largest magnitudes; ties: increase first, then catalog order', () {
      final tie = _Steps({'A': _q('10'), 'B': _q('10'), 'C': _q('10'), 'D': _q('10')})
        ..manual(_ago(30), {'A': _q('10')})
        ..scan(_ago(3), 's1', {'A': _q('15'), 'B': _q('5'), 'C': _q('15'), 'D': _q('11')});
      final board = _board({'A': '15', 'B': '5', 'C': '15', 'D': '11'});
      final top2 = inventoryNetChanges(
        tie.build(),
        board,
        InventoryChangeWindow.week1,
        limit: 2,
      );
      expect([for (final row in top2.rows) row.view.key], ['A', 'C']);
      final top3 = inventoryNetChanges(
        tie.build(),
        board,
        InventoryChangeWindow.week1,
        limit: 3,
      );
      expect([for (final row in top3.rows) (row.view.key, row.delta)], [
        ('A', 5),
        ('C', 5),
        ('B', -5),
      ]);
    });

    test('a window outside the recorded range is unknown (no rows, not zero)', () {
      final late = _Steps({'A': _q('1')})..scan(_ago(3), 's1', {'A': _q('9')});
      final history = late.build(
        coverage: InventoryHistoryCoverage(
          origin: 'legacy',
          firstRetainedAt: _ago(3),
        ),
      );
      final changes = inventoryNetChanges(
        history,
        _board({'A': '9'}),
        InventoryChangeWindow.week1,
      );
      expect(changes.known, isFalse);
      expect(changes.rows, isEmpty);
    });

    test('2주 · 4주 use their own boundaries', () {
      final s = _Steps({'C': _q('100')})
        ..manual(_ago(31), {'C': _q('100')})
        ..scan(_ago(20), 's1', {'C': _q('300')})
        ..scan(_ago(10), 's2', {'C': _q('500')})
        ..scan(_ago(3), 's3', {'C': _q('520')});
      final history = s.build();
      final board = _board({'C': '520'});
      int delta(InventoryChangeWindow window) =>
          inventoryNetChanges(history, board, window).rows.single.delta;
      expect(delta(InventoryChangeWindow.week1), 20);
      expect(delta(InventoryChangeWindow.week2), 220);
      expect(delta(InventoryChangeWindow.week4), 420);
    });
  });

  group('forecasts (FD-042)', () {
    InventoryHistory history(Map<String, List<(int, int)>> series) {
      final steps = _Steps({
        for (final entry in series.entries)
          entry.key: _q('${entry.value.first.$2}'),
      });
      final days = {for (final s in series.values) for (final p in s) p.$1}.toList()
        ..sort((a, b) => b.compareTo(a));
      for (final day in days) {
        steps.scan(_ago(day), 's$day', {
          for (final entry in series.entries)
            for (final point in entry.value)
              if (point.$1 == day) entry.key: _q('${point.$2}'),
        });
      }
      return steps.build();
    }

    test('worsening: 4주 뒤 projected shortage (시안 4주 뒤 −66)', () {
      final h = history({
        'A': [(24, 65), (17, 57), (10, 50), (3, 43)],
      });
      final board = _board({'A': '43'});
      final rows = inventoryForecasts(h, board);
      expect(rows.single.kind, InventoryForecastKind.worsening);
      // 필요 60, 지금 43, 기울기 −1.0429/일 → 4주 뒤 13.8 → 부족 46.
      expect(rows.single.shortage, 46);
      expect(rows.single.text, '기술 노트 (최상급) 부족이 커지는 중');
      expect(rows.single.chip, '4주 뒤 −46');
      expect(board.hasShortages, isTrue);
    });

    test('recovering: weeks until the requirement (시안 2주 뒤 0)', () {
      final h = history({
        'B': [(24, 7), (17, 14), (10, 21)],
      });
      final rows = inventoryForecasts(h, _board({'B': '21'}));
      // 필요 28, 지금 21, +1/일 → 7일 → 1주.
      expect(rows.single.kind, InventoryForecastKind.recovering);
      expect(rows.single.weeks, 1);
      expect(rows.single.text, '밀레니엄 BD는 곧 충분');
      expect(rows.single.chip, '1주 뒤 0');
    });

    test('recovering beyond 4 weeks, not short, unplanned or < 3 scans: no row', () {
      final slow = history({
        'B': [(24, 1), (17, 2), (10, 3)],
      });
      expect(inventoryForecasts(slow, _board({'B': '3'})), isEmpty);
      final enough = history({
        'A': [(24, 90), (17, 80), (10, 70)],
      });
      expect(inventoryForecasts(enough, _board({'A': '70'})), isEmpty);
      final unplanned = history({
        'C': [(24, 90), (17, 80), (10, 70)],
      });
      expect(inventoryForecasts(unplanned, _board({'C': '70'})), isEmpty);
      final two = history({
        'A': [(10, 50), (3, 43)],
      });
      expect(inventoryForecasts(two, _board({'A': '43'})), isEmpty);
      expect(
        inventoryForecasts(two, _board({'A': '43'}, plan: false)),
        isEmpty,
      );
    });

    test('both kinds: worst worsening first, then the soonest recovering', () {
      final h = history({
        'A': [(24, 65), (17, 57), (10, 50), (3, 43)],
        'D': [(24, 30), (17, 25), (10, 20), (3, 15)],
        'B': [(24, 7), (17, 14), (10, 21)],
      });
      final rows = inventoryForecasts(
        h,
        _board({'A': '43', 'D': '15', 'B': '21'}),
      );
      expect([for (final row in rows) row.view.key], ['A', 'B']);
      final worsening = inventoryForecasts(
        h,
        _board({'A': '43', 'D': '15', 'B': '21'}),
        limit: 1,
      );
      expect(worsening.single.view.key, 'A');
    });
  });
}
