// FE3-f1 성장 계산기 상태 테스트: 칸 토글·되돌리기·빠른 목표·현재값 출처·최근 계산
// (FD-167·FD-168·FD-169·FD-170).
import 'package:ba_planner_v7/ui/models/growth_calculator_rules.dart';
import 'package:ba_planner_v7/ui/models/growth_calculator_state.dart';
import 'package:ba_planner_v7/ui/models/planning_growth_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _current = <String, int>{
  'level': 70,
  'bond_rank': 12,
  'student_star': 3,
  'weapon_level': 0,
  'weapon_star': 0,
  'ex_skill': 2,
  'skill1': 5,
  'skill2': 5,
  'skill3': 4,
  'equip1_tier': 7,
  'equip2_tier': 7,
  'equip3_tier': 6,
  'equip1_level': 55,
  'equip2_level': 55,
  'equip3_level': 50,
  'equip4_tier': 0,
  'stat_hp': 0,
  'stat_atk': 0,
  'stat_heal': 0,
};

GrowthCalculatorState _state({
  String studentId = 'hoshino',
  bool hasFavoriteItem = true,
  GrowthCalculatorBasis basis = GrowthCalculatorBasis.confirmed,
  Map<String, int>? initialTargets,
}) => GrowthCalculatorState(
  studentId: studentId,
  confirmedCurrent: _current,
  hasFavoriteItem: hasFavoriteItem,
  basis: basis,
  initialTargets: initialTargets,
);

GrowthCalculationRecord _record(String studentId, {int level = 90}) =>
    GrowthCalculationRecord(
      studentId: studentId,
      basis: GrowthCalculatorBasis.confirmed,
      targets: {..._current, 'level': level},
    );

void main() {
  test('처음에는 목표 = 현재값, 바뀌는 칸 0', () {
    final state = _state();
    addTearDown(state.dispose);
    expect(state.targets, _current);
    expect(state.rows.length, 13);
    expect(
      state.cellCounts,
      const GrowthCalculatorCellCounts(changing: 0, unchanged: 13),
    );
    expect(state.changes, isEmpty);
    expect(state.rowCurrent(GrowthCalculatorRow.equipment3), 6);
    expect(state.rowMaximum(GrowthCalculatorRow.equipment3), 10);
    expect(state.rowMaximum(GrowthCalculatorRow.abilityRelease), 75);
    final withoutFavorite = _state(hasFavoriteItem: false);
    addTearDown(withoutFavorite.dispose);
    expect(withoutFavorite.rows.length, 12);
  });

  test('행 목표를 바꾸면 알리고, 같은 값이면 알리지 않는다', () {
    final state = _state();
    addTearDown(state.dispose);
    var notified = 0;
    state.addListener(() => notified += 1);
    state.setRowTarget(GrowthCalculatorRow.equipment1, 10);
    expect(state.targets['equip1_level'], 70);
    expect(notified, 1);
    state.setRowTarget(GrowthCalculatorRow.equipment1, 10);
    expect(notified, 1);
    state.setAbilityTarget(GrowthCalculatorAbility.atk, 4);
    expect(state.abilityTarget(GrowthCalculatorAbility.atk), 4);
    expect(state.targets['level'], 90);
    expect(notified, 2);
    expect(
      () => state.setRowTarget(GrowthCalculatorRow.abilityRelease, 1),
      throwsArgumentError,
    );
  });

  test('애장품이 없는 학생은 애장품 행을 쓰지 않는다', () {
    final state = _state(hasFavoriteItem: false);
    addTearDown(state.dispose);
    expect(state.isRowAvailable(GrowthCalculatorRow.favoriteItem), isFalse);
    expect(
      () => state.setRowTarget(GrowthCalculatorRow.favoriteItem, 1),
      throwsArgumentError,
    );
    expect(state.toggleRow(GrowthCalculatorRow.favoriteItem), isFalse);
  });

  group('칸 토글(FD-167)', () {
    test('목표 ↔ 현재값을 오가고 바뀌는 칸 개수가 따라간다', () {
      final state = _state();
      addTearDown(state.dispose);
      state.setRowTarget(GrowthCalculatorRow.level, 90);
      state.setRowTarget(GrowthCalculatorRow.equipment2, 9);
      expect(
        state.cellCounts,
        const GrowthCalculatorCellCounts(changing: 2, unchanged: 11),
      );
      expect(state.canToggleRow(GrowthCalculatorRow.level), isTrue);

      expect(state.toggleRow(GrowthCalculatorRow.level), isTrue);
      expect(state.targets['level'], 70);
      expect(state.isRowChanged(GrowthCalculatorRow.level), isFalse);
      expect(
        state.cellCounts,
        const GrowthCalculatorCellCounts(changing: 1, unchanged: 12),
      );
      // 직전 목표가 남아 있어 다시 누를 수 있다.
      expect(state.canToggleRow(GrowthCalculatorRow.level), isTrue);
      expect(state.toggleRow(GrowthCalculatorRow.level), isTrue);
      expect(state.targets['level'], 90);
      expect(
        state.cellCounts,
        const GrowthCalculatorCellCounts(changing: 2, unchanged: 11),
      );

      // 장비 행은 티어와 레벨을 함께 되돌린다.
      expect(state.toggleRow(GrowthCalculatorRow.equipment2), isTrue);
      expect(state.targets['equip2_tier'], 7);
      expect(state.targets['equip2_level'], 55);
      expect(state.toggleRow(GrowthCalculatorRow.equipment2), isTrue);
      expect(state.targets['equip2_tier'], 9);
      expect(state.targets['equip2_level'], 65);
    });

    test('바뀐 적 없는 칸은 눌러도 그대로다', () {
      final state = _state();
      addTearDown(state.dispose);
      expect(state.canToggleRow(GrowthCalculatorRow.bond), isFalse);
      expect(state.toggleRow(GrowthCalculatorRow.bond), isFalse);
      expect(state.targets, _current);
    });

    test('스테퍼로 바꾸면 그 칸의 직전 목표 기억은 지운다', () {
      final state = _state();
      addTearDown(state.dispose);
      state.setRowTarget(GrowthCalculatorRow.exSkill, 5);
      state.toggleRow(GrowthCalculatorRow.exSkill);
      state.setRowTarget(GrowthCalculatorRow.exSkill, 2);
      expect(state.canToggleRow(GrowthCalculatorRow.exSkill), isFalse);
    });
  });

  group('되돌리기', () {
    test('행 단위로 처음 값으로 돌리고, 전체도 돌린다', () {
      final state = _state();
      addTearDown(state.dispose);
      state.setRowTarget(GrowthCalculatorRow.normalSkill, 10);
      state.setRowTarget(GrowthCalculatorRow.equipment3, 10);
      expect(state.isRowModified(GrowthCalculatorRow.normalSkill), isTrue);
      state.revertRow(GrowthCalculatorRow.normalSkill);
      expect(state.targets['skill1'], 5);
      expect(state.isRowModified(GrowthCalculatorRow.normalSkill), isFalse);
      expect(state.targets['equip3_tier'], 10);
      state.revertAll();
      expect(state.targets, _current);
    });

    test('최근 계산에서 다시 열면 그때 목표가 처음 값이다', () {
      final state = _state(initialTargets: {..._current, 'level': 80});
      addTearDown(state.dispose);
      expect(state.targets['level'], 80);
      state.setRowTarget(GrowthCalculatorRow.level, 90);
      state.revertRow(GrowthCalculatorRow.level);
      expect(state.targets['level'], 80);
      expect(state.isRowChanged(GrowthCalculatorRow.level), isTrue);
    });
  });

  test('빠른 목표 3종(FD-169)', () {
    final state = _state();
    addTearDown(state.dispose);
    state.applyQuickTarget(GrowthCalculatorQuickTarget.fullGrowth);
    expect(state.targets, planElementTargetMaximums);
    expect(
      state.cellCounts,
      const GrowthCalculatorCellCounts(changing: 13, unchanged: 0),
    );
    state.applyQuickTarget(GrowthCalculatorQuickTarget.levelAndEquipment);
    expect(state.targets['level'], 90);
    expect(state.targets['equip1_tier'], 10);
    expect(state.targets['equip1_level'], 70);
    expect(state.targets['ex_skill'], 2);
    expect(state.targets['bond_rank'], 12);
    state.applyQuickTarget(GrowthCalculatorQuickTarget.skills);
    expect(state.targets['level'], 70);
    expect(state.targets['ex_skill'], 5);
    expect(state.targets['skill3'], 10);
    expect(state.changeChips.map((chip) => chip.label), ['스킬 +19단계']);
  });

  group('현재값 출처(FD-168)', () {
    test('직접 입력은 현재값을 고치고 목표 하한도 따라간다. 확정값으로 돌아가면 다시 올린다', () {
      final state = _state();
      addTearDown(state.dispose);
      expect(
        () => state.setDirectCurrentRow(GrowthCalculatorRow.level, 30),
        throwsStateError,
      );
      state.setBasis(GrowthCalculatorBasis.direct);
      expect(state.current, _current);
      state.setDirectCurrentRow(GrowthCalculatorRow.level, 30);
      expect(state.current['level'], 30);
      expect(state.confirmedCurrent['level'], 70);
      // 목표는 그대로(70)지만 이제 30까지 내릴 수 있다.
      state.setRowTarget(GrowthCalculatorRow.level, 40);
      expect(state.targets['level'], 40);
      expect(state.isRowChanged(GrowthCalculatorRow.level), isTrue);
      // 장비는 그 티어 최대 레벨을 현재 레벨로 본다.
      state.setDirectCurrentRow(GrowthCalculatorRow.equipment1, 3);
      expect(state.current['equip1_tier'], 3);
      expect(state.current['equip1_level'], 30);
      state.setDirectCurrentAbility(GrowthCalculatorAbility.hp, 0);

      state.setBasis(GrowthCalculatorBasis.confirmed);
      expect(state.current, _current);
      expect(state.targets['level'], 70);
      // 직접 입력 값은 이 상태가 살아 있는 동안 기억한다(저장하지 않는다).
      state.setBasis(GrowthCalculatorBasis.direct);
      expect(state.current['level'], 30);
    });

    test('미보유 학생도 기본 현재값으로 계산한다', () {
      final state = GrowthCalculatorState(
        studentId: 'unowned',
        confirmedCurrent: {
          ..._current,
          'level': 1,
          'student_star': 1,
          'bond_rank': 1,
          'ex_skill': 1,
          'skill1': 1,
          'skill2': 0,
          'skill3': 0,
          'equip1_tier': 0,
          'equip2_tier': 0,
          'equip3_tier': 0,
          'equip1_level': 0,
          'equip2_level': 0,
          'equip3_level': 0,
        },
        hasFavoriteItem: true,
        basis: GrowthCalculatorBasis.direct,
      );
      addTearDown(state.dispose);
      state.setDirectCurrentRow(GrowthCalculatorRow.studentStar, 3);
      expect(state.current['student_star'], 3);
      expect(state.current['skill2'], 1);
      expect(state.current['skill3'], 1);
      state.applyQuickTarget(GrowthCalculatorQuickTarget.fullGrowth);
      expect(state.targets, planElementTargetMaximums);
    });

    test('확정값이 바뀌면(스캔 승인 등) 목표 하한을 다시 맞춘다', () {
      final state = _state();
      addTearDown(state.dispose);
      var notified = 0;
      state.addListener(() => notified += 1);
      state.updateConfirmedCurrent({..._current, 'level': 85});
      expect(state.targets['level'], 85);
      expect(notified, 1);
      state.updateConfirmedCurrent({..._current, 'level': 85});
      expect(notified, 1);
    });

    test('계산기 기록은 학생 + 기준 + 목표다', () {
      final state = _state(basis: GrowthCalculatorBasis.direct);
      addTearDown(state.dispose);
      state.setRowTarget(GrowthCalculatorRow.level, 90);
      expect(
        state.record,
        GrowthCalculationRecord(
          studentId: 'hoshino',
          basis: GrowthCalculatorBasis.direct,
          targets: {..._current, 'level': 90},
        ),
      );
    });
  });

  group('최근 계산(FD-170)', () {
    test('최대 6건, 가장 최근이 맨 앞', () {
      final recent = RecentGrowthCalculations();
      addTearDown(recent.dispose);
      for (var index = 0; index < 8; index++) {
        recent.add(_record('s$index'));
      }
      expect(recent.records.map((record) => record.studentId), [
        's7',
        's6',
        's5',
        's4',
        's3',
        's2',
      ]);
      expect(recentGrowthCalculationCapacity, 6);
    });

    test('같은 학생은 한 건만 두고 맨 앞으로 옮긴다(새 목표로 바꾼다)', () {
      final recent = RecentGrowthCalculations();
      addTearDown(recent.dispose);
      recent.add(_record('a'));
      recent.add(_record('b'));
      recent.add(_record('a', level: 80));
      expect(recent.records.map((record) => record.studentId), ['a', 'b']);
      expect(recent.records.first.targets['level'], 80);
      var notified = 0;
      recent.addListener(() => notified += 1);
      recent.add(_record('a', level: 80));
      expect(notified, 0);
    });

    test('계정(프로필)을 바꾸면 비운다', () {
      final recent = RecentGrowthCalculations();
      addTearDown(recent.dispose);
      recent.syncProfile('000000000000000000000001');
      recent.add(_record('a'));
      recent.syncProfile('000000000000000000000001');
      expect(recent.records, hasLength(1));
      recent.syncProfile('000000000000000000000002');
      expect(recent.records, isEmpty);
      expect(recent.profileId, '000000000000000000000002');
      recent.add(_record('b'));
      recent.clear();
      expect(recent.records, isEmpty);
    });
  });
}
