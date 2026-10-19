// 계획 만들기 4단계 저장 테스트(FE4-e): 병합 문서(페이즈로 추가, v2 null 유지·퇴행 차단), FD-031 충족률, 비교 읽기,
// 저장 3지선다의 서비스 연결(시나리오 = createScenario, 페이즈로 추가 = plan.save, 이걸로 바꾸기 = plan.replace),
// 실패 처리(revision_conflict·authoring_required → 초안을 두고 다시 읽기, 연결 끊김 → 같은 키·같은 문서로 다시 보내기,
// idempotency_conflict → 새 키를 만들지 않음), A 레일 primary 글자 = C 선택(FD-079).
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/repository_service.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/kit/buttons.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_save.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileId = '000000000000000000000001';

typedef _PlanSave = ({
  PlanningDocument document,
  PlanningAuthoring? authoring,
  int expectedRevision,
  String key,
});

typedef _Replace = ({
  PlanningDocument document,
  PlanningAuthoring? authoring,
  int expectedRevision,
  int expectedScenarioRevision,
  String key,
  String archiveName,
  String archiveDescription,
});

typedef _Create = ({
  PlanningDocument document,
  PlanningAuthoring? authoring,
  int expectedRevision,
  int baseProfileRevision,
  String key,
  String name,
  String description,
});

/// 저장 요청을 기록하고, [failures]가 있으면 그 오류를 하나씩 먼저 던지는 mock.
class _RecordingService extends MockAppService {
  final planSaves = <_PlanSave>[];
  final replaces = <_Replace>[];
  final creates = <_Create>[];
  final failures = <Object>[];

  @override
  Future<int> saveRepositoryPlan({
    required String profileId,
    required PlanningDocument document,
    PlanningAuthoring? authoring,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    planSaves.add((
      document: document,
      authoring: authoring,
      expectedRevision: expectedRevision,
      key: idempotencyKey,
    ));
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return super.saveRepositoryPlan(
      profileId: profileId,
      document: document,
      authoring: authoring,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<RepositoryPlanReplaceResult> replaceRepositoryPlan({
    required String profileId,
    required PlanningDocument document,
    PlanningAuthoring? authoring,
    required int expectedRevision,
    required int expectedScenarioRevision,
    required String idempotencyKey,
    required String archiveName,
    required String archiveDescription,
  }) async {
    replaces.add((
      document: document,
      authoring: authoring,
      expectedRevision: expectedRevision,
      expectedScenarioRevision: expectedScenarioRevision,
      key: idempotencyKey,
      archiveName: archiveName,
      archiveDescription: archiveDescription,
    ));
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return super.replaceRepositoryPlan(
      profileId: profileId,
      document: document,
      authoring: authoring,
      expectedRevision: expectedRevision,
      expectedScenarioRevision: expectedScenarioRevision,
      idempotencyKey: idempotencyKey,
      archiveName: archiveName,
      archiveDescription: archiveDescription,
    );
  }

  @override
  Future<PlanningScenarioMutationResult> createScenario({
    required String profileId,
    required int expectedRevision,
    required String idempotencyKey,
    required String name,
    required String description,
    required int baseProfileRevision,
    required PlanningDocument document,
    PlanningAuthoring? authoring,
  }) async {
    creates.add((
      document: document,
      authoring: authoring,
      expectedRevision: expectedRevision,
      baseProfileRevision: baseProfileRevision,
      key: idempotencyKey,
      name: name,
      description: description,
    ));
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return super.createScenario(
      profileId: profileId,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
      name: name,
      description: description,
      baseProfileRevision: baseProfileRevision,
      document: document,
      authoring: authoring,
    );
  }
}

PlanningStudentSeed _seed(String studentId) => PlanningStudentSeed(
  handoffId: 'seed-$studentId',
  studentId: studentId,
  metadata: const {},
  currentValues: const {},
);

/// 학생마다 단계 목표(v2, 적지 않은 키는 null). 단계 번호마다 칸 하나("n순위", id `flow-phase-n`).
PlanFlowDraft _draft(Map<String, List<Map<String, int?>>> stagesByStudent) {
  final steps = stagesByStudent.values.fold<int>(
    0,
    (max, stages) => stages.length > max ? stages.length : max,
  );
  return PlanFlowDraft(
    students: [for (final studentId in stagesByStudent.keys) _seed(studentId)],
    stagesByStudent: {
      for (final entry in stagesByStudent.entries)
        entry.key: [
          for (final (index, targets) in entry.value.indexed)
            PlanFlowStageDraft(
              id: '${entry.key}-stage-${index + 1}',
              name: '${index + 1}단계',
              targets: targets,
            ),
        ],
    },
    phases: [
      for (var step = 1; step <= steps; step++)
        PlanFlowPhase(
          id: 'flow-phase-$step',
          name: '$step순위',
          stageIds: [
            for (final entry in stagesByStudent.entries)
              if (entry.value.length >= step) '${entry.key}-stage-$step',
          ],
        ),
    ],
  );
}

/// 활성 계획 문서(학생마다 한 단계, 칸 하나 `flow-phase-1`). 초안과 같은 id를 써서 id 겹침을 시험한다.
PlanningDocument _activeDocument(
  Map<String, Map<String, int?>> targetsByStudent, {
  String id = 'active-plan',
  String name = '활성 계획',
  Map<String, PlanningGoalMetadata> goalMetadata = const {},
}) => PlanningDocument(
  id: id,
  name: name,
  kind: PlanningDocumentKind.plan,
  version: 2,
  phases: [
    if (targetsByStudent.isNotEmpty)
      PlanningDocumentPhase(
        id: 'flow-phase-1',
        name: '1순위',
        stages: [
          for (final entry in targetsByStudent.entries)
            PlanningDocumentStage(
              id: '${entry.key}-stage-1',
              studentId: entry.key,
              name: '1단계',
              targets: {
                for (final key in planningDocumentTargetKeys)
                  key: entry.value[key],
              },
            ),
        ],
      ),
  ],
  goalMetadata: {
    for (final studentId in targetsByStudent.keys)
      studentId: goalMetadata[studentId] ?? planFlowDefaultGoalMetadata,
  },
);

/// mock의 활성 계획을 [targetsByStudent]로 바꾼다(plan.save). 새 revision을 준다.
Future<int> _seedActive(
  MockAppService service,
  Map<String, Map<String, int?>> targetsByStudent,
) async {
  final plan = await service.loadRepositoryPlan(_profileId);
  return service.saveRepositoryPlan(
    profileId: _profileId,
    document: _activeDocument(
      targetsByStudent,
      id: plan.document.id,
      name: plan.document.name,
    ),
    expectedRevision: plan.revision,
    idempotencyKey: 'seed-${plan.revision}',
  );
}

Future<PlanFlowController> _flow(
  MockAppService service,
  PlanFlowDraft draft, {
  PlanFlowStep step = PlanFlowStep.order,
}) async {
  final state = await service.loadRepositoryState(_profileId);
  final catalog = await service.listStudents();
  final flow = PlanFlowController(
    purpose: PlanFlowPurpose.newScenario,
    context: PlanFlowContext(
      repositoryState: state,
      catalog: {for (final entry in catalog) entry.studentId: entry},
    ),
    service: service,
    initialDraft: draft,
    initialStep: step,
  );
  addTearDown(flow.dispose);
  return flow;
}

/// 19키 nullable 목표(적지 않은 키는 null).
Map<String, int?> _targets(Map<String, int?> values) => {
  for (final key in planningDocumentTargetKeys) key: values[key],
};

/// 활성 "나중에" 칸 단계 하나(FE4-g4).
PlanningDocumentStage _laterStage(
  String id,
  String studentId,
  Map<String, int?> targets, {
  String name = '나중',
}) => PlanningDocumentStage(
  id: id,
  studentId: studentId,
  name: name,
  targets: _targets(targets),
);

/// [document]에 [later](활성 나중에 칸 단계, 체인 순서)를 더한 활성 authoring(공용 validator로 만든다).
PlanningAuthoring _activeAuthoring(
  PlanningDocument document,
  List<PlanningDocumentStage> later,
) {
  final order = [
    ...{
      for (final stage in document.stages) stage.studentId,
      for (final stage in later) stage.studentId,
    },
  ];
  final placed = {for (final stage in document.stages) stage.studentId};
  return PlanningAuthoring.fromWire({
    'version': 1,
    'prerequisites': const <Object>[],
    'deferred_stages': [for (final stage in later) stage.toWire()],
    'student_order': order,
    'stage_order_by_student': {
      for (final studentId in order)
        studentId: [
          for (final stage in document.stages)
            if (stage.studentId == studentId) stage.id,
          for (final stage in later)
            if (stage.studentId == studentId) stage.id,
        ],
    },
    'goal_metadata': {
      for (final studentId in order)
        if (!placed.contains(studentId))
          studentId: planFlowDefaultGoalMetadata.toWire(),
    },
  }, document);
}

/// mock 활성 계획을 [targetsByStudent](배치) + [later](나중에 칸)로 바꾼다. 새 revision을 준다.
Future<int> _seedActiveWithLater(
  MockAppService service,
  Map<String, Map<String, int?>> targetsByStudent,
  List<PlanningDocumentStage> later,
) async {
  final plan = await service.loadRepositoryPlan(_profileId);
  final document = _activeDocument(
    targetsByStudent,
    id: plan.document.id,
    name: plan.document.name,
  );
  return service.saveRepositoryPlan(
    profileId: _profileId,
    document: document,
    authoring: _activeAuthoring(document, later),
    expectedRevision: plan.revision,
    idempotencyKey: 'seed-later-${plan.revision}',
  );
}

/// 저장 상태를 만들고 저장 직전 상태를 읽는다(흐름은 3단계에 둬서 저절로 읽지 않게 한다).
Future<PlanFlowSaveController> _save(PlanFlowController flow) async {
  final save = PlanFlowSaveController(flow: flow);
  addTearDown(save.dispose);
  await save.reload();
  return save;
}

/// 다시 읽기·비교가 끝날 때까지 microtask를 돌린다.
Future<void> _idle(PlanFlowSaveController save) async {
  for (var index = 0; index < 50; index++) {
    await Future<void>.delayed(Duration.zero);
    if (!save.loading && !save.comparing) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('병합 문서(페이즈로 추가)', () {
    test('활성 페이즈 뒤에 초안 페이즈를 붙이고 v2 null은 활성에서 정한 키만 이어 받는다', () {
      final active = _activeDocument(
        {
          'aru': {'level': 50, 'skill1': 4},
        },
        goalMetadata: {
          'aru': const PlanningGoalMetadata(favorite: true, notes: '활성'),
        },
      );
      final draft = _draft({
        'aru': [
          {'level': 70},
        ],
        'hoshino': [
          {'level': 30},
        ],
      });
      final merged = planFlowMergedPlanDocument(
        active: active,
        draft: draft,
        id: active.id,
        name: active.name,
      );
      expect(merged.blocked, isFalse);
      final document = merged.document!;
      expect(document.kind, PlanningDocumentKind.plan);
      expect(document.version, 2);
      expect(document.id, 'active-plan');
      expect(document.phases.map((phase) => phase.id), [
        'flow-phase-1',
        'flow-phase-1-2',
      ]);
      expect(merged.phaseIds, {'flow-phase-1': 'flow-phase-1-2'});
      final added = {
        for (final stage in document.phases.last.stages) stage.studentId: stage,
      };
      expect(added['aru']!.id, 'aru-stage-1-2');
      expect(added['hoshino']!.id, 'hoshino-stage-1');
      // 초안 값은 그대로, 활성에서 정한 skill1만 이어 받고, 아무도 정하지 않은 키는 null로 남는다.
      expect(added['aru']!.nullableTargets['level'], 70);
      expect(added['aru']!.nullableTargets['skill1'], 4);
      expect(added['aru']!.nullableTargets['ex_skill'], isNull);
      expect(added['hoshino']!.nullableTargets['level'], 30);
      expect(added['hoshino']!.nullableTargets['skill1'], isNull);
      expect(document.goalMetadata.keys.toSet(), {'aru', 'hoshino'});
      expect(document.goalMetadata['aru']!.notes, '활성');
      expect(document.goalMetadata['hoshino'], planFlowDefaultGoalMetadata);
      // 저장 경계(v2 kind=plan, 퇴행 없음)를 통과한다.
      expect(repositoryActiveDocument(document.toWire()).phases, hasLength(2));
    });

    test('초안 목표가 활성 목표보다 낮으면 문서를 만들지 않고 학생을 알린다', () {
      final merged = planFlowMergedPlanDocument(
        active: _activeDocument({
          'aru': {'level': 50},
        }),
        draft: _draft({
          'aru': [
            {'level': 40},
          ],
          'hoshino': [
            {'level': 30},
          ],
        }),
        id: 'active-plan',
        name: '활성 계획',
      );
      expect(merged.blocked, isTrue);
      expect(merged.document, isNull);
      expect(merged.regressedStudentIds, ['aru']);
    });
  });

  group('비교(FD-031 (a), FD-080)', () {
    test('충족률은 min(보유, 필요)/필요의 평균이고 보유를 모르는 재화는 빼고 센다', () {
      final rows = <Map<String, dynamic>>[
        {'required_a': 100, 'required_b': 100, 'owned': 50},
        {'required_a': 0, 'required_b': 10, 'owned': 20},
        {'required_a': 10, 'required_b': 10, 'owned': null},
      ];
      final a = planFlowFulfillment(rows, 'a');
      expect(a.rate, closeTo(0.5, 1e-9));
      expect(a.unknown, 1);
      final b = planFlowFulfillment(rows, 'b');
      expect(b.rate, closeTo(0.75, 1e-9));
      expect(b.unknown, 1);
      expect(planFlowFulfillment(const [], 'a').rate, isNull);
    });

    test('비교 응답에서 타일 값과 크게 늘어나는 재화 3개를 읽는다', () {
      Map<String, dynamic> resource(
        String key,
        int requiredA,
        int requiredB, {
        int? owned,
      }) => {
        'resource_key': key,
        'item_id': key,
        'display_name': key,
        'category': 'oopart',
        'owned': owned,
        'required_a': requiredA,
        'required_b': requiredB,
        'required_delta_b_minus_a': requiredB - requiredA,
        'shortage_a': owned == null ? null : (requiredA - owned).clamp(0, 1 << 30),
        'shortage_b': owned == null ? null : (requiredB - owned).clamp(0, 1 << 30),
      };
      final comparison = PlanFlowSaveComparison.fromResult(
        PlanningScenarioComparisonResult(
          projectionA: const {},
          projectionB: {
            'phase_results': [
              {
                'phase_id': 'flow-phase-1',
                'resources': [
                  {
                    'resource_key': 'note',
                    'item_id': 'note',
                    'display_name': '노트',
                    'category': 'oopart',
                    'required': 96,
                    'owned': 66,
                    'shortage': 30,
                  },
                ],
              },
            ],
          },
          comparison: {
            'credits_a': 100,
            'credits_b': 250,
            'known_shortage_type_count_a': 1,
            'known_shortage_type_count_b': 3,
            'students': [
              {'student_id': 'aru', 'presence': 'both'},
              {'student_id': 'hoshino', 'presence': 'b_only'},
              {'student_id': 'shun', 'presence': 'a_only'},
            ],
            'resources': [
              resource('a', 10, 20, owned: 15),
              resource('b', 10, 110, owned: 50),
              resource('c', 10, 40),
              resource('d', 10, 5, owned: 50),
              resource('e', 0, 2, owned: 0),
            ],
          },
        ),
      );
      expect(comparison.creditsA, 100);
      expect(comparison.creditsB, 250);
      expect(comparison.shortageKindsA, 1);
      expect(comparison.shortageKindsB, 3);
      expect(comparison.studentsA, 2);
      expect(comparison.studentsB, 2);
      expect(comparison.increases.map((item) => item.resourceKey), [
        'b',
        'c',
        'a',
      ]);
      expect(comparison.increases.first.shortageB, 60);
      expect(comparison.increases[1].coverage, isNull);
      final phase = comparison.phaseResourcesB['flow-phase-1']!.single;
      expect(phase.ownedAtEntry, 66);
      expect(phase.shortageAtEntry, 30);
    });
  });

  group('가장 크게 늘어나는 재화(FE5-c2)', () {
    test('크레딧 줄은 재화 증가 목록에 넣지 않는다(크레딧 KPI에서 필요량 차이로 보인다, FD-038)', () {
      final comparison = PlanFlowSaveComparison.fromResult(
        const PlanningScenarioComparisonResult(
          projectionA: {},
          projectionB: {},
          comparison: {
            'credits_a': 1000000,
            'credits_b': 9000000,
            'resources': [
              {
                'resource_key': 'credits',
                'item_id': null,
                'display_name': '크레딧',
                'category': 'credits',
                'owned': 5000000,
                'required_a': 1000000,
                'required_b': 9000000,
                'required_delta_b_minus_a': 8000000,
                'shortage_a': 0,
                'shortage_b': 4000000,
              },
              {
                'resource_key': 'note',
                'item_id': 'note',
                'display_name': '노트',
                'category': 'tech_notes',
                'owned': 10,
                'required_a': 10,
                'required_b': 40,
                'required_delta_b_minus_a': 30,
                'shortage_a': 0,
                'shortage_b': 30,
              },
            ],
          },
        ),
      );
      expect(comparison.increases.map((item) => item.resourceKey), ['note']);
      // 크레딧은 KPI 쪽 값으로 남는다.
      expect(comparison.creditsB, 9000000);
    });
  });

  group('저장 3지선다', () {
    test('시나리오로 저장: 패널 이름으로 createScenario, 문서는 v2 초안 그대로다', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      final flow = await _flow(
        service,
        _draft({
          'aru': [
            {'level': 70},
          ],
        }),
      );
      final save = await _save(flow);
      expect(save.target, PlanFlowSaveTarget.scenario);
      expect(save.scenarioName, '새 시나리오 1');
      save.scenarioName = '총력전 준비';
      final snapshot = save.snapshot!;
      final outcome = await save.save();
      expect(outcome, isNotNull);
      expect(outcome!.target, PlanFlowSaveTarget.scenario);
      expect(outcome.changedActivePlan, isFalse);
      expect(outcome.openScenarioList, isTrue);
      final create = service.creates.single;
      expect(create.name, '총력전 준비');
      expect(create.description, '');
      expect(create.expectedRevision, snapshot.scenarioRevision);
      expect(create.baseProfileRevision, snapshot.revision);
      expect(create.key, startsWith('plan-flow-save-scenario-'));
      expect(create.document.kind, PlanningDocumentKind.scenario);
      expect(create.document.version, 2);
      final stage = create.document.stages.single;
      expect(stage.nullableTargets['level'], 70);
      expect(stage.nullableTargets['ex_skill'], isNull);
      // FE4-f1: authoring 전체를 함께 보낸다(여기서는 문서 기본값과 같다).
      expect(create.authoring, isNotNull);
      expect(create.authoring!.studentOrder, ['aru']);
      expect(create.authoring!.stageOrderByStudent['aru'], [stage.id]);
      expect(create.authoring!.isDefaultForDocument(create.document), isTrue);
      expect(service.planSaves, isEmpty);
      expect(service.replaces, isEmpty);
    });

    test('페이즈로 추가: plan.save(활성 + 새 페이즈, plan.get revision), 활성 authoring과 합친 authoring을 보낸다', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _seedActive(service, {
        'aru': {'level': 50},
      });
      service.planSaves.clear();
      final flow = await _flow(
        service,
        _draft({
          'aru': [
            {'level': 70, 'ex_skill': 3},
          ],
        }),
      );
      final save = await _save(flow);
      expect(save.isAvailable(PlanFlowSaveTarget.appendPhases), isTrue);
      expect(
        planFlowSaveTargetSubtitle(
          PlanFlowSaveTarget.appendPhases,
          save: save,
          newPhaseCount: 1,
        ),
        '지금 P1 뒤에 P2로 붙입니다',
      );
      save.selectTarget(PlanFlowSaveTarget.appendPhases);
      final revision = save.snapshot!.revision;
      final plan = await service.loadRepositoryPlan(_profileId);
      expect(plan.revision, revision);
      final outcome = await save.save();
      expect(outcome, isNotNull);
      expect(outcome!.changedActivePlan, isTrue);
      final request = service.planSaves.single;
      expect(request.expectedRevision, revision);
      // FE4-f1: 초안 단계 id가 활성 단계 id와 겹쳐 바꾼 id가 학생 체인에도 들어간다.
      expect(request.authoring, isNotNull);
      expect(request.authoring!.studentOrder, ['aru']);
      expect(request.authoring!.stageOrderByStudent['aru'], [
        'aru-stage-1',
        'aru-stage-1-2',
      ]);
      expect(request.key, startsWith('plan-flow-save-appendPhases-'));
      expect(request.document.id, plan.document.id);
      expect(request.document.phases, hasLength(2));
      final added = request.document.phases.last.stages.single;
      expect(added.nullableTargets['level'], 70);
      expect(added.nullableTargets['ex_skill'], 3);
      expect(added.nullableTargets['skill1'], isNull);
      final saved = await service.loadRepositoryPlan(_profileId);
      expect(saved.revision, revision + 1);
      expect(saved.document.phases, hasLength(2));
      expect(service.creates, isEmpty);
    });

    test('페이즈로 추가: 활성 목표보다 낮은 단계가 있으면 고를 수 없다', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _seedActive(service, {
        'aru': {'level': 50},
      });
      final flow = await _flow(
        service,
        _draft({
          'aru': [
            {'level': 40},
          ],
        }),
      );
      final save = await _save(flow);
      expect(save.isAvailable(PlanFlowSaveTarget.appendPhases), isFalse);
      expect(
        save.unavailableReason(PlanFlowSaveTarget.appendPhases),
        contains('활성 계획보다 낮아'),
      );
      save.selectTarget(PlanFlowSaveTarget.appendPhases);
      expect(save.target, PlanFlowSaveTarget.scenario);
    });

    test('이걸로 바꾸기: 빈 활성 계획이면 옮겨 둔 시나리오가 없다(archivedScenarioId null)', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      final flow = await _flow(
        service,
        _draft({
          'aru': [
            {'level': 70},
          ],
        }),
      );
      final save = await _save(flow);
      save.selectTarget(PlanFlowSaveTarget.replace);
      expect(save.target, PlanFlowSaveTarget.replace);
      final snapshot = save.snapshot!;
      final outcome = await save.save();
      expect(outcome, isNotNull);
      expect(outcome!.archivedScenarioId, isNull);
      expect(outcome.message, '활성 계획을 바꿨습니다.');
      final request = service.replaces.single;
      expect(request.expectedRevision, snapshot.revision);
      expect(request.expectedScenarioRevision, snapshot.scenarioRevision);
      expect(request.archiveName, planFlowDefaultArchiveName);
      expect(request.archiveDescription, '');
      expect(request.authoring, isNotNull);
      expect(request.authoring!.deferredStages, isEmpty);
      expect(request.document.kind, PlanningDocumentKind.plan);
      expect(request.document.stages.single.nullableTargets['skill1'], isNull);
      expect((await service.listScenarios(_profileId)).scenarios, isEmpty);
    });

    test('이걸로 바꾸기: 기존 활성 계획은 고친 이름의 시나리오로 옮겨 둔다', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _seedActive(service, {
        'aru': {'level': 50},
      });
      final flow = await _flow(
        service,
        _draft({
          'hoshino': [
            {'level': 30},
          ],
        }),
      );
      final save = await _save(flow);
      save
        ..selectTarget(PlanFlowSaveTarget.replace)
        ..archiveName = '지난 총력전 계획';
      final outcome = await save.save();
      expect(outcome!.archivedScenarioId, isNotNull);
      final list = await service.listScenarios(_profileId);
      expect(list.scenarios.single.name, '지난 총력전 계획');
      final active = await service.loadRepositoryPlan(_profileId);
      expect(active.document.stages.single.studentId, 'hoshino');
    });
  });

  group('저장 실패', () {
    test('revision_conflict: 초안은 두고 최신 상태를 다시 읽어 알린다', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _seedActive(service, {
        'aru': {'level': 50},
      });
      final draft = _draft({
        'aru': [
          {'level': 70},
        ],
      });
      final flow = await _flow(service, draft);
      final save = await _save(flow);
      save.selectTarget(PlanFlowSaveTarget.appendPhases);
      // 다른 곳에서 활성 계획을 바꾼다.
      final latest = await _seedActive(service, {
        'aru': {'level': 60},
      });
      service.planSaves.clear();
      expect(await save.save(), isNull);
      await _idle(save);
      expect(service.planSaves, hasLength(1));
      expect(save.message, contains('최신 상태를 다시 읽었습니다'));
      expect(save.messageIsError, isTrue);
      expect(save.pendingRequest, isNull);
      expect(save.snapshot!.revision, latest);
      expect(identical(flow.draft, draft), isTrue);
      // 다시 누르면 새 revision으로 보낸다.
      final outcome = await save.save();
      expect(outcome, isNotNull);
      expect(service.planSaves.last.expectedRevision, latest);
      expect(service.planSaves.last.key, isNot(service.planSaves.first.key));
    });

    test('authoring_required: 저장하지 않고 다시 읽어 알린다', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _seedActive(service, {
        'aru': {'level': 50},
      });
      final flow = await _flow(
        service,
        _draft({
          'aru': [
            {'level': 70},
          ],
        }),
      );
      final save = await _save(flow);
      save.selectTarget(PlanFlowSaveTarget.appendPhases);
      final before = save.snapshot;
      service.failures.add(
        BackendRemoteException(
          code: 'invalid_payload',
          message: 'authoring does not match',
          details: {
            'reason': 'authoring_required',
            'authoring_reason': 'unknown_stage',
          },
        ),
      );
      expect(await save.save(), isNull);
      await _idle(save);
      expect(save.message, contains('페이즈 편집 정보'));
      expect(identical(save.snapshot, before), isFalse);
      expect(save.pendingRequest, isNull);
      expect(save.target, PlanFlowSaveTarget.appendPhases);
      final active = await service.loadRepositoryPlan(_profileId);
      expect(active.document.phases, hasLength(1));
    });

    test('연결이 끊기면 같은 키·같은 문서로 다시 보낸다', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      final flow = await _flow(
        service,
        _draft({
          'aru': [
            {'level': 70},
          ],
        }),
      );
      final save = await _save(flow);
      service.failures.add(BackendDisconnectedException('backend stopped'));
      expect(await save.save(), isNull);
      expect(save.pendingRequest, isNotNull);
      expect(save.message, contains('같은 요청을 그대로 보냅니다'));
      final outcome = await save.save();
      expect(outcome, isNotNull);
      expect(service.creates, hasLength(2));
      expect(service.creates.last.key, service.creates.first.key);
      expect(
        identical(service.creates.last.document, service.creates.first.document),
        isTrue,
      );
      expect(save.pendingRequest, isNull);
    });

    test('idempotency_conflict: 새 키를 저절로 만들지 않는다', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      final flow = await _flow(
        service,
        _draft({
          'aru': [
            {'level': 70},
          ],
        }),
      );
      final save = await _save(flow);
      service.failures.add(
        BackendRemoteException(
          code: 'idempotency_conflict',
          message: 'Key belongs to another mutation',
        ),
      );
      expect(await save.save(), isNull);
      expect(save.message, contains('다시 읽기'));
      final pending = save.pendingRequest;
      expect(pending, isNotNull);
      await save.save();
      expect(service.creates.last.key, pending!.idempotencyKey);
    });
  });

  group('나중 단계 올림(FE4-g4, FD-180 (a))', () {
    test('나중에 단계 여럿: 체인 순서대로 바로 앞 값까지 올리고 비운 키도 채운다. 높은 값 · 앞도 비운 키는 그대로다', () {
      final active = _activeDocument({
        'aru': {'level': 50},
      });
      final d1 = _laterStage('aru-later-1', 'aru', {
        'level': 60,
        'skill1': 5,
      }, name: '나중 1');
      final d2 = _laterStage('aru-later-2', 'aru', {
        'level': 90,
        'skill1': 5,
        'ex_skill': 3,
      }, name: '나중 2');
      final merged = planFlowMergedPlanDocument(
        active: active,
        draft: _draft({
          'aru': [
            {'level': 70, 'ex_skill': 4},
          ],
        }),
        id: active.id,
        name: active.name,
        activeAuthoring: _activeAuthoring(active, [d1, d2]),
      );
      expect(merged.blocked, isFalse);
      expect(merged.authoringReason, isNull);
      // D1: 레벨 60→70(낮음), EX 없음→4(비움). 기본 5는 앞(초안 · 활성 모두 null)이 비워 그대로.
      // D2: 레벨 90(높음) 그대로, EX 3→4(올린 D1 기준).
      expect(merged.raisedTargets, const [
        PlanFlowRaisedTarget(
          studentId: 'aru',
          stageId: 'aru-later-1',
          stageName: '나중 1',
          key: 'level',
          before: 60,
          after: 70,
        ),
        PlanFlowRaisedTarget(
          studentId: 'aru',
          stageId: 'aru-later-1',
          stageName: '나중 1',
          key: 'ex_skill',
          before: null,
          after: 4,
        ),
        PlanFlowRaisedTarget(
          studentId: 'aru',
          stageId: 'aru-later-2',
          stageName: '나중 2',
          key: 'ex_skill',
          before: 3,
          after: 4,
        ),
      ]);
      expect(merged.raisedStageIds, ['aru-later-1', 'aru-later-2']);
      final later = {
        for (final stage in merged.authoring!.deferredStages) stage.id: stage,
      };
      expect(later['aru-later-1']!.nullableTargets['level'], 70);
      expect(later['aru-later-1']!.nullableTargets['ex_skill'], 4);
      expect(later['aru-later-1']!.nullableTargets['skill1'], 5);
      expect(later['aru-later-2']!.nullableTargets['level'], 90);
      expect(later['aru-later-2']!.nullableTargets['ex_skill'], 4);
      // 검증(target_regression)은 그대로다: 올린 결과는 다시 읽어도 통과하고, 올리지 않은 원래 나중에 단계로는
      // 거절한다(이 slice 전 동작).
      final wire = merged.authoring!.toWire();
      expect(
        PlanningAuthoring.fromWire(wire, merged.document!).deferredStages,
        hasLength(2),
      );
      expect(
        () => PlanningAuthoring.fromWire({
          ...wire,
          'deferred_stages': [d1.toWire(), d2.toWire()],
        }, merged.document!),
        throwsA(
          isA<PlanningAuthoringFormatException>().having(
            (error) => error.reason,
            'reason',
            'target_regression',
          ),
        ),
      );
    });

    test('MAX · 직접 입력 값도 숫자 그대로 올린다. 활성 계획에 나중에 단계만 있는 학생도 같다', () {
      final active = _activeDocument({});
      final merged = planFlowMergedPlanDocument(
        active: active,
        draft: _draft({
          'hina': [
            {'level': 90, 'bond_rank': 37},
          ],
        }),
        id: active.id,
        name: active.name,
        activeAuthoring: _activeAuthoring(active, [
          _laterStage('hina-later', 'hina', {'level': 80, 'bond_rank': 20}),
        ]),
      );
      expect(merged.blocked, isFalse);
      expect(merged.raisedTargets.map(planFlowRaisedTargetText), [
        '레벨 80→90',
        '인연 20→37',
      ]);
    });

    test('초안 나중에 단계는 올리지 않는다: 체인은 활성 배치 → 초안 배치 → 활성 나중에(올림) → 초안 나중에', () {
      final active = _activeDocument({
        'aru': {'level': 50},
      });
      final base = _draft({
        'aru': [
          {'level': 70},
          {'level': 88},
        ],
      });
      final merged = planFlowMergedPlanDocument(
        active: active,
        draft: base.copyWith(
          phases: [base.phases.first],
          deferredStageIds: ['aru-stage-2'],
        ),
        id: active.id,
        name: active.name,
        activeAuthoring: _activeAuthoring(active, [
          _laterStage('aru-later', 'aru', {'level': 60}),
        ]),
      );
      expect(merged.blocked, isFalse);
      expect(
        merged.raisedTargets.map((item) => (item.stageId, item.key)).toList(),
        [('aru-later', 'level')],
      );
      final authoring = merged.authoring!;
      expect(authoring.stageOrderByStudent['aru'], [
        'aru-stage-1',
        'aru-stage-1-2',
        'aru-later',
        'aru-stage-2',
      ]);
      final later = {
        for (final stage in authoring.deferredStages) stage.id: stage,
      };
      expect(later['aru-later']!.nullableTargets['level'], 70);
      expect(later['aru-stage-2']!.nullableTargets['level'], 88);
    });

    test('초안 나중에 단계가 활성 나중에 단계보다 낮으면 지금처럼 막는다(올림 없음)', () {
      final active = _activeDocument({
        'aru': {'level': 50},
      });
      final base = _draft({
        'aru': [
          {'level': 70},
          {'level': 85},
        ],
      });
      final merged = planFlowMergedPlanDocument(
        active: active,
        draft: base.copyWith(
          phases: [base.phases.first],
          deferredStageIds: ['aru-stage-2'],
        ),
        id: active.id,
        name: active.name,
        activeAuthoring: _activeAuthoring(active, [
          _laterStage('aru-later', 'aru', {'level': 90}),
        ]),
      );
      expect(merged.blocked, isTrue);
      expect(merged.regressedStudentIds, ['aru']);
      expect(merged.raisedTargets, isEmpty);
    });

    test('같거나 높은 나중에 단계 · 초안에 없는 학생은 그대로, 막힌 병합은 올림을 알리지 않는다', () {
      final active = _activeDocument({
        'aru': {'level': 50},
        'ayane': {'level': 40},
      });
      final authoring = _activeAuthoring(active, [
        _laterStage('aru-later', 'aru', {'level': 70}),
        _laterStage('ayane-later', 'ayane', {'level': 45}),
      ]);
      final same = planFlowMergedPlanDocument(
        active: active,
        draft: _draft({
          'aru': [
            {'level': 70},
          ],
        }),
        id: active.id,
        name: active.name,
        activeAuthoring: authoring,
      );
      expect(same.blocked, isFalse);
      expect(same.raisedTargets, isEmpty);
      // 초안 배치가 활성 배치보다 낮으면 FE4-e 규칙대로 막는다(나중에 단계 EX는 비어 있지만 알리지 않는다).
      final blocked = planFlowMergedPlanDocument(
        active: active,
        draft: _draft({
          'aru': [
            {'level': 40, 'ex_skill': 5},
          ],
        }),
        id: active.id,
        name: active.name,
        activeAuthoring: authoring,
      );
      expect(blocked.blocked, isTrue);
      expect(blocked.regressedStudentIds, ['aru']);
      expect(blocked.raisedTargets, isEmpty);
    });

    test('시나리오 편입은 그대로다: 활성 나중에 단계와 맞지 않는 시나리오 단계는 빼고 올리지 않는다', () {
      final active = _activeDocument({
        'aru': {'level': 50},
      });
      final scenario = PlanningDocument(
        id: 'scenario-1',
        name: '후보',
        kind: PlanningDocumentKind.scenario,
        version: 2,
        goalMetadata: {'aru': planFlowDefaultGoalMetadata},
        phases: [
          PlanningDocumentPhase(
            id: 'scenario-phase-1',
            name: '1순위',
            stages: [
              PlanningDocumentStage(
                id: 'scenario-aru-1',
                studentId: 'aru',
                name: '1단계',
                targets: _targets({'level': 80}),
              ),
            ],
          ),
        ],
      );
      final incorporated = planFlowIncorporateScenario(
        active: active,
        activeAuthoring: _activeAuthoring(active, [
          _laterStage('aru-later', 'aru', {'level': 60}),
        ]),
        scenarioDocument: scenario,
        scenarioName: '후보',
        seedFor: _seed,
      );
      expect(incorporated.skippedStageCount, 1);
      expect(incorporated.merged.raisedTargets, isEmpty);
    });

    test('알림 글자: 제목 · 단계마다 한 줄 · 저장 결과 요약(단계가 넘치면 외 n개 단계)', () {
      const items = [
        PlanFlowRaisedTarget(
          studentId: 'aru',
          stageId: 'a',
          stageName: '목표',
          key: 'level',
          before: 70,
          after: 80,
        ),
        PlanFlowRaisedTarget(
          studentId: 'aru',
          stageId: 'a',
          stageName: '목표',
          key: 'ex_skill',
          before: null,
          after: 5,
        ),
        PlanFlowRaisedTarget(
          studentId: 'hina',
          stageId: 'b',
          stageName: '총력전',
          key: 'equip1_tier',
          before: 7,
          after: 9,
        ),
      ];
      String name(String id) => id == 'aru' ? '아루' : '히나';
      // FE4-g5(FE4-g4 발견 1): 저장 전 미리보기는 미래형, 저장 뒤 결과 안내(요약)는 완료형이다.
      expect(planFlowRaisingTitle(2), '저장하면 나중 단계 2개를 함께 올립니다');
      expect(planFlowRaisedTitle(2), '나중 단계 2개를 함께 올렸습니다');
      expect(planFlowRaisedStageLines(items, name), [
        '아루 · 나중에 칸 목표 · 레벨 70→80, EX —→5',
        '히나 · 나중에 칸 총력전 · 장비1 티어 T7→T9',
      ]);
      expect(
        planFlowRaisedSummary(items, name),
        '나중 단계 2개를 함께 올렸습니다(아루 · 나중에 칸 목표 · 레벨 70→80, EX —→5 / '
        '히나 · 나중에 칸 총력전 · 장비1 티어 T7→T9).',
      );
      expect(
        planFlowRaisedSummary(items, name, maxLines: 1),
        '나중 단계 2개를 함께 올렸습니다(아루 · 나중에 칸 목표 · 레벨 70→80, EX —→5 외 1개 단계).',
      );
      expect(planFlowRaisedSummary(const [], name), isNull);
    });

    test('페이즈로 추가 저장: 올린 나중에 단계를 보내 검증을 통과하고 결과 안내에 같은 요약이 붙는다', () async {
      final service = _RecordingService();
      addTearDown(service.dispose);
      await _seedActiveWithLater(
        service,
        {
          'aru': {'level': 50},
        },
        [
          _laterStage('aru-later', 'aru', {'level': 60}, name: '총력전'),
        ],
      );
      service.planSaves.clear();
      final flow = await _flow(
        service,
        _draft({
          'aru': [
            {'level': 70},
          ],
        }),
      );
      final save = await _save(flow);
      // 시나리오로 저장을 고른 동안은 알리지 않는다.
      expect(save.target, PlanFlowSaveTarget.scenario);
      expect(save.raisedTargets, isEmpty);
      expect(save.isAvailable(PlanFlowSaveTarget.appendPhases), isTrue);
      save.selectTarget(PlanFlowSaveTarget.appendPhases);
      expect(save.canSave, isTrue);
      expect(save.raisedTargets.single.key, 'level');
      final outcome = await save.save();
      expect(outcome, isNotNull);
      final name = flow.context.displayName('aru');
      expect(
        outcome!.message,
        '활성 계획에 페이즈 1개를 붙였습니다. 나중 단계 1개를 함께 올렸습니다($name · 나중에 칸 총력전 · '
        '레벨 60→70).',
      );
      final request = service.planSaves.single;
      expect(
        request.authoring!.deferredStages.single.nullableTargets['level'],
        70,
      );
      expect(request.authoring!.stageOrderByStudent['aru'], [
        'aru-stage-1',
        'aru-stage-1-2',
        'aru-later',
      ]);
      // mock 저장소가 받아 다시 읽은 활성 계획의 나중에 단계도 올라 있다.
      final saved = await service.loadRepositoryPlan(_profileId);
      expect(
        saved.authoring.deferredStages.single.nullableTargets['level'],
        70,
      );
    });

    for (final size in const [Size(2560, 1208), Size(1280, 625)]) {
      testWidgets(
        '4단계 C: 페이즈로 추가를 고르면 저장 버튼 아래에 올린 나중 단계를 알린다(${size.width.toInt()}폭, 넘침 없음)',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final service = MockAppService();
          addTearDown(service.dispose);
          await _seedActiveWithLater(
            service,
            {
              'aru': {'level': 50},
            },
            [
              _laterStage('aru-later', 'aru', {'level': 60}, name: '총력전'),
            ],
          );
          final flow = await _flow(
            service,
            _draft({
              'aru': [
                {'level': 70, 'ex_skill': 4},
              ],
            }),
            step: PlanFlowStep.save,
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: BAPlannerTheme.dark(),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: PlanFlowWorkspace(
                      flow: flow,
                      service: service,
                      onClosed: (_) {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(planFlowCalculationDebounce);
          await tester.pump(AppMotion.section);
          await tester.pump();
          expect(
            find.byKey(const ValueKey('plan-flow-save-raised-title')),
            findsNothing,
          );
          await tester.tap(
            find.byKey(const ValueKey('plan-flow-save-target-appendPhases')),
          );
          await tester.pump();
          // 저장 전 미리보기라 미래형이다(FE4-g5). 완료형은 저장 뒤 안내에만 쓴다.
          expect(find.text('저장하면 나중 단계 1개를 함께 올립니다'), findsOneWidget);
          expect(find.textContaining('함께 올렸습니다'), findsNothing);
          final name = flow.context.displayName('aru');
          expect(
            find.text('$name · 나중에 칸 총력전 · 레벨 60→70, EX —→4'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.byKey(const ValueKey('plan-flow-save-target-scenario')),
          );
          await tester.pump();
          expect(
            find.byKey(const ValueKey('plan-flow-save-raised-title')),
            findsNothing,
          );
        },
      );
    }
  });

  testWidgets('A 레일 primary와 C 버튼 글자는 C에서 고른 저장 위치를 따른다(FD-079)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2560, 1392);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = MockAppService();
    addTearDown(service.dispose);
    final flow = await _flow(
      service,
      _draft({
        'aru': [
          {'level': 70},
        ],
      }),
      step: PlanFlowStep.save,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: BAPlannerTheme.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 2560,
              height: 1208,
              child: PlanFlowWorkspace(
                flow: flow,
                service: service,
                onClosed: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(planFlowCalculationDebounce);
    await tester.pump(AppMotion.section);
    await tester.pump();

    String railLabel() => tester
        .widget<RailButton>(find.byKey(const ValueKey('plan-flow-next')))
        .semanticLabel!;
    String asideLabel() => tester
        .widget<RailButton>(find.byKey(const ValueKey('plan-flow-save-confirm')))
        .semanticLabel!;

    expect(find.byKey(const ValueKey('plan-scenario-save-dialog')), findsNothing);
    expect(find.byKey(const ValueKey('plan-flow-save-name-field')), findsOneWidget);
    expect(railLabel(), '시나리오로 저장');
    expect(asideLabel(), '시나리오로 저장');

    await tester.tap(find.byKey(const ValueKey('plan-flow-save-target-replace')));
    await tester.pump();
    expect(railLabel(), '활성 계획을 이걸로 바꾸기');
    expect(asideLabel(), '활성 계획을 이걸로 바꾸기');
    // 이름 칸은 기존 활성 계획이 비어 있으면 옮겨 둘 것이 없다고 알린다.
    expect(
      find.byKey(const ValueKey('plan-flow-save-archive-empty')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('plan-flow-save-target-appendPhases')),
    );
    await tester.pump();
    expect(railLabel(), '활성 계획에 페이즈로 추가');
    expect(asideLabel(), '활성 계획에 페이즈로 추가');
    expect(
      find.byKey(const ValueKey('plan-flow-save-phase-flow-phase-1')),
      findsOneWidget,
    );
  });
}
