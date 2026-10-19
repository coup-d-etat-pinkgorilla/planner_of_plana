import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/app_service.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _cases() =>
    (jsonDecode(
              File(
                '../contracts/fixtures/planning_student_bond_v1.json',
              ).readAsStringSync(),
            )['cases']
            as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = _cases();
  for (final entry in cases) {
    test('strict DTO and canned mock: ${entry['name']}', () async {
      final payload = Map<String, dynamic>.from(
        entry['request']['payload'] as Map,
      );
      final expected = Map<String, dynamic>.from(
        entry['response']['payload']['bond'] as Map,
      );
      final result = StudentCalculationResult.fromWire(
        Map<String, dynamic>.from(entry['response']['payload'] as Map),
      );
      expect(result.reservedBond, expected);
      expect(result.bond!.requiredExp, expected['required_exp']);
      expect(result.bond!.petting.availableCount, isNull);
      expect(result.bond!.sourceVersion, 'jp-1.73.0');
      final AppService service = MockAppService();
      addTearDown(service.dispose);
      final mocked = await service.calculateStudent(
        currentStudent: Map<String, dynamic>.from(
          payload['current_student'] as Map,
        ),
        targets: Map<String, int>.from(payload['targets'] as Map),
        inventory: Map<String, dynamic>.from(payload['inventory'] as Map),
        bond: StudentBondRequest(
          currentRank: payload['bond']['current_rank'] as int?,
        ),
      );
      expect(mocked.reservedBond, expected);
      final growthOnly = await service.calculateStudent(
        currentStudent: Map<String, dynamic>.from(
          payload['current_student'] as Map,
        ),
        targets: Map<String, int>.from(payload['targets'] as Map),
        inventory: Map<String, dynamic>.from(payload['inventory'] as Map),
      );
      expect(
        mocked.resources.map((row) => row.toWire()).toList(),
        growthOnly.resources.map((row) => row.toWire()).toList(),
      );
    });
  }

  test(
    'bond DTO rejects extra fields, false numeric values and inconsistent calculations',
    () {
      final base = Map<String, dynamic>.from(
        cases.first['response']['payload'] as Map,
      );
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (b) => b['extra'] = 0,
        (b) => b.remove('plans'),
        (b) => b['current_rank'] = true,
        (b) => b['target_rank'] = 101,
        (b) => b['required_exp'] = 45.0,
        (b) => b['assumption'] = 'partial_rank',
        (b) => b['plans']['petting']['available_count'] = 8,
        (b) => b['plans']['petting']['minimum_hours'] = 9,
        (b) => b['plans']['petting']['required_count'] = 4,
        (b) => b['plans']['normal']['extra'] = true,
        (b) => b['plans']['normal']['available'] = 1,
        (b) => b['plans']['normal']['provided_exp'] = 0,
        (b) => b['plans']['normal']['gifts'][0]['multiplier'] = true,
        (b) => b['plans']['normal']['gifts'][0]['exp_per_gift'] = 1,
        (b) => b['plans']['normal']['gifts'][0]['owned'] = -1,
        (b) => b['plans']['normal']['gifts'][0]['used_owned'] = 1,
        (b) => b['plans']['normal']['gifts'][0]['shortage'] = 0,
        (b) => (b['plans']['normal']['gifts'] as List).add(
          b['plans']['normal']['gifts'][0],
        ),
      ]) {
        final bad = _copy(base);
        mutate(bad['bond'] as Map<String, dynamic>);
        expect(
          () => StudentCalculationResult.fromWire(bad),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'unknown current produces no exp, count, elapsed time or available gifts',
    () {
      final entry = cases.singleWhere(
        (entry) => entry['name'] == 'unknown_current',
      );
      final result = StudentCalculationResult.fromWire(
        Map<String, dynamic>.from(entry['response']['payload'] as Map),
      ).bond!;
      expect(result.requiredExp, isNull);
      expect(result.petting.requiredCount, isNull);
      expect(result.petting.minimumHours, isNull);
      expect(result.preferredLarge.available, isFalse);
      expect(result.normal.available, isFalse);
      expect(result.warnings, isNotEmpty);
    },
  );

  test('quantity first and all typed collections are immutable', () {
    final entry = cases.singleWhere(
      (entry) => entry['name'] == 'quantity_before_exp',
    );
    final result = StudentCalculationResult.fromWire(
      Map<String, dynamic>.from(entry['response']['payload'] as Map),
    );
    expect(result.bond!.normal.gifts.map((gift) => gift.giftId), [5000, 5017]);
    expect(result.bond!.normal.gifts.map((gift) => gift.usedOwned), [6, 1]);
    expect(() => result.bond!.normal.gifts.clear(), throwsUnsupportedError);
    expect(() => result.bond!.warnings.add('later'), throwsUnsupportedError);
    expect(
      () => result.reservedBond!['plans']['normal']['gifts'].clear(),
      throwsUnsupportedError,
    );
    expect(
      () => const StudentBondRequest(currentRank: 0).toWire(),
      throwsFormatException,
    );
  });

  test(
    'mock refuses unsupported pairs rather than returning another pair',
    () async {
      final AppService service = MockAppService();
      addTearDown(service.dispose);
      final payload = Map<String, dynamic>.from(
        cases.first['request']['payload'] as Map,
      );
      expect(
        service.calculateStudent(
          currentStudent: Map<String, dynamic>.from(
            payload['current_student'] as Map,
          ),
          targets: Map<String, int>.from(payload['targets'] as Map),
          bond: const StudentBondRequest(currentRank: 2),
        ),
        throwsUnsupportedError,
      );
    },
  );
}
