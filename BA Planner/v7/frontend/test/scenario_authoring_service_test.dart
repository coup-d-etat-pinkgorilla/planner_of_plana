import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

extension MutationSnapshot on PlanningScenarioMutationResult {
  Map<String, dynamic> toWire() => {
    'revision': revision,
    'scenario_id': scenarioId,
  };
}

extension StateSnapshot on RepositoryState {
  Map<String, dynamic> toWire() => {
    'revision': revision,
    'students': students.map((s) => s.toWire()).toList(),
    'inventory': inventory.toWire(),
    'goals': goals
        .map((g) => {'student_id': g.studentId, ...g.values})
        .toList(),
  };
}

Map<String, dynamic> copy(Object value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
List<Map<String, dynamic>> fixture(String name) => [
  for (final c
      in (jsonDecode(
                File('../contracts/fixtures/$name.json').readAsStringSync(),
              )
              as Map)['cases']
          as List)
    Map<String, dynamic>.from(c as Map),
];
({PlanningDocument document, PlanningAuthoring authoring}) bundle(String name) {
  final c = fixture(
    'planning_authoring_v1',
  ).singleWhere((c) => c['name'] == name);
  final doc = scenarioDocumentFromWire({
    ...copy(c['document']),
    'kind': 'scenario',
  });
  return (
    document: doc,
    authoring: PlanningAuthoring.fromWire(c['canonical'], doc),
  );
}

Matcher remote(String code, [String? reason]) => throwsA(
  isA<BackendRemoteException>()
      .having((e) => e.code, 'code', code)
      .having(
        (e) => reason == null || e.details?['reason'] == reason,
        'reason',
        true,
      ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final c in fixture('scenario_authoring_v1')) {
    test('scenario strict wire: ${c['id']}', () {
      final message = copy(c['message']);
      final method = message['method'] as String;
      final payload = copy(message['payload']);
      expect(
        message['type'] == 'request'
            ? isValidScenarioRequestPayload(method, payload)
            : isValidScenarioSuccessPayload(method, payload),
        c['valid'],
      );
      if (c['valid'] == true && method == 'repository.scenario.create') {
        expect(
          PlanningScenarioCreateRequest.fromWire(payload).toWire(),
          payload,
        );
      }
      if (c['valid'] == true && method == 'repository.scenario.update') {
        expect(
          PlanningScenarioUpdateRequest.fromWire(payload).toWire(),
          payload,
        );
      }
    });
  }
  for (final c in fixture('planning_authoring_v1')) {
    test('scenario shares authoring policy: ${c['name']}', () {
      final doc = scenarioDocumentFromWire({
        ...copy(c['document']),
        'kind': 'scenario',
      });
      final payload = <String, dynamic>{
        'profile_id': 'a' * 24,
        'expected_revision': 0,
        'idempotency_key': 'policy',
        'name': 'Policy',
        'description': '',
        'base_profile_revision': 0,
        'document': doc.toWire(),
        'authoring': c['authoring'],
      };
      if (c['valid'] == true) {
        expect(
          PlanningScenarioCreateRequest.fromWire(payload).toWire()['authoring'],
          c['canonical'],
        );
      } else {
        expect(
          () => PlanningScenarioCreateRequest.fromWire(payload),
          throwsA(
            isA<PlanningAuthoringFormatException>().having(
              (e) => e.reason,
              'reason',
              c['reason'],
            ),
          ),
        );
      }
    });
  }
  test(
    'strict request rejects wrong identity, revisions, document kind and null',
    () {
      final valid =
          copy(fixture('scenario_authoring_v1').first['message'])['payload']
              as Map;
      for (final invalid in [
        {...valid, 'expected_revision': true},
        {...valid, 'expected_revision': -1},
        {...valid, 'profile_id': 'A' * 24},
        {...valid, 'name': '  '},
        {...valid, 'base_profile_revision': 1.0},
        {...valid, 'authoring': null},
        {
          ...valid,
          'document': {...copy(valid['document']), 'kind': 'plan'},
        },
      ]) {
        expect(
          () => PlanningScenarioCreateRequest.fromWire(
            Map<String, dynamic>.from(invalid),
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'mock metadata-only update, omission, replacement, duplicate and replay',
    () async {
      final s = MockAppService();
      addTearDown(s.dispose);
      final pid = (await s.listProfiles()).single.id;
      final before = (await s.loadRepositoryState(pid)).toWire();
      final b = bundle('deferred-targets-selected-order');
      Future<PlanningScenarioMutationResult> create() => s.createScenario(
        profileId: pid,
        expectedRevision: 0,
        idempotencyKey: 'create',
        name: 'Candidate',
        description: '',
        baseProfileRevision: 0,
        document: b.document,
        authoring: b.authoring,
      );
      final created = await create();
      expect((await create()).toWire(), created.toWire());
      final changed = PlanningAuthoring.fromWire({
        ...b.authoring.toWire(),
        'student_order': b.authoring.studentOrder.reversed.toList(),
      }, b.document);
      Future<PlanningScenarioMutationResult> update(
        int rev,
        int recordRev,
        String key,
        PlanningAuthoring? auth, [
        PlanningDocument? doc,
      ]) => s.updateScenario(
        profileId: pid,
        scenarioId: created.scenarioId,
        expectedRevision: rev,
        expectedScenarioRevision: recordRev,
        idempotencyKey: key,
        name: 'Candidate',
        description: '',
        baseProfileRevision: 0,
        document: doc ?? b.document,
        authoring: auth,
      );
      final metadata = await update(1, 0, 'metadata', changed);
      expect(metadata.revision, 2);
      expect(
        (await s.getScenario(pid, created.scenarioId)).scenario.revision,
        1,
      );
      await update(2, 1, 'preserve', null);
      expect(
        (await s.getScenario(
          pid,
          created.scenarioId,
        )).scenario.authoring.toWire(),
        changed.toWire(),
      );
      final empty = bundle('empty-default');
      await expectLater(
        update(3, 2, 'bad', null, empty.document),
        remote('invalid_payload', 'authoring_required'),
      );
      expect((await s.listScenarios(pid)).revision, 3);
      Future<PlanningScenarioMutationResult> duplicate() => s.duplicateScenario(
        profileId: pid,
        scenarioId: created.scenarioId,
        expectedRevision: 3,
        expectedScenarioRevision: 2,
        idempotencyKey: 'duplicate',
      );
      final copied = await duplicate();
      expect((await duplicate()).toWire(), copied.toWire());
      expect((await s.listScenarios(pid)).scenarios.length, 2);
      final record = (await s.getScenario(pid, copied.scenarioId)).scenario;
      expect(record.authoring.toWire(), changed.toWire());
      expect(record.document.toWire()['phases'], b.document.toWire()['phases']);
      expect(record.document.id, copied.scenarioId);
      expect(record.revision, 0);
      await update(
        4,
        2,
        'clear',
        PlanningAuthoring.defaultForDocument(b.document),
      );
      expect(
        (await s.getScenario(
          pid,
          copied.scenarioId,
        )).scenario.authoring.toWire(),
        changed.toWire(),
      );
      expect(
        (await update(1, 0, 'metadata', changed)).toWire(),
        metadata.toWire(),
      );
      await expectLater(
        update(5, 3, 'metadata', b.authoring),
        remote('idempotency_conflict'),
      );
      await expectLater(
        update(4, 3, 'stale', changed),
        remote('revision_conflict'),
      );
      await expectLater(
        update(5, 0, 'stale-record', changed),
        remote('revision_conflict'),
      );
      expect((await s.loadRepositoryState(pid)).toWire(), before);
      await s.deleteScenario(
        profileId: pid,
        scenarioId: created.scenarioId,
        expectedRevision: 5,
        expectedScenarioRevision: 3,
        idempotencyKey: 'delete',
      );
      expect((await create()).toWire(), created.toWire());
      expect(
        (await update(1, 0, 'metadata', changed)).toWire(),
        metadata.toWire(),
      );
      expect((await s.listScenarios(pid)).revision, 6);
    },
  );

  test(
    'mock checks old omitted replay before new authoring compatibility',
    () async {
      final s = MockAppService();
      addTearDown(s.dispose);
      final pid = (await s.listProfiles()).single.id;
      final empty = bundle('empty-default');
      final c = await s.createScenario(
        profileId: pid,
        expectedRevision: 0,
        idempotencyKey: 'create',
        name: 'Old',
        description: '',
        baseProfileRevision: 0,
        document: empty.document,
      );
      expect(
        (await s.getScenario(pid, c.scenarioId)).scenario.hasAuthoring,
        false,
      );
      Future<PlanningScenarioMutationResult> old() => s.updateScenario(
        profileId: pid,
        scenarioId: c.scenarioId,
        expectedRevision: 1,
        expectedScenarioRevision: 0,
        idempotencyKey: 'old',
        name: 'Old',
        description: '',
        baseProfileRevision: 0,
        document: empty.document,
      );
      final response = await old();
      final b = bundle('deferred-targets-selected-order');
      await s.updateScenario(
        profileId: pid,
        scenarioId: c.scenarioId,
        expectedRevision: 2,
        expectedScenarioRevision: 1,
        idempotencyKey: 'new',
        name: 'New',
        description: '',
        baseProfileRevision: 0,
        document: b.document,
        authoring: b.authoring,
      );
      expect((await old()).toWire(), response.toWire());
      expect(
        (await s.getScenario(pid, c.scenarioId)).scenario.authoring.toWire(),
        b.authoring.toWire(),
      );
    },
  );

  test(
    'mock deferred-only and selected-only count scheduled students only',
    () async {
      final s = MockAppService();
      addTearDown(s.dispose);
      final pid = (await s.listProfiles()).single.id;
      var revision = 0;
      for (final name in ['all-deferred', 'selected-only']) {
        final b = bundle(name);
        await s.createScenario(
          profileId: pid,
          expectedRevision: revision++,
          idempotencyKey: name,
          name: name,
          description: '',
          baseProfileRevision: 0,
          document: b.document,
          authoring: b.authoring,
        );
      }
      for (final summary in (await s.listScenarios(pid)).scenarios) {
        expect(summary.stageCount, 0);
        expect(summary.studentCount, 0);
        expect(summary.phaseCount, 0);
        expect(summary.studentIds, isEmpty);
        expect(summary.calculation!.credits, 0);
      }
    },
  );
}
