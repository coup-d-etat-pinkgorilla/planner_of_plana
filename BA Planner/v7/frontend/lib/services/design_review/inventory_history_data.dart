// FE6-f 인벤토리 이력 검수 데이터 도우미. mockdemo에서 `test/inventory_history_fixture.dart`에서 옮겼다.
//
// 검수 fixture(`test/inventory_fe6a_fixture.dart` · `test/inventory_fe6c_fixture.dart`)와 검수 시나리오 Mock
// (`mock_design_review_scenario.dart`)이 Mock 저장소에 넣을 현재 이력(FB-2a `current_history` v1)을 만든다. 시계는 고정이다
// ([inventoryHistoryFixtureNow] = 2026-10-05 12:00 UTC, 시안 날짜).
// - 기준선은 legacy(첫 스캔 앞 상태 = 각 재화의 가장 오래된 값)이고, 스캔 회차(지금 기준 며칠 전)마다 scan profile별
//   세션 하나(`scan_kind = inventory`, `inventory_scan_profile` = 카탈로그 profile)를 1분 간격으로 쌓는다. 세션 승인
//   scope는 그 회차에 값을 준 재화뿐이다.
// - 마지막 상태는 fixture의 지금 수량과 같아야 한다(Mock 생성자가 이력 → 지금 재구성을 검사한다).
import '../repository_service.dart';

/// 검수 fixture의 "지금"(시안 날짜 2026-10-05, 정오 UTC라 어느 시간대에서도 날짜 차가 같다).
final inventoryHistoryFixtureNow = DateTime.utc(2026, 10, 5, 12);

/// 검수 fixture 계정 상태의 revision(이력 적용 수보다 커야 한다).
const inventoryHistoryFixtureRevision = 40;

/// scan profile → resource key → (며칠 전 → 수량)으로 이력을 만든다.
///
/// [stateWire]는 revision과 수량 표로 `repository.state` wire를 만든다(학생 · 목표는 fixture 그대로).
RepositoryCurrentHistory inventoryFixtureScanHistory({
  required Map<String, dynamic> Function(int revision, Map<String, String> owned)
  stateWire,
  required Map<String, String> current,
  required Map<String, Map<String, Map<int, int>>> scans,
  DateTime? now,
}) {
  final at = now ?? inventoryHistoryFixtureNow;
  final owned = Map<String, String>.of(current);
  final days = <int>{};
  for (final keys in scans.values) {
    for (final entry in keys.entries) {
      final oldest = entry.value.keys.reduce((a, b) => a > b ? a : b);
      owned[entry.key] = '${entry.value[oldest]}';
      days.addAll(entry.value.keys);
    }
  }
  var before = RepositoryState.fromWire(stateWire(0, owned));
  var history = RepositoryCurrentHistory.empty(legacy: before);
  for (final day in days.toList()..sort((a, b) => b.compareTo(a))) {
    var minute = 0;
    for (final MapEntry(key: profile, value: keys) in scans.entries) {
      final scope = [
        for (final entry in keys.entries)
          if (entry.value.containsKey(day)) entry.key,
      ];
      if (scope.isEmpty) continue;
      for (final key in scope) {
        owned[key] = '${keys[key]![day]}';
      }
      final after = RepositoryState.fromWire(
        stateWire(before.revision + 1, owned),
      );
      history = history.appendScan(
        before,
        after,
        at.subtract(Duration(days: day)).add(Duration(minutes: minute++)),
        rawScanKind: 'inventory',
        rawInventoryScanProfile: profile,
        scanContext: {
          'session_id': 'fixture-scan-$day-$profile',
          'generation': 1,
          'candidate_id': 'fixture-candidate-$day-$profile',
          'candidate_revision': 0,
        },
        studentIds: const [],
        resourceKeys: scope,
      );
      before = after;
    }
  }
  if (before.revision > inventoryHistoryFixtureRevision) {
    throw StateError('fixture history needs a larger state revision');
  }
  for (final entry in owned.entries) {
    if (current[entry.key] != entry.value) {
      throw StateError('fixture history must end at ${entry.key}=${current[entry.key]}');
    }
  }
  return history;
}
