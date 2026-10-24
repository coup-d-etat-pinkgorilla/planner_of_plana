import 'dart:io';

import 'package:ba_planner_v7/developer_tools/tool_backend_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'metadata JSON is decoded as UTF-8 across the Python process boundary',
    () async {
      final backend = Directory('../backend').absolute.path;
      final userDir = await Directory.systemTemp.createTemp(
        'ba_planner_m3r_tool_user_',
      );
      try {
        final client = ToolBackendClient(
          backendDirectory: backend,
          environment: {'BA_PLANNER_USER_DIR': userDir.path},
        );

        final result = await client.call('metadata.list', {'query': 'hoshino'});
        final students = (result['students'] as List).cast<Map>();

        expect(students, isNotEmpty);
        expect(
          students.any((student) => student['display_name'] == '호시노'),
          isTrue,
        );
      } finally {
        await userDir.delete(recursive: true);
      }
    },
  );
}
