// 통계 "학생 성장" 2차 타일 projection(FE7-f, 시안 Stats-Growth A3 · A4, Statistics-Proposal A3 · A4, F §2 · §5).
// 위젯이 없는 순수 계산이다. 입력은 성장 projection(FE7-b, 통계 필터가 걸렸으면 대상 학생만 — FE7-e)과 학생 목록(정적
// 메타)뿐이다.
//
// - A3 성작 · 전용무기: 성급 ★1~5 · 전용무기 없음(0) · 1~4 단계마다 학생 수(단계 막대), 편성(스트라이커 · 스페셜)마다 ★1~5
//   비율(100% 누적). 값을 모르는 학생은 그 막대에서 빼고 "n명 모름"으로 센다(0으로 채우지 않는다). 편성을 모르는 학생은
//   누적 막대에서만 빠진다.
// - A4 학교 · 역할 비교: 그룹(seg 학교 · 역할, 학생 목록 코드 값)마다 점 하나.
//   - 보유율 = 그 그룹의 대상(보유) 학생 수 / 학생 목록에서 그 그룹 학생 수. 분모는 필터와 상관없는 학생 목록 전체다.
//   - 평균 육성도 = 그 그룹 대상 학생 중 육성도(FD-028)를 아는 학생의 평균. 아는 학생이 없는 그룹은 점이 없다.
//   - 평균선 = 점을 찍은 그룹 전체의 보유율(대상 학생 합 / 학생 목록 합)과 평균 육성도(아는 학생 전체 평균). 필터가
//     없으면 평균 육성도는 KPI "평균 육성도"와 같다.
//   - 학교의 협업 값(Sakugawa · Tokiwadai)은 학생 탭 필터 칩과 같이 그룹으로 세지 않는다.
//   - 빈 상태(시안 Stats-Growth-Filter, FE7-e 발견 3): 통계 필터가 걸렸고 대상 학생의 고른 seg 값이 하나 이하.
// FE7-i: A5 스킬 · 장비 매트릭스(`statistics_matrix_projection.dart`)도 같은 학생으로 함께 만든다([StatisticsGrowthBreakdown.matrix]).
import 'package:flutter/foundation.dart';

import '../services/app_service.dart';
import 'statistics_growth_projection.dart';
import 'statistics_matrix_projection.dart';

/// A3 단계 종류.
enum StatisticsStarKind {
  /// 성급 ★1~5.
  star('성작'),

  /// 전용무기 없음 · 1~4.
  weapon('전용무기');

  const StatisticsStarKind(this.label);

  final String label;

  /// 단계 수.
  int get steps => 5;

  /// 단계 순번(0부터)의 막대 아래 글자(시안 "★1" · "없음" · "1").
  String stepLabel(int index) => switch (this) {
    StatisticsStarKind.star => '★${index + 1}',
    StatisticsStarKind.weapon => index == 0 ? '없음' : '$index',
  };

  /// 근거 머리 글자(예: "성작 ★3", "전용무기 없음", "전용무기 ★2").
  String titleOf(int index) => switch (this) {
    StatisticsStarKind.star => '성작 ★${index + 1}',
    StatisticsStarKind.weapon => index == 0 ? '전용무기 없음' : '전용무기 ★$index',
  };
}

/// A3 100% 누적 막대의 편성(시안 스트라이커 · 스페셜 순).
const statisticsA3CombatClasses = ['striker', 'special'];

/// A3 값.
@immutable
class StatisticsStarDistribution {
  StatisticsStarDistribution._({
    required List<List<StatisticsStudentGrowth>> stars,
    required List<List<StatisticsStudentGrowth>> weapons,
    required Map<String, List<int>> classMix,
    required this.unknownStars,
    required this.unknownWeapons,
  }) : stars = List.unmodifiable(
         stars.map(List<StatisticsStudentGrowth>.unmodifiable),
       ),
       weapons = List.unmodifiable(
         weapons.map(List<StatisticsStudentGrowth>.unmodifiable),
       ),
       classMix = Map.unmodifiable({
         for (final entry in classMix.entries)
           entry.key: List<int>.unmodifiable(entry.value),
       });

  factory StatisticsStarDistribution.of(StatisticsGrowth growth) {
    final stars = List.generate(5, (_) => <StatisticsStudentGrowth>[]);
    final weapons = List.generate(5, (_) => <StatisticsStudentGrowth>[]);
    final mix = {
      for (final value in statisticsA3CombatClasses) value: List.filled(5, 0),
    };
    var unknownStars = 0, unknownWeapons = 0;
    for (final student in growth.students) {
      final star = student.studentStar;
      if (star == null || star < 1 || star > 5) {
        unknownStars++;
      } else {
        stars[star - 1].add(student);
        mix[student.combatClass]?[star - 1]++;
      }
      final weapon = student.weaponStar;
      if (weapon == null || weapon < 0 || weapon > 4) {
        unknownWeapons++;
      } else {
        weapons[weapon].add(student);
      }
    }
    for (final list in [...stars, ...weapons]) {
      list.sort(statisticsCompareLowItem);
    }
    return StatisticsStarDistribution._(
      stars: stars,
      weapons: weapons,
      classMix: mix,
      unknownStars: unknownStars,
      unknownWeapons: unknownWeapons,
    );
  }

  /// ★1~5 학생(낮은 항목 순).
  final List<List<StatisticsStudentGrowth>> stars;

  /// 전용무기 없음 · 1~4 학생(낮은 항목 순).
  final List<List<StatisticsStudentGrowth>> weapons;

  /// 편성 → ★1~5 학생 수(성급을 아는 학생만).
  final Map<String, List<int>> classMix;
  final int unknownStars;
  final int unknownWeapons;

  List<List<StatisticsStudentGrowth>> of(StatisticsStarKind kind) =>
      kind == StatisticsStarKind.star ? stars : weapons;

  /// 단계 막대 축 최대(두 묶음 공통, 시안 성작 · 전용무기 같은 축척).
  int get maxCount {
    var result = 0;
    for (final list in [...stars, ...weapons]) {
      if (list.length > result) result = list.length;
    }
    return result;
  }

  /// 아는 값이 하나도 없다.
  bool get isEmpty =>
      stars.every((list) => list.isEmpty) &&
      weapons.every((list) => list.isEmpty);
}

/// A3 고른 단계.
@immutable
class StatisticsStarStep {
  const StatisticsStarStep(this.kind, this.index);

  final StatisticsStarKind kind;

  /// 0부터(성작 ★1 = 0, 전용무기 없음 = 0).
  final int index;

  @override
  bool operator ==(Object other) =>
      other is StatisticsStarStep && other.kind == kind && other.index == index;

  @override
  int get hashCode => Object.hash(kind, index);
}

/// A4 seg(시안 학교 · 역할).
enum StatisticsA4Group {
  school('학교', 'school'),
  role('역할', 'role');

  const StatisticsA4Group(this.label, this.key);

  final String label;

  /// 학생 필터 그룹 key(`studentFilterChipLabel` 이름표).
  final String key;

  /// 학생 목록 코드 값. 협업 학교 값은 그룹이 아니다(학생 탭 필터 칩과 같다).
  String? read(StudentCatalogEntry entry) =>
      readValue(this == StatisticsA4Group.school ? entry.school : entry.role);

  /// 성장 학생의 코드 값.
  String? readGrowth(StatisticsStudentGrowth student) => readValue(
    this == StatisticsA4Group.school ? student.school : student.role,
  );

  String? readValue(String? value) {
    if (value == null || value.isEmpty) return null;
    if (this == StatisticsA4Group.school &&
        statisticsA4ExcludedSchools.contains(value)) {
      return null;
    }
    return value;
  }
}

/// 학생 탭 필터 학교 칩에서 빼는 협업 값(`studentCatalogFilterGroups`와 같다).
const statisticsA4ExcludedSchools = {'Sakugawa', 'Tokiwadai'};

/// A4 점 하나(그룹).
@immutable
class StatisticsGroupPoint {
  StatisticsGroupPoint({
    required this.value,
    required this.catalogCount,
    required List<StatisticsStudentGrowth> students,
  }) : students = List.unmodifiable(students);

  /// 학생 목록 코드 값(학교 · 역할).
  final String value;

  /// 학생 목록에서 이 그룹 학생 수(보유율 분모).
  final int catalogCount;

  /// 이 그룹의 대상(보유) 학생(낮은 항목 순).
  final List<StatisticsStudentGrowth> students;

  int get ownedCount => students.length;

  /// 보유율(0~1). 학생 목록에 이 그룹이 없으면 null.
  double? get ownedRatio =>
      catalogCount <= 0 ? null : ownedCount / catalogCount;

  /// 육성도를 아는 학생의 평균(0~1). 없으면 null.
  double? get averageGrowth {
    var sum = 0.0;
    var count = 0;
    for (final student in students) {
      final value = student.growth;
      if (value == null) continue;
      sum += value;
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  /// 산점도에 찍을 수 있다(보유율 · 평균 육성도를 안다).
  bool get plotted => ownedRatio != null && averageGrowth != null;

  int get plannedCount => students.where((student) => student.planned).length;
}

/// A4 한 seg의 값.
@immutable
class StatisticsGroupComparison {
  StatisticsGroupComparison._({
    required this.group,
    required List<StatisticsGroupPoint> groups,
    required this.unknownCount,
  }) : groups = List.unmodifiable(groups);

  /// [growth] 대상 학생을 [group]으로 나눈다. [catalog]가 없으면 보유율을 몰라 점이 없다.
  factory StatisticsGroupComparison.of(
    StatisticsGrowth growth,
    List<StudentCatalogEntry>? catalog,
    StatisticsA4Group group,
  ) {
    final totals = <String, int>{};
    for (final entry in catalog ?? const <StudentCatalogEntry>[]) {
      final value = group.read(entry);
      if (value == null) continue;
      totals[value] = (totals[value] ?? 0) + 1;
    }
    final members = <String, List<StatisticsStudentGrowth>>{};
    var unknown = 0;
    for (final student in growth.students) {
      final value = group.readGrowth(student);
      if (value == null) {
        unknown++;
        continue;
      }
      members.putIfAbsent(value, () => []).add(student);
    }
    final groups = [
      for (final entry in members.entries)
        StatisticsGroupPoint(
          value: entry.key,
          catalogCount: totals[entry.key] ?? 0,
          students: entry.value..sort(statisticsCompareLowItem),
        ),
    ]..sort((a, b) => a.value.compareTo(b.value));
    return StatisticsGroupComparison._(
      group: group,
      groups: groups,
      unknownCount: unknown,
    );
  }

  final StatisticsA4Group group;

  /// 대상 학생이 있는 그룹(코드 값 순).
  final List<StatisticsGroupPoint> groups;

  /// 그룹 값을 모르는 대상 학생 수(학생 목록에 없음 · 값 없음 · 협업 학교).
  final int unknownCount;

  /// 대상 학생의 그룹 값 수(빈 상태 판정, FE7-e 발견 3).
  int get valueCount => groups.length;

  /// 찍는 점.
  List<StatisticsGroupPoint> get points => [
    for (final point in groups)
      if (point.plotted) point,
  ];

  /// 평균선 보유율: 점을 찍은 그룹의 대상 학생 합 / 학생 목록 합. 점이 없으면 null.
  double? get meanRatio {
    var owned = 0, total = 0;
    for (final point in points) {
      owned += point.ownedCount;
      total += point.catalogCount;
    }
    return total == 0 ? null : owned / total;
  }

  /// 평균선 육성도: 점을 찍은 그룹에서 육성도를 아는 학생 전체 평균. 점이 없으면 null.
  double? get meanGrowth {
    var sum = 0.0;
    var count = 0;
    for (final point in points) {
      for (final student in point.students) {
        final value = student.growth;
        if (value == null) continue;
        sum += value;
        count++;
      }
    }
    return count == 0 ? null : sum / count;
  }

  /// 고른 그룹. 없으면 null.
  StatisticsGroupPoint? operator [](String value) {
    for (final point in groups) {
      if (point.value == value) return point;
    }
    return null;
  }

  /// 시안 강조(분홍, 질문 "많이 모였지만 덜 키운 학교"): 평균 육성도가 평균선 아래인 점 중 대상 학생이 가장 많은 점(같으면
  /// 보유율 높은 → 코드 값 순). 평균선 아래 점이 없으면 null. 점을 고르면 고른 점이 강조다(차트가 정한다).
  StatisticsGroupPoint? get emphasized {
    final mean = meanGrowth;
    if (mean == null) return null;
    StatisticsGroupPoint? best;
    for (final point in points) {
      if (point.averageGrowth! >= mean) continue;
      if (best == null ||
          point.ownedCount > best.ownedCount ||
          (point.ownedCount == best.ownedCount &&
              point.ownedRatio! > best.ownedRatio!)) {
        best = point;
      }
    }
    return best;
  }
}

/// A4 고른 점.
@immutable
class StatisticsGroupSelection {
  const StatisticsGroupSelection(this.group, this.value);

  final StatisticsA4Group group;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is StatisticsGroupSelection &&
      other.group == group &&
      other.value == value;

  @override
  int get hashCode => Object.hash(group, value);
}

/// 학생 성장 2차 타일 값(A3 · A4 두 seg). 페이지가 성장 · 학생 목록이 같으면 다시 만들지 않는다.
@immutable
class StatisticsGrowthBreakdown {
  StatisticsGrowthBreakdown._({
    required this.stars,
    required this.matrix,
    required Map<StatisticsA4Group, StatisticsGroupComparison> comparisons,
  }) : _comparisons = Map.unmodifiable(comparisons);

  factory StatisticsGrowthBreakdown.of(
    StatisticsGrowth growth,
    List<StudentCatalogEntry>? catalog,
  ) => StatisticsGrowthBreakdown._(
    stars: StatisticsStarDistribution.of(growth),
    matrix: StatisticsSkillMatrix.of(growth),
    comparisons: {
      for (final group in StatisticsA4Group.values)
        group: StatisticsGroupComparison.of(growth, catalog, group),
    },
  );

  final StatisticsStarDistribution stars;

  /// A5 스킬 · 장비 매트릭스(같은 학생, FE7-i).
  final StatisticsSkillMatrix matrix;
  final Map<StatisticsA4Group, StatisticsGroupComparison> _comparisons;

  StatisticsGroupComparison comparison(StatisticsA4Group group) =>
      _comparisons[group]!;
}
