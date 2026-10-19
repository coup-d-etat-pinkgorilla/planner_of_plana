// 계획 만들기 3단계 단계 순서 테스트(FE4-d1, 시안 Flow-3-Order, FD-035·FD-069·FD-070·FD-071).
//
// - 초안 컨트롤러: 칸에 없는 단계 넣기, 카드 옮기기(선행보다 앞 칸 거부 · 같은 칸 정렬), 칸 이름 · 칸 추가,
//   자동 정렬 3종, 빈 칸은 저장·계산 문서에서 뺀다.
// - 상태(FD-035): 부족 · 막힘 · 가능, 응답 `bottlenecks` · `affected_stage_ids` 읽기.
// - 화면: 처음 그리면 칸에 넣기, 끌어 옮기기와 거부 이유, 카드 고르기 → C 상세, 칸 이름 바꾸기, 칸 추가, 자동 정렬.
// - FE4-d2: 화살표가 칸 머리를 피해 들어가기, 단계가 12개를 넘으면 작게 보기(크게·작게, 펼친 카드, 이어진 선만,
//   흐리게, 선택 풀기, 부족 있는 단계만, 학생별 묶음, 끌어 옮기기·거부).
// - FE4-f2: 선 경로 규칙(작게 보기 사이 줄 칩 피하기 · 같은 줄 아래로 돌기, 크게 보기 "칸 추가" 타일 비키기).
// - FE4-f1: "칸 추가" 아래 빈 "나중에" 칸도 "여기로 끌어다 놓기"를 보인다(교차 선행·나중에 칸은
//   `plan_flow_authoring_test.dart`).
//
// 계산 디바운스(Timer)가 있어서 pumpAndSettle 대신 명시적인 pump를 쓴다.
import 'package:ba_planner_v7/app/theme.dart';
import 'package:ba_planner_v7/services/mock_app_service.dart';
import 'package:ba_planner_v7/ui/kit/kit_pressable.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_draft.dart';
import 'package:ba_planner_v7/ui/models/plan_flow_order_editor.dart';
import 'package:ba_planner_v7/ui/models/planning_models.dart';
import 'package:ba_planner_v7/ui/widgets/plan_flow_order_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 콘텐츠 캔버스(기준 viewport 2560×1392에서 헤더 184 아래).
const _canvas = Size(2560, 1208);

const _shortItem = 'Item_Icon_Material_Nebra_3';
const _shortName = '오파츠 · 네브라 디스크 (최상급)';
const _plentyItem = 'Item_Icon_Material_Nebra_2';

PlanningStudentSeed _seed(String studentId) => PlanningStudentSeed(
  handoffId: 'seed-$studentId',
  studentId: studentId,
  metadata: const {},
  currentValues: const {},
);

PlanFlowStageDraft _v2Stage(String studentId, int number, {int level = 50}) =>
    PlanFlowStageDraft(
      id: '$studentId-stage-$number',
      name: '$number단계',
      targets: {'level': level + number},
    );

/// 아루 2단계 · 아야네 1단계(칸 배치는 [phases]).
PlanFlowDraft _draft({List<PlanFlowPhase> phases = const []}) => PlanFlowDraft(
  students: [_seed('aru'), _seed('ayane')],
  stagesByStudent: {
    'aru': [_v2Stage('aru', 1), _v2Stage('aru', 2)],
    'ayane': [_v2Stage('ayane', 1)],
  },
  phases: phases,
);

/// 단계가 많은 초안(학생 5명 × 3단계 = 15개, 작게 보기). [phases]가 없으면 칸에 넣지 않는다.
const _manyStudents = ['aru', 'ayane', 'hoshino', 'hina', 'noa'];

PlanFlowDraft _manyDraft({List<PlanFlowPhase> phases = const []}) =>
    PlanFlowDraft(
      students: [for (final id in _manyStudents) _seed(id)],
      stagesByStudent: {
        for (final id in _manyStudents)
          id: [for (var step = 1; step <= 3; step++) _v2Stage(id, step)],
      },
      phases: phases,
    );

PlanFlowPhase _phase(String id, String name, List<String> stageIds) =>
    PlanFlowPhase(id: id, name: name, stageIds: stageIds);

List<List<String>> _lanes(PlanFlowController flow) => [
  for (final phase in flow.draft.phases) [...phase.stageIds],
];

/// 학생마다 1단계는 [_shortItem]을 10 모자라게 쓰고(병목은 문서 순서상 첫 1단계), 2단계 이후는 넉넉한
/// [_plentyItem]을 쓴다.
class _OrderService extends MockAppService {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> calculatePlanningDocument({
    required List<Map<String, dynamic>> currentStudents,
    required Map<String, dynamic> inventory,
    required Map<String, dynamic> document,
  }) async {
    calls += 1;
    final seen = <String, int>{};
    final results = <Map<String, dynamic>>[];
    final shortUsers = <String>[];
    final plentyUsers = <String>[];
    String? bottleneck;
    for (final phase in document['phases'] as List) {
      for (final raw in (phase as Map)['stages'] as List) {
        final stage = raw as Map;
        final stageId = stage['stage_id'] as String;
        final step = seen.update(
          stage['student_id'] as String,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        final first = step == 1;
        (first ? shortUsers : plentyUsers).add(stageId);
        if (first) bottleneck ??= stageId;
        results.add({
          'stage_id': stageId,
          'phase_id': phase['phase_id'],
          'student_id': stage['student_id'],
          'name': stage['name'],
          'cost': {'credits': 1000},
          'resources': [
            {
              'resource_key': first ? _shortItem : _plentyItem,
              'item_id': first ? _shortItem : _plentyItem,
              'display_name': first ? _shortName : '오파츠 · 네브라 디스크 (상급)',
              'category': 'oopart',
              'required': 20,
              'owned_at_entry': first ? 10 : 40,
              'shortage_at_entry': first ? 10 : 0,
            },
          ],
        });
      }
    }
    return {
      'document_id': document['document_id'],
      'kind': document['kind'],
      'stage_results': results,
      'phase_results': const <Object>[],
      'overall': {
        'cost': {'credits': 1000 * results.length},
        'resources': [
          {
            'resource_key': _shortItem,
            'item_id': _shortItem,
            'display_name': _shortName,
            'category': 'oopart',
            'required': 20 * shortUsers.length,
            'owned': 10,
            'shortage': 20 * shortUsers.length - 10,
            'affected_stage_ids': shortUsers,
          },
          {
            'resource_key': _plentyItem,
            'item_id': _plentyItem,
            'display_name': '오파츠 · 네브라 디스크 (상급)',
            'category': 'oopart',
            'required': 20 * plentyUsers.length,
            'owned': 999,
            'shortage': 0,
            'affected_stage_ids': plentyUsers,
          },
        ],
      },
      'bottlenecks': [
        if (bottleneck != null)
          {
            'resource_key': _shortItem,
            'item_id': _shortItem,
            'display_name': _shortName,
            'category': 'oopart',
            'shortage': 10,
            'stage_id': bottleneck,
          },
      ],
      'warnings': const <Object>[],
    };
  }
}

Future<PlanFlowContext> _context(MockAppService service) async {
  final profile = (await service.listProfiles()).firstWhere(
    (profile) => profile.selected,
  );
  final state = await service.loadRepositoryState(profile.id);
  final catalog = await service.listStudents();
  return PlanFlowContext(
    repositoryState: state,
    catalog: {for (final entry in catalog) entry.studentId: entry},
  );
}

Future<PlanFlowController> _controller(
  MockAppService service, {
  PlanFlowDraft? draft,
}) async {
  final flow = PlanFlowController(
    purpose: PlanFlowPurpose.newScenario,
    context: await _context(service),
    service: service,
    initialDraft: draft ?? _draft(),
    initialStep: PlanFlowStep.order,
  );
  addTearDown(flow.dispose);
  return flow;
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

/// [stageId] 카드를 끌어 [phaseId] 칸의 빈 자리(오른쪽 3/4 지점)에 놓는다.
Future<void> _drag(
  WidgetTester tester,
  String stageId,
  String phaseId,
) async {
  final card = find.byKey(ValueKey('plan-flow-order-card-$stageId'));
  final lane = tester.getRect(
    find.byKey(ValueKey('plan-flow-order-lane-$phaseId')),
  );
  final gesture = await tester.startGesture(tester.getCenter(card));
  await gesture.moveBy(const Offset(30, 0));
  await tester.pump();
  await gesture.moveTo(Offset(lane.left + lane.width * 0.78, lane.center.dy));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  group('초안 컨트롤러', () {
    test('칸에 없는 단계는 n단계 → n순위 칸에, 이미 칸에 있는 단계는 그대로 둔다', () async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      expect(flow.canGoNext, isFalse);
      flow.placeUnassignedStages();
      expect(_lanes(flow), [
        ['aru-stage-1', 'ayane-stage-1'],
        ['aru-stage-2'],
      ]);
      expect(flow.draft.phases.map((phase) => phase.name), ['1순위', '2순위']);
      expect(flow.canGoNext, isTrue);

      // 아야네가 이미 1순위에 있으면 아루만 넣는다. 칸이 모자라면 "n순위" 칸을 더한다.
      final partial = await _controller(
        service,
        draft: _draft(
          phases: [
            _phase('p1', '급한 것', ['ayane-stage-1']),
          ],
        ),
      );
      partial.placeUnassignedStages();
      expect(_lanes(partial), [
        ['ayane-stage-1', 'aru-stage-1'],
        ['aru-stage-2'],
      ]);
      expect(partial.draft.phases.map((phase) => phase.name), [
        '급한 것',
        '2순위',
      ]);
    });

    test('선행보다 앞 칸 · 뒤 단계보다 뒤 칸은 거부하고 이유를 돌려준다', () async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(
        service,
        draft: _draft(
          phases: [
            _phase('p1', '1순위', ['aru-stage-1', 'ayane-stage-1']),
            _phase('p2', '2순위', ['aru-stage-2']),
            _phase('p3', '3순위', []),
          ],
        ),
      );
      final aru = flow.context.displayName('aru');
      final before = _lanes(flow);
      expect(
        flow.moveStage('aru-stage-1', phaseId: 'p3'),
        '$aru 1단계는 뒤 단계($aru 2단계)보다 뒤 칸에 둘 수 없습니다.',
      );
      expect(_lanes(flow), before);
      // 같은 칸은 허용하고(FD-069), 뒤에 놓아도 선행 → 후행으로 다시 놓는다.
      expect(flow.moveStage('aru-stage-1', phaseId: 'p2', index: 1), isNull);
      expect(_lanes(flow), [
        ['ayane-stage-1'],
        ['aru-stage-1', 'aru-stage-2'],
        <String>[],
      ]);
      expect(flow.orderViolation('aru-stage-2', 0), contains('선행 단계'));
      expect(
        flow.moveStage('aru-stage-2', phaseId: 'p1'),
        '$aru 2단계는 선행 단계($aru 1단계)보다 앞 칸에 둘 수 없습니다.',
      );
      // 칸 안 자리 옮기기: 지금 보이는 목록 기준 자리.
      expect(flow.moveStage('ayane-stage-1', phaseId: 'p2', index: 0), isNull);
      expect(_lanes(flow)[1], ['ayane-stage-1', 'aru-stage-1', 'aru-stage-2']);
      expect(flow.moveStage('ayane-stage-1', phaseId: 'p2', index: 3), isNull);
      expect(_lanes(flow)[1], ['aru-stage-1', 'aru-stage-2', 'ayane-stage-1']);
    });

    test('칸 이름 · 칸 추가 · 빈 칸은 저장 문서와 계산 문서에서 뺀다(FD-071)', () async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      flow.placeUnassignedStages();
      final first = flow.draft.phases.first.id;
      flow.renamePhase(first, '  먼저 할 것 ');
      expect(flow.draft.phases.first.name, '먼저 할 것');
      flow.renamePhase(first, '   ');
      expect(flow.draft.phases.first.name, '1순위');

      final added = flow.addPhase();
      expect(flow.draft.phases.last.id, added);
      expect(flow.draft.phases.last.name, '3순위');
      expect(flow.draft.phases.last.stageIds, isEmpty);

      final document = PlanFlowDocumentBoundary.toScenarioDocument(
        flow.draft,
        id: 'scenario',
        name: '후보',
      );
      expect(document.phases, hasLength(2));
      final wire = PlanFlowDocumentBoundary.calculationWire(
        flow.draft,
        id: 'flow',
      );
      expect(wire['phases'] as List, hasLength(2));
    });

    test('자동 정렬 3종은 같은 학생 순서를 지키고 칸 이름을 앞에서부터 다시 쓴다', () async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      flow.placeUnassignedStages();
      flow.renamePhase(flow.draft.phases.first.id, '먼저');

      flow.autoArrange(PlanFlowAutoArrange.studentOrder);
      expect(_lanes(flow), [
        ['aru-stage-1', 'aru-stage-2'],
        ['ayane-stage-1'],
      ]);
      expect(flow.draft.phases.first.name, '먼저');

      flow.autoArrange(PlanFlowAutoArrange.stageStep);
      expect(_lanes(flow), [
        ['aru-stage-1', 'ayane-stage-1'],
        ['aru-stage-2'],
      ]);
    });

    testWidgets('부족이 적은 단계부터: 계산의 들어설 때 부족 수로 칸을 나누고 같은 학생 순서는 지킨다', (
      tester,
    ) async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      flow.placeUnassignedStages();
      await _settle(tester);
      expect(flow.calculation, isNotNull);
      // 1단계(아루·아야네)는 부족 1종, 아루 2단계는 0종. 아루 2단계는 아루 1단계보다 앞 칸에 갈 수 없다.
      flow.autoArrange(PlanFlowAutoArrange.fewestShortages);
      expect(_lanes(flow), [
        ['aru-stage-1', 'aru-stage-2', 'ayane-stage-1'],
      ]);
      await _settle(tester);
    });
  });

  group('상태(FD-035)', () {
    test('병목 단계는 부족, 그 재화를 문서 순서상 뒤에서 또 쓰는 단계는 막힘, 나머지는 가능', () {
      final draft = _draft(
        phases: [
          _phase('p1', '1순위', ['aru-stage-1', 'ayane-stage-1']),
          _phase('p2', '2순위', ['aru-stage-2']),
        ],
      );
      expect(planFlowStageStatuses(draft, null), isEmpty);
      final calculation = PlanFlowCalculation.fromProjection(
        const {
          'overall': {
            'cost': {'credits': 10},
            'resources': [
              {
                'resource_key': 'x',
                'item_id': 'x',
                'display_name': 'X',
                'category': 'oopart',
                'required': 30,
                'owned': 10,
                'shortage': 20,
                'affected_stage_ids': ['aru-stage-1', 'ayane-stage-1'],
              },
            ],
          },
          'stage_results': <Object>[],
          'bottlenecks': [
            {
              'resource_key': 'x',
              'item_id': 'x',
              'display_name': 'X',
              'stage_id': 'aru-stage-1',
              'shortage': 20,
            },
          ],
        },
        stageLookup: (_) => null,
      );
      expect(calculation.bottlenecks.single.stageId, 'aru-stage-1');
      expect(calculation.bottlenecks.single.resourceKey, 'x');
      expect(calculation.shortages.single.affectedStageIds, [
        'aru-stage-1',
        'ayane-stage-1',
      ]);
      expect(planFlowStageStatuses(draft, calculation), {
        'aru-stage-1': PlanFlowStageStatus.short,
        'ayane-stage-1': PlanFlowStageStatus.blocked,
        'aru-stage-2': PlanFlowStageStatus.possible,
      });

      // 아야네를 병목보다 앞에 두면 막히지 않는다.
      final reordered = _draft(
        phases: [
          _phase('p1', '1순위', ['ayane-stage-1', 'aru-stage-1']),
          _phase('p2', '2순위', ['aru-stage-2']),
        ],
      );
      expect(
        planFlowStageStatuses(reordered, calculation)['ayane-stage-1'],
        PlanFlowStageStatus.possible,
      );
    });

    test('카드 · 칸 머리 글자', () {
      expect(
        planFlowOrderStatusChip(
          PlanFlowStageStatus.blocked,
          owned: true,
          calculating: false,
        ).label,
        '막힘',
      );
      expect(
        planFlowOrderStatusChip(null, owned: false, calculating: true).label,
        '모집 필요',
      );
      expect(
        planFlowOrderStatusChip(null, owned: true, calculating: true).label,
        '계산 중',
      );
      final phase = _phase('p1', '1순위', ['a', 'b']);
      expect(
        planFlowOrderLaneChip(
          phase,
          const {'a': PlanFlowStageStatus.possible},
          const [],
          calculating: false,
        )?.label,
        '모두 지금 가능',
      );
      expect(
        planFlowOrderLaneChip(
          phase,
          const {'a': PlanFlowStageStatus.blocked},
          const [
            PlanFlowLaneShortage(
              resourceKey: 'x',
              name: 'X',
              category: 'oopart',
              shortage: 3,
            ),
          ],
          calculating: false,
        )?.label,
        '부족 1종',
      );
      expect(
        planFlowOrderLaneChip(
          _phase('p2', '2순위', []),
          const {},
          const [],
          calculating: false,
        ),
        isNull,
      );
      expect(
        planFlowGoalChanges(
          const {'level': 70, 'ex_skill': 3, 'skill1': 7},
          const {'level': 90, 'ex_skill': 5, 'skill1': 10},
        ).map((change) => change.detail),
        ['Lv. 70→90', 'EX 3→5', '기본 7→M'],
      );
    });
  });

  group('화면', () {
    testWidgets('처음 그리면 칸에 넣고 카드 · 상태 배지 · 같은 학생 화살표를 그린다', (tester) async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      await _pumpOrder(tester, flow);
      expect(flow.draft.allStagesAssigned, isTrue);
      final phases = flow.draft.phases;
      expect(phases, hasLength(2));
      for (final phase in phases) {
        expect(
          find.byKey(ValueKey('plan-flow-order-lane-${phase.id}')),
          findsOneWidget,
        );
      }
      // 칸은 80° 레일을 따라 한 칸마다 왼쪽으로 놓인다.
      final firstLane = tester.getRect(
        find.byKey(ValueKey('plan-flow-order-lane-${phases[0].id}')),
      );
      final secondLane = tester.getRect(
        find.byKey(ValueKey('plan-flow-order-lane-${phases[1].id}')),
      );
      expect(firstLane.left - secondLane.left, closeTo(40.2, 0.5));
      expect(secondLane.top - firstLane.top, closeTo(228, 0.5));
      expect(find.text('단계 3개'), findsOneWidget);

      String chip(String stageId) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey('plan-flow-order-card-$stageId-status')),
              matching: find.byType(Text),
            ),
          )
          .data!;
      expect(chip('aru-stage-1'), '부족');
      expect(chip('ayane-stage-1'), '막힘');
      expect(chip('aru-stage-2'), '가능');
      final painter = tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey('plan-flow-order-arrows')),
          )
          .painter! as PlanFlowOrderArrowPainter;
      expect(painter.arrows, hasLength(1));
      // FE4-d2: 다음 칸 첫 카드로 가는 화살표는 칸 사이 틈에서 옆으로 가고, 칸 머리(이름 칸 220 + 상태 칩) 오른쪽으로
      // 카드 윗변에 들어간다(보드 좌표, 보드 왼쪽 위 = 캔버스 (400, 101.2)).
      const board = Offset(400, 101.2);
      final arrow = painter.arrows.single;
      final target = tester
          .getRect(find.byKey(const ValueKey('plan-flow-order-card-aru-stage-2')))
          .shift(-board);
      expect(arrow.curve, isFalse);
      expect(arrow.elbowY, closeTo(secondLane.top - board.dy - 7, 0.5));
      expect(arrow.to.dy, closeTo(target.top - 6, 0.5));
      expect(arrow.to.dx, greaterThan(target.left + 25.6 + 220 + 8));
      expect(arrow.to.dx, lessThanOrEqualTo(target.left + 372 + 0.01));
      // 처음 고른 카드는 첫 칸의 첫 단계다.
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('plan-flow-order-aside-title')),
            )
            .data,
        '${flow.context.displayName('aru')} 1단계',
      );
    });

    testWidgets('카드를 끌어 칸을 옮기고, 선행보다 앞 칸은 거부하고 이유를 보인다', (tester) async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      final editor = await _pumpOrder(tester, flow);
      final p1 = flow.draft.phases[0].id;
      final p2 = flow.draft.phases[1].id;

      await _drag(tester, 'aru-stage-1', p2);
      expect(_lanes(flow), [
        ['ayane-stage-1'],
        ['aru-stage-1', 'aru-stage-2'],
      ]);
      expect(editor.message, isNull);
      expect(editor.selectedStageId, 'aru-stage-1');

      await _drag(tester, 'aru-stage-2', p1);
      expect(_lanes(flow), [
        ['ayane-stage-1'],
        ['aru-stage-1', 'aru-stage-2'],
      ]);
      expect(find.byKey(const ValueKey('plan-flow-order-message')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('plan-flow-order-message')))
            .data,
        contains('선행 단계'),
      );
      // 다른 카드를 고르면 이유를 지운다.
      await tester.tap(find.byKey(const ValueKey('plan-flow-order-card-ayane-stage-1')));
      await tester.pump();
      expect(find.byKey(const ValueKey('plan-flow-order-message')), findsNothing);
      await _settle(tester);
    });

    testWidgets('카드를 고르면 C에 포함한 목표 · 먼저 끝나야 하는 단계 · 이 칸의 부족 재화를 보인다', (tester) async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      await _pumpOrder(tester, flow);
      final aru = flow.context.displayName('aru');

      await tester.tap(find.byKey(const ValueKey('plan-flow-order-card-aru-stage-2')));
      await tester.pump();
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('plan-flow-order-aside-title')),
            )
            .data,
        '$aru 2단계',
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('plan-flow-order-aside-goals')),
            )
            .data,
        'Lv. 51→52',
      );
      final predecessor = find.byKey(
        const ValueKey('plan-flow-order-aside-predecessor'),
      );
      expect(
        find.descendant(of: predecessor, matching: find.text('$aru 1단계')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: predecessor, matching: find.text('자동')),
        findsOneWidget,
      );
      // 2순위 칸에는 모자라는 재화가 없다. 1순위 칸은 1단계 둘이 10씩 모자란다.
      expect(
        find.byKey(const ValueKey('plan-flow-order-aside-lane-empty')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('plan-flow-order-card-ayane-stage-1')));
      await tester.pump();
      expect(find.text('이 칸(1순위)에서 부족한 재화'), findsOneWidget);
      final row = find.byKey(
        const ValueKey('plan-flow-order-aside-shortage-$_shortItem'),
      );
      expect(find.descendant(of: row, matching: find.text('−20')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('plan-flow-order-aside-predecessor')),
          matching: find.text('자동'),
        ),
        findsNothing,
      );
    });

    testWidgets('칸 이름 바꾸기 · 칸 추가 · 자동 정렬', (tester) async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service);
      await _pumpOrder(tester, flow);
      final first = flow.draft.phases.first.id;

      await tester.enterText(
        find.descendant(
          of: find.byKey(ValueKey('plan-flow-order-lane-$first-name')),
          matching: find.byType(TextField),
        ),
        '먼저 할 것',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(flow.draft.phases.first.name, '먼저 할 것');

      await tester.tap(find.byKey(const ValueKey('plan-flow-order-add-lane')));
      await tester.pump();
      expect(flow.draft.phases, hasLength(3));
      expect(flow.draft.phases.last.name, '3순위');
      // FE4-f1: 빈 "나중에" 칸에도 같은 안내가 있어 새 칸 안에서 찾는다.
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey('plan-flow-order-lane-${flow.draft.phases.last.id}'),
          ),
          matching: find.text('여기로 끌어다 놓기'),
        ),
        findsOneWidget,
      );
      // 빈 칸에도 끌어 놓을 수 있다(아루 2단계는 아루 1단계보다 뒤 칸이다).
      await _drag(tester, 'aru-stage-2', flow.draft.phases.last.id);
      expect(_lanes(flow), [
        ['aru-stage-1', 'ayane-stage-1'],
        <String>[],
        ['aru-stage-2'],
      ]);

      await tester.tap(
        find.byKey(const ValueKey('plan-flow-order-arrange-studentOrder')),
      );
      await tester.pump();
      expect(_lanes(flow), [
        ['aru-stage-1', 'aru-stage-2'],
        ['ayane-stage-1'],
      ]);
      expect(flow.draft.phases.first.name, '먼저 할 것');
      await _settle(tester);
    });
  });

  group('작게 보기(FE4-d2)', () {
    Finder chipOf(String stageId) =>
        find.byKey(ValueKey('plan-flow-order-chip-$stageId'));
    Finder cardOf(String stageId) =>
        find.byKey(ValueKey('plan-flow-order-card-$stageId'));
    double opacityOf(WidgetTester tester, String stageId) => tester
        .widget<Opacity>(
          find.descendant(of: chipOf(stageId), matching: find.byType(Opacity)).first,
        )
        .opacity;
    PlanFlowOrderArrowPainter arrows(WidgetTester tester) =>
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey('plan-flow-order-arrows')),
                )
                .painter!
            as PlanFlowOrderArrowPainter;

    test('화살표 경로: 같은 칸 다음 줄은 줄 사이 틈, 머리 피하는 x는 카드 윗변 안', () {
      const from = Rect.fromLTWH(1000, 48, 398.4, 150);
      const to = Rect.fromLTWH(170, 212, 398.4, 150);
      final arrow = planFlowOrderArrowBetween(from, to);
      expect(arrow.elbowY, closeTo(to.top - 7, 0.01));
      expect(arrow.to, Offset(to.left + 212.5, to.top - 6));
      expect(arrow.endDirection, const Offset(0, 1));
      expect(arrow.path().getBounds().top, closeTo(from.bottom, 0.01));
      expect(
        planFlowOrderHeaderClearX(to, 60),
        closeTo(to.left + 25.66 + 228 + 76, 0.01),
      );
      expect(planFlowOrderHeaderClearX(to, 400), closeTo(to.left + 372, 0.01));
      final compact = planFlowOrderCompactArrow(
        const Rect.fromLTWH(327.9, 26, 203.8, 44),
        const Rect.fromLTWH(269.7, 167, 398.4, 150),
      );
      // 시안 Flow-3-Order-Many: M425.9 70 C … 468.9 162.
      expect(compact.from.dx, closeTo(425.9, 0.1));
      expect(compact.from.dy, closeTo(70, 0.01));
      expect(compact.to.dx, closeTo(468.9, 0.01));
      expect(compact.to.dy, closeTo(162, 0.01));
      expect(compact.curve, isTrue);
    });

    testWidgets('단계가 12개를 넘으면 작게 보기: 고른 카드만 펼치고 이어진 선만, 나머지는 흐리게', (
      tester,
    ) async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service, draft: _manyDraft());
      await _pumpOrder(tester, flow);
      expect(flow.draft.stageCount, 15);
      expect(
        find.byKey(const ValueKey('plan-flow-order-compact-board')),
        findsOneWidget,
      );
      expect(find.text('단계 15개'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-flow-order-toolbar')), findsOneWidget);
      // 처음 고른 카드(아루 1단계)는 398×150으로 펼치고 칩 자리는 비운다. 나머지 14개는 204×44 칩.
      expect(cardOf('aru-stage-1'), findsOneWidget);
      expect(chipOf('aru-stage-1'), findsNothing);
      final card = tester.getSize(cardOf('aru-stage-1'));
      expect(card.width, closeTo(planFlowOrderCardSize.width, 0.01));
      expect(card.height, closeTo(planFlowOrderCardSize.height, 0.01));
      final chip = tester.getSize(chipOf('ayane-stage-1'));
      expect(chip.width, closeTo(planFlowOrderChipSize.width, 0.01));
      expect(chip.height, closeTo(planFlowOrderChipSize.height, 0.01));
      for (final id in _manyStudents.skip(1)) {
        expect(chipOf('$id-stage-1'), findsOneWidget);
      }
      // 같은 칸 칩은 한 줄에 다섯, 줄마다 레일을 따라 같은 간격.
      final first = tester.getRect(chipOf('ayane-stage-1'));
      final second = tester.getRect(chipOf('hoshino-stage-1'));
      expect(second.left - first.left, closeTo(planFlowOrderChipPitch, 0.5));
      // 펼친 카드는 보이는 칩을 하나도 가리지 않는다(gate ① 20261009_150924 뒤 배치 결정).
      final expandedRect = tester.getRect(cardOf('aru-stage-1'));
      for (final stage in flow.draft.stages) {
        final chipFinder = chipOf(stage.id);
        if (chipFinder.evaluate().isEmpty) continue;
        expect(
          tester.getRect(chipFinder).overlaps(expandedRect),
          isFalse,
          reason: '${stage.id} 칩이 펼친 카드에 가려진다',
        );
      }
      // 선은 고른 카드와 이어진 것(아루 1 → 2)만, 이어지지 않은 칩은 흐리게.
      expect(arrows(tester).arrows, hasLength(1));
      expect(arrows(tester).arrows.single.curve, isTrue);
      expect(opacityOf(tester, 'aru-stage-2'), 1);
      expect(opacityOf(tester, 'ayane-stage-1'), planFlowOrderDimOpacity);

      // 크게 · 작게 세그먼트로 되돌린다.
      await tester.tap(find.text('크게'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('plan-flow-order-compact-board')),
        findsNothing,
      );
      expect(cardOf('ayane-stage-1'), findsOneWidget);
      expect(find.byKey(const ValueKey('plan-flow-order-toolbar')), findsNothing);
      await tester.tap(find.text('작게'));
      await tester.pump();
      expect(chipOf('ayane-stage-1'), findsOneWidget);
    });

    testWidgets('칩을 누르면 그 카드를 펼치고, 선택 중 × 는 선택을 푼다', (tester) async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service, draft: _manyDraft());
      await _pumpOrder(tester, flow);

      await tester.tap(chipOf('aru-stage-2'));
      await tester.pump();
      expect(cardOf('aru-stage-2'), findsOneWidget);
      expect(chipOf('aru-stage-1'), findsOneWidget);
      // 앞(1단계)·뒤(3단계)로 두 선.
      expect(arrows(tester).arrows, hasLength(2));
      expect(opacityOf(tester, 'aru-stage-1'), 1);
      expect(opacityOf(tester, 'aru-stage-3'), 1);
      expect(opacityOf(tester, 'hoshino-stage-2'), planFlowOrderDimOpacity);
      final selection = find.byKey(const ValueKey('plan-flow-order-selection'));
      expect(
        find.descendant(
          of: selection,
          matching: find.text('${flow.context.displayName('aru')} 선택 중'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(of: selection, matching: find.byType(KitPressable)),
      );
      await tester.pump();
      expect(cardOf('aru-stage-2'), findsNothing);
      expect(chipOf('aru-stage-2'), findsOneWidget);
      expect(selection, findsNothing);
      expect(arrows(tester).arrows, isEmpty);
      expect(opacityOf(tester, 'hoshino-stage-2'), 1);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('plan-flow-order-aside-title')),
            )
            .data,
        '고른 단계가 없습니다',
      );
    });

    testWidgets('부족 있는 단계만 · 학생별 묶음은 보기만 바꾸고 배치는 그대로다', (tester) async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(
        service,
        draft: _manyDraft(
          phases: [
            _phase('p1', '1순위', [
              'ayane-stage-1',
              'aru-stage-1',
              'hoshino-stage-1',
              'hina-stage-1',
              'noa-stage-1',
            ]),
            _phase('p2', '2순위', [
              for (final id in _manyStudents) '$id-stage-2',
            ]),
            _phase('p3', '3순위', [
              for (final id in _manyStudents) '$id-stage-3',
            ]),
          ],
        ),
      );
      await _pumpOrder(tester, flow);
      final before = _lanes(flow);
      // 처음 고른 카드는 1순위 첫 카드(아야네 1단계).
      expect(cardOf('ayane-stage-1'), findsOneWidget);
      expect(
        tester.getRect(cardOf('ayane-stage-1')).left,
        lessThan(tester.getRect(chipOf('aru-stage-1')).left),
      );

      // 1단계(병목·막힘)만 남고 2·3단계(가능)는 숨는다.
      await tester.tap(find.byKey(const ValueKey('plan-flow-order-short-only')));
      await tester.pump();
      expect(chipOf('aru-stage-1'), findsOneWidget);
      expect(chipOf('aru-stage-2'), findsNothing);
      expect(find.text('조건에 맞는 단계가 없습니다'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('plan-flow-order-short-only')));
      await tester.pump();
      expect(chipOf('aru-stage-2'), findsOneWidget);

      // 고른 학생 순서(아루 → 아야네 …)로 묶는다.
      await tester.tap(find.byKey(const ValueKey('plan-flow-order-group')));
      await tester.pump();
      expect(
        tester.getRect(cardOf('ayane-stage-1')).left,
        greaterThan(tester.getRect(chipOf('aru-stage-1')).left),
      );
      expect(_lanes(flow), before);
    });

    testWidgets('작게 보기에서도 끌어 옮기고, 선행 규칙에 걸리면 거부한다', (tester) async {
      final service = _OrderService();
      addTearDown(service.dispose);
      final flow = await _controller(service, draft: _manyDraft());
      final editor = await _pumpOrder(tester, flow);
      final lanes = [for (final phase in flow.draft.phases) phase.id];

      Future<void> drag(String stageId, String phaseId) async {
        final lane = tester.getRect(
          find.byKey(ValueKey('plan-flow-order-lane-$phaseId')),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(chipOf(stageId)),
        );
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        await gesture.moveTo(
          Offset(lane.left + lane.width * 0.8, lane.top + 36),
        );
        await tester.pump();
        await gesture.up();
        await tester.pump();
      }

      // 호시노 2단계를 1순위로(같은 칸 허용, 1단계 뒤로 정렬).
      await drag('hoshino-stage-2', lanes[0]);
      expect(editor.message, isNull);
      final first = _lanes(flow)[0];
      expect(first, contains('hoshino-stage-2'));
      expect(
        first.indexOf('hoshino-stage-1'),
        lessThan(first.indexOf('hoshino-stage-2')),
      );
      // 호시노 1단계를 3순위로: 뒤 단계(2단계)보다 뒤 칸이라 거부.
      await drag('hoshino-stage-1', lanes[2]);
      expect(editor.message, contains('뒤 단계'));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('plan-flow-order-message')))
            .data,
        contains('뒤 단계'),
      );
      expect(_lanes(flow)[0], first);
      await _settle(tester);
    });
  });

  group('선 경로(FE4-f2)', () {
    List<Offset> samples(Path path) => [
      for (final metric in path.computeMetrics())
        for (var distance = 0.0; distance <= metric.length; distance += 2)
          metric.getTangentForOffset(distance)!.position,
    ];

    test('작게 보기: 사이 줄 칩을 지나면 칩 사이 틈으로 세로로 지나고 줄 사이 틈에서만 옆으로 간다', () {
      // 0줄 첫 칩 → 2줄 첫 칩. 1줄은 레일을 따라 9.5 왼쪽으로 놓인다.
      const from = Rect.fromLTWH(327.9, 26, 203.8, 44);
      const blocker = Rect.fromLTWH(318.4, 80, 203.8, 44);
      const beside = Rect.fromLTWH(532.15, 80, 203.8, 44);
      const to = Rect.fromLTWH(308.9, 134, 203.8, 44);
      const obstacles = [blocker, beside];
      final direct = planFlowOrderCompactArrow(from, to);
      expect(direct.via, isEmpty);
      expect(planFlowOrderPathHits(direct.path(), obstacles), isTrue);
      final arrow = planFlowOrderCompactArrow(from, to, obstacles: obstacles);
      // S 곡선 판정·시작·끝 점은 돌지 않을 때와 같다.
      expect(arrow.curve, isTrue);
      expect(arrow.from, direct.from);
      expect(arrow.to, direct.to);
      expect(arrow.endDirection, const Offset(0, 1));
      expect(planFlowOrderPathHits(arrow.path(), obstacles), isFalse);
      // 1줄은 두 칩 사이 틈 가운데로, 줄 위·아래 2 안쪽에서 세로로 지난다.
      expect(arrow.via, hasLength(2));
      final channel = (blocker.right + beside.left) / 2;
      expect(arrow.via.first.dx, closeTo(channel, 0.01));
      expect(arrow.via.first.dy, closeTo(blocker.top - 2, 0.01));
      expect(arrow.via.last.dx, closeTo(channel, 0.01));
      expect(arrow.via.last.dy, closeTo(blocker.bottom + 2, 0.01));
      // 옆으로 가는 곳은 줄 사이 틈뿐이다(칩 높이 안에서는 x가 그대로).
      for (final point in samples(arrow.path())) {
        if (point.dy > blocker.top && point.dy < blocker.bottom) {
          expect(point.dx, closeTo(arrow.via.first.dx, 0.5));
        }
      }
      // 막는 칩이 없으면 그대로 S 곡선이다.
      expect(
        planFlowOrderCompactArrow(
          from,
          to,
          obstacles: [beside.shift(const Offset(400, 0))],
        ),
        direct,
      );
    });

    test('작게 보기: 같은 줄 사이에 칩이 있으면 줄 아래 틈으로 돌아 그 칩 아래로 들어간다', () {
      const from = Rect.fromLTWH(327.9, 26, 203.8, 44);
      const middle = Rect.fromLTWH(541.65, 26, 203.8, 44);
      const to = Rect.fromLTWH(755.4, 26, 203.8, 44);
      final direct = planFlowOrderCompactArrow(from, to);
      expect(direct.curve, isFalse);
      expect(planFlowOrderPathHits(direct.path(), [middle]), isTrue);
      final arrow = planFlowOrderCompactArrow(from, to, obstacles: [middle]);
      expect(planFlowOrderPathHits(arrow.path(), [middle]), isFalse);
      expect(arrow.from, Offset(from.center.dx, from.bottom));
      expect(arrow.to, Offset(to.center.dx, to.bottom + 2));
      expect(arrow.endDirection, const Offset(0, -1));
      for (final point in samples(arrow.path())) {
        expect(point.dy, greaterThanOrEqualTo(from.bottom - 0.01));
        expect(point.dy, lessThanOrEqualTo(from.bottom + 6.01));
      }
    });

    test('크게 보기: 칸 → 나중에 칸 선은 "칸 추가" 타일 위 틈에서 타일 오른쪽으로 비켜 내려간다', () {
      const from = Rect.fromLTWH(150, 48, 398.4, 150);
      const add = Rect.fromLTWH(100, 240, 360, 56);
      const to = Rect.fromLTWH(120, 358, 398.4, 150);
      final base = planFlowOrderArrowBetween(
        from,
        to,
        gapY: to.top - 7,
        enterX: to.left + 372,
      );
      expect(planFlowOrderPathHits(base.path(), [add]), isTrue);
      final arrow = planFlowOrderArrowAvoiding(base, add, aboveY: add.top - 7);
      expect(planFlowOrderPathHits(arrow.path(), [add]), isFalse);
      expect(arrow.from, base.from);
      expect(arrow.to, base.to);
      expect(arrow.endDirection, const Offset(0, 1));
      expect(arrow.via, [
        Offset(base.from.dx, add.top - 7),
        Offset(add.right + 16, add.top - 7),
        Offset(add.right + 16, base.elbowY!),
        Offset(base.to.dx, base.elbowY!),
      ]);
      // 타일을 지나지 않는 선은 그대로 둔다.
      final clear = planFlowOrderArrowBetween(
        from.shift(const Offset(500, 0)),
        to,
        gapY: to.top - 7,
        enterX: to.left + 372,
      );
      expect(
        planFlowOrderArrowAvoiding(clear, add, aboveY: add.top - 7),
        same(clear),
      );
    });
  });
}
