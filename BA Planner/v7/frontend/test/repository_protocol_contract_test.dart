import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shared repository protocol fixture keeps strict envelopes', () {
    final fixture = jsonDecode(File('../contracts/fixtures/repository_protocol_v1.json').readAsStringSync()) as Map<String, dynamic>;
    expect(fixture['version'], 1);
    final cases = fixture['cases'] as List<dynamic>;
    expect(cases.length, greaterThanOrEqualTo(13));
    for (final raw in cases) {
      final testCase = Map<String, dynamic>.from(raw as Map);
      final message = Map<String, dynamic>.from(testCase['message'] as Map);
      expect(message.keys.toSet(), {'protocol', 'id', 'type', 'method', 'payload'}, reason: testCase['id'] as String);
      expect((message['method'] as String).startsWith('repository.'), isTrue);
    }
  });
}
