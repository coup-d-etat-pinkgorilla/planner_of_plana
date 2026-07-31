import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/tactical_v2_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P13 shared fixture matches the strict Dart validator', () {
    final fixture =
        jsonDecode(
              File(
                '../contracts/fixtures/tactical_share_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final item in fixture['cases'] as List) {
      final entry = Map<String, dynamic>.from(item as Map);
      expect(
        isValidTacticalV2ProtocolMessage(entry['message']),
        entry['valid'],
        reason: entry['name'] as String,
      );
    }
  });
}
