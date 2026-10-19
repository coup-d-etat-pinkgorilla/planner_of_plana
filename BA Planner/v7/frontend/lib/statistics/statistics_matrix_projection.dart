// 통계 3차 타일 projection(FE7-i, 시안 Stats-Growth A5 · Stats-Plan C5, Statistics-Proposal A5 · C5, F §2 · §5).
// 위젯이 없는 순수 계산이다. 입력은 성장 projection(FE7-b)뿐이다.
//
// - A5 스킬 · 장비 매트릭스(학생 성장 — 통계 필터가 걸렸으면 대상 학생만, FE7-e 발견 4 · F §3.2 모순 메모):
//   행 EX · 일반 · 강화 · 서브 · 장비 × 열 1–3 · 4–6 · 7–8 · 9 · M(시안 머리 글자). 칸 값 = 그 칸 학생 수(시안 행 합이
//   모두 보유 128명이라 비율이 아니라 인원이다). 행마다 학생 하나는 한 칸에만 든다.
//   - 일반(skill1) · 강화(skill2) · 서브(skill3): 레벨 1~10(M = 10). 강화 · 서브의 0(미개방)은 첫 칸이다.
//   - EX(ex_skill): 레벨 1~5(M = 5). 1–3 = 1~3, 4–6 = 4, M = 5이고 7–8 · 9 칸은 해당 없음(빗금, 시안 "EX 최대 5").
//   - 장비: 장비 3칸 티어 중 가장 낮은 칸(학생 탭 필터 "장비 티어 3칸 중 가장 낮은 칸"과 같은 값). T0~T3 = 첫 칸,
//     T4~T6 · T7~T8 · T9 · T10(M)이다.
//   - 그 행 값을 모르는 학생은 그 행에서 빠진다(0으로 채우지 않는다). 하나라도 모르는 학생 수를 "n명 모름"으로 센다.
// - C5 미계획 학생(계획 집계 — 늘 전체, FD-104): 편성(스트라이커 · 스페셜, 시안 행)마다 학생 점(가로축 육성도, FD-028).
//   계획 있음 = 사용자 목표가 있는 보유 학생(C4 · KPI "계획 등록"과 같은 집합). 고른 구간 = 미계획 · 육성도 40% 미만
//   (KPI "미계획 · 40% 미만"과 같은 `statisticsUnplannedLowStudents`, `statistics_supply_projection.dart`). 편성이나 육성도를 모르는 학생은 점이 없다.
import 'package:flutter/foundation.dart';

import 'statistics_growth_projection.dart';
import 'statistics_supply_projection.dart'
    show statisticsUnplannedLowGrowth, statisticsUnplannedLowStudents;

/// A5 행(시안 순서).
enum StatisticsMatrixRow {
  ex('EX', 'EX 스킬', 'ex_skill'),
  normal('일반', '일반 스킬', 'skill1'),
  enhanced('강화', '강화 스킬', 'skill2'),
  sub('서브', '서브 스킬', 'skill3'),
  equipment('장비', '장비', null);

  const StatisticsMatrixRow(this.label, this.title, this.valueKey);

  /// 그래프 행 글자(시안).
  final String label;

  /// 근거 머리 글자.
  final String title;

  /// 학생 값 키(장비는 3칸 티어 중 가장 낮은 칸이라 null).
  final String? valueKey;

  /// 해당 없는 열(빗금).
  bool appliesTo(int column) =>
      this != StatisticsMatrixRow.ex || (column != 2 && column != 3);

  /// 값 → 열(0~4). EX는 1~3 · 4 · 5(M), 나머지는 0~3 · 4~6 · 7~8 · 9 · 10(M).
  int columnOf(int value) {
    if (this == StatisticsMatrixRow.ex) {
      if (value <= 3) return 0;
      return value >= 5 ? 4 : 1;
    }
    if (value <= 3) return 0;
    if (value <= 6) return 1;
    if (value <= 8) return 2;
    return value >= 10 ? 4 : 3;
  }

  /// 근거 머리 열 글자(이 행에서 그 칸이 뜻하는 값).
  String columnTitle(int column) => switch (this) {
    StatisticsMatrixRow.ex => const ['1–3', '4', '—', '—', 'M'][column],
    StatisticsMatrixRow.normal => statisticsMatrixColumns[column],
    StatisticsMatrixRow.enhanced ||
    StatisticsMatrixRow.sub => const ['0–3', '4–6', '7–8', '9', 'M'][column],
    StatisticsMatrixRow.equipment => const [
      'T0–3',
      'T4–6',
      'T7–8',
      'T9',
      'T10',
    ][column],
  };
}

/// A5 열 머리 글자(시안).
const statisticsMatrixColumns = ['1–3', '4–6', '7–8', '9', 'M'];

/// A5 칸 하나.
@immutable
class StatisticsMatrixCell {
  const StatisticsMatrixCell(this.row, this.column);

  final StatisticsMatrixRow row;
  final int column;

  /// 근거 머리(예: "EX 스킬 1–3", "장비 T7–8").
  String get title => '${row.title} ${row.columnTitle(column)}';

  @override
  bool operator ==(Object other) =>
      other is StatisticsMatrixCell &&
      other.row == row &&
      other.column == column;

  @override
  int get hashCode => Object.hash(row, column);
}

/// A5 값.
@immutable
class StatisticsSkillMatrix {
  StatisticsSkillMatrix._({
    required Map<StatisticsMatrixRow, List<List<StatisticsStudentGrowth>>>
    cells,
    required this.unknownCount,
  }) : _cells = Map.unmodifiable({
         for (final entry in cells.entries)
           entry.key: List<List<StatisticsStudentGrowth>>.unmodifiable(
             entry.value.map(List<StatisticsStudentGrowth>.unmodifiable),
           ),
       });

  factory StatisticsSkillMatrix.of(StatisticsGrowth growth) {
    final cells = {
      for (final row in StatisticsMatrixRow.values)
        row: List.generate(
          statisticsMatrixColumns.length,
          (_) => <StatisticsStudentGrowth>[],
        ),
    };
    var unknown = 0;
    for (final student in growth.students) {
      var missing = false;
      for (final row in StatisticsMatrixRow.values) {
        final value = statisticsMatrixValue(student, row);
        if (value == null) {
          missing = true;
          continue;
        }
        cells[row]![row.columnOf(value)].add(student);
      }
      if (missing) unknown++;
    }
    for (final row in cells.values) {
      for (final students in row) {
        students.sort(statisticsCompareLowItem);
      }
    }
    return StatisticsSkillMatrix._(cells: cells, unknownCount: unknown);
  }

  final Map<StatisticsMatrixRow, List<List<StatisticsStudentGrowth>>> _cells;

  /// 행 값 하나라도 모르는 학생 수.
  final int unknownCount;

  /// 칸 학생(낮은 항목 순). 해당 없는 칸은 빈 목록이다.
  List<StatisticsStudentGrowth> operator [](StatisticsMatrixCell cell) =>
      _cells[cell.row]![cell.column];

  int count(StatisticsMatrixRow row, int column) => _cells[row]![column].length;

  /// 가장 많은 칸 인원(색 농도 기준). 모두 0이면 0.
  int get maxCount {
    var result = 0;
    for (final row in _cells.values) {
      for (final students in row) {
        if (students.length > result) result = students.length;
      }
    }
    return result;
  }

  /// 아는 값이 하나라도 있는가.
  bool get hasValues =>
      _cells.values.any((row) => row.any((students) => students.isNotEmpty));
}

/// 학생 한 명의 A5 행 값. 모르면 null.
int? statisticsMatrixValue(
  StatisticsStudentGrowth student,
  StatisticsMatrixRow row,
) => switch (row) {
  StatisticsMatrixRow.ex => student.exSkill,
  StatisticsMatrixRow.normal => student.skill1,
  StatisticsMatrixRow.enhanced => student.skill2,
  StatisticsMatrixRow.sub => student.skill3,
  StatisticsMatrixRow.equipment => student.lowestEquipmentTier,
};

// --- C5 ----------------------------------------------------------------------

/// C5 행 편성(시안 스트라이커 · 스페셜 순).
const statisticsC5CombatClasses = ['striker', 'special'];

/// C5 점 하나.
@immutable
class StatisticsUnplannedDot {
  const StatisticsUnplannedDot({
    required this.student,
    required this.row,
    required this.growth,
  });

  final StatisticsStudentGrowth student;

  /// 편성 행 순번([statisticsC5CombatClasses]).
  final int row;

  /// 육성도(0~1).
  final double growth;

  bool get planned => student.planned;

  /// 고른 구간(미계획 · 40% 미만)에 드는 점.
  bool get low => !planned && growth < statisticsUnplannedLowGrowth;
}

/// C5 값.
@immutable
class StatisticsUnplannedStrip {
  StatisticsUnplannedStrip._({
    required List<StatisticsUnplannedDot> dots,
    required List<StatisticsStudentGrowth> low,
    required this.unknownCount,
  }) : dots = List.unmodifiable(dots),
       low = List.unmodifiable(low);

  factory StatisticsUnplannedStrip.of(StatisticsGrowth growth) {
    final dots = <StatisticsUnplannedDot>[];
    var unknown = 0;
    for (final student in growth.students) {
      final value = student.growth;
      final row = statisticsC5CombatClasses.indexOf(student.combatClass ?? '');
      if (value == null || row < 0) {
        unknown++;
        continue;
      }
      dots.add(
        StatisticsUnplannedDot(student: student, row: row, growth: value),
      );
    }
    return StatisticsUnplannedStrip._(
      dots: dots,
      low: statisticsUnplannedLowStudents(growth),
      unknownCount: unknown,
    );
  }

  /// 편성과 육성도를 아는 보유 학생 점(성장 projection 학생 순 = id 순).
  final List<StatisticsUnplannedDot> dots;

  /// 미계획 · 40% 미만 학생(KPI와 같은 집합, 편성을 모르는 학생 포함), 육성도 낮은 순.
  final List<StatisticsStudentGrowth> low;

  /// 편성이나 육성도를 몰라 점이 없는 보유 학생 수.
  final int unknownCount;
}
