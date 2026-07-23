import 'dart:io';

import 'package:ba_planner_v7/services/backend_process.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/process_app_service.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/tactical_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real Dart to Python tactical save survives process restart',
    () async {
      final storage = await Directory.systemTemp.createTemp(
        'ba_planner_v7_tactical_e2e_',
      );
      final backend = Directory(
        '${Directory.current.parent.path}${Platform.pathSeparator}backend',
      );
      final config = BackendProcessConfig.resolve(
        backendDirectory: backend.path,
        environment: {'BA_PLANNER_STORAGE_ROOT': storage.path},
      );
      ProcessAppService service() => ProcessAppService(
        PlanningProtocolClient(
          () => startBackendProcess(config),
          defaultTimeout: const Duration(seconds: 10),
        ),
      );
      ProcessAppService? first, second;
      try {
        first = service();
        await first.reconnect();
        final profile = await first.createProfile(
          'Tactical E2E',
          'tactical-e2e-profile',
        );
        await first.saveRepositoryStudents(
          profile.id,
          [
            ConfirmedStudentState.fromValues('hoshino', {}),
            ConfirmedStudentState.fromValues('ayane', {}),
          ],
          0,
          'tactical-owned',
        );
        final mine = TacticalDeck(
          strikers: const ['hoshino', null, null, null],
          specials: const ['ayane', null],
        );
        final opponent = TacticalDeck(
          strikers: const ['shiroko', null, null, null],
          specials: const ['serika_new_year', null],
        );
        final revision = await first.saveTacticalMatch(
          profile.id,
          TacticalMatch(
            id: 'e2e-match',
            kind: 'attack',
            occurredOn: null,
            season: 'S1',
            opponent: 'Rival',
            result: 'win',
            attackDeck: mine,
            defenseDeck: opponent,
            notes: 'restart',
          ),
          0,
          'save-match',
        );
        expect(revision, 1);
        await first.dispose();
        first = null;
        second = service();
        await second.reconnect();
        final restored = await second.loadTacticalState(profile.id);
        expect(restored.revision, 1);
        expect(restored.matches.single.id, 'e2e-match');
        expect(restored.matches.single.occurredOn, isNull);
        expect(restored.matches.single.attackDeck.strikers, [
          'hoshino',
          null,
          null,
          null,
        ]);
      } finally {
        await first?.dispose();
        await second?.dispose();
        if (storage.existsSync()) await storage.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
