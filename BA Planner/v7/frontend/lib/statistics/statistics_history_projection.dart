// 통계 이력 projection(FE7-h, FD-041 · FD-042 · FD-106 · FD-110 · FD-175, F 보고서 §1.6 확정 4 · §2.2 기준 데이터 · §5 A6 · B3 ·
// K 증감). 위젯과 서비스 호출이 없는 순수 계산이다. 입력은 `_reload()`가 읽은 지금 계정 상태 · 학생 목록 · 인벤토리 목록과 FB-2
// 이력(`repository.history.events` 전체 쪽 · `scan_latest`)뿐이다.
//
// - 스냅샷 = 가까운 scan 세션 묶음(FD-175, 사용자 결정 2026-10-14): 학생 · 인벤토리 모든 profile의 scan 세션(같은 세션의 여러
//   commit은 그 세션 끝 1점)을 시각순으로 놓고, 앞 세션 끝에서 [statisticsSnapshotGap] 안에 시작한 세션을 같은 스냅샷으로
//   묶는다([statisticsSnapshotGroups]). 기준 데이터 "스냅샷 n회 · 기간"은 남아 있는(보존) 이력의 모든 묶음이다. scan 종류
//   원문(`scan_kind`)에는 기대지 않는다. 학생 스냅샷은 승인 scope에 학생이 든 세션이 있는 묶음, 재화 점은 scope에 그 재화가 든
//   세션이 있는 묶음이고(FE6-f 규칙 2를 묶음에 적용), 값은 묶음 끝 상태다.
// - 시점별 학생 상태: 지금 확정 학생에서 이력의 `student_changes`(before)를 거꾸로 되돌려 학생 스냅샷마다 그 묶음 끝 상태를
//   얻는다(FE6-f가 인벤토리 수량을 되돌리는 것과 같은 방식). 그 상태로 FE7-b 성장 projection(FD-028)을 그대로 다시 센다.
//   통계 필터(FE7-e)가 걸리면 대상 학생만 다시 센다([StatisticsHistory.studentSnapshotsFor]).
// - "지난 스냅샷 대비"(FD-041): 수동 수정도 지금 값에 들어가고, 비교 기준은 scan 점이다.
//   - 학생(성장 KPI): 마지막 학생 스냅샷 바로 앞 학생 스냅샷의 학생 상태. 학생 스냅샷이 2개 미만이면 '—'.
//   - 재화(인벤토리 · 계획 KPI): 재화마다 마지막 바로 앞 스냅샷(묶음) 점(지금 − 28일 안), [inventoryKpiDeltas]를 쓴다. FE6-f
//     인벤토리 탭의 재화별 "지난 스캔"(세션 단위)과는 한 묶음 안에서 같은 재화를 두 번 스캔했을 때만 다르다.
//     충족률 · 충족 카테고리는 그 점 수량으로 바꾼 보드를 같은 식(FD-031 · 032)으로 다시 센다. 비교 못 하는 재화는 지금 값
//     그대로다(FE6-f "변화 없음"과 같은 수). 필요량은 지금 계획이다(이력은 지난 계획을 남기지 않는다).
//   - 목표(계획 등록 · 미계획 학생)와 문서 계산(막힌 학생)은 이력에 없어 '—'다.
// - B3(FD-110): seg "스냅샷 6회" = 재화마다 최근 6점, "4주" = 지금 − 28일 안, "전체" = 남은 이력 전부. 패널은 재화(크레딧 ·
//   엘리그마) 다음에 계획이 쓰는 재화 중 |순변화| / 필요량이 큰 것으로 3개까지다(단위가 달라 수량끼리 비교하지 않는다, FD-033).
// - A6 고른 구간(FE7-j, Statistics-Proposal A6 "오른 학생 순위"): 두 학생 스냅샷의 확정 학생으로 학생별 육성도 증감을 센다
//   ([statisticsGrowthRanking]). 시작 때 보유하지 않던 학생은 "새 학생"이다.
// - 시계가 되돌려진 기록(`timestamps_monotonic = false`)이 있으면 증감 · 추이를 내지 않는다(FE6-f와 같다).
// - 모르는 값은 0이 아니라 null('—')이다.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../services/app_service.dart';
import '../services/repository_service.dart';
import '../ui/inventory/inventory_analysis.dart' show inventoryCoverageOf;
import '../ui/inventory/inventory_history.dart';
import '../ui/inventory/inventory_view_model.dart';
import 'statistics_growth_projection.dart';
import 'statistics_supply_projection.dart';

/// 스냅샷 묶음 간격(FD-175, 사용자 결정 2026-10-14: 앞 세션 끝에서 2시간 안. 바꾸려면 FD-175를 갱신한다).
const statisticsSnapshotGap = Duration(hours: 2);

/// A6 점 수 · B3 "스냅샷 6회"(FD-110 권장안: 최근 6회).
const statisticsHistoryRecentSnapshots = 6;

/// A6 강조 구간: 마지막 스냅샷에서 이 기간 안의 첫 스냅샷부터(시안 9/22 → 10/05).
const statisticsGrowthTrendHighlight = Duration(days: 14);

/// B3 패널 수(시안 3개).
const statisticsB3PanelCount = 3;

/// 스냅샷 2회 미만 문구(Statistics-Proposal 확정 4 · FD-106).
const statisticsHistoryMoreScansText = '스캔을 더 실행하면 변화가 나타납니다.';

/// 이력을 읽는 사이에 상태가 바뀜(FE6-f와 같은 문구).
const statisticsHistoryMismatchText =
    '수량이 바뀌는 사이에 읽어 이력을 맞추지 못했습니다. 탭을 다시 열면 다시 읽습니다.';

/// B3 seg(FD-110).
enum StatisticsB3Range {
  /// 재화마다 최근 6점.
  recent,

  /// 지금 − 28일 안.
  weeks4,

  /// 남은 이력 전부.
  all,
}

/// 학생 스냅샷 하나(그 세션 끝 학생 상태로 다시 센 성장 값).
@immutable
class StatisticsStudentSnapshot {
  const StatisticsStudentSnapshot({
    required this.at,
    required this.sessionId,
    required this.ownedCount,
    required this.averageGrowth,
    required this.maxLevelCount,
    required this.fullGrowthCount,
    this.states = const {},
  });

  final DateTime at;

  /// 묶음의 마지막 세션 id(FD-175).
  final String sessionId;
  final int ownedCount;

  /// FD-028 평균 육성도(0~1). 아는 학생이 없으면 null.
  final double? averageGrowth;
  final int? maxLevelCount;
  final int? fullGrowthCount;

  /// 묶음 끝 확정 학생(id → 상태). 통계 필터 대상만 다시 셀 때 쓴다(FE7-e).
  final Map<String, ConfirmedStudentState> states;

  /// 성장 projection 값으로 만든다.
  factory StatisticsStudentSnapshot.of(
    StatisticsGrowth growth, {
    required DateTime at,
    required String sessionId,
    Map<String, ConfirmedStudentState> states = const {},
  }) => StatisticsStudentSnapshot(
    at: at,
    sessionId: sessionId,
    ownedCount: growth.ownedCount,
    averageGrowth: growth.averageGrowth,
    maxLevelCount: growth.maxLevelCount,
    fullGrowthCount: growth.fullGrowthCount,
    states: states,
  );
}

/// 스냅샷 묶음 하나(FD-175): 가까운 scan 세션들.
@immutable
class StatisticsSnapshotGroup {
  const StatisticsSnapshotGroup({
    required this.sessionIds,
    required this.endSequence,
    required this.endAt,
  });

  /// 묶인 세션(시각순).
  final List<String> sessionIds;

  /// 마지막 세션 끝 점의 이력 순번.
  final int endSequence;

  /// 마지막 세션 끝 시각(스냅샷 시각).
  final DateTime endAt;

  /// 묶음 이름(마지막 세션 id). 재화 색인의 점 세션 자리에 쓴다.
  String get key => sessionIds.last;
}

/// scan 세션 끝 점([points])을 스냅샷으로 묶는다(FD-175). 순번(= 기록 순서)대로 놓고, 세션 시작([starts], 그 세션 첫
/// commit 시각, 모르면 끝 시각)이 바로 앞 세션 끝에서 [gap] 안이면 앞 묶음에 넣는다. 오래된 묶음부터.
List<StatisticsSnapshotGroup> statisticsSnapshotGroups(
  Iterable<InventoryScanPoint> points, {
  Map<String, DateTime> starts = const {},
  Duration gap = statisticsSnapshotGap,
}) {
  final ordered = [...points]..sort((a, b) => a.sequence.compareTo(b.sequence));
  final groups = <StatisticsSnapshotGroup>[];
  var sessions = <String>[];
  InventoryScanPoint? previous;
  void close() {
    final last = previous;
    if (last == null) return;
    groups.add(
      StatisticsSnapshotGroup(
        sessionIds: List.unmodifiable(sessions),
        endSequence: last.sequence,
        endAt: last.recordedAt,
      ),
    );
  }

  for (final point in ordered) {
    final last = previous;
    final start = starts[point.sessionId] ?? point.recordedAt;
    if (last != null && start.difference(last.recordedAt) > gap) {
      close();
      sessions = <String>[];
    }
    sessions.add(point.sessionId);
    previous = point;
  }
  close();
  return groups;
}

/// 이력 집계 입력.
@immutable
class StatisticsHistoryInput {
  const StatisticsHistoryInput({
    required this.now,
    required this.state,
    required this.pages,
    this.students,
    this.lastStudentScanAt,
    this.lastInventoryScanAt,
  });

  final DateTime now;

  /// 지금 계정 상태(학생 · 인벤토리 bucket).
  final RepositoryState state;

  /// events 전체 쪽(같은 anchor, from_at 없이 남은 이력 전부).
  final List<RepositoryHistoryEventsResult> pages;

  /// 학생 목록(애장품 여부). 없으면 애장품이 모름이다(성장 projection과 같다).
  final List<StudentCatalogEntry>? students;

  /// `scan_latest` by_student_id 최댓값(학생 스캔 시각).
  final DateTime? lastStudentScanAt;

  /// `scan_latest` by_resource_key 최댓값(인벤토리 스캔 시각, FE6-f).
  final DateTime? lastInventoryScanAt;
}

/// 통계 이력 색인.
class StatisticsHistory {
  StatisticsHistory._({
    required this.now,
    required this.timestampsMonotonic,
    required this.snapshotTimes,
    required this.studentSnapshots,
    required this.inventorySnapshotTimes,
    required this._growthOf,
    required this.inventory,
    required this.inventoryWindow,
    required this.lastStudentScanAt,
    required this.lastInventoryScanAt,
  });

  /// 읽은 이력으로 만든다.
  factory StatisticsHistory.build(StatisticsHistoryInput input) {
    final first = input.pages.isEmpty ? null : input.pages.first;
    final events = [for (final page in input.pages) ...page.events]
      ..sort((a, b) => b.sequence.compareTo(a.sequence));
    final points = [
      for (final point in first?.scanPoints ?? const <HistoryScanPoint>[])
        InventoryScanPoint.fromPoint(point),
    ]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final studentSessions = <String>{};
    final inventorySessions = <String>{};
    final starts = <String, DateTime>{};
    for (final event in events) {
      final session = event.scanSessionId;
      if (event.source != 'scan' || session == null) continue;
      if (event.appliedStudentIds.isNotEmpty) studentSessions.add(session);
      if (event.appliedResourceKeys.isNotEmpty) inventorySessions.add(session);
      final at = DateTime.parse(event.recordedAt);
      final start = starts[session];
      if (start == null || at.isBefore(start)) starts[session] = at;
    }
    // FD-175: 가까운 세션을 한 스냅샷으로 묶는다. 학생 · 재화 점은 묶음 끝에 하나다.
    final groups = statisticsSnapshotGroups(points, starts: starts);
    final groupByEnd = {for (final group in groups) group.endSequence: group};
    final groupBySession = {
      for (final group in groups)
        for (final session in group.sessionIds) session: group,
    };
    final catalog = {
      for (final entry in input.students ?? const <StudentCatalogEntry>[])
        entry.studentId: entry,
    };
    final planned = {for (final goal in input.state.goals) goal.studentId};
    StatisticsGrowth growthOf(Map<String, ConfirmedStudentState> students) =>
        StatisticsGrowth(
          catalogCount: input.students == null ? null : catalog.length,
          students: [
            for (final student in students.values)
              statisticsStudentGrowth(
                student,
                catalog: catalog[student.studentId],
                planned: planned.contains(student.studentId),
              ),
          ],
        );
    // 지금 학생에서 거꾸로 되돌린다(늦은 적용부터). 학생 세션이 든 묶음의 끝에서 그때 상태를 센다.
    final students = {
      for (final student in input.state.students) student.studentId: student,
    };
    final snapshots = <StatisticsStudentSnapshot>[];
    for (final event in events) {
      final group = groupByEnd[event.sequence];
      if (group != null && group.sessionIds.any(studentSessions.contains)) {
        snapshots.add(
          StatisticsStudentSnapshot.of(
            growthOf(students),
            at: group.endAt,
            sessionId: group.key,
            states: Map.unmodifiable(students),
          ),
        );
      }
      for (final change in event.studentChanges) {
        final before = change.before;
        final value = before.value;
        if (before.present && value != null) {
          students[change.studentId] = value;
        } else {
          students.remove(change.studentId);
        }
      }
    }
    final coverage = first == null
        ? InventoryHistoryCoverage.unrecorded
        : InventoryHistoryCoverage.fromQuery(first.coverage);
    // 재화 색인(FE6-f 함수)에는 묶음을 세션 하나로 넘긴다: scan 적용의 세션 자리를 묶음 이름으로 바꾸고, 점은 묶음 끝 하나다.
    // 그러면 재화 점 = 그 재화가 scope에 든 세션이 있는 묶음, 값 = 묶음 끝 수량이다.
    final allEvents = [
      for (final event in events)
        _grouped(InventoryHistoryEvent.fromEvent(event), groupBySession),
    ];
    final groupPoints = [
      for (final group in groups)
        InventoryScanPoint(
          sessionId: group.key,
          sequence: group.endSequence,
          recordedAt: group.endAt,
        ),
    ];
    final current = inventoryHistoryCurrent(input.state.inventory);
    final boundary = input.now.subtract(inventoryHistoryWindow);
    bool inWindow(DateTime at) => !at.isBefore(boundary);
    return StatisticsHistory._(
      now: input.now,
      timestampsMonotonic: coverage.timestampsMonotonic,
      snapshotTimes: [for (final group in groups) group.endAt],
      studentSnapshots: List.unmodifiable(snapshots.reversed),
      inventorySnapshotTimes: [
        for (final group in groups)
          if (group.sessionIds.any(inventorySessions.contains)) group.endAt,
      ],
      growthOf: growthOf,
      inventory: InventoryHistory.build(
        InventoryHistoryInput(
          now: input.now,
          current: current,
          events: allEvents,
          scanPoints: groupPoints,
          coverage: coverage,
          lastScanAt: input.lastInventoryScanAt,
        ),
      ),
      // FE6-f 인벤토리 탭과 같은 4주 색인(KPI "지난 스캔"이 두 탭에서 같다).
      inventoryWindow: InventoryHistory.build(
        InventoryHistoryInput(
          now: input.now,
          current: current,
          events: [
            for (final event in allEvents)
              if (inWindow(event.recordedAt)) event,
          ],
          scanPoints: [
            for (final point in groupPoints)
              if (inWindow(point.recordedAt)) point,
          ],
          coverage: coverage,
          lastScanAt: input.lastInventoryScanAt,
        ),
      ),
      lastStudentScanAt: input.lastStudentScanAt,
      lastInventoryScanAt: input.lastInventoryScanAt,
    );
  }

  final DateTime now;

  /// 시계가 되돌려진 기록이 없다(증감 · 추이를 낼 수 있다).
  final bool timestampsMonotonic;

  /// 남은 이력의 모든 스냅샷(FD-175 묶음 끝) 시각, 오래된 것부터.
  final List<DateTime> snapshotTimes;

  /// 학생 스냅샷(학생을 적용한 세션이 든 묶음), 오래된 것부터.
  final List<StatisticsStudentSnapshot> studentSnapshots;

  /// 재화를 적용한 세션이 든 묶음 끝 시각, 오래된 것부터.
  final List<DateTime> inventorySnapshotTimes;

  final StatisticsGrowth Function(Map<String, ConfirmedStudentState>)
  _growthOf;
  Set<String>? _targets;
  List<StatisticsStudentSnapshot>? _targetSnapshots;

  /// 통계 필터 대상([targets], 학생 id)만 다시 센 학생 스냅샷(FE7-e). 대상은 지금 정한 학생 집합이고, 스냅샷마다 그때 보유한
  /// 대상만 센다. null이면 [studentSnapshots]다. 같은 집합(동일 객체)이면 다시 세지 않는다.
  List<StatisticsStudentSnapshot> studentSnapshotsFor(Set<String>? targets) {
    if (targets == null) return studentSnapshots;
    final cached = _targetSnapshots;
    if (cached != null && identical(_targets, targets)) return cached;
    _targets = targets;
    StatisticsStudentSnapshot scoped(StatisticsStudentSnapshot snapshot) {
      final states = Map<String, ConfirmedStudentState>.unmodifiable({
        for (final entry in snapshot.states.entries)
          if (targets.contains(entry.key)) entry.key: entry.value,
      });
      return StatisticsStudentSnapshot.of(
        _growthOf(states),
        at: snapshot.at,
        sessionId: snapshot.sessionId,
        states: states,
      );
    }

    return _targetSnapshots = List.unmodifiable([
      for (final snapshot in studentSnapshots) scoped(snapshot),
    ]);
  }

  /// [states](어느 스냅샷의 확정 학생)로 다시 센 성장(FE7-b 식, 학생 목록 · 계획 등록은 지금 것). A6 오른 학생 순위(FE7-j)가 쓴다.
  StatisticsGrowth growthAt(Map<String, ConfirmedStudentState> states) =>
      _growthOf(states);

  Object? _rankingKey;
  StatisticsGrowthRanking? _ranking;

  /// 남은 이력 전부로 만든 재화 색인(B3).
  final InventoryHistory inventory;

  /// 지금 − 28일 색인(FE6-f KPI와 같은 "지난 스캔").
  final InventoryHistory inventoryWindow;
  final DateTime? lastStudentScanAt;
  final DateTime? lastInventoryScanAt;
}

/// scan 적용의 세션 자리를 그 세션의 묶음 이름으로 바꾼다(FD-175). 묶음이 없는 세션(끝 점이 없음)은 그대로다.
InventoryHistoryEvent _grouped(
  InventoryHistoryEvent event,
  Map<String, StatisticsSnapshotGroup> groups,
) {
  final group = groups[event.sessionId];
  if (group == null || group.key == event.sessionId) return event;
  return InventoryHistoryEvent(
    sequence: event.sequence,
    recordedAt: event.recordedAt,
    source: event.source,
    sessionId: group.key,
    resourceKeys: event.resourceKeys,
    changes: event.changes,
  );
}

/// scan_latest 결과들에서 학생을 적용한 가장 최근 scan 시각. 없으면 null.
DateTime? statisticsLastStudentScanAt(
  Iterable<RepositoryHistoryScanLatestResult> results,
) {
  DateTime? latest;
  for (final result in results) {
    for (final row in result.byStudentId) {
      final scan = row.latestScan;
      if (scan == null) continue;
      final at = DateTime.parse(scan.recordedAt);
      if (latest == null || at.isAfter(latest)) latest = at;
    }
  }
  return latest;
}

// --- 표시 도우미 ----------------------------------------------------------------

String _two(int value) => value.toString().padLeft(2, '0');

/// 날짜 글자 `M/dd`(지역 시각, 시안 "9/02" · "10/05").
String statisticsDateText(DateTime at) {
  final local = at.toLocal();
  return '${local.month}/${_two(local.day)}';
}

/// 날짜 · 시각 글자 `M/dd HH:mm`(시안 "9/22 21:40").
String statisticsDateTimeText(DateTime at) {
  final local = at.toLocal();
  return '${statisticsDateText(local)} ${_two(local.hour)}:${_two(local.minute)}';
}

/// 기준 데이터 "스냅샷" 값: `6회 · 9/02 ~ 10/05`, 1회 `1회 · 9/22`, 없으면 '—'.
String statisticsSnapshotRangeText(List<DateTime> times) {
  if (times.isEmpty) return '—';
  final first = statisticsDateText(times.first);
  if (times.length == 1) return '1회 · $first';
  return '${times.length}회 · $first ~ ${statisticsDateText(times.last)}';
}

/// 스냅샷 2회 미만 안내 둘째 줄: `스냅샷 1회 · 9/22 21:40`, 없으면 `스냅샷 0회`.
String statisticsSnapshotNoteText(int count, DateTime? last) => last == null
    ? '스냅샷 $count회'
    : '스냅샷 $count회 · ${statisticsDateTimeText(last)}';

/// 부호 있는 소수 한 자리(`+1.2` · `−0.4` · `0.0`, 빼기는 U+2212).
String statisticsSignedTenths(int tenths) {
  final text = '${tenths.abs() ~/ 10}.${tenths.abs() % 10}';
  return tenths > 0
      ? '+$text'
      : tenths < 0
      ? '−$text'
      : text;
}

/// 부호 있는 수량(백만 이상은 `−43.6M`, FE7-c 수량 글자와 같은 단위).
String statisticsSignedAmount(int value) {
  final text = statisticsAmountText(value.abs());
  return value > 0
      ? '+$text'
      : value < 0
      ? '−$text'
      : '0';
}

/// 비율(0~1)을 화면 글자 반올림 단위(1/10^decimals %)의 정수로.
int _percentUnits(double fraction, int decimals) =>
    (fraction * 100 * math.pow(10, decimals)).round();

// --- KPI 증감 -------------------------------------------------------------------

/// 성장 KPI 증감(지난 학생 스냅샷 대비). 모르면 null.
@immutable
class StatisticsGrowthDeltas {
  const StatisticsGrowthDeltas({
    this.owned,
    this.averageTenths,
    this.maxLevel,
    this.fullGrowth,
  });

  static const unknown = StatisticsGrowthDeltas();

  final int? owned;

  /// 평균 육성도 증감(%p의 1/10, 화면 글자 한 자리끼리의 차).
  final int? averageTenths;
  final int? maxLevel;
  final int? fullGrowth;
}

/// 지금 성장([growth], 수동 수정 포함)과 마지막 바로 앞 학생 스냅샷을 비교한다. 학생 스냅샷 2개 미만 · 시계 되돌림이면 모름.
/// 통계 필터(FE7-e)가 걸리면 [growth]는 대상 학생만의 성장이고 [targets]는 그 학생 id다(스냅샷도 대상만 센다).
StatisticsGrowthDeltas statisticsGrowthDeltas(
  StatisticsHistory? history,
  StatisticsGrowth? growth, {
  Set<String>? targets,
}) {
  if (history == null || growth == null || !history.timestampsMonotonic) {
    return StatisticsGrowthDeltas.unknown;
  }
  final snapshots = history.studentSnapshotsFor(targets);
  if (snapshots.length < 2) return StatisticsGrowthDeltas.unknown;
  final base = snapshots[snapshots.length - 2];
  int? diff(int? now, int? then) =>
      now == null || then == null ? null : now - then;
  final now = growth.averageGrowth, then = base.averageGrowth;
  return StatisticsGrowthDeltas(
    owned: growth.ownedCount - base.ownedCount,
    averageTenths: now == null || then == null
        ? null
        : _percentUnits(now, 1) - _percentUnits(then, 1),
    maxLevel: diff(growth.maxLevelCount, base.maxLevelCount),
    fullGrowth: diff(growth.fullGrowthCount, base.fullGrowthCount),
  );
}

/// 인벤토리 · 계획 KPI 증감(FE6-f "지난 스캔" 재화별). 모르면 null.
@immutable
class StatisticsSupplyDeltas {
  const StatisticsSupplyDeltas({
    this.fulfillment,
    this.shortageKinds,
    this.excessKinds,
    this.metCategories,
  });

  static const unknown = StatisticsSupplyDeltas();

  /// 전체(계획) 충족률 증감(%p, 화면 글자 정수끼리의 차).
  final int? fulfillment;
  final int? shortageKinds;
  final int? excessKinds;
  final int? metCategories;
}

/// [supply]와 같은 식으로 "지난 스캔" 보드를 다시 세어 비교한다.
///
/// 지난 스캔 수량 = 재화마다 지금 − 28일 안 마지막 바로 앞 스캔 점(FE6-f). 그 점 수량과 지금 보유를 둘 다 아는 재화만
/// 그 점 수량으로 바꾸고, 나머지는 지금 값 그대로다. 바꾼 재화가 없으면 충족률 · 충족 카테고리 증감은 모름이다. 부족 · 과잉
/// 종 수 증감은 [inventoryKpiDeltas] 그대로다(재화 제외, 인벤토리 탭 KPI와 같은 값).
StatisticsSupplyDeltas statisticsSupplyDeltas(
  StatisticsHistory? history,
  StatisticsSupply? supply, {
  required List<InventoryCatalogEntry>? catalog,
  required RepositoryState? state,
  required InventoryShortageResult? shortages,
}) {
  if (history == null ||
      supply == null ||
      state == null ||
      !history.timestampsMonotonic) {
    return StatisticsSupplyDeltas.unknown;
  }
  final window = history.inventoryWindow;
  final counts = inventoryKpiDeltas(window, supply.board);
  final past = <String, int>{};
  for (final view in supply.board.items) {
    final track = window.track(view.key);
    if (track.length < 2) continue;
    final base = track[track.length - 2].value.known;
    if (base == null || view.owned == null) continue;
    past[historyCanonicalResourceKey(view.key)] = base;
  }
  int? fulfillment;
  int? met;
  if (past.isNotEmpty) {
    var replaced = 0;
    final entries = <Map<String, dynamic>>[];
    for (final entry in state.inventory.entries) {
      final quantity =
          past[historyCanonicalResourceKey(inventoryEntryIdentity(entry))];
      if (quantity == null) {
        entries.add(entry);
      } else {
        replaced++;
        entries.add({...entry, 'quantity': '$quantity'});
      }
    }
    if (replaced > 0) {
      final board = InventoryBoard.build(
        catalog: catalog ?? const [],
        inventory: RepositoryInventoryState.fromEntries(entries),
        shortages: shortages,
      );
      final planned = [
        for (final view in board.items)
          if (view.planned) view,
      ];
      final now = supply.kpis.fulfillment;
      final then = inventoryCoverageOf(planned).fulfillment;
      fulfillment = now == null || then == null
          ? null
          : _percentUnits(now, 0) - _percentUnits(then, 0);
      met =
          supply.metCategoryCount -
          statisticsCategoryFills(planned).where((item) => item.met).length;
    }
  }
  return StatisticsSupplyDeltas(
    fulfillment: fulfillment,
    shortageKinds: counts.shortage,
    excessKinds: counts.excess,
    metCategories: met,
  );
}

// --- A6 성장 추이 -----------------------------------------------------------------

/// A6 값. [points]가 2개 미만이면 그래프 대신 확정 4 문구다.
@immutable
class StatisticsGrowthTrend {
  const StatisticsGrowthTrend({
    required this.points,
    required this.snapshotCount,
    this.lastAt,
    this.highlightStart,
  });

  /// 최근 학생 스냅샷([statisticsHistoryRecentSnapshots]개까지, 오래된 것부터).
  final List<StatisticsStudentSnapshot> points;

  /// 남은 이력의 학생 스냅샷 수.
  final int snapshotCount;

  /// 마지막 학생 스냅샷 시각.
  final DateTime? lastAt;

  /// 강조 구간 시작 점(끝은 마지막 점). 없으면 null.
  final int? highlightStart;

  bool get drawable => points.length >= 2;

  /// 안내 둘째 줄(`스냅샷 1회 · 9/22 21:40`).
  String get note => statisticsSnapshotNoteText(snapshotCount, lastAt);

  /// [sessionId] 스냅샷의 점 순번. 없으면 null.
  int? indexOf(String sessionId) {
    final index = points.indexWhere((point) => point.sessionId == sessionId);
    return index < 0 ? null : index;
  }

  /// 강조 구간 시작만 [start]로 바꾼 값(A6 고른 구간, FE7-j).
  StatisticsGrowthTrend withHighlight(int start) => StatisticsGrowthTrend(
    points: points,
    snapshotCount: snapshotCount,
    lastAt: lastAt,
    highlightStart: start,
  );

  /// 강조 구간 글자(`9/22 → 10/05 +2.0%p`). 끝 값을 모르면 null.
  String? get highlightText {
    final start = highlightStart;
    if (start == null) return null;
    final from = points[start], to = points.last;
    final a = from.averageGrowth, b = to.averageGrowth;
    if (a == null || b == null) return null;
    final tenths = _percentUnits(b, 1) - _percentUnits(a, 1);
    return '${statisticsDateText(from.at)} → ${statisticsDateText(to.at)} '
        '${statisticsSignedTenths(tenths)}%p';
  }
}

/// A6: 최근 학생 스냅샷의 평균 육성도. 시계 되돌림이면 null(그리지 않는다).
///
/// 강조 구간은 마지막 스냅샷에서 [statisticsGrowthTrendHighlight] 안의 첫 스냅샷부터 마지막까지다. 그 안에 마지막 하나뿐이면
/// 바로 앞 스냅샷부터다. 통계 필터(FE7-e)가 걸리면 [targets] 학생만 센다.
StatisticsGrowthTrend? statisticsGrowthTrend(
  StatisticsHistory? history, {
  Set<String>? targets,
}) {
  if (history == null || !history.timestampsMonotonic) return null;
  final all = history.studentSnapshotsFor(targets);
  final points = all.length > statisticsHistoryRecentSnapshots
      ? all.sublist(all.length - statisticsHistoryRecentSnapshots)
      : all;
  int? start;
  if (points.length >= 2) {
    final from = points.last.at.subtract(statisticsGrowthTrendHighlight);
    start = points.indexWhere((point) => !point.at.isBefore(from));
    if (start < 0 || start >= points.length - 1) start = points.length - 2;
  }
  return StatisticsGrowthTrend(
    points: List.unmodifiable(points),
    snapshotCount: all.length,
    lastAt: all.isEmpty ? null : all.last.at,
    highlightStart: start,
  );
}

// --- A6 오른 학생 순위(FE7-j) ----------------------------------------------------------

/// A6 고른 구간의 학생 한 명(끝 스냅샷 상태).
@immutable
class StatisticsGrowthRise {
  const StatisticsGrowthRise({required this.student, this.tenths});

  final StatisticsStudentGrowth student;

  /// 두 스냅샷 사이 육성도 증감(0.1%p 단위, 화면 글자 반올림끼리의 차). 새 학생이면 null.
  final int? tenths;

  /// 시작 스냅샷 때 보유하지 않던 학생.
  bool get isNew => tenths == null;
}

/// A6 고른 구간(두 학생 스냅샷 사이)의 학생별 육성도 증감(Statistics-Proposal A6 "오른 학생 순위").
@immutable
class StatisticsGrowthRanking {
  StatisticsGrowthRanking({
    required this.from,
    required this.to,
    required List<StatisticsGrowthRise> rows,
    required this.risenCount,
    required this.newCount,
    required this.unknownCount,
  }) : rows = List.unmodifiable(rows);

  final StatisticsStudentSnapshot from;
  final StatisticsStudentSnapshot to;

  /// 오른 학생(증감 큰 순) 다음에 새 학생(끝 육성도 높은 순, 모르면 뒤).
  final List<StatisticsGrowthRise> rows;
  final int risenCount;
  final int newCount;

  /// 두 스냅샷에 다 있지만 한쪽이라도 육성도를 몰라 비교하지 못한 학생 수.
  final int unknownCount;

  /// 머리 글자(`9/22 → 10/05`).
  String get title =>
      '${statisticsDateText(from.at)} → ${statisticsDateText(to.at)}';

  /// 평균 육성도 증감(`+2.0%p`, A6 강조 글자와 같은 값). 모르면 '—'.
  String get averageText {
    final a = from.averageGrowth, b = to.averageGrowth;
    if (a == null || b == null) return '—';
    return '${statisticsSignedTenths(_percentUnits(b, 1) - _percentUnits(a, 1))}%p';
  }
}

/// A6에서 고른 구간([fromSession] → [toSession], [trend]의 점)의 학생별 육성도 증감. 두 끝은 그 스냅샷(FD-175 묶음 끝)의
/// 확정 학생이고, [trend]가 통계 필터 대상만 센 것이면(FE7-e) 대상 학생만이다. 끝 스냅샷에 있는 학생만 본다:
/// - 시작 스냅샷에 없던 학생은 "새 학생"이다(증감 없음).
/// - 두 스냅샷의 육성도(FD-028)를 다 알면 화면 글자(0.1%p) 반올림끼리의 차가 0보다 큰 학생이 "오른 학생"이다.
/// - 한쪽이라도 모르면 비교하지 않는다([StatisticsGrowthRanking.unknownCount]). 그대로이거나 내린 학생은 넣지 않는다.
/// 구간을 찾지 못하면(다시 읽어 점이 바뀜 등) null.
StatisticsGrowthRanking? statisticsGrowthRanking(
  StatisticsHistory? history,
  StatisticsGrowthTrend? trend, {
  required String fromSession,
  required String toSession,
}) {
  if (history == null || trend == null) return null;
  final start = trend.indexOf(fromSession), end = trend.indexOf(toSession);
  if (start == null || end == null || start >= end) return null;
  final from = trend.points[start], to = trend.points[end];
  final key = (from, to);
  final cached = history._ranking;
  if (cached != null && history._rankingKey == key) return cached;
  final before = {
    for (final student in history.growthAt(from.states).students)
      student.studentId: student,
  };
  final risen = <StatisticsGrowthRise>[];
  final added = <StatisticsGrowthRise>[];
  var unknown = 0;
  for (final student in history.growthAt(to.states).students) {
    final then = before[student.studentId];
    if (then == null) {
      added.add(StatisticsGrowthRise(student: student));
      continue;
    }
    final a = then.growth, b = student.growth;
    if (a == null || b == null) {
      unknown++;
      continue;
    }
    final tenths = _percentUnits(b, 1) - _percentUnits(a, 1);
    if (tenths > 0) {
      risen.add(StatisticsGrowthRise(student: student, tenths: tenths));
    }
  }
  int byName(StatisticsGrowthRise a, StatisticsGrowthRise b) {
    final name = a.student.displayName.compareTo(b.student.displayName);
    return name != 0
        ? name
        : a.student.studentId.compareTo(b.student.studentId);
  }

  int byGrowth(StatisticsGrowthRise a, StatisticsGrowthRise b) {
    final x = a.student.growth, y = b.student.growth;
    if (x == null || y == null) {
      return x == y ? byName(a, b) : (x == null ? 1 : -1);
    }
    final order = y.compareTo(x);
    return order != 0 ? order : byName(a, b);
  }

  risen.sort((a, b) {
    final order = b.tenths!.compareTo(a.tenths!);
    return order != 0 ? order : byGrowth(a, b);
  });
  added.sort(byGrowth);
  history._rankingKey = key;
  return history._ranking = StatisticsGrowthRanking(
    from: from,
    to: to,
    rows: [...risen, ...added],
    risenCount: risen.length,
    newCount: added.length,
    unknownCount: unknown,
  );
}

// --- B3 주요 재화 변화 -------------------------------------------------------------

/// B3 패널의 점 하나. [scan]이 false면 마지막 스캔 뒤 바뀐 지금 수량(수동 수정 등)이다.
@immutable
class StatisticsResourcePoint {
  const StatisticsResourcePoint({
    required this.at,
    required this.value,
    this.scan = true,
  });

  final DateTime at;

  /// 수량. 모르면 null.
  final int? value;
  final bool scan;

  @override
  bool operator ==(Object other) =>
      other is StatisticsResourcePoint &&
      other.at == at &&
      other.value == value &&
      other.scan == scan;

  @override
  int get hashCode => Object.hash(at, value, scan);
}

/// B3 패널 하나(재화 하나, 패널마다 축이 따로).
@immutable
class StatisticsResourceTrend {
  const StatisticsResourceTrend({
    required this.view,
    required this.points,
    required this.netChange,
  });

  final InventoryItemView view;

  /// 고른 seg 범위의 스캔 점(오래된 것부터) + 필요하면 끝의 지금 점.
  final List<StatisticsResourcePoint> points;

  /// 첫 점 → 끝 점 순변화. 모르면 null.
  final int? netChange;

  String get name => view.item.displayName;

  /// 활성 계획 필요량. 계획이 쓰지 않으면 null.
  int? get required => view.requiredAmount;

  /// 지금 보유(끝 점). 모르면 null.
  int? get current => points.isEmpty ? null : points.last.value;
}

/// B3 값. [panels]가 비면 그래프 대신 확정 4 문구다.
@immutable
class StatisticsResourceTrends {
  const StatisticsResourceTrends({
    required this.panels,
    required this.snapshotCount,
    this.lastAt,
  });

  final List<StatisticsResourceTrend> panels;

  /// 남은 이력에서 재화를 적용한 스냅샷 수.
  final int snapshotCount;
  final DateTime? lastAt;

  bool get drawable => panels.isNotEmpty;

  String get note => statisticsSnapshotNoteText(snapshotCount, lastAt);
}

/// [range] 안 [view] 재화의 점. 아는 수량 점이 2개 미만이면 null.
StatisticsResourceTrend? _resourceTrend(
  StatisticsHistory history,
  InventoryItemView view,
  StatisticsB3Range range,
) {
  final inventory = history.inventory;
  var track = inventory.track(view.key);
  switch (range) {
    case StatisticsB3Range.recent:
      if (track.length > statisticsHistoryRecentSnapshots) {
        track = track.sublist(track.length - statisticsHistoryRecentSnapshots);
      }
    case StatisticsB3Range.weeks4:
      final boundary = history.now.subtract(inventoryHistoryWindow);
      track = [
        for (final point in track)
          if (!point.at.isBefore(boundary)) point,
      ];
    case StatisticsB3Range.all:
      break;
  }
  if (track.isEmpty) return null;
  final current = inventory.current(view.key);
  final points = [
    for (final point in track)
      StatisticsResourcePoint(at: point.at, value: point.value.known),
    // FD-041: 마지막 스캔 뒤 바뀐 지금 수량(수동 수정)도 변화 그래프에 남는다(FE6-f 스파크라인과 같다).
    if (current != inventory.track(view.key).last.value)
      StatisticsResourcePoint(
        at: history.now,
        value: current.known,
        scan: false,
      ),
  ];
  final known = [
    for (final point in points)
      if (point.value != null) point.value!,
  ];
  if (known.length < 2) return null;
  final first = points.first.value, last = points.last.value;
  return StatisticsResourceTrend(
    view: view,
    points: List.unmodifiable(points),
    netChange: first == null || last == null ? null : last - first,
  );
}

/// B3 패널(FD-110 seg, FD-033). 재화(크레딧 · 엘리그마, 카탈로그 순서)를 먼저, 그다음 계획이 쓰는 재화를 |순변화| / 필요량이
/// 큰 순(같으면 카탈로그 순서)으로 [statisticsB3PanelCount]개까지 고른다. 아는 수량 점이 2개 미만인 재화는 뺀다. 시계
/// 되돌림이면 null(그리지 않는다).
StatisticsResourceTrends? statisticsResourceTrends(
  StatisticsHistory? history,
  InventoryBoard? board,
  StatisticsB3Range range,
) {
  if (history == null || board == null || !history.timestampsMonotonic) {
    return null;
  }
  final currencies = <StatisticsResourceTrend>[];
  final planned = <(StatisticsResourceTrend, double)>[];
  for (final view in board.items) {
    if (!view.isCurrency && !view.planned) continue;
    final trend = _resourceTrend(history, view, range);
    if (trend == null) continue;
    if (view.isCurrency) {
      currencies.add(trend);
      continue;
    }
    final net = trend.netChange;
    final required = view.requiredAmount;
    if (net == null || required == null) continue;
    planned.add((trend, net.abs() / required));
  }
  planned.sort((a, b) {
    final ratio = b.$2.compareTo(a.$2);
    return ratio != 0 ? ratio : a.$1.view.order.compareTo(b.$1.view.order);
  });
  final times = history.inventorySnapshotTimes;
  return StatisticsResourceTrends(
    panels: List.unmodifiable(
      [
        ...currencies,
        for (final item in planned) item.$1,
      ].take(statisticsB3PanelCount),
    ),
    snapshotCount: times.length,
    lastAt: times.isEmpty ? null : times.last,
  );
}
