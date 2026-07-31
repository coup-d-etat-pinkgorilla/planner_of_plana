import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_student_fixture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mock roster has 42 unique students and evenly spread progression', () {
    final students = buildMockOwnedStudents();
    final ids = students.map((student) => student['student_id'] as String);
    final values = students
        .map((student) => Map<String, dynamic>.from(student['values'] as Map))
        .toList(growable: false);

    expect(students, hasLength(42));
    expect(ids.toSet(), hasLength(students.length));
    expect(values.map((value) => value['level']), containsAll([1, 90]));
    final levels =
        values.map((value) => value['level'] as int).toList(growable: false)
          ..sort();
    expect(levels.toSet(), hasLength(students.length));
    for (var index = 1; index < levels.length; index++) {
      expect(levels[index] - levels[index - 1], inInclusiveRange(2, 3));
    }

    final starCounts = <int, int>{};
    for (final value in values) {
      final star = value['student_star'] as int;
      starCounts.update(star, (count) => count + 1, ifAbsent: () => 1);
      expect(value['level'], inInclusiveRange(1, 90));
      expect(value['bond_rank'], inInclusiveRange(1, 100));
      expect(value['ex_skill'], inInclusiveRange(1, 5));
      for (final field in ['skill1', 'skill2', 'skill3']) {
        expect(value[field], inInclusiveRange(1, 10));
      }
      for (final field in ['equip1_level', 'equip2_level', 'equip3_level']) {
        expect(value[field], inInclusiveRange(1, 70));
      }
      for (final field in [
        'combat_hp',
        'combat_atk',
        'combat_def',
        'combat_heal',
      ]) {
        expect(value[field], inInclusiveRange(0, 999999));
      }
      if (star == 5) {
        expect(value['weapon_state'], 'weapon_unlocked');
        expect(value['weapon_star'], inInclusiveRange(1, 4));
        expect(value['weapon_level'], inInclusiveRange(1, 60));
      } else {
        expect(value['weapon_state'], 'weapon_locked');
        expect(value['weapon_star'], 0);
        expect(value['weapon_level'], 0);
      }
    }

    expect(starCounts.keys, containsAll([1, 2, 3, 4, 5]));
    expect(
      starCounts.values.reduce((left, right) => left > right ? left : right) -
          starCounts.values.reduce(
            (left, right) => left < right ? left : right,
          ),
      lessThanOrEqualTo(1),
    );
    expect(
      values
          .where((value) => value['student_star'] == 5)
          .map((value) => value['weapon_star'])
          .toSet(),
      {1, 2, 3, 4},
    );
    expect(values.map((value) => value['equip4']).toSet(), {
      null,
      'T1',
      'T2',
      'love_locked',
    });
    expect(values.any((value) => value['combat_hp'] == 999999), isTrue);
  });

  test(
    'full-catalog mock seeds the selected profile with the roster',
    () async {
      final service = MockAppService(fullStudentCatalog: true);
      addTearDown(service.dispose);

      final state = await service.loadRepositoryState(
        '000000000000000000000001',
      );

      expect(state.students, hasLength(mockOwnedStudentIds.length));
      expect(
        state.students.map((student) => student.studentId).toSet(),
        mockOwnedStudentIds.toSet(),
      );
      final catalogIds = (await service.listStudents())
          .map((student) => student.studentId)
          .toSet();
      expect(catalogIds, containsAll(mockOwnedStudentIds));
      expect(
        (await service.listStudents()).where(
          (student) =>
              student.equipmentSlot1 != null &&
              student.equipmentSlot2 != null &&
              student.equipmentSlot3 != null,
        ),
        hasLength(greaterThanOrEqualTo(mockOwnedStudentIds.length)),
      );
      for (final studentId in mockOwnedStudentIds) {
        expect(
          (await rootBundle.load(
            'assets/student_portraits/$studentId.png',
          )).lengthInBytes,
          greaterThan(0),
        );
      }
    },
  );

  test('compact test mock keeps an empty repository by default', () async {
    final service = MockAppService();
    addTearDown(service.dispose);

    final state = await service.loadRepositoryState('000000000000000000000001');

    expect(state.students, isEmpty);
  });
}
