// 인벤토리 이력 집계(FE6-f, FD-041 · FD-042, E 보고서 §1.5 · §2.5 · §3.2 S5 · §3.5). 위젯과 서비스 호출이 없는 순수
// 계산이다. 통계(FE7-h)도 같은 함수를 쓸 수 있게 화면 상태(보기 · 선택)에 기대지 않는다.
//
// 읽는 기간은 지금 − 28일([inventoryHistoryWindow], 화면에서 가장 긴 기간: 상세 스파크라인 · S5 4주)이다. 그 안의 이력
// (모든 출처: scan · manual · import · unattributed)을 지금 확정 수량에서 거꾸로 되돌려(`inventory_changes`의 before)
// 스캔 점과 기간 시작 시점의 수량을 얻는다.
// - 스캔 점(FB-2c display point): scan 세션마다 그 세션의 마지막 적용 하나다. 재화 하나의 점은 그 세션 승인 scope
//   (합집합)에 그 재화가 든 세션만이다. 인벤토리 스캔은 scan profile마다 세션이 따로라, 다른 profile 세션은 그 재화를
//   다시 보지 않았다.
// - "지난 스캔"(FD-041): 재화마다 마지막 스캔 점 바로 앞 점이다. 수동 수정은 지금 수량에 들어가고, 비교 기준은 늘 scan
//   점이다. 그 재화의 점이 읽는 기간 안에 2개 미만이면 비교하지 않는다(이력 0 · 1회 → `—`).
// - 기간 시작 수량: 그 시각 직전 확정 상태다. 기록이 그 시각을 덮지 못하면(legacy 시각 모름 · 압축 · 기록 없음 · 시계
//   되돌림) 모른다. 0을 만들지 않는다.
// - 추세(FD-042): 그 재화의 스캔 점 중 수량을 아는 점이 3개 이상일 때 최소제곱 직선의 기울기(하루당)다. 예측은 지금 수량에서
//   그 기울기로 [inventoryForecastHorizon](4주)까지만 본다.
// - 서로 다른 재화의 수량은 더하지 않는다(FD-033). 세는 값은 품목 수(종)다. 크레딧 · 엘리그마는 KPI · S5에서 뺀다
//   (KPI 띠 다른 칸과 같은 범위).
// - 시계가 되돌려진 기록(`timestamps_monotonic = false`)이 있으면 증감 · 추세 · 기간 순증감을 내지 않는다(FB-2c 규칙).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../services/repository_service.dart';
import 'inventory_analysis.dart' show InventoryChangeWindow;
import 'inventory_view_model.dart';

/// 이력 읽기 기간(지금 − 28일).
const inventoryHistoryWindow = Duration(days: 28);

/// 예측이 보는 앞날(4주).
const inventoryForecastHorizon = Duration(days: 28);

/// 추세에 필요한 스캔 점 수(FD-042).
const inventoryTrendMinPoints = 3;

/// S5 순증감 상위 행 수(시안 6행).
const inventoryNetChangeRows = 6;

/// S5 "이 추세라면" 행 수(시안 2행).
const inventoryForecastRows = 2;

/// 이력 읽기 한 쪽 최대 건수(FB-2c limit 상한).
const inventoryHistoryPageLimit = 200;

/// scan_latest 한 번에 보내는 재화 key 수(FB-2b 상한).
const inventoryScanLatestChunk = 256;

const _dayMinutes = 1440.0;
const _minus = '−';

/// S5 기간 seg의 길이와 캡션.
extension InventoryChangeWindowSpan on InventoryChangeWindow {
  Duration get span => switch (this) {
    InventoryChangeWindow.week1 => const Duration(days: 7),
    InventoryChangeWindow.week2 => const Duration(days: 14),
    InventoryChangeWindow.week4 => const Duration(days: 28),
  };

  /// 시안 "주간 순증감 상위 (오른쪽 증가 · 왼쪽 감소)". 2주 · 4주는 "2주 순증감 상위 …".
  String get caption =>
      '${this == InventoryChangeWindow.week1 ? '주간' : label} 순증감 상위 (오른쪽 증가 · 왼쪽 감소)';
}

/// 이력의 수량 한 칸. 항목이 없으면 [present]가 false, 항목은 있는데 수량을 모르면 [quantity]가 null이다.
@immutable
class InventoryHistoryValue {
  const InventoryHistoryValue.absent() : present = false, quantity = null;
  const InventoryHistoryValue.of(this.quantity) : present = true;

  final bool present;
  final String? quantity;

  /// 아는 수량(정수). 없거나 모르거나 정수로 읽지 못하면 null.
  int? get known {
    final quantity = this.quantity;
    return present && quantity != null ? int.tryParse(quantity) : null;
  }

  @override
  bool operator ==(Object other) =>
      other is InventoryHistoryValue &&
      other.present == present &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(present, quantity);

  @override
  String toString() => present ? 'qty($quantity)' : 'absent';
}

/// 이력 한 건(집계에 쓰는 것만). [changes]는 정규 resource key → (before, after)다.
@immutable
class InventoryHistoryEvent {
  const InventoryHistoryEvent({
    required this.sequence,
    required this.recordedAt,
    required this.source,
    this.sessionId,
    this.resourceKeys = const [],
    this.changes = const {},
  });

  /// 서비스 DTO에서 만든다.
  factory InventoryHistoryEvent.fromEvent(CurrentHistoryEvent event) {
    InventoryHistoryValue side(HistoryPresence<String> value) => value.present
        ? InventoryHistoryValue.of(value.value)
        : const InventoryHistoryValue.absent();
    return InventoryHistoryEvent(
      sequence: event.sequence,
      recordedAt: DateTime.parse(event.recordedAt),
      source: event.source,
      sessionId: event.source == 'scan' ? event.scanSessionId : null,
      resourceKeys: [
        for (final key in event.appliedResourceKeys)
          historyCanonicalResourceKey(key),
      ],
      changes: {
        for (final change in event.inventoryChanges)
          historyCanonicalResourceKey(change.resourceKey): (
            side(change.before),
            side(change.after),
          ),
      },
    );
  }

  final int sequence;
  final DateTime recordedAt;

  /// `scan` · `manual` · `import` · `unattributed`.
  final String source;

  /// scan 세션 id(scan만).
  final String? sessionId;

  /// 승인 scope의 resource key(정규 key).
  final List<String> resourceKeys;
  final Map<String, (InventoryHistoryValue, InventoryHistoryValue)> changes;
}

/// 스캔 세션의 끝 점(FB-2c `scan_points`).
@immutable
class InventoryScanPoint {
  const InventoryScanPoint({
    required this.sessionId,
    required this.sequence,
    required this.recordedAt,
  });

  factory InventoryScanPoint.fromPoint(HistoryScanPoint point) =>
      InventoryScanPoint(
        sessionId: point.sessionId,
        sequence: point.sequence,
        recordedAt: DateTime.parse(point.recordedAt),
      );

  final String sessionId;
  final int sequence;
  final DateTime recordedAt;
}

/// 이력이 덮는 범위(FB-2c query coverage에서 시각 판단에 쓰는 것만).
@immutable
class InventoryHistoryCoverage {
  const InventoryHistoryCoverage({
    required this.origin,
    this.baselineAt,
    this.firstRetainedAt,
    this.timestampsMonotonic = true,
  });

  factory InventoryHistoryCoverage.fromQuery(
    RepositoryHistoryQueryCoverage coverage,
  ) {
    DateTime? time(String? value) =>
        value == null ? null : DateTime.parse(value);
    return InventoryHistoryCoverage(
      origin: coverage.origin,
      baselineAt: time(coverage.baselineAt),
      firstRetainedAt: time(coverage.firstRetainedAt),
      timestampsMonotonic: coverage.timestampsMonotonic,
    );
  }

  /// 기록이 없는 계정.
  static const unrecorded = InventoryHistoryCoverage(origin: 'unrecorded');

  /// `empty` · `legacy` · `compacted` · `unrecorded`.
  final String origin;
  final DateTime? baselineAt;
  final DateTime? firstRetainedAt;
  final bool timestampsMonotonic;

  /// [boundary] 직전 확정 상태를 이력으로 알 수 있는가.
  ///
  /// - `empty`: 계정이 처음부터 기록되었다.
  /// - 남은 첫 적용이 [boundary] 이전(같아도 됨)이면 그 앞 상태가 경계까지 이어진다.
  /// - `compacted`: 접힌 마지막 적용 시각이 [boundary]보다 앞이면 그 뒤로는 남은 적용뿐이다.
  /// - `legacy`의 첫 적용 전 시각 · `unrecorded` · 시계 되돌림은 모른다.
  bool covers(DateTime boundary) {
    if (!timestampsMonotonic) return false;
    if (origin == 'empty') return true;
    final first = firstRetainedAt;
    if ((origin == 'legacy' || origin == 'compacted') &&
        first != null &&
        !first.isAfter(boundary)) {
      return true;
    }
    final baseline = baselineAt;
    return origin == 'compacted' &&
        baseline != null &&
        baseline.isBefore(boundary);
  }
}

/// 집계 입력. [current]는 정규 resource key → 지금 확정 수량(항목이 없으면 key가 없다)이다.
@immutable
class InventoryHistoryInput {
  const InventoryHistoryInput({
    required this.now,
    required this.current,
    required this.events,
    required this.scanPoints,
    required this.coverage,
    this.lastScanAt,
  });

  final DateTime now;
  final Map<String, InventoryHistoryValue> current;

  /// 읽는 기간([inventoryHistoryWindow]) 안의 적용(순서 무관).
  final List<InventoryHistoryEvent> events;

  /// 읽는 기간 안에서 끝난 스캔 세션.
  final List<InventoryScanPoint> scanPoints;
  final InventoryHistoryCoverage coverage;

  /// 마지막 인벤토리 스캔 시각(카탈로그 재화를 적용한 가장 최근 scan, 기간 밖이어도 된다). 없으면 null.
  final DateTime? lastScanAt;
}

/// 저장된 인벤토리 bucket → 정규 key별 지금 수량.
Map<String, InventoryHistoryValue> inventoryHistoryCurrent(
  RepositoryInventoryState inventory,
) => {
  for (final entry in inventory.entries)
    historyCanonicalResourceKey(inventoryEntryIdentity(entry)):
        InventoryHistoryValue.of(entry['quantity'] as String?),
};

/// FB-2c events 결과(쪽 전부)와 지금 bucket으로 집계 입력을 만든다. 쪽들은 같은 anchor다(cursor).
InventoryHistoryInput inventoryHistoryInputFromQuery({
  required DateTime now,
  required RepositoryInventoryState inventory,
  required List<RepositoryHistoryEventsResult> pages,
  DateTime? lastScanAt,
}) {
  final first = pages.isEmpty ? null : pages.first;
  return InventoryHistoryInput(
    now: now,
    current: inventoryHistoryCurrent(inventory),
    events: [
      for (final page in pages)
        for (final event in page.events) InventoryHistoryEvent.fromEvent(event),
    ],
    scanPoints: [
      for (final point in first?.scanPoints ?? const <HistoryScanPoint>[])
        InventoryScanPoint.fromPoint(point),
    ],
    coverage: first == null
        ? InventoryHistoryCoverage.unrecorded
        : InventoryHistoryCoverage.fromQuery(first.coverage),
    lastScanAt: lastScanAt,
  );
}

/// FB-2b scan_latest 결과들에서 재화를 적용한 가장 최근 scan 시각. 없으면 null.
DateTime? inventoryLastScanAt(
  Iterable<RepositoryHistoryScanLatestResult> results,
) {
  DateTime? latest;
  for (final result in results) {
    for (final row in result.byResourceKey) {
      final scan = row.latestScan;
      if (scan == null) continue;
      final at = DateTime.parse(scan.recordedAt);
      if (latest == null || at.isAfter(latest)) latest = at;
    }
  }
  return latest;
}

/// 재화 하나의 스캔 점.
@immutable
class InventoryHistoryPoint {
  const InventoryHistoryPoint({
    required this.at,
    required this.value,
    required this.sessionId,
  });

  final DateTime at;
  final InventoryHistoryValue value;
  final String sessionId;
}

/// 집계 색인: 재화별 스캔 점, 기간 시작 수량, 지금 수량.
class InventoryHistory {
  InventoryHistory._(
    this.now,
    this.lastScanAt,
    this.timestampsMonotonic,
    this.scanSessionCount,
    this.eventCount,
    this._current,
    this._tracks,
    this._starts,
  );

  /// 지금 수량에서 이력을 거꾸로 되돌려 색인을 만든다.
  factory InventoryHistory.build(InventoryHistoryInput input) {
    final events = [...input.events]
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
    final scopes = <String, Set<String>>{};
    for (final event in input.events) {
      final session = event.sessionId;
      if (event.source != 'scan' || session == null) continue;
      scopes.putIfAbsent(session, () => <String>{}).addAll(event.resourceKeys);
    }
    final points = {
      for (final point in input.scanPoints) point.sequence: point,
    };
    final state = Map<String, InventoryHistoryValue>.of(input.current);
    final tracks = <String, List<InventoryHistoryPoint>>{};
    // 늦은 경계부터(1주 → 2주 → 4주).
    final pending = [...InventoryChangeWindow.values]
      ..sort((a, b) => a.span.compareTo(b.span));
    DateTime boundary(InventoryChangeWindow window) =>
        input.now.subtract(window.span);
    final starts =
        <InventoryChangeWindow, Map<String, InventoryHistoryValue>?>{};
    for (final event in events) {
      // 경계보다 앞선 적용에 닿으면 그 경계 뒤 적용은 모두 되돌렸다 = 경계 직전 상태.
      while (pending.isNotEmpty &&
          event.recordedAt.isBefore(boundary(pending.first))) {
        starts[pending.removeAt(0)] = Map.of(state);
      }
      final point = points[event.sequence];
      if (point != null) {
        for (final key in scopes[point.sessionId] ?? const <String>{}) {
          tracks
              .putIfAbsent(key, () => [])
              .add(
                InventoryHistoryPoint(
                  at: point.recordedAt,
                  value: state[key] ?? const InventoryHistoryValue.absent(),
                  sessionId: point.sessionId,
                ),
              );
        }
      }
      event.changes.forEach((key, change) {
        final before = change.$1;
        if (before.present) {
          state[key] = before;
        } else {
          state.remove(key);
        }
      });
    }
    for (final window in pending) {
      starts[window] = Map.of(state);
    }
    for (final window in InventoryChangeWindow.values) {
      if (!input.coverage.covers(boundary(window))) starts[window] = null;
    }
    return InventoryHistory._(
      input.now,
      input.lastScanAt,
      input.coverage.timestampsMonotonic,
      input.scanPoints.length,
      input.events.length,
      Map.unmodifiable(input.current),
      {
        for (final entry in tracks.entries)
          entry.key: List.unmodifiable(entry.value.reversed),
      },
      starts,
    );
  }

  final DateTime now;
  final DateTime? lastScanAt;

  /// 시계가 되돌려진 기록이 없다(증감 · 추세 · 기간 순증감을 낼 수 있다).
  final bool timestampsMonotonic;

  /// 읽는 기간 안에서 끝난 스캔 세션 수.
  final int scanSessionCount;

  /// 읽는 기간 안의 적용 수(모든 출처). 0이면 보일 변화 기록이 없다.
  final int eventCount;
  final Map<String, InventoryHistoryValue> _current;
  final Map<String, List<InventoryHistoryPoint>> _tracks;
  final Map<InventoryChangeWindow, Map<String, InventoryHistoryValue>?> _starts;

  /// [key]의 지금 수량.
  InventoryHistoryValue current(String key) =>
      _current[historyCanonicalResourceKey(key)] ??
      const InventoryHistoryValue.absent();

  /// [key]의 스캔 점(오래된 것부터).
  List<InventoryHistoryPoint> track(String key) =>
      _tracks[historyCanonicalResourceKey(key)] ??
      const <InventoryHistoryPoint>[];

  /// [window] 시작 시점의 수량을 아는가.
  bool knows(InventoryChangeWindow window) => _starts[window] != null;

  /// [window] 시작 직전의 [key] 수량. 그 시점을 모르면 null.
  InventoryHistoryValue? startOf(String key, InventoryChangeWindow window) {
    final state = _starts[window];
    if (state == null) return null;
    return state[historyCanonicalResourceKey(key)] ??
        const InventoryHistoryValue.absent();
  }
}

// --- 표시 도우미 ----------------------------------------------------------------

/// 부호 있는 정수(`+3` · `−1` · `0`, 빼기는 U+2212).
String inventorySignedCount(int value) => value > 0
    ? '+$value'
    : value < 0
    ? '$_minus${-value}'
    : '0';

/// [at]에서 [now]까지 지난 날 수(지역 달력 날짜 차, 0 이상).
int inventoryDaysAgo(DateTime at, DateTime now) {
  final a = at.toLocal(), n = now.toLocal();
  final days = DateTime.utc(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  return math.max(0, days);
}

/// "마지막 스캔" 값: `오늘` · `n일 전`, 모르면 `—`.
String inventoryDaysAgoLabel(int? days) => days == null
    ? '—'
    : days == 0
    ? '오늘'
    : '$days일 전';

/// 스파크라인 시간 라벨: 지난 주 수를 반올림해 `n주 전`, 0이면 `지금`(시안 3주 전 · 2주 전 · 1주 전 · 지금).
String inventoryWeeksAgoLabel(DateTime at, DateTime now) {
  final weeks = (now.difference(at).inMinutes / _dayMinutes / 7).round();
  return weeks <= 0 ? '지금' : '$weeks주 전';
}

/// [name] 뒤 주제 조사(`은`/`는`). 끝의 한글 · 영문 · 숫자 소리로 고른다(괄호 · 공백은 건너뛴다).
String inventoryTopicParticle(String name) {
  for (var index = name.length - 1; index >= 0; index--) {
    final code = name.codeUnitAt(index);
    if (code >= 0xac00 && code <= 0xd7a3) {
      return (code - 0xac00) % 28 == 0 ? '는' : '은';
    }
    final char = name[index].toLowerCase();
    if (RegExp(r'[0-9]').hasMatch(char)) {
      return '013678'.contains(char) ? '은' : '는';
    }
    if (RegExp(r'[a-z]').hasMatch(char)) {
      return 'lmnr'.contains(char) ? '은' : '는';
    }
  }
  return '는';
}

// --- KPI 증감 -------------------------------------------------------------------

/// KPI 띠 이력 값. 모르면 null(`—`, 0을 만들지 않는다).
@immutable
class InventoryKpiDeltas {
  const InventoryKpiDeltas({
    this.shortage,
    this.excess,
    this.decline,
    this.lastScanDays,
  });

  static const unknown = InventoryKpiDeltas();

  /// 부족 재화 종 수의 지난 스캔 대비 증감.
  final int? shortage;

  /// 과잉 재화(FD-040) 종 수의 지난 스캔 대비 증감.
  final int? excess;

  /// 지난 스캔보다 지금 수량이 적은 재화 종 수("최근 감소").
  final int? decline;

  /// 마지막 인벤토리 스캔 뒤 지난 날 수.
  final int? lastScanDays;
}

/// KPI 띠 증감(FD-041). 재화(크레딧 · 엘리그마)를 뺀 품목마다 "지난 스캔"(그 재화의 마지막 바로 앞 스캔 점) 수량과 지금
/// 보유를 비교한다. 지난 스캔 수량 · 지금 보유를 둘 다 아는 품목만 센다. 계획 필요량은 지금 계획이다(이력은 지난 계획을
/// 남기지 않는다).
InventoryKpiDeltas inventoryKpiDeltas(
  InventoryHistory? history,
  InventoryBoard board,
) {
  if (history == null) return InventoryKpiDeltas.unknown;
  final lastScan = history.lastScanAt;
  final days = lastScan == null
      ? null
      : inventoryDaysAgo(lastScan, history.now);
  if (!history.timestampsMonotonic) {
    return InventoryKpiDeltas(lastScanDays: days);
  }
  var compared = 0, planned = 0, decline = 0, shortage = 0, excess = 0;
  for (final view in board.items) {
    if (view.isCurrency) continue;
    final track = history.track(view.key);
    if (track.length < 2) continue;
    final base = track[track.length - 2].value.known;
    final now = view.owned;
    if (base == null || now == null) continue;
    compared++;
    if (now < base) decline++;
    final required = view.requiredAmount;
    if (!board.hasShortages || required == null) continue;
    planned++;
    int flag(bool value) => value ? 1 : 0;
    shortage += flag(now < required) - flag(base < required);
    final limit = required * inventoryExcessRatio;
    excess += flag(now >= limit) - flag(base >= limit);
  }
  return InventoryKpiDeltas(
    shortage: planned == 0 ? null : shortage,
    excess: planned == 0 ? null : excess,
    decline: compared == 0 ? null : decline,
    lastScanDays: days,
  );
}

// --- 추세 · 스파크라인 -----------------------------------------------------------

/// 최소제곱 추세(FD-042).
@immutable
class InventoryTrend {
  const InventoryTrend({required this.slopePerDay, required this.points});

  /// 하루당 수량 변화.
  final double slopePerDay;

  /// 쓴 스캔 점 수(3 이상).
  final int points;
}

/// [track] 중 수량을 아는 스캔 점이 [inventoryTrendMinPoints]개 이상이면 최소제곱 기울기. 아니면 null.
InventoryTrend? inventoryTrend(
  List<InventoryHistoryPoint> track,
  DateTime now,
) {
  final samples = [
    for (final point in track)
      if (point.value.known != null)
        (
          point.at.difference(now).inMinutes / _dayMinutes,
          point.value.known!.toDouble(),
        ),
  ];
  if (samples.length < inventoryTrendMinPoints) return null;
  final meanX =
      samples.fold<double>(0, (sum, item) => sum + item.$1) / samples.length;
  final meanY =
      samples.fold<double>(0, (sum, item) => sum + item.$2) / samples.length;
  var sxx = 0.0, sxy = 0.0;
  for (final (x, y) in samples) {
    sxx += (x - meanX) * (x - meanX);
    sxy += (x - meanX) * (y - meanY);
  }
  if (sxx == 0) return null;
  return InventoryTrend(slopePerDay: sxy / sxx, points: samples.length);
}

/// [days]일을 주로 올림(최소 1주).
int _weeksCeil(double days) => math.max(1, (days / 7).ceil());

/// 스파크라인 오른쪽 글자 종류.
enum InventorySparkNote {
  /// 읽을 비교가 없다(끝 두 점 중 모르는 값).
  none,

  /// 추세로 4주 안에 0이 된다(`n주 뒤 소진 예상`).
  depletion,

  /// 끝 두 점이 같다(`이전 스캔과 이상 없음`).
  unchanged,

  /// 끝 두 점이 다르다(`이전 스캔 대비 ±n`).
  changed,

  /// 점이 하나뿐이다.
  single,
}

/// 스파크라인 점 하나. [scan]이 false면 마지막 스캔 뒤 바뀐 지금 수량(수동 수정 등)이다.
@immutable
class InventorySparkPoint {
  const InventorySparkPoint({
    required this.label,
    required this.value,
    this.scan = true,
  });

  /// 시간 라벨. 앞 점과 같은 라벨이면 빈 글자다.
  final String label;

  /// 수량. 모르면 null(끊긴 선 · 빗금).
  final int? value;
  final bool scan;
}

/// 상세 "최근 변화" 값.
@immutable
class InventorySparkline {
  const InventorySparkline({
    required this.points,
    required this.scanCount,
    required this.netChange,
    required this.note,
    this.noteValue,
  });

  final List<InventorySparkPoint> points;

  /// 읽는 기간 안에서 이 재화를 본 스캔 세션 수.
  final int scanCount;

  /// 첫 점 → 끝 점 순변화. 모르면 null.
  final int? netChange;
  final InventorySparkNote note;

  /// [InventorySparkNote.depletion]이면 주 수, [InventorySparkNote.changed]면 끝 두 점 차.
  final int? noteValue;

  /// 머리 글자(`최근 변화 · 스캔 n회`).
  String get header => '최근 변화 · 스캔 $scanCount회';

  /// 소진 예상(분홍)인가.
  bool get warning => note == InventorySparkNote.depletion;

  /// 오른쪽 글자(`순변화 +1 · 이전 스캔과 이상 없음` 등).
  String get summary {
    if (note == InventorySparkNote.single) return '비교할 이전 스캔이 없습니다';
    final net = netChange;
    final head = '순변화 ${net == null ? '—' : inventorySignedCount(net)}';
    return switch (note) {
      InventorySparkNote.depletion => '$head · $noteValue주 뒤 소진 예상',
      InventorySparkNote.unchanged => '$head · 이전 스캔과 이상 없음',
      InventorySparkNote.changed =>
        '$head · 이전 스캔 대비 ${inventorySignedCount(noteValue ?? 0)}',
      InventorySparkNote.none || InventorySparkNote.single => head,
    };
  }
}

/// [key] 재화의 상세 스파크라인(한 재화 안에서만, FD-033).
///
/// 점 = 읽는 기간 안에서 이 재화를 본 스캔 세션의 끝 수량(오래된 것부터). 지금 수량이 마지막 스캔 점과 다르면(그 뒤 수동
/// 수정 등) 끝에 `지금` 점을 하나 더한다(FD-041: 수동 수정도 변화 그래프에 남는다).
InventorySparkline inventorySparkline(InventoryHistory history, String key) {
  final track = history.track(key);
  final current = history.current(key);
  if (track.isEmpty) {
    return const InventorySparkline(
      points: [],
      scanCount: 0,
      netChange: null,
      note: InventorySparkNote.none,
    );
  }
  final raw = <InventorySparkPoint>[
    for (final point in track)
      InventorySparkPoint(
        label: inventoryWeeksAgoLabel(point.at, history.now),
        value: point.value.known,
      ),
    if (current != track.last.value)
      InventorySparkPoint(label: '지금', value: current.known, scan: false),
  ];
  // 같은 라벨이 이어지면 마지막 점에만 둔다.
  final points = [
    for (var index = 0; index < raw.length; index++)
      InventorySparkPoint(
        label:
            index + 1 < raw.length && raw[index + 1].label == raw[index].label
            ? ''
            : raw[index].label,
        value: raw[index].value,
        scan: raw[index].scan,
      ),
  ];
  if (points.length == 1) {
    return InventorySparkline(
      points: points,
      scanCount: track.length,
      netChange: null,
      note: InventorySparkNote.single,
    );
  }
  final first = points.first.value, last = points.last.value;
  final net = history.timestampsMonotonic && first != null && last != null
      ? last - first
      : null;
  final owned = current.known;
  final trend = history.timestampsMonotonic
      ? inventoryTrend(track, history.now)
      : null;
  if (trend != null && trend.slopePerDay < 0 && owned != null && owned > 0) {
    final days = owned / -trend.slopePerDay;
    if (days <= inventoryForecastHorizon.inDays) {
      return InventorySparkline(
        points: points,
        scanCount: track.length,
        netChange: net,
        note: InventorySparkNote.depletion,
        noteValue: _weeksCeil(days),
      );
    }
  }
  final previous = points[points.length - 2].value;
  if (previous == null || last == null) {
    return InventorySparkline(
      points: points,
      scanCount: track.length,
      netChange: net,
      note: InventorySparkNote.none,
    );
  }
  return InventorySparkline(
    points: points,
    scanCount: track.length,
    netChange: net,
    note: previous == last
        ? InventorySparkNote.unchanged
        : InventorySparkNote.changed,
    noteValue: last - previous,
  );
}

// --- S5 기간 순증감 ---------------------------------------------------------------

/// 재화 하나의 기간 순증감.
@immutable
class InventoryNetChange {
  const InventoryNetChange({required this.view, required this.delta});

  final InventoryItemView view;
  final int delta;
}

/// S5 순증감 상위.
@immutable
class InventoryNetChanges {
  const InventoryNetChanges({required this.known, required this.rows});

  /// 기간 시작 수량을 아는가(모르면 [rows]는 비어 있다).
  final bool known;

  /// 순증감 큰 순(증가 → 감소).
  final List<InventoryNetChange> rows;

  /// 막대 길이 기준(행 중 |순증감| 최댓값, 행이 없으면 0).
  int get maxMagnitude =>
      rows.fold(0, (value, row) => math.max(value, row.delta.abs()));
}

/// [window] 기간 순증감 = 지금 수량 − 기간 시작 직전 수량(모든 출처의 적용 포함). 둘 다 아는 품목(재화 제외)만, 0은 뺀다.
///
/// |순증감|이 큰 [limit]개를 고르고(같으면 증가 먼저 → 카탈로그 순서), 순증감 큰 순(같으면 카탈로그 순서)으로 놓는다.
InventoryNetChanges inventoryNetChanges(
  InventoryHistory history,
  InventoryBoard board,
  InventoryChangeWindow window, {
  int limit = inventoryNetChangeRows,
}) {
  if (!history.timestampsMonotonic || !history.knows(window)) {
    return const InventoryNetChanges(known: false, rows: []);
  }
  final changes = <InventoryNetChange>[];
  for (final view in board.items) {
    if (view.isCurrency) continue;
    final start = history.startOf(view.key, window)?.known;
    final now = history.current(view.key).known;
    if (start == null || now == null || start == now) continue;
    changes.add(InventoryNetChange(view: view, delta: now - start));
  }
  changes.sort((a, b) {
    final magnitude = b.delta.abs().compareTo(a.delta.abs());
    if (magnitude != 0) return magnitude;
    final sign = b.delta.compareTo(a.delta);
    return sign != 0 ? sign : a.view.order.compareTo(b.view.order);
  });
  final rows = changes.take(limit).toList()
    ..sort((a, b) {
      final delta = b.delta.compareTo(a.delta);
      return delta != 0 ? delta : a.view.order.compareTo(b.view.order);
    });
  return InventoryNetChanges(known: true, rows: List.unmodifiable(rows));
}

// --- S5 "이 추세라면" -------------------------------------------------------------

/// 예측 행 종류.
enum InventoryForecastKind {
  /// 지금 모자라고 줄어드는 중(`… 부족이 커지는 중`, 칩 위험 `4주 뒤 −n`).
  worsening,

  /// 지금 모자라지만 늘어 4주 안에 필요량에 닿는다(`…은/는 곧 충분`, 칩 충분 `n주 뒤 0`).
  recovering,
}

/// "이 추세라면" 행 하나(FD-042, 활성 계획 필요량 기준).
@immutable
class InventoryForecast {
  const InventoryForecast({
    required this.view,
    required this.kind,
    required this.weeks,
    required this.shortage,
    required this.days,
  });

  final InventoryItemView view;
  final InventoryForecastKind kind;

  /// 칩의 주 수.
  final int weeks;

  /// [weeks]주 뒤 예상 부족량(0 이상).
  final int shortage;

  /// 정렬용: 필요량에 닿는 날 수(recovering) 또는 앞날 길이(worsening).
  final double days;

  /// 행 글자.
  String get text {
    final name = view.item.displayName;
    return kind == InventoryForecastKind.worsening
        ? '$name 부족이 커지는 중'
        : '$name${inventoryTopicParticle(name)} 곧 충분';
  }

  /// 칩 글자(`4주 뒤 −66` · `2주 뒤 0`).
  String get chip => '$weeks주 뒤 ${shortage == 0 ? '0' : '$_minus$shortage'}';
}

/// "이 추세라면" 행(FD-042). 활성 계획이 쓰는(필요 > 0) 품목(재화 제외) 중 지금 보유를 알고 모자라며, 그 재화 스캔 점이
/// 3개 이상인 것만 본다. 지금 보유에서 추세 기울기로:
/// - 줄어들면 4주 뒤 예상 부족(보유는 0 아래로 내려가지 않는다) → worsening(예상 부족 큰 순).
/// - 늘어나 4주 안에 필요량에 닿으면 그 주 수(올림) → recovering(빠른 순).
/// 둘 다 있으면 각 1위를, 한쪽만 있으면 그쪽 위에서 [limit]개를 보인다. 같으면 카탈로그 순서다.
List<InventoryForecast> inventoryForecasts(
  InventoryHistory history,
  InventoryBoard board, {
  int limit = inventoryForecastRows,
}) {
  if (!history.timestampsMonotonic || !board.hasShortages) return const [];
  final horizon = inventoryForecastHorizon.inDays.toDouble();
  final worsening = <InventoryForecast>[];
  final recovering = <InventoryForecast>[];
  for (final view in board.items) {
    if (view.isCurrency) continue;
    final required = view.requiredAmount;
    final owned = history.current(view.key).known;
    if (required == null || owned == null || owned >= required) continue;
    final trend = inventoryTrend(history.track(view.key), history.now);
    if (trend == null || trend.slopePerDay == 0) continue;
    if (trend.slopePerDay < 0) {
      final projected = math.max(0.0, owned + trend.slopePerDay * horizon);
      worsening.add(
        InventoryForecast(
          view: view,
          kind: InventoryForecastKind.worsening,
          weeks: _weeksCeil(horizon),
          shortage: (required - projected).round(),
          days: horizon,
        ),
      );
    } else {
      final days = (required - owned) / trend.slopePerDay;
      if (days > horizon) continue;
      recovering.add(
        InventoryForecast(
          view: view,
          kind: InventoryForecastKind.recovering,
          weeks: _weeksCeil(days),
          shortage: 0,
          days: days,
        ),
      );
    }
  }
  worsening.sort((a, b) {
    final shortage = b.shortage.compareTo(a.shortage);
    return shortage != 0 ? shortage : a.view.order.compareTo(b.view.order);
  });
  recovering.sort((a, b) {
    final days = a.days.compareTo(b.days);
    return days != 0 ? days : a.view.order.compareTo(b.view.order);
  });
  if (worsening.isNotEmpty && recovering.isNotEmpty && limit >= 2) {
    return [worsening.first, recovering.first];
  }
  return [...worsening, ...recovering].take(limit).toList();
}
