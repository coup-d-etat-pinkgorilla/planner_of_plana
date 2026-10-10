// 시나리오 목록 v2 상태(FE5-a, 시안 Scenario-List, D 보고서 §1-2·§1-5, FD-084).
//
// 목록 요약(`repository.scenario.list`)만으로 정렬 · 필터 · 검색 · 오래된 개수를 계산한다(클라이언트 처리, D §1-5).
// - 정렬 4종(시안 seg): 최근 수정 · 부족 적은 순 · 크레딧 적은 순 · 이름. 계산 요약이 없는 시나리오는 부족·크레딧
//   정렬에서 맨 뒤다(모르는 값을 0으로 보지 않는다). 같으면 최근 수정 → 이름 → id 순이다.
// - 필터: "현재 데이터 기준만"(저장 기준 프로필 revision이 지금 revision과 같은 것), 학생 한 명(그 학생이 들어 있는
//   시나리오), 이름·설명 검색(대소문자 무시, 앞뒤 공백 무시).
// - 오래된 시나리오 = 저장 기준 프로필 revision < 지금 프로필 revision(`PlanningScenarioRecord.isStaleAgainst`와 같은 식).
// - 비교 담기(FD-084): 슬롯 A는 활성 계획 고정(뺄 수 없음), B~D에 시나리오를 담은 순서대로 둔다(최대 3개 = 모두 4).
//   목록을 다시 읽어 없어진 시나리오는 슬롯에서 빠진다.
// - 펼친 행: 한 번에 하나. 펼친 행 = 고른 행(미리보기 대상, FE5-b)이다.
import 'package:flutter/foundation.dart';

import '../../services/scenario_service.dart';

/// 목록 정렬(시안 seg 순서).
enum PlanScenarioSort {
  recent('최근 수정'),
  shortage('부족 적은 순'),
  credits('크레딧 적은 순'),
  name('이름');

  const PlanScenarioSort(this.label);

  final String label;
}

/// 비교에 담을 수 있는 시나리오 수(슬롯 B~D). 슬롯 A(활성 계획)를 더하면 [planScenarioCompareCapacity]다.
const planScenarioCompareScenarioCapacity = 3;

/// 비교할 계획 최대 수(시안 "비교할 계획 n / 4").
const planScenarioCompareCapacity = planScenarioCompareScenarioCapacity + 1;

/// 슬롯 글자(A = 활성 계획).
const planScenarioCompareSlotLetters = ['A', 'B', 'C', 'D'];

/// 시나리오가 지금 프로필 revision보다 오래된 데이터로 저장되었는가.
bool planScenarioIsStale(
  PlanningScenarioSummary scenario,
  int currentProfileRevision,
) => scenario.baseProfileRevision < currentProfileRevision;

/// 오래된 시나리오 수(시안 "오래된 시나리오 n개").
int planScenarioStaleCount(
  Iterable<PlanningScenarioSummary> scenarios,
  int currentProfileRevision,
) => scenarios
    .where((scenario) => planScenarioIsStale(scenario, currentProfileRevision))
    .length;

/// 검색어가 이름·설명에 들어 있는가(대소문자 무시). 빈 검색어는 모두 맞는다.
bool planScenarioMatchesQuery(PlanningScenarioSummary scenario, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  return scenario.name.toLowerCase().contains(needle) ||
      scenario.description.toLowerCase().contains(needle);
}

DateTime? _updatedAt(PlanningScenarioSummary scenario) =>
    DateTime.tryParse(scenario.updatedAt);

/// 최근 수정이 앞. 시각을 읽지 못하면 뒤로 보내고 문자열로 비교한다.
int _compareRecent(PlanningScenarioSummary a, PlanningScenarioSummary b) {
  final left = _updatedAt(a);
  final right = _updatedAt(b);
  if (left != null && right != null) {
    final byTime = right.compareTo(left);
    if (byTime != 0) return byTime;
  } else if (left != null) {
    return -1;
  } else if (right != null) {
    return 1;
  }
  return b.updatedAt.compareTo(a.updatedAt);
}

/// 값이 작은 쪽이 앞, 모르는 값(null)은 맨 뒤.
int _compareKnownAscending(int? left, int? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

/// [sort] 기준 비교. 같으면 최근 수정 → 이름 → id 순이다.
int planScenarioCompare(
  PlanningScenarioSummary a,
  PlanningScenarioSummary b,
  PlanScenarioSort sort,
) {
  final primary = switch (sort) {
    PlanScenarioSort.recent => _compareRecent(a, b),
    PlanScenarioSort.shortage => _compareKnownAscending(
      a.calculation?.knownShortageTypeCount,
      b.calculation?.knownShortageTypeCount,
    ),
    PlanScenarioSort.credits => _compareKnownAscending(
      a.calculation?.credits,
      b.calculation?.credits,
    ),
    PlanScenarioSort.name => a.name.compareTo(b.name),
  };
  if (primary != 0) return primary;
  if (sort != PlanScenarioSort.recent) {
    final recent = _compareRecent(a, b);
    if (recent != 0) return recent;
  }
  final byName = a.name.compareTo(b.name);
  if (byName != 0) return byName;
  return a.id.compareTo(b.id);
}

/// 목록에 보일 시나리오(필터 → 정렬).
List<PlanningScenarioSummary> planScenarioVisible(
  Iterable<PlanningScenarioSummary> scenarios, {
  required int currentProfileRevision,
  required PlanScenarioSort sort,
  bool currentOnly = false,
  String? studentId,
  String query = '',
}) {
  final visible = [
    for (final scenario in scenarios)
      if ((!currentOnly ||
              !planScenarioIsStale(scenario, currentProfileRevision)) &&
          (studentId == null || scenario.studentIds.contains(studentId)) &&
          planScenarioMatchesQuery(scenario, query))
        scenario,
  ];
  visible.sort((a, b) => planScenarioCompare(a, b, sort));
  return visible;
}

/// 시나리오들에 들어 있는 학생(처음 나온 순서). 학생 필터 메뉴가 쓴다.
List<String> planScenarioStudentIds(
  Iterable<PlanningScenarioSummary> scenarios,
) {
  final seen = <String>{};
  return [
    for (final scenario in scenarios)
      for (final id in scenario.studentIds)
        if (seen.add(id)) id,
  ];
}

/// 비교 담기 결과.
enum PlanScenarioCompareToggle { added, removed, full }

/// 시나리오 목록 화면 상태: 정렬 · 필터 · 검색 · 펼친 행 · 비교 슬롯.
///
/// 목록 자체(서비스 응답)는 화면이 들고 있고, 다시 읽을 때 [retainExisting]으로 없어진 시나리오를 정리한다.
class PlanScenarioListController extends ChangeNotifier {
  PlanScenarioSort _sort = PlanScenarioSort.recent;
  bool _currentOnly = false;
  String? _studentId;
  String _query = '';
  String? _expandedId;
  List<String> _compareIds = const [];
  bool _disposed = false;

  PlanScenarioSort get sort => _sort;
  bool get currentOnly => _currentOnly;

  /// 학생 필터(null = 전체).
  String? get studentId => _studentId;
  String get query => _query;

  /// 펼친 행(= 고른 행). 없으면 null.
  String? get expandedId => _expandedId;

  /// 슬롯 B~D에 담은 시나리오(담은 순서).
  List<String> get compareIds => _compareIds;

  /// 비교할 계획 수(슬롯 A 포함).
  int get compareCount => _compareIds.length + 1;

  bool isCompared(String scenarioId) => _compareIds.contains(scenarioId);

  /// 필터가 하나라도 걸려 있는가(빈 목록 안내 문구를 고른다).
  bool get filtering =>
      _currentOnly || _studentId != null || _query.trim().isNotEmpty;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void setSort(PlanScenarioSort value) {
    if (value == _sort) return;
    _sort = value;
    _changed();
  }

  void setCurrentOnly(bool value) {
    if (value == _currentOnly) return;
    _currentOnly = value;
    _changed();
  }

  void setStudent(String? value) {
    if (value == _studentId) return;
    _studentId = value;
    _changed();
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    _changed();
  }

  /// 필터 · 검색을 모두 푼다(정렬은 둔다).
  void clearFilters() {
    if (!filtering) return;
    _currentOnly = false;
    _studentId = null;
    _query = '';
    _changed();
  }

  /// 행을 펼친다. 이미 펼친 행이면 접는다.
  void toggleExpanded(String scenarioId) {
    _expandedId = _expandedId == scenarioId ? null : scenarioId;
    _changed();
  }

  void expand(String? scenarioId) {
    if (_expandedId == scenarioId) return;
    _expandedId = scenarioId;
    _changed();
  }

  /// 비교에 담거나 뺀다. 슬롯이 다 찼으면 담지 않고 [PlanScenarioCompareToggle.full]이다.
  PlanScenarioCompareToggle toggleCompare(String scenarioId) {
    if (_compareIds.contains(scenarioId)) {
      _compareIds = List.unmodifiable([
        for (final id in _compareIds)
          if (id != scenarioId) id,
      ]);
      _changed();
      return PlanScenarioCompareToggle.removed;
    }
    if (_compareIds.length >= planScenarioCompareScenarioCapacity) {
      return PlanScenarioCompareToggle.full;
    }
    _compareIds = List.unmodifiable([..._compareIds, scenarioId]);
    _changed();
    return PlanScenarioCompareToggle.added;
  }

  /// 목록을 다시 읽은 뒤 없어진 시나리오를 펼침 · 비교 · 학생 필터에서 뺀다.
  void retainExisting(Iterable<PlanningScenarioSummary> scenarios) {
    final ids = {for (final scenario in scenarios) scenario.id};
    final students = planScenarioStudentIds(scenarios).toSet();
    var changed = false;
    if (_expandedId != null && !ids.contains(_expandedId)) {
      _expandedId = null;
      changed = true;
    }
    final kept = [
      for (final id in _compareIds)
        if (ids.contains(id)) id,
    ];
    if (kept.length != _compareIds.length) {
      _compareIds = List.unmodifiable(kept);
      changed = true;
    }
    if (_studentId != null && !students.contains(_studentId)) {
      _studentId = null;
      changed = true;
    }
    if (changed) _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
