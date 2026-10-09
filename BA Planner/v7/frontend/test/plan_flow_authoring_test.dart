// 계획 만들기 3단계 교차 선행·"나중에" 칸 테스트(FE4-f1, FD-068, FB-8 authoring v1).
//
// - 초안: "나중에" 칸으로 옮기기(같은 학생 뒤 단계 함께), 명시 나중에와 임시 미배치 구별(ensurePlaced가 다시 놓지
//   않음), 모두 나중에여도 저장 가능, 직접 선행 잇기·거부(자기 자신 · 같은 학생 · 이미 이음 · 순환 · 뒤 칸)·지우기,
//   같은 칸 stable topological 순서, 규칙 위반(lane_order · cycle · stage_reference) reason과 카드.
// - 경계: authoring wire(학생 순서 · 체인 · 나중에 단계 nullable 목표 · goal_metadata) ↔ 초안 복원.
// - 저장: 시나리오 create · 페이즈로 추가(활성 authoring 병합, id 재발급 remap) · authoring 오류를 카드에 잇고 초안 유지.
// - 화면: "나중에" 칸에 끌어 놓기, C "선행 단계 추가" 뒤 카드 누르기, 카드 아래 점 끌기, 분홍 점선, C ×.
// - FE4-f2: 시나리오 편입(stage ID 재발급 remap · 퇴행 단계와 그 직접 선행을 명시해 빼기), 활성 계획을 고치는 흐름의
//   4단계(이걸로 바꾸기 기본 · 페이즈로 추가 막음 · 초안을 연 revision으로 충돌 알림).
//
// 계산 디바운스(Timer)가 있어서 pumpAndSettle 대신 명시적인 pump를 쓴다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/services/planning_protocol_client.dart';
import 'package:ba_planner_v7/services/scenario_service.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_order_editor.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_save.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_order_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 콘텐츠 캔버스(기준 viewport 2560×1392에서 헤더 184 아래).
const _canvas = Size(2560, 1208);

PlanningStudentSeed _seed(String studentId) => PlanningStudentSeed(
  handoffId: 'seed-$studentId',
  studentId: studentId,
  metadata: const {},
  currentValues: const {},
);

PlanFlowStageDraft _stage(String studentId, int number) => PlanFlowStageDraft(
  id: '$studentId-stage-$number',
  name: '$number단계',
  targets: {'level': 50 + number},
);

/// 아루 2단계 · 아야네 1단계. 기본 칸: 1순위 [아루 1, 아야네 1], 2순위 [아루 2].
PlanFlowDraft _draft({
  List<PlanFlowPhase>? phases,
  List<String> deferred = const [],
  List<PlanFlowPrerequisite> prerequisites = const [],
  List<String> extraStudents = const [],
  Map<String, PlanningGoalMetadata> goalMetadata = const {},
}) => PlanFlowDraft(
  students: [
    _seed('aru'),
    _seed('ayane'),
    for (final id in extraStudents) _seed(id),
  ],
  stagesByStudent: {
    'aru': [_stage('aru', 1), _stage('aru', 2)],
    'ayane': [_stage('ayane', 1)],
  },
  phases:
      phases ??
      [
        PlanFlowPhase(
          id: 'p1',
          name: '1순위',
          stageIds: const ['aru-stage-1', 'ayane-stage-1'],
        ),
        PlanFlowPhase(
          id: 'p2',
          name: '2순위',
          stageIds: const ['aru-stage-2'],
        ),
      ],
  deferredStageIds: deferred,
  prerequisites: prerequisites,
  goalMetadata: goalMetadata,
);

List<List<String>> _lanes(PlanFlowController flow) => [
  for (final phase in flow.draft.phases) [...phase.stageIds],
];

Future<String> _profileId(MockAppService service) async =>
    (await service.listProfiles()).firstWhere((profile) => profile.selected).id;

Future<PlanFlowController> _controller(
  MockAppService service, {
  PlanFlowDraft? draft,
  PlanFlowStep step = PlanFlowStep.order,
}) async {
  final state = await service.loadRepositoryState(await _profileId(service));
  final catalog = await service.listStudents();
  final flow = PlanFlowController(
    purpose: PlanFlowPurpose.newScenario,
    context: PlanFlowContext(
      repositoryState: state,
      catalog: {for (final entry in catalog) entry.studentId: entry},
    ),
    service: service,
    initialDraft: draft ?? _draft(),
    initialStep: step,
  );
  addTearDown(flow.dispose);
  return flow;
}

/// 시나리오 create · plan.save의 authoring을 기록하고 [failures]를 먼저 던지는 mock.
class _AuthoringService extends MockAppService {
  final created = <PlanningAuthoring?>[];
  final planSaves = <({PlanningDocument document, PlanningAuthoring? authoring})>[];
  final failures = <Object>[];

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
    created.add(authoring);
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

  @override
  Future<int> saveRepositoryPlan({
    required String profileId,
    required PlanningDocument document,
    PlanningAuthoring? authoring,
    required int expectedRevision,
    required String idempotencyKey,
  }) async {
    planSaves.add((document: document, authoring: authoring));
    if (failures.isNotEmpty) throw failures.removeAt(0);
    return super.saveRepositoryPlan(
      profileId: profileId,
      document: document,
      authoring: authoring,
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
    );
  }
}

/// 저장 상태를 만들고 저장 직전 상태를 읽는다(흐름은 3단계라 저절로 읽지 않는다).
Future<PlanFlowSaveController> _save(PlanFlowController flow) async {
  final save = PlanFlowSaveController(flow: flow);
  addTearDown(save.dispose);
  await save.reload();
  return save;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(planFlowCalculationDebounce);
  await tester.pump();
}

/// B 본문 + C 보조를 캔버스에 그린다.
Future<PlanFlowOrderEditor> _pumpOrder(
  WidgetTester tester,
  PlanFlowController flow,
) async {
  tester.view.physicalSize = const Size(2560, 1392);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final editor = PlanFlowOrderEditor(flow: flow);
  addTearDown(editor.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: BAPlannerTheme.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: _canvas,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PlanFlowOrderBody(flow: flow, editor: editor),
                ),
                Positioned.fill(
                  child: PlanFlowOrderAside(flow: flow, editor: editor),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  return editor;
}

/// [from] 위치에서 [to] 위치로 끈다.
Future<void> _dragBetween(WidgetTester tester, Offset from, Offset to) async {
  final gesture = await tester.startGesture(from);
  await gesture.moveBy(const Offset(0, 30));
  await tester.pump();
  await gesture.moveTo(to);
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

List<PlanFlowOrderArrow> _directArrows(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(const ValueKey('plan-flow-order-direct-arrows')),
  );
  return (paint.painter! as PlanFlowOrderArrowPainter).arrows;
}

/// v2 단계(적지 않은 키는 null).
PlanningDocumentStage _docStage(String id, String studentId, int level) =>
    PlanningDocumentStage(
      id: id,
      studentId: studentId,
      name: id,
      targets: {
        for (final key in planningDocumentTargetKeys)
          key: key == 'level' ? level : null,
      },
    );

/// v2 문서(goal_metadata는 문서 학생 기본값).
PlanningDocument _doc(
  String id,
  PlanningDocumentKind kind,
  List<PlanningDocumentPhase> phases,
) => PlanningDocument(
  id: id,
  name: id,
  kind: kind,
  version: 2,
  phases: phases,
  goalMetadata: {
    for (final phase in phases)
      for (final stage in phase.stages)
        stage.studentId: planFlowDefaultGoalMetadata,
  },
);

void main() {
  group('나중에 칸(FE4-f1)', () {
    test('나중에 칸으로 옮기면 같은 학생 뒤 단계도 함께 가고, 칸에 다시 놓지 않는다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      expect(
        flow.moveStage('aru-stage-1', phaseId: planFlowDeferredLaneId),
        isNull,
      );
      expect(flow.draft.deferredStageIds, ['aru-stage-1', 'aru-stage-2']);
      expect(_lanes(flow), [
        ['ayane-stage-1'],
        <String>[],
      ]);
      // 명시 나중에는 임시 미배치가 아니다.
      expect(flow.draft.unassignedStages, isEmpty);
      expect(flow.draft.allStagesAssigned, isTrue);
      final editor = PlanFlowOrderEditor(flow: flow);
      addTearDown(editor.dispose);
      editor.ensurePlaced();
      flow.placeUnassignedStages();
      expect(flow.draft.deferredStageIds, ['aru-stage-1', 'aru-stage-2']);
      expect(flow.canGoNext, isTrue);
      // 나중에 칸의 뒤 단계만 칸으로 꺼낼 수는 없다(선행이 나중에 칸 = 마지막 칸).
      final aru = flow.context.displayName('aru');
      expect(
        flow.moveStage('aru-stage-2', phaseId: 'p1'),
        '$aru 2단계는 선행 단계($aru 1단계)보다 앞 칸에 둘 수 없습니다.',
      );
      expect(flow.moveStage('aru-stage-1', phaseId: 'p1'), isNull);
      expect(flow.draft.deferredStageIds, ['aru-stage-2']);
      expect(_lanes(flow).first, ['ayane-stage-1', 'aru-stage-1']);
      // 계산 문서에는 나중에 칸 단계가 없다.
      final wire = PlanFlowDocumentBoundary.calculationWire(
        flow.draft,
        id: 'flow',
      );
      final ids = [
        for (final phase in wire['phases'] as List)
          for (final stage in (phase as Map)['stages'] as List)
            (stage as Map)['stage_id'],
      ];
      expect(ids, ['ayane-stage-1', 'aru-stage-1']);
    });

    test('모든 단계가 나중에여도 3단계를 마치고 authoring으로 저장할 수 있다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      expect(
        flow.moveStage('aru-stage-1', phaseId: planFlowDeferredLaneId),
        isNull,
      );
      expect(
        flow.moveStage('ayane-stage-1', phaseId: planFlowDeferredLaneId),
        isNull,
      );
      expect(flow.draft.deferredStageIds, [
        'aru-stage-1',
        'aru-stage-2',
        'ayane-stage-1',
      ]);
      expect(flow.canEnter(PlanFlowStep.save), isTrue);
      // 계산할 단계가 없으면 계산을 부르지 않는다.
      expect(flow.calculating, isFalse);
      expect(flow.calculation, isNull);
      final document = PlanFlowDocumentBoundary.toScenarioDocument(
        flow.draft,
        id: 'scenario',
        name: '나중에만',
      );
      expect(document.phases, isEmpty);
      final authoring = PlanFlowDocumentBoundary.authoringFor(
        flow.draft,
        document,
      );
      expect(authoring.studentOrder, ['aru', 'ayane']);
      expect([for (final stage in authoring.deferredStages) stage.id], [
        'aru-stage-1',
        'aru-stage-2',
        'ayane-stage-1',
      ]);
      expect(authoring.goalMetadata.keys.toSet(), {'aru', 'ayane'});
      // 나중에 단계 목표는 v2 nullable 그대로다(정수로 채우지 않는다).
      expect(authoring.deferredStages.first.nullableTargets['ex_skill'], isNull);
    });

    test('목표 편집 중 칸에서 빠진 임시 미배치와 명시 나중에를 구별한다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      expect(
        flow.moveStage('aru-stage-2', phaseId: planFlowDeferredLaneId),
        isNull,
      );
      // 2단계에서 아루 3단계를 더한다(남은 단계 id는 그대로).
      flow.setStudentStages('aru', [
        for (var step = 1; step <= 3; step++)
          PlanElementStageDraft(
            id: 'aru-stage-$step',
            name: '$step단계',
            targets: {'level': 50 + step},
          ),
      ]);
      expect(flow.draft.deferredStageIds, ['aru-stage-2']);
      expect(
        {for (final stage in flow.draft.unassignedStages) stage.id},
        {'aru-stage-1', 'aru-stage-3'},
      );
      flow.placeUnassignedStages();
      // 1단계는 칸으로, 3단계는 앞 단계가 나중에 칸이라 나중에 칸으로 간다(배치 prefix + 나중에 suffix).
      expect(_lanes(flow).first, contains('aru-stage-1'));
      expect(flow.draft.deferredStageIds, ['aru-stage-2', 'aru-stage-3']);
      expect(flow.orderIssues, isEmpty);
    });
  });

  group('직접 선행(FE4-f1)', () {
    test('자기 자신 · 같은 학생 · 뒤 칸 · 이미 이음 · 순환은 거부하고, 같은 칸이면 선행을 앞에 놓는다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      expect(
        flow.addPrerequisite(
          stageId: 'aru-stage-1',
          requiresStageId: 'aru-stage-1',
        ),
        contains('자기 자신'),
      );
      expect(
        flow.addPrerequisite(
          stageId: 'aru-stage-2',
          requiresStageId: 'aru-stage-1',
        ),
        contains('같은 학생'),
      );
      expect(
        flow.addPrerequisite(
          stageId: 'ayane-stage-1',
          requiresStageId: 'aru-stage-2',
        ),
        contains('뒤 칸에 있어'),
      );
      expect(flow.draft.prerequisites, isEmpty);
      // 같은 칸: 아야네 1 → 아루 1, 칸 배열이 선행 → 후행으로 바뀐다.
      expect(
        flow.addPrerequisite(
          stageId: 'aru-stage-1',
          requiresStageId: 'ayane-stage-1',
        ),
        isNull,
      );
      expect(_lanes(flow).first, ['ayane-stage-1', 'aru-stage-1']);
      expect(flow.draft.prerequisites, [
        const PlanFlowPrerequisite(
          stageId: 'aru-stage-1',
          requiresStageId: 'ayane-stage-1',
        ),
      ]);
      expect(
        flow.addPrerequisite(
          stageId: 'aru-stage-1',
          requiresStageId: 'ayane-stage-1',
        ),
        contains('이미'),
      );
      expect(
        flow.addPrerequisite(
          stageId: 'ayane-stage-1',
          requiresStageId: 'aru-stage-2',
        ),
        contains('돌고 돕니다'),
      );
      // 기다리는 단계보다 뒤 칸으로는 옮길 수 없다.
      expect(
        flow.moveStage('ayane-stage-1', phaseId: 'p2'),
        contains('이 단계를 기다리는'),
      );
      // 나중에 칸 안에서도 선행 → 후행 순서다.
      expect(
        flow.moveStage('aru-stage-1', phaseId: planFlowDeferredLaneId),
        isNull,
      );
      expect(
        flow.moveStage('ayane-stage-1', phaseId: planFlowDeferredLaneId),
        isNull,
      );
      expect(flow.draft.deferredStageIds, [
        'ayane-stage-1',
        'aru-stage-1',
        'aru-stage-2',
      ]);
      expect(flow.orderIssues, isEmpty);
      flow.removePrerequisite(
        stageId: 'aru-stage-1',
        requiresStageId: 'ayane-stage-1',
      );
      expect(flow.draft.prerequisites, isEmpty);
    });

    test('자동 정렬은 나중에 칸을 두고 직접 선행보다 앞 칸에 놓지 않는다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(
        service,
        draft: _draft(
          prerequisites: const [
            PlanFlowPrerequisite(
              stageId: 'ayane-stage-1',
              requiresStageId: 'aru-stage-2',
            ),
          ],
          phases: [
            PlanFlowPhase(id: 'p1', name: '1순위', stageIds: const ['aru-stage-1']),
            PlanFlowPhase(
              id: 'p2',
              name: '2순위',
              stageIds: const ['aru-stage-2', 'ayane-stage-1'],
            ),
          ],
        ),
      );
      flow.autoArrange(PlanFlowAutoArrange.stageStep);
      expect(_lanes(flow), [
        ['aru-stage-1'],
        ['aru-stage-2', 'ayane-stage-1'],
      ]);
      expect(flow.orderIssues, isEmpty);
    });

    test('규칙 위반은 백엔드와 같은 reason과 카드 id로 알리고 3단계를 끝내지 않는다', () async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final laneOrder = await _controller(
        service,
        draft: _draft(
          prerequisites: const [
            PlanFlowPrerequisite(
              stageId: 'ayane-stage-1',
              requiresStageId: 'aru-stage-2',
            ),
          ],
        ),
      );
      expect(laneOrder.orderIssues.single.reason, 'lane_order');
      expect(laneOrder.orderIssues.single.stageIds, [
        'ayane-stage-1',
        'aru-stage-2',
      ]);
      expect(laneOrder.orderReady, isFalse);
      expect(laneOrder.canEnter(PlanFlowStep.save), isFalse);
      expect(laneOrder.issuesOf('ayane-stage-1'), hasLength(1));

      final cycle = await _controller(
        service,
        draft: _draft(
          prerequisites: const [
            PlanFlowPrerequisite(
              stageId: 'aru-stage-1',
              requiresStageId: 'ayane-stage-1',
            ),
            PlanFlowPrerequisite(
              stageId: 'ayane-stage-1',
              requiresStageId: 'aru-stage-2',
            ),
          ],
        ),
      );
      expect(
        cycle.orderIssues.map((issue) => issue.reason),
        contains('cycle'),
      );

      final dangling = await _controller(
        service,
        draft: _draft(
          prerequisites: const [
            PlanFlowPrerequisite(
              stageId: 'ayane-stage-1',
              requiresStageId: 'gone-stage',
            ),
          ],
        ),
      );
      expect(dangling.orderIssues.single.reason, 'stage_reference');
      expect(dangling.orderIssues.single.stageIds, ['ayane-stage-1']);
    });
  });

  group('authoring 경계(FE4-f1)', () {
    test('저장 authoring과 문서로 초안을 그대로 복원한다(목표 없는 선택 학생 포함)', () {
      final draft = _draft(
        deferred: const ['aru-stage-2'],
        phases: [
          PlanFlowPhase(
            id: 'p1',
            name: '먼저',
            stageIds: const ['ayane-stage-1', 'aru-stage-1'],
          ),
        ],
        prerequisites: const [
          PlanFlowPrerequisite(
            stageId: 'aru-stage-1',
            requiresStageId: 'ayane-stage-1',
          ),
        ],
        extraStudents: const ['hoshino'],
        goalMetadata: const {
          'hoshino': PlanningGoalMetadata(favorite: true, notes: '나중에 볼 학생'),
        },
      );
      final document = PlanFlowDocumentBoundary.toScenarioDocument(
        draft,
        id: 'scenario',
        name: '후보',
      );
      final authoring = PlanFlowDocumentBoundary.authoringFor(draft, document);
      final wire = authoring.toWire();
      expect(wire['student_order'], ['aru', 'ayane', 'hoshino']);
      expect(wire['stage_order_by_student'], {
        'aru': ['aru-stage-1', 'aru-stage-2'],
        'ayane': ['ayane-stage-1'],
        'hoshino': <String>[],
      });
      expect((wire['goal_metadata'] as Map).keys.toSet(), {'hoshino'});
      expect(wire['prerequisites'], [
        {'stage_id': 'aru-stage-1', 'requires_stage_id': 'ayane-stage-1'},
      ]);

      final restored = PlanFlowDocumentBoundary.fromDocument(
        document,
        seedFor: _seed,
        authoring: authoring,
      );
      expect(restored.studentIds, ['aru', 'ayane', 'hoshino']);
      expect(restored.deferredStageIds, ['aru-stage-2']);
      expect(restored.prerequisites, draft.prerequisites);
      expect(restored.phases.single.stageIds, ['ayane-stage-1', 'aru-stage-1']);
      expect(
        [for (final stage in restored.stagesByStudent['aru']!) stage.id],
        ['aru-stage-1', 'aru-stage-2'],
      );
      expect(
        restored.stagesByStudent['aru']![1].targets['ex_skill'],
        isNull,
      );
      expect(restored.goalMetadata['hoshino']!.notes, '나중에 볼 학생');

      // authoring이 없으면 DTO 기본값이다(나중에 칸·직접 선행 없음).
      final plain = PlanFlowDocumentBoundary.fromDocument(
        document,
        seedFor: _seed,
      );
      expect(plain.deferredStageIds, isEmpty);
      expect(plain.prerequisites, isEmpty);
      expect(plain.studentIds, ['ayane', 'aru']);
    });
  });

  group('저장(FE4-f1)', () {
    test('시나리오 create는 나중에 칸 · 직접 선행이 든 authoring 전체를 보낸다', () async {
      final service = _AuthoringService();
      addTearDown(service.dispose);
      final flow = await _controller(
        service,
        draft: _draft(
          deferred: const ['aru-stage-2'],
          phases: [
            PlanFlowPhase(
              id: 'p1',
              name: '1순위',
              stageIds: const ['ayane-stage-1', 'aru-stage-1'],
            ),
          ],
          prerequisites: const [
            PlanFlowPrerequisite(
              stageId: 'aru-stage-1',
              requiresStageId: 'ayane-stage-1',
            ),
          ],
        ),
      );
      final save = await _save(flow);
      expect(save.canSave, isTrue);
      expect(await save.save(), isNotNull);
      final authoring = service.created.single!;
      expect([for (final stage in authoring.deferredStages) stage.id], [
        'aru-stage-2',
      ]);
      expect(authoring.prerequisites.single.requiresStageId, 'ayane-stage-1');
      final list = await service.listScenarios(await _profileId(service));
      final stored = await service.getScenario(
        await _profileId(service),
        list.scenarios.single.id,
      );
      expect(stored.scenario.hasAuthoring, isTrue);
      expect(stored.scenario.authoring.deferredStages.single.id, 'aru-stage-2');
    });

    test('페이즈로 추가는 활성 authoring 뒤에 초안 것을 붙이고 바꾼 id로 edge를 잇는다', () async {
      final service = _AuthoringService();
      addTearDown(service.dispose);
      final profileId = await _profileId(service);
      final plan = await service.loadRepositoryPlan(profileId);
      // 활성 계획: 아루 1단계(id가 초안과 겹친다) + 나중에 칸 아루 단계 하나.
      final active = PlanningDocument(
        id: plan.document.id,
        name: plan.document.name,
        kind: PlanningDocumentKind.plan,
        version: 2,
        phases: [
          PlanningDocumentPhase(
            id: 'p1',
            name: '1순위',
            stages: [
              PlanningDocumentStage(
                id: 'aru-stage-1',
                studentId: 'aru',
                name: '1단계',
                targets: {
                  for (final key in planningDocumentTargetKeys)
                    key: key == 'level' ? 40 : null,
                },
              ),
            ],
          ),
        ],
        goalMetadata: const {'aru': planFlowDefaultGoalMetadata},
      );
      final activeAuthoring = PlanningAuthoring.fromWire({
        'version': 1,
        'prerequisites': const <Object>[],
        'deferred_stages': [
          PlanningDocumentStage(
            id: 'aru-later',
            studentId: 'aru',
            name: '나중 목표',
            targets: {
              for (final key in planningDocumentTargetKeys)
                key: key == 'level' ? 45 : null,
            },
          ).toWire(),
        ],
        'student_order': const ['aru'],
        'stage_order_by_student': const {
          'aru': ['aru-stage-1', 'aru-later'],
        },
        'goal_metadata': const <String, Object>{},
      }, active);
      await service.saveRepositoryPlan(
        profileId: profileId,
        document: active,
        authoring: activeAuthoring,
        expectedRevision: plan.revision,
        idempotencyKey: 'seed-active-authoring',
      );
      service.planSaves.clear();
      // 초안: 아야네 1단계(칸) → 아루 1단계(id 겹침, 나중에 칸)를 직접 선행으로 잇는다.
      final flow = await _controller(
        service,
        draft: PlanFlowDraft(
          students: [_seed('ayane'), _seed('aru')],
          stagesByStudent: {
            'ayane': [_stage('ayane', 1)],
            'aru': [
              PlanFlowStageDraft(
                id: 'aru-stage-1',
                name: '더 올리기',
                targets: const {'level': 60},
              ),
            ],
          },
          phases: [
            PlanFlowPhase(
              id: 'p1',
              name: '1순위',
              stageIds: const ['ayane-stage-1'],
            ),
          ],
          deferredStageIds: const ['aru-stage-1'],
          prerequisites: const [
            PlanFlowPrerequisite(
              stageId: 'aru-stage-1',
              requiresStageId: 'ayane-stage-1',
            ),
          ],
        ),
      );
      final save = await _save(flow);
      final merged = save.merged!;
      expect(merged.blocked, isFalse);
      expect(merged.stageIds['aru-stage-1'], 'aru-stage-1-2');
      save.selectTarget(PlanFlowSaveTarget.appendPhases);
      expect(await save.save(), isNotNull);
      final sent = service.planSaves.single.authoring!;
      expect(sent.studentOrder, ['aru', 'ayane']);
      expect([for (final stage in sent.deferredStages) stage.id], [
        'aru-later',
        'aru-stage-1-2',
      ]);
      expect(sent.stageOrderByStudent['aru'], [
        'aru-stage-1',
        'aru-later',
        'aru-stage-1-2',
      ]);
      expect(sent.prerequisites.single.stageId, 'aru-stage-1-2');
      expect(sent.prerequisites.single.requiresStageId, 'ayane-stage-1');
      final stored = await service.loadRepositoryPlan(profileId);
      expect(stored.hasAuthoring, isTrue);
      expect(stored.authoring.deferredStages, hasLength(2));
    });

    test('authoring 규칙 오류는 reason과 카드를 3단계에 잇고 초안 · 상태를 그대로 둔다', () async {
      final service = _AuthoringService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      final save = await _save(flow);
      final before = save.snapshot;
      service.failures.add(
        BackendRemoteException(
          code: 'invalid_payload',
          message: 'implicit and direct prerequisites must form a DAG',
          details: const {
            'reason': 'stage_order',
            'stage_id': 'aru-stage-2',
            'requires_stage_id': 'aru-stage-1',
          },
        ),
      );
      final draft = flow.draft;
      expect(await save.save(), isNull);
      expect(save.message, contains('같은 칸에서 먼저 끝나야 하는 단계가 뒤에 있습니다'));
      expect(save.messageIsError, isTrue);
      expect(save.pendingRequest, isNull);
      expect(identical(save.snapshot, before), isTrue);
      expect(identical(flow.draft, draft), isTrue);
      expect(flow.savedIssue?.reason, 'stage_order');
      expect(flow.issuesOf('aru-stage-2'), hasLength(1));
      // 초안을 고치면 저장 거절 표시는 없어진다.
      flow.renamePhase('p1', '먼저 할 것');
      expect(flow.savedIssue, isNull);
    });

    test('authoring 오류 코드: invalid_payload + validator reason, 보내기 전 예외', () {
      expect(
        planFlowSaveErrorCode(
          BackendRemoteException(
            code: 'invalid_payload',
            message: 'cycle',
            details: const {'reason': 'cycle'},
          ),
        ),
        'invalid_authoring',
      );
      expect(
        planFlowSaveErrorCode(
          const PlanningAuthoringFormatException('lane_order', 'x'),
        ),
        'invalid_authoring',
      );
      final found = planFlowAuthoringErrorOf(
        BackendRemoteException(
          code: 'invalid_payload',
          message: 'lane',
          details: const {
            'reason': 'lane_order',
            'stage_id': 'b',
            'requires_stage_id': 'a',
          },
        ),
      );
      expect(found?.reason, 'lane_order');
      expect(found?.stageIds, ['b', 'a']);
    });
  });

  group('화면(FE4-f1)', () {
    testWidgets('카드를 나중에 칸에 끌어 놓으면 같은 학생 뒤 단계도 함께 가고 상태는 "나중에"다', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      await _pumpOrder(tester, flow);
      const deferredLane = 'plan-flow-order-lane-$planFlowDeferredLaneId';
      expect(find.byKey(const ValueKey(deferredLane)), findsOneWidget);
      expect(find.text('나중에'), findsWidgets);
      final lane = tester.getRect(find.byKey(const ValueKey(deferredLane)));
      await _dragBetween(
        tester,
        tester.getCenter(
          find.byKey(const ValueKey('plan-flow-order-card-aru-stage-1')),
        ),
        Offset(lane.left + lane.width * 0.6, lane.center.dy),
      );
      await _settle(tester);
      expect(flow.draft.deferredStageIds, ['aru-stage-1', 'aru-stage-2']);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('plan-flow-order-card-aru-stage-1')),
          matching: find.text('나중에 칸 단계는 계산에서 빠집니다'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('C "선행 단계 추가" 뒤 카드를 누르면 분홍 점선으로 잇고 C ×로 지운다', (tester) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      final editor = await _pumpOrder(tester, flow);
      expect(_directArrows(tester), isEmpty);
      await tester.tap(
        find.byKey(const ValueKey('plan-flow-order-card-aru-stage-1')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plan-flow-order-aside-link')));
      await tester.pump();
      expect(editor.linking, isTrue);
      expect(find.byKey(const ValueKey('plan-flow-order-message')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('plan-flow-order-card-ayane-stage-1')),
      );
      await _settle(tester);
      expect(editor.linking, isFalse);
      expect(flow.draft.prerequisites, [
        const PlanFlowPrerequisite(
          stageId: 'aru-stage-1',
          requiresStageId: 'ayane-stage-1',
        ),
      ]);
      expect(_directArrows(tester), hasLength(1));
      expect(
        find.byKey(
          const ValueKey('plan-flow-order-aside-prerequisite-ayane-stage-1'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey(
            'plan-flow-order-aside-prerequisite-ayane-stage-1-remove',
          ),
        ),
      );
      await _settle(tester);
      expect(flow.draft.prerequisites, isEmpty);
      expect(_directArrows(tester), isEmpty);
    });

    testWidgets('카드 아래 점을 다른 카드로 끌면 그 카드의 먼저 끝나야 하는 단계가 되고, 거부하면 이유를 보인다', (
      tester,
    ) async {
      final service = MockAppService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      final editor = await _pumpOrder(tester, flow);
      await _dragBetween(
        tester,
        tester.getCenter(
          find.byKey(const ValueKey('plan-flow-order-card-ayane-stage-1-dot')),
        ),
        tester.getCenter(
          find.byKey(const ValueKey('plan-flow-order-card-aru-stage-2')),
        ),
      );
      await _settle(tester);
      expect(flow.draft.prerequisites, [
        const PlanFlowPrerequisite(
          stageId: 'aru-stage-2',
          requiresStageId: 'ayane-stage-1',
        ),
      ]);
      expect(editor.selectedStageId, 'aru-stage-2');
      // 반대로 이으면 선행 순서가 돌고 돌아 거부하고 이유를 보인다.
      await _dragBetween(
        tester,
        tester.getCenter(
          find.byKey(const ValueKey('plan-flow-order-card-aru-stage-2-dot')),
        ),
        tester.getCenter(
          find.byKey(const ValueKey('plan-flow-order-card-ayane-stage-1')),
        ),
      );
      await _settle(tester);
      expect(flow.draft.prerequisites, hasLength(1));
      expect(editor.message, isNotNull);
      expect(find.byKey(const ValueKey('plan-flow-order-message')), findsOneWidget);
    });
  });

  group('시나리오 편입(FE4-f2)', () {
    test('stage ID를 재발급하면 나중에 단계·직접 선행 양 끝·학생 체인·학생 순서를 함께 바꾼다', () {
      // 활성: 아루 1단계(칸, id 겹침) + 나중에 칸 아루 단계.
      final active = _doc('active-plan', PlanningDocumentKind.plan, [
        PlanningDocumentPhase(
          id: 'p1',
          name: '1순위',
          stages: [_docStage('aru-stage-1', 'aru', 40)],
        ),
      ]);
      final activeAuthoring = PlanningAuthoring.fromWire({
        'version': 1,
        'prerequisites': const <Object>[],
        'deferred_stages': [_docStage('aru-later', 'aru', 45).toWire()],
        'student_order': const ['aru'],
        'stage_order_by_student': const {
          'aru': ['aru-stage-1', 'aru-later'],
        },
        'goal_metadata': const <String, Object>{},
      }, active);
      // 시나리오: 아야네 1단계(칸) → 아루 1단계(나중에 칸, id 겹침) 직접 선행.
      final scenario = _doc('scenario', PlanningDocumentKind.scenario, [
        PlanningDocumentPhase(
          id: 'p1',
          name: '1순위',
          stages: [_docStage('ayane-stage-1', 'ayane', 51)],
        ),
      ]);
      final scenarioAuthoring = PlanningAuthoring.fromWire({
        'version': 1,
        'prerequisites': const [
          {'stage_id': 'aru-stage-1', 'requires_stage_id': 'ayane-stage-1'},
        ],
        'deferred_stages': [_docStage('aru-stage-1', 'aru', 60).toWire()],
        'student_order': const ['ayane', 'aru'],
        'stage_order_by_student': const {
          'ayane': ['ayane-stage-1'],
          'aru': ['aru-stage-1'],
        },
        'goal_metadata': const {
          'aru': {'favorite': false, 'notes': ''},
        },
      }, scenario);
      final result = planFlowIncorporateScenario(
        active: active,
        activeAuthoring: activeAuthoring,
        scenarioDocument: scenario,
        scenarioAuthoring: scenarioAuthoring,
        scenarioName: '후보',
        seedFor: _seed,
      );
      expect(result.skippedStageCount, 0);
      expect(result.droppedPrerequisites, isEmpty);
      expect(result.addedStageCount, 2);
      final merged = result.merged;
      expect(merged.blocked, isFalse);
      expect(merged.stageIds['aru-stage-1'], 'aru-stage-1-2');
      final document = merged.document!;
      expect(document.phases.map((phase) => (phase.id, phase.name)), [
        ('p1', '1순위'),
        ('p1-2', '후보 · 1순위'),
      ]);
      final authoring = merged.authoring!;
      expect(authoring.studentOrder, ['aru', 'ayane']);
      expect([for (final stage in authoring.deferredStages) stage.id], [
        'aru-later',
        'aru-stage-1-2',
      ]);
      expect(authoring.stageOrderByStudent['aru'], [
        'aru-stage-1',
        'aru-later',
        'aru-stage-1-2',
      ]);
      final prerequisite = authoring.prerequisites.single;
      expect(prerequisite.stageId, 'aru-stage-1-2');
      expect(prerequisite.requiresStageId, 'ayane-stage-1');
      // v2 nullable 원본 그대로다.
      expect(
        authoring.deferredStages.last.nullableTargets['ex_skill'],
        isNull,
      );
    });

    test('활성 목표보다 낮은 단계는 빼고, 그 단계에 이은 직접 선행은 명시해 뺀다', () {
      final active = _doc('active-plan', PlanningDocumentKind.plan, [
        PlanningDocumentPhase(
          id: 'p1',
          name: '1순위',
          stages: [_docStage('aru-active', 'aru', 70)],
        ),
      ]);
      final scenario = _doc('scenario', PlanningDocumentKind.scenario, [
        PlanningDocumentPhase(
          id: 's1',
          name: '1순위',
          stages: [
            _docStage('aru-s1', 'aru', 50),
            _docStage('ayane-s1', 'ayane', 51),
          ],
        ),
        PlanningDocumentPhase(
          id: 's2',
          name: '2순위',
          stages: [_docStage('ayane-s2', 'ayane', 60)],
        ),
      ]);
      final scenarioAuthoring = PlanningAuthoring.fromWire({
        'version': 1,
        'prerequisites': const [
          {'stage_id': 'ayane-s2', 'requires_stage_id': 'aru-s1'},
        ],
        'deferred_stages': const <Object>[],
        'student_order': const ['aru', 'ayane'],
        'stage_order_by_student': const {
          'aru': ['aru-s1'],
          'ayane': ['ayane-s1', 'ayane-s2'],
        },
        'goal_metadata': const <String, Object>{},
      }, scenario);
      final result = planFlowIncorporateScenario(
        active: active,
        scenarioDocument: scenario,
        scenarioAuthoring: scenarioAuthoring,
        scenarioName: '후보',
        seedFor: _seed,
      );
      expect(result.skippedStageCount, 1);
      expect(result.droppedPrerequisites, [
        const PlanFlowPrerequisite(
          stageId: 'ayane-s2',
          requiresStageId: 'aru-s1',
        ),
      ]);
      expect(result.addedStageCount, 2);
      final merged = result.merged;
      expect(merged.blocked, isFalse);
      expect(
        merged.document!.phases.map((phase) => phase.name),
        ['1순위', '후보 · 1순위', '후보 · 2순위'],
      );
      expect(merged.document!.stages.map((stage) => stage.id), [
        'aru-active',
        'ayane-s1',
        'ayane-s2',
      ]);
      expect(merged.authoring!.prerequisites, isEmpty);
      expect(merged.authoring!.studentOrder, ['aru', 'ayane']);
    });
  });

  group('시나리오 편입 · 활성 나중에(FE4-f2)', () {
    test('활성 나중에 단계보다 높은 시나리오 배치 단계는 빼서 체인이 퇴행하지 않게 한다', () {
      final active = _doc('active-plan', PlanningDocumentKind.plan, [
        PlanningDocumentPhase(
          id: 'p1',
          name: '1순위',
          stages: [_docStage('aru-active', 'aru', 40)],
        ),
      ]);
      final activeAuthoring = PlanningAuthoring.fromWire({
        'version': 1,
        'prerequisites': const <Object>[],
        'deferred_stages': [_docStage('aru-later', 'aru', 45).toWire()],
        'student_order': const ['aru'],
        'stage_order_by_student': const {
          'aru': ['aru-active', 'aru-later'],
        },
        'goal_metadata': const <String, Object>{},
      }, active);
      final scenario = _doc('scenario', PlanningDocumentKind.scenario, [
        PlanningDocumentPhase(
          id: 's1',
          name: '1순위',
          stages: [
            _docStage('aru-s1', 'aru', 60),
            _docStage('ayane-s1', 'ayane', 51),
          ],
        ),
      ]);
      final result = planFlowIncorporateScenario(
        active: active,
        activeAuthoring: activeAuthoring,
        scenarioDocument: scenario,
        scenarioName: '후보',
        seedFor: _seed,
      );
      expect(result.skippedStageCount, 1);
      expect(result.merged.blocked, isFalse);
      expect(result.merged.document!.stages.map((stage) => stage.id), [
        'aru-active',
        'ayane-s1',
      ]);
      expect(result.merged.authoring!.stageOrderByStudent['aru'], [
        'aru-active',
        'aru-later',
      ]);
    });
  });

  group('활성 계획 고치기(FE4-f2)', () {
    test('4단계는 이걸로 바꾸기가 기본이고 페이즈로 추가는 막으며, 초안을 연 revision으로 충돌을 알린다', () async {
      final service = _AuthoringService();
      addTearDown(service.dispose);
      final profileId = await _profileId(service);
      final initial = await service.loadRepositoryPlan(profileId);
      await service.saveRepositoryPlan(
        profileId: profileId,
        document: _doc(initial.document.id, PlanningDocumentKind.plan, [
          PlanningDocumentPhase(
            id: 'p1',
            name: '1순위',
            stages: [_docStage('aru-stage-1', 'aru', 60)],
          ),
        ]),
        expectedRevision: initial.revision,
        idempotencyKey: 'seed-edit-active',
      );
      final plan = await service.loadRepositoryPlan(profileId);
      final state = await service.loadRepositoryState(profileId);
      final catalog = await service.listStudents();
      final flow = PlanFlowController(
        purpose: PlanFlowPurpose.editActivePlan,
        context: PlanFlowContext(
          repositoryState: state,
          catalog: {for (final entry in catalog) entry.studentId: entry},
          activePlan: plan.document,
        ),
        service: service,
        initialDraft: PlanFlowDocumentBoundary.fromDocument(
          plan.document,
          seedFor: _seed,
          authoring: plan.authoring,
        ),
        initialStep: PlanFlowStep.order,
        activePlanRevision: plan.revision,
      );
      addTearDown(flow.dispose);
      expect(flow.draft.phases.single.stageIds, ['aru-stage-1']);
      expect(
        flow.moveStage('aru-stage-1', phaseId: planFlowDeferredLaneId),
        isNull,
      );
      // 초안을 연 뒤 다른 곳에서 활성 계획이 바뀌었다.
      await service.saveRepositoryPlan(
        profileId: profileId,
        document: plan.document,
        expectedRevision: plan.revision,
        idempotencyKey: 'bump-edit-active',
      );
      final save = await _save(flow);
      expect(save.target, PlanFlowSaveTarget.replace);
      expect(save.isAvailable(PlanFlowSaveTarget.appendPhases), isFalse);
      expect(
        save.unavailableReason(PlanFlowSaveTarget.appendPhases),
        contains('고치는 중'),
      );
      expect(save.archiveName, planFlowEditedArchiveName);
      expect(save.snapshot!.revision, plan.revision + 1);
      expect(await save.save(), isNull);
      expect(save.message, contains('바뀌어 저장하지 않았습니다'));
      // 다시 읽은 뒤에는 최신 revision으로 보낸다.
      await save.reload();
      final outcome = await save.save();
      expect(outcome, isNotNull);
      expect(outcome!.changedActivePlan, isTrue);
      final stored = await service.loadRepositoryPlan(profileId);
      expect(stored.document.phases, isEmpty);
      expect(stored.authoring.deferredStages.single.id, 'aru-stage-1');
    });
  });
}
