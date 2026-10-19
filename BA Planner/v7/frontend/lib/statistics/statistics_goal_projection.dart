// 통계 "계획 집계" C4 학생별 목표 진행 projection(FE7-f, 시안 Stats-Plan C4, Statistics-Proposal C4, F §5 C4).
// 위젯이 없는 순수 계산이다. 입력은 계정 상태(스캔 현재 상태 · 사용자 목표)와 학생 목록(정적 메타)뿐이다. 계획 집계라
// 통계 필터와 상관없이 전체다(FD-104).
//
// - 행 = 활성 계획 학생(계정 상태 `goals`의 학생, 계획 집계 범위 칩 "활성 계획 · n명"과 같은 집합).
// - 현재 육성도 = FD-028 (a) 식(성장 projection과 같은 함수, 애장품 없는 학생은 6항목).
// - 목표 육성도 = 같은 식을 "목표를 덮어쓴 값 맵"에 쓴다(FD-028 "목표값에도 같은 공식"). 목표 키가 있는 항목은
//   max(현재, 목표)(이미 넘은 목표는 지금 값 — 목표 진행이 거꾸로 가지 않는다), 목표 키가 없는 항목은 그 목표가 올리지
//   않는 항목이라 현재 값이다. 현재 값을 모르고 목표 키도 없으면 모름이다(추정하지 않는다). 목표만 알고 현재를 모르면
//   목표 쪽 항목은 알지만 현재 육성도가 모름이라 그 행은 '—'다.
// - 남은 폭 = 목표 육성도 − 현재 육성도(0 이상). 행 순서: 남은 폭 큰 순 → 현재 낮은 순 → id. 둘 중 하나라도 모르는 행은
//   뒤(id 순).
// - 보유하지 않은 계획 학생은 현재 값이 없어 '—' 행이다(FD-028 "미보유 학생은 뺀다").
import 'package:flutter/foundation.dart';

import '../services/app_service.dart';
import '../services/repository_service.dart';
import 'statistics_growth_projection.dart';

/// C4에 그리는 행 수(시안 다섯 행).
const statisticsC4RowCount = 5;

/// 목표 키 → 확정 학생 값 키(FD-028 7항목에 드는 키만).
const statisticsGoalValueKeys = {
  'target_level': 'level',
  'target_ex_skill': 'ex_skill',
  'target_skill1': 'skill1',
  'target_skill2': 'skill2',
  'target_skill3': 'skill3',
  'target_equip1_tier': 'equip1',
  'target_equip2_tier': 'equip2',
  'target_equip3_tier': 'equip3',
  'target_equip4_tier': 'equip4',
  'target_star': 'student_star',
  'target_weapon_star': 'weapon_star',
};

/// 장비 · 애장품 티어 값 키.
const _tierKeys = {'equip1', 'equip2', 'equip3', 'equip4'};

/// 학생 한 명의 목표 진행.
@immutable
class StatisticsGoalProgress {
  const StatisticsGoalProgress({
    required this.studentId,
    required this.displayName,
    required this.current,
    required this.target,
  });

  final String studentId;
  final String displayName;

  /// 지금 값의 성장(보유하지 않았으면 모든 항목이 모름).
  final StatisticsStudentGrowth current;

  /// 목표를 덮어쓴 값의 성장.
  final StatisticsStudentGrowth target;

  double? get currentGrowth => current.growth;
  double? get targetGrowth => target.growth;

  /// 남은 폭(0~1). 둘 중 하나라도 모르면 null.
  double? get remaining {
    final now = currentGrowth, goal = targetGrowth;
    if (now == null || goal == null) return null;
    return goal - now < 0 ? 0 : goal - now;
  }

  bool get known => remaining != null;
}

/// C4 값.
@immutable
class StatisticsGoalProgressSet {
  StatisticsGoalProgressSet._(List<StatisticsGoalProgress> rows)
    : rows = List.unmodifiable(rows);

  /// [state]의 목표마다 한 행. [catalog]가 없으면 애장품 여부를 몰라 애장품이 모름이다(성장 projection과 같다).
  factory StatisticsGoalProgressSet.of({
    required RepositoryState state,
    required List<StudentCatalogEntry>? catalog,
  }) {
    final byId = {
      for (final entry in catalog ?? const <StudentCatalogEntry>[])
        entry.studentId: entry,
    };
    final students = {
      for (final student in state.students) student.studentId: student,
    };
    final rows = <StatisticsGoalProgress>[];
    final seen = <String>{};
    for (final goal in state.goals) {
      if (!seen.add(goal.studentId)) continue;
      final entry = byId[goal.studentId];
      final values = students[goal.studentId]?.values ?? const {};
      rows.add(
        StatisticsGoalProgress(
          studentId: goal.studentId,
          displayName: entry?.displayName ?? goal.studentId,
          current: statisticsGrowthOfValues(
            goal.studentId,
            values,
            catalog: entry,
            planned: true,
          ),
          target: statisticsGrowthOfValues(
            goal.studentId,
            statisticsGoalTargetValues(values, goal.values),
            catalog: entry,
            planned: true,
          ),
        ),
      );
    }
    rows.sort((a, b) {
      final x = a.remaining, y = b.remaining;
      if (x == null || y == null) {
        if (x != null) return -1;
        if (y != null) return 1;
        return a.studentId.compareTo(b.studentId);
      }
      final remaining = y.compareTo(x);
      if (remaining != 0) return remaining;
      final current = a.currentGrowth!.compareTo(b.currentGrowth!);
      return current != 0 ? current : a.studentId.compareTo(b.studentId);
    });
    return StatisticsGoalProgressSet._(rows);
  }

  /// 남은 폭 큰 순(모르는 행은 뒤).
  final List<StatisticsGoalProgress> rows;

  /// C4에 그리는 행(최대 [statisticsC4RowCount]).
  List<StatisticsGoalProgress> get visible =>
      rows.take(statisticsC4RowCount).toList(growable: false);

  StatisticsGoalProgress? operator [](String studentId) {
    for (final row in rows) {
      if (row.studentId == studentId) return row;
    }
    return null;
  }
}

/// 지금 값 [current]에 목표 [goal](`target_*`)을 덮어쓴 값 맵. 목표 키가 있으면 max(지금, 목표)(지금을 모르면 목표),
/// 없으면 지금 값 그대로다. 장비 · 애장품 티어는 정수로 쓴다(성장 projection이 정수 · `T7` 모두 읽는다).
Map<String, dynamic> statisticsGoalTargetValues(
  Map<String, dynamic> current,
  Map<String, dynamic> goal,
) {
  final result = Map<String, dynamic>.of(current);
  for (final MapEntry(key: targetKey, value: valueKey)
      in statisticsGoalValueKeys.entries) {
    final target = goal[targetKey];
    if (target is! int) continue;
    final now = _tierKeys.contains(valueKey)
        ? statisticsGrowthEquipmentTier(current[valueKey])
        : current[valueKey] is int
        ? current[valueKey] as int
        : null;
    result[valueKey] = now == null || target > now ? target : now;
  }
  return result;
}
