import 'dart:convert';
import 'dart:io';

import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/mock_repository_plan.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:flutter_test/flutter_test.dart';

const pid = 'aaaaaaaaaaaaaaaaaaaaaaaa';
List<Map<String, dynamic>> _fixture(String name) => [
  for (final raw
      in (jsonDecode(
                File('../contracts/fixtures/$name.json').readAsStringSync(),
              )
              as Map)['cases']
          as List)
    Map<String, dynamic>.from(raw as Map),
];
Map<String, dynamic> _copy(Object value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
Map<String, dynamic> _state(Map<String, dynamic> policy) => {
  'profile_id': pid,
  'revision': 4,
  'students': policy['students'] ?? [],
  'inventory': {'version': 1, 'entries': <dynamic>[]},
  'goals': policy['legacy_goals'],
};
MockAppService _legacy(Map<String, dynamic> policy) => MockAppService(
  profiles: const [
    RepositoryProfile(
      id: pid,
      displayName: 'Legacy',
      revision: 4,
      selected: true,
    ),
  ],
  repositoryStates: {pid: _state(policy)},
);

class _UnavailableCalculation extends MockAppService {
  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async => throw StateError('calculation unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final policies = _fixture('repository_plan_migration_v1');
  test(
    'mock calculation failure keeps the stored document retrievable',
    () async {
      final service = _UnavailableCalculation();
      addTearDown(service.dispose);
      final profile = (await service.listProfiles()).single;
      final plan = await service.loadRepositoryPlan(profile.id);
      expect(plan.calculation, isNull);
      expect(plan.document.phases, isEmpty);
      expect(plan.revision, 0);
    },
  );
  Map<String, dynamic> policy(String id) =>
      policies.singleWhere((p) => p['id'] == id);

  test(
    'shared request/response fixture matches strict repository validation',
    () {
      for (final value in _fixture('repository_plan_v1')) {
        expect(
          isValidRepositoryProtocolMessage(_copy(value['message'] as Map)),
          value['valid'],
          reason: value['id'] as String,
        );
      }
    },
  );

  test(
    'mock conversion matches frozen policies without filling current values',
    () {
      for (final p in policies.where(
        (p) => p.containsKey('expected_document'),
      )) {
        final doc = mockDocumentFromGoals(_copy(p['legacy_goals'] as Map));
        expect(doc.toWire(), p['expected_document'], reason: p['id'] as String);
        expect(mockGoalsFromDocument(doc), p['expected_goals']);
      }
    },
  );

  test(
    'nullable active document and metadata are immutable and strictly typed',
    () {
      final wire = {
        'profile_id': pid,
        'revision': 5,
        'document': _copy(policy('all_null_goal')['expected_document'] as Map),
        'calculation': null,
      };
      final state = RepositoryPlanState.fromWire(wire);
      expect(state.calculation, isNull);
      expect(state.document.stages.single.nullableTargets['bond_rank'], isNull);
      expect(state.document.goalMetadata['aru']!.favorite, isFalse);
      expect(state.document.goalMetadata['aru']!.notes, '  남겨 둘 메모  ');
      (wire['document'] as Map)['goal_metadata']['aru']['notes'] = 'mutated';
      expect(state.document.goalMetadata['aru']!.notes, '  남겨 둘 메모  ');
      expect(
        () => state.document.stages.single.nullableTargets['level'] = 90,
        throwsUnsupportedError,
      );
      expect(() => state.document.phases.clear(), throwsUnsupportedError);
      for (final invalid in [
        {...wire, 'revision': true},
        {...wire, 'extra': 0},
        {'profile_id': pid, 'revision': 0, 'document': state.document.toWire()},
        {
          ...wire,
          'document': {...state.document.toWire(), 'kind': 'scenario'},
        },
      ]) {
        expect(
          () => RepositoryPlanState.fromWire(invalid),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'mock first mutation migrates once and rejects the old revision',
    () async {
      final service = _legacy(policy('empty_legacy'));
      addTearDown(service.dispose);
      await expectLater(
        service.renameProfile(pid, 'Too early', 4, 'rename'),
        throwsStateError,
      );
      expect((await service.loadRepositoryPlan(pid)).revision, 5);
      expect((await service.listProfiles()).single.displayName, 'Legacy');
      await expectLater(
        service.saveRepositoryStudents(pid, [], 4, 'students'),
        throwsStateError,
      );
      await expectLater(
        service.saveRepositoryInventory(
          pid,
          RepositoryInventoryState.fromEntries([]),
          4,
          'inventory',
        ),
        throwsStateError,
      );
      expect((await service.loadRepositoryState(pid)).revision, 5);
    },
  );

  test('save serialization rejects v1 and invalid IDs before dispatch', () {
    final doc = repositoryActiveDocument(
      policy('empty_legacy')['expected_document'],
    );
    final request = RepositoryPlanSaveRequest(
      profileId: pid,
      expectedRevision: 5,
      idempotencyKey: 'save',
      document: doc,
    );
    expect(request.toWire()['document'], doc.toWire());
    expect(request.toWire()['expected_revision'], 5);
    for (final bad in [
      RepositoryPlanSaveRequest(
        profileId: 'bad',
        expectedRevision: 5,
        idempotencyKey: 'save',
        document: doc,
      ),
      RepositoryPlanSaveRequest(
        profileId: pid,
        expectedRevision: -1,
        idempotencyKey: 'save',
        document: doc,
      ),
      RepositoryPlanSaveRequest(
        profileId: pid,
        expectedRevision: 5,
        idempotencyKey: '',
        document: doc,
      ),
      RepositoryPlanSaveRequest(
        profileId: pid,
        expectedRevision: 5,
        idempotencyKey: 'save',
        document: PlanningDocument(
          id: 'old',
          name: 'Old',
          kind: PlanningDocumentKind.plan,
          phases: const [],
        ),
      ),
    ]) {
      expect(bad.toWire, throwsFormatException);
    }
  });

  test(
    'mock profile/current/inventory changes keep plan targets and revision aligned',
    () async {
      final service = _legacy(policy('empty_legacy'));
      addTearDown(service.dispose);
      await service.loadRepositoryPlan(pid);
      final doc = repositoryActiveDocument(
        policy('partial_goal_explicit_zero')['expected_document'],
      );
      await service.saveRepositoryPlan(
        profileId: pid,
        document: doc,
        expectedRevision: 5,
        idempotencyKey: 'plan',
      );
      final current = ConfirmedStudentState.fromWire({
        'version': 1,
        'student_id': 'aru',
        'values': {'level': 30, 'bond_rank': null},
      });
      expect(
        await service.saveRepositoryStudents(pid, [current], 6, 'current'),
        7,
      );
      expect(
        await service.saveRepositoryInventory(
          pid,
          RepositoryInventoryState.fromEntries([]),
          7,
          'inventory',
        ),
        8,
      );
      expect(await service.renameProfile(pid, 'Changed', 8, 'rename'), 9);
      expect(await service.selectProfile(pid, 9, 'select'), 10);
      expect(
        await service.updateProfile(pid, 'Changed', 'aru', 10, 'profile'),
        11,
      );
      expect(
        (await service.loadRepositoryPlan(pid)).document.toWire(),
        doc.toWire(),
      );
      expect((await service.loadRepositoryPlan(pid)).revision, 11);
      expect((await service.loadRepositoryState(pid)).revision, 11);
      expect((await service.listProfiles()).single.revision, 11);
    },
  );

  test('get calculation summary rejects unknown and invalid nested fields', () {
    final fixture = _fixture(
      'repository_plan_v1',
    ).singleWhere((p) => p['id'] == 'get_empty_calculation');
    final payload = _copy(fixture['message']['payload'] as Map);
    expect(RepositoryPlanState.fromWire(payload).calculation!.credits, 0);
    for (final bad in [
      {...payload['calculation'] as Map, 'credits': true},
      {...payload['calculation'] as Map, 'extra': 1},
      {
        ...payload['calculation'] as Map,
        'representative_shortage': {'shortage': 0},
      },
    ]) {
      expect(
        () => RepositoryPlanState.fromWire({...payload, 'calculation': bad}),
        throwsFormatException,
      );
    }
  });

  test(
    'legacy mock first get migrates once and refreshes catalog revision',
    () async {
      final p = policy('null_bond_known_current');
      final service = _legacy(p);
      addTearDown(service.dispose);
      final state = await service.loadRepositoryState(pid);
      expect(state.revision, 5);
      expect(
        (await service.loadRepositoryPlan(pid)).document.toWire(),
        p['expected_document'],
      );
      expect((await service.loadRepositoryPlan(pid)).revision, 5);
      expect((await service.listProfiles()).single.revision, 5);
      expect(state.goals.single.values['target_level'], 10);
      expect(state.students.single.values['bond_rank'], 35);
    },
  );

  test(
    'duplicate legacy mock is an explicit conflict and retains original input',
    () async {
      final p = policy('duplicate_goals');
      final before = jsonEncode(p);
      final service = _legacy(p);
      addTearDown(service.dispose);
      await expectLater(
        service.loadRepositoryPlan(pid),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'code',
            'legacy_goals_conflict',
          ),
        ),
      );
      expect((await service.listProfiles()).single.revision, 4);
      expect(jsonEncode(p), before);
    },
  );

  test(
    'plan save is atomic for document/goals and idempotent after later writes',
    () async {
      final service = _legacy(policy('empty_legacy'));
      addTearDown(service.dispose);
      await service.loadRepositoryPlan(pid);
      final doc = repositoryActiveDocument(
        policy('partial_goal_explicit_zero')['expected_document'],
      );
      Future<int> save(PlanningDocument value, int revision, String key) =>
          service.saveRepositoryPlan(
            profileId: pid,
            document: value,
            expectedRevision: revision,
            idempotencyKey: key,
          );
      expect(await save(doc, 5, 'once'), 6);
      expect(await save(doc, 5, 'once'), 6);
      await expectLater(save(doc, 5, 'stale'), throwsStateError);
      final empty = repositoryActiveDocument(
        policy('empty_legacy')['expected_document'],
      );
      await expectLater(save(empty, 5, 'once'), throwsStateError);
      expect(await save(empty, 6, 'empty'), 7);
      expect(await save(doc, 5, 'once'), 6);
      expect((await service.loadRepositoryState(pid)).goals, isEmpty);
      expect((await service.loadRepositoryPlan(pid)).document.phases, isEmpty);
      expect((await service.loadRepositoryPlan(pid)).revision, 7);
    },
  );

  test(
    'legacy save shares conversion and rejects multi phase, stage and bond loss',
    () async {
      final service = _legacy(policy('empty_legacy'));
      addTearDown(service.dispose);
      await service.loadRepositoryPlan(pid);
      final p = policy('partial_goal_explicit_zero');
      expect(
        await service.saveRepositoryGoals(
          pid,
          _copy(p['legacy_goals'] as Map),
          5,
          'goals',
        ),
        6,
      );
      expect(
        (await service.loadRepositoryPlan(pid)).document.toWire(),
        p['expected_document'],
      );
      for (final reason in ['phase', 'stage', 'bond']) {
        final wire = _copy(p['expected_document'] as Map);
        final stages = wire['phases'][0]['stages'] as List;
        if (reason == 'phase') {
          (wire['phases'] as List).add({
            'phase_id': 'second',
            'name': 'Second',
            'stages': [],
          });
        } else if (reason == 'stage') {
          stages.add({..._copy(stages.single as Map), 'stage_id': 'later'});
        } else {
          stages.single['targets']['bond_rank'] = 20;
        }
        final revision = (await service.loadRepositoryPlan(pid)).revision;
        await service.saveRepositoryPlan(
          profileId: pid,
          document: repositoryActiveDocument(wire),
          expectedRevision: revision,
          idempotencyKey: reason,
        );
        await expectLater(
          service.saveRepositoryGoals(
            pid,
            {'version': 1, 'goals': []},
            revision + 1,
            'loss-$reason',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'code',
              'plan_lossy_write',
            ),
          ),
        );
        expect((await service.loadRepositoryPlan(pid)).document.toWire(), wire);
      }
      expect(
        await service.saveRepositoryGoals(
          pid,
          _copy(p['legacy_goals'] as Map),
          5,
          'goals',
        ),
        6,
      );
    },
  );

  test('final stage keeps first student order and document-only bond goal', () {
    final wire = _copy(
      policy('null_bond_unknown_current')['expected_document'] as Map,
    );
    final stages = wire['phases'][0]['stages'] as List;
    stages.add({
      ..._copy(stages.first as Map),
      'stage_id': 'ayane',
      'student_id': 'ayane',
    });
    stages.add({
      ..._copy(stages.first as Map),
      'stage_id': 'last',
      'targets': {
        ...stages.first['targets'] as Map,
        'level': 20,
        'bond_rank': 40,
      },
    });
    wire['goal_metadata']['ayane'] = {'favorite': false, 'notes': 'other'};
    final goals =
        mockGoalsFromDocument(repositoryActiveDocument(wire))['goals'] as List;
    expect(goals.map((g) => g['student_id']), ['aru', 'ayane']);
    expect(goals.first['target_level'], 20);
    expect(goals.last['favorite'], isFalse);
    expect(goals.first.containsKey('bond_rank'), isFalse);
  });
}
