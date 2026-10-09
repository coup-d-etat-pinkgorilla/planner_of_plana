import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

const pid = 'aaaaaaaaaaaaaaaaaaaaaaaa';
Map<String, dynamic> copy(Object value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
List<Map<String, dynamic>> fixture(String name) => [
  for (final raw
      in (jsonDecode(
                File('../contracts/fixtures/$name.json').readAsStringSync(),
              )
              as Map)['cases']
          as List)
    Map<String, dynamic>.from(raw as Map),
];
PlanningDocument document({
  int level = 10,
  int? bond = 35,
  bool empty = false,
}) {
  final wire = copy(
    fixture('repository_plan_migration_v1').first['expected_document'] as Map,
  );
  if (empty) {
    wire['phases'] = <dynamic>[];
    wire['goal_metadata'] = <String, dynamic>{};
  } else {
    wire['phases'][0]['stages'][0]['targets']['level'] = level;
    wire['phases'][0]['stages'][0]['targets']['bond_rank'] = bond;
    wire['goal_metadata']['aru'] = {
      'favorite': false,
      'notes': ' old metadata ',
    };
  }
  return repositoryActiveDocument(wire);
}

Future<RepositoryPlanReplaceResult> replace(
  MockAppService service, {
  required int revision,
  int scenarioRevision = 0,
  String key = 'replace',
  PlanningDocument? next,
}) => service.replaceRepositoryPlan(
  profileId: pid,
  document: next ?? document(level: 20, bond: null),
  expectedRevision: revision,
  expectedScenarioRevision: scenarioRevision,
  idempotencyKey: key,
  archiveName: ' Archive ',
  archiveDescription: ' retained ',
);
MockAppService mock() => MockAppService(
  profiles: const [
    RepositoryProfile(
      id: pid,
      displayName: 'Replace',
      revision: 0,
      selected: true,
    ),
  ],
);
Matcher remote(String code, {String? scope}) => isA<BackendRemoteException>()
    .having((error) => error.code, 'code', code)
    .having((error) => error.details?['revision_scope'], 'scope', scope);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('shared replace fixture is strict for request and response', () {
    for (final item in fixture('repository_plan_replace_v1')) {
      expect(
        isValidRepositoryProtocolMessage(copy(item['message'] as Map)),
        item['valid'],
        reason: item['id'] as String,
      );
    }
  });
  test(
    'replace DTO roundtrip rejects bools, missing fields and v1 document',
    () {
      final source = copy(
        fixture('repository_plan_replace_v1').first['message']['payload']
            as Map,
      );
      final request = RepositoryPlanReplaceRequest.fromWire(source);
      expect(request.toWire(), source);
      source['document']['phases'].clear();
      expect(request.document.phases, isNotEmpty);
      final returned = {
        'revision': 7,
        'scenario_revision': 3,
        'archived_scenario_id': pid,
      };
      expect(RepositoryPlanReplaceResult.fromWire(returned).toWire(), returned);
      for (final item in fixture(
        'repository_plan_replace_v1',
      ).where((item) => item['valid'] == false)) {
        final message = item['message'] as Map;
        final wire = copy(message['payload'] as Map);
        expect(
          () => message['type'] == 'request'
              ? RepositoryPlanReplaceRequest.fromWire(wire)
              : RepositoryPlanReplaceResult.fromWire(wire),
          throwsFormatException,
          reason: item['id'] as String,
        );
      }
      final v1 = copy(request.toWire());
      v1['document']['version'] = 1;
      expect(
        () => RepositoryPlanReplaceRequest.fromWire(v1),
        throwsFormatException,
      );
    },
  );
  test(
    'mock replaces once, preserves archive metadata and original reply after later edits',
    () async {
      final service = mock();
      addTearDown(service.dispose);
      final previous = document();
      await service.saveRepositoryPlan(
        profileId: pid,
        document: previous,
        expectedRevision: 0,
        idempotencyKey: 'save',
      );
      final response = await replace(service, revision: 1);
      expect(response.revision, 2);
      expect(response.scenarioRevision, 1);
      expect(response.archivedScenarioId, isNotNull);
      final archive = (await service.getScenario(
        pid,
        response.archivedScenarioId!,
      )).scenario;
      expect(archive.document.toWire(), {
        ...previous.toWire(),
        'kind': 'scenario',
        'document_id': response.archivedScenarioId,
      });
      expect(archive.baseProfileRevision, 1);
      expect(archive.revision, 0);
      expect(archive.name, 'Archive');
      expect(archive.description, 'retained');
      expect(
        (await service.loadRepositoryState(
          pid,
        )).goals.single.values['target_level'],
        20,
      );
      expect((await replace(service, revision: 1)).toWire(), response.toWire());
      await service.saveRepositoryPlan(
        profileId: pid,
        document: previous,
        expectedRevision: 2,
        idempotencyKey: 'later',
      );
      await service.deleteScenario(
        profileId: pid,
        scenarioId: archive.id,
        expectedRevision: 1,
        expectedScenarioRevision: 0,
        idempotencyKey: 'delete',
      );
      expect((await replace(service, revision: 1)).toWire(), response.toWire());
      expect((await service.listScenarios(pid)).scenarios, isEmpty);
      expect((await service.loadRepositoryPlan(pid)).revision, 3);
    },
  );
  test(
    'empty active plan keeps collection revision and makes no archive',
    () async {
      final service = mock();
      addTearDown(service.dispose);
      final response = await replace(service, revision: 0);
      expect(response.toWire(), {
        'revision': 1,
        'scenario_revision': 0,
        'archived_scenario_id': null,
      });
      expect((await service.listScenarios(pid)).scenarios, isEmpty);
      final empty = document(empty: true);
      final archived = await replace(
        service,
        revision: 1,
        key: 'clear',
        next: empty,
      );
      expect(archived.scenarioRevision, 1);
      final sameRevision = await replace(
        service,
        revision: 2,
        scenarioRevision: 1,
        key: 'fill',
      );
      expect(sameRevision.scenarioRevision, 1);
      expect(sameRevision.archivedScenarioId, isNull);
      expect((await service.listScenarios(pid)).scenarios.length, 1);
    },
  );
  test(
    'two revision conflicts identify scope and preserve both buckets',
    () async {
      final service = mock();
      addTearDown(service.dispose);
      await service.saveRepositoryPlan(
        profileId: pid,
        document: document(),
        expectedRevision: 0,
        idempotencyKey: 'save',
      );
      for (final entry in [
        (0, 0, 'profile'),
        (1, 1, 'scenario'),
        (0, 1, 'both'),
      ]) {
        await expectLater(
          replace(service, revision: entry.$1, scenarioRevision: entry.$2),
          throwsA(remote('revision_conflict', scope: entry.$3)),
        );
      }
      expect((await service.loadRepositoryPlan(pid)).revision, 1);
      expect((await service.listScenarios(pid)).revision, 0);
    },
  );
  test(
    'replacement cache shares key namespace with old revision-only save cache',
    () async {
      final service = mock();
      addTearDown(service.dispose);
      final previous = document();
      await service.saveRepositoryPlan(
        profileId: pid,
        document: previous,
        expectedRevision: 0,
        idempotencyKey: 'save',
      );
      await expectLater(
        replace(service, revision: 1, key: 'save'),
        throwsA(remote('idempotency_conflict')),
      );
      await replace(service, revision: 1);
      expect(
        await service.saveRepositoryPlan(
          profileId: pid,
          document: previous,
          expectedRevision: 0,
          idempotencyKey: 'save',
        ),
        1,
      );
      await expectLater(
        replace(service, revision: 2),
        throwsA(remote('idempotency_conflict')),
      );
      expect((await service.listScenarios(pid)).scenarios.length, 1);
    },
  );
  test(
    'legacy first get then save then replace uses migrated revision and nullable bond',
    () async {
      final policy = fixture('repository_plan_migration_v1').first;
      final service = MockAppService(
        profiles: const [
          RepositoryProfile(
            id: pid,
            displayName: 'Legacy',
            revision: 4,
            selected: true,
          ),
        ],
        repositoryStates: {
          pid: {
            'profile_id': pid,
            'revision': 4,
            'students': policy['students'],
            'inventory': {'version': 1, 'entries': []},
            'goals': policy['legacy_goals'],
          },
        },
      );
      addTearDown(service.dispose);
      final migrated = await service.loadRepositoryPlan(pid);
      expect(migrated.revision, 5);
      expect(
        migrated.document.stages.single.nullableTargets['bond_rank'],
        isNull,
      );
      await service.saveRepositoryPlan(
        profileId: pid,
        document: document(),
        expectedRevision: 5,
        idempotencyKey: 'save',
      );
      final replaced = await replace(service, revision: 6);
      expect(replaced.revision, 7);
      expect((await service.listProfiles()).single.revision, 7);
      expect(
        (await service.getScenario(
          pid,
          replaced.archivedScenarioId!,
        )).scenario.document.stages.single.nullableTargets['bond_rank'],
        35,
      );
    },
  );
}
