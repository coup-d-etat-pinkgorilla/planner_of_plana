// 학생 그리드 필터 상태 (FE3-c).
//
// 학생 탭 페이지가 하나를 소유하고 S4(표시 토글·적용 필터 칩·결과 수)와 필터 화면(지금은 Section 5와
// 범위 카드, FE3-d부터 필터 모달)이 함께 읽고 바꾼다.
// - S4 "미보유 학생 숨김"·"일본 서버 전용 숨김"과 필터 팝업의 "보유 · 서버" 그룹은 같은 상태 하나다(FD-057).
// - 적용 필터 칩은 속성 조건과 범위 조건(레벨 70~90 등)을 함께 보인다(FD-060).
import 'package:flutter/foundation.dart';

import '../widgets/student_range_condition_section.dart';
import 'planning_growth_rules.dart';

/// 범위 조건 칩에 쓰는 짧은 이름(시안 팝업 헤더 "레벨 70~90", "EX 3~5").
const Map<String, String> studentRangeChipLabels = {
  'level': '레벨',
  'bond_rank': '인연',
  'student_star': '성급',
  'weapon_level': '전무 레벨',
  'weapon_star': '전무 성급',
  'ex_skill': 'EX',
  'skill1': '기본',
  'skill2': '강화',
  'skill3': '서브',
  'equip1_tier': '장비1 티어',
  'equip2_tier': '장비2 티어',
  'equip3_tier': '장비3 티어',
  'equip1_level': '장비1 레벨',
  'equip2_level': '장비2 레벨',
  'equip3_level': '장비3 레벨',
  'equip4_tier': '애장품',
  'stat_hp': 'HP',
  'stat_atk': 'ATK',
  'stat_heal': 'HEAL',
};

/// 적용 필터 칩 하나.
@immutable
class StudentAppliedFilter {
  const StudentAppliedFilter.catalog({
    required this.key,
    required String value,
    required this.label,
  }) : catalogValue = value,
       rangeKey = null;

  const StudentAppliedFilter.range({required this.key, required this.label})
    : rangeKey = key,
      catalogValue = null;

  /// 속성 조건이면 필터 키(`school` 등), 범위 조건이면 목표 키(`level` 등).
  final String key;

  /// 속성 조건 값. 범위 조건이면 null.
  final String? catalogValue;

  /// 범위 조건 키. 속성 조건이면 null.
  final String? rangeKey;
  final String label;

  bool get isRange => rangeKey != null;

  /// 위젯 키에 쓰는 식별자.
  String get id => isRange ? 'range-$key' : '$key-$catalogValue';

  @override
  bool operator ==(Object other) =>
      other is StudentAppliedFilter &&
      other.key == key &&
      other.catalogValue == catalogValue &&
      other.rangeKey == rangeKey &&
      other.label == label;

  @override
  int get hashCode => Object.hash(key, catalogValue, rangeKey, label);
}

/// 학생 그리드 필터 상태. 바뀌면 알린다.
class StudentFilterController extends ChangeNotifier {
  StudentFilterController({Iterable<String> catalogKeys = const []})
    : _catalog = {for (final key in catalogKeys) key: <String>{}};

  final Map<String, Set<String>> _catalog;
  bool _hideUnowned = false;
  bool _hideJpOnly = false;
  StudentRangeConditions _range = StudentRangeConditions.initial();

  /// 속성 조건(키 → 고른 값). 바꾸려면 [toggleCatalog]·[clearCatalog]를 쓴다.
  Map<String, Set<String>> get catalog => {
    for (final entry in _catalog.entries)
      entry.key: Set.unmodifiable(entry.value),
  };

  /// 미보유 학생 숨김(S4 토글 = 팝업 "보유 · 서버", FD-057).
  bool get hideUnowned => _hideUnowned;

  /// 일본 서버 전용 숨김(S4 토글 = 팝업 "보유 · 서버", FD-057).
  bool get hideJpOnly => _hideJpOnly;

  /// 범위 조건(지금은 Section 5 옆 범위 카드, FE3-d부터 필터 모달).
  StudentRangeConditions get range => _range;

  bool isCatalogSelected(String key, String value) =>
      _catalog[key]?.contains(value) ?? false;

  void toggleCatalog(String key, String value) {
    final values = _catalog.putIfAbsent(key, () => <String>{});
    values.contains(value) ? values.remove(value) : values.add(value);
    notifyListeners();
  }

  void clearCatalog() {
    if (_catalog.values.every((values) => values.isEmpty)) return;
    for (final values in _catalog.values) {
      values.clear();
    }
    notifyListeners();
  }

  set hideUnowned(bool value) {
    if (value == _hideUnowned) return;
    _hideUnowned = value;
    notifyListeners();
  }

  set hideJpOnly(bool value) {
    if (value == _hideJpOnly) return;
    _hideJpOnly = value;
    notifyListeners();
  }

  set range(StudentRangeConditions value) {
    _range = value;
    notifyListeners();
  }

  /// 범위 조건을 처음 상태로 되돌린다(Section 5를 닫을 때의 기존 동작, FE3-d 전까지 유지).
  void resetRange() => range = StudentRangeConditions.initial();

  /// 범위 조건 한 항목을 최소~최대(조건 없음)로 되돌린다.
  void clearRangeKey(String key) {
    final minimum = planElementTargetMinimums[key];
    final maximum = planElementTargetMaximums[key];
    if (minimum == null || maximum == null) return;
    range = _range.copyWith(
      lowerTargets: {..._range.lowerTargets, key: minimum},
      upperTargets: {..._range.upperTargets, key: maximum},
    );
  }

  /// "모두 지우기": 적용 필터 칩으로 보이는 조건(속성·범위)을 모두 지운다. S4 토글은 그대로 둔다.
  void clearApplied() {
    for (final values in _catalog.values) {
      values.clear();
    }
    _range = StudentRangeConditions.initial();
    notifyListeners();
  }

  /// 이 항목의 범위 조건 (최소, 최대). 조건이 없으면 null.
  (int, int)? rangeBounds(String key) {
    final minimum = planElementTargetMinimums[key];
    final maximum = planElementTargetMaximums[key];
    if (minimum == null || maximum == null) return null;
    final low = _range.lowerEnabled
        ? (_range.lowerTargets[key] ?? minimum)
        : minimum;
    final high = _range.upperEnabled
        ? (_range.upperTargets[key] ?? maximum)
        : maximum;
    if (low <= minimum && high >= maximum) return null;
    return (low, high);
  }

  /// 적용 필터 칩 목록: 속성 조건(필터 정의 순서, 값 이름순) 다음 범위 조건(목표 키 순서).
  List<StudentAppliedFilter> appliedFilters({
    required String Function(String key, String value) catalogLabel,
  }) => [
    for (final entry in _catalog.entries)
      for (final value in (entry.value.toList()..sort()))
        StudentAppliedFilter.catalog(
          key: entry.key,
          value: value,
          label: catalogLabel(entry.key, value),
        ),
    for (final key in planElementTargetMinimums.keys)
      if (rangeBounds(key) case (final low, final high))
        StudentAppliedFilter.range(
          key: key,
          label: '${studentRangeChipLabels[key] ?? key} $low~$high',
        ),
  ];

  /// 칩 하나를 뺀다(칩의 ×).
  void removeApplied(StudentAppliedFilter filter) {
    final rangeKey = filter.rangeKey;
    if (rangeKey != null) {
      clearRangeKey(rangeKey);
      return;
    }
    final value = filter.catalogValue;
    if (value == null) return;
    if (_catalog[filter.key]?.remove(value) ?? false) notifyListeners();
  }
}
