import 'dart:io';

import 'package:ba_planner_v7/developer_tools/tool_backend_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'metadata JSON is decoded as UTF-8 across the Python process boundary',
    () async {
      final backend = Directory('../backend').absolute.path;
      final client = ToolBackendClient(backendDirectory: backend);

      final result = await client.call('metadata.list', {'query': 'hoshino'});
      final students = (result['students'] as List).cast<Map>();

      expect(students, isNotEmpty);
      expect(
        students.any((student) => student['display_name'] == '호시노'),
        isTrue,
      );
    },
  );
}
