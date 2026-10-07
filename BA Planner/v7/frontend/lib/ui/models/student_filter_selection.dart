// 필터 선택 값과 성장 범위 모델 (FE3-d1).
//
// 학생 탭·계획 만들기 1단계·통계가 함께 쓰는 필터 모달(FE3-d2)의 값이다. 상태 객체(FD-104)는 이 값을
// 적용 값과 초안(draft)으로 들고, 모달은 초안을 바꾸고 "적용"으로 적용 값에 넣는다.
//
// - 속성: 그룹마다 고른 값. 같은 그룹 = 또는, 그룹끼리 = 그리고(시안 도움말).
// - 보유 · 서버: 보유/미보유(또는) + 일본 서버 전용 제외. S4 토글과 같은 상태다(FD-057).
// - 성장 범위(FD-053): 행마다 최소~최대. 장비 티어·레벨은 3칸 중 가장 낮은 칸, 성급은 학생★ + 전용무기★
//   9단계 하나, 추가 능력치는 HP·ATK·HEAL 합 0~75(FD-055). 강화·서브 최소 0은 "–"로 쓴다(FD-059).
//   행 목록은 그룹마다 늘릴 수 있다(FD-063, 육성도 행은 FE7-d). 심상개화는 비활성 자리다(FD-054).
// - 토글 칩 옆 학생 수: 같은 그룹 조건은 빼고 다른 그룹 조건만 반영해 센다(FD-056 (a)).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../services/app_service.dart';
import '../kit/range_controls.dart'
    show
        starRangeStepCount,
        starRangeStepLabel,
        starRangeStepSpoken,
        starRangeStudentSteps;
import '../widgets/plan_element_builder.dart' show planElementCurrentTargets;
import '../widgets/student_section_layout.dart';
import 'planning_models.dart';

// ---------------------------------------------------------------------------
// 성장 범위

/// 범위 값 표시 방식.
enum StudentRangeValueStyle {
  /// 숫자 그대로.
  plain,

  /// 장비·애장품 티어 `T0`.
  tier,

  /// 스킬: 최대 = `M`, 0(미개방) = `–`(FD-059).
  skill,

  /// 성급 9단계: 1~5 = `★n`, 6~9 = `무기★n`.
  star,
}

/// 성장 범위 한 행.
class StudentGrowthRangeRow {
  const StudentGrowthRangeRow({
    required this.key,
    required this.label,
    required this.chipLabel,
    required this.min,
    required this.max,
    required this.read,
    this.caption,
    this.style = StudentRangeValueStyle.plain,
  }) : assert(min < max);

  /// 범위 키(`level`, `star` …). 조건 저장·위젯 키에 쓴다.
  final String key;

  /// 행 이름(시안 13px 굵게, "학생 레벨").
  final String label;

  /// 적용 칩 이름(시안 머리 칩 "레벨 70~90").
  final String chipLabel;

  /// 행 이름 아래 보조 설명(시안 10.5px, "3칸 중 가장 낮은 칸").
  final String? caption;
  final int min;
  final int max;
  final StudentRangeValueStyle style;

  /// 학생의 현재 성장 값([planElementCurrentTargets] 결과)에서 이 행의 값을 읽는다.
  final int Function(Map<String, int> growth) read;

  /// 행 오른쪽 값(시안 `70 ~ 90`, `1 ~ M`, `T0 ~ T10`, `★3 ~ 무기★1`).
  String formatValue(int value) => switch (style) {
    StudentRangeValueStyle.plain => '$value',
    StudentRangeValueStyle.tier => 'T$value',
    StudentRangeValueStyle.skill =>
      value == 0 ? '–' : (value >= max ? 'M' : '$value'),
    StudentRangeValueStyle.star => starRangeStepLabel(value),
  };

  /// 접근성 값 문구(읽는 말): 티어 "7티어", 스킬 0 "미개방", 성급 "학생 3성"·"전용무기 1성".
  String formatSpokenValue(int value) => switch (style) {
    StudentRangeValueStyle.plain => '$value',
    StudentRangeValueStyle.tier => '$value티어',
    StudentRangeValueStyle.skill => value == 0 ? '미개방' : '$value',
    StudentRangeValueStyle.star => starRangeStepSpoken(value),
  };

  /// 칩 안 값. 스킬 최대는 숫자로 쓴다(시안 머리 칩 "EX 3~5").
  String formatChipValue(int value) => switch (style) {
    StudentRangeValueStyle.skill => value == 0 ? '–' : '$value',
    _ => formatValue(value),
  };

  /// 적용 칩 문구("레벨 70~90").
  String chipText(int low, int high) =>
      '$chipLabel ${formatChipValue(low)}~${formatChipValue(high)}';
}

/// 성장 범위 그룹(시안 소제목 "기본", "스킬", "장비 · 능력치").
class StudentGrowthRangeGroup {
  const StudentGrowthRangeGroup({
    required this.key,
    required this.label,
    required this.rows,
  });

  final String key;
  final String label;
  final List<StudentGrowthRangeRow> rows;
}

/// 학생★·전용무기★ → 9단계(1~9, [starRangeStepCount]). 학생★ 5 미만이면 학생★, 5면 5 + 전용무기★.
int studentStarStep({required int studentStar, required int weaponStar}) {
  final student = studentStar.clamp(1, starRangeStudentSteps);
  if (student < starRangeStudentSteps) return student;
  return starRangeStudentSteps +
      weaponStar.clamp(0, starRangeStepCount - starRangeStudentSteps);
}

int _growth(Map<String, int> growth, String key, int fallback) =>
    growth[key] ?? fallback;

int _lowestOf(Map<String, int> growth, List<String> keys) =>
    keys.map((key) => _growth(growth, key, 0)).reduce(math.min);

/// 추가 능력치 합의 최대(각 25 × 3, FD-055 (a)).
const studentStatSumMaximum = 75;

/// 성장 범위 그룹과 행(시안 Student-Filter 오른쪽 패널 순서). FD-063: 육성도 행은 FE7-d에서
/// "기본" 그룹 첫 줄에 더한다.
final List<StudentGrowthRangeGroup> studentGrowthRangeGroups = [
  StudentGrowthRangeGroup(
    key: 'basic',
    label: '기본',
    rows: [
      StudentGrowthRangeRow(
        key: 'level',
        label: '학생 레벨',
        chipLabel: '레벨',
        min: 1,
        max: 90,
        read: (growth) => _growth(growth, 'level', 1),
      ),
      StudentGrowthRangeRow(
        key: 'star',
        label: '성급',
        chipLabel: '성급',
        caption: '학생 ★ + 전용무기 ★',
        min: 1,
        max: starRangeStepCount,
        style: StudentRangeValueStyle.star,
        read: (growth) => studentStarStep(
          studentStar: _growth(growth, 'student_star', 1),
          weaponStar: _growth(growth, 'weapon_star', 0),
        ),
      ),
      StudentGrowthRangeRow(
        key: 'weapon_level',
        label: '전용무기 레벨',
        chipLabel: '전무 레벨',
        min: 0,
        max: 60,
        read: (growth) => _growth(growth, 'weapon_level', 0),
      ),
      StudentGrowthRangeRow(
        key: 'bond_rank',
        label: '인연 랭크',
        chipLabel: '인연',
        min: 1,
        max: 100,
        read: (growth) => _growth(growth, 'bond_rank', 1),
      ),
    ],
  ),
  StudentGrowthRangeGroup(
    key: 'skill',
    label: '스킬',
    rows: [
      for (final (key, label, minimum, maximum) in const [
        ('ex_skill', 'EX', 1, 5),
        ('skill1', '기본', 1, 10),
        ('skill2', '강화', 0, 10),
        ('skill3', '서브', 0, 10),
      ])
        StudentGrowthRangeRow(
          key: key,
          label: label,
          chipLabel: label,
          min: minimum,
          max: maximum,
          style: StudentRangeValueStyle.skill,
          read: (growth) => _growth(growth, key, minimum),
        ),
    ],
  ),
  StudentGrowthRangeGroup(
    key: 'equipment',
    label: '장비 · 능력치',
    rows: [
      StudentGrowthRangeRow(
        key: 'equip_tier',
        label: '장비 티어',
        chipLabel: '장비 티어',
        caption: '3칸 중 가장 낮은 칸',
        min: 0,
        max: 10,
        style: StudentRangeValueStyle.tier,
        read: (growth) =>
            _lowestOf(growth, const ['equip1_tier', 'equip2_tier', 'equip3_tier']),
      ),
      StudentGrowthRangeRow(
        key: 'equip_level',
        label: '장비 레벨',
        chipLabel: '장비 레벨',
        caption: '3칸 중 가장 낮은 칸',
        min: 0,
        max: 70,
        read: (growth) => _lowestOf(growth, const [
          'equip1_level',
          'equip2_level',
          'equip3_level',
        ]),
      ),
      StudentGrowthRangeRow(
        key: 'equip4_tier',
        label: '애장품',
        chipLabel: '애장품',
        min: 0,
        max: 2,
        style: StudentRangeValueStyle.tier,
        read: (growth) => _growth(growth, 'equip4_tier', 0),
      ),
      StudentGrowthRangeRow(
        key: 'stat_sum',
        label: '추가 능력치',
        chipLabel: '추가 능력치',
        caption: 'HP · ATK · HEAL 합',
        min: 0,
        max: studentStatSumMaximum,
        read: (growth) =>
            _growth(growth, 'stat_hp', 0) +
            _growth(growth, 'stat_atk', 0) +
            _growth(growth, 'stat_heal', 0),
      ),
    ],
  ),
];

/// 모든 성장 범위 행(그룹 순서).
List<StudentGrowthRangeRow> get studentGrowthRangeRows => [
  for (final group in studentGrowthRangeGroups) ...group.rows,
];

/// 키로 행을 찾는다. 없으면 null.
StudentGrowthRangeRow? studentGrowthRangeRow(String key) {
  for (final group in studentGrowthRangeGroups) {
    for (final row in group.rows) {
      if (row.key == key) return row;
    }
  }
  return null;
}

/// 심상개화 그룹(FD-054): 데이터가 없어 비활성으로 보이고 조건에는 넣지 않는다.
const studentPotentialFilterLabel = '심상개화';
const studentPotentialFilterChoices = ['상관없음', '개방', '미개방'];

/// 심상개화 자리 설명(시안 `v7 “준비 중” 자리`).
const studentPotentialFilterNote = 'v7 “준비 중” 자리';

/// 좁힌 성장 범위. 좁히지 않은 행(최소~최대 전체)은 조건이 아니다.
@immutable
class StudentGrowthRanges {
  const StudentGrowthRanges._(this._narrowed);

  /// 조건 없음.
  static const none = StudentGrowthRanges._({});

  final Map<String, (int, int)> _narrowed;

  bool get isEmpty => _narrowed.isEmpty;

  /// 좁힌 행 키(그룹·행 순서).
  List<String> get narrowedKeys => [
    for (final row in studentGrowthRangeRows)
      if (_narrowed.containsKey(row.key)) row.key,
  ];

  bool isNarrowed(String key) => _narrowed.containsKey(key);

  /// 이 행의 (최소, 최대). 좁히지 않았으면 행 전체.
  (int, int) bounds(StudentGrowthRangeRow row) =>
      _narrowed[row.key] ?? (row.min, row.max);

  /// [row]를 [low]~[high]로 좁힌다. 범위 밖은 자르고, 순서가 바뀌면 바로잡는다.
  /// 행 전체가 되면 조건을 뺀다.
  StudentGrowthRanges withBounds(StudentGrowthRangeRow row, int low, int high) {
    final a = low.clamp(row.min, row.max);
    final b = high.clamp(row.min, row.max);
    final lo = math.min(a, b);
    final hi = math.max(a, b);
    final next = Map<String, (int, int)>.of(_narrowed);
    if (lo == row.min && hi == row.max) {
      next.remove(row.key);
    } else {
      next[row.key] = (lo, hi);
    }
    return StudentGrowthRanges._(Map.unmodifiable(next));
  }

  /// 한 행의 조건을 뺀다.
  StudentGrowthRanges without(String key) {
    if (!_narrowed.containsKey(key)) return this;
    final next = Map<String, (int, int)>.of(_narrowed)..remove(key);
    return StudentGrowthRanges._(Map.unmodifiable(next));
  }

  /// 학생 성장 값이 좁힌 행을 모두 만족하는가.
  bool matches(Map<String, int> growth) {
    for (final entry in _narrowed.entries) {
      final row = studentGrowthRangeRow(entry.key);
      if (row == null) continue;
      final value = row.read(growth);
      final (low, high) = entry.value;
      if (value < low || value > high) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is StudentGrowthRanges && mapEquals(other._narrowed, _narrowed);

  @override
  int get hashCode => Object.hashAllUnordered(
    _narrowed.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}

// ---------------------------------------------------------------------------
// 속성 그룹

/// 속성 그룹(토글 칩 한 줄). 학생 탭은 [studentCatalogFilterGroups]를 쓰고, 계획 1단계(FE4-b)는
/// 계획 그룹을 더해 넘긴다(FD-104 주입 구조).
class StudentFilterGroup {
  const StudentFilterGroup({
    required this.key,
    required this.label,
    required this.read,
    this.order = const [],
    this.excludedValues = const {},
  });

  final String key;
  final String label;

  /// 학생의 이 그룹 값. 없으면 null(어떤 칩에도 들지 않는다).
  final String? Function(StudentFilterCandidate candidate) read;

  /// 칩 순서(시안 순서). 목록에 없는 값은 뒤에 이름순으로 붙는다.
  final List<String> order;

  /// 칩으로 보이지 않는 값(학교의 협업 학생 등).
  final Set<String> excludedValues;

  /// catalog에 있는 값만 칩으로 만든다(FD-059: 화학처럼 시안에 없는 값도 catalog에 있으면 보인다).
  List<String> valuesIn(Iterable<StudentFilterCandidate> candidates) {
    final present = {
      for (final candidate in candidates)
        if (read(candidate) case final value?)
          if (!excludedValues.contains(value)) value,
    };
    final ordered = [
      for (final value in order)
        if (present.remove(value)) value,
    ];
    final rest = present.toList()
      ..sort(
        (a, b) => studentFilterChipLabel(key, a).compareTo(studentFilterChipLabel(key, b)),
      );
    return [...ordered, ...rest];
  }
}

/// 속성 칩 이름. 초기 성급은 시안대로 `★n`이다.
String studentFilterChipLabel(String key, String value) =>
    key == 'rarity' ? '★$value' : studentFilterValueLabel(key, value);

/// 시안 Student-Filter의 칩 순서(코드 값).
const Map<String, List<String>> studentFilterChipOrders = {
  'school': [
    'Gehenna',
    'Millennium',
    'Trinity',
    'Abydos',
    'Hyakkiyako',
    'Shanhaijing',
    'Red Winter',
    'RedWinter',
    'Valkyrie',
    'Arius',
    'Wild Hunt',
    'Wildhunt',
    'Highlander',
    'SRT',
    'ETC',
    'Etc',
  ],
  'rarity': ['1', '2', '3'],
  'attack_type': ['Explosive', 'Piercing', 'Mystic', 'Sonic', 'Chemical'],
  'defense_type': ['Light', 'Heavy', 'Special', 'Elastic', 'Composite'],
  'combat_class': ['striker', 'special'],
  'role': ['dealer', 'tanker', 'healer', 'supporter', 't_s'],
  'position': ['front', 'middle', 'back'],
};

/// 학생 탭 속성 그룹 7개(학교 · 초기 성급 · 공격 · 방어 · 편성 · 역할 · 포지션).
List<StudentFilterGroup> get studentCatalogFilterGroups => [
  for (final definition in studentFilterDefinitions)
    StudentFilterGroup(
      key: definition.key,
      label: definition.label,
      read: (candidate) => definition.read(candidate.student),
      order: studentFilterChipOrders[definition.key] ?? const [],
      excludedValues: definition.key == 'school'
          ? const {'Sakugawa', 'Tokiwadai'}
          : const {},
    ),
];

// ---------------------------------------------------------------------------
// 후보 · 선택

/// 필터를 거는 학생 한 명(속성 + 보유 + 현재 성장 값).
@immutable
class StudentFilterCandidate {
  const StudentFilterCandidate({
    required this.student,
    required this.owned,
    required this.growth,
  });

  /// 현재 값(`ConfirmedStudentState.values`)에서 성장 값을 만든다. 미보유면 초기 값이다.
  factory StudentFilterCandidate.fromValues({
    required StudentCatalogEntry student,
    required bool owned,
    required Map<String, dynamic> currentValues,
  }) => StudentFilterCandidate(
    student: student,
    owned: owned,
    growth: planElementCurrentTargets(
      PlanningStudentSeed(
        handoffId: 'student-filter-${student.studentId}',
        studentId: student.studentId,
        metadata: student.metadata,
        currentValues: currentValues,
        owned: owned,
      ),
    ),
  );

  final StudentCatalogEntry student;
  final bool owned;
  final Map<String, int> growth;
}

/// "보유 · 서버" 그룹 키와 값(FD-057).
const studentOwnershipGroupKey = 'ownership';
const studentOwnedValue = 'owned';
const studentUnownedValue = 'unowned';
const studentExcludeJpOnlyValue = 'exclude_jp_only';

/// "보유 · 서버" 칩 이름.
const Map<String, String> studentOwnershipChipLabels = {
  studentOwnedValue: '보유',
  studentUnownedValue: '미보유',
  studentExcludeJpOnlyValue: '일본 서버 전용 제외',
};

/// 성장 범위 조건 묶음 키(칩 개수 셀 때 "같은 그룹").
const studentGrowthRangeGroupKey = 'growth';

/// 적용 필터 칩 하나(모달 머리 칩, S4 적용 필터 칩).
@immutable
class StudentFilterChipItem {
  const StudentFilterChipItem({
    required this.groupKey,
    required this.value,
    required this.label,
  });

  /// 속성 그룹 키, [studentOwnershipGroupKey], 또는 [studentGrowthRangeGroupKey].
  final String groupKey;

  /// 속성 값, 보유 값, 또는 성장 범위 행 키.
  final String value;
  final String label;

  bool get isRange => groupKey == studentGrowthRangeGroupKey;

  /// 위젯 키에 쓰는 식별자.
  String get id => '$groupKey-$value';

  @override
  bool operator ==(Object other) =>
      other is StudentFilterChipItem &&
      other.groupKey == groupKey &&
      other.value == value &&
      other.label == label;

  @override
  int get hashCode => Object.hash(groupKey, value, label);
}

/// 필터 선택 값(불변). 적용 값과 초안이 이 값이다.
@immutable
class StudentFilterSelection {
  StudentFilterSelection({
    Map<String, Set<String>> catalog = const {},
    Set<String> ownership = const {},
    this.excludeJpOnly = false,
    this.ranges = StudentGrowthRanges.none,
  }) : catalog = Map.unmodifiable({
         for (final entry in catalog.entries)
           if (entry.value.isNotEmpty) entry.key: Set<String>.unmodifiable(entry.value),
       }),
       ownership = Set.unmodifiable(
         ownership.where(
           (value) => value == studentOwnedValue || value == studentUnownedValue,
         ),
       );

  /// 조건 없음.
  static final empty = StudentFilterSelection();

  /// 속성 그룹 키 → 고른 값(빈 그룹은 없다).
  final Map<String, Set<String>> catalog;

  /// 보유·미보유 중 고른 것(또는). 비면 조건 없음.
  final Set<String> ownership;

  /// 일본 서버 전용 학생 제외.
  final bool excludeJpOnly;
  final StudentGrowthRanges ranges;

  bool get isEmpty =>
      catalog.isEmpty && ownership.isEmpty && !excludeJpOnly && ranges.isEmpty;

  /// S4 "미보유 학생 숨김"(FD-057): 보유만 고른 상태.
  bool get hidesUnowned =>
      ownership.length == 1 && ownership.contains(studentOwnedValue);

  /// S4 "일본 서버 전용 숨김"(FD-057).
  bool get hidesJpOnly => excludeJpOnly;

  bool isSelected(String groupKey, String value) {
    if (groupKey == studentOwnershipGroupKey) {
      return value == studentExcludeJpOnlyValue
          ? excludeJpOnly
          : ownership.contains(value);
    }
    if (groupKey == studentGrowthRangeGroupKey) return ranges.isNarrowed(value);
    return catalog[groupKey]?.contains(value) ?? false;
  }

  StudentFilterSelection copyWith({
    Map<String, Set<String>>? catalog,
    Set<String>? ownership,
    bool? excludeJpOnly,
    StudentGrowthRanges? ranges,
  }) => StudentFilterSelection(
    catalog: catalog ?? this.catalog,
    ownership: ownership ?? this.ownership,
    excludeJpOnly: excludeJpOnly ?? this.excludeJpOnly,
    ranges: ranges ?? this.ranges,
  );

  /// 칩 하나를 켜고 끈다(속성·보유 · 서버).
  StudentFilterSelection toggle(String groupKey, String value) {
    if (groupKey == studentOwnershipGroupKey) {
      if (value == studentExcludeJpOnlyValue) {
        return copyWith(excludeJpOnly: !excludeJpOnly);
      }
      final next = {...ownership};
      next.contains(value) ? next.remove(value) : next.add(value);
      return copyWith(ownership: next);
    }
    final values = {...?catalog[groupKey]};
    values.contains(value) ? values.remove(value) : values.add(value);
    return copyWith(catalog: {...catalog, groupKey: values});
  }

  /// S4 "미보유 학생 숨김"을 켜고 끈다(FD-057). 켜면 보유만, 끄면 보유 조건을 푼다.
  StudentFilterSelection withHideUnowned(bool hide) {
    if (hide) return copyWith(ownership: const {studentOwnedValue});
    return hidesUnowned ? copyWith(ownership: const {}) : this;
  }

  /// S4 "일본 서버 전용 숨김"을 켜고 끈다(FD-057).
  StudentFilterSelection withHideJpOnly(bool hide) =>
      copyWith(excludeJpOnly: hide);

  /// 성장 범위 한 행을 바꾼다.
  StudentFilterSelection withRange(
    StudentGrowthRangeRow row,
    int low,
    int high,
  ) => copyWith(ranges: ranges.withBounds(row, low, high));

  /// 적용 칩 하나를 뺀다(칩의 ×).
  StudentFilterSelection without(StudentFilterChipItem item) {
    if (item.isRange) return copyWith(ranges: ranges.without(item.value));
    if (!isSelected(item.groupKey, item.value)) return this;
    return toggle(item.groupKey, item.value);
  }

  /// 속성·성장 범위만 지운다. 보유 · 서버(S4 토글과 같은 상태)는 남긴다.
  StudentFilterSelection clearedKeepingOwnership() => StudentFilterSelection(
    ownership: ownership,
    excludeJpOnly: excludeJpOnly,
  );

  /// 성장 범위만 모두 푼다(시안 "범위 모두 풀기").
  StudentFilterSelection clearedRanges() =>
      copyWith(ranges: StudentGrowthRanges.none);

  /// 이 학생이 조건을 모두 만족하는가. [exceptGroup]의 조건은 보지 않는다(칩 개수용, FD-056).
  bool matches(
    StudentFilterCandidate candidate,
    List<StudentFilterGroup> groups, {
    String? exceptGroup,
  }) {
    for (final group in groups) {
      if (group.key == exceptGroup) continue;
      final values = catalog[group.key];
      if (values == null) continue;
      final value = group.read(candidate);
      if (value == null || !values.contains(value)) return false;
    }
    if (exceptGroup != studentOwnershipGroupKey) {
      if (ownership.isNotEmpty &&
          !ownership.contains(
            candidate.owned ? studentOwnedValue : studentUnownedValue,
          )) {
        return false;
      }
      if (excludeJpOnly && candidate.student.jpOnly) return false;
    }
    if (exceptGroup != studentGrowthRangeGroupKey &&
        !ranges.matches(candidate.growth)) {
      return false;
    }
    return true;
  }

  /// 조건을 만족하는 학생 수(시안 머리 "38 / 170명", 적용 전 미리보기).
  int countMatching(
    Iterable<StudentFilterCandidate> candidates,
    List<StudentFilterGroup> groups,
  ) => candidates.where((candidate) => matches(candidate, groups)).length;

  /// 토글 칩 옆 학생 수(FD-056 (a)): 같은 그룹 조건을 빼고 다른 그룹 조건만 반영해, 이 값에 드는 학생을 센다.
  int chipCount(
    Iterable<StudentFilterCandidate> candidates,
    List<StudentFilterGroup> groups,
    String groupKey,
    String value,
  ) {
    bool hasValue(StudentFilterCandidate candidate) {
      if (groupKey == studentOwnershipGroupKey) {
        return switch (value) {
          studentOwnedValue => candidate.owned,
          studentUnownedValue => !candidate.owned,
          _ => !candidate.student.jpOnly,
        };
      }
      for (final group in groups) {
        if (group.key == groupKey) return group.read(candidate) == value;
      }
      return false;
    }

    return candidates
        .where(
          (candidate) =>
              hasValue(candidate) &&
              matches(candidate, groups, exceptGroup: groupKey),
        )
        .length;
  }

  /// 적용 칩 목록: 속성(그룹 순서, 칩 순서) → 보유 · 서버 → 성장 범위(행 순서).
  List<StudentFilterChipItem> chips(List<StudentFilterGroup> groups) => [
    for (final group in groups)
      if (catalog[group.key] case final values?)
        for (final value in _ordered(group, values))
          StudentFilterChipItem(
            groupKey: group.key,
            value: value,
            label: studentFilterChipLabel(group.key, value),
          ),
    for (final value in const [studentOwnedValue, studentUnownedValue])
      if (ownership.contains(value))
        StudentFilterChipItem(
          groupKey: studentOwnershipGroupKey,
          value: value,
          label: studentOwnershipChipLabels[value]!,
        ),
    if (excludeJpOnly)
      StudentFilterChipItem(
        groupKey: studentOwnershipGroupKey,
        value: studentExcludeJpOnlyValue,
        label: studentOwnershipChipLabels[studentExcludeJpOnlyValue]!,
      ),
    for (final key in ranges.narrowedKeys)
      if (studentGrowthRangeRow(key) case final row?)
        StudentFilterChipItem(
          groupKey: studentGrowthRangeGroupKey,
          value: key,
          label: () {
            final (low, high) = ranges.bounds(row);
            return row.chipText(low, high);
          }(),
        ),
  ];

  /// 걸린 조건 수("필터 · n", FD-058).
  int activeCount(List<StudentFilterGroup> groups) => chips(groups).length;

  static List<String> _ordered(StudentFilterGroup group, Set<String> values) {
    final ordered = [
      for (final value in group.order)
        if (values.contains(value)) value,
    ];
    final rest =
        values.where((value) => !group.order.contains(value)).toList()..sort();
    return [...ordered, ...rest];
  }

  @override
  bool operator ==(Object other) =>
      other is StudentFilterSelection &&
      other.excludeJpOnly == excludeJpOnly &&
      other.ranges == ranges &&
      setEquals(other.ownership, ownership) &&
      other.catalog.length == catalog.length &&
      catalog.entries.every(
        (entry) => setEquals(other.catalog[entry.key], entry.value),
      );

  @override
  int get hashCode => Object.hash(
    excludeJpOnly,
    ranges,
    Object.hashAllUnordered(ownership),
    Object.hashAllUnordered(
      catalog.entries.map(
        (entry) => Object.hash(entry.key, Object.hashAllUnordered(entry.value)),
      ),
    ),
  );
}
