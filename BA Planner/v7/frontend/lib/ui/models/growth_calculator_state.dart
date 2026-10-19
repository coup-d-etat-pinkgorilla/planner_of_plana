// 성장 계산기 상태 (FE3-f1, FD-166·FD-167·FD-168·FD-169·FD-170).
//
// 학생 한 명의 계산기 목표를 들고 있다. 화면 연결은 FE3-f2가 한다.
// - 목표는 어디에도 저장하지 않는다. 학생 탭 인연 게이지의 활성 계획 목표(FD-049)와도 섞지 않는다.
// - 현재값 출처(FD-168): 확정값 = repository 학생 상태(미보유 학생은 계획 요소 빌더와 같은 기본값),
//   직접 입력 = 현재값을 고칠 수 있는 휘발 상태. 직접 입력은 저장하지 않고 미보유 학생도 계산한다.
// - 행 규칙과 정규화는 `growth_calculator_rules.dart`에 있다.
// - 최근 계산(FD-170)은 [RecentGrowthCalculations]다. 최근 본 학생(FD-061)과 같은 수명이다.
import 'package:flutter/foundation.dart';

import 'growth_calculator_rules.dart';
import 'planning_growth_rules.dart';

/// 현재값 출처(FD-168, 시안 S1 "확정값 기준 / 직접 입력").
enum GrowthCalculatorBasis {
  confirmed('확정값'),
  direct('직접 입력');

  const GrowthCalculatorBasis(this.label);

  final String label;
}

/// 성장 계산기 한 명의 상태.
///
/// [confirmedCurrent]는 19 key 현재값이다. FE3-f2는 `planElementCurrentTargets(seed)`(계획 요소 빌더와
/// 같은 변환, 미보유면 기본값)를 넘긴다. [initialTargets]가 없으면 목표는 현재값에서 시작한다.
class GrowthCalculatorState extends ChangeNotifier {
  GrowthCalculatorState({
    required this.studentId,
    required Map<String, int> confirmedCurrent,
    required this.hasFavoriteItem,
    GrowthCalculatorBasis basis = GrowthCalculatorBasis.confirmed,
    Map<String, int>? initialTargets,
  }) : _activeBasis = basis,
       _confirmedCurrent = growthCalculatorCurrent(
         confirmedCurrent,
         hasFavoriteItem: hasFavoriteItem,
       ) {
    if (basis == GrowthCalculatorBasis.direct) {
      _directCurrent = _confirmedCurrent;
    }
    _targets = normalizeGrowthCalculatorTargets(
      current: current,
      targets: initialTargets ?? current,
      hasFavoriteItem: hasFavoriteItem,
    );
    _initialTargets = _targets;
  }

  final String studentId;
  final bool hasFavoriteItem;

  GrowthCalculatorBasis _activeBasis;
  Map<String, int> _confirmedCurrent;
  Map<String, int>? _directCurrent;
  late Map<String, int> _targets;
  late Map<String, int> _initialTargets;
  final Map<GrowthCalculatorRow, Map<String, int>> _toggleMemory = {};

  /// 지금 현재값 출처.
  GrowthCalculatorBasis get basis => _activeBasis;

  /// 확정값(repository) 현재값.
  Map<String, int> get confirmedCurrent => _confirmedCurrent;

  /// 지금 출처의 현재값(19 key). 목표의 하한이다.
  Map<String, int> get current =>
      _activeBasis == GrowthCalculatorBasis.direct
          ? _directCurrent ?? _confirmedCurrent
          : _confirmedCurrent;

  /// 계산기 목표(19 key). 정규화된 값이라 계획 성장 규칙에 맞는다.
  Map<String, int> get targets => _targets;

  /// 이 계산기를 열 때의 목표(되돌리기의 "원래 값"). 보통은 현재값이고, 최근 계산에서 다시 열면
  /// 그때의 목표다.
  Map<String, int> get initialTargets => _initialTargets;

  /// 이 학생에게 쓰는 행(13행, 애장품이 없는 학생은 12행).
  List<GrowthCalculatorRow> get rows =>
      growthCalculatorRows(hasFavoriteItem: hasFavoriteItem);

  /// 이 학생에게 쓰는 MAX.
  Map<String, int> get maximums =>
      growthCalculatorTargetMaximums(hasFavoriteItem: hasFavoriteItem);

  bool isRowAvailable(GrowthCalculatorRow row) =>
      growthCalculatorRowAvailable(row, hasFavoriteItem: hasFavoriteItem);

  /// [row]의 목표 스테퍼 값(장비는 티어, 전용무기는 ★, 능력 개방은 세 값 합).
  int rowTarget(GrowthCalculatorRow row) =>
      growthCalculatorRowValue(_targets, row);

  /// [row]의 현재 스테퍼 값. 목표 스테퍼의 하한이다.
  int rowCurrent(GrowthCalculatorRow row) =>
      growthCalculatorRowValue(current, row);

  /// [row]의 목표 스테퍼 상한.
  int rowMaximum(GrowthCalculatorRow row) =>
      growthCalculatorRowValue(maximums, row);

  int abilityTarget(GrowthCalculatorAbility ability) => _targets[ability.key]!;

  int abilityCurrent(GrowthCalculatorAbility ability) => current[ability.key]!;

  /// [row] 목표가 현재값과 다른가(S3 분홍 칸).
  bool isRowChanged(GrowthCalculatorRow row) =>
      isRowAvailable(row) && growthCalculatorRowChanged(current, _targets, row);

  /// [row] 목표가 처음 값([initialTargets])과 다른가(되돌리기 버튼).
  bool isRowModified(GrowthCalculatorRow row) => row.keys.any(
    (key) => _targets[key] != _initialTargetFor(key),
  );

  /// 칸을 누르면 바뀌는가(FD-167). 현재값과 다르거나, 현재값으로 돌린 뒤 직전 목표가 남아 있을 때.
  bool canToggleRow(GrowthCalculatorRow row) =>
      isRowAvailable(row) &&
      (isRowChanged(row) || _toggleMemory.containsKey(row));

  /// "바뀌는 칸 n · 그대로 m"(FD-167).
  GrowthCalculatorCellCounts get cellCounts => growthCalculatorCellCounts(
    current,
    _targets,
    hasFavoriteItem: hasFavoriteItem,
  );

  /// "바뀐 목표" 목록(행 단위).
  List<GrowthCalculatorChange> get changes => growthCalculatorChanges(
    current,
    _targets,
    hasFavoriteItem: hasFavoriteItem,
  );

  /// "바뀐 목표" 칩(시안 "레벨 +20 · 성급 +2 · …").
  List<GrowthCalculatorChangeChip> get changeChips =>
      growthCalculatorChangeChips(
        current,
        _targets,
        hasFavoriteItem: hasFavoriteItem,
      );

  /// 최근 계산에 넣을 기록(학생 + 기준 + 목표, FD-170).
  GrowthCalculationRecord get record => GrowthCalculationRecord(
    studentId: studentId,
    basis: _activeBasis,
    targets: _targets,
  );

  /// [row] 목표 스테퍼를 [value]로 둔다. 능력 개방 행은 [setAbilityTarget]을 쓴다.
  void setRowTarget(GrowthCalculatorRow row, int value) {
    _requireAvailable(row);
    _toggleMemory.remove(row);
    _setTargets(
      growthCalculatorWithRow(
        current: current,
        targets: _targets,
        row: row,
        value: value,
        hasFavoriteItem: hasFavoriteItem,
      ),
    );
  }

  /// 능력 개방 [ability] 목표를 [value]로 둔다.
  void setAbilityTarget(GrowthCalculatorAbility ability, int value) {
    _toggleMemory.remove(GrowthCalculatorRow.abilityRelease);
    _setTargets(
      growthCalculatorWithAbility(
        current: current,
        targets: _targets,
        ability: ability,
        value: value,
        hasFavoriteItem: hasFavoriteItem,
      ),
    );
  }

  /// 빠른 목표를 고른다(FD-169). 고른 행은 MAX, 나머지는 현재값.
  void applyQuickTarget(GrowthCalculatorQuickTarget quickTarget) {
    _toggleMemory.clear();
    _setTargets(
      growthCalculatorQuickTargets(
        current: current,
        quickTarget: quickTarget,
        hasFavoriteItem: hasFavoriteItem,
      ),
    );
  }

  /// 빠른 목표의 단계 프리셋 항목을 고른다(FD-169 (a), FE4-i). 프리셋 마지막 단계가 정한 목표만 올린다.
  void applyPresetTarget(GrowthCalculatorPresetTarget preset) {
    _toggleMemory.clear();
    _setTargets(
      growthCalculatorPresetTargets(
        current: current,
        presetTargets: preset.targets,
        hasFavoriteItem: hasFavoriteItem,
      ),
    );
  }

  /// S3 칸 토글(FD-167): 목표가 현재값과 다르면 현재값으로 두고 직전 목표를 기억한다. 현재값과 같고
  /// 기억한 직전 목표가 있으면 그 목표로 돌린다. 바뀐 것이 없으면 false.
  ///
  /// 다른 행 목표가 이 행을 끌어올리면(예: 성급 목표 ★2 이상이면 강화 스킬 최소 1) 현재값까지
  /// 내려가지 않을 수 있다. 그 칸은 "바뀌는 칸"으로 남는다.
  bool toggleRow(GrowthCalculatorRow row) {
    if (!isRowAvailable(row)) return false;
    final Map<String, int> values;
    if (isRowChanged(row)) {
      _toggleMemory[row] = {for (final key in row.keys) key: _targets[key]!};
      values = current;
    } else {
      final memory = _toggleMemory.remove(row);
      if (memory == null) return false;
      values = memory;
    }
    return _setTargets(
      growthCalculatorWithRowValues(
        current: current,
        targets: _targets,
        row: row,
        values: values,
        hasFavoriteItem: hasFavoriteItem,
      ),
    );
  }

  /// [row]를 처음 값([initialTargets])으로 되돌린다.
  void revertRow(GrowthCalculatorRow row) {
    _toggleMemory.remove(row);
    _setTargets(
      growthCalculatorWithRowValues(
        current: current,
        targets: _targets,
        row: row,
        values: {for (final key in row.keys) key: _initialTargetFor(key)},
        hasFavoriteItem: hasFavoriteItem,
      ),
    );
  }

  /// 모든 행 목표를 현재값으로 둔다(S1·"바꾼 목표" 줄의 "현재값으로 되돌리기", FE3-f2a).
  /// 처음 값([initialTargets])이 아니라 지금 출처의 현재값이다.
  void resetToCurrent() {
    _toggleMemory.clear();
    _setTargets(
      normalizeGrowthCalculatorTargets(
        current: current,
        targets: current,
        hasFavoriteItem: hasFavoriteItem,
      ),
    );
  }

  /// 모든 행을 처음 값으로 되돌린다.
  void revertAll() {
    _toggleMemory.clear();
    _setTargets(
      normalizeGrowthCalculatorTargets(
        current: current,
        targets: _initialTargets,
        hasFavoriteItem: hasFavoriteItem,
      ),
    );
  }

  /// 현재값 출처를 바꾼다(FD-168). 직접 입력은 처음 고를 때 확정값에서 시작하고, 이 상태가 살아 있는
  /// 동안 고친 값을 기억한다(저장하지 않는다). 목표는 새 현재값 아래로 내려가지 않게 다시 맞춘다.
  void setBasis(GrowthCalculatorBasis value) {
    if (value == _activeBasis) return;
    _activeBasis = value;
    if (value == GrowthCalculatorBasis.direct) {
      _directCurrent ??= _confirmedCurrent;
    }
    _rebound();
    notifyListeners();
  }

  /// 직접 입력에서 [row]의 현재 스테퍼 값을 [value]로 고친다. 장비는 그 티어 최대 레벨, 전용무기는
  /// 그 ★ 최대 Lv을 현재 레벨로 본다. 확정값 기준에서는 쓰지 않는다(StateError).
  void setDirectCurrentRow(GrowthCalculatorRow row, int value) {
    _requireDirect();
    _requireAvailable(row);
    if (row == GrowthCalculatorRow.abilityRelease) {
      throw ArgumentError.value(row, 'row', 'use setDirectCurrentAbility');
    }
    final next = {...current, row.primaryKey: value};
    final slot = row.equipmentSlot;
    if (slot != null) {
      final tier = value.clamp(
        0,
        planElementTargetMaximums['equip${slot}_tier']!,
      );
      next['equip${slot}_level'] = equipmentTierMaximumLevels[tier]!;
    } else if (row == GrowthCalculatorRow.weapon) {
      final star = value.clamp(0, planElementTargetMaximums['weapon_star']!);
      next['weapon_level'] = weaponStarMaximumLevels[star]!;
    }
    _setDirectCurrent(next, row.keys.toSet());
  }

  /// 직접 입력에서 능력 개방 [ability] 현재값을 고친다.
  void setDirectCurrentAbility(GrowthCalculatorAbility ability, int value) {
    _requireDirect();
    _setDirectCurrent({...current, ability.key: value}, {ability.key});
  }

  /// repository 학생 상태가 바뀌었을 때(스캔 승인 등) 확정값을 바꾼다. 확정값 기준이면 목표 하한도 바뀐다.
  void updateConfirmedCurrent(Map<String, int> value) {
    final next = growthCalculatorCurrent(
      value,
      hasFavoriteItem: hasFavoriteItem,
    );
    if (mapEquals(next, _confirmedCurrent)) return;
    _confirmedCurrent = next;
    if (_activeBasis == GrowthCalculatorBasis.confirmed) _rebound();
    notifyListeners();
  }

  int _initialTargetFor(String key) {
    final value = _initialTargets[key]!;
    final lower = current[key]!;
    return value < lower ? lower : value;
  }

  void _setDirectCurrent(Map<String, int> next, Set<String> changedKeys) {
    final normalized = normalizePlanningGrowthTargets(
      next,
      changedKeys: changedKeys,
      hasFavoriteItem: hasFavoriteItem,
    );
    if (mapEquals(normalized, _directCurrent)) return;
    _directCurrent = normalized;
    _rebound();
    notifyListeners();
  }

  // 목표를 지금 현재값 위로 다시 맞춘다.
  void _rebound() {
    _targets = normalizeGrowthCalculatorTargets(
      current: current,
      targets: _targets,
      hasFavoriteItem: hasFavoriteItem,
    );
  }

  bool _setTargets(Map<String, int> next) {
    if (mapEquals(next, _targets)) return false;
    _targets = next;
    notifyListeners();
    return true;
  }

  void _requireAvailable(GrowthCalculatorRow row) {
    if (!isRowAvailable(row)) {
      throw ArgumentError.value(row, 'row', 'not available for this student');
    }
  }

  void _requireDirect() {
    if (_activeBasis != GrowthCalculatorBasis.direct) {
      throw StateError('current values are editable only in direct input');
    }
  }
}

/// 최근 계산 한 건(FD-170): 학생 + 기준 + 목표 맵.
@immutable
class GrowthCalculationRecord {
  GrowthCalculationRecord({
    required this.studentId,
    required this.basis,
    required Map<String, int> targets,
  }) : targets = Map.unmodifiable(targets);

  final String studentId;
  final GrowthCalculatorBasis basis;
  final Map<String, int> targets;

  @override
  bool operator ==(Object other) =>
      other is GrowthCalculationRecord &&
      other.studentId == studentId &&
      other.basis == basis &&
      mapEquals(other.targets, targets);

  @override
  int get hashCode => Object.hash(
    studentId,
    basis,
    Object.hashAllUnordered(
      targets.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );
}

/// 최근 계산 수 상한(FD-170, FD-061과 같다).
const recentGrowthCalculationCapacity = 6;

/// 최근 계산 목록(FD-170). 앱 실행 동안만 들고 있고 저장하지 않는다. 가장 최근이 맨 앞이며 학생마다
/// 한 건이다. 계정(프로필)을 바꾸면 비운다(최근 본 학생과 같은 규칙). 앱 셸을 고치지 않고도 계정 변화를
/// 알 수 있도록 [syncProfile]을 둔다.
class RecentGrowthCalculations extends ChangeNotifier {
  RecentGrowthCalculations({this.capacity = recentGrowthCalculationCapacity})
    : assert(capacity > 0);

  final int capacity;
  List<GrowthCalculationRecord> _records = const [];
  String? _profileId;

  /// 가장 최근이 맨 앞. 최대 [capacity]건, 학생마다 한 건.
  List<GrowthCalculationRecord> get records => _records;

  /// 지금 목록이 속한 계정. 아직 모르면 null.
  String? get profileId => _profileId;

  /// [entry]를 맨 앞에 넣는다. 같은 학생 기록이 있으면 지우고 맨 앞으로 옮긴다.
  void add(GrowthCalculationRecord entry) {
    if (_records.isNotEmpty && _records.first == entry) return;
    _records = List.unmodifiable(
      [
        entry,
        for (final record in _records)
          if (record.studentId != entry.studentId) record,
      ].take(capacity),
    );
    notifyListeners();
  }

  /// 목록을 비운다.
  void clear() {
    if (_records.isEmpty) return;
    _records = const [];
    notifyListeners();
  }

  /// 지금 계정을 알린다. 이전에 알린 계정과 다르면 목록을 비운다(처음 알릴 때도 그 전 기록은 비운다).
  void syncProfile(String? profileId) {
    if (profileId == _profileId) return;
    _profileId = profileId;
    clear();
  }
}
