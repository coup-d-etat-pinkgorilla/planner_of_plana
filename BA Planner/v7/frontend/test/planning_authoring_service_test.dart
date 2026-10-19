import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> fixture(String name) => [
  for (final raw
      in (jsonDecode(
                File('../contracts/fixtures/$name.json').readAsStringSync(),
              )
              as Map)['cases']
          as List)
    Map<String, dynamic>.from(raw as Map),
];
Map<String, dynamic> copy(Object value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cases = fixture('planning_authoring_v1');
  Map<String, dynamic> policy(String name) =>
      copy(cases.singleWhere((c) => c['name'] == name));
  for (final c in cases) {
    test('shared authoring policy: ${c['name']}', () {
      final document = PlanningDocument.fromWire(copy(c['document']));
      if (c['valid'] as bool) {
        final authoring = PlanningAuthoring.fromWire(c['authoring'], document);
        expect(authoring.toWire(), c['canonical']);
        expect(
          PlanningAuthoring.fromWire(authoring.toWire(), document).toWire(),
          c['canonical'],
        );
      } else {
        expect(
          () => PlanningAuthoring.fromWire(c['authoring'], document),
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
  for (final c in fixture('repository_plan_authoring_v1')) {
    test('shared authoring wire: ${c['id']}', () {
      final message = copy(c['message']);
      final method = message['method'] as String;
      expect(
        method.startsWith('repository.scenario.')
            ? isValidScenarioSuccessPayload(method, copy(message['payload']))
            : isValidRepositoryProtocolMessage(message),
        c['valid'],
      );
    });
  }

  test(
    'strict save/replace serialization preserves omission and validates bundles',
    () {
      final c = policy('deferred-targets-selected-order');
      final document = repositoryActiveDocument(c['document']);
      final authoring = PlanningAuthoring.fromWire(c['authoring'], document);
      final wire = RepositoryPlanSaveRequest(
        profileId: 'a' * 24,
        expectedRevision: 0,
        idempotencyKey: 'save',
        document: document,
        authoring: authoring,
      ).toWire();
      expect(RepositoryPlanSaveRequest.fromWire(wire).toWire(), wire);
      final omitted = {...wire}..remove('authoring');
      expect(
        RepositoryPlanSaveRequest.fromWire(
          omitted,
        ).toWire().containsKey('authoring'),
        false,
      );
      expect(
        () =>
            RepositoryPlanSaveRequest.fromWire({...omitted, 'authoring': null}),
        throwsFormatException,
      );
      final other = repositoryActiveDocument(
        policy('empty-default')['document'],
      );
      expect(
        () => RepositoryPlanSaveRequest(
          profileId: 'a' * 24,
          expectedRevision: 0,
          idempotencyKey: 'bad',
          document: other,
          authoring: authoring,
        ).toWire(),
        throwsFormatException,
      );
      final replace = {
        ...wire,
        'expected_scenario_revision': 0,
        'archive_name': ' Old ',
        'archive_description': '',
      };
      expect(
        RepositoryPlanReplaceRequest.fromWire(replace).toWire()['authoring'],
        authoring.toWire(),
      );
    },
  );

  test(
    'legacy plan getter supplies a default without inventing a stored field',
    () {
      final c = policy('document-default');
      final state = RepositoryPlanState.fromWire({
        'profile_id': 'a' * 24,
        'revision': 2,
        'document': c['document'],
        'calculation': null,
      });
      expect(state.hasAuthoring, false);
      expect(state.authoring.toWire(), c['canonical']);
      expect(state.authoring.isDefaultForDocument(state.document), true);
    },
  );

  test(
    'authoring is immutable and toWire returns isolated lists and targets',
    () {
      final c = policy('deferred-targets-selected-order');
      final a = PlanningAuthoring.fromWire(
        c['authoring'],
        repositoryActiveDocument(c['document']),
      );
      expect(() => a.studentOrder.add('x'), throwsUnsupportedError);
      expect(
        () => a.stageOrderByStudent['aru']!.add('x'),
        throwsUnsupportedError,
      );
      expect(
        () => a.deferredStages.first.nullableTargets['level'] = 1,
        throwsUnsupportedError,
      );
      final wire = a.toWire();
      (wire['student_order'] as List).clear();
      (wire['deferred_stages'][0]['targets'] as Map)['level'] = 1;
      expect(a.toWire(), c['canonical']);
    },
  );

  test(
    'mock save preserves omitted metadata, rejects incompatible omission and clears explicitly',
    () async {
      final s = MockAppService();
      addTearDown(s.dispose);
      final pid = (await s.listProfiles()).single.id;
      final c = policy('deferred-targets-selected-order');
      final doc = repositoryActiveDocument(c['document']);
      final a = PlanningAuthoring.fromWire(c['authoring'], doc);
      expect(
        await s.saveRepositoryPlan(
          profileId: pid,
          document: doc,
          authoring: a,
          expectedRevision: 0,
          idempotencyKey: 'save',
        ),
        1,
      );
      expect(
        (await s.loadRepositoryPlan(pid)).authoring.toWire(),
        c['canonical'],
      );
      expect(
        await s.saveRepositoryPlan(
          profileId: pid,
          document: doc,
          expectedRevision: 1,
          idempotencyKey: 'preserve',
        ),
        2,
      );
      expect(
        (await s.loadRepositoryPlan(pid)).authoring.toWire(),
        c['canonical'],
      );
      final empty = repositoryActiveDocument(
        policy('empty-default')['document'],
      );
      await expectLater(
        s.saveRepositoryPlan(
          profileId: pid,
          document: empty,
          expectedRevision: 2,
          idempotencyKey: 'bad',
        ),
        throwsA(
          isA<BackendRemoteException>().having(
            (e) => e.details?['reason'],
            'reason',
            'authoring_required',
          ),
        ),
      );
      expect((await s.loadRepositoryPlan(pid)).revision, 2);
      await s.saveRepositoryPlan(
        profileId: pid,
        document: empty,
        authoring: PlanningAuthoring.defaultForDocument(empty),
        expectedRevision: 2,
        idempotencyKey: 'clear',
      );
      expect((await s.loadRepositoryPlan(pid)).authoring.studentOrder, isEmpty);
    },
  );

  test(
    'mock metadata-only revision, replay and changed-key conflict',
    () async {
      final s = MockAppService();
      addTearDown(s.dispose);
      final pid = (await s.listProfiles()).single.id;
      final c = policy('selected-only');
      final doc = repositoryActiveDocument(c['document']);
      final a = PlanningAuthoring.fromWire(c['authoring'], doc);
      Future<int> save(PlanningAuthoring value) => s.saveRepositoryPlan(
        profileId: pid,
        document: doc,
        authoring: value,
        expectedRevision: 0,
        idempotencyKey: 'metadata',
      );
      expect(await save(a), 1);
      expect(await save(a), 1);
      expect((await s.loadRepositoryState(pid)).goals, isEmpty);
      expect((await s.listProfiles()).single.revision, 1);
      final changed = copy(c['authoring']);
      changed['goal_metadata']['unknown-empty']['notes'] = 'changed';
      await expectLater(
        save(PlanningAuthoring.fromWire(changed, doc)),
        throwsStateError,
      );
      expect((await s.loadRepositoryPlan(pid)).revision, 1);
    },
  );

  test(
    'mock old omitted request replays before new bundle compatibility',
    () async {
      final s = MockAppService();
      addTearDown(s.dispose);
      final pid = (await s.listProfiles()).single.id;
      final doc = repositoryActiveDocument(
        policy('document-default')['document'],
      );
      Future<int> old() => s.saveRepositoryPlan(
        profileId: pid,
        document: doc,
        expectedRevision: 0,
        idempotencyKey: 'old',
      );
      expect(await old(), 1);
      final c = policy('selected-only');
      final next = repositoryActiveDocument(c['document']);
      await s.saveRepositoryPlan(
        profileId: pid,
        document: next,
        expectedRevision: 1,
        idempotencyKey: 'new',
        authoring: PlanningAuthoring.fromWire(c['authoring'], next),
      );
      expect(await old(), 1);
      expect((await s.loadRepositoryPlan(pid)).revision, 2);
    },
  );

  test(
    'mock replace preserves whole bundle and default omission clears new sidecar',
    () async {
      final s = MockAppService();
      addTearDown(s.dispose);
      final pid = (await s.listProfiles()).single.id;
      final c = policy('deferred-targets-selected-order');
      final doc = repositoryActiveDocument(c['document']);
      await s.saveRepositoryPlan(
        profileId: pid,
        document: doc,
        authoring: PlanningAuthoring.fromWire(c['authoring'], doc),
        expectedRevision: 0,
        idempotencyKey: 'save',
      );
      final empty = repositoryActiveDocument(
        policy('empty-default')['document'],
      );
      Future<RepositoryPlanReplaceResult> replace() => s.replaceRepositoryPlan(
        profileId: pid,
        document: empty,
        expectedRevision: 1,
        expectedScenarioRevision: 0,
        idempotencyKey: 'replace',
        archiveName: 'Archive',
        archiveDescription: '',
      );
      final response = await replace();
      expect(response.scenarioRevision, 1);
      expect((await replace()).toWire(), response.toWire());
      final archive = (await s.getScenario(
        pid,
        response.archivedScenarioId!,
      )).scenario;
      expect(archive.authoring.toWire(), c['canonical']);
      expect(archive.document.stages.length, 3);
      expect(
        PlanningScenarioRecord.fromWire(archive.toWire()).authoring.toWire(),
        c['canonical'],
      );
      final active = await s.loadRepositoryPlan(pid);
      expect(active.hasAuthoring, false);
      expect(active.authoring.studentOrder, isEmpty);
      final duplicate = await s.duplicateScenario(
        profileId: pid,
        scenarioId: archive.id,
        expectedRevision: 1,
        expectedScenarioRevision: 0,
        idempotencyKey: 'duplicate',
      );
      expect(
        (await s.getScenario(
          pid,
          duplicate.scenarioId,
        )).scenario.authoring.toWire(),
        c['canonical'],
      );
      await expectLater(
        s.updateScenario(
          profileId: pid,
          scenarioId: archive.id,
          expectedRevision: 2,
          expectedScenarioRevision: 0,
          idempotencyKey: 'bad-update',
          name: 'Bad',
          description: '',
          baseProfileRevision: 2,
          document: PlanningDocument.fromWire({
            ...empty.toWire(),
            'kind': 'scenario',
          }),
        ),
        throwsA(
          isA<BackendRemoteException>().having(
            (e) => e.details?['reason'],
            'reason',
            'authoring_required',
          ),
        ),
      );
    },
  );

  test(
    'mock all-deferred and selected-only plans archive, fully empty skips',
    () async {
      for (final name in ['all-deferred', 'selected-only', 'empty-default']) {
        final s = MockAppService();
        try {
          final pid = (await s.listProfiles()).single.id;
          final c = policy(name);
          final doc = repositoryActiveDocument(c['document']);
          await s.saveRepositoryPlan(
            profileId: pid,
            document: doc,
            authoring: PlanningAuthoring.fromWire(c['authoring'], doc),
            expectedRevision: 0,
            idempotencyKey: 'save',
          );
          expect((await s.loadRepositoryState(pid)).goals, isEmpty);
          final result = await s.replaceRepositoryPlan(
            profileId: pid,
            document: doc,
            expectedRevision: 1,
            expectedScenarioRevision: 0,
            idempotencyKey: 'replace',
            archiveName: 'Old',
            archiveDescription: '',
          );
          expect(result.archivedScenarioId == null, name == 'empty-default');
          expect(result.scenarioRevision, name == 'empty-default' ? 0 : 1);
        } finally {
          await s.dispose();
        }
      }
    },
  );

  test('mock legacy goals writer cannot discard selected students', () async {
    final s = MockAppService();
    addTearDown(s.dispose);
    final pid = (await s.listProfiles()).single.id;
    final c = policy('selected-only');
    final doc = repositoryActiveDocument(c['document']);
    await s.saveRepositoryPlan(
      profileId: pid,
      document: doc,
      authoring: PlanningAuthoring.fromWire(c['authoring'], doc),
      expectedRevision: 0,
      idempotencyKey: 'save',
    );
    await expectLater(
      s.saveRepositoryGoals(
        pid,
        {'version': 1, 'goals': <dynamic>[]},
        1,
        'legacy',
      ),
      throwsStateError,
    );
    expect((await s.loadRepositoryPlan(pid)).revision, 1);
  });
}
