// 통계 "학생 성장" projection(FE7-b, FD-028 (a) · FD-029, 시안 Stats-Growth · Statistics-Proposal A1 · A2 · K).
//
// 화면과 분리한 순수 함수다. 입력은 `_reload()`가 읽은 계정 상태(스캔 현재 상태 · 사용자 목표)와 정적 메타(학생 목록)뿐이고,
// 계산 결과 · 부족 버킷은 쓰지 않는다.
//
// FD-028 (a)(확정 2026-10-06) 그대로:
// - 항목 완성도 = (현재 − 최소) / (최대 − 최소). 최소 · 최대는 `planElementTargetMinimums` · `planElementTargetMaximums`.
// - 육성도 = 7항목 단순 평균: 레벨, EX, 일반 스킬(skill1~3 완성도 평균), 장비(equip1~3 티어 완성도 평균),
//   애장품(equip4 티어), 성작(student_star), 전용무기(weapon_star). 미보유 학생은 뺀다.
// - 인연(bond_rank) · 추가 능력치(stat_hp · stat_atk · stat_heal) · 장비 레벨 · 전용무기 레벨은 성장 축이 달라 넣지 않는다.
// - A1 평균(학생 육성도의 평균)과 A2 막대(항목 완성도 평균)들의 평균은 같은 학생 집합 · 같은 값으로 센다. 그래서
//   모든 학생이 7항목을 다 가지면 두 값이 같다(단위 테스트로 고정).
// 착수 때 사용자 확인(2026-10-13):
// - 애장품이 없는 학생(카탈로그 `hasFavoriteItem == false`)은 애장품을 "해당 없음"으로 빼고 나머지 6항목 평균이다.
//   A2 애장품 막대는 애장품이 있는 학생만 센다. 이런 학생이 섞이면 A1 평균과 A2 막대 평균은 근사치가 된다.
// - A2는 7행이다(시안 6행 + 애장품).
// 모르는 값(값 없음 · 형식 아님 · 카탈로그에 없어 애장품 여부를 모름)은 0으로 채우지 않는다. 항목 하나라도 모르면 그 학생의
// 육성도는 모름이고, A1 · A2 · 평균 육성도 · 완전 육성에서 빠져 "n명 모름"으로 센다.
//
// FD-029(워커 재량, 권장안): 완전 육성 = 육성도 100%, 최대 레벨 = level이 최대(90), "낮음" = 그 항목 완성도 < 60%
// (A2 기준선과 같은 값).
import 'dart:math' as math;

import '../services/app_service.dart';
import '../services/repository_service.dart';
import '../ui/models/planning_growth_rules.dart';

/// A2 기준선이자 "낮음" 판정 값(FD-029).
const statisticsGrowthLowThreshold = 0.6;

/// A1 구간 수(10% 구간).
const statisticsGrowthBinCount = 10;

/// 육성도 항목(FD-028 (a), A2 행 순서).
enum StatisticsGrowthItem {
  level('레벨'),
  exSkill('EX 스킬'),
  normalSkill('일반 스킬'),
  equipment('장비'),
  favoriteItem('애장품'),
  studentStar('성작'),
  weapon('전용무기');

  const StatisticsGrowthItem(this.label);

  final String label;
}

/// A1 머리 seg(시안 육성도 · 레벨 · 스킬 · 장비).
enum StatisticsGrowthMetric {
  /// 7항목 육성도.
  growth('육성도'),

  /// 레벨 완성도.
  level('레벨'),

  /// EX · 일반 스킬 완성도 평균(FD-028 (b)의 "스킬 4종" 묶음).
  skill('스킬'),

  /// 장비(equip1~3 티어) 완성도.
  equipment('장비');

  const StatisticsGrowthMetric(this.label);

  final String label;
}

/// 근거 행의 "낮음" 칩(FD-029, 시안 근거 패널). 육성으로 올리는 항목(레벨 · 스킬 · 장비)만 단다.
enum StatisticsGrowthFlag {
  level('레벨 낮음'),
  skill('스킬 낮음'),
  equipment('장비 뒤처짐');

  const StatisticsGrowthFlag(this.label);

  final String label;
}

/// 학생 한 명의 성장 값.
class StatisticsStudentGrowth {
  StatisticsStudentGrowth({
    required this.studentId,
    required this.displayName,
    required this.level,
    required this.planned,
    required Map<StatisticsGrowthItem, double> items,
    required Set<StatisticsGrowthItem> unknownItems,
    this.studentStar,
    this.weaponStar,
    this.school,
    this.role,
    this.combatClass,
    this.exSkill,
    this.skill1,
    this.skill2,
    this.skill3,
    this.lowestEquipmentTier,
  }) : items = Map.unmodifiable(items),
       unknownItems = Set.unmodifiable(unknownItems);

  final String studentId;
  final String displayName;

  /// 스캔한 레벨. 모르면 null.
  final int? level;

  /// 계획(사용자 목표)에 등록된 학생인가.
  final bool planned;

  /// 아는 항목 완성도(0~1). 해당 없음(애장품 없는 학생)과 모르는 항목은 없다.
  final Map<StatisticsGrowthItem, double> items;

  /// 모르는 항목.
  final Set<StatisticsGrowthItem> unknownItems;

  /// 성급(★1~5, A3 · FE7-f). 모르면 null.
  final int? studentStar;

  /// 전용무기 ★(0 = 없음 · 1~4, A3 · FE7-f). 모르면 null.
  final int? weaponStar;

  /// 학생 목록의 학교 · 역할 · 편성 코드 값(A3 · A4, FE7-f). 학생 목록에 없거나 값이 없으면 null.
  final String? school;
  final String? role;
  final String? combatClass;

  /// A5 원값(FE7-i): EX · 일반(skill1) · 강화(skill2) · 서브(skill3) 레벨, 장비 3칸 티어 중 가장 낮은 칸. 모르면 null
  /// (장비는 한 칸이라도 모르면 null).
  final int? exSkill;
  final int? skill1;
  final int? skill2;
  final int? skill3;
  final int? lowestEquipmentTier;

  /// 육성도(0~1). 모르는 항목이 있으면 null.
  double? get growth {
    if (unknownItems.isNotEmpty || items.isEmpty) return null;
    var sum = 0.0;
    for (final value in items.values) {
      sum += value;
    }
    return sum / items.length;
  }

  /// A1 seg 값(0~1). 모르면 null.
  double? metric(StatisticsGrowthMetric metric) => switch (metric) {
    StatisticsGrowthMetric.growth => growth,
    StatisticsGrowthMetric.level => items[StatisticsGrowthItem.level],
    StatisticsGrowthMetric.skill => _mean([
      items[StatisticsGrowthItem.exSkill],
      items[StatisticsGrowthItem.normalSkill],
    ]),
    StatisticsGrowthMetric.equipment => items[StatisticsGrowthItem.equipment],
  };

  /// 칩을 다는 항목(레벨 · EX · 일반 스킬 · 장비) 중 가장 낮은 완성도. 모르면 null.
  double? get lowestTrainable {
    double? lowest;
    for (final item in _trainableItems) {
      final value = items[item];
      if (value == null) continue;
      if (lowest == null || value < lowest) lowest = value;
    }
    return lowest;
  }

  /// "낮음" 칩: 레벨 · 스킬(EX · 일반) · 장비 중 60% 미만인 가장 낮은 항목. 같으면 레벨 → 스킬 → 장비 순.
  StatisticsGrowthFlag? get flag {
    StatisticsGrowthItem? lowestItem;
    for (final item in _trainableItems) {
      final value = items[item];
      if (value == null || value >= statisticsGrowthLowThreshold) continue;
      if (lowestItem == null || value < items[lowestItem]!) lowestItem = item;
    }
    return switch (lowestItem) {
      null => null,
      StatisticsGrowthItem.level => StatisticsGrowthFlag.level,
      StatisticsGrowthItem.equipment => StatisticsGrowthFlag.equipment,
      _ => StatisticsGrowthFlag.skill,
    };
  }

  static const _trainableItems = [
    StatisticsGrowthItem.level,
    StatisticsGrowthItem.exSkill,
    StatisticsGrowthItem.normalSkill,
    StatisticsGrowthItem.equipment,
  ];
}

/// A1 한 장(seg 하나)의 분포.
class StatisticsGrowthHistogram {
  StatisticsGrowthHistogram({
    required this.metric,
    required List<List<StatisticsStudentGrowth>> bins,
    required this.unknownCount,
  }) : bins = List.unmodifiable(
         bins.map(List<StatisticsStudentGrowth>.unmodifiable),
       );

  final StatisticsGrowthMetric metric;

  /// 10% 구간별 학생(0~10 … 90~100, 100%는 마지막 구간).
  final List<List<StatisticsStudentGrowth>> bins;

  /// 보유했지만 이 값을 모르는 학생 수.
  final int unknownCount;

  int get knownCount => bins.fold(0, (sum, bin) => sum + bin.length);

  int get maxBinCount =>
      bins.fold(0, (value, bin) => math.max(value, bin.length));

  /// 평균(0~1). 아는 학생이 없으면 null.
  double? get mean {
    var sum = 0.0;
    var count = 0;
    for (final bin in bins) {
      for (final student in bin) {
        sum += student.metric(metric)!;
        count++;
      }
    }
    return count == 0 ? null : sum / count;
  }
}

/// 성장 주제 전체.
class StatisticsGrowth {
  StatisticsGrowth({
    required this.catalogCount,
    required List<StatisticsStudentGrowth> students,
  }) : students = List.unmodifiable(students);

  /// 학생 목록 수. 목록을 못 읽었으면 null.
  final int? catalogCount;

  /// 보유 학생(계정 상태의 확정 학생), id 순.
  final List<StatisticsStudentGrowth> students;

  int get ownedCount => students.length;

  /// 육성도를 아는 학생(A1 · A2 · 평균 육성도 · 완전 육성의 학생 집합).
  List<StatisticsStudentGrowth> get known => [
    for (final student in students)
      if (student.growth != null) student,
  ];

  /// 육성도를 모르는 보유 학생 수.
  int get unknownCount => ownedCount - known.length;

  /// 평균 육성도(0~1). 아는 학생이 없으면 null.
  double? get averageGrowth => histogram(StatisticsGrowthMetric.growth).mean;

  /// 레벨이 최대(90)인 학생 수. 레벨을 아는 학생이 없으면 null.
  int? get maxLevelCount {
    final maximum = planElementTargetMaximums['level']!;
    var known = 0;
    var count = 0;
    for (final student in students) {
      final level = student.level;
      if (level == null) continue;
      known++;
      if (level >= maximum) count++;
    }
    return known == 0 ? null : count;
  }

  /// 육성도 100%인 학생 수. 육성도를 아는 학생이 없으면 null.
  int? get fullGrowthCount {
    final values = known;
    if (values.isEmpty) return null;
    return values.where((student) => student.growth! >= 1 - _epsilon).length;
  }

  /// 계획(사용자 목표)에 등록된 보유 학생 수.
  int get plannedCount => students.where((student) => student.planned).length;

  /// A1 분포.
  StatisticsGrowthHistogram histogram(StatisticsGrowthMetric metric) {
    final bins = List.generate(
      statisticsGrowthBinCount,
      (_) => <StatisticsStudentGrowth>[],
    );
    var unknown = 0;
    for (final student in students) {
      final value = student.metric(metric);
      if (value == null) {
        unknown++;
        continue;
      }
      bins[statisticsGrowthBinOf(value)].add(student);
    }
    return StatisticsGrowthHistogram(
      metric: metric,
      bins: bins,
      unknownCount: unknown,
    );
  }

  /// A2 항목 평균(0~1, 육성도를 아는 학생 중 그 항목이 해당되는 학생). 해당 학생이 없으면 null.
  Map<StatisticsGrowthItem, double?> get itemAverages =>
      statisticsGrowthItemAverages(known);

  /// A2 강조 항목: 60% 기준선 아래인 항목(시안). 아래인 항목이 없으면 가장 낮은 항목 하나.
  Set<StatisticsGrowthItem> get emphasizedItems {
    final averages = itemAverages;
    final below = {
      for (final entry in averages.entries)
        if (entry.value != null && entry.value! < statisticsGrowthLowThreshold)
          entry.key,
    };
    if (below.isNotEmpty) return below;
    final lowest = statisticsGrowthLowestItem(averages);
    return {?lowest?.item};
  }

  /// A1 구간 근거: 그 구간 학생, 낮은 항목 순(칩 항목 중 가장 낮은 완성도 → 육성도 → id).
  List<StatisticsStudentGrowth> binStudents(
    StatisticsGrowthMetric metric,
    int bin,
  ) {
    final result = [...histogram(metric).bins[bin]];
    result.sort(statisticsCompareLowItem);
    return result;
  }

  /// A2 항목 근거: 육성도를 아는 학생 중 그 항목이 해당되는 학생, 그 항목이 낮은 순(→ id).
  List<StatisticsStudentGrowth> itemStudents(StatisticsGrowthItem item) {
    final result = [
      for (final student in known)
        if (student.items.containsKey(item)) student,
    ];
    result.sort((a, b) {
      final value = a.items[item]!.compareTo(b.items[item]!);
      return value != 0 ? value : a.studentId.compareTo(b.studentId);
    });
    return result;
  }
}

/// 근거 패널 "구간 요약"(시안: 평균 레벨 · 가장 낮은 항목 · 계획 등록).
class StatisticsGrowthSummary {
  const StatisticsGrowthSummary({
    required this.averageLevel,
    required this.lowestItem,
    required this.plannedCount,
  });

  factory StatisticsGrowthSummary.of(List<StatisticsStudentGrowth> students) {
    final levels = [for (final student in students) ?student.level];
    return StatisticsGrowthSummary(
      averageLevel: levels.isEmpty
          ? null
          : levels.fold<int>(0, (sum, level) => sum + level) / levels.length,
      lowestItem: statisticsGrowthLowestItem(
        statisticsGrowthItemAverages([
          for (final student in students)
            if (student.growth != null) student,
        ]),
      ),
      plannedCount: students.where((student) => student.planned).length,
    );
  }

  /// 평균 레벨. 레벨을 아는 학생이 없으면 null.
  final double? averageLevel;

  /// 가장 낮은 항목과 그 평균 완성도. 모르면 null.
  final ({StatisticsGrowthItem item, double value})? lowestItem;
  final int plannedCount;
}

const _epsilon = 1e-9;

/// 근거 "낮은 항목 순"(A1 구간 · A3 단계 · A4 그룹): 칩 항목 중 가장 낮은 완성도 → 육성도 → id. 모르는 값은 뒤다.
int statisticsCompareLowItem(
  StatisticsStudentGrowth a,
  StatisticsStudentGrowth b,
) {
  final low = (a.lowestTrainable ?? 2).compareTo(b.lowestTrainable ?? 2);
  if (low != 0) return low;
  final growth = (a.growth ?? 2).compareTo(b.growth ?? 2);
  return growth != 0 ? growth : a.studentId.compareTo(b.studentId);
}

/// 0~1 값의 10% 구간 번호(0~9, 100%는 9).
int statisticsGrowthBinOf(double value) => math.min(
  statisticsGrowthBinCount - 1,
  math.max(0, ((value * 100 + _epsilon) ~/ 10)),
);

/// 구간 글자(예: "60~70%").
String statisticsGrowthBinLabel(int bin) => '${bin * 10}~${bin * 10 + 10}%';

/// 학생들의 항목 평균. 그 항목이 해당되는 학생이 없으면 null.
Map<StatisticsGrowthItem, double?> statisticsGrowthItemAverages(
  List<StatisticsStudentGrowth> students,
) => {
  for (final item in StatisticsGrowthItem.values)
    item: _mean([
      for (final student in students)
        if (student.items.containsKey(item)) student.items[item],
    ]),
};

/// 평균이 가장 낮은 항목(같으면 앞 항목). 아는 항목이 없으면 null.
({StatisticsGrowthItem item, double value})? statisticsGrowthLowestItem(
  Map<StatisticsGrowthItem, double?> averages,
) {
  ({StatisticsGrowthItem item, double value})? lowest;
  for (final item in StatisticsGrowthItem.values) {
    final value = averages[item];
    if (value == null) continue;
    if (lowest == null || value < lowest.value) {
      lowest = (item: item, value: value);
    }
  }
  return lowest;
}

double? _mean(Iterable<double?> values) {
  var sum = 0.0;
  var count = 0;
  for (final value in values) {
    if (value == null) return null;
    sum += value;
    count++;
  }
  return count == 0 ? null : sum / count;
}

/// 항목 완성도 (현재 − 최소) / (최대 − 최소), 0~1로 자른다. 값이 정수가 아니면 null(모름).
double? statisticsGrowthCompletion(String key, Object? value) {
  if (value is! int) return null;
  final minimum = planElementTargetMinimums[key]!;
  final maximum = planElementTargetMaximums[key]!;
  return ((value - minimum) / (maximum - minimum)).clamp(0.0, 1.0).toDouble();
}

/// 장비 · 애장품 티어(확정값은 `T7` 같은 글자). 계획 요소 빌더(`planElementCurrentTargets`)와 같이 숫자를 읽고,
/// 숫자가 없는 글자(`love_locked` 등)는 0이다. 값이 없으면 null(모름)이다.
int? statisticsGrowthEquipmentTier(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  final match = RegExp(r'(\d+)').firstMatch(value.toString());
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// 학생 한 명의 항목 완성도. [catalog]가 없으면 애장품 여부를 몰라 애장품이 모름이다.
StatisticsStudentGrowth statisticsStudentGrowth(
  ConfirmedStudentState student, {
  StudentCatalogEntry? catalog,
  bool planned = false,
}) => statisticsGrowthOfValues(
  student.studentId,
  student.values,
  catalog: catalog,
  planned: planned,
);

/// 값 맵(확정 학생 `values`와 같은 키) 하나의 항목 완성도. C4 목표 육성도(FE7-f)도 목표를 덮어쓴 값 맵으로 같은 식을 쓴다
/// (FD-028 "목표값에도 같은 공식").
StatisticsStudentGrowth statisticsGrowthOfValues(
  String studentId,
  Map<String, dynamic> values, {
  StudentCatalogEntry? catalog,
  bool planned = false,
}) {
  final items = <StatisticsGrowthItem, double>{};
  final unknown = <StatisticsGrowthItem>{};
  void put(StatisticsGrowthItem item, double? value) {
    if (value == null) {
      unknown.add(item);
    } else {
      items[item] = value;
    }
  }

  double? tier(String valueKey, String ruleKey) {
    final value = statisticsGrowthEquipmentTier(values[valueKey]);
    return value == null ? null : statisticsGrowthCompletion(ruleKey, value);
  }

  put(
    StatisticsGrowthItem.level,
    statisticsGrowthCompletion('level', values['level']),
  );
  put(
    StatisticsGrowthItem.exSkill,
    statisticsGrowthCompletion('ex_skill', values['ex_skill']),
  );
  put(
    StatisticsGrowthItem.normalSkill,
    _mean([
      for (final key in const ['skill1', 'skill2', 'skill3'])
        statisticsGrowthCompletion(key, values[key]),
    ]),
  );
  put(
    StatisticsGrowthItem.equipment,
    _mean([
      for (var slot = 1; slot <= 3; slot++)
        tier('equip$slot', 'equip${slot}_tier'),
    ]),
  );
  if (catalog == null) {
    unknown.add(StatisticsGrowthItem.favoriteItem);
  } else if (catalog.hasFavoriteItem) {
    put(StatisticsGrowthItem.favoriteItem, tier('equip4', 'equip4_tier'));
  }
  put(
    StatisticsGrowthItem.studentStar,
    statisticsGrowthCompletion('student_star', values['student_star']),
  );
  put(
    StatisticsGrowthItem.weapon,
    statisticsGrowthCompletion('weapon_star', values['weapon_star']),
  );
  final level = values['level'];
  final star = values['student_star'];
  final weapon = values['weapon_star'];
  int? whole(String key) => values[key] is int ? values[key] as int : null;
  final tiers = [
    for (var slot = 1; slot <= 3; slot++)
      statisticsGrowthEquipmentTier(values['equip$slot']),
  ];
  return StatisticsStudentGrowth(
    studentId: studentId,
    displayName: catalog?.displayName ?? studentId,
    level: level is int ? level : null,
    planned: planned,
    items: items,
    unknownItems: unknown,
    studentStar: star is int ? star : null,
    weaponStar: weapon is int ? weapon : null,
    school: catalog?.school,
    role: catalog?.role,
    combatClass: catalog?.combatClass,
    exSkill: whole('ex_skill'),
    skill1: whole('skill1'),
    skill2: whole('skill2'),
    skill3: whole('skill3'),
    lowestEquipmentTier: tiers.contains(null)
        ? null
        : tiers.whereType<int>().reduce(math.min),
  );
}

/// 성장 주제 projection. [state]가 없으면 null(읽지 못함).
StatisticsGrowth? buildStatisticsGrowth({
  required RepositoryState? state,
  required List<StudentCatalogEntry>? catalog,
}) {
  if (state == null) return null;
  final catalogById = <String, StudentCatalogEntry>{
    for (final entry in catalog ?? const <StudentCatalogEntry>[])
      entry.studentId: entry,
  };
  final planned = {for (final goal in state.goals) goal.studentId};
  final students = [
    for (final student in state.students)
      statisticsStudentGrowth(
        student,
        catalog: catalogById[student.studentId],
        planned: planned.contains(student.studentId),
      ),
  ]..sort((a, b) => a.studentId.compareTo(b.studentId));
  return StatisticsGrowth(
    catalogCount: catalog == null ? null : catalogById.length,
    students: students,
  );
}

/// 퍼센트 글자: 한 자리(평균 육성도 "63.4%") 또는 정수("82%").
String statisticsPercentText(double fraction, {int decimals = 0}) {
  final scale = math.pow(10, decimals).toDouble();
  final value = (fraction * 100 * scale).round() / scale;
  return '${value.toStringAsFixed(decimals)}%';
}
