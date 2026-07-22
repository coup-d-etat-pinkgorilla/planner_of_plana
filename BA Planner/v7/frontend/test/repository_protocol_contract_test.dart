import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ba_planner_v7/services/repository_service.dart';

void main() {
  test('shared repository protocol fixture matches every expected validity', () {
    final fixture = jsonDecode(File('../contracts/fixtures/repository_protocol_v1.json').readAsStringSync()) as Map<String, dynamic>;
    expect(fixture['version'], 1);
    final cases = fixture['cases'] as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(13));
    for (final raw in cases) {
      final testCase = Map<String, dynamic>.from(raw as Map);
      final message = Map<String, dynamic>.from(testCase['message'] as Map);
      expect(isValidRepositoryProtocolMessage(message), testCase['valid'], reason: testCase['id'] as String);
    }
  });
}
